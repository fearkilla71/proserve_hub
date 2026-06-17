import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants/service_types.dart';
import '../l10n/app_localizations.dart';
import '../services/connect_service.dart';
import 'contractor_portal_helpers.dart';
import 'page_header.dart';

enum _ToolAccess { pro, enterprise }

class _ToolAction {
  const _ToolAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
    required this.access,
    required this.primaryAction,
    this.metric,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? route;
  final _ToolAccess access;
  final String primaryAction;
  final String? metric;
}

class _ToolSection {
  const _ToolSection({required this.title, required this.tools});

  final String title;
  final List<_ToolAction> tools;
}

class ContractorToolsHub extends StatelessWidget {
  const ContractorToolsHub({
    super.key,
    required this.userData,
    required this.openSubscription,
    required this.openProToolOrSubscribe,
    required this.openEnterpriseToolOrSubscribe,
  });

  final Map<String, dynamic>? userData;
  final VoidCallback openSubscription;
  final Future<void> Function({required Future<void> Function() open})
  openProToolOrSubscribe;
  final Future<void> Function({required Future<void> Function() open})
  openEnterpriseToolOrSubscribe;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isPro = pricingToolsUnlockedFromUserDoc(userData);
    final isEnterprise = isEnterpriseFromUserDoc(userData);
    final sections = _sections(l10n);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      children: [
        PageHeader(
          title: l10n.toolsTitle,
          subtitle: l10n.toolsSubtitle,
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
        ),
        _TodayPanel(
          userData: userData,
          isPro: isPro,
          isEnterprise: isEnterprise,
          onSubscriptionTap: openSubscription,
          onPayoutSetupTap: () => _startPayoutSetup(context),
        ),
        const SizedBox(height: 12),
        _SubscriptionCard(
          isPro: isPro,
          isEnterprise: isEnterprise,
          onTap: openSubscription,
        ),
        const SizedBox(height: 12),
        for (final section in sections) ...[
          _SectionHeader(title: section.title),
          const SizedBox(height: 8),
          ...section.tools.map(
            (tool) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ToolCard(
                tool: tool,
                unlocked: tool.access == _ToolAccess.enterprise
                    ? isEnterprise
                    : isPro,
                onTap: () => _openTool(context, tool),
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ],
    );
  }

  Future<void> _startPayoutSetup(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await ConnectService().startOnboarding();
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.toolsPayoutSetupOpenFailed)));
    }
  }

  Future<void> _openTool(BuildContext context, _ToolAction tool) async {
    Future<void> open() async {
      if (tool.route == null) {
        await _showCostEstimatorPicker(context);
        return;
      }
      context.push(tool.route!);
    }

    if (tool.access == _ToolAccess.enterprise) {
      await openEnterpriseToolOrSubscribe(open: open);
    } else {
      await openProToolOrSubscribe(open: open);
    }
  }

  Future<void> _showCostEstimatorPicker(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.toolSelectServiceType),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: kPaintingServices
                .map(
                  (service) => ListTile(
                    title: Text(service),
                    onTap: () {
                      Navigator.pop(dialogContext);
                      context.push('/cost-estimator/$service');
                    },
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  List<_ToolSection> _sections(AppLocalizations l10n) {
    return [
      _ToolSection(
        title: l10n.toolsSectionWinWork,
        tools: [
          _ToolAction(
            icon: Icons.analytics_outlined,
            title: l10n.toolBidAnalyzerTitle,
            subtitle: l10n.toolBidAnalyzerSubtitle,
            route: '/bid-analyzer',
            access: _ToolAccess.enterprise,
            primaryAction: l10n.toolActionAnalyzeBid,
            metric: l10n.toolMetricRiskScore,
          ),
          _ToolAction(
            icon: Icons.storefront_outlined,
            title: l10n.toolSubMarketplaceTitle,
            subtitle: l10n.toolSubMarketplaceSubtitle,
            route: '/sub-marketplace',
            access: _ToolAccess.enterprise,
            primaryAction: l10n.toolActionPostJob,
            metric: l10n.toolMetricVerifiedSubs,
          ),
        ],
      ),
      _ToolSection(
        title: l10n.toolsSectionEstimateQuote,
        tools: [
          _ToolAction(
            icon: Icons.calculate_outlined,
            title: l10n.toolPricingCalculatorTitle,
            subtitle: l10n.toolPricingCalculatorSubtitle,
            route: '/pricing-calculator',
            access: _ToolAccess.pro,
            primaryAction: l10n.toolActionPriceJob,
            metric: l10n.toolMetricMarginReady,
          ),
          _ToolAction(
            icon: Icons.receipt_long_outlined,
            title: l10n.toolCostEstimatorTitle,
            subtitle: l10n.toolCostEstimatorSubtitle,
            route: null,
            access: _ToolAccess.pro,
            primaryAction: l10n.toolActionEstimateCost,
            metric: l10n.toolMetricRevisionHistory,
          ),
          _ToolAction(
            icon: Icons.folder_copy_outlined,
            title: l10n.toolSavedEstimatesTitle,
            subtitle: l10n.toolSavedEstimatesSubtitle,
            route: '/saved-estimates',
            access: _ToolAccess.pro,
            primaryAction: l10n.toolActionReviewEstimates,
            metric: l10n.toolMetricQuoteReady,
          ),
        ],
      ),
      _ToolSection(
        title: l10n.toolsSectionGetPaid,
        tools: [
          _ToolAction(
            icon: Icons.auto_awesome_outlined,
            title: l10n.toolAiInvoiceMakerTitle,
            subtitle: l10n.toolAiInvoiceMakerSubtitle,
            route: '/invoice-maker',
            access: _ToolAccess.pro,
            primaryAction: l10n.toolActionCreateInvoice,
            metric: l10n.toolMetricPaymentLink,
          ),
          _ToolAction(
            icon: Icons.folder_open_outlined,
            title: l10n.toolInvoicesTitle,
            subtitle: l10n.toolInvoicesSubtitle,
            route: '/invoice-drafts',
            access: _ToolAccess.pro,
            primaryAction: l10n.toolActionTrackInvoices,
            metric: l10n.toolMetricOverdueBadges,
          ),
        ],
      ),
      _ToolSection(
        title: l10n.toolsSectionManageJobs,
        tools: [
          _ToolAction(
            icon: Icons.event_available_outlined,
            title: l10n.toolSmartSchedulingTitle,
            subtitle: l10n.toolSmartSchedulingSubtitle,
            route: '/smart-scheduling',
            access: _ToolAccess.enterprise,
            primaryAction: l10n.toolActionBuildSchedule,
            metric: l10n.toolMetricConflictWarnings,
          ),
          _ToolAction(
            icon: Icons.camera_enhance_outlined,
            title: l10n.toolQualityInspectorTitle,
            subtitle: l10n.toolQualityInspectorSubtitle,
            route: '/quality-inspector',
            access: _ToolAccess.enterprise,
            primaryAction: l10n.toolActionInspectPhotos,
            metric: l10n.toolMetricReportPdf,
          ),
        ],
      ),
      _ToolSection(
        title: l10n.toolsSectionGrowOperations,
        tools: [
          _ToolAction(
            icon: Icons.palette_outlined,
            title: l10n.toolRenderToolTitle,
            subtitle: l10n.toolRenderToolSubtitle,
            route: '/render-tool',
            access: _ToolAccess.pro,
            primaryAction: l10n.toolActionCreateRender,
            metric: l10n.toolMetricClientShare,
          ),
          _ToolAction(
            icon: Icons.photo_library_outlined,
            title: l10n.toolRenderGalleryTitle,
            subtitle: l10n.toolRenderGallerySubtitle,
            route: '/render-gallery',
            access: _ToolAccess.pro,
            primaryAction: l10n.toolActionOpenGallery,
            metric: l10n.toolMetricFolders,
          ),
          _ToolAction(
            icon: Icons.dashboard_customize_outlined,
            title: l10n.toolMultiLocationTitle,
            subtitle: l10n.toolMultiLocationSubtitle,
            route: '/multi-location-dashboard',
            access: _ToolAccess.enterprise,
            primaryAction: l10n.toolActionReviewLocations,
            metric: l10n.toolMetricOwnerSummary,
          ),
        ],
      ),
    ];
  }
}

class _TodayPanel extends StatelessWidget {
  const _TodayPanel({
    required this.userData,
    required this.isPro,
    required this.isEnterprise,
    required this.onSubscriptionTap,
    required this.onPayoutSetupTap,
  });

  final Map<String, dynamic>? userData;
  final bool isPro;
  final bool isEnterprise;
  final VoidCallback onSubscriptionTap;
  final VoidCallback onPayoutSetupTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final leadCredits =
        ((userData?['leadCredits'] as num?)?.toInt() ?? 0) +
        ((userData?['exclusiveLeadCredits'] as num?)?.toInt() ?? 0);
    final payoutsReady =
        userData?['stripePayoutsEnabled'] == true ||
        userData?['payoutsEnabled'] == true;
    final detailsSubmitted = userData?['stripeDetailsSubmitted'] == true;
    final hasStripeAccount =
        (userData?['stripeAccountId'] as String?)?.trim().isNotEmpty == true;
    final payoutLabel = payoutsReady
        ? l10n.toolsPayoutsReady
        : (detailsSubmitted || hasStripeAccount
              ? l10n.toolsPayoutsPending
              : l10n.toolsPayoutsNotConnected);
    final setupLabel = !payoutsReady
        ? (hasStripeAccount
              ? l10n.toolsReviewPayoutSetup
              : l10n.toolsConnectPayouts)
        : l10n.toolsReviewSetup;

    return Card(
      color: scheme.primaryContainer.withValues(alpha: 0.55),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.today_outlined, color: scheme.onPrimaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.toolsTodayTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              l10n.toolsTodaySubtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatusChip(
                  icon: payoutsReady ? Icons.verified : Icons.warning_amber,
                  label: payoutLabel,
                  emphasized: !payoutsReady,
                ),
                _StatusChip(
                  icon: Icons.local_activity_outlined,
                  label: l10n.toolsLeadCredits(leadCredits),
                ),
                _StatusChip(
                  icon: isPro ? Icons.workspace_premium : Icons.lock_outline,
                  label: isPro ? l10n.toolsProActive : l10n.toolsProLocked,
                  emphasized: !isPro,
                ),
                _StatusChip(
                  icon: isEnterprise
                      ? Icons.domain_verification_outlined
                      : Icons.lock_outline,
                  label: isEnterprise
                      ? l10n.toolsEnterpriseActive
                      : l10n.toolsEnterpriseLocked,
                  emphasized: !isEnterprise,
                ),
              ],
            ),
            if (!payoutsReady || !isPro) ...[
              const SizedBox(height: 12),
              if (!payoutsReady) ...[
                Text(
                  l10n.toolsPayoutSetupReason,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: !payoutsReady
                      ? onPayoutSetupTap
                      : onSubscriptionTap,
                  icon: Icon(
                    !payoutsReady
                        ? Icons.account_balance_wallet_outlined
                        : Icons.tune_outlined,
                  ),
                  label: Text(setupLabel),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.label,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      visualDensity: VisualDensity.compact,
      backgroundColor: emphasized ? scheme.errorContainer : null,
      labelStyle: emphasized ? TextStyle(color: scheme.onErrorContainer) : null,
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({
    required this.isPro,
    required this.isEnterprise,
    required this.onTap,
  });

  final bool isPro;
  final bool isEnterprise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final compact = isPro || isEnterprise;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.contractorProTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Chip(
                  label: Text(
                    isEnterprise
                        ? l10n.accessEnterprise
                        : (isPro ? l10n.active : l10n.accessPro),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            SizedBox(height: compact ? 4 : 6),
            if (!compact) ...[
              Text(
                l10n.contractorProPrice,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              compact
                  ? l10n.toolsSubscriptionActiveSubtitle
                  : l10n.contractorProUnlocks,
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: compact ? 2 : null,
              overflow: compact ? TextOverflow.ellipsis : null,
            ),
            SizedBox(height: compact ? 8 : 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.workspace_premium),
                onPressed: onTap,
                label: Text(isPro ? l10n.manageSubscription : l10n.subscribe),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.tool,
    required this.unlocked,
    required this.onTap,
  });

  final _ToolAction tool;
  final bool unlocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final accessLabel = tool.access == _ToolAccess.enterprise
        ? l10n.accessEnterprise
        : l10n.accessPro;
    final lockedLabel = tool.access == _ToolAccess.enterprise
        ? l10n.lockedEnterprise
        : l10n.lockedPro;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: unlocked
                    ? scheme.primaryContainer
                    : scheme.surfaceContainerHighest,
                child: Icon(
                  unlocked ? tool.icon : Icons.lock_outline,
                  color: unlocked ? scheme.onPrimaryContainer : scheme.outline,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tool.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tool.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Chip(
                          label: Text(unlocked ? accessLabel : lockedLabel),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                        if (tool.metric != null)
                          Chip(
                            label: Text(tool.metric!),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        TextButton.icon(
                          onPressed: onTap,
                          icon: Icon(
                            unlocked
                                ? Icons.arrow_forward
                                : Icons.workspace_premium,
                            size: 18,
                          ),
                          label: Text(
                            unlocked
                                ? tool.primaryAction
                                : l10n.toolActionUnlock,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
