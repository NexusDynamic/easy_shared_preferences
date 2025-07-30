import 'dart:convert';
import 'dart:async';
import 'serializable.dart';
import 'validators.dart';
import 'exceptions.dart';

/// Type definition for validation error recovery handlers.
///
/// This function is called when a stored value fails validation during
/// initialization or when explicitly set. It allows custom recovery logic
/// instead of silently falling back to default values.
///
/// Parameters:
/// - [settingKey]: The key of the setting that failed validation
/// - [invalidValue]: The value that failed validation
/// - [validationError]: Description of the validation failure
///
/// Returns: The recovered value to use, or null to use the default value
/// Throws: Any exception to indicate recovery failure
typedef ValidationErrorHandler<T> = T? Function(
  String settingKey,
  dynamic invalidValue,
  String validationError,
);

/// Enum for supported setting value types.
///
/// This enum is used internally to track the type of each setting
/// and ensure proper type casting during storage and retrieval operations.
enum SettingType {
  /// Boolean true/false values
  bool,

  /// Integer numeric values
  int,

  /// Double-precision floating point values
  double,

  /// String text values
  string,

  /// List of string values
  stringList,
}

/// Abstract base class for all setting types.
///
/// This class defines the common interface and functionality for all settings,
/// including type safety, validation, change notifications, and metadata.
///
/// Type parameter [T] ensures compile-time type safety for setting values.
///
/// Example usage:
/// ```dart
/// // Create a validated volume setting
/// final volumeSetting = DoubleSetting(
///   key: 'volume',
///   defaultValue: 0.5,
///   validator: (value) => value >= 0.0 && value <= 1.0,
/// );
///
/// // Listen for changes
/// volumeSetting.stream.listen((newValue) {
///   print('Volume changed to: $newValue');
/// });
/// ```
///
/// Concrete implementations:
/// - [BoolSetting] for boolean values
/// - [IntSetting] for integer values
/// - [DoubleSetting] for floating-point values
/// - [StringSetting] for text values
/// - [StringListSetting] for lists of strings
abstract class Setting<T> implements Serializable {
  /// Internal stream controller for broadcasting value changes.
  /// Uses lazy initialization to save memory when streams aren't used.
  StreamController<T>? _controller;

  /// Unique identifier for this setting within its group.
  ///
  /// Keys should be descriptive and follow camelCase convention.
  /// Examples: 'soundEnabled', 'maxRetries', 'serverUrl'
  final String key;

  /// The data type of this setting's value.
  ///
  /// Used internally for type checking and storage operations.
  /// Automatically set by concrete implementations.
  final SettingType type;

  /// The default value used when the setting hasn't been explicitly set.
  ///
  /// This value is used during initialization and reset operations.
  /// Must match the generic type parameter [T].
  final T defaultValue;

  /// Whether this setting can be modified by user code.
  ///
  /// When false, attempts to modify the setting will throw
  /// [SettingNotConfigurableException]. Useful for system settings
  /// or read-only configuration values.
  ///
  /// Defaults to true.
  final bool userConfigurable;

  /// Optional validator for setting values before storage.
  ///
  /// Can be either a function or a SettingValidator instance.
  /// Functions should return true for valid values, false otherwise.
  /// SettingValidator instances provide additional features like serialization and descriptions.
  ///
  /// When validation fails, [SettingValidationException] is thrown.
  ///
  /// Examples:
  /// ```dart
  /// // Function validator
  /// validator: (value) => value >= 0 && value <= 100
  ///
  /// // Class validator
  /// validator: RangeValidator<int>(min: 0, max: 100)
  ///
  /// // Composite validator
  /// validator: CompositeValidator<String>.and([
  ///   LengthValidator(minLength: 8),
  ///   RegexValidator(r'\d+')
  /// ])
  /// ```
  final dynamic validator;

  /// Optional handler for validation errors during initialization.
  ///
  /// This handler is called when a stored value fails validation during
  /// settings initialization. It allows custom recovery logic instead of
  /// silently falling back to the default value.
  ///
  /// If this handler returns null or is not provided, the default value is used.
  /// If the handler throws an exception, initialization will fail.
  ///
  /// Example:
  /// ```dart
  /// final portSetting = IntSetting(
  ///   key: 'serverPort',
  ///   defaultValue: 8080,
  ///   validator: (value) => value > 0 && value < 65536,
  ///   onValidationError: (key, invalidValue, error) {
  ///     // Log the issue and try to recover
  ///     logger.warning('Invalid port $invalidValue, using 8080');
  ///     return 8080;
  ///   },
  /// );
  /// ```
  final ValidationErrorHandler<T>? onValidationError;

  /// Stream that emits new values when the setting changes.
  ///
  /// This stream uses broadcast semantics, allowing multiple listeners.
  /// The stream emits the new value immediately after it's stored.
  /// Stream is lazily initialized to save memory when not used.
  ///
  /// Example:
  /// ```dart
  /// setting.stream.listen((newValue) {
  ///   print('Setting changed to: $newValue');
  ///   updateUI(newValue);
  /// });
  /// ```
  Stream<T> get stream {
    _controller ??= StreamController<T>.broadcast();
    return _controller!.stream;
  }

  /// Creates a new setting with the specified configuration.
  ///
  /// Parameters:
  /// - [key]: Unique identifier within the settings group
  /// - [type]: Data type of the setting value
  /// - [defaultValue]: Initial/reset value for the setting
  /// - [userConfigurable]: Whether the setting can be modified (default: true)
  /// - [validator]: Optional validation function for new values
  /// - [onValidationError]: Optional handler for validation errors during initialization
  Setting({
    required this.key,
    required this.type,
    required this.defaultValue,
    this.userConfigurable = true,
    this.validator,
    this.onValidationError,
  });

  /// Internal method to notify all stream listeners of a value change.
  ///
  /// This method is called automatically by the settings framework
  /// after a value has been successfully stored. Application code
  /// should not call this method directly.
  ///
  /// Only creates the stream controller if there are active listeners.
  ///
  /// Parameters:
  /// - [value]: The new value that was stored
  void notifyChange(T value) {
    // Only notify if stream controller exists (has listeners)
    if (_controller != null) {
      _controller!.add(value);
    }
  }

  /// Internal method to validate a value using the validator.
  ///
  /// Supports both function validators and SettingValidator instances.
  /// Returns a validation result with details about any failures.
  ///
  /// Parameters:
  /// - [value]: The value to validate
  ///
  /// Returns: ValidationResult indicating success or failure with details
  ValidationResult<T> validateWithResult(T value) {
    if (validator == null) {
      return ValidationResult<T>.success(value);
    }

    try {
      bool isValid = false;
      String? errorDescription;

      if (validator is bool Function(T)) {
        isValid = (validator as bool Function(T))(value);
        errorDescription =
            isValid ? null : 'Value $value failed validation function';
      } else if (validator is SettingValidator<T>) {
        final settingValidator = validator as SettingValidator<T>;
        isValid = settingValidator.validate(value);
        errorDescription = isValid
            ? null
            : 'Value $value failed validation: ${settingValidator.description}';
      } else {
        // Fallback for dynamic validators that might match the type
        if (validator is SettingValidator) {
          final settingValidator = validator as SettingValidator;
          isValid = settingValidator.validate(value);
          errorDescription = isValid
              ? null
              : 'Value $value failed validation: ${settingValidator.description}';
        } else {
          return ValidationResult<T>.failure(
            value,
            'Unknown validator type: ${validator.runtimeType}',
          );
        }
      }

      return isValid
          ? ValidationResult<T>.success(value)
          : ValidationResult<T>.failure(value, errorDescription!);
    } catch (e) {
      return ValidationResult<T>.failure(
        value,
        'Validation error: $e',
      );
    }
  }

  /// Legacy validation method for backward compatibility.
  ///
  /// Returns true if validation passes, false otherwise.
  /// Use [validateWithResult] for more detailed validation information.
  bool validate(T value) {
    return validateWithResult(value).isValid;
  }

  /// Attempts to recover from a validation error using the error handler.
  ///
  /// Parameters:
  /// - [invalidValue]: The value that failed validation
  /// - [validationError]: Description of the validation failure
  ///
  /// Returns: The recovered value or null to use default
  /// Throws: SettingRecoveryException if recovery fails
  T? attemptRecovery(dynamic invalidValue, String validationError) {
    if (onValidationError == null) {
      return null; // Use default value
    }

    try {
      final recovered = onValidationError!(key, invalidValue, validationError);

      // If recovery returned a value, validate it
      if (recovered != null) {
        final result = validateWithResult(recovered);
        if (!result.isValid) {
          throw SettingRecoveryException(
            settingKey: key,
            invalidValue: invalidValue,
            validationError: validationError,
            recoveryError:
                'Recovered value also failed validation: ${result.errorDescription}',
            message:
                'Recovery failed for setting $key: recovered value is also invalid',
          );
        }
      }

      return recovered;
    } catch (e) {
      if (e is SettingRecoveryException) {
        rethrow;
      }

      throw SettingRecoveryException(
        settingKey: key,
        invalidValue: invalidValue,
        validationError: validationError,
        recoveryError: e,
        message: 'Recovery handler failed for setting $key: $e',
      );
    }
  }

  /// Get a human-readable description of the validation rules.
  ///
  /// Returns null for function validators, or the description from SettingValidator instances.
  String? get validationDescription {
    if (validator is SettingValidator) {
      return (validator as SettingValidator).description;
    }
    return null;
  }

  /// Dispose of the stream controller and release resources.
  ///
  /// This method should be called when the setting is no longer needed
  /// to prevent memory leaks. It's automatically called by the settings
  /// framework when disposing of setting groups.
  ///
  /// After calling dispose, the [stream] will no longer emit events.
  void dispose() {
    _controller?.close();
    _controller = null;
  }

  /// Converts the setting to a map.
  @override
  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'type': type.name,
      'defaultValue': defaultValue,
      'userConfigurable': userConfigurable,
      // Todo: convert validator to use validation classes (e.g. RangeValidator)
      'validator': null,
    };
  }

  /// Creates a setting from a map representation.
  Setting.fromMap(Map<String, dynamic> map)
      : key = map['key'] as String,
        type = SettingType.values.firstWhere(
          (e) => e.name == map['type'],
          orElse: () =>
              throw ArgumentError('Invalid setting type: ${map['type']}'),
        ),
        defaultValue = map['defaultValue'] as T,
        userConfigurable = map['userConfigurable'] as bool? ?? true,
        validator = null,
        onValidationError = null;

  /// Converts the setting to a JSON string representation.
  @override
  String toJson() {
    return jsonEncode(toMap());
  }

  /// Creates a setting from a JSON string representation.
  Setting.fromJson(String json)
      : this.fromMap(jsonDecode(json) as Map<String, dynamic>);
}

/// A setting that stores boolean (true/false) values.
///
/// This is a concrete implementation of [Setting] specialized for boolean values.
/// Commonly used for feature flags, toggles, and binary preferences.
///
/// Example:
/// ```dart
/// final soundEnabled = BoolSetting(
///   key: 'soundEnabled',
///   defaultValue: true,
/// );
///
/// final debugMode = BoolSetting(
///   key: 'debugMode',
///   defaultValue: false,
///   userConfigurable: false, // System setting
/// );
/// ```
class BoolSetting extends Setting<bool> {
  /// Creates a new boolean setting.
  ///
  /// Parameters:
  /// - [key]: Unique identifier for this setting
  /// - [defaultValue]: Initial boolean value (true or false)
  /// - [userConfigurable]: Whether users can modify this setting (default: true)
  /// - [validator]: Optional validation function for boolean values
  BoolSetting({
    required super.key,
    required super.defaultValue,
    super.userConfigurable,
    super.validator,
    super.onValidationError,
  }) : super(type: SettingType.bool);

  /// Converts the boolean value to a JSON string representation.
  @override
  String toJson() {
    return defaultValue.toString();
  }

  /// Creates a boolean setting from a JSON string representation.
}

/// A setting that stores integer numeric values.
///
/// This is a concrete implementation of [Setting] specialized for integer values.
/// Useful for counts, limits, indices, and whole number preferences.
///
/// Example:
/// ```dart
/// final maxRetries = IntSetting(
///   key: 'maxRetries',
///   defaultValue: 3,
///   validator: (value) => value >= 0 && value <= 10,
/// );
///
/// final fontSize = IntSetting(
///   key: 'fontSize',
///   defaultValue: 14,
///   validator: (value) => value >= 8 && value <= 72,
/// );
/// ```
class IntSetting extends Setting<int> {
  /// Creates a new integer setting.
  ///
  /// Parameters:
  /// - [key]: Unique identifier for this setting
  /// - [defaultValue]: Initial integer value
  /// - [userConfigurable]: Whether users can modify this setting (default: true)
  /// - [validator]: Optional validation function (e.g., range checking)
  IntSetting({
    required super.key,
    required super.defaultValue,
    super.userConfigurable,
    super.validator,
    super.onValidationError,
  }) : super(type: SettingType.int);
}

/// A setting that stores double-precision floating-point values.
///
/// This is a concrete implementation of [Setting] specialized for decimal values.
/// Perfect for percentages, ratios, measurements, and precise numeric settings.
///
/// Example:
/// ```dart
/// final volume = DoubleSetting(
///   key: 'volume',
///   defaultValue: 0.8,
///   validator: (value) => value >= 0.0 && value <= 1.0,
/// );
///
/// final animationSpeed = DoubleSetting(
///   key: 'animationSpeed',
///   defaultValue: 1.0,
///   validator: (value) => value > 0.0 && value <= 5.0,
/// );
/// ```
class DoubleSetting extends Setting<double> {
  /// Creates a new double setting.
  ///
  /// Parameters:
  /// - [key]: Unique identifier for this setting
  /// - [defaultValue]: Initial floating-point value
  /// - [userConfigurable]: Whether users can modify this setting (default: true)
  /// - [validator]: Optional validation function (e.g., range checking)
  DoubleSetting({
    required super.key,
    required super.defaultValue,
    super.userConfigurable,
    super.validator,
    super.onValidationError,
  }) : super(type: SettingType.double);
}

/// A setting that stores string text values.
///
/// This is a concrete implementation of [Setting] specialized for text values.
/// Ideal for names, URLs, file paths, themes, and textual preferences.
///
/// Example:
/// ```dart
/// final theme = StringSetting(
///   key: 'theme',
///   defaultValue: 'light',
///   validator: (value) => ['light', 'dark', 'auto'].contains(value),
/// );
///
/// final serverUrl = StringSetting(
///   key: 'serverUrl',
///   defaultValue: 'https://api.example.com',
///   validator: (value) => Uri.tryParse(value) != null,
/// );
/// ```
class StringSetting extends Setting<String> {
  /// Creates a new string setting.
  ///
  /// Parameters:
  /// - [key]: Unique identifier for this setting
  /// - [defaultValue]: Initial text value
  /// - [userConfigurable]: Whether users can modify this setting (default: true)
  /// - [validator]: Optional validation function (e.g., format checking)
  StringSetting({
    required super.key,
    required super.defaultValue,
    super.userConfigurable,
    super.validator,
    super.onValidationError,
  }) : super(type: SettingType.string);
}

/// A setting that stores lists of string values.
///
/// This is a concrete implementation of [Setting] specialized for string lists.
/// Perfect for tags, categories, selected items, and multi-value preferences.
///
/// Example:
/// ```dart
/// final tags = StringListSetting(
///   key: 'tags',
///   defaultValue: ['flutter', 'dart'],
///   validator: (list) => list.length <= 10,
/// );
///
/// final categories = StringListSetting(
///   key: 'selectedCategories',
///   defaultValue: [],
///   validator: (list) => list.every((item) => item.isNotEmpty),
/// );
/// ```
class StringListSetting extends Setting<List<String>> {
  /// Creates a new string list setting.
  ///
  /// Parameters:
  /// - [key]: Unique identifier for this setting
  /// - [defaultValue]: Initial list of strings
  /// - [userConfigurable]: Whether users can modify this setting (default: true)
  /// - [validator]: Optional validation function (e.g., length or content checking)
  StringListSetting({
    required super.key,
    required super.defaultValue,
    super.userConfigurable,
    super.validator,
    super.onValidationError,
  }) : super(type: SettingType.stringList);
}

/// Represents the result of a validation operation.
///
/// This class provides detailed information about validation success or failure,
/// including error descriptions for better debugging and logging.
class ValidationResult<T> {
  /// The value that was validated.
  final T value;

  /// Whether the validation was successful.
  final bool isValid;

  /// Description of the validation error, if any.
  final String? errorDescription;

  /// Creates a successful validation result.
  ValidationResult.success(this.value)
      : isValid = true,
        errorDescription = null;

  /// Creates a failed validation result.
  ValidationResult.failure(this.value, this.errorDescription) : isValid = false;

  @override
  String toString() {
    return isValid
        ? 'ValidationResult(valid: $value)'
        : 'ValidationResult(invalid: $value, error: $errorDescription)';
  }
}
