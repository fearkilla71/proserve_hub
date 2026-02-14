import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../services/contract_generator_service.dart';

/// Screen for generating and managing service contracts / SOW documents.
class ContractGeneratorScreen extends StatefulWidget {
  const ContractGeneratorScreen({super.key});

  @override
  State<ContractGeneratorScreen> createState() =>
      _ContractGeneratorScreenState();
}

class _ContractGeneratorScreenState extends State<ContractGeneratorScreen> {
  final _svc = ContractGeneratorService.instance;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Contracts & SOW')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _svc.watchContracts(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) return _emptyState(scheme);

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final doc = docs[i];
              final data = doc.data();
              return _ContractCard(
                id: doc.id,
                data: data,
                onTap: () => _showContractDetail(context, doc.id, data),
                onStatusChange: (status) => _svc.updateStatus(doc.id, status),
                onDelete: () => _confirmDelete(doc.id, data['clientName']),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('New Contract'),
      ),
    );
  }

  Widget _emptyState(ColorScheme scheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.gavel,
            size: 72,
            color: scheme.primary.withValues(alpha: .4),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Contracts',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Generate professional contracts and\nscope-of-work documents.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  void _showCreateSheet(BuildContext context) {
    final clientNameCtrl = TextEditingController();
    final clientEmailCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final scopeCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final paymentCtrl = TextEditingController();
    final warrantyCtrl = TextEditingController();
    String serviceType = 'painting';
    DateTime startDate = DateTime.now().add(const Duration(days: 7));
    DateTime endDate = DateTime.now().add(const Duration(days: 21));

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
                      'New Contract',
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _field(ctx, clientNameCtrl, 'Client name', Icons.person),
                    const SizedBox(height: 12),
                    _field(
                      ctx,
                      clientEmailCtrl,
                      'Client email',
                      Icons.email,
                      type: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    _field(ctx, addressCtrl, 'Job address', Icons.location_on),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: serviceType,
                      decoration: const InputDecoration(
                        labelText: 'Service type',
                        prefixIcon: Icon(Icons.work),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'painting',
                          child: Text('Interior Painting'),
                        ),
                        DropdownMenuItem(
                          value: 'exterior_painting',
                          child: Text('Exterior Painting'),
                        ),
                        DropdownMenuItem(
                          value: 'cabinet_painting',
                          child: Text('Cabinet Painting'),
                        ),
                        DropdownMenuItem(
                          value: 'drywall',
                          child: Text('Drywall Repair'),
                        ),
                        DropdownMenuItem(
                          value: 'pressure_washing',
                          child: Text('Pressure Washing'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setSheetState(() => serviceType = v);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    _field(
                      ctx,
                      scopeCtrl,
                      'Scope of work',
                      Icons.description,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 12),
                    _field(
                      ctx,
                      priceCtrl,
                      'Total price',
                      Icons.attach_money,
                      type: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.play_arrow, size: 20),
                            title: Text(
                              'Start: ${DateFormat.yMd().format(startDate)}',
                              style: const TextStyle(fontSize: 13),
                            ),
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: startDate,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365),
                                ),
                              );
                              if (picked != null) {
                                setSheetState(() => startDate = picked);
                              }
                            },
                          ),
                        ),
                        Expanded(
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.stop, size: 20),
                            title: Text(
                              'End: ${DateFormat.yMd().format(endDate)}',
                              style: const TextStyle(fontSize: 13),
                            ),
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: endDate,
                                firstDate: startDate,
                                lastDate: DateTime.now().add(
                                  const Duration(days: 730),
                                ),
                              );
                              if (picked != null) {
                                setSheetState(() => endDate = picked);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _field(
                      ctx,
                      paymentCtrl,
                      'Payment terms (optional)',
                      Icons.payments,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    _field(
                      ctx,
                      warrantyCtrl,
                      'Warranty clause (optional)',
                      Icons.verified,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () async {
                          if (clientNameCtrl.text.trim().isEmpty ||
                              scopeCtrl.text.trim().isEmpty ||
                              priceCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Client, scope, and price are required',
                                ),
                              ),
                            );
                            return;
                          }
                          Navigator.pop(ctx);
                          HapticFeedback.mediumImpact();
                          try {
                            await _svc.createContract(
                              clientName: clientNameCtrl.text.trim(),
                              clientEmail: clientEmailCtrl.text.trim(),
                              jobAddress: addressCtrl.text.trim(),
                              serviceType: serviceType,
                              scopeOfWork: scopeCtrl.text.trim(),
                              totalPrice: double.parse(priceCtrl.text.trim()),
                              expectedStart: startDate,
                              expectedEnd: endDate,
                              paymentTerms: paymentCtrl.text.trim().isEmpty
                                  ? null
                                  : paymentCtrl.text.trim(),
                              warrantyClause: warrantyCtrl.text.trim().isEmpty
                                  ? null
                                  : warrantyCtrl.text.trim(),
                            );
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.gavel),
                        label: const Text('Create Contract'),
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

  void _showContractDetail(
    BuildContext context,
    String id,
    Map<String, dynamic> data,
  ) {
    final contractText = _svc.generateContractText({...data, 'id': id});
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Expanded(child: Text('Contract')),
            _StatusChip(status: data['status'] as String? ?? 'draft'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              contractText,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          TextButton.icon(
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copy'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: contractText));
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Contract copied')));
            },
          ),
          FilledButton.icon(
            icon: const Icon(Icons.share, size: 18),
            label: const Text('Share'),
            onPressed: () {
              Navigator.pop(ctx);
              Share.share(contractText, subject: 'Service Contract');
            },
          ),
        ],
      ),
    );
  }

  void _confirmDelete(String id, String? clientName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Contract'),
        content: Text('Remove contract for ${clientName ?? 'this client'}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _svc.deleteContract(id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _field(
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
      textCapitalization: TextCapitalization.sentences,
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'sent':
        color = Colors.blue;
        break;
      case 'signed':
        color = Colors.green;
        break;
      case 'completed':
        color = Colors.teal;
        break;
      case 'cancelled':
        color = Colors.red;
        break;
      default:
        color = Colors.orange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _ContractCard extends StatelessWidget {
  final String id;
  final Map<String, dynamic> data;
  final VoidCallback onTap;
  final ValueChanged<String> onStatusChange;
  final VoidCallback onDelete;

  const _ContractCard({
    required this.id,
    required this.data,
    required this.onTap,
    required this.onStatusChange,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final client = data['clientName'] ?? 'Unknown';
    final service = data['serviceType'] ?? 'general';
    final status = data['status'] as String? ?? 'draft';
    final total = (data['totalPrice'] as num?)?.toDouble() ?? 0;
    final created = (data['createdAt'] as Timestamp?)?.toDate();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.gavel, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          client,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '$service${created != null ? ' • ${DateFormat.yMMMd().format(created)}' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${total.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: scheme.primary,
                        ),
                      ),
                      _StatusChip(status: status),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  // Status action buttons
                  if (status == 'draft')
                    TextButton.icon(
                      icon: const Icon(Icons.send, size: 16),
                      label: const Text('Mark Sent'),
                      onPressed: () => onStatusChange('sent'),
                    ),
                  if (status == 'sent')
                    TextButton.icon(
                      icon: const Icon(Icons.draw, size: 16),
                      label: const Text('Mark Signed'),
                      onPressed: () => onStatusChange('signed'),
                    ),
                  if (status == 'signed')
                    TextButton.icon(
                      icon: const Icon(Icons.check_circle, size: 16),
                      label: const Text('Complete'),
                      onPressed: () => onStatusChange('completed'),
                    ),
                  const Spacer(),
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
      ),
    );
  }
}
