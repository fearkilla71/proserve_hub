import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../services/offline_sync_service.dart';
import '../theme/proserve_theme.dart';

class OfflineBanner extends StatefulWidget {
  final Widget child;

  const OfflineBanner({super.key, required this.child});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  bool _isOffline = false;
  int _pendingSync = 0;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      final hasConnection = results.any(
        (result) => result != ConnectivityResult.none,
      );
      setState(() {
        _isOffline = !hasConnection;
      });
    });
    OfflineSyncService.instance.pendingSyncCount.addListener(
      _onSyncCountChanged,
    );
    _pendingSync = OfflineSyncService.instance.pendingSyncCount.value;
  }

  void _onSyncCountChanged() {
    if (mounted) {
      setState(() {
        _pendingSync = OfflineSyncService.instance.pendingSyncCount.value;
      });
    }
  }

  Future<void> _checkConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    final hasConnection = results.any(
      (result) => result != ConnectivityResult.none,
    );
    if (mounted) {
      setState(() {
        _isOffline = !hasConnection;
      });
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    OfflineSyncService.instance.pendingSyncCount.removeListener(
      _onSyncCountChanged,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showBanner = _isOffline || _pendingSync > 0;
    return Stack(
      children: [
        widget.child,
        if (showBanner)
          Positioned(
            top: MediaQuery.of(context).padding.top,
            left: 0,
            right: 0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              color: _isOffline
                  ? ProServeColors.error.withValues(alpha: 0.18)
                  : ProServeColors.accent.withValues(alpha: 0.15),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isOffline ? Icons.wifi_off : Icons.sync,
                    color: _isOffline
                        ? ProServeColors.error
                        : ProServeColors.accent,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isOffline
                        ? 'Offline${_pendingSync > 0 ? ' · $_pendingSync changes pending' : ''}'
                        : 'Syncing $_pendingSync changes…',
                    style: const TextStyle(
                      color: ProServeColors.ink,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
