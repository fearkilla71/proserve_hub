import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants/launch_regions.dart';
import '../l10n/app_localizations.dart';
import '../services/region_waitlist_service.dart';

Future<bool> ensureSupportedLaunchRegion(
  BuildContext context, {
  required String zip,
  required String role,
  String? service,
}) async {
  final normalizedZip = normalizeZip(zip);
  if (isSupportedLaunchZip(normalizedZip)) return true;

  await RegionWaitlistService().saveAccountRegion(
    zip: normalizedZip,
    role: role,
    service: service,
  );

  if (!context.mounted) return false;
  final l10n = AppLocalizations.of(context)!;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(l10n.regionWaitlistRequestBlocked)));
  context.go('/region-waitlist');
  return false;
}
