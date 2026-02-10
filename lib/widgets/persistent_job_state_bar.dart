import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

enum JobBarRole { customer, contractor }

class PersistentJobStateBar extends StatelessWidget {
  final JobBarRole role;

  const PersistentJobStateBar({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    final baseQuery = FirebaseFirestore.instance.collection('job_requests');

    final Query<Map<String, dynamic>> query;
    if (role == JobBarRole.customer) {
      query = baseQuery
          .where('requesterUid', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(1);
    } else {
      query = baseQuery
          .where('claimedBy', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(1);
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final doc = snapshot.data!.docs.first;
        final data = doc.data();

        final status = (data['status'] as String?)?.trim().toLowerCase() ?? '';

        final jobId = doc.id;

        final inProgress =
            status == 'accepted' ||
            status == 'claimed' ||
            status == 'in_progress' ||
            status == 'completion_requested' ||
            status == 'completion_approved';

        if (inProgress) {
          return _Bar(
            title: 'In progress',
            subtitle: 'Work is underway.',
            actionLabel: 'Open job',
            onPressed: () {
              context.push('/job/$jobId');
            },
          );
        }

        if (status == 'completed') {
          if (role == JobBarRole.customer) {
            return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
              future: FirebaseFirestore.instance
                  .collection('reviews')
                  .where('jobId', isEqualTo: jobId)
                  .limit(10)
                  .get(),
              builder: (context, reviewSnap) {
                final alreadyReviewed = (reviewSnap.data?.docs ?? []).any((d) {
                  final r = d.data();
                  final customerId = (r['customerId'] as String?)?.trim() ?? '';
                  return customerId == uid;
                });

                if (alreadyReviewed) return const SizedBox.shrink();

                return _Bar(
                  title: 'Awaiting review',
                  subtitle: 'Leave a review to close this out.',
                  actionLabel: 'Review',
                  onPressed: () {
                    context.push('/job/$jobId');
                  },
                );
              },
            );
          }

          return _Bar(
            title: 'Awaiting review',
            subtitle: 'Customer review pending.',
            actionLabel: 'Open job',
            onPressed: () {
              context.push('/job/$jobId');
            },
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}

class _Bar extends StatelessWidget {
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onPressed;

  const _Bar({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.circle, size: 10, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.tonal(
                  onPressed: onPressed,
                  child: Text(actionLabel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
