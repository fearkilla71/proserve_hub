import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../widgets/skeleton_loader.dart';

class ContractorAnalyticsScreen extends StatefulWidget {
  const ContractorAnalyticsScreen({super.key});

  @override
  State<ContractorAnalyticsScreen> createState() =>
      _ContractorAnalyticsScreenState();
}

class _ContractorAnalyticsScreenState extends State<ContractorAnalyticsScreen> {
  String _selectedPeriod = '30'; // days
  bool _isLoading = true;

  Map<String, dynamic> _stats = {
    'totalJobs': 0,
    'completedJobs': 0,
    'totalEarnings': 0.0,
    'averageRating': 0.0,
    'totalReviews': 0,
    'completionRate': 0.0,
  };

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
      final cutoffDate = DateTime.now().subtract(Duration(days: days));

      // Get all jobs for this contractor
      final jobsSnapshot = await FirebaseFirestore.instance
          .collection('job_requests')
          .where('claimedBy', isEqualTo: user.uid)
          .get();

      // Filter by date in code since we can't use two inequality filters
      final filteredDocs = jobsSnapshot.docs.where((doc) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        return createdAt != null && createdAt.isAfter(cutoffDate);
      }).toList();

      int totalJobs = filteredDocs.length;
      int completedJobs = 0;
      double totalEarnings = 0.0;

      // Calculate earnings by day
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

      setState(() {
        _stats = {
          'totalJobs': totalJobs,
          'completedJobs': completedJobs,
          'totalEarnings': totalEarnings,
          'averageRating': averageRating,
          'totalReviews': totalReviews,
          'completionRate': totalJobs > 0
              ? (completedJobs / totalJobs * 100)
              : 0.0,
        };
        _earningsData = earningsData;
        _jobsData = jobsData;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading analytics: $e');
      setState(() => _isLoading = false);
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
                ],
              ),
            ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          'Total Jobs',
          _stats['totalJobs'].toString(),
          Icons.work,
          Colors.blue,
        ),
        _buildStatCard(
          'Completed',
          _stats['completedJobs'].toString(),
          Icons.check_circle,
          Colors.green,
        ),
        _buildStatCard(
          'Total Earnings',
          '\$${_stats['totalEarnings'].toStringAsFixed(2)}',
          Icons.attach_money,
          Colors.orange,
        ),
        _buildStatCard(
          'Completion Rate',
          '${_stats['completionRate'].toStringAsFixed(1)}%',
          Icons.trending_up,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
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
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
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

  Widget _buildEarningsChart() {
    if (_earningsData.isEmpty) {
      return Card(
        child: Container(
          height: 200,
          alignment: Alignment.center,
          child: Text(
            'No earnings data available',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 1,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    strokeWidth: 1,
                  );
                },
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        '\$${value.toInt()}',
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index >= 0 && index < _earningsData.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _earningsData[index]['date'],
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
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
                  color: Colors.orange,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    color: Colors.orange.withValues(alpha: 0.2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildJobsChart() {
    if (_jobsData.isEmpty) {
      return Card(
        child: Container(
          height: 200,
          alignment: Alignment.center,
          child: Text(
            'No jobs data available',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY:
                  (_jobsData
                              .map((e) => e['count'] as int)
                              .reduce((a, b) => a > b ? a : b) +
                          2)
                      .toDouble(),
              barTouchData: BarTouchData(enabled: true),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toInt().toString(),
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index >= 0 && index < _jobsData.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _jobsData[index]['date'],
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    strokeWidth: 1,
                  );
                },
              ),
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
                          color: Colors.blue,
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
              _stats['averageRating'] >= 4.5 ? Colors.green : Colors.orange,
            ),
            const Divider(height: 24),
            _buildPerformanceRow(
              'Total Reviews',
              _stats['totalReviews'].toString(),
              Colors.blue,
            ),
            const Divider(height: 24),
            _buildPerformanceRow(
              'Completion Rate',
              '${_stats['completionRate'].toStringAsFixed(1)}%',
              _stats['completionRate'] >= 80 ? Colors.green : Colors.orange,
            ),
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
