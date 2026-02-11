import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/job_expense.dart';
import '../../services/expense_export_service.dart';
import '../../services/job_expense_service.dart';
import '../../widgets/skeleton_loader.dart';

class ExpensesListPage extends StatefulWidget {
  final String jobId;
  final bool canAdd;
  final String createdByRole;

  const ExpensesListPage({
    super.key,
    required this.jobId,
    required this.canAdd,
    required this.createdByRole,
  });

  @override
  State<ExpensesListPage> createState() => _ExpensesListPageState();
}

class _ExpensesListPageState extends State<ExpensesListPage> {
  DateTime? _filterStart;
  DateTime? _filterEnd;

  List<JobExpense> _applyDateFilter(List<JobExpense> items) {
    if (_filterStart == null && _filterEnd == null) return items;
    return items.where((e) {
      final d = e.receiptDate;
      if (d == null) return true;
      if (_filterStart != null && d.isBefore(_filterStart!)) return false;
      if (_filterEnd != null &&
          d.isAfter(_filterEnd!.add(const Duration(days: 1)))) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: _filterStart != null && _filterEnd != null
          ? DateTimeRange(start: _filterStart!, end: _filterEnd!)
          : null,
    );
    if (range != null) {
      setState(() {
        _filterStart = range.start;
        _filterEnd = range.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view expenses.')),
      );
    }

    final expenseService = JobExpenseService();
    final exportService = ExpenseExportService();

    Future<void> exportCsv(List<JobExpense> items) async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        final csv = exportService.buildCsv(items);
        final file = await exportService.writeCsvToTempFile(
          filenameBase: 'expenses_${widget.jobId}',
          csv: csv,
        );
        await Share.shareXFiles([XFile(file.path)], text: 'Expenses CSV');
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Export failed: ${e.toString().replaceFirst('Exception: ', '')}',
            ),
          ),
        );
      }
    }

    Future<void> exportPdf(List<JobExpense> items) async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        final file = await exportService.writePdfToTempFile(
          filenameBase: 'expenses_${widget.jobId}',
          title: 'Receipts & Expenses',
          expenses: items,
        );
        await Share.shareXFiles([XFile(file.path)], text: 'Expenses PDF');
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Export failed: ${e.toString().replaceFirst('Exception: ', '')}',
            ),
          ),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipts & Expenses'),
        actions: [
          IconButton(
            icon: Icon(
              _filterStart != null
                  ? Icons.filter_alt
                  : Icons.filter_alt_outlined,
            ),
            tooltip: 'Filter by date',
            onPressed: _pickDateRange,
          ),
          if (_filterStart != null)
            IconButton(
              icon: const Icon(Icons.filter_alt_off),
              tooltip: 'Clear filter',
              onPressed: () {
                setState(() {
                  _filterStart = null;
                  _filterEnd = null;
                });
              },
            ),
        ],
      ),
      floatingActionButton: widget.canAdd
          ? FloatingActionButton(
              onPressed: () {
                context.push(
                  '/add-expense/${widget.jobId}',
                  extra: {'createdByRole': widget.createdByRole},
                );
              },
              child: const Icon(Icons.add),
            )
          : null,
      body: StreamBuilder<List<JobExpense>>(
        stream: expenseService.streamExpensesForJob(widget.jobId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: 6,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return Card(
                  child: ListTile(
                    leading: const SkeletonLoader(
                      width: 24,
                      height: 24,
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    title: SkeletonLoader(
                      width: double.infinity,
                      height: 14,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: SkeletonLoader(
                        width: 160,
                        height: 12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                );
              },
            );
          }

          final allItems = snapshot.data!;
          final items = _applyDateFilter(allItems);

          // Aggregate totals
          double totalAmount = 0;
          double totalTax = 0;
          for (final e in items) {
            totalAmount += e.total ?? 0;
            totalTax += e.tax ?? 0;
          }

          return Column(
            children: [
              // Date filter indicator
              if (_filterStart != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  color: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                  child: Text(
                    'Showing ${DateFormat.MMMd().format(_filterStart!)} – '
                    '${DateFormat.MMMd().format(_filterEnd!)}  '
                    '(${items.length} of ${allItems.length})',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),

              // Aggregate totals card
              if (items.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _statCol('Items', items.length.toString()),
                          _statCol(
                            'Subtotal',
                            '\$${(totalAmount - totalTax).toStringAsFixed(2)}',
                          ),
                          _statCol('Tax', '\$${totalTax.toStringAsFixed(2)}'),
                          _statCol(
                            'Total',
                            '\$${totalAmount.toStringAsFixed(2)}',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: items.isEmpty
                            ? null
                            : () => exportCsv(items),
                        child: const Text('Export CSV'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: items.isEmpty
                            ? null
                            : () => exportPdf(items),
                        child: const Text('Export PDF'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: items.isEmpty
                    ? const Center(child: Text('No receipts yet.'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: items.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final e = items[i];
                          final title = (e.vendor?.isNotEmpty ?? false)
                              ? e.vendor!
                              : 'Receipt';

                          final subtitleParts = <String>[];
                          if (e.receiptDate != null) {
                            subtitleParts.add(
                              '${e.receiptDate!.month}/${e.receiptDate!.day}/${e.receiptDate!.year}',
                            );
                          }
                          if (e.total != null) {
                            subtitleParts.add(
                              '${e.currency} ${e.total!.toStringAsFixed(2)}',
                            );
                          }

                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.receipt_long),
                              title: Text(title),
                              subtitle: Text(subtitleParts.join(' • ')),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _statCol(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
