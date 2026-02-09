import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/invoice_models.dart';

/// Top-level function so it can be used with `compute`.
///
/// Expected args:
/// - draft: `Map<String, dynamic>` (`InvoiceDraft.toJson()`)
/// - issuedDateIso: String
/// - discount: num
/// - taxRatePercent: num
Future<Uint8List> buildInvoicePdfBytesFromJson(
  Map<String, dynamic> args,
) async {
  final draftRaw = args['draft'];
  final issuedDateIso = (args['issuedDateIso'] ?? '').toString();

  final draft = (draftRaw is Map)
      ? InvoiceDraft.fromJson(draftRaw.map((k, v) => MapEntry(k.toString(), v)))
      : InvoiceDraft.empty();

  final issuedDate = DateTime.tryParse(issuedDateIso) ?? DateTime.now();

  final discount = (args['discount'] is num)
      ? (args['discount'] as num).toDouble()
      : 0.0;
  final taxRatePercent = (args['taxRatePercent'] is num)
      ? (args['taxRatePercent'] as num).toDouble()
      : 0.0;

  final doc = pw.Document();

  final h1 = pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold);
  final label = pw.TextStyle(fontSize: 10, color: PdfColors.grey700);

  final subtotal = draft.subtotal;
  final safeDiscount = discount.isFinite && discount > 0 ? discount : 0.0;
  final taxable = (subtotal - safeDiscount) > 0 ? (subtotal - safeDiscount) : 0;
  final safeTaxRate = taxRatePercent.isFinite && taxRatePercent > 0
      ? taxRatePercent
      : 0.0;
  final taxAmount = taxable * (safeTaxRate / 100.0);
  final total = (subtotal - safeDiscount + taxAmount) > 0
      ? (subtotal - safeDiscount + taxAmount)
      : 0.0;

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.letter,
      build: (context) {
        return [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    draft.businessName.isEmpty
                        ? 'ProServe Hub Contractor'
                        : draft.businessName,
                    style: h1,
                  ),
                  if (draft.businessEmail.trim().isNotEmpty)
                    pw.Text(draft.businessEmail),
                  if (draft.businessPhone.trim().isNotEmpty)
                    pw.Text(draft.businessPhone),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Invoice', style: h1),
                  pw.SizedBox(height: 4),
                  pw.Text('Invoice #: ${draft.invoiceNumber}', style: label),
                  pw.Text(
                    'Issued: ${issuedDate.toIso8601String().split('T').first}',
                    style: label,
                  ),
                  if (draft.dueDate != null)
                    pw.Text(
                      'Due: ${draft.dueDate!.toIso8601String().split('T').first}',
                      style: label,
                    ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Bill to',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(draft.clientName.isEmpty ? 'Client' : draft.clientName),
          if (draft.clientEmail.trim().isNotEmpty) pw.Text(draft.clientEmail),
          if (draft.clientPhone.trim().isNotEmpty) pw.Text(draft.clientPhone),
          if (draft.clientAddress.trim().isNotEmpty)
            pw.Text(draft.clientAddress),
          pw.SizedBox(height: 16),
          if (draft.jobTitle.trim().isNotEmpty) ...[
            pw.Text(
              draft.jobTitle,
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
          ],
          if (draft.jobDescription.trim().isNotEmpty)
            pw.Text(draft.jobDescription),
          pw.SizedBox(height: 16),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: {
              0: const pw.FlexColumnWidth(5),
              1: const pw.FlexColumnWidth(1.5),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      'Item',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      'Qty',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      'Unit',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      'Total',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                ],
              ),
              ...draft.items.map((it) {
                return pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(it.description),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(it.quantity.toString()),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(it.unitPrice.toStringAsFixed(2)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(it.total.toStringAsFixed(2)),
                    ),
                  ],
                );
              }),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Container(
                width: 220,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Subtotal',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(subtotal.toStringAsFixed(2)),
                      ],
                    ),
                    if (safeDiscount > 0) ...[
                      pw.SizedBox(height: 6),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Discount', style: label),
                          pw.Text('-${safeDiscount.toStringAsFixed(2)}'),
                        ],
                      ),
                    ],
                    if (safeTaxRate > 0) ...[
                      pw.SizedBox(height: 6),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Tax (${safeTaxRate.toStringAsFixed(0)}%)',
                            style: label,
                          ),
                          pw.Text(taxAmount.toStringAsFixed(2)),
                        ],
                      ),
                    ],
                    pw.SizedBox(height: 8),
                    pw.Divider(height: 1, color: PdfColors.grey300),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Total',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(total.toStringAsFixed(2)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          if (draft.paymentTerms.trim().isNotEmpty) ...[
            pw.Text(
              'Payment terms',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(draft.paymentTerms),
            pw.SizedBox(height: 12),
          ],
          if (draft.notes.trim().isNotEmpty) ...[
            pw.Text(
              'Notes',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(draft.notes),
          ],
        ];
      },
    ),
  );

  return doc.save();
}
