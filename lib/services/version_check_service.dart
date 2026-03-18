import 'package:flutter/material.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Compares the running app version against Remote Config values and shows:
///  • A **blocking** dialog when the app is below `minimum_app_version`.
///  • A **dismissible** dialog when a newer `latest_app_version` is available
///    (shown at most once per version so users aren't nagged repeatedly).
class VersionCheckService {
  VersionCheckService._();

  static final VersionCheckService instance = VersionCheckService._();

  static const _dismissedKey = 'dismissed_update_version';

  /// Call once after Firebase initialisation (e.g. from a root gate widget).
  Future<void> checkForUpdate(BuildContext context) async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setDefaults({
        'minimum_app_version': '1.0.0',
        'latest_app_version': '1.0.0',
        'app_store_url': '',
        'play_store_url': '',
        'update_message':
            'A new version of ProServe Hub is available. Please update to continue.',
        'optional_update_message':
            'A new version of ProServe Hub is available with improvements and bug fixes.',
      });
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: const Duration(hours: 1),
        ),
      );
      await remoteConfig.fetchAndActivate();

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final minVersion = remoteConfig.getString('minimum_app_version');
      final latestVersion = remoteConfig.getString('latest_app_version');

      // 1) Forced update — current version is below the hard minimum
      if (_isOlderThan(currentVersion, minVersion)) {
        if (!context.mounted) return;
        final message = remoteConfig.getString('update_message');
        _showForceUpdateDialog(context, message, remoteConfig);
        return;
      }

      // 2) Optional update — a newer version exists but isn't mandatory
      if (_isOlderThan(currentVersion, latestVersion)) {
        // Only show once per latest version so we don't nag
        final prefs = await SharedPreferences.getInstance();
        final dismissed = prefs.getString(_dismissedKey);
        if (dismissed == latestVersion) return;

        if (!context.mounted) return;
        final message = remoteConfig.getString('optional_update_message');
        _showOptionalUpdateDialog(
            context, message, latestVersion, remoteConfig);
      }
    } catch (_) {
      // Non-critical – silently ignore so the app remains usable.
    }
  }

  /// Returns the current app version string (e.g. "1.0.0+1").
  static Future<String> currentVersionLabel() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return 'Version ${info.version}+${info.buildNumber}';
    } catch (_) {
      return 'Version 1.0.0';
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────

  /// Compare two semver strings.  Returns `true` when [current] < [minimum].
  bool _isOlderThan(String current, String minimum) {
    final cur = _parseVersion(current);
    final min = _parseVersion(minimum);
    for (int i = 0; i < 3; i++) {
      if (cur[i] < min[i]) return true;
      if (cur[i] > min[i]) return false;
    }
    return false;
  }

  List<int> _parseVersion(String v) {
    final parts = v.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    while (parts.length < 3) {
      parts.add(0);
    }
    return parts;
  }

  void _showForceUpdateDialog(
    BuildContext context,
    String message,
    FirebaseRemoteConfig config,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          icon: const Icon(Icons.system_update, size: 48),
          title: const Text('Update Required'),
          content: Text(message),
          actions: [
            // Allow dismissing on desktop where no store URL exists
            if (Theme.of(ctx).platform != TargetPlatform.iOS &&
                Theme.of(ctx).platform != TargetPlatform.android)
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Dismiss'),
              ),
            FilledButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('Update Now'),
              onPressed: () => _openStore(ctx, config),
            ),
          ],
        ),
      ),
    );
  }

  void _showOptionalUpdateDialog(
    BuildContext context,
    String message,
    String latestVersion,
    FirebaseRemoteConfig config,
  ) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.system_update_alt, size: 48),
        title: const Text('Update Available'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () async {
              // Remember dismissal so we don't nag again for this version
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(_dismissedKey, latestVersion);
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Later'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.download),
            label: const Text('Update Now'),
            onPressed: () => _openStore(ctx, config),
          ),
        ],
      ),
    );
  }

  void _openStore(BuildContext context, FirebaseRemoteConfig config) {
    final url = Theme.of(context).platform == TargetPlatform.iOS
        ? config.getString('app_store_url')
        : config.getString('play_store_url');
    if (url.isNotEmpty) {
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      Navigator.of(context).pop();
    }
  }
}
