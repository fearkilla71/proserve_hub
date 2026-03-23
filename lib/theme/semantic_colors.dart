import 'package:flutter/material.dart';

/// Semantic colors that adapt to the current theme brightness.
///
/// Use these instead of hardcoded `Colors.green`, `Colors.red`, etc.
/// so the app looks correct in both light and dark mode.
extension SemanticColors on ColorScheme {
  Color get success => brightness == Brightness.dark
      ? const Color(0xFF66BB6A)
      : const Color(0xFF388E3C);

  Color get warning => brightness == Brightness.dark
      ? const Color(0xFFFFB74D)
      : const Color(0xFFF57C00);

  Color get info => brightness == Brightness.dark
      ? const Color(0xFF64B5F6)
      : const Color(0xFF1976D2);

  Color get danger => error;
}
