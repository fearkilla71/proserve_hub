import 'dart:async';
import 'dart:io';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class ErrorLogger {
  static final ErrorLogger instance = ErrorLogger._();
  ErrorLogger._();

  static const String _fileName = 'error_log.txt';
  static const String _oldFileName = 'error_log.old.txt';

  /// Max log size before rotation (500 KB).
  static const int _maxBytes = 500 * 1024;

  /// Whether Firebase Crashlytics is available on the current platform.
  static bool get _crashlyticsSupported =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  File? _logFile;
  File? _oldLogFile;
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
    _oldLogFile = File('${dir.path}${Platform.pathSeparator}$_oldFileName');

    // Ensure file exists.
    if (!await _logFile!.exists()) {
      await _logFile!.create(recursive: true);
    }

    // Rotate on startup if the log is already too large.
    await _rotateIfNeeded();

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

    // Forward to Crashlytics in release builds.
    if (_crashlyticsSupported && !kDebugMode) {
      try {
        await FirebaseCrashlytics.instance.recordError(
          error,
          stack,
          reason: context,
        );
      } catch (_) {
        // Best-effort — never crash the crash reporter.
      }
    }
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

    // Forward to Crashlytics in release builds.
    if (_crashlyticsSupported && !kDebugMode) {
      try {
        await FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      } catch (_) {
        // Best-effort.
      }
    }
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
      await _rotateIfNeeded();
    } catch (_) {
      // If writing fails, don't crash the app.
    }
  }

  /// Rotate the log file when it exceeds [_maxBytes].
  /// The current log is moved to `.old` (overwriting any previous archive)
  /// and a fresh empty log is created.
  Future<void> _rotateIfNeeded() async {
    final file = _logFile;
    if (file == null) return;

    try {
      if (!await file.exists()) return;

      final length = await file.length();
      if (length < _maxBytes) return;

      // Rename current → old (overwrite).
      final oldFile = _oldLogFile;
      if (oldFile != null && await oldFile.exists()) {
        await oldFile.delete();
      }
      await file.rename(oldFile!.path);

      // Re-create the fresh log file at the original path.
      _logFile = File(oldFile.path.replaceAll(_oldFileName, _fileName));
      await _logFile!.create(recursive: true);
    } catch (_) {
      // Best-effort rotation — never crash.
    }
  }
}
