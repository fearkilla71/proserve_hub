import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// OCR service using Apple Vision (iOS) via platform channel.
/// Replaces Google ML Kit to avoid MLImage simulator/Xcode 26 issues.
class NativeOcrService {
  static const _channel = MethodChannel('com.verohue.proservehub/ocr');

  const NativeOcrService();

  /// Recognizes text from an image file. Returns the raw recognized text.
  /// Throws on web or if the platform channel call fails.
  Future<String> recognizeText(File imageFile) async {
    if (kIsWeb) {
      throw Exception('OCR is not supported on web.');
    }

    final result = await _channel.invokeMethod<String>('recognizeText', {
      'imagePath': imageFile.path,
    });
    return result ?? '';
  }

  /// Recognizes text from a file path. Returns the raw recognized text.
  Future<String> recognizeTextFromPath(String path) async {
    if (kIsWeb) {
      throw Exception('OCR is not supported on web.');
    }

    final result = await _channel.invokeMethod<String>('recognizeText', {
      'imagePath': path,
    });
    return result ?? '';
  }

  /// No-op for API compatibility with the old TextRecognizer.close() pattern.
  Future<void> close() async {}
}
