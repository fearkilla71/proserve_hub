import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/proserve_theme.dart';

class ContractorAccountSummaryCard extends StatelessWidget {
  const ContractorAccountSummaryCard({
    super.key,
    required this.data,
    required this.fallbackName,
    required this.fallbackEmail,
    this.onEdit,
    this.onSetup,
    this.showAction = true,
  });

  final Map<String, dynamic>? data;
  final String fallbackName;
  final String fallbackEmail;
  final VoidCallback? onEdit;
  final VoidCallback? onSetup;
  final bool showAction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final displayName = _firstText([
      data?['publicName'],
      data?['businessName'],
      data?['companyName'],
      data?['name'],
      fallbackName,
    ]);
    final contractorName = _firstText([
      data?['contactName'],
      data?['contractorName'],
      data?['name'],
      fallbackName,
    ]);
    final phone = _formatPhone(_firstText([data?['publicPhone']]));
    final contact = _firstText([phone, fallbackEmail]);
    final headline = _firstText([data?['headline']]);
    final logoUrl = _firstText([data?['logoUrl']]);
    final rating = _numFrom(data?['avgRating'] ?? data?['averageRating']);
    final reviewCount = _intFrom(data?['reviewCount'] ?? data?['totalReviews']);
    final years = _intFrom(data?['yearsExperience']);
    final tier = _tierFor(reviewCount);
    final setupComplete =
        displayName.isNotEmpty && (contact.isNotEmpty || logoUrl.isNotEmpty);
    final badgeLabels = _professionalBadges(data?['badges']);

    return _SummarySurface(
      borderColor: ProServeColors.accent2.withValues(alpha: 0.18),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _AccountAvatar(name: displayName, logoUrl: logoUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _BusinessInfoLine(
                      icon: Icons.person_outline,
                      text: contractorName == displayName
                          ? fallbackName
                          : contractorName,
                    ),
                    if (contact.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _BusinessInfoLine(
                        icon: Icons.phone_outlined,
                        text: contact,
                      ),
                    ],
                    if (headline.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        headline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: ProServeColors.accent2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (showAction) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: setupComplete ? onEdit : onSetup,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    setupComplete
                        ? l10n.editProfile
                        : l10n.contractorHomeCompleteSetup,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  icon: Icons.star_rounded,
                  value: rating > 0 ? rating.toStringAsFixed(1) : '-',
                  label: reviewCount > 0
                      ? l10n.contractorHomeReviews(reviewCount)
                      : l10n.contractorHomeNoReviews,
                  accent: ProServeColors.warning,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStat(
                  icon: Icons.work_history_outlined,
                  value: years > 0 ? l10n.contractorHomeYears(years) : '-',
                  label: l10n.contractorHomeExperience,
                  accent: ProServeColors.accent2,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStat(
                  icon: Icons.verified_outlined,
                  value: tier,
                  label: l10n.contractorHomeTier,
                  accent: ProServeColors.accent,
                ),
              ),
            ],
          ),
          if (badgeLabels.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: badgeLabels
                  .map(
                    (label) => _ProfessionalChip(
                      label: label,
                      icon: Icons.check_circle_outline,
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  static String _firstText(List<dynamic> values) {
    for (final value in values) {
      final text = (value as String?)?.trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static String _formatPhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) {
      return '(${digits.substring(0, 3)}) ${digits.substring(3, 6)}-${digits.substring(6)}';
    }
    return value.trim();
  }

  static double _numFrom(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  static int _intFrom(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static String _tierFor(int reviewCount) {
    if (reviewCount >= 75) return 'Platinum';
    if (reviewCount >= 25) return 'Gold';
    if (reviewCount >= 5) return 'Silver';
    return 'Starter';
  }

  static List<String> _professionalBadges(dynamic raw) {
    final list = raw is List
        ? raw.whereType<String>()
        : const Iterable<String>.empty();
    return list
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .map((value) => value.replaceAll('_', ' '))
        .map(
          (value) => value
              .split(' ')
              .map(
                (part) => part.isEmpty
                    ? part
                    : '${part[0].toUpperCase()}${part.substring(1)}',
              )
              .join(' '),
        )
        .take(3)
        .toList();
  }
}

class _BusinessInfoLine extends StatelessWidget {
  const _BusinessInfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        Icon(icon, color: ProServeColors.muted, size: 14),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: ProServeColors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _SummarySurface extends StatelessWidget {
  const _SummarySurface({
    required this.child,
    required this.padding,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: ProServeColors.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor ?? ProServeColors.lineStrong),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _AccountAvatar extends StatelessWidget {
  const _AccountAvatar({required this.name, required this.logoUrl});

  final String name;
  final String logoUrl;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: ProServeColors.ctaGradient,
        border: Border.all(color: ProServeColors.lineStrong),
      ),
      child: ClipOval(
        child: logoUrl.isEmpty
            ? Center(
                child: Text(
                  initial,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF041016),
                  ),
                ),
              )
            : Image.network(
                logoUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Text(
                    initial,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF041016),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.accent,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ProServeColors.line),
      ),
      child: Column(
        children: [
          Icon(icon, color: accent, size: 18),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: ProServeColors.muted,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfessionalChip extends StatelessWidget {
  const _ProfessionalChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: ProServeColors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: ProServeColors.accent.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: ProServeColors.accent, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: ProServeColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
