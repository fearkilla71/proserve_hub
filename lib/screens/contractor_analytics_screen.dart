import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../widgets/skeleton_loader.dart';
import '../theme/semantic_colors.dart';

class ContractorAnalyticsScreen extends StatefulWidget {
  const ContractorAnalyticsScreen({super.key});

  @override
  State<ContractorAnalyticsScreen> createState() =>
      _ContractorAnalyticsScreenState();
}

class _ContractorAnalyticsScreenState extends State<ContractorAnalyticsScreen> {
  String _selectedPeriod = '30'; // days
  bool _isLoading = true;
  String? _error;

  Map<String, dynamic> _stats = {
    'totalJobs': 0,
    'completedJobs': 0,
    'totalEarnings': 0.0,
    'totalExpenses': 0.0,
    'profitMargin': 0.0,
    'conversionRate': 0.0,
    'averageRating': 0.0,
    'totalReviews': 0,
    'completionRate': 0.0,
  };

  // Previous-period stats for comparison.
  Map<String, dynamic> _prevStats = {};

  List<Map<String, dynamic>> _earningsData = [];
  List<Map<String, dynamic>> _jobsData = [];

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final days = int.parse(_selectedPeriod);
      final now = DateTime.now();
      final cutoffDate = now.subtract(Duration(days: days));
      final prevCutoffDate = cutoffDate.subtract(Duration(days: days));

      // Current period jobs.
      final jobsSnapshot = await FirebaseFirestore.instance
          .collection('job_requests')
          .where('claimedBy', isEqualTo: user.uid)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(cutoffDate))
          .get();

      // Previous period jobs (for comparison).
      final prevJobsSnapshot = await FirebaseFirestore.instance
          .collection('job_requests')
          .where('claimedBy', isEqualTo: user.uid)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(prevCutoffDate))
          .where(
            'createdAt',
            isLessThanOrEqualTo: Timestamp.fromDate(cutoffDate),
          )
          .get();

      // Expenses for the current period.
      double totalExpenses = 0.0;
      try {
        final expensesSnap = await FirebaseFirestore.instance
            .collection('contractors')
            .doc(user.uid)
            .collection('expenses')
            .where('date', isGreaterThan: Timestamp.fromDate(cutoffDate))
            .get();
        for (final doc in expensesSnap.docs) {
          totalExpenses += (doc.data()['amount'] as num?)?.toDouble() ?? 0.0;
        }
      } catch (e) {
        debugPrint('Expenses fetch skipped: $e');
      }

      // Quotes sent (for conversion rate).
      int quotesSent = 0;
      int quotesAccepted = 0;
      try {
        final quotesSnap = await FirebaseFirestore.instance
            .collection('contractors')
            .doc(user.uid)
            .collection('quotes')
            .where('createdAt', isGreaterThan: Timestamp.fromDate(cutoffDate))
            .get();
        quotesSent = quotesSnap.docs.length;
        quotesAccepted = quotesSnap.docs
            .where((d) => d.data()['status'] == 'accepted')
            .length;
      } catch (e) {
        debugPrint('Quotes fetch skipped: $e');
      }

      final filteredDocs = jobsSnapshot.docs;

      int totalJobs = filteredDocs.length;
      int completedJobs = 0;
      double totalEarnings = 0.0;

      Map<String, double> earningsByDay = {};
      Map<String, int> jobsByDay = {};

      for (var doc in filteredDocs) {
        final data = doc.data();
        final status = data['status'] as String?;
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

        if (createdAt != null) {
          final dateKey = DateFormat('MM/dd').format(createdAt);
          jobsByDay[dateKey] = (jobsByDay[dateKey] ?? 0) + 1;

          if (status == 'completed') {
            completedJobs++;
            final amount = (data['price'] as num?)?.toDouble() ?? 0.0;
            final tip = (data['tipAmount'] as num?)?.toDouble() ?? 0.0;
            final total = amount + tip;
            totalEarnings += total;
            earningsByDay[dateKey] = (earningsByDay[dateKey] ?? 0.0) + total;
          }
        }
      }

      // Previous period stats.
      int prevTotalJobs = prevJobsSnapshot.docs.length;
      int prevCompletedJobs = 0;
      double prevTotalEarnings = 0.0;
      for (var doc in prevJobsSnapshot.docs) {
        final data = doc.data();
        if (data['status'] == 'completed') {
          prevCompletedJobs++;
          final amount = (data['price'] as num?)?.toDouble() ?? 0.0;
          final tip = (data['tipAmount'] as num?)?.toDouble() ?? 0.0;
          prevTotalEarnings += amount + tip;
        }
      }

      // Get contractor profile for rating
      final contractorDoc = await FirebaseFirestore.instance
          .collection('contractors')
          .doc(user.uid)
          .get();

      double averageRating = 0.0;
      int totalReviews = 0;

      if (contractorDoc.exists) {
        final data = contractorDoc.data()!;
        averageRating = (data['averageRating'] as num?)?.toDouble() ?? 0.0;
        totalReviews = (data['reviewCount'] as num?)?.toInt() ?? 0;
      }

      // Sort and prepare chart data
      final sortedDates = earningsByDay.keys.toList()..sort();
      final earningsData = sortedDates
          .map((date) => {'date': date, 'amount': earningsByDay[date]!})
          .toList();

      final sortedJobDates = jobsByDay.keys.toList()..sort();
      final jobsData = sortedJobDates
          .map((date) => {'date': date, 'count': jobsByDay[date]!})
          .toList();

      final profitMargin = totalEarnings > 0
          ? ((totalEarnings - totalExpenses) / totalEarnings * 100)
          : 0.0;
      final conversionRate = quotesSent > 0
          ? (quotesAccepted / quotesSent * 100)
          : 0.0;

      setState(() {
        _stats = {
          'totalJobs': totalJobs,
          'completedJobs': completedJobs,
          'totalEarnings': totalEarnings,
          'totalExpenses': totalExpenses,
          'profitMargin': profitMargin,
          'conversionRate': conversionRate,
          'averageRating': averageRating,
          'totalReviews': totalReviews,
          'completionRate': totalJobs > 0
              ? (completedJobs / totalJobs * 100)
              : 0.0,
        };
        _prevStats = {
          'totalJobs': prevTotalJobs,
          'completedJobs': prevCompletedJobs,
          'totalEarnings': prevTotalEarnings,
          'completionRate': prevTotalJobs > 0
              ? (prevCompletedJobs / prevTotalJobs * 100)
              : 0.0,
        };
        _earningsData = earningsData;
        _jobsData = jobsData;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading analytics: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load analytics. Pull to refresh.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          PopupMenuButton<String>(
            initialValue: _selectedPeriod,
            onSelected: (value) {
              setState(() => _selectedPeriod = value);
              _loadAnalytics();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: '7', child: Text('Last 7 days')),
              const PopupMenuItem(value: '30', child: Text('Last 30 days')),
              const PopupMenuItem(value: '90', child: Text('Last 90 days')),
              const PopupMenuItem(value: '365', child: Text('Last year')),
            ],
            icon: const Icon(Icons.filter_list),
          ),
        ],
      ),
      body: _isLoading
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: [
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.5,
                  children: List.generate(
                    4,
                    (_) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SkeletonLoader(
                              width: 120,
                              height: 12,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            const SizedBox(height: 10),
                            SkeletonLoader(
                              width: 80,
                              height: 22,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SkeletonLoader(
                  width: 160,
                  height: 18,
                  borderRadius: BorderRadius.circular(6),
                ),
                const SizedBox(height: 12),
                SkeletonLoader(
                  width: double.infinity,
                  height: 200,
                  borderRadius: BorderRadius.circular(12),
                ),
                const SizedBox(height: 24),
                SkeletonLoader(
                  width: 140,
                  height: 18,
                  borderRadius: BorderRadius.circular(6),
                ),
                const SizedBox(height: 12),
                SkeletonLoader(
                  width: double.infinity,
                  height: 200,
                  borderRadius: BorderRadius.circular(12),
                ),
                const SizedBox(height: 24),
                SkeletonLoader(
                  width: double.infinity,
                  height: 120,
                  borderRadius: BorderRadius.circular(12),
                ),
              ],
            )
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 12),
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () {
                      setState(() => _error = null);
                      _loadAnalytics();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadAnalytics,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Stats Cards
                  _buildStatsGrid(),
                  const SizedBox(height: 24),

                  // Earnings Chart
                  Text(
                    'Earnings Trend',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _buildEarningsChart(),
                  const SizedBox(height: 24),

                  // Jobs Chart
                  Text(
                    'Jobs Trend',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _buildJobsChart(),
                  const SizedBox(height: 24),

                  // Performance Card
                  _buildPerformanceCard(),

                  const SizedBox(height: 24),

                  // Profit Breakdown
                  _buildProfitBreakdownCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsGrid() {
    final cs = Theme.of(context).colorScheme;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.3,
      children: [
        _buildStatCard(
          'Total Jobs',
          _stats['totalJobs'].toString(),
          Icons.work,
          cs.info,
          prevValue: _prevStats['totalJobs'],
        ),
        _buildStatCard(
          'Completed',
          _stats['completedJobs'].toString(),
          Icons.check_circle,
          cs.success,
          prevValue: _prevStats['completedJobs'],
        ),
        _buildStatCard(
          'Revenue',
          '\$${_stats['totalEarnings'].toStringAsFixed(0)}',
          Icons.attach_money,
          cs.warning,
          prevValue: _prevStats['totalEarnings'],
          isCurrency: true,
        ),
        _buildStatCard(
          'Expenses',
          '\$${_stats['totalExpenses'].toStringAsFixed(0)}',
          Icons.receipt_long,
          cs.danger,
        ),
        _buildStatCard(
          'Profit Margin',
          '${_stats['profitMargin'].toStringAsFixed(1)}%',
          Icons.trending_up,
          _stats['profitMargin'] >= 30 ? cs.success : cs.warning,
        ),
        _buildStatCard(
          'Conversion Rate',
          '${_stats['conversionRate'].toStringAsFixed(1)}%',
          Icons.swap_horiz,
          _stats['conversionRate'] >= 50 ? cs.success : cs.warning,
        ),
        _buildStatCard(
          'Completion Rate',
          '${_stats['completionRate'].toStringAsFixed(1)}%',
          Icons.task_alt,
          cs.tertiary,
          prevValue: _prevStats['completionRate'],
        ),
        _buildStatCard(
          'Avg Rating',
          '${_stats['averageRating'].toStringAsFixed(1)} ⭐',
          Icons.star,
          _stats['averageRating'] >= 4.5 ? cs.success : cs.warning,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    dynamic prevValue,
    bool isCurrency = false,
  }) {
    // Calculate period-over-period change.
    String? changeText;
    Color? changeColor;
    if (prevValue != null) {
      final current =
          _stats[title == 'Revenue'
              ? 'totalEarnings'
              : title == 'Total Jobs'
              ? 'totalJobs'
              : title == 'Completed'
              ? 'completedJobs'
              : 'completionRate'] ??
          0;
      final prev = (prevValue is num) ? prevValue.toDouble() : 0.0;
      final curr = (current is num) ? current.toDouble() : 0.0;
      if (prev > 0) {
        final pctChange = ((curr - prev) / prev * 100);
        changeText =
            '${pctChange >= 0 ? '+' : ''}${pctChange.toStringAsFixed(0)}%';
        changeColor = pctChange >= 0
            ? Theme.of(context).colorScheme.success
            : Theme.of(context).colorScheme.danger;
      } else if (curr > 0) {
        changeText = 'New';
        changeColor = Theme.of(context).colorScheme.success;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 24),
                if (changeText != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: changeColor!.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      changeText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: changeColor,
                      ),
                    ),
                  )
                else
                  const SizedBox.shrink(),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Chart helpers ──────────────────────────────────────

  Widget _emptyChartCard(String message) {
    return Card(
      child: Container(
        height: 200,
        alignment: Alignment.center,
        child: Text(
          message,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _chartCard({required Widget chart}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(height: 200, child: chart),
      ),
    );
  }

  FlGridData _chartGrid() {
    return FlGridData(
      show: true,
      drawVerticalLine: false,
      getDrawingHorizontalLine: (value) {
        return FlLine(
          color: Theme.of(context).colorScheme.outlineVariant,
          strokeWidth: 1,
        );
      },
    );
  }

  FlTitlesData _chartTitles({
    required SideTitles leftTitles,
    required SideTitles bottomTitles,
  }) {
    return FlTitlesData(
      leftTitles: AxisTitles(sideTitles: leftTitles),
      bottomTitles: AxisTitles(sideTitles: bottomTitles),
      rightTitles: const AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
      topTitles: const AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
    );
  }

  TextStyle _axisTitleStyle() {
    return TextStyle(
      fontSize: 10,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }

  // ── Charts ────────────────────────────────────────────

  Widget _buildEarningsChart() {
    if (_earningsData.isEmpty) {
      return _emptyChartCard('No earnings data available');
    }

    return _chartCard(
      chart: LineChart(
        LineChartData(
          gridData: _chartGrid(),
          titlesData: _chartTitles(
            leftTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text('\$${value.toInt()}', style: _axisTitleStyle());
              },
            ),
            bottomTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < _earningsData.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _earningsData[index]['date'],
                      style: _axisTitleStyle(),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: _earningsData
                  .asMap()
                  .entries
                  .map(
                    (entry) =>
                        FlSpot(entry.key.toDouble(), entry.value['amount']),
                  )
                  .toList(),
              isCurved: true,
              color: Theme.of(context).colorScheme.warning,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: Theme.of(
                  context,
                ).colorScheme.warning.withValues(alpha: 0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobsChart() {
    if (_jobsData.isEmpty) {
      return _emptyChartCard('No jobs data available');
    }

    return _chartCard(
      chart: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY:
              (_jobsData
                          .map((e) => e['count'] as int)
                          .reduce((a, b) => a > b ? a : b) +
                      2)
                  .toDouble(),
          barTouchData: BarTouchData(enabled: true),
          titlesData: _chartTitles(
            leftTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: _axisTitleStyle(),
                );
              },
            ),
            bottomTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < _jobsData.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _jobsData[index]['date'],
                      style: _axisTitleStyle(),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          gridData: _chartGrid(),
          borderData: FlBorderData(show: false),
          barGroups: _jobsData
              .asMap()
              .entries
              .map(
                (entry) => BarChartGroupData(
                  x: entry.key,
                  barRods: [
                    BarChartRodData(
                      toY: entry.value['count'].toDouble(),
                      color: Theme.of(context).colorScheme.info,
                      width: 16,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(4),
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildPerformanceCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Performance Summary',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _buildPerformanceRow(
              'Average Rating',
              '${_stats['averageRating'].toStringAsFixed(1)} ⭐',
              _stats['averageRating'] >= 4.5
                  ? Theme.of(context).colorScheme.success
                  : Theme.of(context).colorScheme.warning,
            ),
            const Divider(height: 24),
            _buildPerformanceRow(
              'Total Reviews',
              _stats['totalReviews'].toString(),
              Theme.of(context).colorScheme.info,
            ),
            const Divider(height: 24),
            _buildPerformanceRow(
              'Completion Rate',
              '${_stats['completionRate'].toStringAsFixed(1)}%',
              _stats['completionRate'] >= 80
                  ? Theme.of(context).colorScheme.success
                  : Theme.of(context).colorScheme.warning,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfitBreakdownCard() {
    final revenue = (_stats['totalEarnings'] as num).toDouble();
    final expenses = (_stats['totalExpenses'] as num).toDouble();
    final profit = revenue - expenses;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Profit Breakdown',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _buildPerformanceRow(
              'Revenue',
              '\$${revenue.toStringAsFixed(2)}',
              Theme.of(context).colorScheme.success,
            ),
            const Divider(height: 24),
            _buildPerformanceRow(
              'Expenses',
              '- \$${expenses.toStringAsFixed(2)}',
              Theme.of(context).colorScheme.danger,
            ),
            const Divider(height: 24),
            _buildPerformanceRow(
              'Net Profit',
              '\$${profit.toStringAsFixed(2)}',
              profit >= 0
                  ? Theme.of(context).colorScheme.success
                  : Theme.of(context).colorScheme.danger,
            ),
            const Divider(height: 24),
            _buildPerformanceRow(
              'Margin',
              '${_stats['profitMargin'].toStringAsFixed(1)}%',
              _stats['profitMargin'] >= 30
                  ? Theme.of(context).colorScheme.success
                  : Theme.of(context).colorScheme.warning,
            ),
            if (_stats['conversionRate'] > 0) ...[
              const Divider(height: 24),
              _buildPerformanceRow(
                'Quote → Job',
                '${_stats['conversionRate'].toStringAsFixed(1)}%',
                _stats['conversionRate'] >= 50
                    ? Theme.of(context).colorScheme.success
                    : Theme.of(context).colorScheme.warning,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: color,
          ),
        ),
      ],
    );
  }
}
