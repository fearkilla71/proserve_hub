import 'package:flutter/material.dart';

import '../theme/proserve_theme.dart';

class EntryBenefit {
  const EntryBenefit({
    required this.icon,
    required this.label,
    required this.description,
  });

  final IconData icon;
  final String label;
  final String description;
}

class ProServeEntryScaffold extends StatelessWidget {
  const ProServeEntryScaffold({
    super.key,
    required this.roleLabel,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.benefits,
    required this.child,
    this.onBack,
    this.trailing,
  });

  final String roleLabel;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final List<EntryBenefit> benefits;
  final Widget child;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ProServeColors.bgDeep,
      body: Stack(
        children: [
          const Positioned.fill(child: _EntryBackground()),
          SafeArea(
            child: CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _EntryIconButton(
                              icon: Icons.arrow_back,
                              label: 'Back',
                              onPressed:
                                  onBack ??
                                  () => Navigator.of(context).maybePop(),
                            ),
                            const Spacer(),
                            if (trailing != null) trailing!,
                          ],
                        ),
                        const SizedBox(height: 22),
                        _EntryHero(
                          roleLabel: roleLabel,
                          title: title,
                          subtitle: subtitle,
                          icon: icon,
                          accent: accent,
                          benefits: benefits,
                        ),
                        const SizedBox(height: 18),
                        child,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProServeEntryPanel extends StatelessWidget {
  const ProServeEntryPanel({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.step,
    this.totalSteps,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final int? step;
  final int? totalSteps;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: ProServeColors.cardGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ProServeColors.lineStrong),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (step != null && totalSteps != null) ...[
            ProServeStepProgress(step: step!, totalSteps: totalSteps!),
            const SizedBox(height: 16),
          ],
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: ProServeColors.muted,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class ProServeStepProgress extends StatelessWidget {
  const ProServeStepProgress({
    super.key,
    required this.step,
    required this.totalSteps,
  });

  final int step;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: ProServeColors.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: ProServeColors.accent.withValues(alpha: 0.32),
            ),
          ),
          child: Text(
            'Step ${step + 1} of $totalSteps',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: ProServeColors.accent,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: (step + 1) / totalSteps,
              backgroundColor: ProServeColors.lineStrong,
              valueColor: const AlwaysStoppedAnimation(ProServeColors.accent),
            ),
          ),
        ),
      ],
    );
  }
}

class ProServeEntryDivider extends StatelessWidget {
  const ProServeEntryDivider({super.key, this.label = 'or'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: ProServeColors.lineStrong)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label, style: Theme.of(context).textTheme.labelMedium),
        ),
        const Expanded(child: Divider(color: ProServeColors.lineStrong)),
      ],
    );
  }
}

class ProServeEntryActionRow extends StatelessWidget {
  const ProServeEntryActionRow({
    super.key,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.loading = false,
  });

  final String primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (secondaryLabel != null) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: loading ? null : onSecondary,
              child: Text(secondaryLabel!),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          flex: 2,
          child: FilledButton(
            onPressed: loading ? null : onPrimary,
            child: loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(primaryLabel),
          ),
        ),
      ],
    );
  }
}

class _EntryHero extends StatelessWidget {
  const _EntryHero({
    required this.roleLabel,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.benefits,
  });

  final String roleLabel;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final List<EntryBenefit> benefits;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ProServeColors.card.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: ProServeColors.ctaGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: ProServeColors.bgDeep),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PROSERVE HUB',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _RolePill(label: roleLabel, color: accent),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontSize: 44,
              height: 0.98,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: ProServeColors.ink.withValues(alpha: 0.78),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          ...benefits
              .take(3)
              .map(
                (benefit) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Icon(benefit.icon, color: accent, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${benefit.label}: ',
                                style: const TextStyle(
                                  color: ProServeColors.ink,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              TextSpan(text: benefit.description),
                            ],
                          ),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: ProServeColors.muted,
                                height: 1.35,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  const _RolePill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _EntryIconButton extends StatelessWidget {
  const _EntryIconButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: label,
      onPressed: onPressed,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        backgroundColor: ProServeColors.card.withValues(alpha: 0.78),
        foregroundColor: ProServeColors.ink,
        side: const BorderSide(color: ProServeColors.lineStrong),
      ),
    );
  }
}

class _EntryBackground extends StatelessWidget {
  const _EntryBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: ProServeColors.heroGradient),
      child: Stack(
        children: [
          Positioned(
            top: -90,
            right: -80,
            child: _BlurCircle(
              size: 220,
              color: ProServeColors.accent2,
              opacity: 0.11,
            ),
          ),
          Positioned(
            bottom: -120,
            left: -90,
            child: _BlurCircle(
              size: 260,
              color: ProServeColors.accent,
              opacity: 0.08,
            ),
          ),
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),
        ],
      ),
    );
  }
}

class _BlurCircle extends StatelessWidget {
  const _BlurCircle({
    required this.size,
    required this.color,
    required this.opacity,
  });

  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: opacity),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.025)
      ..strokeWidth = 1;
    const gap = 40.0;
    for (var x = 0.0; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
