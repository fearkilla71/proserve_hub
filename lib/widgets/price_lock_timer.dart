import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/proserve_theme.dart';

/// Animated 24-hour price lock countdown timer.
///
/// Shows remaining time with urgency colors:
/// - Green: > 6 hours
/// - Amber: 1–6 hours
/// - Red/pulsing: < 1 hour
class PriceLockTimer extends StatefulWidget {
  final DateTime expiresAt;
  final VoidCallback? onExpired;

  const PriceLockTimer({super.key, required this.expiresAt, this.onExpired});

  @override
  State<PriceLockTimer> createState() => _PriceLockTimerState();
}

class _PriceLockTimerState extends State<PriceLockTimer>
    with SingleTickerProviderStateMixin {
  late Timer _timer;
  late Duration _remaining;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _remaining = widget.expiresAt.difference(DateTime.now());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _tick() {
    setState(() {
      _remaining = widget.expiresAt.difference(DateTime.now());
      if (_remaining.isNegative) {
        _remaining = Duration.zero;
        _timer.cancel();
        widget.onExpired?.call();
      }
      // Pulse when under 1 hour
      if (_remaining.inHours < 1 && _remaining > Duration.zero) {
        if (!_pulseController.isAnimating) {
          _pulseController.repeat(reverse: true);
        }
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Color _timerColor() {
    if (_remaining.inHours >= 6) return ProServeColors.success;
    if (_remaining.inHours >= 1) return ProServeColors.warning;
    return ProServeColors.error;
  }

  String _formatDuration(Duration d) {
    if (d <= Duration.zero) return 'EXPIRED';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final expired = _remaining <= Duration.zero;
    final color = _timerColor();
    final totalSeconds = 24 * 3600.0;
    final progress = expired
        ? 0.0
        : (_remaining.inSeconds / totalSeconds).clamp(0.0, 1.0);

    return ScaleTransition(
      scale: _remaining.inHours < 1 && !expired
          ? _pulseAnim
          : const AlwaysStoppedAnimation(1.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            // Circular progress
            SizedBox(
              width: 40,
              height: 40,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 3,
                    backgroundColor: color.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                  Icon(
                    expired ? Icons.timer_off : Icons.lock_clock,
                    color: color,
                    size: 18,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Timer text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expired ? 'Price Lock Expired' : 'Price Locked For You',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    expired
                        ? 'This price is no longer available'
                        : _formatDuration(_remaining),
                    style: TextStyle(
                      color: expired ? Colors.white54 : Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: expired ? 12 : 18,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            if (!expired)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '24h LOCK',
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
