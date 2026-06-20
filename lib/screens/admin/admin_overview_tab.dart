import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../constants/service_types.dart';

class AdminOverviewTab extends StatelessWidget {
  const AdminOverviewTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('job_requests').snapshots(),
      builder: (context, jobsSnap) {
        if (jobsSnap.hasError) {
          return _ErrorState(message: jobsSnap.error.toString());
        }
        if (!jobsSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('disputes').snapshots(),
          builder: (context, disputesSnap) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('escrow_bookings')
                  .snapshots(),
              builder: (context, escrowsSnap) {
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('payments')
                      .snapshots(),
                  builder: (context, paymentsSnap) {
                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('community_posts')
                          .where('reportCount', isGreaterThan: 0)
                          .snapshots(),
                      builder: (context, reportsSnap) {
                        final jobs = jobsSnap.data?.docs ?? const [];
                        final disputes = disputesSnap.data?.docs ?? const [];
                        final escrows = escrowsSnap.data?.docs ?? const [];
                        final payments = paymentsSnap.data?.docs ?? const [];
                        final reports = reportsSnap.data?.docs ?? const [];

                        final openJobs = jobs
                            .where((doc) => _status(doc.data()) == 'open')
                            .length;
                        final unclaimedJobs = jobs
                            .where((doc) => !_isClaimed(doc.data()))
                            .length;
                        final activeDisputes = disputes
                            .where((doc) => _isActiveDispute(doc.data()))
                            .length;
                        final escrowAlerts = escrows
                            .where((doc) => _escrowNeedsAttention(doc.data()))
                            .length;
                        final paymentAlerts = payments
                            .where((doc) => _paymentNeedsAttention(doc.data()))
                            .length;
                        final reportAlerts = reports.length;
                        final serviceDemand = _serviceDemand(jobs);

                        final issues =
                            <_OpsIssue>[
                              ...escrows
                                  .where(
                                    (doc) => _escrowNeedsAttention(doc.data()),
                                  )
                                  .take(4)
                                  .map(
                                    (doc) => _OpsIssue(
                                      icon: Icons.shield_outlined,
                                      title: 'Escrow needs attention',
                                      subtitle: _escrowSubtitle(
                                        doc.id,
                                        doc.data(),
                                      ),
                                      severity: _Severity.critical,
                                      onTap: () => context.push(
                                        '/escrow-status/${doc.id}',
                                      ),
                                    ),
                                  ),
                              ...disputes
                                  .where((doc) => _isActiveDispute(doc.data()))
                                  .take(4)
                                  .map(
                                    (doc) => _OpsIssue(
                                      icon: Icons.report_problem_outlined,
                                      title: 'Active dispute',
                                      subtitle: _disputeSubtitle(
                                        doc.id,
                                        doc.data(),
                                      ),
                                      severity: _Severity.high,
                                      onTap: () => context.push(
                                        '/dispute-detail/${doc.id}',
                                      ),
                                    ),
                                  ),
                              ...payments
                                  .where(
                                    (doc) => _paymentNeedsAttention(doc.data()),
                                  )
                                  .take(4)
                                  .map(
                                    (doc) => _OpsIssue(
                                      icon: Icons.receipt_long_outlined,
                                      title: 'Payment record needs review',
                                      subtitle: _paymentSubtitle(
                                        doc.id,
                                        doc.data(),
                                      ),
                                      severity: _Severity.high,
                                      onTap: null,
                                    ),
                                  ),
                              ...reports
                                  .take(4)
                                  .map(
                                    (doc) => _OpsIssue(
                                      icon: Icons.flag_outlined,
                                      title: 'Reported community post',
                                      subtitle: _reportSubtitle(
                                        doc.id,
                                        doc.data(),
                                      ),
                                      severity: _Severity.medium,
                                      onTap: null,
                                    ),
                                  ),
                            ]..sort(
                              (a, b) =>
                                  a.severity.index.compareTo(b.severity.index),
                            );

                        return ListView(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
                          children: [
                            _HeroCard(
                              criticalCount: escrowAlerts,
                              highCount: activeDisputes + paymentAlerts,
                              mediumCount: reportAlerts + unclaimedJobs,
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _MetricCard(
                                  label: 'Open jobs',
                                  value: openJobs.toString(),
                                  icon: Icons.work_outline,
                                ),
                                _MetricCard(
                                  label: 'Unclaimed',
                                  value: unclaimedJobs.toString(),
                                  icon: Icons.person_search_outlined,
                                ),
                                _MetricCard(
                                  label: 'Escrow alerts',
                                  value: escrowAlerts.toString(),
                                  icon: Icons.shield_outlined,
                                ),
                                _MetricCard(
                                  label: 'Payment alerts',
                                  value: paymentAlerts.toString(),
                                  icon: Icons.payments_outlined,
                                ),
                                _MetricCard(
                                  label: 'Disputes',
                                  value: activeDisputes.toString(),
                                  icon: Icons.report_problem_outlined,
                                ),
                                _MetricCard(
                                  label: 'Reports',
                                  value: reportAlerts.toString(),
                                  icon: Icons.flag_outlined,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _ServiceDemandCard(items: serviceDemand),
                            const SizedBox(height: 16),
                            Text(
                              'Operations queue',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 8),
                            if (issues.isEmpty)
                              const _EmptyState(
                                title: 'No urgent operational issues',
                                subtitle:
                                    'Payments, disputes, jobs, and reported content are quiet right now.',
                              )
                            else
                              ...issues
                                  .take(10)
                                  .map((issue) => _IssueCard(issue: issue)),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  static String _status(Map<String, dynamic> data) {
    final raw = (data['status'] ?? 'open').toString().trim().toLowerCase();
    return raw.isEmpty ? 'open' : raw;
  }

  static bool _isClaimed(Map<String, dynamic> data) {
    return data['claimed'] == true ||
        ((data['claimedBy'] ?? data['contractorId'] ?? '')
            .toString()
            .trim()
            .isNotEmpty);
  }

  static List<_ServiceDemand> _serviceDemand(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> jobs,
  ) {
    final counts = <String, ({int total, int unclaimed})>{};
    for (final doc in jobs) {
      final data = doc.data();
      final service = canonicalServiceName(
        (data['service'] ?? data['serviceType'] ?? 'Service').toString(),
      );
      final current = counts[service] ?? (total: 0, unclaimed: 0);
      counts[service] = (
        total: current.total + 1,
        unclaimed: current.unclaimed + (_isClaimed(data) ? 0 : 1),
      );
    }
    final items =
        counts.entries
            .map(
              (entry) => _ServiceDemand(
                service: entry.key,
                total: entry.value.total,
                unclaimed: entry.value.unclaimed,
              ),
            )
            .toList()
          ..sort((a, b) {
            final unclaimed = b.unclaimed.compareTo(a.unclaimed);
            if (unclaimed != 0) return unclaimed;
            return b.total.compareTo(a.total);
          });
    return items.take(6).toList();
  }

  static bool _isActiveDispute(Map<String, dynamic> data) {
    final status = (data['status'] ?? 'open').toString().trim().toLowerCase();
    return status == 'open' || status == 'under_review';
  }

  static bool _escrowNeedsAttention(Map<String, dynamic> data) {
    final status = (data['status'] ?? '').toString().toLowerCase();
    final payout = (data['payoutStatus'] ?? '').toString().toLowerCase();
    final error = (data['payoutError'] ?? '').toString().trim();
    final reviewed = data['adminReviewedAt'] != null;
    if (reviewed && !status.contains('failed') && error.isEmpty) return false;
    return status.contains('failed') ||
        status.contains('dispute') ||
        status.contains('refund') ||
        status == 'payoutpending' ||
        payout.contains('failed') ||
        error.isNotEmpty;
  }

  static bool _paymentNeedsAttention(Map<String, dynamic> data) {
    final status = (data['status'] ?? '').toString().toLowerCase();
    final error = (data['error'] ?? data['failureReason'] ?? '').toString();
    return status.contains('failed') ||
        status.contains('dispute') ||
        status.contains('refund') ||
        error.trim().isNotEmpty;
  }

  static String _escrowSubtitle(String id, Map<String, dynamic> data) {
    final service = (data['service'] ?? 'Escrow').toString();
    final status = (data['status'] ?? 'unknown').toString();
    final jobId = (data['jobId'] ?? '').toString();
    return '$service • $status${jobId.isEmpty ? '' : ' • job $jobId'}';
  }

  static String _disputeSubtitle(String id, Map<String, dynamic> data) {
    final category = (data['category'] ?? 'Dispute').toString();
    final status = (data['status'] ?? 'open').toString();
    final jobId = (data['jobId'] ?? '').toString();
    return '$category • $status${jobId.isEmpty ? '' : ' • job $jobId'}';
  }

  static String _paymentSubtitle(String id, Map<String, dynamic> data) {
    final status = (data['status'] ?? 'unknown').toString();
    final type = (data['type'] ?? 'payment').toString();
    return '$type • $status • $id';
  }

  static String _reportSubtitle(String id, Map<String, dynamic> data) {
    final reports = (data['reportCount'] as num?)?.toInt() ?? 0;
    final author = (data['authorName'] ?? 'Unknown author').toString();
    return '$reports reports • $author • $id';
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.criticalCount,
    required this.highCount,
    required this.mediumCount,
  });

  final int criticalCount;
  final int highCount;
  final int mediumCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasIssues = criticalCount + highCount + mediumCount > 0;
    return Card(
      color: hasIssues
          ? scheme.errorContainer.withValues(alpha: 0.55)
          : scheme.primaryContainer.withValues(alpha: 0.55),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasIssues
                      ? Icons.warning_amber_outlined
                      : Icons.verified_outlined,
                  color: hasIssues ? scheme.error : scheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hasIssues ? 'Admin attention needed' : 'Operations stable',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              hasIssues
                  ? 'Review critical payment, dispute, job, and moderation issues before widening beta.'
                  : 'No urgent marketplace operations are currently surfaced.',
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('$criticalCount critical')),
                Chip(label: Text('$highCount high')),
                Chip(label: Text('$mediumCount watch')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

class _IssueCard extends StatelessWidget {
  const _IssueCard({required this.issue});

  final _OpsIssue issue;

  @override
  Widget build(BuildContext context) {
    final color = switch (issue.severity) {
      _Severity.critical => Theme.of(context).colorScheme.error,
      _Severity.high => Colors.deepOrange,
      _Severity.medium => Colors.amber.shade800,
    };
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.14),
          child: Icon(issue.icon, color: color),
        ),
        title: Text(issue.title),
        subtitle: Text(issue.subtitle),
        trailing: issue.onTap == null ? null : const Icon(Icons.chevron_right),
        onTap: issue.onTap,
      ),
    );
  }
}

class _ServiceDemandCard extends StatelessWidget {
  const _ServiceDemandCard({required this.items});

  final List<_ServiceDemand> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.category_outlined, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Service demand',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Watch unclaimed demand so new service categories do not outrun contractor coverage.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const Text('No customer job requests yet.')
            else
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.service,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text('${item.total} total'),
                      ),
                      const SizedBox(width: 6),
                      Chip(
                        visualDensity: VisualDensity.compact,
                        backgroundColor: item.unclaimed > 0
                            ? scheme.errorContainer.withValues(alpha: 0.55)
                            : scheme.primaryContainer.withValues(alpha: 0.45),
                        label: Text('${item.unclaimed} unclaimed'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const Icon(Icons.check_circle_outline, size: 40),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(subtitle, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}

class _ServiceDemand {
  const _ServiceDemand({
    required this.service,
    required this.total,
    required this.unclaimed,
  });

  final String service;
  final int total;
  final int unclaimed;
}

class _OpsIssue {
  const _OpsIssue({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.severity,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final _Severity severity;
  final VoidCallback? onTap;
}

enum _Severity { critical, high, medium }
