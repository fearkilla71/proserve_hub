import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Animated aura effects painted around the contractor card.
/// Each effect has its own painter driven by an animation value [t] ∈ [0, 1].
enum AuraType { none, lightning, fire, rainbow, ice, gold }

String auraLabel(AuraType a) {
  switch (a) {
    case AuraType.none:
      return 'None';
    case AuraType.lightning:
      return 'Lightning';
    case AuraType.fire:
      return 'Fire';
    case AuraType.rainbow:
      return 'Rainbow';
    case AuraType.ice:
      return 'Ice';
    case AuraType.gold:
      return 'Gold';
  }
}

AuraType auraFromString(String? s) {
  switch (s) {
    case 'lightning':
      return AuraType.lightning;
    case 'fire':
      return AuraType.fire;
    case 'rainbow':
      return AuraType.rainbow;
    case 'ice':
      return AuraType.ice;
    case 'gold':
      return AuraType.gold;
    default:
      return AuraType.none;
  }
}

String auraToString(AuraType a) {
  switch (a) {
    case AuraType.none:
      return 'none';
    case AuraType.lightning:
      return 'lightning';
    case AuraType.fire:
      return 'fire';
    case AuraType.rainbow:
      return 'rainbow';
    case AuraType.ice:
      return 'ice';
    case AuraType.gold:
      return 'gold';
  }
}

IconData auraIcon(AuraType a) {
  switch (a) {
    case AuraType.none:
      return Icons.block;
    case AuraType.lightning:
      return Icons.bolt;
    case AuraType.fire:
      return Icons.local_fire_department;
    case AuraType.rainbow:
      return Icons.auto_awesome;
    case AuraType.ice:
      return Icons.ac_unit;
    case AuraType.gold:
      return Icons.star;
  }
}

class CardAuraPainter extends CustomPainter {
  CardAuraPainter({
    required this.aura,
    required this.t,
    required this.borderRadius,
  });

  final AuraType aura;
  final double t; // 0..1 looping animation value
  final double borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    if (aura == AuraType.none) return;

    switch (aura) {
      case AuraType.lightning:
        _paintLightning(canvas, size);
        break;
      case AuraType.fire:
        _paintFire(canvas, size);
        break;
      case AuraType.rainbow:
        _paintRainbow(canvas, size);
        break;
      case AuraType.ice:
        _paintIce(canvas, size);
        break;
      case AuraType.gold:
        _paintGold(canvas, size);
        break;
      default:
        break;
    }
  }

  // ─── Lightning ────────────────────────────────────────────────────
  void _paintLightning(Canvas canvas, Size size) {
    final rng = math.Random((t * 30).floor());
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Outer glow
    final glowPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 18)
      ..color = const Color(
        0xFF4FC3F7,
      ).withValues(alpha: 0.3 + 0.2 * math.sin(t * math.pi * 2));

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(-4, -4, size.width + 8, size.height + 8),
      Radius.circular(borderRadius + 4),
    );
    canvas.drawRRect(rrect, glowPaint);

    // Electric bolts around perimeter
    final numBolts = 6;
    for (int i = 0; i < numBolts; i++) {
      final progress = ((t * 3 + i / numBolts) % 1.0);
      final startPoint = _pointOnPerimeter(size, progress);
      final endPoint = _pointOnPerimeter(size, (progress + 0.08) % 1.0);

      final path = Path();
      path.moveTo(startPoint.dx, startPoint.dy);

      final segments = 4 + rng.nextInt(3);
      for (int j = 1; j <= segments; j++) {
        final frac = j / segments;
        final baseX = startPoint.dx + (endPoint.dx - startPoint.dx) * frac;
        final baseY = startPoint.dy + (endPoint.dy - startPoint.dy) * frac;
        final jitter = (rng.nextDouble() - 0.5) * 14;
        path.lineTo(baseX + jitter, baseY + jitter);
      }

      paint.color = Color.lerp(
        const Color(0xFF4FC3F7),
        const Color(0xFFE1F5FE),
        rng.nextDouble(),
      )!.withValues(alpha: 0.5 + rng.nextDouble() * 0.5);
      paint.strokeWidth = 1.0 + rng.nextDouble() * 2.0;
      canvas.drawPath(path, paint);
    }

    // Spark particles
    final sparkPaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 12; i++) {
      final angle = (t * 4 + i * 0.52) * math.pi * 2;
      final radius = 4 + rng.nextDouble() * 10;
      final pos = _pointOnPerimeter(size, (t * 2 + i / 12) % 1.0);
      final offsetPos = Offset(
        pos.dx + math.cos(angle) * radius,
        pos.dy + math.sin(angle) * radius,
      );
      sparkPaint.color = const Color(
        0xFFE1F5FE,
      ).withValues(alpha: rng.nextDouble() * 0.8);
      canvas.drawCircle(offsetPos, 1.0 + rng.nextDouble() * 1.5, sparkPaint);
    }
  }

  // ─── Fire ─────────────────────────────────────────────────────────
  void _paintFire(Canvas canvas, Size size) {
    // Outer ember glow
    final glowPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 22)
      ..color = const Color(
        0xFFFF6D00,
      ).withValues(alpha: 0.25 + 0.15 * math.sin(t * math.pi * 2));

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(-6, -6, size.width + 12, size.height + 12),
      Radius.circular(borderRadius + 6),
    );
    canvas.drawRRect(rrect, glowPaint);

    // Flame tongues rising from bottom
    final rng = math.Random(42);
    final flamePaint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 16; i++) {
      final baseX = (i / 16) * size.width;
      final phase = rng.nextDouble() * math.pi * 2;
      final height = 12 + 18 * math.sin(t * math.pi * 4 + phase).abs();
      final width = 6 + rng.nextDouble() * 8;

      final path = Path();
      path.moveTo(baseX - width / 2, size.height + 4);
      path.quadraticBezierTo(
        baseX + math.sin(t * math.pi * 3 + phase) * 4,
        size.height - height,
        baseX + width / 2,
        size.height + 4,
      );

      final color = Color.lerp(
        const Color(0xFFFF6D00),
        const Color(0xFFFFD600),
        math.sin(t * math.pi * 3 + phase).abs(),
      )!;
      flamePaint.color = color.withValues(
        alpha: 0.4 + 0.3 * math.sin(t * math.pi * 2 + phase).abs(),
      );
      canvas.drawPath(path, flamePaint);
    }

    // Top edge subtle heat shimmer
    for (int i = 0; i < 10; i++) {
      final baseX = (i / 10) * size.width;
      final phase = rng.nextDouble() * math.pi * 2;
      final height = 6 + 10 * math.sin(t * math.pi * 3 + phase).abs();

      final path = Path();
      path.moveTo(baseX - 4, -2);
      path.quadraticBezierTo(
        baseX + math.sin(t * math.pi * 2 + phase) * 3,
        -height,
        baseX + 4,
        -2,
      );
      flamePaint.color = const Color(0xFFFF6D00).withValues(alpha: 0.15);
      canvas.drawPath(path, flamePaint);
    }

    // Ember particles
    final emberPaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 10; i++) {
      final startX = rng.nextDouble() * size.width;
      final phase = rng.nextDouble() * math.pi * 2;
      final y =
          size.height - (t * 80 + i * 12 + phase * 5) % (size.height + 20);
      final x = startX + math.sin(t * math.pi * 2 + phase) * 8;
      final alpha = (1 - y / size.height).clamp(0.0, 0.8);

      emberPaint.color = Color.lerp(
        const Color(0xFFFF6D00),
        const Color(0xFFFFEA00),
        rng.nextDouble(),
      )!.withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), 1.2 + rng.nextDouble(), emberPaint);
    }
  }

  // ─── Rainbow / Holographic ────────────────────────────────────────
  void _paintRainbow(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(-2, -2, size.width + 4, size.height + 4),
      Radius.circular(borderRadius + 2),
    );

    // Sweeping rainbow gradient
    paint.shader = ui.Gradient.sweep(
      Offset(size.width / 2, size.height / 2),
      [
        HSLColor.fromAHSL(1, (t * 360) % 360, 0.9, 0.6).toColor(),
        HSLColor.fromAHSL(1, (t * 360 + 60) % 360, 0.9, 0.6).toColor(),
        HSLColor.fromAHSL(1, (t * 360 + 120) % 360, 0.9, 0.6).toColor(),
        HSLColor.fromAHSL(1, (t * 360 + 180) % 360, 0.9, 0.6).toColor(),
        HSLColor.fromAHSL(1, (t * 360 + 240) % 360, 0.9, 0.6).toColor(),
        HSLColor.fromAHSL(1, (t * 360 + 300) % 360, 0.9, 0.6).toColor(),
        HSLColor.fromAHSL(1, (t * 360) % 360, 0.9, 0.6).toColor(),
      ],
      [0, 0.17, 0.33, 0.5, 0.67, 0.83, 1.0],
    );

    canvas.drawRRect(rrect, paint);

    // Holographic shimmer overlay
    final shimmerPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;

    shimmerPaint.shader = ui.Gradient.sweep(
      Offset(size.width / 2, size.height / 2),
      [
        Colors.white.withValues(alpha: 0),
        Colors.white.withValues(alpha: 0.3),
        Colors.white.withValues(alpha: 0),
      ],
      [(t - 0.05) % 1.0, t % 1.0, (t + 0.05) % 1.0]..sort(),
    );

    canvas.drawRRect(rrect, shimmerPaint);
  }

  // ─── Ice / Frost ──────────────────────────────────────────────────
  void _paintIce(Canvas canvas, Size size) {
    // Frost glow
    final glowPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 16)
      ..color = const Color(
        0xFF80DEEA,
      ).withValues(alpha: 0.2 + 0.1 * math.sin(t * math.pi * 2));

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(-4, -4, size.width + 8, size.height + 8),
      Radius.circular(borderRadius + 4),
    );
    canvas.drawRRect(rrect, glowPaint);

    // Frost crystals around edge
    final rng = math.Random(77);
    final crystalPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 20; i++) {
      final pos = _pointOnPerimeter(size, (i / 20 + t * 0.3) % 1.0);
      final angle = rng.nextDouble() * math.pi * 2;
      final len = 4 + rng.nextDouble() * 8;
      final alpha = 0.3 + 0.4 * math.sin(t * math.pi * 3 + i).abs();

      crystalPaint.color = Color.lerp(
        const Color(0xFF80DEEA),
        const Color(0xFFE0F7FA),
        rng.nextDouble(),
      )!.withValues(alpha: alpha);

      // 6-armed snowflake
      for (int arm = 0; arm < 6; arm++) {
        final armAngle = angle + arm * (math.pi / 3);
        final end = Offset(
          pos.dx + math.cos(armAngle) * len,
          pos.dy + math.sin(armAngle) * len,
        );
        canvas.drawLine(pos, end, crystalPaint);

        // Small branch
        final mid = Offset(
          pos.dx + math.cos(armAngle) * len * 0.6,
          pos.dy + math.sin(armAngle) * len * 0.6,
        );
        final branchAngle = armAngle + math.pi / 6;
        final branchEnd = Offset(
          mid.dx + math.cos(branchAngle) * len * 0.3,
          mid.dy + math.sin(branchAngle) * len * 0.3,
        );
        canvas.drawLine(mid, branchEnd, crystalPaint);
      }
    }

    // Glitter particles
    final glitterPaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 15; i++) {
      final px = rng.nextDouble() * size.width;
      final py = rng.nextDouble() * size.height;
      final twinkle = math.sin(t * math.pi * 6 + i * 1.3).abs();
      glitterPaint.color = Colors.white.withValues(alpha: twinkle * 0.6);
      canvas.drawCircle(Offset(px, py), 0.8 + twinkle * 1.2, glitterPaint);
    }
  }

  // ─── Gold ─────────────────────────────────────────────────────────
  void _paintGold(Canvas canvas, Size size) {
    // Golden glow
    final glowPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 20)
      ..color = const Color(
        0xFFFFD54F,
      ).withValues(alpha: 0.3 + 0.15 * math.sin(t * math.pi * 2));

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(-4, -4, size.width + 8, size.height + 8),
      Radius.circular(borderRadius + 4),
    );
    canvas.drawRRect(rrect, glowPaint);

    // Shining sweep
    final sweepPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    sweepPaint.shader = ui.Gradient.sweep(
      Offset(size.width / 2, size.height / 2),
      [
        const Color(0x00FFD54F),
        const Color(0xCCFFD54F),
        const Color(0xFFFFECB3),
        const Color(0xCCFFD54F),
        const Color(0x00FFD54F),
      ],
      [
        (t - 0.1) % 1.0,
        (t - 0.03) % 1.0,
        t % 1.0,
        (t + 0.03) % 1.0,
        (t + 0.1) % 1.0,
      ]..sort(),
    );
    canvas.drawRRect(rrect, sweepPaint);

    // Sparkle particles drifting upward
    final rng = math.Random(99);
    final sparklePaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 12; i++) {
      final baseX = rng.nextDouble() * size.width;
      final phase = rng.nextDouble() * math.pi * 2;
      final y =
          (1 - ((t * 1.5 + i * 0.08 + phase / 6) % 1.0)) * (size.height + 30) -
          10;
      final x = baseX + math.sin(t * math.pi * 2 + phase) * 6;
      final twinkle = math.sin(t * math.pi * 4 + i * 2).abs();

      sparklePaint.color = Color.lerp(
        const Color(0xFFFFD54F),
        const Color(0xFFFFF9C4),
        twinkle,
      )!.withValues(alpha: twinkle * 0.7);

      // 4-pointed star
      final r = 1.5 + twinkle * 2;
      final path = Path();
      for (int p = 0; p < 4; p++) {
        final a = p * (math.pi / 2) + t * math.pi;
        final outerX = x + math.cos(a) * r;
        final outerY = y + math.sin(a) * r;
        final innerA = a + math.pi / 4;
        final innerX = x + math.cos(innerA) * r * 0.3;
        final innerY = y + math.sin(innerA) * r * 0.3;
        if (p == 0) {
          path.moveTo(outerX, outerY);
        } else {
          path.lineTo(outerX, outerY);
        }
        path.lineTo(innerX, innerY);
      }
      path.close();
      canvas.drawPath(path, sparklePaint);
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────
  Offset _pointOnPerimeter(Size size, double fraction) {
    final totalPerimeter = 2 * (size.width + size.height);
    final dist = fraction * totalPerimeter;

    if (dist < size.width) {
      return Offset(dist, 0); // top
    } else if (dist < size.width + size.height) {
      return Offset(size.width, dist - size.width); // right
    } else if (dist < 2 * size.width + size.height) {
      return Offset(
        size.width - (dist - size.width - size.height),
        size.height,
      ); // bottom
    } else {
      return Offset(
        0,
        size.height - (dist - 2 * size.width - size.height),
      ); // left
    }
  }

  @override
  bool shouldRepaint(covariant CardAuraPainter old) {
    return aura != old.aura || t != old.t;
  }
}
