import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../widgets/skeleton_loader.dart';

class AnalyticsAdminTab extends StatefulWidget {
  const AnalyticsAdminTab({super.key});

  @override
  State<AnalyticsAdminTab> createState() => _AnalyticsAdminTabState();
}

class _AnalyticsAdminTabState extends State<AnalyticsAdminTab> {
  String _selectedPeriod = '30'; // days
  bool _isLoading = true;

  Map<String, dynamic> _stats = {
    'totalUsers': 0,
    'totalContractors': 0,
    'totalCustomers': 0,
    'totalJobs': 0,
    'completedJobs': 0,
    'totalRevenue': 0.0,
    'pendingVerifications': 0,
    'activeDisputes': 0,
  };

  List<Map<String, dynamic>> _revenueData = [];
  List<Map<String, dynamic>> _userGrowthData = [];

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);

    try {
      final days = int.parse(_selectedPeriod);
      final cutoffDate = DateTime.now().subtract(Duration(days: days));

      // Get total users
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();
      final totalUsers = usersSnapshot.docs.length;

      // Get contractors
      final contractorsSnapshot = await FirebaseFirestore.instance
          .collection('contractors')
          .get();
      final totalContractors = contractorsSnapshot.docs.length;

      // Count pending verifications
      int pendingVerifications = 0;
      for (var doc in contractorsSnapshot.docs) {
        final data = doc.data();
        if (data['idVerification']?['status'] == 'pending' ||
            data['licenseVerification']?['status'] == 'pending' ||
            data['insuranceVerification']?['status'] == 'pending') {
          pendingVerifications++;
        }
      }

      // Get customers (users who are not contractors)
      final totalCustomers = totalUsers - totalContractors;

      // Get jobs
      final jobsSnapshot = await FirebaseFirestore.instance
          .collection('job_requests')
          .where('createdAt', isGreaterThan: cutoffDate)
          .get();

      int totalJobs = jobsSnapshot.docs.length;
      int completedJobs = 0;
      double totalRevenue = 0.0;

      Map<String, double> revenueByDay = {};
      Map<String, int> usersByDay = {};

      for (var doc in jobsSnapshot.docs) {
        final data = doc.data();
        final status = data['status'] as String?;
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

        if (createdAt != null) {
          final dateKey = DateFormat('MM/dd').format(createdAt);
          usersByDay[dateKey] = (usersByDay[dateKey] ?? 0) + 1;

          if (status == 'completed') {
            completedJobs++;
            final amount = (data['price'] as num?)?.toDouble() ?? 0.0;
            final tip = (data['tipAmount'] as num?)?.toDouble() ?? 0.0;
            final total = amount + tip;

            // Platform takes 7.5% commission
            final commission = total * 0.075;
            totalRevenue += commission;
            revenueByDay[dateKey] = (revenueByDay[dateKey] ?? 0.0) + commission;
          }
        }
      }

      // Get active disputes
      final disputesSnapshot = await FirebaseFirestore.instance
          .collection('disputes')
          .where('status', whereIn: ['open', 'under_review'])
          .get();
      final activeDisputes = disputesSnapshot.docs.length;

      // Sort and prepare chart data
      final sortedDates = revenueByDay.keys.toList()..sort();
      final revenueData = sortedDates
          .map((date) => {'date': date, 'amount': revenueByDay[date]!})
          .toList();

      final sortedUserDates = usersByDay.keys.toList()..sort();
      final userGrowthData = sortedUserDates
          .map((date) => {'date': date, 'count': usersByDay[date]!})
          .toList();

      setState(() {
        _stats = {
          'totalUsers': totalUsers,
          'totalContractors': totalContractors,
          'totalCustomers': totalCustomers,
          'totalJobs': totalJobs,
          'completedJobs': completedJobs,
          'totalRevenue': totalRevenue,
          'pendingVerifications': pendingVerifications,
          'activeDisputes': activeDisputes,
        };
        _revenueData = revenueData;
        _userGrowthData = userGrowthData;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading analytics: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SkeletonLoader(
                    width: 180,
                    height: 22,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  SkeletonLoader(
                    width: 90,
                    height: 36,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ],
              ),
              const SizedBox(height: 24),
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
                // Period Selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Platform Analytics',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    DropdownButton<String>(
                      value: _selectedPeriod,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedPeriod = value);
                          _loadAnalytics();
                        }
                      },
                      items: const [
                        DropdownMenuItem(value: '7', child: Text('7 days')),
                        DropdownMenuItem(value: '30', child: Text('30 days')),
                        DropdownMenuItem(value: '90', child: Text('90 days')),
                        DropdownMenuItem(value: '365', child: Text('1 year')),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Stats Grid
                _buildStatsGrid(),
                const SizedBox(height: 24),

                // Revenue Chart
                Text(
                  'Platform Revenue',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  '7.5% commission on completed jobs',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                _buildRevenueChart(),
                const SizedBox(height: 24),

                // User Growth Chart
                Text(
                  'Job Activity',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                _buildUserGrowthChart(),
                const SizedBox(height: 24),

                // Alerts Card
                _buildAlertsCard(),
              ],
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
          'Total Users',
          _stats['totalUsers'].toString(),
          Icons.people,
          Colors.blue,
        ),
        _buildStatCard(
          'Contractors',
          _stats['totalContractors'].toString(),
          Icons.construction,
          Colors.green,
        ),
        _buildStatCard(
          'Platform Revenue',
          '\$${_stats['totalRevenue'].toStringAsFixed(2)}',
          Icons.monetization_on,
          Colors.orange,
        ),
        _buildStatCard(
          'Completed Jobs',
          _stats['completedJobs'].toString(),
          Icons.check_circle,
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

  Widget _buildRevenueChart() {
    if (_revenueData.isEmpty) {
      return Card(
        child: Container(
          height: 200,
          alignment: Alignment.center,
          child: Text(
            'No revenue data available',
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
                      if (index >= 0 && index < _revenueData.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _revenueData[index]['date'],
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
                  spots: _revenueData
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

  Widget _buildUserGrowthChart() {
    if (_userGrowthData.isEmpty) {
      return Card(
        child: Container(
          height: 200,
          alignment: Alignment.center,
          child: Text(
            'No activity data available',
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
                  (_userGrowthData
                              .map((e) => e['count'] as int)
                              .reduce((a, b) => a > b ? a : b) +
                          2)
                      .toDouble(),
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
                      if (index >= 0 && index < _userGrowthData.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _userGrowthData[index]['date'],
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
              barGroups: _userGrowthData
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

  Widget _buildAlertsCard() {
    final alerts = <Map<String, dynamic>>[];

    if (_stats['pendingVerifications'] > 0) {
      alerts.add({
        'title': 'Pending Verifications',
        'count': _stats['pendingVerifications'],
        'icon': Icons.verified_user,
        'color': Colors.orange,
      });
    }

    if (_stats['activeDisputes'] > 0) {
      alerts.add({
        'title': 'Active Disputes',
        'count': _stats['activeDisputes'],
        'icon': Icons.report_problem,
        'color': Colors.red,
      });
    }

    if (alerts.isEmpty) {
      return Card(
        color: Colors.green.shade50,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 12),
              Text(
                'All caught up! No pending actions.',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Attention Required',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ...alerts.map(
              (alert) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(alert['icon'], color: alert['color']),
                    const SizedBox(width: 12),
                    Expanded(child: Text(alert['title'])),
                    Chip(
                      label: Text(alert['count'].toString()),
                      backgroundColor: alert['color'].withValues(alpha: 0.2),
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
