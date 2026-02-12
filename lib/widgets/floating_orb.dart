import 'package:flutter/material.dart';

/// Floating orb widget (matches the landing page hero orbs).
class FloatingOrb extends StatefulWidget {
  const FloatingOrb({
    super.key,
    required this.color,
    required this.size,
    this.delay = Duration.zero,
  });

  final Color color;
  final double size;
  final Duration delay;

  @override
  State<FloatingOrb> createState() => _FloatingOrbState();
}

class _FloatingOrbState extends State<FloatingOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final t = _ctrl.value;
        return Transform.translate(
          offset: Offset(0, 20 * (t - 0.5)),
          child: Opacity(opacity: 0.4 + 0.2 * t, child: child),
        );
      },
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.4),
              blurRadius: widget.size * 0.6,
            ),
          ],
        ),
      ),
    );
  }
}
