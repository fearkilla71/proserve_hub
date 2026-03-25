import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Real-time Admin Alerts — Threshold-based anomaly monitoring
class AdminAlertsTab extends StatefulWidget {
  const AdminAlertsTab({super.key});

  @override
  State<AdminAlertsTab> createState() => _AdminAlertsTabState();
}

class _AdminAlertsTabState extends State<AdminAlertsTab> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        // ── Header ──
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Row(
            children: [
              Icon(Icons.notifications_active, color: cs.error, size: 28),
              const SizedBox(width: 12),
              Text(
                'Admin Alerts',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
              const Spacer(),
              _UnreadBadge(),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // ── Live alert thresholds ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _LiveThresholdIndicators(),
        ),
        const SizedBox(height: 12),

        // ── Alert history ──
        Expanded(child: _AlertHistory()),
      ],
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('admin_alerts')
          .where('read', isEqualTo: false)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return const SizedBox.shrink();
        final count = snap.data?.docs.length ?? 0;
        if (count == 0) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, size: 16, color: Colors.green),
                SizedBox(width: 6),
                Text(
                  'All clear',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          );
        }
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: cs.error.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber, size: 16, color: cs.error),
              const SizedBox(width: 6),
              Text(
                '$count unread alert${count > 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.error,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LiveThresholdIndicators extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90,
      child: Row(
        children: [
          // Payment failures (24h)
          Expanded(
            child: _ThresholdCard(
              icon: Icons.credit_card_off,
              label: 'Payment Failures (24h)',
              threshold: 5,
              stream: FirebaseFirestore.instance
                  .collection('payment_failures')
                  .orderBy('createdAt', descending: true)
                  .limit(100)
                  .snapshots(),
            ),
          ),
          const SizedBox(width: 12),
          // Error logs (24h)
          Expanded(
            child: _ThresholdCard(
              icon: Icons.bug_report_outlined,
              label: 'Error Logs (24h)',
              threshold: 20,
              stream: FirebaseFirestore.instance
                  .collection('error_logs')
                  .orderBy('timestamp', descending: true)
                  .limit(100)
                  .snapshots(),
            ),
          ),
          const SizedBox(width: 12),
          // Disputes
          Expanded(
            child: _ThresholdCard(
              icon: Icons.gavel,
              label: 'Open Disputes',
              threshold: 3,
              stream: FirebaseFirestore.instance
                  .collection('disputes')
                  .where('status', isEqualTo: 'open')
                  .snapshots(),
            ),
          ),
          const SizedBox(width: 12),
          // New signups
          Expanded(
            child: _ThresholdCard(
              icon: Icons.person_add_outlined,
              label: 'New Users (24h)',
              threshold: 0,
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .orderBy('createdAt', descending: true)
                  .limit(100)
                  .snapshots(),
              isInfoOnly: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThresholdCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int threshold;
  final Stream<QuerySnapshot> stream;
  final bool isInfoOnly;

  const _ThresholdCard({
    required this.icon,
    required this.label,
    required this.threshold,
    required this.stream,
    this.isInfoOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) return const SizedBox.shrink();
        final count = snap.data?.docs.length ?? 0;
        final breached = !isInfoOnly && count >= threshold && threshold > 0;
        final color = breached
            ? cs.error
            : isInfoOnly
            ? cs.primary
            : Colors.green;

        return Card(
          elevation: 1,
          color: breached ? cs.error.withValues(alpha: 0.08) : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurface.withValues(alpha: 0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (!isInfoOnly)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      breached ? 'ALERT' : 'OK',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AlertHistory extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = DateFormat('MMM d  h:mm a');

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('admin_alerts')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return const SizedBox.shrink();
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.notifications_none,
                  size: 64,
                  color: cs.onSurface.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 12),
                Text(
                  'No alerts yet',
                  style: TextStyle(
                    fontSize: 18,
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Alerts are auto-generated when thresholds are breached',
                  style: TextStyle(
                    fontSize: 14,
                    color: cs.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final d = docs[i].data();
            final severity = d['severity'] as String? ?? 'info';
            final title = d['title'] as String? ?? 'Alert';
            final message = d['message'] as String? ?? '';
            final isRead = d['read'] as bool? ?? false;
            final ts = d['createdAt'] as Timestamp?;
            final dateStr = ts != null ? fmt.format(ts.toDate()) : '';

            final color = _severityColor(severity);
            final icon = _severityIcon(severity);

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(icon, color: color, size: 20),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontWeight: isRead
                            ? FontWeight.normal
                            : FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      severity.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(message, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
              isThreeLine: true,
              trailing: !isRead
                  ? IconButton(
                      icon: const Icon(Icons.mark_email_read, size: 18),
                      tooltip: 'Mark read',
                      onPressed: () => docs[i].reference.update({'read': true}),
                    )
                  : null,
            );
          },
        );
      },
    );
  }

  Color _severityColor(String severity) {
    switch (severity) {
      case 'critical':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      case 'info':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _severityIcon(String severity) {
    switch (severity) {
      case 'critical':
        return Icons.error;
      case 'warning':
        return Icons.warning_amber;
      case 'info':
        return Icons.info_outline;
      default:
        return Icons.notifications;
    }
  }
}
