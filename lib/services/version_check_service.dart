import 'package:flutter/material.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Compares the running app version against a minimum version published in
/// Firebase Remote Config.  If the installed version is older, a non-dismissible
/// dialog prompts the user to update.
class VersionCheckService {
  VersionCheckService._();

  static final VersionCheckService instance = VersionCheckService._();

  /// Call once after Firebase initialisation (e.g. from main.dart).
  Future<void> checkForUpdate(BuildContext context) async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setDefaults({
        'minimum_app_version': '1.0.0',
        'app_store_url': '',
        'play_store_url': '',
        'update_message':
            'A new version of ProServe Hub is available. Please update to continue.',
      });
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: const Duration(hours: 1),
        ),
      );
      await remoteConfig.fetchAndActivate();

      final minVersion = remoteConfig.getString('minimum_app_version');
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      if (_isOlderThan(currentVersion, minVersion)) {
        if (!context.mounted) return;
        final message = remoteConfig.getString('update_message');
        _showUpdateDialog(context, message, remoteConfig);
      }
    } catch (_) {
      // Non-critical – silently ignore version check failures so the app
      // remains usable even if Remote Config is unreachable.
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

  void _showUpdateDialog(
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
            FilledButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('Update Now'),
              onPressed: () {
                final url = Theme.of(ctx).platform == TargetPlatform.iOS
                    ? config.getString('app_store_url')
                    : config.getString('play_store_url');
                if (url.isNotEmpty) {
                  launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
