/// Exception thrown when a requested setting is not found.
///
/// This occurs when:
/// - Accessing a setting that doesn't exist in the group
/// - Using an invalid storage key format
/// - Referencing a setting before it's been registered
///
/// Example:
/// ```dart
/// try {
///   Settings.getBool('nonexistent.setting');
/// } catch (e) {
///   if (e is SettingNotFoundException) {
///     print('Setting not found: ${e.message}');
///   }
/// }
/// ```
class SettingNotFoundException implements Exception {
  /// Descriptive error message explaining what setting was not found.
  final String message;

  /// Creates a new [SettingNotFoundException] with the given [message].
  const SettingNotFoundException(this.message);

  @override
  String toString() => 'SettingNotFoundException: $message';
}

/// Exception thrown when attempting to modify a non-configurable setting.
///
/// Settings can be marked as non-configurable by setting `userConfigurable: false`.
/// This is useful for system settings or read-only configuration values.
///
/// Example:
/// ```dart
/// final systemSetting = BoolSetting(
///   key: 'systemFlag',
///   defaultValue: true,
///   userConfigurable: false, // This setting cannot be modified by users
/// );
/// ```
class SettingNotConfigurableException implements Exception {
  /// Descriptive error message explaining which setting cannot be configured.
  final String message;

  /// Creates a new [SettingNotConfigurableException] with the given [message].
  const SettingNotConfigurableException(this.message);

  @override
  String toString() => 'SettingNotConfigurableException: $message';
}

/// Exception thrown when a setting value fails validation.
///
/// This occurs when a validator function returns false for a given value.
/// Validators are useful for ensuring data integrity and business rules.
///
/// Example:
/// ```dart
/// final volumeSetting = DoubleSetting(
///   key: 'volume',
///   defaultValue: 0.5,
///   validator: (value) => value >= 0.0 && value <= 1.0,
/// );
///
/// // This will throw SettingValidationException
/// await Settings.setDouble('audio.volume', 1.5);
/// ```
class SettingValidationException implements Exception {
  /// Descriptive error message explaining the validation failure.
  final String message;

  /// Creates a new [SettingValidationException] with the given [message].
  const SettingValidationException(this.message);

  @override
  String toString() => 'SettingValidationException: $message';
}

/// Exception thrown when attempting to access settings before initialization.
///
/// The settings framework requires asynchronous initialization before use.
/// Always await `Settings.init()` or individual `readyFuture` properties
/// before accessing setting values.
///
/// Example:
/// ```dart
/// // Wrong - may throw SettingsNotReadyException
/// bool value = Settings.getBool('game.sound');
///
/// // Correct - wait for initialization
/// await Settings.init();
/// bool value = Settings.getBool('game.sound');
/// ```
class SettingsNotReadyException implements Exception {
  /// Descriptive error message explaining the readiness issue.
  final String message;

  /// Creates a new [SettingsNotReadyException] with the given [message].
  const SettingsNotReadyException(this.message);

  @override
  String toString() => 'SettingsNotReadyException: $message';
}

/// Exception thrown when a setting value cannot be recovered after validation failure.
///
/// This occurs during initialization when a stored value fails validation
/// and the recovery handler also fails or throws an exception.
///
/// Example:
/// ```dart
/// // If stored value is invalid and recovery fails
/// final setting = IntSetting(
///   key: 'port',
///   defaultValue: 8080,
///   validator: (value) => value > 0 && value < 65536,
///   onValidationError: (key, value, error) {
///     throw Exception('Cannot recover port setting');
///   },
/// );
/// ```
class SettingRecoveryException implements Exception {
  /// The setting key that failed recovery.
  final String settingKey;
  
  /// The invalid value that was stored.
  final dynamic invalidValue;
  
  /// The original validation error.
  final String validationError;
  
  /// The recovery error that occurred.
  final dynamic recoveryError;
  
  /// Descriptive error message.
  final String message;

  /// Creates a new [SettingRecoveryException].
  const SettingRecoveryException({
    required this.settingKey,
    required this.invalidValue,
    required this.validationError,
    required this.recoveryError,
    required this.message,
  });

  @override
  String toString() => 'SettingRecoveryException: $message';
}