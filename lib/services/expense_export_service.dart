import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/job_expense.dart';

class ExpenseExportService {
  const ExpenseExportService();

  String buildCsv(List<JobExpense> expenses) {
    String esc(String? v) {
      final s = (v ?? '').replaceAll('"', '""');
      return '"$s"';
    }

    String numFmt(double? v) => v == null ? '' : v.toStringAsFixed(2);

    final buf = StringBuffer();
    buf.writeln(
      'receiptDate,vendor,total,tax,currency,notes,createdAt,createdByRole,createdByUid',
    );

    for (final e in expenses) {
      final rd = e.receiptDate == null
          ? ''
          : DateFormat('yyyy-MM-dd').format(e.receiptDate!);
      final ca = DateFormat('yyyy-MM-dd HH:mm:ss').format(e.createdAt);

      buf.writeln(
        [
          esc(rd),
          esc(e.vendor),
          esc(numFmt(e.total)),
          esc(numFmt(e.tax)),
          esc(e.currency),
          esc(e.notes),
          esc(ca),
          esc(e.createdByRole),
          esc(e.createdByUid),
        ].join(','),
      );
    }

    return buf.toString();
  }

  Future<File> writeCsvToTempFile({
    required String filenameBase,
    required String csv,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filenameBase.csv');
    await file.writeAsString(csv);
    return file;
  }

  Future<File> writePdfToTempFile({
    required String filenameBase,
    required String title,
    required List<JobExpense> expenses,
  }) async {
    final doc = pw.Document();

    String money(double? v, String currency) {
      if (v == null) return '';
      return '${v.toStringAsFixed(2)} $currency';
    }

    String date(DateTime? d) {
      if (d == null) return '';
      return DateFormat('yMMMd').format(d);
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        build: (context) {
          return [
            pw.Text(
              title,
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),
            pw.TableHelper.fromTextArray(
              headers: const ['Date', 'Vendor', 'Total', 'Tax', 'Notes'],
              data: expenses
                  .map(
                    (e) => [
                      date(e.receiptDate),
                      e.vendor ?? '',
                      money(e.total, e.currency),
                      money(e.tax, e.currency),
                      (e.notes ?? '').replaceAll('\n', ' '),
                    ],
                  )
                  .toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellAlignment: pw.Alignment.centerLeft,
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              border: pw.TableBorder.all(color: PdfColors.grey400),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.2),
                1: const pw.FlexColumnWidth(2.0),
                2: const pw.FlexColumnWidth(1.2),
                3: const pw.FlexColumnWidth(1.0),
                4: const pw.FlexColumnWidth(3.0),
              },
            ),
          ];
        },
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filenameBase.pdf');
    await file.writeAsBytes(await doc.save());
    return file;
  }
}
