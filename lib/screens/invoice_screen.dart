import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../models/invoice_item.dart';

class InvoiceScreen extends StatefulWidget {
  final String jobId;

  const InvoiceScreen({super.key, required this.jobId});

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  bool _editMode = false;
  bool _saving = false;

  List<InvoiceItem> _draftItems = <InvoiceItem>[];
  final TextEditingController _notesController = TextEditingController();

  DocumentReference<Map<String, dynamic>> get _invoiceRef =>
      FirebaseFirestore.instance.collection('invoices').doc(widget.jobId);

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  String _formatMoney(double value) => '\$${value.toStringAsFixed(2)}';

  double? _readPlatformFeeAmount(Map<String, dynamic> job) {
    final candidates = <dynamic>[
      job['platformFeeAmount'],
      job['platformFee'],
      job['applicationFeeAmount'],
      job['feeAmount'],
    ];
    for (final raw in candidates) {
      if (raw is num) return raw.toDouble();
    }
    return null;
  }

  List<InvoiceItem> _defaultItems({
    required Map<String, dynamic> job,
    required double jobAmount,
  }) {
    final service = (job['service'] as String?)?.trim();
    return [
      InvoiceItem(
        description: (service != null && service.isNotEmpty)
            ? service
            : 'Service',
        quantity: 1,
        unitPrice: jobAmount,
      ),
    ];
  }

  List<InvoiceItem> _itemsFromInvoiceData({
    required Map<String, dynamic>? invoiceData,
    required Map<String, dynamic> job,
    required double jobAmount,
  }) {
    final itemsRaw = invoiceData?['items'];
    if (itemsRaw is List) {
      final parsed = <InvoiceItem>[];
      for (final item in itemsRaw) {
        if (item is Map) {
          parsed.add(InvoiceItem.fromMap(Map<String, dynamic>.from(item)));
        }
      }
      if (parsed.isNotEmpty) return parsed;
    }
    return _defaultItems(job: job, jobAmount: jobAmount);
  }

  String _notesFromInvoiceData(Map<String, dynamic>? invoiceData) {
    return (invoiceData?['notes'] as String?)?.trim() ?? '';
  }

  void _enterEdit({required List<InvoiceItem> items, required String notes}) {
    setState(() {
      _editMode = true;
      _draftItems = List<InvoiceItem>.from(items);
      _notesController.text = notes;
    });
  }

  void _cancelEdit() {
    setState(() {
      _editMode = false;
      _draftItems = <InvoiceItem>[];
      _notesController.text = '';
    });
  }

  Future<void> _createInvoiceIfMissing({
    required Map<String, dynamic> job,
    required double jobAmount,
  }) async {
    final snap = await _invoiceRef.get();
    if (snap.exists) return;

    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final contractorId = (job['claimedBy'] as String?)?.trim() ?? '';
    if (currentUid == null || currentUid != contractorId) {
      throw Exception('Only the assigned contractor can create an invoice');
    }

    await _invoiceRef.set({
      'jobId': widget.jobId,
      'contractorId': contractorId,
      'customerId': (job['requesterUid'] as String?)?.trim() ?? '',
      'status': 'draft',
      'items': _defaultItems(
        job: job,
        jobAmount: jobAmount,
      ).map((e) => e.toMap()).toList(),
      'notes': '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _saveInvoice({required Map<String, dynamic> job}) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final contractorId = (job['claimedBy'] as String?)?.trim() ?? '';
    if (currentUid == null || currentUid != contractorId) {
      throw Exception('Only the assigned contractor can edit the invoice');
    }
    if (_draftItems.isEmpty) {
      throw Exception('Add at least one line item');
    }

    setState(() => _saving = true);
    try {
      await _invoiceRef.set({
        'jobId': widget.jobId,
        'contractorId': contractorId,
        'customerId': (job['requesterUid'] as String?)?.trim() ?? '',
        'status': 'draft',
        'items': _draftItems.map((e) => e.toMap()).toList(),
        'notes': _notesController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invoice saved')));
      _cancelEdit();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showItemDialog({
    InvoiceItem? initial,
    required void Function(InvoiceItem item) onSave,
  }) async {
    final desc = TextEditingController(text: initial?.description ?? '');
    final qty = TextEditingController(
      text: initial == null ? '1' : initial.quantity.toStringAsFixed(0),
    );
    final price = TextEditingController(
      text: initial == null ? '' : initial.unitPrice.toStringAsFixed(2),
    );

    final result = await showDialog<InvoiceItem>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(initial == null ? 'Add line item' : 'Edit line item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: desc,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: qty,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Qty'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: price,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Unit price',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final description = desc.text.trim();
                final quantity = double.tryParse(qty.text.trim()) ?? 0;
                final unitPrice = double.tryParse(price.text.trim()) ?? -1;
                if (description.isEmpty || quantity <= 0 || unitPrice < 0) {
                  Navigator.pop(context);
                  return;
                }

                Navigator.pop(
                  context,
                  InvoiceItem(
                    description: description,
                    quantity: quantity,
                    unitPrice: unitPrice,
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result != null) onSave(result);
  }

  Future<Map<String, dynamic>> _loadInvoiceData() async {
    final jobDoc = await FirebaseFirestore.instance
        .collection('job_requests')
        .doc(widget.jobId)
        .get();

    if (!jobDoc.exists) {
      throw Exception('Job not found');
    }

    final jobData = jobDoc.data()!;
    final customerId = jobData['requesterUid'] as String;
    final contractorId = jobData['claimedBy'] as String?;

    // Load customer data
    final customerDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(customerId)
        .get();

    // Load contractor data
    DocumentSnapshot? contractorDoc;
    if (contractorId != null) {
      contractorDoc = await FirebaseFirestore.instance
          .collection('contractors')
          .doc(contractorId)
          .get();
    }

    return {
      'job': jobData,
      'customer': customerDoc.data(),
      'contractor': contractorDoc?.data(),
      'jobId': widget.jobId,
    };
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return DateFormat('MMM d, y').format(timestamp.toDate());
    }
    return DateFormat('MMM d, y').format(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share Invoice',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Invoice sharing coming soon!')),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _loadInvoiceData(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading invoice: ${snapshot.error}'),
            );
          }

          final data = snapshot.data!;
          final job = data['job'] as Map<String, dynamic>;
          final customer = data['customer'] as Map<String, dynamic>?;
          final contractor = data['contractor'] as Map<String, dynamic>?;

          final currentUid = FirebaseAuth.instance.currentUser?.uid;
          final requesterId = (job['requesterUid'] as String?)?.trim() ?? '';
          final contractorId = (job['claimedBy'] as String?)?.trim() ?? '';
          final isRequester = currentUid != null && currentUid == requesterId;
          final isAssignedContractor =
              currentUid != null &&
              contractorId.isNotEmpty &&
              currentUid == contractorId;

          final jobAmount = (job['price'] as num?)?.toDouble() ?? 0;
          final tipAmount = (job['tipAmount'] as num?)?.toDouble() ?? 0;

          final status = (job['status'] as String?)?.trim().toLowerCase() ?? '';
          final String paymentStatus;
          if (status == 'completed') {
            paymentStatus = 'Paid';
          } else {
            paymentStatus = 'Unpaid';
          }

          final platformFee = _readPlatformFeeAmount(job);
          final double contractorPayout = platformFee == null
              ? jobAmount
              : (jobAmount - platformFee)
                    .clamp(0.0, double.infinity)
                    .toDouble();

          final invoiceNumber =
              'INV-${widget.jobId.substring(0, 8).toUpperCase()}';
          final invoiceDate = _formatDate(
            job['completedAt'] ?? job['createdAt'],
          );

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _invoiceRef.snapshots(),
            builder: (context, invoiceSnap) {
              final invoiceData = invoiceSnap.data?.data();
              final invoiceExists = invoiceSnap.data?.exists == true;

              final items = _itemsFromInvoiceData(
                invoiceData: invoiceData,
                job: job,
                jobAmount: jobAmount,
              );
              final notes = _notesFromInvoiceData(invoiceData);

              final displayItems = _editMode ? _draftItems : items;
              final displayNotes = _editMode ? _notesController.text : notes;
              final subtotal = displayItems.fold<double>(
                0,
                (total, item) => total + item.total,
              );
              final totalAmount = subtotal + tipAmount;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'INVOICE',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  invoiceNumber,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'ProServe Hub',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                                Text(
                                  'Date: $invoiceDate',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const Divider(height: 32),

                        // Bill To / From
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'BILL TO',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    customer?['name'] ?? 'Customer',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (customer?['email'] != null)
                                    Text(
                                      customer!['email'],
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'FROM',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    contractor?['businessName'] ?? 'Contractor',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (contractor?['location'] != null)
                                    Text(
                                      contractor!['location'],
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Payment status
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.lock_outline,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Payment: $paymentStatus',
                                            style: TextStyle(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurface,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Job total',
                                            style: TextStyle(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                        Text(_formatMoney(jobAmount)),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Platform fee',
                                            style: TextStyle(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          platformFee == null
                                              ? '—'
                                              : _formatMoney(platformFee),
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (platformFee == null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'Fee is calculated during checkout.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Contractor payout',
                                            style: TextStyle(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                        Text(_formatMoney(contractorPayout)),
                                      ],
                                    ),
                                    if (tipAmount > 0) ...[
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'Tip',
                                              style: TextStyle(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ),
                                          Text(_formatMoney(tipAmount)),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'ITEMS',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (isAssignedContractor)
                              TextButton.icon(
                                onPressed: _saving
                                    ? null
                                    : () async {
                                        if (!_editMode) {
                                          try {
                                            if (!invoiceExists) {
                                              await _createInvoiceIfMissing(
                                                job: job,
                                                jobAmount: jobAmount,
                                              );
                                            }
                                            _enterEdit(
                                              items: items,
                                              notes: notes,
                                            );
                                          } catch (e) {
                                            if (!context.mounted) return;
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  e.toString().replaceFirst(
                                                    'Exception: ',
                                                    '',
                                                  ),
                                                ),
                                              ),
                                            );
                                          }
                                        } else {
                                          await _showItemDialog(
                                            onSave: (item) {
                                              setState(() {
                                                _draftItems.add(item);
                                              });
                                            },
                                          );
                                        }
                                      },
                                icon: Icon(_editMode ? Icons.add : Icons.edit),
                                label: Text(_editMode ? 'Add item' : 'Edit'),
                              ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        ...displayItems.map(
                          (item) => Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.description,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        _formatMoney(item.total),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${item.quantity.toStringAsFixed(0)} × ${_formatMoney(item.unitPrice)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  if (_editMode && isAssignedContractor)
                                    Row(
                                      children: [
                                        TextButton(
                                          onPressed: () async {
                                            await _showItemDialog(
                                              initial: item,
                                              onSave: (updated) {
                                                setState(() {
                                                  final idx = _draftItems
                                                      .indexOf(item);
                                                  if (idx >= 0) {
                                                    _draftItems[idx] = updated;
                                                  }
                                                });
                                              },
                                            );
                                          },
                                          child: const Text('Edit'),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            setState(() {
                                              _draftItems.remove(item);
                                            });
                                          },
                                          child: const Text('Remove'),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        if (tipAmount > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Gratuity (Tip)'),
                                Text(_formatMoney(tipAmount)),
                              ],
                            ),
                          ),

                        const Divider(height: 24),

                        if (_editMode && isAssignedContractor) ...[
                          TextField(
                            controller: _notesController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Notes (optional)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _saving ? null : _cancelEdit,
                                  child: const Text('Cancel'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton(
                                  onPressed: _saving
                                      ? null
                                      : () async {
                                          try {
                                            await _saveInvoice(job: job);
                                          } catch (e) {
                                            if (!context.mounted) return;
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  e.toString().replaceFirst(
                                                    'Exception: ',
                                                    '',
                                                  ),
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                  child: _saving
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text('Save invoice'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                        ] else if (displayNotes.trim().isNotEmpty) ...[
                          Text(
                            'NOTES',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(displayNotes),
                          const SizedBox(height: 24),
                        ],

                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'TOTAL',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                  Text(
                                    _formatMoney(totalAmount),
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        Center(
                          child: Text(
                            'Thank you for your business!',
                            style: TextStyle(
                              fontSize: 16,
                              fontStyle: FontStyle.italic,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),

                        if (!isRequester && !isAssignedContractor)
                          const SizedBox.shrink(),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
