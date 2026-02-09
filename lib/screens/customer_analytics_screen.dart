import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../widgets/skeleton_loader.dart';

class CustomerAnalyticsScreen extends StatefulWidget {
  const CustomerAnalyticsScreen({super.key});

  @override
  State<CustomerAnalyticsScreen> createState() =>
      _CustomerAnalyticsScreenState();
}

class _CustomerAnalyticsScreenState extends State<CustomerAnalyticsScreen> {
  String _selectedPeriod = '30'; // days
  bool _isLoading = true;

  Map<String, dynamic> _stats = {
    'totalJobs': 0,
    'completedJobs': 0,
    'totalSpent': 0.0,
    'averageJobCost': 0.0,
    'pendingJobs': 0,
  };

  List<Map<String, dynamic>> _spendingData = [];
  List<Map<String, String>> _favoriteContractors = [];
  Map<String, int> _serviceBreakdown = {};

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

      // Get all jobs for this customer
      final jobsSnapshot = await FirebaseFirestore.instance
          .collection('job_requests')
          .where('requesterUid', isEqualTo: user.uid)
          .get();

      // Filter by date in code since we can't use two inequality filters
      final filteredDocs = jobsSnapshot.docs.where((doc) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        return createdAt != null && createdAt.isAfter(cutoffDate);
      }).toList();

      int totalJobs = filteredDocs.length;
      int completedJobs = 0;
      int pendingJobs = 0;
      double totalSpent = 0.0;

      Map<String, double> spendingByDay = {};
      Map<String, int> contractorCounts = {};
      Map<String, int> serviceCounts = {};

      for (var doc in filteredDocs) {
        final data = doc.data();
        final status = data['status'] as String?;
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        final claimedBy = data['claimedBy'] as String?;
        final serviceType = data['service'] as String? ?? 'Other';

        // Count by service type
        serviceCounts[serviceType] = (serviceCounts[serviceType] ?? 0) + 1;

        if (status == 'completed') {
          completedJobs++;
          final amount = (data['price'] as num?)?.toDouble() ?? 0.0;
          final tip = (data['tipAmount'] as num?)?.toDouble() ?? 0.0;
          final total = amount + tip;
          totalSpent += total;

          if (createdAt != null) {
            final dateKey = DateFormat('MM/dd').format(createdAt);
            spendingByDay[dateKey] = (spendingByDay[dateKey] ?? 0.0) + total;
          }

          // Count jobs per contractor
          if (claimedBy != null && claimedBy.trim().isNotEmpty) {
            contractorCounts[claimedBy] =
                (contractorCounts[claimedBy] ?? 0) + 1;
          }
        } else if (status == 'pending' || status == 'in_progress') {
          pendingJobs++;
        }
      }

      // Get top 3 contractors
      final sortedContractors = contractorCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final favoriteContractors = <Map<String, String>>[];
      for (var entry in sortedContractors.take(3)) {
        try {
          final contractorDoc = await FirebaseFirestore.instance
              .collection('contractors')
              .doc(entry.key)
              .get();

          if (contractorDoc.exists) {
            final data = contractorDoc.data()!;
            favoriteContractors.add({
              'name': data['name'] as String? ?? 'Unknown',
              'count': entry.value.toString(),
            });
          }
        } catch (e) {
          debugPrint('Error loading contractor: $e');
        }
      }

      // Sort and prepare chart data
      final sortedDates = spendingByDay.keys.toList()..sort();
      final spendingData = sortedDates
          .map((date) => {'date': date, 'amount': spendingByDay[date]!})
          .toList();

      setState(() {
        _stats = {
          'totalJobs': totalJobs,
          'completedJobs': completedJobs,
          'totalSpent': totalSpent,
          'averageJobCost': completedJobs > 0
              ? (totalSpent / completedJobs)
              : 0.0,
          'pendingJobs': pendingJobs,
        };
        _spendingData = spendingData;
        _favoriteContractors = favoriteContractors;
        _serviceBreakdown = serviceCounts;
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
        title: const Text('My Analytics'),
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
                  height: 180,
                  borderRadius: BorderRadius.circular(12),
                ),
                const SizedBox(height: 24),
                SkeletonLoader(
                  width: 180,
                  height: 18,
                  borderRadius: BorderRadius.circular(6),
                ),
                const SizedBox(height: 12),
                SkeletonLoader(
                  width: double.infinity,
                  height: 140,
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

                  // Spending Chart
                  Text(
                    'Spending Trend',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _buildSpendingChart(),
                  const SizedBox(height: 24),

                  // Service Breakdown
                  Text(
                    'Services Used',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _buildServiceBreakdown(),
                  const SizedBox(height: 24),

                  // Favorite Contractors
                  if (_favoriteContractors.isNotEmpty) ...[
                    Text(
                      'Favorite Contractors',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    _buildFavoriteContractors(),
                  ],
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
          Icons.work_outline,
          Colors.blue,
        ),
        _buildStatCard(
          'Completed',
          _stats['completedJobs'].toString(),
          Icons.check_circle_outline,
          Colors.green,
        ),
        _buildStatCard(
          'Total Spent',
          '\$${_stats['totalSpent'].toStringAsFixed(2)}',
          Icons.payments_outlined,
          Colors.orange,
        ),
        _buildStatCard(
          'Avg Cost',
          '\$${_stats['averageJobCost'].toStringAsFixed(2)}',
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
            Icon(icon, color: color, size: 24),
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

  Widget _buildSpendingChart() {
    if (_spendingData.isEmpty) {
      return Card(
        child: Container(
          height: 200,
          alignment: Alignment.center,
          child: Text(
            'No spending data available',
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
                      if (index >= 0 && index < _spendingData.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _spendingData[index]['date'],
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
                  spots: _spendingData
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

  Widget _buildServiceBreakdown() {
    if (_serviceBreakdown.isEmpty) {
      return Card(
        child: Container(
          height: 200,
          alignment: Alignment.center,
          child: Text(
            'No service data available',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final sortedServices = _serviceBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sections: sortedServices.map((entry) {
                final total = _serviceBreakdown.values.reduce((a, b) => a + b);
                final percentage = (entry.value / total * 100).toStringAsFixed(
                  1,
                );
                return PieChartSectionData(
                  value: entry.value.toDouble(),
                  title: '$percentage%',
                  color: _getServiceColor(entry.key),
                  radius: 60,
                  titleStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              }).toList(),
              sectionsSpace: 2,
              centerSpaceRadius: 40,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFavoriteContractors() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: _favoriteContractors.map((contractor) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: Text(
                          contractor['name']![0].toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        contractor['name']!,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  Chip(
                    label: Text('${contractor['count']} jobs'),
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Color _getServiceColor(String service) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.amber,
      Colors.indigo,
      Colors.pink,
    ];
    return colors[service.hashCode % colors.length];
  }
}
