import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/job_expense_service.dart';
import '../../services/receipt_ocr_service.dart';

class AddExpensePage extends StatefulWidget {
  final String jobId;
  final String createdByRole;

  const AddExpensePage({
    super.key,
    required this.jobId,
    required this.createdByRole,
  });

  @override
  State<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends State<AddExpensePage> {
  final _vendorCtrl = TextEditingController();
  final _totalCtrl = TextEditingController();
  final _taxCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  DateTime? _receiptDate;
  File? _imageFile;
  String _ocrText = '';

  bool _isScanning = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _vendorCtrl.dispose();
    _totalCtrl.dispose();
    _taxCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 2000,
    );
    if (x == null) return;

    setState(() {
      _imageFile = File(x.path);
      _ocrText = '';
    });
  }

  Future<void> _scan() async {
    final image = _imageFile;
    if (image == null) return;

    setState(() => _isScanning = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final ocr = ReceiptOcrService();
      final res = await ocr.recognizeFromImageFile(image);

      setState(() {
        _ocrText = res.rawText;
        if ((_vendorCtrl.text).trim().isEmpty) {
          _vendorCtrl.text = res.vendor ?? '';
        }
        _receiptDate ??= res.date;
        if ((_totalCtrl.text).trim().isEmpty && res.total != null) {
          _totalCtrl.text = res.total!.toStringAsFixed(2);
        }
        if ((_taxCtrl.text).trim().isEmpty && res.tax != null) {
          _taxCtrl.text = res.tax!.toStringAsFixed(2);
        }
      });

      messenger.showSnackBar(const SnackBar(content: Text('Scan complete.')));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Scan failed: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _save() async {
    final image = _imageFile;
    if (image == null) return;

    double? parseMoney(String s) {
      final cleaned = s.trim().replaceAll(',', '');
      if (cleaned.isEmpty) return null;
      return double.tryParse(cleaned);
    }

    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    try {
      await JobExpenseService().addExpense(
        jobId: widget.jobId,
        imageFile: image,
        createdByRole: widget.createdByRole,
        vendor: _vendorCtrl.text.trim().isEmpty
            ? null
            : _vendorCtrl.text.trim(),
        receiptDate: _receiptDate,
        total: parseMoney(_totalCtrl.text),
        tax: parseMoney(_taxCtrl.text),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        ocrText: _ocrText.isEmpty ? null : _ocrText,
      );

      messenger.showSnackBar(const SnackBar(content: Text('Saved receipt.')));
      nav.pop();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Save failed: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _receiptDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 1),
    );
    if (picked == null) return;
    setState(() => _receiptDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final image = _imageFile;

    return Scaffold(
      appBar: AppBar(title: const Text('Add Receipt')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: FilledButton.tonal(
                  onPressed: _isSaving ? null : () => _pick(ImageSource.camera),
                  child: const Text('Camera'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonal(
                  onPressed: _isSaving
                      ? null
                      : () => _pick(ImageSource.gallery),
                  child: const Text('Gallery'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (image != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(image, height: 220, fit: BoxFit.cover),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: (_isScanning || _isSaving) ? null : _scan,
              icon: _isScanning
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.document_scanner),
              label: const Text('Scan Text'),
            ),
          ] else ...[
            const Text('Add a receipt photo to scan and save.'),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _vendorCtrl,
            decoration: const InputDecoration(
              labelText: 'Vendor',
              border: OutlineInputBorder(),
            ),
            enabled: !_isSaving,
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _isSaving ? null : _pickDate,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Receipt Date',
                border: OutlineInputBorder(),
              ),
              child: Text(
                _receiptDate == null
                    ? 'Select date'
                    : '${_receiptDate!.month}/${_receiptDate!.day}/${_receiptDate!.year}',
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _totalCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Total',
                    border: OutlineInputBorder(),
                  ),
                  enabled: !_isSaving,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _taxCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Tax',
                    border: OutlineInputBorder(),
                  ),
                  enabled: !_isSaving,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notes',
              border: OutlineInputBorder(),
            ),
            enabled: !_isSaving,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: (image == null || _isSaving) ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
    );
  }
}
