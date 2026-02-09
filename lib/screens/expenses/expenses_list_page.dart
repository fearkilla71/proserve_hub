import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/job_expense.dart';
import '../../services/expense_export_service.dart';
import '../../services/job_expense_service.dart';
import '../../widgets/skeleton_loader.dart';
import 'add_expense_page.dart';

class ExpensesListPage extends StatelessWidget {
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
          filenameBase: 'expenses_$jobId',
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
          filenameBase: 'expenses_$jobId',
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
      appBar: AppBar(title: const Text('Receipts & Expenses')),
      floatingActionButton: canAdd
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddExpensePage(
                      jobId: jobId,
                      createdByRole: createdByRole,
                    ),
                  ),
                );
              },
              child: const Icon(Icons.add),
            )
          : null,
      body: StreamBuilder<List<JobExpense>>(
        stream: expenseService.streamExpensesForJob(jobId),
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

          final items = snapshot.data!;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
}
