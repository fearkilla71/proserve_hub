import 'package:flutter/material.dart';

import '../theme/proserve_theme.dart';

class ProServeSurfaceCard extends StatelessWidget {
  const ProServeSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
    this.borderColor,
    this.highlight = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? borderColor;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final effectiveBorder =
        borderColor ??
        (highlight
            ? ProServeColors.accent.withValues(alpha: 0.72)
            : ProServeColors.lineStrong);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        gradient: ProServeColors.cardGradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: effectiveBorder, width: highlight ? 1.6 : 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class ProServeStatusPill extends StatelessWidget {
  const ProServeStatusPill({
    super.key,
    required this.label,
    this.icon,
    this.color = ProServeColors.accent,
  });

  final String label;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: ProServeColors.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class ProServeNoticeBanner extends StatelessWidget {
  const ProServeNoticeBanner({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.icon = Icons.info_outline,
    this.tone = ProServeNoticeTone.info,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData icon;
  final ProServeNoticeTone tone;

  @override
  Widget build(BuildContext context) {
    final accent = switch (tone) {
      ProServeNoticeTone.info => ProServeColors.accent2,
      ProServeNoticeTone.warning => ProServeColors.warning,
      ProServeNoticeTone.error => ProServeColors.error,
      ProServeNoticeTone.success => ProServeColors.success,
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 19),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: ProServeColors.ink,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 8),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

enum ProServeNoticeTone { info, warning, error, success }
