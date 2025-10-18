import 'dart:io';

/// Simple logger for RPC operations
///
/// This provides a centralized logging mechanism that can be easily
/// configured or disabled as needed.
class RpcLogger {
  /// Enable or disable logging
  static bool enabled = true;

  /// Current log level
  static LogLevel level = LogLevel.info;

  /// Log an info message
  static void info(final String message) {
    if (enabled && level.index <= LogLevel.info.index) {
      _log('INFO', message);
    }
  }

  /// Log a warning message
  static void warning(final String message) {
    if (enabled && level.index <= LogLevel.warning.index) {
      _log('WARN', message);
    }
  }

  /// Log an error message
  static void error(
    final String message, [
    final Object? error,
    final StackTrace? stackTrace,
  ]) {
    if (enabled && level.index <= LogLevel.error.index) {
      _log('ERROR', message);
      if (error != null) {
        _log('ERROR', '  $error');
      }
      if (stackTrace != null && level == LogLevel.debug) {
        _log('ERROR', '  $stackTrace');
      }
    }
  }

  /// Log a debug message
  static void debug(final String message) {
    if (enabled && level.index <= LogLevel.debug.index) {
      _log('DEBUG', message);
    }
  }

  static void _log(final String level, final String message) {
    final timestamp = DateTime.now().toIso8601String();
    stderr.writeln('[$timestamp] [$level] $message');
  }
}

/// Log levels for filtering messages
enum LogLevel {
  error,
  warning,
  info,
  debug,
}
