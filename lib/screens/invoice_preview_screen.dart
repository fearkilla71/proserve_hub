import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models/invoice_models.dart';

enum InvoicePreviewResult { none, downloaded, sent }

class InvoicePreviewScreen extends StatefulWidget {
  final InvoiceDraft draft;
  final DateTime issuedDate;
  final double total;
  final Future<Uint8List> Function() buildPdf;

  const InvoicePreviewScreen({
    super.key,
    required this.draft,
    required this.issuedDate,
    required this.total,
    required this.buildPdf,
  });

  @override
  State<InvoicePreviewScreen> createState() => _InvoicePreviewScreenState();
}

class _InvoicePreviewScreenState extends State<InvoicePreviewScreen> {
  bool _busy = false;
  final Completer<Uint8List> _pdfBytesCompleter = Completer<Uint8List>();
  late final Future<Uint8List> _pdfBytesFuture = _pdfBytesCompleter.future;
  late bool _showPdfPreview;
  double _paid = 0.0;
  final List<_PaymentRecord> _payments = <_PaymentRecord>[];

  bool _loadingRemote = false;
  String? _remoteError;

  User? get _user => FirebaseAuth.instance.currentUser;

  DocumentReference<Map<String, dynamic>>? get _invoiceDoc {
    final u = _user;
    if (u == null) return null;

    final invoiceId = widget.draft.invoiceNumber.trim().isEmpty
        ? DateTime.now().millisecondsSinceEpoch.toString()
        : widget.draft.invoiceNumber.trim();

    return FirebaseFirestore.instance
        .collection('users')
        .doc(u.uid)
        .collection('invoices')
        .doc(invoiceId);
  }

  CollectionReference<Map<String, dynamic>>? get _paymentsCol {
    final doc = _invoiceDoc;
    if (doc == null) return null;
    return doc.collection('payments');
  }

  double get _due =>
      (widget.total - _paid).clamp(0.0, double.infinity).toDouble();

  String _formatMoney(double v) => v.toStringAsFixed(2);

  String _formatIsoDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  @override
  void initState() {
    super.initState();

    // PdfPreview can trigger expensive native rasterization on touch/scroll.
    // On some emulators this can stall the Android main thread long enough to
    // cause input-dispatch ANRs. Keep it enabled in release, but make it opt-in
    // in debug.
    const enablePdfPreviewInDebug = bool.fromEnvironment(
      'ENABLE_PDF_PREVIEW_DEBUG',
    );
    _showPdfPreview = !kDebugMode || enablePdfPreviewInDebug;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final bytes = await widget.buildPdf();
        if (!_pdfBytesCompleter.isCompleted) {
          _pdfBytesCompleter.complete(bytes);
        }
      } catch (e, st) {
        if (!_pdfBytesCompleter.isCompleted) {
          _pdfBytesCompleter.completeError(e, st);
        }
      }
    });
    _bootstrapRemote();
  }

  Future<void> _bootstrapRemote() async {
    final doc = _invoiceDoc;
    final paymentsCol = _paymentsCol;
    if (doc == null || paymentsCol == null) return;

    setState(() {
      _loadingRemote = true;
      _remoteError = null;
    });

    try {
      // Ensure invoice doc exists.
      final snap = await doc.get();

      final dueDate =
          widget.draft.dueDate ??
          widget.issuedDate.add(const Duration(days: 30));

      final payload = <String, Object?>{
        'invoiceNumber': widget.draft.invoiceNumber,
        'issuedDateISO': widget.issuedDate.toIso8601String(),
        'dueDateISO': dueDate.toIso8601String(),
        'currency': widget.draft.currency,
        'total': widget.total,
        'draft': widget.draft.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (!snap.exists) {
        payload['createdAt'] = FieldValue.serverTimestamp();
        payload['status'] = 'unpaid';
        payload['paidAmount'] = 0.0;
      }
      await doc.set(payload, SetOptions(merge: true));

      // Load remote payments.
      final paymentsSnap = await paymentsCol
          .orderBy('dateISO', descending: true)
          .get();
      final loaded = <_PaymentRecord>[];
      double sum = 0.0;

      for (final d in paymentsSnap.docs) {
        final data = d.data();
        final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
        final method = (data['method'] ?? '').toString().trim();
        final dateIso = (data['dateISO'] ?? '').toString().trim();
        final notes = (data['notes'] ?? '').toString().trim();

        DateTime date = DateTime.now();
        if (dateIso.isNotEmpty) {
          date = DateTime.tryParse(dateIso) ?? date;
        }

        loaded.add(
          _PaymentRecord(
            amount: amount,
            method: method.isEmpty ? null : method,
            date: date,
            notes: notes,
          ),
        );
        sum += amount;
      }

      final paid = sum.clamp(0.0, widget.total).toDouble();

      // Best-effort: keep paid/status on invoice doc in sync with computed sum.
      final status = _statusFor(paid: paid, total: widget.total);
      await doc.set({
        'paidAmount': paid,
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() {
        _payments
          ..clear()
          ..addAll(loaded);
        _paid = paid;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _remoteError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingRemote = false);
    }
  }

  String _statusFor({required double paid, required double total}) {
    if (total <= 0) return 'unpaid';
    if (paid <= 0.005) return 'unpaid';
    if ((total - paid).abs() <= 0.005) return 'paid';
    return 'partial';
  }

  Future<void> _markInvoiceAction(String field) async {
    final doc = _invoiceDoc;
    if (doc == null) return;
    try {
      await doc.set({
        field: FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Best-effort only.
    }
  }

  Future<void> _deleteDraftBestEffort() async {
    final u = _user;
    if (u == null) return;

    final draftId = widget.draft.invoiceNumber.trim();
    if (draftId.isEmpty) return;

    final draftDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(u.uid)
        .collection('invoice_drafts')
        .doc(draftId);

    try {
      await draftDoc.delete();
    } catch (_) {
      // Best-effort only.
    }
  }

  Future<void> _downloadPdf() async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final bytes = await _pdfBytesFuture;

      final dir = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Folder',
      );
      if (dir == null || dir.trim().isEmpty) return;

      final name =
          '${widget.draft.invoiceNumber.isEmpty ? 'invoice' : widget.draft.invoiceNumber}.pdf';
      final target = File('$dir${Platform.pathSeparator}$name');
      await target.writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Saved to ${target.path}')));

      await _markInvoiceAction('downloadedAt');
      await _deleteDraftBestEffort();

      if (!mounted) return;
      Navigator.pop(context, InvoicePreviewResult.downloaded);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Couldn\'t download: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendInvoice() async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final bytes = await _pdfBytesFuture;
      final name =
          '${widget.draft.invoiceNumber.isEmpty ? 'invoice' : widget.draft.invoiceNumber}.pdf';

      await Share.shareXFiles([
        XFile.fromData(bytes, name: name, mimeType: 'application/pdf'),
      ], text: 'Invoice ${widget.draft.invoiceNumber}');

      if (!mounted) return;
      await _markInvoiceAction('sentAt');
      await _deleteDraftBestEffort();
      if (!mounted) return;
      Navigator.pop(context, InvoicePreviewResult.sent);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Couldn\'t send invoice: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _recordPaymentSheet() async {
    final amount = TextEditingController(text: _due.toStringAsFixed(0));
    final notes = TextEditingController();

    String? method;
    DateTime date = DateTime.now();

    final ok = await showModalBottomSheet<bool>(
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context, false),
                          icon: const Icon(Icons.close),
                        ),
                        const Expanded(
                          child: Text(
                            'Record Payment',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Amount',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: amount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Payment Method',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () async {
                        final selected = await showModalBottomSheet<String>(
                          context: context,
                          showDragHandle: true,
                          builder: (context) {
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

                            return SafeArea(
                              child: ListView(
                                shrinkWrap: true,
                                children: methods
                                    .map(
                                      (m) => ListTile(
                                        title: Text(m),
                                        trailing: const Icon(
                                          Icons.chevron_right,
                                        ),
                                        onTap: () => Navigator.pop(context, m),
                                      ),
                                    )
                                    .toList(growable: false),
                              ),
                            );
                          },
                        );

                        if (selected == null) return;
                        setSheetState(() => method = selected);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Select payment method',
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                method ?? 'Select payment method',
                                style: TextStyle(
                                  color: method == null
                                      ? Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Date',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: date,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked == null) return;
                        setSheetState(() => date = picked);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          MaterialLocalizations.of(
                            context,
                          ).formatMediumDate(date),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Notes',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: notes,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Add details…',
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF00A8C6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(context, true);
                        },
                        child: const Text(
                          'Save',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
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

    if (ok != true) return;

    final amt = double.tryParse(amount.text.trim()) ?? 0.0;
    if (amt <= 0) return;

    final record = _PaymentRecord(
      amount: amt,
      method: method,
      date: date,
      notes: notes.text.trim(),
    );

    final doc = _invoiceDoc;
    final paymentsCol = _paymentsCol;
    if (doc == null || paymentsCol == null) {
      // Local-only fallback.
      setState(() {
        _payments.add(record);
        _paid = (_paid + amt).clamp(0.0, widget.total).toDouble();
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to save payment history.')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final paymentRef = paymentsCol.doc();
      final newPaid = (_paid + amt).clamp(0.0, widget.total).toDouble();
      final newStatus = _statusFor(paid: newPaid, total: widget.total);

      await FirebaseFirestore.instance.runTransaction((tx) async {
        tx.set(paymentRef, {
          'amount': amt,
          'method': method,
          'dateISO': date.toIso8601String(),
          'notes': notes.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });

        tx.set(doc, {
          'paidAmount': newPaid,
          'status': newStatus,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });

      if (!mounted) return;
      setState(() {
        _payments.add(record);
        _paid = newPaid;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Couldn\'t save payment: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unpaid = _due > 0.005;
    final dueDate =
        widget.draft.dueDate ?? widget.issuedDate.add(const Duration(days: 30));
    final dueInDays = dueDate.difference(DateTime.now()).inDays;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C1B3A),
        foregroundColor: Colors.white,
        title: const Text(
          'Preview Invoice',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.more_horiz)),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: _showPdfPreview
                ? PdfPreview(
                    build: (_) => _pdfBytesFuture,
                    allowPrinting: false,
                    allowSharing: false,
                    canChangeOrientation: false,
                    canChangePageFormat: false,
                    pdfFileName:
                        '${widget.draft.invoiceNumber.isEmpty ? 'invoice' : widget.draft.invoiceNumber}.pdf',
                  )
                : Container(
                    color: const Color(0xFF0C172C),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 150),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.picture_as_pdf_outlined,
                            size: 44,
                            color: Color(0xFF0C1B3A),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'PDF preview disabled in debug',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'This avoids emulator ANRs caused by heavy native PDF rasterization.\n\nTo enable: run with ENABLE_PDF_PREVIEW_DEBUG=true',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.black54,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            onPressed: () =>
                                setState(() => _showPdfPreview = true),
                            icon: const Icon(Icons.visibility_outlined),
                            label: const Text('Render preview now'),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          Positioned(
            top: 14,
            right: 16,
            child: TextButton.icon(
              onPressed: _busy ? null : _downloadPdf,
              icon: const Icon(Icons.download, color: Color(0xFF00A8C6)),
              label: const Text(
                'Download',
                style: TextStyle(
                  color: Color(0xFF00A8C6),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.32,
            minChildSize: 0.24,
            maxChildSize: 0.62,
            builder: (context, controller) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 14,
                      color: Color(0x22000000),
                      offset: Offset(0, -3),
                    ),
                  ],
                ),
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  children: [
                    if (_remoteError != null && _remoteError!.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          'Couldn\'t load invoice history: $_remoteError',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    else if (_loadingRemote)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: LinearProgressIndicator(minHeight: 2.5),
                      ),
                    Center(
                      child: Container(
                        width: 46,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.black12,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Icon(
                          Icons.receipt_long_outlined,
                          color: Color(0xFF00A8C6),
                          size: 26,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'TOTAL',
                                style: TextStyle(
                                  letterSpacing: 0.5,
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '\$${_formatMoney(widget.total)}',
                                style: const TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                dueInDays >= 0
                                    ? 'Due in $dueInDays days'
                                    : 'Due ${_formatIsoDate(dueDate)}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            unpaid ? 'Unpaid' : 'Paid',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 58,
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF00A8C6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: _busy ? null : _sendInvoice,
                        child: _busy
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Send Invoice',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 58,
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: Color(0xFF00A8C6),
                            width: 3,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: () =>
                            Navigator.pop(context, InvoicePreviewResult.none),
                        child: const Text(
                          'Edit',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF00A8C6),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      tileColor: const Color(0xFF101E38),
                      title: const Text(
                        'Record Payment',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _recordPaymentSheet,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.black12),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Transaction History',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.black12,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Due:',
                                style: TextStyle(fontSize: 18),
                              ),
                              Text(
                                '\$${_formatMoney(_due)}',
                                style: const TextStyle(fontSize: 18),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Paid:',
                                style: TextStyle(fontSize: 18),
                              ),
                              Text(
                                '\$${_formatMoney(_paid)}',
                                style: const TextStyle(fontSize: 18),
                              ),
                            ],
                          ),
                          if (_payments.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            ..._payments.map(
                              (p) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${_formatIsoDate(p.date)} • ${p.method ?? 'Payment'}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '\$${_formatMoney(p.amount)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PaymentRecord {
  final double amount;
  final String? method;
  final DateTime date;
  final String notes;

  const _PaymentRecord({
    required this.amount,
    required this.method,
    required this.date,
    required this.notes,
  });
}
