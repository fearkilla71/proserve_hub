import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../services/standalone_expense_service.dart';

/// Standalone expense tracker — view ALL expenses across jobs,
/// categorize, flag tax-deductible, and see totals dashboard.
class StandaloneExpensesScreen extends StatefulWidget {
  const StandaloneExpensesScreen({super.key});

  @override
  State<StandaloneExpensesScreen> createState() =>
      _StandaloneExpensesScreenState();
}

class _StandaloneExpensesScreenState extends State<StandaloneExpensesScreen> {
  String? _categoryFilter;
  bool _taxDeductibleOnly = false;
  final _svc = StandaloneExpenseService.instance;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Please sign in.')));
    }
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Tracker'),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(
              _categoryFilter != null
                  ? Icons.filter_alt
                  : Icons.filter_alt_outlined,
            ),
            tooltip: 'Filter by category',
            onSelected: (v) {
              setState(() {
                _categoryFilter = v == 'all' ? null : v;
              });
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'all', child: Text('All categories')),
              ...StandaloneExpenseService.categories.entries.map(
                (e) => PopupMenuItem(value: e.key, child: Text(e.value)),
              ),
            ],
          ),
          IconButton(
            icon: Icon(
              _taxDeductibleOnly
                  ? Icons.receipt_long
                  : Icons.receipt_long_outlined,
              color: _taxDeductibleOnly ? Colors.green : null,
            ),
            tooltip: 'Tax-deductible only',
            onPressed: () =>
                setState(() => _taxDeductibleOnly = !_taxDeductibleOnly),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _svc.watchAllExpenses(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) return _emptyState(scheme);

          // Apply filters
          var items = docs;
          if (_categoryFilter != null) {
            items = items
                .where((d) => d.data()['category'] == _categoryFilter)
                .toList();
          }
          if (_taxDeductibleOnly) {
            items = items
                .where((d) => d.data()['taxDeductible'] == true)
                .toList();
          }

          // Compute totals
          double totalAmount = 0;
          double taxDeductibleTotal = 0;
          final categoryTotals = <String, double>{};
          for (final doc in items) {
            final data = doc.data();
            final amount = (data['total'] as num?)?.toDouble() ?? 0;
            totalAmount += amount;
            if (data['taxDeductible'] == true) {
              taxDeductibleTotal += amount;
            }
            final cat = data['category'] as String? ?? 'general';
            categoryTotals[cat] = (categoryTotals[cat] ?? 0) + amount;
          }

          return Column(
            children: [
              // ── Totals Dashboard ──
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: .3),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statCol(
                      'Total',
                      '\$${totalAmount.toStringAsFixed(0)}',
                      scheme.primary,
                    ),
                    _statCol(
                      'Tax Deductible',
                      '\$${taxDeductibleTotal.toStringAsFixed(0)}',
                      Colors.green,
                    ),
                    _statCol(
                      'Items',
                      '${items.length}',
                      scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
              // ── Category breakdown chips ──
              if (categoryTotals.length > 1)
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: categoryTotals.entries.map((e) {
                      final label =
                          StandaloneExpenseService.categories[e.key] ?? e.key;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Chip(
                          label: Text(
                            '$label: \$${e.value.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              // ── Expense list ──
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final doc = items[i];
                    final data = doc.data();
                    return _ExpenseCard(
                      id: doc.id,
                      data: data,
                      onToggleTax: (v) => _svc.toggleTaxDeductible(doc.id, v),
                      onSetCategory: (cat) => _svc.setCategory(doc.id, cat),
                      onDelete: () => _confirmDelete(doc.id),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddExpenseSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
    );
  }

  Widget _emptyState(ColorScheme scheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.receipt_long,
            size: 72,
            color: scheme.primary.withValues(alpha: .4),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Expenses Yet',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Track materials, fuel, tools, and\nother business expenses.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _statCol(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  void _showAddExpenseSheet(BuildContext context) {
    final vendorCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final taxCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String category = 'general';
    bool taxDeductible = false;
    DateTime receiptDate = DateTime.now();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                0,
                20,
                MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add Expense',
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _sheetField(ctx, vendorCtrl, 'Vendor / Store', Icons.store),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _sheetField(
                            ctx,
                            amountCtrl,
                            'Amount',
                            Icons.attach_money,
                            type: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _sheetField(
                            ctx,
                            taxCtrl,
                            'Tax',
                            Icons.percent,
                            type: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        prefixIcon: Icon(Icons.category),
                        border: OutlineInputBorder(),
                      ),
                      items: StandaloneExpenseService.categories.entries
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setSheetState(() => category = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today),
                      title: Text(
                        'Date: ${DateFormat.yMMMd().format(receiptDate)}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: receiptDate,
                          firstDate: DateTime(DateTime.now().year - 5),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setSheetState(() => receiptDate = picked);
                        }
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Tax Deductible'),
                      secondary: const Icon(Icons.check_circle_outline),
                      value: taxDeductible,
                      onChanged: (v) => setSheetState(() => taxDeductible = v),
                    ),
                    const SizedBox(height: 8),
                    _sheetField(
                      ctx,
                      notesCtrl,
                      'Notes',
                      Icons.note,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () async {
                          if (vendorCtrl.text.trim().isEmpty ||
                              amountCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text('Vendor and amount required'),
                              ),
                            );
                            return;
                          }
                          Navigator.pop(ctx);
                          HapticFeedback.mediumImpact();
                          try {
                            await _svc.addStandaloneExpense(
                              vendor: vendorCtrl.text.trim(),
                              amount: double.parse(amountCtrl.text.trim()),
                              tax: double.tryParse(taxCtrl.text.trim()),
                              category: category,
                              notes: notesCtrl.text.trim().isEmpty
                                  ? null
                                  : notesCtrl.text.trim(),
                              receiptDate: receiptDate,
                              taxDeductible: taxDeductible,
                            );
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.save),
                        label: const Text('Save Expense'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense'),
        content: const Text('Remove this expense permanently?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _svc.deleteExpense(id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _sheetField(
    BuildContext ctx,
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType? type,
    int maxLines = 1,
  }) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Theme.of(ctx).colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      keyboardType: type,
      maxLines: maxLines,
      textCapitalization: TextCapitalization.words,
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  final String id;
  final Map<String, dynamic> data;
  final ValueChanged<bool> onToggleTax;
  final ValueChanged<String> onSetCategory;
  final VoidCallback onDelete;

  const _ExpenseCard({
    required this.id,
    required this.data,
    required this.onToggleTax,
    required this.onSetCategory,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final vendor = data['vendor'] as String? ?? 'Unknown';
    final total = (data['total'] as num?)?.toDouble() ?? 0;
    final category = data['category'] as String? ?? 'general';
    final taxDeductible = data['taxDeductible'] as bool? ?? false;
    final receiptDate = (data['receiptDate'] as Timestamp?)?.toDate();
    final notes = data['notes'] as String?;
    final jobId = data['jobId'] as String?;
    final catLabel = StandaloneExpenseService.categories[category] ?? category;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_categoryIcon(category), color: scheme.primary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vendor,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        '${receiptDate != null ? DateFormat.yMMMd().format(receiptDate) : 'No date'} • $catLabel',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '\$${total.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
            if (notes != null && notes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                notes,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                if (taxDeductible)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Tax Deductible',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (jobId != null && jobId != 'standalone')
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Job linked',
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSecondaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    taxDeductible
                        ? Icons.check_circle
                        : Icons.check_circle_outline,
                    color: taxDeductible ? Colors.green : null,
                    size: 20,
                  ),
                  tooltip: 'Toggle tax deductible',
                  onPressed: () => onToggleTax(!taxDeductible),
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: scheme.error,
                  ),
                  tooltip: 'Delete',
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'materials':
        return Icons.hardware;
      case 'tools':
        return Icons.construction;
      case 'fuel':
        return Icons.local_gas_station;
      case 'subcontractor':
        return Icons.people;
      case 'insurance':
        return Icons.shield;
      case 'advertising':
        return Icons.campaign;
      case 'office':
        return Icons.business;
      case 'vehicle':
        return Icons.directions_car;
      case 'meals':
        return Icons.restaurant;
      case 'education':
        return Icons.school;
      default:
        return Icons.receipt_long;
    }
  }
}
