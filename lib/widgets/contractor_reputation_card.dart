import 'package:flutter/material.dart';

/// Displays comprehensive reputation metrics for a contractor
class ContractorReputationCard extends StatelessWidget {
  final Map<String, dynamic> reputationData;
  final bool compact;

  const ContractorReputationCard({
    super.key,
    required this.reputationData,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final reliabilityScore =
        (reputationData['reliabilityScore'] as num?)?.toDouble() ?? 0.0;
    final completionRate =
        (reputationData['completionRate'] as num?)?.toDouble() ?? 0.0;
    final avgResponseTime =
        (reputationData['avgResponseTimeMinutes'] as num?)?.toInt() ?? 0;
    final repeatCustomerRate =
        (reputationData['repeatCustomerRate'] as num?)?.toDouble() ?? 0.0;
    final totalJobs =
        (reputationData['totalJobsCompleted'] as num?)?.toInt() ?? 0;
    final isTopPro = reputationData['topProBadge'] == true;

    if (compact) {
      return _buildCompactView(
        context,
        reliabilityScore,
        isTopPro,
        completionRate,
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Reputation',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (isTopPro) _buildTopProBadge(),
              ],
            ),
            const SizedBox(height: 16),
            _buildReliabilityScore(context, reliabilityScore),
            const Divider(height: 24),
            _buildMetricsGrid(
              context,
              completionRate,
              avgResponseTime,
              repeatCustomerRate,
              totalJobs,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactView(
    BuildContext context,
    double reliabilityScore,
    bool isTopPro,
    double completionRate,
  ) {
    return Row(
      children: [
        if (isTopPro) ...[
          _buildTopProBadge(small: true),
          const SizedBox(width: 8),
        ],
        Icon(
          Icons.verified,
          color: _getReliabilityColor(reliabilityScore),
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(
          reliabilityScore.toStringAsFixed(1),
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 12),
        Text(
          '${completionRate.toStringAsFixed(0)}% completion',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildReliabilityScore(BuildContext context, double score) {
    final scoreColor = _getReliabilityColor(score);
    final scoreLabel = _getReliabilityLabel(score);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Reliability Score',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message:
                        'Composite score based on completion rate, response time, and customer feedback',
                    child: Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    score.toStringAsFixed(1),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: scoreColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(' / 5.0'),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: scoreColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      scoreLabel,
                      style: TextStyle(
                        color: scoreColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: score / 5.0,
                backgroundColor: Colors.grey[200],
                color: scoreColor,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricsGrid(
    BuildContext context,
    double completionRate,
    int avgResponseTime,
    double repeatCustomerRate,
    int totalJobs,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricItem(
                context,
                icon: Icons.task_alt,
                label: 'Completion Rate',
                value: '${completionRate.toStringAsFixed(0)}%',
                color: completionRate >= 90
                    ? Colors.green
                    : completionRate >= 70
                    ? Colors.orange
                    : Colors.red,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricItem(
                context,
                icon: Icons.schedule,
                label: 'Avg Response Time',
                value: _formatResponseTime(avgResponseTime),
                color: avgResponseTime <= 60
                    ? Colors.green
                    : avgResponseTime <= 240
                    ? Colors.orange
                    : Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildMetricItem(
                context,
                icon: Icons.replay,
                label: 'Repeat Customers',
                value: '${repeatCustomerRate.toStringAsFixed(0)}%',
                color: repeatCustomerRate >= 40
                    ? Colors.green
                    : repeatCustomerRate >= 20
                    ? Colors.orange
                    : Colors.grey,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricItem(
                context,
                icon: Icons.work,
                label: 'Jobs Completed',
                value: totalJobs.toString(),
                color: Colors.blue,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopProBadge({bool small = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 6 : 8,
        vertical: small ? 2 : 4,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
        ),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.stars, size: small ? 12 : 16, color: Colors.white),
          SizedBox(width: small ? 2 : 4),
          Text(
            'TOP PRO',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: small ? 10 : 12,
            ),
          ),
        ],
      ),
    );
  }

  Color _getReliabilityColor(double score) {
    if (score >= 4.5) return Colors.green;
    if (score >= 3.5) return Colors.lightGreen;
    if (score >= 2.5) return Colors.orange;
    return Colors.red;
  }

  String _getReliabilityLabel(double score) {
    if (score >= 4.5) return 'Excellent';
    if (score >= 3.5) return 'Good';
    if (score >= 2.5) return 'Fair';
    return 'Needs Improvement';
  }

  String _formatResponseTime(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    if (hours < 24) return '${hours}h';
    final days = hours ~/ 24;
    return '${days}d';
  }
}
