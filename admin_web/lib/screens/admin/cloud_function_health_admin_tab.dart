import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Cloud Function Health Admin Tab — Monitor function invocations, errors, latency
class CloudFunctionHealthAdminTab extends StatefulWidget {
  const CloudFunctionHealthAdminTab({super.key});

  @override
  State<CloudFunctionHealthAdminTab> createState() =>
      _CloudFunctionHealthAdminTabState();
}

class _CloudFunctionHealthAdminTabState
    extends State<CloudFunctionHealthAdminTab> {
  final _fmt = DateFormat('MMM d  h:mm a');

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('function_health')
          .orderBy('lastUpdated', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Could not load function health. Check admin permissions and try again.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];

        return Column(
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: [
                  Icon(Icons.cloud_outlined, color: cs.primary, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'Cloud Function Health',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                  const Spacer(),
                  _OverallStatus(docs: docs),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Function cards or recent errors ──
            Expanded(
              child: docs.isEmpty ? _buildEmptyState(cs) : _buildGrid(docs, cs),
            ),

            // ── Recent errors log ──
            _RecentFunctionErrors(),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_queue,
            size: 64,
            color: cs.primary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          Text(
            'No function health data yet',
            style: TextStyle(
              fontSize: 18,
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Health data is written by Cloud Functions on each invocation.\n'
            'Add a Firestore write to "function_health/{functionName}" from your functions.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: cs.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    ColorScheme cs,
  ) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 380,
        mainAxisExtent: 200,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: docs.length,
      itemBuilder: (context, i) {
        final d = docs[i].data();
        final name = docs[i].id;
        final invocations = d['invocations'] as int? ?? 0;
        final errors = d['errors'] as int? ?? 0;
        final avgMs = (d['avgDurationMs'] as num?)?.toDouble() ?? 0;
        final lastTs = d['lastUpdated'] as Timestamp?;
        final lastStr = lastTs != null ? _fmt.format(lastTs.toDate()) : '—';
        final errorRate = invocations > 0 ? (errors / invocations * 100) : 0.0;
        final status = _healthStatus(errorRate, avgMs);

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row
                Row(
                  children: [
                    Icon(status.icon, color: status.color, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 8),

                // Stats
                _stat('Invocations', '$invocations', cs),
                _stat(
                  'Errors',
                  '$errors',
                  cs,
                  valueColor: errors > 0 ? cs.error : null,
                ),
                _stat(
                  'Error Rate',
                  '${errorRate.toStringAsFixed(1)}%',
                  cs,
                  valueColor: errorRate > 5 ? cs.error : null,
                ),
                _stat(
                  'Avg Duration',
                  '${avgMs.toStringAsFixed(0)} ms',
                  cs,
                  valueColor: avgMs > 5000 ? Colors.orange : null,
                ),
                const Spacer(),
                Text(
                  'Updated: $lastStr',
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _stat(
    String label,
    String value,
    ColorScheme cs, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: valueColor ?? cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  _HealthStatus _healthStatus(double errorRate, double avgMs) {
    if (errorRate > 10) {
      return _HealthStatus(Icons.error, Colors.red);
    }
    if (errorRate > 5 || avgMs > 10000) {
      return _HealthStatus(Icons.warning_amber, Colors.orange);
    }
    return _HealthStatus(Icons.check_circle, Colors.green);
  }
}

class _HealthStatus {
  final IconData icon;
  final Color color;
  _HealthStatus(this.icon, this.color);
}

class _OverallStatus extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  const _OverallStatus({required this.docs});

  @override
  Widget build(BuildContext context) {
    int totalErrors = 0;
    int totalInvocations = 0;
    for (final doc in docs) {
      totalErrors += (doc.data()['errors'] as int?) ?? 0;
      totalInvocations += (doc.data()['invocations'] as int?) ?? 0;
    }
    final rate = totalInvocations > 0
        ? (totalErrors / totalInvocations * 100)
        : 0.0;
    final healthy = rate < 5;
    final color = healthy ? Colors.green : Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            healthy ? Icons.check_circle : Icons.warning_amber,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            '${docs.length} functions · ${rate.toStringAsFixed(1)}% errors',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentFunctionErrors extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = DateFormat('MMM d  h:mm a');

    return Container(
      height: 200,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
            child: Text(
              'Recent Function Errors',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: cs.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('function_errors')
                  .orderBy('timestamp', descending: true)
                  .limit(20)
                  .snapshots(),
              builder: (context, snap) {
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      'No recent errors',
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final d = docs[i].data();
                    final fn = d['functionName'] as String? ?? '?';
                    final msg = d['message'] as String? ?? '';
                    final ts = d['timestamp'] as Timestamp?;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, size: 14, color: cs.error),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 180,
                            child: Text(
                              fn,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'monospace',
                                color: cs.onSurface,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              msg,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            ts != null ? fmt.format(ts.toDate()) : '',
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurface.withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
