import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:intl/intl.dart';

class ReceiptOcrResult {
  final String rawText;
  final String? vendor;
  final DateTime? date;
  final double? total;
  final double? tax;
  final List<ReceiptLineItem> lineItems;

  const ReceiptOcrResult({
    required this.rawText,
    this.vendor,
    this.date,
    this.total,
    this.tax,
    this.lineItems = const [],
  });
}

/// Represents a single line item extracted from a receipt.
class ReceiptLineItem {
  final String description;
  final int quantity;
  final double unitPrice;
  final double total;

  const ReceiptLineItem({
    required this.description,
    this.quantity = 1,
    required this.unitPrice,
    required this.total,
  });

  Map<String, dynamic> toMap() => {
    'description': description,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'total': total,
  };
}

class ReceiptOcrService {
  const ReceiptOcrService();

  Future<ReceiptOcrResult> recognizeFromImageFile(File imageFile) async {
    if (kIsWeb) {
      throw Exception('Receipt OCR is not supported on web.');
    }

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final result = await recognizer.processImage(inputImage);
      final rawText = result.text;
      return _parse(rawText);
    } finally {
      await recognizer.close();
    }
  }

  ReceiptOcrResult _parse(String rawText) {
    final lines = rawText
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final vendor = _guessVendor(lines);
    final date = _guessDate(rawText);
    final total = _guessMoney(
      rawText,
      keywords: const [
        'total',
        'amount due',
        'balance due',
        'grand total',
        'total due',
        'amount',
      ],
    );
    final tax = _guessMoney(
      rawText,
      keywords: const ['tax', 'sales tax', 'vat'],
    );
    final lineItems = _extractLineItems(lines);

    return ReceiptOcrResult(
      rawText: rawText,
      vendor: vendor,
      date: date,
      total: total,
      tax: tax,
      lineItems: lineItems,
    );
  }

  /// Attempts to extract individual line items from receipt text.
  ///
  /// Looks for lines with a description followed by a price, e.g.:
  ///   "Paper Towels  2x  $3.99  $7.98"
  ///   "Coffee Filters         $4.29"
  List<ReceiptLineItem> _extractLineItems(List<String> lines) {
    final items = <ReceiptLineItem>[];

    // Pattern: description text followed by price(s)
    // Captures: description, optional qty, price
    final linePattern = RegExp(
      r'^(.+?)\s+'
      r'(?:(\d+)\s*[xX@]\s*)?'
      r'\$?\s*(\d{1,3}(?:,\d{3})*\.\d{2})'
      r'(?:\s+\$?\s*(\d{1,3}(?:,\d{3})*\.\d{2}))?$',
    );

    // Skip lines that are headers, totals, tax, etc.
    final skipPatterns = RegExp(
      r'(?:^sub\s*total|^total|^tax|^sales\s*tax|^vat|^amount|^balance|'
      r'^change|^cash|^credit|^debit|^visa|^master|^amex|'
      r'^thank|^receipt|^invoice|^order|^date|^time|^store|'
      r'^phone|^addr|^www\.|^http)',
      caseSensitive: false,
    );

    for (final line in lines) {
      if (skipPatterns.hasMatch(line.toLowerCase())) continue;

      final match = linePattern.firstMatch(line);
      if (match == null) continue;

      final desc = match.group(1)?.trim() ?? '';
      if (desc.length < 2) continue;

      // Skip if description looks like a number or date
      if (RegExp(r'^\d+[\/-]\d+').hasMatch(desc)) continue;

      final qtyStr = match.group(2);
      final qty = qtyStr != null ? (int.tryParse(qtyStr) ?? 1) : 1;

      final price1 = double.tryParse(
        (match.group(3) ?? '').replaceAll(',', ''),
      );
      final price2 = double.tryParse(
        (match.group(4) ?? '').replaceAll(',', ''),
      );

      if (price1 == null) continue;

      // If there are two prices, the last is usually the line total
      final double unitPrice;
      final double lineTotal;
      if (price2 != null) {
        unitPrice = price1;
        lineTotal = price2;
      } else {
        unitPrice = qty > 1 ? (price1 / qty) : price1;
        lineTotal = price1;
      }

      // Ignore unlikely values
      if (lineTotal <= 0 || lineTotal > 100000) continue;

      items.add(
        ReceiptLineItem(
          description: desc,
          quantity: qty,
          unitPrice: double.parse(unitPrice.toStringAsFixed(2)),
          total: lineTotal,
        ),
      );
    }

    return items;
  }

  String? _guessVendor(List<String> lines) {
    // Very simple heuristic: first line that looks like a name (not mostly digits).
    for (final l in lines.take(8)) {
      final cleaned = l.replaceAll(RegExp(r"[^A-Za-z0-9 &\-'\.]"), '').trim();
      if (cleaned.length < 3) continue;
      final digitCount = RegExp(r'\d').allMatches(cleaned).length;
      if (digitCount > (cleaned.length / 2)) continue;

      // Avoid lines that are clearly receipt metadata.
      final lower = cleaned.toLowerCase();
      if (lower.contains('invoice') ||
          lower.contains('receipt') ||
          lower.contains('order') ||
          lower.contains('thank')) {
        continue;
      }

      return cleaned;
    }
    return null;
  }

  DateTime? _guessDate(String text) {
    // Common patterns: MM/DD/YYYY, M/D/YY, YYYY-MM-DD.
    final candidates = <DateTime>[];

    final mdy = RegExp(r'\b(\d{1,2})[\/-](\d{1,2})[\/-](\d{2,4})\b');
    for (final m in mdy.allMatches(text)) {
      final mm = int.tryParse(m.group(1) ?? '');
      final dd = int.tryParse(m.group(2) ?? '');
      final yyRaw = m.group(3) ?? '';
      if (mm == null || dd == null) continue;
      var yy = int.tryParse(yyRaw);
      if (yy == null) continue;
      if (yy < 100) yy += 2000;

      final dt = _safeDate(yy, mm, dd);
      if (dt != null) candidates.add(dt);
    }

    final ymd = RegExp(r'\b(\d{4})[\/-](\d{1,2})[\/-](\d{1,2})\b');
    for (final m in ymd.allMatches(text)) {
      final yy = int.tryParse(m.group(1) ?? '');
      final mm = int.tryParse(m.group(2) ?? '');
      final dd = int.tryParse(m.group(3) ?? '');
      if (yy == null || mm == null || dd == null) continue;
      final dt = _safeDate(yy, mm, dd);
      if (dt != null) candidates.add(dt);
    }

    if (candidates.isEmpty) return null;

    // Pick the most recent date that isn't in the far future.
    candidates.sort();
    final now = DateTime.now();
    final notFuture = candidates.where(
      (d) => d.isBefore(now.add(const Duration(days: 2))),
    );
    return notFuture.isNotEmpty ? notFuture.last : candidates.last;
  }

  DateTime? _safeDate(int year, int month, int day) {
    try {
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  double? _guessMoney(String text, {required List<String> keywords}) {
    final lower = text.toLowerCase();

    // Find lines containing keywords first.
    final lines = lower.split(RegExp(r'\r?\n')).map((l) => l.trim()).toList();
    final candidateNumbers = <double>[];

    for (final line in lines) {
      if (!keywords.any((k) => line.contains(k))) continue;
      final nums = _extractMoneyNumbers(line);
      candidateNumbers.addAll(nums);
    }

    if (candidateNumbers.isNotEmpty) {
      return candidateNumbers.reduce((a, b) => a > b ? a : b);
    }

    // Fallback: use the largest amount in the whole text.
    final allNums = _extractMoneyNumbers(lower);
    if (allNums.isEmpty) return null;
    return allNums.reduce((a, b) => a > b ? a : b);
  }

  List<double> _extractMoneyNumbers(String text) {
    final pattern = RegExp(
      r'(\$\s*)?(\d{1,3}(?:,\d{3})*(?:\.\d{2})|\d+(?:\.\d{2}))',
    );
    final values = <double>[];
    for (final m in pattern.allMatches(text)) {
      final raw = (m.group(2) ?? '').replaceAll(',', '');
      final v = double.tryParse(raw);
      if (v == null) continue;
      // Ignore tiny values that are usually quantities.
      if (v <= 0) continue;
      values.add(v);
    }
    return values;
  }
}

String formatDateForUi(DateTime? date) {
  if (date == null) return '';
  return DateFormat.yMMMd().format(date);
}
