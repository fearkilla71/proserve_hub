import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants/service_types.dart';
import '../l10n/app_localizations.dart';

/// Shows the tools quick-actions bottom sheet.
///
/// [parentContext] — the State's context used for navigation after sheet closes.
/// [openProToolOrSubscribe] — gate that checks Pro entitlement before opening.
Future<void> showToolsQuickActions({
  required BuildContext sheetContext,
  required BuildContext parentContext,
  required Future<void> Function({required Future<void> Function() open})
  openProToolOrSubscribe,
  required Future<void> Function({required Future<void> Function() open})
  openEnterpriseToolOrSubscribe,
}) async {
  await showModalBottomSheet<void>(
    context: sheetContext,
    showDragHandle: true,
    builder: (context) {
      final l10n = AppLocalizations.of(context)!;

      Widget tile({
        required IconData icon,
        required String title,
        String? subtitle,
        required VoidCallback onTap,
      }) {
        return ListTile(
          leading: CircleAvatar(child: Icon(icon)),
          title: Text(title),
          subtitle: subtitle != null ? Text(subtitle) : null,
          onTap: onTap,
        );
      }

      const divider = Divider(height: 1);

      return SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          shrinkWrap: true,
          children: [
            Text(
              l10n.toolsTitle,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  tile(
                    icon: Icons.auto_awesome_outlined,
                    title: l10n.toolAiInvoiceMakerTitle,
                    subtitle: l10n.toolAiInvoiceMakerSubtitle,
                    onTap: () async {
                      Navigator.pop(context);
                      await openProToolOrSubscribe(
                        open: () async => parentContext.push('/invoice-maker'),
                      );
                    },
                  ),
                  divider,
                  tile(
                    icon: Icons.folder_open,
                    title: l10n.toolInvoicesTitle,
                    subtitle: l10n.toolInvoicesSubtitle,
                    onTap: () async {
                      Navigator.pop(context);
                      await openProToolOrSubscribe(
                        open: () async => parentContext.push('/invoice-drafts'),
                      );
                    },
                  ),
                  divider,
                  tile(
                    icon: Icons.calculate,
                    title: l10n.toolPricingCalculatorTitle,
                    subtitle: l10n.toolPricingCalculatorSubtitle,
                    onTap: () async {
                      Navigator.pop(context);
                      await openProToolOrSubscribe(
                        open: () async =>
                            parentContext.push('/pricing-calculator'),
                      );
                    },
                  ),
                  divider,
                  tile(
                    icon: Icons.receipt_long,
                    title: l10n.toolCostEstimatorTitle,
                    subtitle: l10n.toolCostEstimatorSubtitle,
                    onTap: () async {
                      Navigator.pop(context);
                      await openProToolOrSubscribe(
                        open: () async {
                          showDialog(
                            context: parentContext,
                            builder: (dlgCtx) => AlertDialog(
                              title: Text(l10n.toolSelectServiceType),
                              content: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: kPaintingServices
                                      .map(
                                        (service) => ListTile(
                                          title: Text(service),
                                          onTap: () {
                                            Navigator.pop(dlgCtx);
                                            parentContext.push(
                                              '/cost-estimator/$service',
                                            );
                                          },
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  divider,
                  tile(
                    icon: Icons.palette_outlined,
                    title: l10n.toolRenderToolTitle,
                    subtitle: l10n.toolRenderToolSubtitle,
                    onTap: () async {
                      Navigator.pop(context);
                      await openProToolOrSubscribe(
                        open: () async => parentContext.push('/render-tool'),
                      );
                    },
                  ),
                  divider,
                  tile(
                    icon: Icons.photo_library_outlined,
                    title: l10n.toolRenderGalleryTitle,
                    subtitle: l10n.toolRenderGallerySubtitle,
                    onTap: () async {
                      Navigator.pop(context);
                      await openProToolOrSubscribe(
                        open: () async => parentContext.push('/render-gallery'),
                      );
                    },
                  ),
                  divider,
                  tile(
                    icon: Icons.auto_awesome,
                    title: l10n.toolSmartSchedulingTitle,
                    subtitle: l10n.toolSmartSchedulingSubtitle,
                    onTap: () async {
                      Navigator.pop(context);
                      await openEnterpriseToolOrSubscribe(
                        open: () async =>
                            parentContext.push('/smart-scheduling'),
                      );
                    },
                  ),
                  divider,
                  tile(
                    icon: Icons.camera_enhance,
                    title: l10n.toolQualityInspectorTitle,
                    subtitle: l10n.toolQualityInspectorSubtitle,
                    onTap: () async {
                      Navigator.pop(context);
                      await openEnterpriseToolOrSubscribe(
                        open: () async =>
                            parentContext.push('/quality-inspector'),
                      );
                    },
                  ),
                  divider,
                  tile(
                    icon: Icons.dashboard,
                    title: l10n.toolMultiLocationTitle,
                    subtitle: l10n.toolMultiLocationSubtitle,
                    onTap: () async {
                      Navigator.pop(context);
                      await openEnterpriseToolOrSubscribe(
                        open: () async =>
                            parentContext.push('/multi-location-dashboard'),
                      );
                    },
                  ),
                  divider,
                  tile(
                    icon: Icons.storefront,
                    title: l10n.toolSubMarketplaceTitle,
                    subtitle: l10n.toolSubMarketplaceSubtitle,
                    onTap: () async {
                      Navigator.pop(context);
                      await openEnterpriseToolOrSubscribe(
                        open: () async =>
                            parentContext.push('/sub-marketplace'),
                      );
                    },
                  ),
                  divider,
                  tile(
                    icon: Icons.analytics,
                    title: l10n.toolBidAnalyzerTitle,
                    subtitle: l10n.toolBidAnalyzerSubtitle,
                    onTap: () async {
                      Navigator.pop(context);
                      await openEnterpriseToolOrSubscribe(
                        open: () async => parentContext.push('/bid-analyzer'),
                      );
                    },
                  ),
                  divider,
                  tile(
                    icon: Icons.workspace_premium,
                    title: l10n.subscribe,
                    onTap: () {
                      Navigator.pop(context);
                      parentContext.push('/contractor-subscription');
                    },
                  ),
                  divider,
                  tile(
                    icon: Icons.rocket_launch,
                    title: l10n.boostListingTitle,
                    subtitle: l10n.boostListingSubtitle,
                    onTap: () {
                      Navigator.pop(context);
                      parentContext.push('/boost-listing');
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
