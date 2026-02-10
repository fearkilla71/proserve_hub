import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling background message: ${message.messageId}');
}

class FcmService {
  static final Set<String> _syncedUids = <String>{};
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static Function(Map<String, dynamic>)? _onNotificationTap;
  static StreamSubscription<String>? _tokenRefreshSub;

  static bool _isMobilePlatform() {
    return !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
  }

  /// Initialize FCM with notification handling
  static Future<void> initialize({
    Function(Map<String, dynamic>)? onNotificationTap,
  }) async {
    if (!_isMobilePlatform()) return;

    _onNotificationTap = onNotificationTap;

    // Set up background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Initialize local notifications
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        if (response.payload != null && _onNotificationTap != null) {
          final data = _parsePayload(response.payload!);
          _onNotificationTap!(data);
        }
      },
    );

    // Create notification channel for Android
    const androidChannel = AndroidNotificationChannel(
      'proserve_hub_channel',
      'ProServe Hub Notifications',
      description: 'Notifications for messages, bids, and job updates',
      importance: Importance.high,
      playSound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(androidChannel);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });

    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (_onNotificationTap != null) {
        _onNotificationTap!(message.data);
      }
    });

    // Check for initial message (app opened from terminated state)
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null && _onNotificationTap != null) {
      _onNotificationTap!(initialMessage.data);
    }
  }

  /// Show local notification for foreground messages
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'proserve_hub_channel',
      'ProServe Hub Notifications',
      channelDescription: 'Notifications for messages, bids, and job updates',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      details,
      payload: _encodePayload(message.data),
    );
  }

  /// Parse notification payload
  static Map<String, dynamic> _parsePayload(String payload) {
    try {
      final parts = payload.split('&');
      final map = <String, dynamic>{};
      for (final part in parts) {
        final kv = part.split('=');
        if (kv.length == 2) {
          map[Uri.decodeComponent(kv[0])] = Uri.decodeComponent(kv[1]);
        }
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  /// Encode notification data to payload
  static String _encodePayload(Map<String, dynamic> data) {
    return data.entries
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}',
        )
        .join('&');
  }

  /// Sync FCM token to Firestore
  static Future<void> syncTokenOnce() async {
    if (!_isMobilePlatform()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (_syncedUids.contains(user.uid)) return;

    try {
      final messaging = FirebaseMessaging.instance;

      // Request permission (iOS will prompt; Android typically auto-grants)
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('FCM permission denied');
        return;
      }

      final token = await messaging.getToken();
      if (token == null || token.trim().isEmpty) return;

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmToken': token.trim(),
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _syncedUids.add(user.uid);

      // Cancel any previous listener to prevent writing to a stale uid
      // after sign-out / sign-in with a different account.
      await _tokenRefreshSub?.cancel();

      // Capture uid at subscription time so the closure always writes to the
      // correct user document, even if FirebaseAuth.currentUser changes.
      final capturedUid = user.uid;
      _tokenRefreshSub =
          FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        final t = newToken.trim();
        if (t.isEmpty) return;
        FirebaseFirestore.instance.collection('users').doc(capturedUid).set({
          'fcmToken': t,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });
    } catch (e) {
      debugPrint('FCM token sync error: $e');
    }
  }

  /// Clear FCM token on logout
  static Future<void> clearToken() async {
    if (!_isMobilePlatform()) return;

    // Cancel the token-refresh listener first to prevent writes after
    // sign-out (the currentUser reference may become null mid-flow).
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _syncedUids.clear();
      return;
    }

    try {
      await FirebaseMessaging.instance.deleteToken();
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmToken': FieldValue.delete(),
      }, SetOptions(merge: true));

      _syncedUids.remove(user.uid);
    } catch (e) {
      debugPrint('FCM token clear error: $e');
    }
  }

  /// Get current notification permission status
  static Future<bool> hasPermission() async {
    if (!_isMobilePlatform()) return false;

    try {
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (_) {
      return false;
    }
  }
}
