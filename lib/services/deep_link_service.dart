import 'dart:async';

import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:go_router/go_router.dart';

import '../screens/chat_screen.dart';
import '../screens/job_detail_page.dart';
import '../screens/payment_history_screen.dart';

/// Handles external deep links (URI) + internal "deep link" payloads (like FCM data)
/// and navigates using the GoRouter's navigator key.
class DeepLinkService {
  static GoRouter? _router;
  static StreamSubscription? _sub;

  static final AppLinks _appLinks = AppLinks();

  static Uri? _pendingUri;
  static Map<String, dynamic>? _pendingData;

  static void initialize({required GoRouter router}) {
    _router = router;

    // Handle initial launch deep link.
    () async {
      try {
        final initial = await _appLinks.getInitialLink();
        if (initial != null) {
          _pendingUri = initial;
          _tryHandlePending();
        }
      } catch (e) {
        debugPrint('DeepLinkService: getInitialUri failed: $e');
      }
    }();

    // Listen for deep links while app is running.
    _sub?.cancel();
    _sub = _appLinks.uriLinkStream.listen(
      (uri) {
        _pendingUri = uri;
        _tryHandlePending();
      },
      onError: (e) {
        debugPrint('DeepLinkService: uriLinkStream error: $e');
      },
    );

    // Also try pending in case navigator wasn't ready at init time.
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryHandlePending());
  }

  static void dispose() {
    _sub?.cancel();
    _sub = null;
  }

  /// Handle internal payloads (e.g., push notification data).
  /// If navigation isn't ready yet, the payload will be queued and retried.
  static void handlePayload(Map<String, dynamic> data) {
    _pendingData = data;
    _tryHandlePending();
  }

  static void _tryHandlePending() {
    final key = _router?.routerDelegate.navigatorKey;
    final nav = key?.currentState;
    final context = key?.currentContext;
    if (nav == null || context == null) return;

    final uri = _pendingUri;
    if (uri != null) {
      _pendingUri = null;
      _navigateFromUri(context, uri);
    }

    final data = _pendingData;
    if (data != null) {
      _pendingData = null;
      _navigateFromPayload(context, data);
    }
  }

  static void _navigateFromUri(BuildContext context, Uri uri) {
    // For custom URL schemes, the "route" is often encoded in the host
    // (e.g. proservehub://payments). For http(s) links, the host is the domain.
    final isHttp = uri.scheme == 'http' || uri.scheme == 'https';
    final host = isHttp ? '' : uri.host.trim();

    final segments = <String>[
      if (host.isNotEmpty) host,
      ...uri.pathSegments.where((s) => s.trim().isNotEmpty),
    ];
    final first = segments.isNotEmpty ? segments.first.toLowerCase() : '';

    String? readId(int idx, String queryKey) {
      if (segments.length > idx) return segments[idx];
      return uri.queryParameters[queryKey];
    }

    switch (first) {
      case '':
      case 'home':
        Navigator.popUntil(context, (route) => route.isFirst);
        return;

      case 'job':
      case 'jobs':
        final jobId = readId(1, 'jobId');
        if (jobId == null || jobId.trim().isEmpty) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => JobDetailPage(jobId: jobId)),
        );
        return;

      case 'chat':
      case 'chats':
        final conversationId = readId(1, 'conversationId');
        final otherUserId = uri.queryParameters['otherUserId'];
        final otherUserName = uri.queryParameters['otherUserName'];
        final jobId = uri.queryParameters['jobId'];

        if (conversationId == null || conversationId.trim().isEmpty) return;
        if (otherUserId == null || otherUserId.trim().isEmpty) return;
        if (otherUserName == null || otherUserName.trim().isEmpty) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              conversationId: conversationId,
              otherUserId: otherUserId,
              otherUserName: otherUserName,
              jobId: jobId,
            ),
          ),
        );
        return;

      case 'payments':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PaymentHistoryScreen()),
        );
        return;

      default:
        debugPrint('DeepLinkService: Unhandled URI $uri');
        return;
    }
  }

  static void _navigateFromPayload(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final type = data['type'] as String?;

    switch (type) {
      case 'message':
        final conversationId = data['conversationId'] as String?;
        final otherUserId = data['otherUserId'] as String?;
        final otherUserName = data['otherUserName'] as String?;
        final jobId = data['jobId'] as String?;

        if (conversationId != null &&
            otherUserId != null &&
            otherUserName != null &&
            conversationId.trim().isNotEmpty &&
            otherUserId.trim().isNotEmpty &&
            otherUserName.trim().isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                conversationId: conversationId,
                otherUserId: otherUserId,
                otherUserName: otherUserName,
                jobId: jobId,
              ),
            ),
          );
        }
        return;

      case 'bid':
      case 'bid_accepted':
      case 'bid_rejected':
      case 'job_match':
      case 'job_status':
        final jobId = data['jobId'] as String?;
        if (jobId != null && jobId.trim().isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => JobDetailPage(jobId: jobId)),
          );
        }
        return;

      case 'payment':
      case 'payments':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PaymentHistoryScreen()),
        );
        return;

      default:
        debugPrint('DeepLinkService: Unhandled payload type: $type');
        return;
    }
  }
}
