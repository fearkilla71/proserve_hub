import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../widgets/skeleton_loader.dart';

/// ---------------------------------------------------------------------------
/// Revenue Admin Tab — Real-time financial dashboard
/// ---------------------------------------------------------------------------
class RevenueAdminTab extends StatefulWidget {
  const RevenueAdminTab({super.key});

  @override
  State<RevenueAdminTab> createState() => _RevenueAdminTabState();
}

class _RevenueAdminTabState extends State<RevenueAdminTab> {
  StreamSubscription? _escrowSub;
  StreamSubscription? _usersSub;
  bool _loading = true;
  int _periodDays = 30;

  // Financial data
  List<Map<String, dynamic>> _escrows = [];
  int _proCount = 0;
  int _enterpriseCount = 0;

  // Computed KPIs
  double _totalEscrowVolume = 0;
  double _totalPlatformFees = 0;
  double _totalContractorPayouts = 0;
  double _totalCustomerSavings = 0;
  double _subscriptionMrr = 0;
  double _totalRevenue = 0;
  int _completedBookings = 0;
  int _cancelledBookings = 0;
  double _avgBookingValue = 0;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void dispose() {
    _escrowSub?.cancel();
    _usersSub?.cancel();
    super.dispose();
  }

  void _listen() {
    // Escrow bookings — real-time
    _escrowSub = FirebaseFirestore.instance
        .collection('escrow_bookings')
        .snapshots()
        .listen((snap) {
          _escrows = snap.docs.map((d) {
            final data = d.data();
            data['id'] = d.id;
            return data;
          }).toList();
          _recalculate();
        });

    // Users — for subscription counts
    _usersSub = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'contractor')
        .snapshots()
        .listen((snap) {
          int pro = 0, enterprise = 0;
          for (final d in snap.docs) {
            final data = d.data();
            final tier = _effectiveTier(data);
            if (tier == 'enterprise') {
              enterprise++;
            } else if (tier == 'pro') {
              pro++;
            }
          }
          _proCount = pro;
          _enterpriseCount = enterprise;
          _recalculate();
        });
  }

  String _effectiveTier(Map<String, dynamic> data) {
    final tier = (data['subscriptionTier'] as String?)?.toLowerCase();
    if (tier == 'enterprise') return 'enterprise';
    if (tier == 'pro') return 'pro';
    if (data['pricingToolsPro'] == true ||
        data['contractorPro'] == true ||
        data['isPro'] == true) {
      return 'pro';
    }
    return 'basic';
  }

  void _recalculate() {
    final cutoff = DateTime.now().subtract(Duration(days: _periodDays));

    final periodEscrows = _escrows.where((e) {
      final created = e['createdAt'];
      if (created is Timestamp) {
        return created.toDate().isAfter(cutoff);
      }
      return false;
    }).toList();

    double volume = 0, fees = 0, payouts = 0, savings = 0;
    int completed = 0, cancelled = 0;

    for (final e in periodEscrows) {
      final status = (e['status'] ?? '').toString().toLowerCase();
      final price = (e['agreedPrice'] ?? e['finalPrice'] ?? 0).toDouble();
      final fee = (e['platformFee'] ?? 0).toDouble();
      final payout = (e['contractorPayout'] ?? 0).toDouble();
      final marketPrice = (e['marketPrice'] ?? 0).toDouble();
      final saving = marketPrice > price ? marketPrice - price : 0.0;

      volume += price;
      fees += fee;
      payouts += payout;
      savings += saving;

      if (status == 'released' || status == 'completed') completed++;
      if (status == 'cancelled' || status == 'refunded') cancelled++;
    }

    final mrr = (_proCount * 11.99) + (_enterpriseCount * 29.99);
    final totalRev = fees + mrr;

    setState(() {
      _totalEscrowVolume = volume;
      _totalPlatformFees = fees;
      _totalContractorPayouts = payouts;
      _totalCustomerSavings = savings;
      _subscriptionMrr = mrr;
      _totalRevenue = totalRev;
      _completedBookings = completed;
      _cancelledBookings = cancelled;
      _avgBookingValue = periodEscrows.isNotEmpty
          ? volume / periodEscrows.length
          : 0;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            ListTileSkeleton(),
            SizedBox(height: 12),
            ListTileSkeleton(),
            SizedBox(height: 12),
            ListTileSkeleton(),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ── Period selector ──────────────────────────────────────
        Row(
          children: [
            Text(
              'Revenue Dashboard',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const Spacer(),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 7, label: Text('7d')),
                ButtonSegment(value: 30, label: Text('30d')),
                ButtonSegment(value: 90, label: Text('90d')),
                ButtonSegment(value: 365, label: Text('1y')),
              ],
              selected: {_periodDays},
              onSelectionChanged: (v) {
                setState(() => _periodDays = v.first);
                _recalculate();
              },
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ── Total Revenue Hero Card ─────────────────────────────
        Card(
          color: Colors.green.withValues(alpha: 0.15),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(
                  Icons.account_balance_wallet,
                  size: 40,
                  color: Colors.greenAccent,
                ),
                const SizedBox(height: 8),
                Text(
                  '\$${_totalRevenue.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.greenAccent,
                  ),
                ),
                Text(
                  'Total Revenue (${_periodDays}d)',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 4),
                Text(
                  'Platform Fees: \$${_totalPlatformFees.toStringAsFixed(2)}  ·  '
                  'Subscription MRR: \$${_subscriptionMrr.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // ── KPI Grid ─────────────────────────────────────────────
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _kpiCard(
              'Escrow Volume',
              '\$${_fmt(_totalEscrowVolume)}',
              Icons.account_balance,
              Colors.blue,
            ),
            _kpiCard(
              'Platform Fees',
              '\$${_fmt(_totalPlatformFees)}',
              Icons.percent,
              Colors.green,
            ),
            _kpiCard(
              'Contractor Payouts',
              '\$${_fmt(_totalContractorPayouts)}',
              Icons.payments,
              Colors.orange,
            ),
            _kpiCard(
              'Customer Savings',
              '\$${_fmt(_totalCustomerSavings)}',
              Icons.savings,
              Colors.teal,
            ),
            _kpiCard(
              'Completed',
              '$_completedBookings',
              Icons.check_circle,
              Colors.green,
            ),
            _kpiCard(
              'Cancelled',
              '$_cancelledBookings',
              Icons.cancel,
              Colors.red,
            ),
            _kpiCard(
              'Avg Booking',
              '\$${_fmt(_avgBookingValue)}',
              Icons.receipt_long,
              Colors.purple,
            ),
            _kpiCard(
              'Sub MRR',
              '\$${_fmt(_subscriptionMrr)}',
              Icons.autorenew,
              Colors.amber,
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ── Revenue Trend Chart ──────────────────────────────────
        Text('Revenue Trend', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        SizedBox(height: 250, child: _buildRevenueTrendChart()),
        const SizedBox(height: 24),

        // ── Revenue Sources Breakdown ────────────────────────────
        Text('Revenue Sources', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: Row(
            children: [
              Expanded(
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 30,
                    sections: [
                      PieChartSectionData(
                        value: _totalPlatformFees,
                        color: Colors.green,
                        title:
                            'Fees\n\$${_totalPlatformFees.toStringAsFixed(0)}',
                        titleStyle: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        radius: 55,
                      ),
                      PieChartSectionData(
                        value: _subscriptionMrr > 0 ? _subscriptionMrr : 0.01,
                        color: Colors.amber,
                        title: 'Subs\n\$${_subscriptionMrr.toStringAsFixed(0)}',
                        titleStyle: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        radius: 55,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Money Flow',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 12),
                        _flowRow(
                          'In: Escrow Volume',
                          '\$${_fmt(_totalEscrowVolume)}',
                          Colors.blue,
                        ),
                        const SizedBox(height: 4),
                        _flowRow(
                          'Out: Contractor Payouts',
                          '-\$${_fmt(_totalContractorPayouts)}',
                          Colors.red,
                        ),
                        const SizedBox(height: 4),
                        _flowRow(
                          'Kept: Platform Fees',
                          '\$${_fmt(_totalPlatformFees)}',
                          Colors.green,
                        ),
                        const SizedBox(height: 4),
                        _flowRow(
                          '+ Subscriptions',
                          '\$${_fmt(_subscriptionMrr)}',
                          Colors.amber,
                        ),
                        const Divider(height: 16),
                        _flowRow(
                          'Net Revenue',
                          '\$${_fmt(_totalRevenue)}',
                          Colors.greenAccent,
                          bold: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── Recent Transactions ──────────────────────────────────
        Text(
          'Recent Transactions',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        ..._buildRecentTransactions(),
      ],
    );
  }

  Widget _buildRevenueTrendChart() {
    final cutoff = DateTime.now().subtract(Duration(days: _periodDays));
    final Map<String, double> dailyFees = {};
    final Map<String, double> dailyVolume = {};

    for (final e in _escrows) {
      final created = e['createdAt'];
      if (created is! Timestamp) continue;
      final date = created.toDate();
      if (date.isBefore(cutoff)) continue;

      final key = DateFormat('MM/dd').format(date);
      final fee = (e['platformFee'] ?? 0).toDouble();
      final price = (e['agreedPrice'] ?? e['finalPrice'] ?? 0).toDouble();
      dailyFees[key] = (dailyFees[key] ?? 0) + fee;
      dailyVolume[key] = (dailyVolume[key] ?? 0) + price;
    }

    final sortedKeys = dailyFees.keys.toList()..sort();
    if (sortedKeys.isEmpty) {
      return const Center(child: Text('No data for this period'));
    }

    return BarChart(
      BarChartData(
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final key = sortedKeys[group.x.toInt()];
              return BarTooltipItem(
                '$key\n\$${rod.toY.toStringAsFixed(2)}',
                const TextStyle(color: Colors.white, fontSize: 12),
              );
            },
          ),
        ),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= sortedKeys.length) {
                  return const SizedBox.shrink();
                }
                // Show every nth label to avoid overlap
                final step = (sortedKeys.length / 8).ceil().clamp(1, 100);
                if (idx % step != 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    sortedKeys[idx],
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (v, _) =>
                  Text('\$${v.toInt()}', style: const TextStyle(fontSize: 10)),
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        barGroups: List.generate(sortedKeys.length, (i) {
          final key = sortedKeys[i];
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: dailyFees[key] ?? 0,
                color: Colors.greenAccent,
                width: 12,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  List<Widget> _buildRecentTransactions() {
    final sorted = List<Map<String, dynamic>>.from(_escrows);
    sorted.sort((a, b) {
      final aTime = a['createdAt'] as Timestamp?;
      final bTime = b['createdAt'] as Timestamp?;
      return (bTime?.seconds ?? 0).compareTo(aTime?.seconds ?? 0);
    });

    final recent = sorted.take(20);
    if (recent.isEmpty) {
      return [const Center(child: Text('No transactions yet'))];
    }

    return recent.map((e) {
      final status = (e['status'] ?? '').toString();
      final service = e['serviceType'] ?? 'Service';
      final price = (e['agreedPrice'] ?? e['finalPrice'] ?? 0).toDouble();
      final fee = (e['platformFee'] ?? 0).toDouble();
      final created = e['createdAt'];
      final dateStr = created is Timestamp
          ? DateFormat.yMMMd().add_jm().format(created.toDate())
          : '—';

      Color statusColor;
      switch (status.toLowerCase()) {
        case 'released':
        case 'completed':
          statusColor = Colors.green;
          break;
        case 'cancelled':
        case 'refunded':
          statusColor = Colors.red;
          break;
        case 'funded':
          statusColor = Colors.blue;
          break;
        default:
          statusColor = Colors.grey;
      }

      return Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: statusColor.withValues(alpha: 0.2),
            child: Icon(Icons.receipt, color: statusColor, size: 20),
          ),
          title: Text('$service — \$${price.toStringAsFixed(2)}'),
          subtitle: Text('Fee: \$${fee.toStringAsFixed(2)} · $dateStr'),
          trailing: Chip(
            label: Text(
              status.toUpperCase(),
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            ),
            backgroundColor: statusColor.withValues(alpha: 0.2),
            side: BorderSide(color: statusColor),
          ),
        ),
      );
    }).toList();
  }

  Widget _kpiCard(String label, String value, IconData icon, Color color) {
    return SizedBox(
      width: 180,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.white60),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _flowRow(
    String label,
    String value,
    Color color, {
    bool bold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  String _fmt(double v) => NumberFormat('#,##0.00').format(v);
}
