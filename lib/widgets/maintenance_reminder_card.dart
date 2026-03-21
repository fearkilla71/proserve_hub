import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/proserve_theme.dart';

/// Smart maintenance reminder cards shown after completed jobs.
class MaintenanceReminderCard extends StatelessWidget {
  const MaintenanceReminderCard({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('maintenance_reminders')
          .where('dismissed', isEqualTo: false)
          .where('reminderDate', isLessThanOrEqualTo: Timestamp.now())
          .orderBy('reminderDate')
          .limit(3)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError || !snap.hasData || snap.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final reminders = snap.data!.docs;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.notifications_active,
                    color: ProServeColors.accent2,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Maintenance Reminders',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ...reminders.map((doc) {
              final data = doc.data();
              return _ReminderTile(reminderId: doc.id, userId: uid, data: data);
            }),
          ],
        );
      },
    );
  }
}

class _ReminderTile extends StatelessWidget {
  final String reminderId;
  final String userId;
  final Map<String, dynamic> data;

  const _ReminderTile({
    required this.reminderId,
    required this.userId,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final title = data['title'] as String? ?? 'Maintenance Due';
    final service = data['service'] as String? ?? '';
    final icon = _iconForService(service);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              ProServeColors.warning.withValues(alpha: 0.08),
              ProServeColors.accent.withValues(alpha: 0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: ProServeColors.warning.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ProServeColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: ProServeColors.warning, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tap to schedule a follow-up',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  tooltip: 'Dismiss',
                  onPressed: () {
                    FirebaseFirestore.instance
                        .collection('users')
                        .doc(userId)
                        .collection('maintenance_reminders')
                        .doc(reminderId)
                        .update({'dismissed': true});
                  },
                ),
                FilledButton.tonal(
                  onPressed: () {
                    context.push(
                      '/smart-request',
                      extra: {'serviceType': service, 'serviceName': title},
                    );
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(0, 34),
                  ),
                  child: const Text(
                    'Book',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForService(String service) {
    const map = {
      'interior_painting': Icons.format_paint,
      'exterior_painting': Icons.house,
      'drywall_repair': Icons.construction,
      'pressure_washing': Icons.water_drop,
      'cabinets': Icons.kitchen,
      'roofing': Icons.roofing,
      'flooring': Icons.grid_view,
      'plumbing': Icons.plumbing,
      'electrical': Icons.electrical_services,
    };
    return map[service] ?? Icons.build;
  }
}
