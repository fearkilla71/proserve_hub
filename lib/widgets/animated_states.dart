import 'package:flutter/material.dart';

import '../theme/proserve_theme.dart';

class AnimatedStateSwitcher extends StatelessWidget {
  const AnimatedStateSwitcher({
    super.key,
    required this.stateKey,
    required this.child,
    this.duration = const Duration(milliseconds: 200),
  });

  final String stateKey;
  final Widget child;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
        final slide = Tween<Offset>(
          begin: const Offset(0, 0.03),
          end: Offset.zero,
        ).animate(fade);
        return FadeTransition(
          opacity: fade,
          child: SlideTransition(position: slide, child: child),
        );
      },
      child: KeyedSubtree(key: ValueKey<String>(stateKey), child: child),
    );
  }
}

class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.footnote,
    this.action,
    this.secondaryAction,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? footnote;
  final Widget? action;
  final Widget? secondaryAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtitleText = (subtitle ?? '').trim();
    final footnoteText = (footnote ?? '').trim();

    return Container(
      decoration: BoxDecoration(
        gradient: ProServeColors.cardGradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ProServeColors.lineStrong),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: ProServeColors.accent.withValues(
                    alpha: 0.13,
                  ),
                  foregroundColor: ProServeColors.accent,
                  child: Icon(icon),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      if (subtitleText.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          subtitleText,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: ProServeColors.muted),
                        ),
                      ],
                      if (footnoteText.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer.withValues(
                              alpha: 0.22,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: scheme.primary.withValues(alpha: 0.22),
                            ),
                          ),
                          child: Text(
                            footnoteText,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: scheme.onSurface,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (action != null) ...[
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: action!),
            ],
            if (secondaryAction != null) ...[
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: secondaryAction!),
            ],
          ],
        ),
      ),
    );
  }
}
