import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants/service_types.dart';

/// Shows the tools quick-actions bottom sheet.
///
/// [parentContext] — the State's context used for navigation after sheet closes.
/// [openProToolOrSubscribe] — gate that checks Pro entitlement before opening.
Future<void> showToolsQuickActions({
  required BuildContext sheetContext,
  required BuildContext parentContext,
  required Future<void> Function({required Future<void> Function() open})
  openProToolOrSubscribe,
}) async {
  await showModalBottomSheet<void>(
    context: sheetContext,
    showDragHandle: true,
    builder: (context) {
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
              'Tools',
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
                    title: 'AI Invoice Maker',
                    subtitle: 'Generate line items and export PDF',
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
                    title: 'Invoices',
                    subtitle: 'Browse saved invoices & track status',
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
                    title: 'Pricing Calculator',
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
                    title: 'Cost Estimator',
                    onTap: () async {
                      Navigator.pop(context);
                      await openProToolOrSubscribe(
                        open: () async {
                          showDialog(
                            context: parentContext,
                            builder: (dlgCtx) => AlertDialog(
                              title: const Text('Select Service Type'),
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
                    title: 'Render Tool',
                    subtitle: 'Preview wall colors on photos',
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
                    title: 'Render Gallery',
                    subtitle: 'Browse saved renders by room',
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
                    title: 'Smart Scheduling AI',
                    subtitle: 'AI-optimized crew schedules',
                    onTap: () async {
                      Navigator.pop(context);
                      await openProToolOrSubscribe(
                        open: () async =>
                            parentContext.push('/smart-scheduling'),
                      );
                    },
                  ),
                  divider,
                  tile(
                    icon: Icons.camera_enhance,
                    title: 'AI Quality Inspector',
                    subtitle: 'Detect defects in photos',
                    onTap: () async {
                      Navigator.pop(context);
                      await openProToolOrSubscribe(
                        open: () async =>
                            parentContext.push('/quality-inspector'),
                      );
                    },
                  ),
                  divider,
                  tile(
                    icon: Icons.dashboard,
                    title: 'Multi-Location Dashboard',
                    subtitle: 'Track crews & revenue',
                    onTap: () async {
                      Navigator.pop(context);
                      await openProToolOrSubscribe(
                        open: () async =>
                            parentContext.push('/multi-location-dashboard'),
                      );
                    },
                  ),
                  divider,
                  tile(
                    icon: Icons.storefront,
                    title: 'Sub Marketplace',
                    subtitle: 'Post jobs for sub bids',
                    onTap: () async {
                      Navigator.pop(context);
                      await openProToolOrSubscribe(
                        open: () async =>
                            parentContext.push('/sub-marketplace'),
                      );
                    },
                  ),
                  divider,
                  tile(
                    icon: Icons.analytics,
                    title: 'AI Bid Analyzer',
                    subtitle: 'Compare competitor bids',
                    onTap: () async {
                      Navigator.pop(context);
                      await openProToolOrSubscribe(
                        open: () async => parentContext.push('/bid-analyzer'),
                      );
                    },
                  ),
                  divider,
                  tile(
                    icon: Icons.workspace_premium,
                    title: 'Subscribe (\$11.99/mo)',
                    onTap: () {
                      Navigator.pop(context);
                      parentContext.push('/contractor-subscription');
                    },
                  ),
                  divider,
                  tile(
                    icon: Icons.rocket_launch,
                    title: 'Boost Listing',
                    subtitle: 'Appear first in search results',
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
