import 'package:logging/logging.dart';
import 'dart:developer' as developer;

/// Global logger instance for the Easy Shared Preferences framework.
///
/// This logger provides structured logging throughout the framework with
/// configurable levels and formatting. By default, logging is disabled
/// in production builds and enabled in debug mode.
///
/// Usage:
/// ```dart
/// // Enable logging (usually during app initialization)
/// EspLogger.enableLogging(Level.INFO);
///
/// // Use throughout the framework
/// EspLogger.info('Settings initialized successfully');
/// EspLogger.warning('Validation failed for setting: $key');
/// EspLogger.severe('Failed to initialize SharedPreferences', error);
/// ```
class EspLogger {
  static final Logger _logger = Logger('EasySharedPreferences');
  static bool _initialized = false;

  /// Initialize logging with the specified level.
  ///
  /// This should be called once during application startup to configure
  /// the logging behavior. In production, you may want to set this to
  /// Level.WARNING or Level.SEVERE to reduce log output.
  ///
  /// Parameters:
  /// - [level]: The minimum log level to output (default: Level.INFO)
  /// - [onRecord]: Optional custom log handler (default: prints to console)
  ///
  /// Example:
  /// ```dart
  /// // During app initialization
  /// EspLogger.enableLogging(Level.ALL); // Development
  /// EspLogger.enableLogging(Level.WARNING); // Production
  /// ```
  static void enableLogging([
    Level level = Level.INFO,
    void Function(LogRecord)? onRecord,
  ]) {
    if (_initialized) return;

    Logger.root.level = level;
    Logger.root.onRecord.listen(onRecord ?? _defaultLogHandler);
    _initialized = true;

    _logger
        .info('EasySharedPreferences logging enabled at level: ${level.name}');
  }

  /// Disable all logging for the framework.
  ///
  /// This sets the log level to OFF, effectively disabling all log output.
  /// Useful for production builds where you want minimal overhead.
  static void disableLogging() {
    Logger.root.level = Level.OFF;
    _logger.fine('EasySharedPreferences logging disabled');
  }

  /// Default log handler that formats and outputs log records.
  static void _defaultLogHandler(LogRecord record) {
    final timestamp = record.time.toIso8601String();
    final level = record.level.name.padRight(7);
    final logger = record.loggerName;
    final message = record.message;

    final logMessage = '[$timestamp] $level [$logger] $message';

    // Use dart:developer log for better integration with Flutter DevTools
    developer.log(
      logMessage,
      name: record.loggerName,
      level: record.level.value,
      error: record.error,
      stackTrace: record.stackTrace,
    );
  }

  // Convenience methods for different log levels

  /// Log a fine-grained informational message (Level.FINE).
  /// Used for detailed debugging information.
  static void fine(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.fine(message, error, stackTrace);
  }

  /// Log an informational message (Level.INFO).
  /// Used for general operational information.
  static void info(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.info(message, error, stackTrace);
  }

  /// Log a warning message (Level.WARNING).
  /// Used for potentially problematic situations.
  static void warning(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.warning(message, error, stackTrace);
  }

  /// Log a severe error message (Level.SEVERE).
  /// Used for serious failures that should be investigated.
  static void severe(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.severe(message, error, stackTrace);
  }

  /// Create a scoped logger for a specific component.
  ///
  /// This creates a child logger with a more specific name for better
  /// log organization and filtering.
  ///
  /// Parameters:
  /// - [name]: The specific component name (e.g., 'SettingsGroup', 'Validator')
  ///
  /// Returns: A Logger instance for the specific component
  ///
  /// Example:
  /// ```dart
  /// final logger = EspLogger.forComponent('SettingsGroup');
  /// logger.info('Group initialized: $groupKey');
  /// ```
  static Logger forComponent(String name) {
    return Logger('EasySharedPreferences.$name');
  }

  /// Check if logging is enabled at the specified level.
  ///
  /// This can be used to avoid expensive log message construction
  /// when logging is disabled for performance optimization.
  ///
  /// Example:
  /// ```dart
  /// if (EspLogger.isLoggable(Level.FINE)) {
  ///   EspLogger.fine('Expensive debug info: ${buildComplexDebugString()}');
  /// }
  /// ```
  static bool isLoggable(Level level) {
    return _logger.isLoggable(level);
  }
}
