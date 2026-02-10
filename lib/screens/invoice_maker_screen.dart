import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'invoice_preview_screen.dart';
import 'package:image_picker/image_picker.dart';

import '../models/invoice_models.dart';
import '../services/invoice_ai_service.dart';
import '../services/invoice_pdf_builder.dart';
import '../widgets/animated_states.dart';

class InvoiceMakerScreen extends StatefulWidget {
  final InvoiceDraft? initialDraft;

  const InvoiceMakerScreen({super.key, this.initialDraft});

  @override
  State<InvoiceMakerScreen> createState() => _InvoiceMakerScreenState();
}

class _InvoiceMakerScreenState extends State<InvoiceMakerScreen> {
  final _ai = InvoiceAiService();
  final _imagePicker = ImagePicker();

  late InvoiceDraft _draft;
  bool _loading = false;
  bool _savingDraft = false;
  bool _completed = false;
  bool _everSavedDraft = false;
  bool _allowPop = false;
  bool _shownDraftSaveWarning = false;
  String? _error;

  DateTime _issuedDate = DateTime.now();
  double _discount = 0.0;
  double _taxRatePercent = 0.0;
  final List<String> _paymentMethods = <String>[];
  final List<XFile> _photos = <XFile>[];

  late final Map<String, Object?> _initialFingerprint;
  late Map<String, Object?> _lastSavedFingerprint;

  final _clientName = TextEditingController();
  final _clientEmail = TextEditingController();
  final _clientPhone = TextEditingController();
  final _clientAddress = TextEditingController();
  final _jobTitle = TextEditingController();
  final _jobDescription = TextEditingController();
  final _paymentTerms = TextEditingController();
  final _notes = TextEditingController();

  @override
  void initState() {
    super.initState();
    _draft = widget.initialDraft ?? InvoiceDraft.empty();
    _syncControllersFromDraft();

    _initialFingerprint = _draftFingerprint(_draft);
    _lastSavedFingerprint = Map<String, Object?>.from(_initialFingerprint);
  }

  @override
  void dispose() {
    _clientName.dispose();
    _clientEmail.dispose();
    _clientPhone.dispose();
    _clientAddress.dispose();
    _jobTitle.dispose();
    _jobDescription.dispose();
    _paymentTerms.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _syncControllersFromDraft() {
    _clientName.text = _draft.clientName;
    _clientEmail.text = _draft.clientEmail;
    _clientPhone.text = _draft.clientPhone;
    _clientAddress.text = _draft.clientAddress;
    _jobTitle.text = _draft.jobTitle;
    _jobDescription.text = _draft.jobDescription;
    _paymentTerms.text = _draft.paymentTerms;
    _notes.text = _draft.notes;
  }

  void _syncDraftFromControllers() {
    _draft = _draft.copyWith(
      clientName: _clientName.text,
      clientEmail: _clientEmail.text,
      clientPhone: _clientPhone.text,
      clientAddress: _clientAddress.text,
      jobTitle: _jobTitle.text,
      jobDescription: _jobDescription.text,
      paymentTerms: _paymentTerms.text,
      notes: _notes.text,
    );
  }

  void _requestPop() {
    if (_allowPop) {
      Navigator.maybePop(context);
      return;
    }

    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.maybePop(context);
    });
  }

  Future<void> _generateWithAi() async {
    _syncDraftFromControllers();

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final next = await _ai.draftInvoice(current: _draft);
      if (!mounted) return;
      setState(() {
        _draft = next;
        _syncControllersFromDraft();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _editClientSheet() async {
    final name = TextEditingController(text: _clientName.text);
    final email = TextEditingController(text: _clientEmail.text);
    final phone = TextEditingController(text: _clientPhone.text);
    final address = TextEditingController(text: _clientAddress.text);

    final ok = await _showEditorSheet<bool>(
      title: 'Client',
      primaryButtonText: 'Save',
      builder: (context, setSheetState) {
        return Column(
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Client name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email (optional)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone (optional)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: address,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Address (optional)',
              ),
            ),
          ],
        );
      },
      onPrimary: () => true,
    );

    if (ok != true) return;

    setState(() {
      _clientName.text = name.text;
      _clientEmail.text = email.text;
      _clientPhone.text = phone.text;
      _clientAddress.text = address.text;
      _syncDraftFromControllers();
    });
  }

  Future<void> _editNotesSheet() async {
    final notes = TextEditingController(text: _notes.text);

    final ok = await _showEditorSheet<bool>(
      title: 'Edit Notes',
      primaryButtonText: 'Save',
      builder: (context, setSheetState) {
        return TextField(
          controller: notes,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: 'Add notes for this invoice…',
            border: OutlineInputBorder(),
          ),
        );
      },
      onPrimary: () => true,
    );

    if (ok != true) return;

    setState(() {
      _notes.text = notes.text;
      _syncDraftFromControllers();
    });
  }

  Future<void> _editLineItemSheet({int? index}) async {
    final existing = index == null ? null : _draft.items[index];

    final nameController = TextEditingController(
      text: existing == null ? '' : _lineItemName(existing.description),
    );
    final descController = TextEditingController(
      text: existing == null ? '' : _lineItemDetails(existing.description),
    );
    final qtyController = TextEditingController(
      text: (existing?.quantity ?? 1).toString(),
    );
    final priceController = TextEditingController(
      text: (existing?.unitPrice ?? 0).toStringAsFixed(0),
    );

    int quantity = existing?.quantity ?? 1;
    double unitPrice = existing?.unitPrice ?? 0.0;

    void recalc(void Function(void Function()) setSheetState) {
      setSheetState(() {
        quantity = int.tryParse(qtyController.text.trim()) ?? quantity;
        if (quantity <= 0) quantity = 1;
        unitPrice = double.tryParse(priceController.text.trim()) ?? unitPrice;
        if (!unitPrice.isFinite || unitPrice < 0) unitPrice = 0.0;
      });
    }

    final result = await _showEditorSheet<_LineItemSheetResult>(
      title: 'Edit Line Item',
      primaryButtonText: 'Save',
      showDelete: index != null,
      onDelete: () {
        if (index == null) return null;
        if (_draft.items.length <= 1) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Keep at least one line item')),
          );
          return null;
        }
        return _LineItemSheetResult(deleteIndex: index);
      },
      builder: (context, setSheetState) {
        return Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Enter item name'),
              onChanged: (_) => recalc(setSheetState),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
              ),
              onChanged: (_) => recalc(setSheetState),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantity'),
              onChanged: (_) => recalc(setSheetState),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Unit Price (\$)'),
              onChanged: (_) => recalc(setSheetState),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Line Total:',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    (quantity * unitPrice).toStringAsFixed(2),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
      onPrimary: () {
        final name = nameController.text.trim();
        final details = descController.text.trim();

        final desc = _composeLineItemDescription(name: name, details: details);
        final q = int.tryParse(qtyController.text.trim()) ?? 1;
        final p = double.tryParse(priceController.text.trim()) ?? 0.0;

        return _LineItemSheetResult(
          index: index,
          item: InvoiceLineItem(
            description: desc.isEmpty ? 'Service' : desc,
            quantity: q <= 0 ? 1 : q,
            unitPrice: p.isFinite && p >= 0 ? p : 0.0,
          ),
        );
      },
    );

    if (result == null) return;
    if (result.deleteIndex != null) {
      setState(() {
        final next = [..._draft.items]..removeAt(result.deleteIndex!);
        _draft = _draft.copyWith(items: next);
      });
      return;
    }

    final item = result.item;
    if (item == null) return;

    setState(() {
      final items = [..._draft.items];
      final uiIsEmpty = _isDefaultSingleLineItem(items);
      if (result.index == null) {
        if (uiIsEmpty) {
          _draft = _draft.copyWith(items: [item]);
        } else {
          _draft = _draft.copyWith(items: [...items, item]);
        }
      } else {
        items[result.index!] = item;
        _draft = _draft.copyWith(items: items);
      }
    });
  }

  String _lineItemName(String description) {
    final parts = description.split('\n');
    return parts.isEmpty ? description : parts.first.trim();
  }

  String _lineItemDetails(String description) {
    final parts = description.split('\n');
    if (parts.length <= 1) return '';
    return parts.sublist(1).join('\n').trim();
  }

  String _composeLineItemDescription({required String name, String? details}) {
    final cleanName = name.trim();
    final cleanDetails = (details ?? '').trim();
    if (cleanDetails.isEmpty) return cleanName;
    if (cleanName.isEmpty) return cleanDetails;
    return '$cleanName\n$cleanDetails';
  }

  Future<void> _selectPaymentMethodSheet() async {
    const methods = <String>[
      'Cash',
      'Credit Card',
      'ACH Transfer',
      'Paypal',
      'Venmo',
      'Zelle',
      'Square',
      'Check',
    ];

    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                    const Expanded(
                      child: Text(
                        'Select Payment Method',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: methods
                      .map(
                        (m) => ListTile(
                          title: Text(m),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.pop(context, m),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selected == null) return;

    setState(() {
      if (!_paymentMethods.contains(selected)) {
        _paymentMethods.add(selected);
      }
    });
  }

  Future<void> _addPhotoDialog() async {
    final choice = await showDialog<_AddPhotoChoice>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Photo'),
          content: const Text('Choose an option'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, _AddPhotoChoice.gallery),
              child: const Text('CHOOSE FROM GALLERY'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, _AddPhotoChoice.camera),
              child: const Text('TAKE PHOTO'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, _AddPhotoChoice.cancel),
              child: const Text('CANCEL'),
            ),
          ],
        );
      },
    );

    if (choice == null || choice == _AddPhotoChoice.cancel) return;

    try {
      if (choice == _AddPhotoChoice.gallery) {
        final picks = await _imagePicker.pickMultiImage();
        if (picks.isEmpty) return;
        setState(() => _photos.addAll(picks));
      } else {
        final pick = await _imagePicker.pickImage(source: ImageSource.camera);
        if (pick == null) return;
        setState(() => _photos.add(pick));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Couldn\'t add photo: $e')));
    }
  }

  Future<void> _openPreview() async {
    _syncDraftFromControllers();

    final result = await context.push<InvoicePreviewResult>(
      '/invoice-preview',
      extra: {
        'draft': _draft,
        'issuedDate': _issuedDate,
        'total': _total,
        'buildPdf': () async {
          final args = <String, dynamic>{
            'draft': _draft.toJson(),
            'issuedDateIso': _issuedDate.toIso8601String(),
            'discount': _discount,
            'taxRatePercent': _taxRatePercent,
          };

          if (kIsWeb) {
            return await buildInvoicePdfBytesFromJson(args);
          }
          return compute(buildInvoicePdfBytesFromJson, args);
        },
      },
    );

    if (!mounted) return;
    final completed =
        result == InvoicePreviewResult.downloaded ||
        result == InvoicePreviewResult.sent;
    if (completed) {
      setState(() => _completed = true);
    }
  }

  String _formatDate(BuildContext context, DateTime value) {
    return MaterialLocalizations.of(context).formatShortDate(value);
  }

  double get _subtotal => _draft.subtotal;

  double get _taxAmount {
    final taxable = (_subtotal - _discount);
    if (taxable <= 0) return 0.0;
    return taxable * (_taxRatePercent / 100.0);
  }

  double get _total {
    final total = _subtotal - _discount + _taxAmount;
    return total.isFinite && total > 0 ? total : 0.0;
  }

  Map<String, Object?> _draftFingerprint(InvoiceDraft draft) {
    return {
      'clientName': draft.clientName.trim(),
      'clientEmail': draft.clientEmail.trim(),
      'clientPhone': draft.clientPhone.trim(),
      'clientAddress': draft.clientAddress.trim(),
      'jobTitle': draft.jobTitle.trim(),
      'jobDescription': draft.jobDescription.trim(),
      'notes': draft.notes.trim(),
      'paymentTerms': draft.paymentTerms.trim(),
      'items': draft.items
          .map(
            (it) => {
              'description': it.description.trim(),
              'quantity': it.quantity,
              'unitPrice': it.unitPrice,
            },
          )
          .toList(growable: false),
    };
  }

  bool _isDefaultSingleLineItem(List<InvoiceLineItem> items) {
    if (items.length != 1) return false;
    final it = items.first;
    return it.description.trim().toLowerCase() == 'service' &&
        it.quantity == 1 &&
        it.unitPrice == 0.0;
  }

  bool _isMeaningfulDraft(InvoiceDraft draft) {
    final hasText =
        draft.clientName.trim().isNotEmpty ||
        draft.clientEmail.trim().isNotEmpty ||
        draft.clientPhone.trim().isNotEmpty ||
        draft.clientAddress.trim().isNotEmpty ||
        draft.jobTitle.trim().isNotEmpty ||
        draft.jobDescription.trim().isNotEmpty ||
        draft.notes.trim().isNotEmpty;

    final paymentTerms = draft.paymentTerms.trim();
    final hasNonDefaultPaymentTerms =
        paymentTerms.isNotEmpty && paymentTerms != 'Due upon receipt';

    final hasNonDefaultItems = !_isDefaultSingleLineItem(draft.items);
    final hasPricedItems = draft.items.any((x) => x.unitPrice > 0);

    return hasText ||
        hasNonDefaultPaymentTerms ||
        hasNonDefaultItems ||
        hasPricedItems;
  }

  void _showDraftSaveWarningOnce(String message) {
    if (!mounted) return;
    if (_shownDraftSaveWarning) return;
    _shownDraftSaveWarning = true;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  bool _isPermissionDeniedError(Object error) {
    if (error is FirebaseException) {
      return error.code.toLowerCase() == 'permission-denied';
    }
    return error.toString().toLowerCase().contains('permission-denied');
  }

  Future<void> _saveDraftIfNeededAndPop() async {
    if (!mounted) return;
    if (_loading || _savingDraft) return;

    _syncDraftFromControllers();

    if (_completed || !_isMeaningfulDraft(_draft)) {
      _requestPop();
      return;
    }

    final currentFingerprint = _draftFingerprint(_draft);
    final changedSinceLastSave =
        currentFingerprint.toString() != _lastSavedFingerprint.toString();

    if (!changedSinceLastSave && _everSavedDraft) {
      _requestPop();
      return;
    }

    setState(() => _savingDraft = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showDraftSaveWarningOnce('Draft not saved (sign in required).');
        _requestPop();
        return;
      }

      final draftId = _draft.invoiceNumber.trim().isEmpty
          ? DateTime.now().millisecondsSinceEpoch.toString()
          : _draft.invoiceNumber.trim();

      final doc = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('invoice_drafts')
          .doc(draftId);

      final payload = <String, Object?>{
        'status': 'draft',
        'updatedAt': FieldValue.serverTimestamp(),
        'draft': _draft.toJson(),
      };
      if (!_everSavedDraft) {
        payload['createdAt'] = FieldValue.serverTimestamp();
      }

      await doc.set(payload, SetOptions(merge: true));

      _everSavedDraft = true;
      _lastSavedFingerprint = currentFingerprint;

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Saved draft.')));
      _requestPop();
    } catch (e) {
      if (!mounted) return;
      if (_isPermissionDeniedError(e)) {
        _showDraftSaveWarningOnce('Draft not saved (no Firestore permission).');
      } else {
        _showDraftSaveWarningOnce('Draft not saved.');
      }
      _requestPop();
    } finally {
      if (mounted) setState(() => _savingDraft = false);
    }
  }

  Future<T?> _showEditorSheet<T>({
    required String title,
    required String primaryButtonText,
    required Widget Function(
      BuildContext context,
      void Function(void Function()) setState,
    )
    builder,
    required T Function() onPrimary,
    bool showDelete = false,
    T? Function()? onDelete,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                        Expanded(
                          child: Text(
                            title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (showDelete)
                          IconButton(
                            onPressed: () {
                              if (onDelete == null) return;
                              final res = onDelete();
                              if (res == null) return;
                              Navigator.pop(context, res);
                            },
                            icon: const Icon(
                              Icons.delete,
                              color: Color(0xFFE74C3C),
                            ),
                          )
                        else
                          const SizedBox(width: 48),
                      ],
                    ),
                    const SizedBox(height: 8),
                    builder(context, setSheetState),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF00A8C6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context, onPrimary()),
                        child: Text(
                          primaryButtonText,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _sectionHeader({required String title, bool requiredField = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        if (requiredField)
          const Text(
            '* Required',
            style: TextStyle(
              color: Color(0xFFE74C3C),
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }

  Widget _dashedAddTile({required VoidCallback onTap}) {
    return _DashedBorder(
      borderRadius: 12,
      color: Colors.black26,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          height: 64,
          width: double.infinity,
          child: Center(
            child: Icon(Icons.add, color: const Color(0xFF00A8C6), size: 30),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stateKey = _loading
        ? 'loading'
        : (_error != null && _error!.trim().isNotEmpty)
        ? 'error'
        : 'ready';

    final scheme = Theme.of(context).colorScheme;

    final itemsForUi = _isDefaultSingleLineItem(_draft.items)
        ? const <InvoiceLineItem>[]
        : _draft.items;
    final canProceed =
        _draft.clientName.trim().isNotEmpty && itemsForUi.isNotEmpty;

    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _saveDraftIfNeededAndPop();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF0C1B3A),
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
          actionsIconTheme: const IconThemeData(color: Colors.white),
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
          systemOverlayStyle: SystemUiOverlayStyle.light,
          leading: IconButton(
            tooltip: 'Back',
            onPressed: _savingDraft ? null : _saveDraftIfNeededAndPop,
            icon: const Icon(Icons.arrow_back),
          ),
          centerTitle: true,
          title: const Text(
            'Create Invoice',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
          actions: [
            IconButton(
              tooltip: 'AI Assist',
              onPressed: _loading ? null : _generateWithAi,
              icon: const Icon(Icons.auto_awesome),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: SizedBox(
              height: 58,
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: canProceed
                      ? const Color(0xFF22E39B)
                      : const Color(0xFF142647),
                  foregroundColor: canProceed
                      ? const Color(0xFF041016)
                      : const Color(0xFF9FB2D4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: canProceed ? _openPreview : null,
                child: const Text(
                  'Next',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            children: [
              AnimatedStateSwitcher(
                stateKey: 'invoice_state_$stateKey',
                child: _loading
                    ? Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Drafting with AI…',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 10),
                              const LinearProgressIndicator(),
                            ],
                          ),
                        ),
                      )
                    : (_error != null && _error!.trim().isNotEmpty)
                    ? EmptyStateCard(
                        icon: Icons.error_outline,
                        title: 'AI assist failed',
                        subtitle: _error!,
                        action: OutlinedButton.icon(
                          onPressed: _generateWithAi,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try again'),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              if (_loading || (_error != null && _error!.trim().isNotEmpty))
                const SizedBox(height: 12),
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Import from estimate coming soon.'),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 18,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDBF3F8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.file_download_outlined,
                        color: Color(0xFF00A8C6),
                        size: 30,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Import from estimate',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: const Color(0xFF00A8C6),
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _DateOrValueBox(
                      label: 'Issued',
                      value: _formatDate(context, _issuedDate),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _issuedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked == null) return;
                        setState(() => _issuedDate = picked);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DateOrValueBox(
                      label: 'Due',
                      value: _draft.dueDate == null
                          ? '—'
                          : _formatDate(context, _draft.dueDate!),
                      onTap: () async {
                        final initial =
                            _draft.dueDate ??
                            _issuedDate.add(const Duration(days: 30));
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: initial,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked == null) return;
                        setState(
                          () => _draft = _draft.copyWith(dueDate: picked),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DateOrValueBox(
                      label: 'Invoice #',
                      value: _draft.invoiceNumber.split('-').last,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Invoice #: ${_draft.invoiceNumber}'),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _sectionHeader(title: 'Client', requiredField: true),
              const SizedBox(height: 10),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: _editClientSheet,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    hintText: 'Select client…',
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _draft.clientName.trim().isEmpty
                              ? 'Select client…'
                              : _draft.clientName,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: _draft.clientName.trim().isEmpty
                                    ? scheme.onSurfaceVariant
                                    : scheme.onSurface,
                              ),
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _sectionHeader(title: 'Items', requiredField: true),
              const SizedBox(height: 10),
              if (itemsForUi.isNotEmpty) ...[
                ...itemsForUi.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final it = entry.value;
                  return Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(_lineItemName(it.description)),
                        subtitle: Text(
                          '${it.quantity} × ${it.unitPrice.toStringAsFixed(2)}',
                        ),
                        trailing: Text(it.total.toStringAsFixed(2)),
                        onTap: () => _editLineItemSheet(index: idx),
                      ),
                      const Divider(height: 1),
                    ],
                  );
                }),
                const SizedBox(height: 10),
              ],
              _dashedAddTile(onTap: () => _editLineItemSheet()),
              const SizedBox(height: 18),
              _sectionHeader(title: 'Payment Methods'),
              const SizedBox(height: 10),
              if (_paymentMethods.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _paymentMethods
                      .map(
                        (m) => InputChip(
                          label: Text(m),
                          onDeleted: () =>
                              setState(() => _paymentMethods.remove(m)),
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: 10),
              ],
              _dashedAddTile(onTap: _selectPaymentMethodSheet),
              const SizedBox(height: 18),
              _sectionHeader(title: 'Photos'),
              const SizedBox(height: 10),
              if (_photos.isNotEmpty) ...[
                Text(
                  '${_photos.length} photo${_photos.length == 1 ? '' : 's'} added',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              _dashedAddTile(onTap: _addPhotoDialog),
              const SizedBox(height: 18),
              _sectionHeader(title: 'Payment Schedule'),
              const SizedBox(height: 10),
              _dashedAddTile(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Payment schedule coming soon.'),
                    ),
                  );
                },
              ),
              const SizedBox(height: 18),
              _sectionHeader(title: 'Notes'),
              const SizedBox(height: 10),
              _dashedAddTile(onTap: _editNotesSheet),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: scheme.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('Subtotal'),
                      trailing: Text('\$${_subtotal.toStringAsFixed(2)}'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('Discount'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('\$${_discount.toStringAsFixed(2)}'),
                          const SizedBox(width: 6),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                      onTap: () async {
                        final controller = TextEditingController(
                          text: _discount.toStringAsFixed(2),
                        );
                        final next = await showDialog<double>(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: const Text('Discount'),
                              content: TextField(
                                controller: controller,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Amount',
                                  prefixText: '\$',
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () {
                                    final v =
                                        double.tryParse(
                                          controller.text.trim(),
                                        ) ??
                                        0.0;
                                    Navigator.pop(context, v);
                                  },
                                  child: const Text('Save'),
                                ),
                              ],
                            );
                          },
                        );
                        if (next == null) return;
                        setState(() {
                          _discount = next.isFinite && next >= 0 ? next : 0.0;
                        });
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('Tax (excl.)'),
                      subtitle: Text(
                        '${_taxRatePercent.toStringAsFixed(0)}% of \$${(_subtotal - _discount).clamp(0, double.infinity).toStringAsFixed(2)}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('\$${_taxAmount.toStringAsFixed(2)}'),
                          const SizedBox(width: 6),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                      onTap: () async {
                        final controller = TextEditingController(
                          text: _taxRatePercent.toStringAsFixed(0),
                        );
                        final next = await showDialog<double>(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: const Text('Tax rate'),
                              content: TextField(
                                controller: controller,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Percent',
                                  suffixText: '%',
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () {
                                    final v =
                                        double.tryParse(
                                          controller.text.trim(),
                                        ) ??
                                        0.0;
                                    Navigator.pop(context, v);
                                  },
                                  child: const Text('Save'),
                                ),
                              ],
                            );
                          },
                        );
                        if (next == null) return;
                        setState(() {
                          _taxRatePercent = next.isFinite && next >= 0
                              ? next
                              : 0.0;
                        });
                      },
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE9E9E9),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            '\$${_total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LineItemSheetResult {
  final int? index;
  final InvoiceLineItem? item;
  final int? deleteIndex;

  const _LineItemSheetResult({this.index, this.item, this.deleteIndex});
}

enum _AddPhotoChoice { gallery, camera, cancel }

class _DateOrValueBox extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _DateOrValueBox({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black12),
          borderRadius: BorderRadius.circular(10),
          color: Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedBorder extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final Color color;

  const _DashedBorder({
    required this.child,
    required this.borderRadius,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(radius: borderRadius, color: color),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: child,
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final double radius;
  final Color color;

  _DashedBorderPainter({required this.radius, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = color
      ..strokeWidth = 1.2;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    const dashWidth = 6.0;
    const dashSpace = 4.0;
    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.radius != radius || oldDelegate.color != color;
  }
}
