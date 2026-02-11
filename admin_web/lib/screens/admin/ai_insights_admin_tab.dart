import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../theme/admin_theme.dart';
import '../../widgets/skeleton_loader.dart';

/// AI Insights tab — pricing accuracy, trends, confidence analysis,
/// service-level breakdowns, and smart recommendations.
class AiInsightsAdminTab extends StatefulWidget {
  const AiInsightsAdminTab({super.key});

  @override
  State<AiInsightsAdminTab> createState() => _AiInsightsAdminTabState();
}

class _AiInsightsAdminTabState extends State<AiInsightsAdminTab> {
  final _db = FirebaseFirestore.instance;
  final _currencyFmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  bool _loading = true;

  // Aggregate data
  double _avgRating = 0;
  int _totalRated = 0;
  Map<int, int> _ratingDistribution = {}; // 1-5 star counts
  double _avgPriceAccuracy = 0; // how close AI price is to market
  double _avgSavingsPercent = 0;
  double _avgDiscount = 0;
  double _totalRevenue = 0;

  // per-service breakdowns
  List<Map<String, dynamic>> _serviceBreakdowns = [];

  // Trend data (daily booking counts)
  List<Map<String, dynamic>> _dailyTrend = [];

  // Smart recommendations
  List<Map<String, dynamic>> _recommendations = [];

  @override
  void initState() {
    super.initState();
    _loadInsights();
  }

  Future<void> _loadInsights() async {
    setState(() => _loading = true);
    try {
      final snap = await _db
          .collection('escrow_bookings')
          .orderBy('createdAt', descending: true)
          .limit(500)
          .get();

      int totalRated = 0;
      double ratingSum = 0;
      final ratingDist = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
      double totalSavings = 0;
      double totalDiscount = 0;
      double totalAccuracy = 0;
      int accuracyCount = 0;
      double totalRev = 0;
      int discountCount = 0;

      final serviceMap = <String, _ServiceAgg>{};
      final dailyMap = <String, int>{};
      final savingsByService = <String, List<double>>{};

      for (final doc in snap.docs) {
        final d = doc.data();
        final status = d['status'] as String? ?? '';
        final service = d['service'] as String? ?? 'Unknown';
        final rating = (d['priceFairnessRating'] as num?)?.toInt();
        final aiPrice = (d['aiPrice'] as num?)?.toDouble() ?? 0;
        final marketPrice = (d['estimatedMarketPrice'] as num?)?.toDouble();
        final savingsPct = (d['savingsPercent'] as num?)?.toDouble();
        final discount = (d['discountPercent'] as num?)?.toDouble();
        final fee = (d['platformFee'] as num?)?.toDouble() ?? 0;
        final created = (d['createdAt'] as Timestamp?)?.toDate();

        // Rating aggregation
        if (rating != null && rating >= 1 && rating <= 5) {
          totalRated++;
          ratingSum += rating;
          ratingDist[rating] = (ratingDist[rating] ?? 0) + 1;
        }

        // Accuracy (how close AI price is to market)
        if (marketPrice != null && marketPrice > 0) {
          final accuracy = 1 - ((aiPrice - marketPrice).abs() / marketPrice);
          totalAccuracy += accuracy;
          accuracyCount++;
        }

        // Savings
        if (savingsPct != null) {
          totalSavings += savingsPct;
        }

        // Discount
        if (discount != null) {
          totalDiscount += discount;
          discountCount++;
        }

        // Revenue from active/released bookings
        if (status == 'funded' ||
            status == 'released' ||
            status == 'customerConfirmed' ||
            status == 'contractorConfirmed') {
          totalRev += fee;
        }

        // Service breakdowns
        serviceMap.putIfAbsent(service, () => _ServiceAgg());
        serviceMap[service]!.count++;
        serviceMap[service]!.totalPrice += aiPrice;
        if (rating != null) {
          serviceMap[service]!.ratingSum += rating;
          serviceMap[service]!.ratingCount++;
        }
        if (savingsPct != null) {
          savingsByService.putIfAbsent(service, () => []);
          savingsByService[service]!.add(savingsPct);
        }
        if (status == 'released') serviceMap[service]!.completed++;
        if (status == 'cancelled' || status == 'declined') {
          serviceMap[service]!.cancelled++;
        }

        // Daily trend
        if (created != null) {
          final dayKey = DateFormat('MM/dd').format(created);
          dailyMap[dayKey] = (dailyMap[dayKey] ?? 0) + 1;
        }
      }

      // Build service breakdowns list
      final breakdowns =
          serviceMap.entries.map((e) {
              final svc = e.key;
              final a = e.value;
              final avgPrice = a.count > 0 ? a.totalPrice / a.count : 0.0;
              final avgRating = a.ratingCount > 0
                  ? a.ratingSum / a.ratingCount
                  : 0.0;
              final avgSavings = (savingsByService[svc]?.isNotEmpty ?? false)
                  ? savingsByService[svc]!.reduce((a, b) => a + b) /
                        savingsByService[svc]!.length
                  : 0.0;
              return {
                'service': svc,
                'count': a.count,
                'avgPrice': avgPrice,
                'avgRating': avgRating,
                'ratingCount': a.ratingCount,
                'completed': a.completed,
                'cancelled': a.cancelled,
                'conversionRate': a.count > 0
                    ? (a.completed / a.count * 100)
                    : 0.0,
                'avgSavings': avgSavings,
              };
            }).toList()
            ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      // Daily trend sorted
      final sortedDays = dailyMap.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      final dailyTrend = sortedDays
          .map((e) => {'day': e.key, 'count': e.value})
          .toList();

      // Generate smart recommendations
      final recommendations = <Map<String, dynamic>>[];

      // Low-rated services
      for (final b in breakdowns) {
        final avgR = b['avgRating'] as double;
        if (avgR > 0 && avgR < 3.0 && (b['ratingCount'] as int) >= 3) {
          recommendations.add({
            'type': 'warning',
            'icon': Icons.warning_amber,
            'color': AdminColors.warning,
            'title': 'Low pricing satisfaction: ${b['service']}',
            'detail':
                'Avg rating ${avgR.toStringAsFixed(1)}/5 across ${b['ratingCount']} ratings. Consider recalibrating AI pricing for this service.',
          });
        }
      }

      // High cancellation services
      for (final b in breakdowns) {
        final cancelRate = (b['count'] as int) > 0
            ? ((b['cancelled'] as int) / (b['count'] as int)) * 100
            : 0.0;
        if (cancelRate > 30 && (b['count'] as int) >= 5) {
          recommendations.add({
            'type': 'alert',
            'icon': Icons.cancel,
            'color': AdminColors.error,
            'title': 'High cancellation: ${b['service']}',
            'detail':
                '${cancelRate.toStringAsFixed(0)}% cancellation rate. Review pricing or service expectations.',
          });
        }
      }

      // Pricing accuracy check
      final accuracy = accuracyCount > 0
          ? (totalAccuracy / accuracyCount * 100)
          : 0.0;
      if (accuracy > 0 && accuracy < 80) {
        recommendations.add({
          'type': 'insight',
          'icon': Icons.psychology,
          'color': AdminColors.accent3,
          'title': 'AI pricing accuracy below 80%',
          'detail':
              'Current accuracy: ${accuracy.toStringAsFixed(1)}%. Consider more training data or regional price adjustments.',
        });
      }

      // Top service suggestion
      if (breakdowns.isNotEmpty) {
        final top = breakdowns.first;
        recommendations.add({
          'type': 'success',
          'icon': Icons.trending_up,
          'color': AdminColors.accent,
          'title': 'Top service: ${top['service']}',
          'detail':
              '${top['count']} bookings with ${(top['conversionRate'] as double).toStringAsFixed(0)}% completion rate.',
        });
      }

      if (recommendations.isEmpty) {
        recommendations.add({
          'type': 'info',
          'icon': Icons.check_circle,
          'color': AdminColors.accent,
          'title': 'All systems healthy',
          'detail': 'AI pricing and escrow metrics are within normal ranges.',
        });
      }

      setState(() {
        _avgRating = totalRated > 0 ? ratingSum / totalRated : 0;
        _totalRated = totalRated;
        _ratingDistribution = ratingDist;
        _avgPriceAccuracy = accuracy;
        _avgSavingsPercent = snap.docs.isNotEmpty
            ? totalSavings / snap.docs.length
            : 0;
        _avgDiscount = discountCount > 0 ? totalDiscount / discountCount : 0;
        _totalRevenue = totalRev;
        _serviceBreakdowns = breakdowns;
        _dailyTrend = dailyTrend;
        _recommendations = recommendations;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading AI insights: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return _buildSkeleton();

    return RefreshIndicator(
      onRefresh: _loadInsights,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'AI Insights',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadInsights,
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── KPI Cards ──
          _buildKpiRow(),
          const SizedBox(height: 20),

          // ── Smart Recommendations ──
          _buildRecommendations(),
          const SizedBox(height: 20),

          // ── Rating Distribution ──
          _buildRatingChart(),
          const SizedBox(height: 20),

          // ── Booking Trend ──
          _buildTrendChart(),
          const SizedBox(height: 20),

          // ── Service Breakdown Table ──
          _buildServiceTable(),
        ],
      ),
    );
  }

  // ── KPI row ──

  Widget _buildKpiRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900 ? 5 : 3;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: crossAxisCount == 5 ? 1.8 : 2.0,
          children: [
            _kpiCard(
              'AI Rating',
              '${_avgRating.toStringAsFixed(1)}/5',
              Icons.star,
              AdminColors.warning,
              '$_totalRated rated',
            ),
            _kpiCard(
              'Price Accuracy',
              '${_avgPriceAccuracy.toStringAsFixed(1)}%',
              Icons.gps_fixed,
              AdminColors.accent,
              'vs market price',
            ),
            _kpiCard(
              'Avg Savings',
              '${_avgSavingsPercent.toStringAsFixed(1)}%',
              Icons.savings,
              const Color(0xFF4CAF50),
              'customer savings',
            ),
            _kpiCard(
              'Avg Discount',
              '${_avgDiscount.toStringAsFixed(1)}%',
              Icons.discount,
              AdminColors.accent3,
              'instant booking',
            ),
            _kpiCard(
              'Escrow Revenue',
              _currencyFmt.format(_totalRevenue),
              Icons.monetization_on,
              AdminColors.accent2,
              'platform fees',
            ),
          ],
        );
      },
    );
  }

  Widget _kpiCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String sub,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: AdminColors.ink,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                color: AdminColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              sub,
              style: TextStyle(
                color: AdminColors.muted.withValues(alpha: 0.5),
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Recommendations ──

  Widget _buildRecommendations() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: AdminColors.accent3, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Smart Recommendations',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._recommendations.map((r) {
              final icon = r['icon'] as IconData;
              final color = r['color'] as Color;
              final title = r['title'] as String;
              final detail = r['detail'] as String;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.15)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: color, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            detail,
                            style: TextStyle(
                              color: AdminColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ── Rating distribution chart ──

  Widget _buildRatingChart() {
    final maxCount = _ratingDistribution.values.fold<int>(
      0,
      (prev, v) => v > prev ? v : prev,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Price Fairness Rating Distribution',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: (maxCount + 2).toDouble(),
                  barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) {
                          final stars = v.toInt() + 1;
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '$stars★',
                              style: TextStyle(
                                color: AdminColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(5, (i) {
                    final count = _ratingDistribution[i + 1] ?? 0;
                    final colors = [
                      AdminColors.error,
                      AdminColors.warning,
                      AdminColors.accent2,
                      AdminColors.accent,
                      const Color(0xFF4CAF50),
                    ];
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: count.toDouble(),
                          color: colors[i],
                          width: 28,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Trend chart ──

  Widget _buildTrendChart() {
    if (_dailyTrend.isEmpty) return const SizedBox.shrink();

    final spots = _dailyTrend.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), (e.value['count'] as int).toDouble());
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Escrow Booking Trend',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) =>
                        FlLine(color: AdminColors.line, strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: (_dailyTrend.length / 6).ceilToDouble(),
                        getTitlesWidget: (v, _) {
                          final idx = v.toInt();
                          if (idx < 0 || idx >= _dailyTrend.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              _dailyTrend[idx]['day'] as String,
                              style: TextStyle(
                                color: AdminColors.muted,
                                fontSize: 9,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (v, _) => Text(
                          v.toInt().toString(),
                          style: TextStyle(
                            color: AdminColors.muted,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: AdminColors.accent,
                      barWidth: 2.5,
                      isStrokeCapRound: true,
                      dotData: FlDotData(show: spots.length < 20),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AdminColors.accent.withValues(alpha: 0.08),
                      ),
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

  // ── Service breakdown table ──

  Widget _buildServiceTable() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Service Breakdown',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(AdminColors.bgDeep),
                columnSpacing: 20,
                columns: const [
                  DataColumn(label: Text('Service')),
                  DataColumn(label: Text('Bookings'), numeric: true),
                  DataColumn(label: Text('Avg Price'), numeric: true),
                  DataColumn(label: Text('Avg Rating'), numeric: true),
                  DataColumn(label: Text('Completed'), numeric: true),
                  DataColumn(label: Text('Cancelled'), numeric: true),
                  DataColumn(label: Text('Conv %'), numeric: true),
                  DataColumn(label: Text('Avg Savings'), numeric: true),
                ],
                rows: _serviceBreakdowns.take(15).map((s) {
                  final avgR = s['avgRating'] as double;
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          s['service'] as String,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      DataCell(Text('${s['count']}')),
                      DataCell(
                        Text(_currencyFmt.format(s['avgPrice'] as double)),
                      ),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              avgR.toStringAsFixed(1),
                              style: TextStyle(
                                color: avgR >= 4
                                    ? AdminColors.accent
                                    : avgR >= 3
                                    ? AdminColors.warning
                                    : AdminColors.error,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.star,
                              size: 12,
                              color: avgR >= 4
                                  ? AdminColors.accent
                                  : avgR >= 3
                                  ? AdminColors.warning
                                  : AdminColors.error,
                            ),
                          ],
                        ),
                      ),
                      DataCell(Text('${s['completed']}')),
                      DataCell(
                        Text(
                          '${s['cancelled']}',
                          style: TextStyle(
                            color: (s['cancelled'] as int) > 0
                                ? AdminColors.error
                                : AdminColors.muted,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          '${(s['conversionRate'] as double).toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: (s['conversionRate'] as double) >= 50
                                ? AdminColors.accent
                                : AdminColors.warning,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          '${(s['avgSavings'] as double).toStringAsFixed(1)}%',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SkeletonLoader(
          width: 140,
          height: 24,
          borderRadius: BorderRadius.circular(6),
        ),
        const SizedBox(height: 20),
        GridView.count(
          crossAxisCount: 5,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.8,
          children: List.generate(
            5,
            (_) => SkeletonLoader(
              width: double.infinity,
              height: 80,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 20),
        SkeletonLoader(
          width: double.infinity,
          height: 200,
          borderRadius: BorderRadius.circular(12),
        ),
        const SizedBox(height: 20),
        SkeletonLoader(
          width: double.infinity,
          height: 200,
          borderRadius: BorderRadius.circular(12),
        ),
      ],
    );
  }
}

/// Helper class for per-service aggregation
class _ServiceAgg {
  int count = 0;
  double totalPrice = 0;
  double ratingSum = 0;
  int ratingCount = 0;
  int completed = 0;
  int cancelled = 0;
}
