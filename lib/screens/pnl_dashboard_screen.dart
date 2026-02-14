import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../services/pnl_service.dart';
import '../widgets/skeleton_loader.dart';

class PnlDashboardScreen extends StatefulWidget {
  const PnlDashboardScreen({super.key});

  @override
  State<PnlDashboardScreen> createState() => _PnlDashboardScreenState();
}

class _PnlDashboardScreenState extends State<PnlDashboardScreen> {
  bool _loading = true;
  String? _error;
  PnlReport? _report;
  int _monthsBack = 6;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final report = await PnlService.instance.buildReport(
        monthsBack: _monthsBack,
      );
      if (!mounted) return;
      setState(() {
        _report = report;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profit & Loss'),
        actions: [
          PopupMenuButton<int>(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: 'Period',
            onSelected: (v) {
              setState(() => _monthsBack = v);
              _loadReport();
            },
            itemBuilder: (_) => [
              _periodItem(3, '3 months'),
              _periodItem(6, '6 months'),
              _periodItem(12, '12 months'),
            ],
          ),
        ],
      ),
      body: _buildBody(scheme),
    );
  }

  PopupMenuItem<int> _periodItem(int value, String label) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          if (value == _monthsBack)
            Icon(
              Icons.check,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            )
          else
            const SizedBox(width: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildBody(ColorScheme scheme) {
    if (_loading) {
      return const Center(
        child: SkeletonLoader(width: double.infinity, height: 200),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: scheme.error),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loadReport,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final report = _report!;

    return RefreshIndicator(
      onRefresh: _loadReport,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Summary cards ──
          _summaryCards(report, scheme),
          const SizedBox(height: 24),

          // ── Revenue vs Expenses chart ──
          Text(
            'Revenue vs Expenses',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          SizedBox(height: 220, child: _revenueVsExpensesChart(report, scheme)),
          const SizedBox(height: 24),

          // ── Net Profit trend ──
          Text(
            'Net Profit Trend',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          SizedBox(height: 200, child: _profitTrendChart(report, scheme)),
          const SizedBox(height: 24),

          // ── Expense breakdown ──
          Text(
            'Expense Breakdown',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          _expenseBreakdownCards(report, scheme),
          const SizedBox(height: 24),

          // ── Category breakdown ──
          if (report.expensesByCategory.isNotEmpty) ...[
            Text(
              'By Category',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            SizedBox(height: 200, child: _categoryPieChart(report, scheme)),
            const SizedBox(height: 24),
          ],

          // ── Monthly table ──
          Text(
            'Monthly Detail',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          _monthlyTable(report, scheme),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Summary Cards ──
  Widget _summaryCards(PnlReport report, ColorScheme scheme) {
    final fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    final profitColor = report.netProfit >= 0
        ? Colors.green.shade700
        : scheme.error;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _statCard(
          'Revenue',
          fmt.format(report.totalRevenue),
          Icons.trending_up,
          scheme.primary,
          scheme,
        ),
        _statCard(
          'Expenses',
          fmt.format(report.totalExpenses),
          Icons.receipt_long_outlined,
          scheme.error,
          scheme,
        ),
        _statCard(
          'Net Profit',
          fmt.format(report.netProfit),
          Icons.account_balance_wallet_outlined,
          profitColor,
          scheme,
        ),
        _statCard(
          'Margin',
          '${report.marginPercent.toStringAsFixed(1)}%',
          Icons.pie_chart_outline,
          profitColor,
          scheme,
        ),
      ],
    );
  }

  Widget _statCard(
    String label,
    String value,
    IconData icon,
    Color iconColor,
    ColorScheme scheme,
  ) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 44) / 2,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 22, color: iconColor),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Revenue vs Expenses Bar Chart ──
  Widget _revenueVsExpensesChart(PnlReport report, ColorScheme scheme) {
    if (report.months.isEmpty) {
      return Center(
        child: Text(
          'No data yet',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      );
    }

    final months = report.months;
    final maxVal = months.fold<double>(0, (prev, m) {
      final v = m.revenue > m.totalExpenses ? m.revenue : m.totalExpenses;
      return v > prev ? v : prev;
    });

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxVal * 1.15,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final label = rodIndex == 0 ? 'Revenue' : 'Expenses';
              return BarTooltipItem(
                '$label\n\$${rod.toY.toStringAsFixed(0)}',
                TextStyle(color: scheme.onInverseSurface, fontSize: 12),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= months.length) return const SizedBox();
                return Text(
                  DateFormat.MMM().format(months[idx].month),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox();
                return Text(
                  '\$${(value / 1000).toStringAsFixed(1)}k',
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxVal > 0 ? maxVal / 4 : 1,
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(months.length, (i) {
          final m = months[i];
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: m.revenue,
                color: scheme.primary,
                width: 12,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
              BarChartRodData(
                toY: m.totalExpenses,
                color: scheme.error.withValues(alpha: 0.7),
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

  // ── Net Profit Line Chart ──
  Widget _profitTrendChart(PnlReport report, ColorScheme scheme) {
    if (report.months.isEmpty) {
      return Center(
        child: Text(
          'No data yet',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      );
    }

    final months = report.months;
    final spots = List.generate(
      months.length,
      (i) => FlSpot(i.toDouble(), months[i].netProfit),
    );

    final minY = spots.fold<double>(0, (prev, s) => s.y < prev ? s.y : prev);
    final maxY = spots.fold<double>(0, (prev, s) => s.y > prev ? s.y : prev);
    final range = (maxY - minY).abs();

    return LineChart(
      LineChartData(
        minY: minY - range * 0.1,
        maxY: maxY + range * 0.1,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.green.shade600,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, xPercentage, bar, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: spot.y >= 0 ? Colors.green.shade600 : scheme.error,
                  strokeWidth: 2,
                  strokeColor: scheme.surface,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.green.shade600.withValues(alpha: 0.1),
            ),
          ),
        ],
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= months.length) return const SizedBox();
                return Text(
                  DateFormat.MMM().format(months[idx].month),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
              getTitlesWidget: (value, meta) {
                return Text(
                  '\$${(value / 1000).toStringAsFixed(1)}k',
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) {
              return spots.map((s) {
                return LineTooltipItem(
                  '\$${s.y.toStringAsFixed(0)}',
                  TextStyle(
                    color: s.y >= 0 ? Colors.green.shade600 : scheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  // ── Expense Breakdown Cards ──
  Widget _expenseBreakdownCards(PnlReport report, ColorScheme scheme) {
    final fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    return Row(
      children: [
        Expanded(
          child: _breakdownCard(
            'Materials',
            fmt.format(report.totalMaterialCosts),
            Icons.hardware_outlined,
            Colors.orange.shade700,
            scheme,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _breakdownCard(
            'Labor',
            fmt.format(report.totalLaborCosts),
            Icons.engineering_outlined,
            Colors.blue.shade700,
            scheme,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _breakdownCard(
            'Other',
            fmt.format(report.totalOtherExpenses),
            Icons.receipt_outlined,
            Colors.purple.shade600,
            scheme,
          ),
        ),
      ],
    );
  }

  Widget _breakdownCard(
    String label,
    String value,
    IconData icon,
    Color color,
    ColorScheme scheme,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  // ── Category Pie Chart ──
  Widget _categoryPieChart(PnlReport report, ColorScheme scheme) {
    final cats = report.expensesByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final colors = [
      Colors.orange.shade600,
      Colors.blue.shade600,
      Colors.purple.shade500,
      Colors.teal.shade500,
      Colors.red.shade500,
      Colors.amber.shade600,
      Colors.indigo.shade400,
      Colors.green.shade600,
    ];

    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 30,
              sections: List.generate(cats.length, (i) {
                final cat = cats[i];
                return PieChartSectionData(
                  value: cat.value,
                  color: colors[i % colors.length],
                  radius: 40,
                  title: '',
                );
              }),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: List.generate(cats.length.clamp(0, 6), (i) {
              final cat = cats[i];
              final fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: colors[i % colors.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _titleCase(cat.key),
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      fmt.format(cat.value),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  // ── Monthly Table ──
  Widget _monthlyTable(PnlReport report, ColorScheme scheme) {
    if (report.months.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No data yet',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ),
      );
    }

    final fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 16,
        headingRowColor: WidgetStateColor.resolveWith(
          (_) => scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        ),
        columns: const [
          DataColumn(label: Text('Month')),
          DataColumn(label: Text('Revenue'), numeric: true),
          DataColumn(label: Text('Expenses'), numeric: true),
          DataColumn(label: Text('Profit'), numeric: true),
          DataColumn(label: Text('Margin'), numeric: true),
        ],
        rows: report.months.map((m) {
          final isProfit = m.netProfit >= 0;
          return DataRow(
            cells: [
              DataCell(Text(DateFormat.yMMM().format(m.month))),
              DataCell(Text(fmt.format(m.revenue))),
              DataCell(Text(fmt.format(m.totalExpenses))),
              DataCell(
                Text(
                  fmt.format(m.netProfit),
                  style: TextStyle(
                    color: isProfit ? Colors.green.shade700 : scheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              DataCell(
                Text(
                  '${m.marginPercent.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: isProfit ? Colors.green.shade700 : scheme.error,
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  String _titleCase(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
