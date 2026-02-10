import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ---------------------------------------------------------------------------
// Shared helper widgets for the Contractor Portal tabs.
// Extracted from contractor_portal_page.dart to reduce file size.
// ---------------------------------------------------------------------------

/// Small pill showing a status badge (e.g. "Verified", "Active").
Widget contractorStatusPill({
  required BuildContext context,
  required String label,
  required IconData icon,
  Color? sideColor,
}) {
  final scheme = Theme.of(context).colorScheme;
  final borderColor = sideColor ?? scheme.outlineVariant;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: borderColor),
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: sideColor ?? scheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

/// ListTile-style action row for the Plan tab.
Widget contractorActionTile({
  required BuildContext context,
  required IconData icon,
  required String title,
  required String subtitle,
  required VoidCallback onTap,
}) {
  return ListTile(
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}

/// Format a Firestore Timestamp for display.
String formatTimestamp(dynamic raw) {
  if (raw == null) return '';
  final ts = raw is Timestamp ? raw : null;
  if (ts == null) return '';
  return DateFormat.yMMMd().add_jm().format(ts.toDate());
}

/// Check whether the user doc indicates pricing tools are unlocked.
bool pricingToolsUnlockedFromUserDoc(Map<String, dynamic>? data) {
  if (data == null) return false;
  return data['pricingToolsPro'] == true ||
      data['contractorPro'] == true ||
      data['isPro'] == true;
}
