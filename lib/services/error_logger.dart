import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class ErrorLogger {
  static final ErrorLogger instance = ErrorLogger._();
  ErrorLogger._();

  static const String _fileName = 'error_log.txt';

  File? _logFile;
  final List<String> _buffer = <String>[];
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    if (kIsWeb) {
      _initialized = true;
      return;
    }

    final dir = await getApplicationDocumentsDirectory();
    _logFile = File('${dir.path}${Platform.pathSeparator}$_fileName');

    // Ensure file exists.
    if (!await _logFile!.exists()) {
      await _logFile!.create(recursive: true);
    }

    _initialized = true;

    // Flush any buffered logs.
    if (_buffer.isNotEmpty) {
      final toWrite = _buffer.join('');
      _buffer.clear();
      await _appendRaw(toWrite);
    }
  }

  Future<String> getLogPath() async {
    if (kIsWeb) return 'web://console';
    if (!_initialized) {
      await init();
    }
    return _logFile?.path ?? '';
  }

  Future<String> readLogs() async {
    if (kIsWeb) {
      return 'Logs are not persisted on web. Check the browser console.';
    }

    if (!_initialized) {
      await init();
    }

    final file = _logFile;
    if (file == null) return '';

    if (!await file.exists()) return '';
    return file.readAsString();
  }

  Future<void> clear() async {
    if (kIsWeb) return;
    if (!_initialized) {
      await init();
    }

    final file = _logFile;
    if (file == null) return;

    await file.writeAsString('');
  }

  Future<void> logError(
    Object error,
    StackTrace stack, {
    String? context,
  }) async {
    final message = _format(
      header: 'ERROR',
      body: error.toString(),
      stack: stack,
      context: context,
    );

    await _write(message);
  }

  Future<void> logFlutterError(FlutterErrorDetails details) async {
    final stack = details.stack ?? StackTrace.current;
    final message = _format(
      header: 'FLUTTER_ERROR',
      body: details.exceptionAsString(),
      stack: stack,
      context: details.context?.toDescription(),
    );

    await _write(message);
  }

  Future<void> logMessage(String message, {String? context}) async {
    final formatted = _format(
      header: 'MESSAGE',
      body: message,
      stack: null,
      context: context,
    );

    await _write(formatted);
  }

  String _format({
    required String header,
    required String body,
    StackTrace? stack,
    String? context,
  }) {
    final now = DateTime.now().toIso8601String();
    final ctx = (context ?? '').trim();

    final buffer = StringBuffer();
    buffer.writeln('[$now] $header${ctx.isNotEmpty ? ' ($ctx)' : ''}');
    buffer.writeln(body);
    if (stack != null) {
      buffer.writeln(stack.toString());
    }
    buffer.writeln('---');
    return buffer.toString();
  }

  Future<void> _write(String message) async {
    // Always mirror to console in debug.
    if (kDebugMode) {
      debugPrint(message);
    }

    if (kIsWeb) {
      return;
    }

    // Avoid races during early startup.
    if (!_initialized) {
      _buffer.add(message);
      return;
    }

    await _appendRaw(message);
  }

  Future<void> _appendRaw(String message) async {
    final file = _logFile;
    if (file == null) return;

    try {
      await file.writeAsString(message, mode: FileMode.append, flush: true);
    } catch (_) {
      // If writing fails, don't crash the app.
    }
  }
}
