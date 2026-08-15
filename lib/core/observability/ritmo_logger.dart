import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum LogLevel { debug, info, warning, error }

abstract class LogSink {
  void write(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stack,
    Map<String, Object?>? context,
  });
}

/// Redaction and privacy helper ensuring user personal data (reflection text,
/// health/cycle notes, routine titles, etc.) are redacted from production logs.
class LogRedactor {
  static final RegExp _persianTextRegex = RegExp(r'[\u0600-\u06FF]+');

  /// Redacts freeform Persian text or sensitive fields from log messages.
  static String redact(String input) {
    if (input.isEmpty) return input;
    return input.replaceAll(_persianTextRegex, '[REDACTED_TEXT]');
  }

  /// Sanitizes context map values, redacting String values that contain user text.
  static Map<String, Object?> sanitizeContext(Map<String, Object?>? context) {
    if (context == null || context.isEmpty) return {};
    final cleanMap = <String, Object?>{};
    for (final entry in context.entries) {
      final val = entry.value;
      if (val is String) {
        cleanMap[entry.key] = redact(val);
      } else {
        cleanMap[entry.key] = val;
      }
    }
    return cleanMap;
  }
}

/// Sink for printing to console in debug mode.
///
/// Stack traces are deliberately trimmed: `debugPrint` output is queued in
/// memory and, while a VM-service client (`flutter run`) is attached, that
/// buffered output is charged to the Dart heap. Dumping full async stacks from
/// a hot path is enough to exhaust it.
class ConsoleLogSink implements LogSink {
  static const int _maxStackFrames = 8;

  @override
  void write(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stack,
    Map<String, Object?>? context,
  }) {
    if (!kDebugMode) return;
    final ctxStr = context != null && context.isNotEmpty ? ' | Context: $context' : '';
    final errStr = error != null ? ' | Error: $error' : '';
    final formatted = '[${level.name.toUpperCase()}] $message$ctxStr$errStr';
    debugPrint(formatted);
    if (stack != null && level == LogLevel.error) {
      final frames = stack.toString().split('\n');
      final trimmed = frames.take(_maxStackFrames).join('\n');
      debugPrint(trimmed);
      if (frames.length > _maxStackFrames) {
        debugPrint('    ... ${frames.length - _maxStackFrames} more frames');
      }
    }
  }
}

/// Circular in-memory ring buffer sink for diagnostics.
class RingBufferLogSink implements LogSink {
  RingBufferLogSink({this.capacity = 500});
  final int capacity;
  final Queue<String> _buffer = Queue<String>();

  @override
  void write(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stack,
    Map<String, Object?>? context,
  }) {
    final cleanMsg = LogRedactor.redact(message);
    final cleanContext = LogRedactor.sanitizeContext(context);
    final now = DateTime.now().toIso8601String();
    final ctxStr = cleanContext.isNotEmpty ? ' | $cleanContext' : '';
    final errStr = error != null ? ' | Error: ${LogRedactor.redact(error.toString())}' : '';
    final line = '$now [${level.name.toUpperCase()}] $cleanMsg$ctxStr$errStr';

    if (_buffer.length >= capacity) {
      _buffer.removeFirst();
    }
    _buffer.addLast(line);
  }

  List<String> getLogs() => _buffer.toList();
  void clear() => _buffer.clear();
}

/// Local file sink writing rotated log files to disk (max 2 MB total cap).
///
/// Writes are batched through a single serialized flush chain: one directory
/// lookup per process, one file append per batch, and a bounded queue that
/// drops (and counts) lines during a burst. Never awaited by callers, but also
/// never spawns more than one in-flight I/O operation.
class LocalFileLogSink implements LogSink {
  LocalFileLogSink({
    this.maxSizeBytes = 2 * 1024 * 1024,
    this.minLevel = LogLevel.warning,
  });

  final int maxSizeBytes;

  /// Debug/info never touch the disk; only warning and error are persisted.
  final LogLevel minLevel;

  static const int _maxQueuedLines = 200;
  static const int _maxStackFrames = 8;

  final Queue<String> _queue = Queue<String>();
  Future<void>? _flushing;
  File? _logFile;
  int _droppedLines = 0;

  @override
  void write(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stack,
    Map<String, Object?>? context,
  }) {
    if (kIsWeb) return;
    if (level.index < minLevel.index) return;

    final cleanMsg = LogRedactor.redact(message);
    final cleanContext = LogRedactor.sanitizeContext(context);
    final cleanError = error != null ? LogRedactor.redact(error.toString()) : null;

    final sb = StringBuffer()
      ..write('${DateTime.now().toIso8601String()} [${level.name.toUpperCase()}] $cleanMsg');
    if (cleanContext.isNotEmpty) {
      sb.write(' | Context: $cleanContext');
    }
    if (cleanError != null && cleanError.isNotEmpty) {
      sb.write(' | Error: $cleanError');
    }
    if (stack != null && level == LogLevel.error) {
      final frames = stack.toString().split('\n').take(_maxStackFrames).join(' <- ');
      sb.write(' | Stack: $frames');
    }

    if (_queue.length >= _maxQueuedLines) {
      _droppedLines++;
      return;
    }
    _queue.addLast(sb.toString());
    _scheduleFlush();
  }

  void _scheduleFlush() {
    if (_flushing != null) return;
    _flushing = _flush().whenComplete(() {
      _flushing = null;
      if (_queue.isNotEmpty) _scheduleFlush();
    });
  }

  Future<void> _flush() async {
    if (_queue.isEmpty) return;
    try {
      final file = await _resolveFile();
      if (file == null) {
        _queue.clear();
        return;
      }

      final sb = StringBuffer();
      while (_queue.isNotEmpty) {
        sb.writeln(_queue.removeFirst());
      }
      if (_droppedLines > 0) {
        sb.writeln('... $_droppedLines log line(s) suppressed (burst protection)');
        _droppedLines = 0;
      }

      await file.writeAsString(sb.toString(), mode: FileMode.append);
      await _rotateIfNeeded(file);
    } catch (e) {
      // Never let logging failures cascade, and never retry a growing backlog.
      _queue.clear();
      _droppedLines = 0;
      if (kDebugMode) {
        debugPrint('[LocalFileLogSink] Write failed: $e');
      }
    }
  }

  Future<File?> _resolveFile() async {
    final cached = _logFile;
    if (cached != null) return cached;

    final dir = await getApplicationDocumentsDirectory();
    final logDir = Directory(p.join(dir.path, 'ritmo_logs'));
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }
    final file = File(p.join(logDir.path, 'ritmo_app.log'));
    _logFile = file;
    return file;
  }

  Future<void> _rotateIfNeeded(File file) async {
    if (!await file.exists()) return;
    if (await file.length() <= maxSizeBytes) return;

    final backup = File('${file.path}.old');
    if (await backup.exists()) {
      await backup.delete();
    }
    await file.rename(backup.path);
    _logFile = null;
  }
}

/// Primary Observability Logger for Ritmo application (R-3 requirement).
///
/// Logging is bounded on purpose: identical messages are deduplicated inside a
/// short window and the total rate is capped. A logger must never be able to
/// take the app down, no matter how hot the code path that calls it is.
class RitmoLogger {
  static final List<LogSink> _sinks = [
    ConsoleLogSink(),
    RingBufferLogSink(),
    LocalFileLogSink(),
  ];

  static const int _maxLogsPerSecond = 30;
  static const Duration _dedupeWindow = Duration(seconds: 5);
  static const int _maxDedupeKeys = 256;

  static final Map<String, int> _lastSeenMs = <String, int>{};
  static int _windowStartMs = 0;
  static int _windowCount = 0;
  static int _suppressedCount = 0;

  static RingBufferLogSink get ringBuffer =>
      _sinks.whereType<RingBufferLogSink>().first;

  static void addSink(LogSink sink) => _sinks.add(sink);

  /// Test/diagnostics hook: forget dedupe and rate-limit state.
  @visibleForTesting
  static void resetThrottleState() {
    _lastSeenMs.clear();
    _windowStartMs = 0;
    _windowCount = 0;
    _suppressedCount = 0;
  }

  static void debug(
    String message, {
    Object? error,
    StackTrace? stack,
    Map<String, Object?>? context,
  }) {
    _dispatch(LogLevel.debug, message, error: error, stack: stack, context: context);
  }

  static void info(
    String message, {
    Object? error,
    StackTrace? stack,
    Map<String, Object?>? context,
  }) {
    _dispatch(LogLevel.info, message, error: error, stack: stack, context: context);
  }

  static void warning(
    String message, {
    Object? error,
    StackTrace? stack,
    Map<String, Object?>? context,
  }) {
    _dispatch(LogLevel.warning, message, error: error, stack: stack, context: context);
  }

  static void error(
    String message, {
    Object? error,
    StackTrace? stack,
    Map<String, Object?>? context,
  }) {
    _dispatch(LogLevel.error, message, error: error, stack: stack, context: context);
  }

  /// Returns false when this record must be dropped (duplicate or burst).
  static bool _admit(LogLevel level, String message) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    if (nowMs - _windowStartMs >= 1000) {
      if (_suppressedCount > 0 && kDebugMode) {
        debugPrint(
            '[RitmoLogger] $_suppressedCount repeated log line(s) suppressed in the last second');
      }
      _windowStartMs = nowMs;
      _windowCount = 0;
      _suppressedCount = 0;
    }

    final key = '${level.name}|$message';
    final lastMs = _lastSeenMs[key];
    if (lastMs != null && nowMs - lastMs < _dedupeWindow.inMilliseconds) {
      _suppressedCount++;
      return false;
    }
    if (_lastSeenMs.length >= _maxDedupeKeys) {
      _lastSeenMs.clear();
    }
    _lastSeenMs[key] = nowMs;

    if (_windowCount >= _maxLogsPerSecond) {
      _suppressedCount++;
      return false;
    }
    _windowCount++;
    return true;
  }

  static void _dispatch(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stack,
    Map<String, Object?>? context,
  }) {
    if (!_admit(level, message)) return;
    for (final sink in _sinks) {
      try {
        sink.write(level, message, error: error, stack: stack, context: context);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[RitmoLogger] Sink write failed: $e');
        }
      }
    }
  }
}
