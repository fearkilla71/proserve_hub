import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminActionHistoryCard extends StatelessWidget {
  const AdminActionHistoryCard({super.key, required this.parentRef});

  final DocumentReference<Map<String, dynamic>> parentRef;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: parentRef
          .collection('admin_actions')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(
            'Action history unavailable.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.error),
          );
        }

        final docs = snapshot.data?.docs ?? const [];
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.history, size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Action history',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (!snapshot.hasData)
                const LinearProgressIndicator()
              else if (docs.isEmpty)
                Text(
                  'No admin actions recorded yet.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                )
              else
                for (final doc in docs) ...[
                  _HistoryRow(data: doc.data()),
                  if (doc.id != docs.last.id) const Divider(height: 16),
                ],
            ],
          ),
        );
      },
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final createdAt = data['createdAt'] is Timestamp
        ? (data['createdAt'] as Timestamp).toDate()
        : null;
    final action = (data['action'] ?? 'admin_action').toString();
    final note = (data['note'] ?? '').toString().trim();
    final adminName = (data['adminName'] ?? 'Admin').toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          action.replaceAll('_', ' '),
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (note.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(note, style: Theme.of(context).textTheme.bodySmall),
        ],
        const SizedBox(height: 2),
        Text(
          [
            adminName,
            if (createdAt != null) DateFormat.MMMd().add_jm().format(createdAt),
          ].join(' • '),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
