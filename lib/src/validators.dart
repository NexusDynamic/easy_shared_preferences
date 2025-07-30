/// Built-in validator classes for common validation scenarios.
///
/// This module provides pre-built validator classes that can be used
/// with settings to ensure data integrity and business rule compliance.
/// These validators are serializable and can be stored as part of
/// setting definitions.
///
/// Example usage:
/// ```dart
/// final volumeSetting = DoubleSetting(
///   key: 'volume',
///   defaultValue: 0.5,
///   validator: RangeValidator<double>(min: 0.0, max: 1.0),
/// );
///
/// final themeSetting = StringSetting(
///   key: 'theme',
///   defaultValue: 'light',
///   validator: EnumValidator<String>(['light', 'dark', 'auto']),
/// );
/// ```
library;

/// Abstract base class for all built-in validators.
///
/// This class provides the foundation for serializable validators that can
/// be stored and reconstructed from configuration. All built-in validators
/// should extend this class.
abstract class SettingValidator<T> {
  /// Validates the given value according to the validator's rules.
  ///
  /// Returns true if the value is valid, false otherwise.
  /// Subclasses should override this method to implement specific validation logic.
  bool validate(T value);

  /// Converts the validator to a map representation for serialization.
  ///
  /// This allows validators to be stored alongside setting definitions
  /// and reconstructed later. Subclasses must implement this method.
  Map<String, dynamic> toMap();

  /// Creates a validator from a map representation.
  ///
  /// This factory method reconstructs validators from their serialized form.
  /// The [type] parameter indicates which validator class to instantiate.
  static SettingValidator<dynamic> fromMap(Map<String, dynamic> map) {
    final type = map['type'] as String;

    switch (type) {
      case 'RangeValidator':
        if (map['min'] is int || map['max'] is int) {
          return RangeValidator<int>.fromMap(map) as SettingValidator<dynamic>;
        } else if (map['min'] is double || map['max'] is double) {
          return RangeValidator<double>.fromMap(map) as SettingValidator<dynamic>;
        } else {
          return RangeValidator<String>.fromMap(map) as SettingValidator<dynamic>;
        }
      case 'EnumValidator':
        return EnumValidator<dynamic>.fromMap(map);
      case 'LengthValidator':
        return LengthValidator.fromMap(map);
      case 'RegexValidator':
        return RegexValidator.fromMap(map);
      case 'CompositeValidator':
        return CompositeValidator<dynamic>.fromMap(map);
      case 'ListLengthValidator':
        return ListLengthValidator.fromMap(map);
      case 'ListContentValidator':
        return ListContentValidator.fromMap(map);
      default:
        throw ArgumentError('Unknown validator type: $type');
    }
  }

  /// Returns a human-readable description of the validation rules.
  ///
  /// This is useful for error messages and documentation.
  String get description;
}

/// Validates that numeric values fall within a specified range.
///
/// This validator works with any comparable type (int, double, DateTime, etc.)
/// and ensures values are within the specified minimum and maximum bounds.
///
/// Example:
/// ```dart
/// // Volume between 0.0 and 1.0
/// final volumeValidator = RangeValidator<double>(min: 0.0, max: 1.0);
///
/// // Age between 0 and 120
/// final ageValidator = RangeValidator<int>(min: 0, max: 120);
///
/// // Optional bounds (only minimum)
/// final positiveValidator = RangeValidator<int>(min: 0);
/// ```
class RangeValidator<T extends Comparable<dynamic>>
    extends SettingValidator<T> {
  /// The minimum allowed value (inclusive). Null means no minimum bound.
  final T? min;

  /// The maximum allowed value (inclusive). Null means no maximum bound.
  final T? max;

  /// Creates a range validator with optional minimum and maximum bounds.
  ///
  /// At least one of [min] or [max] must be provided.
  ///
  /// Parameters:
  /// - [min]: Minimum allowed value (inclusive), null for no lower bound
  /// - [max]: Maximum allowed value (inclusive), null for no upper bound
  ///
  /// Throws [ArgumentError] if both min and max are null.
  RangeValidator({this.min, this.max}) {
    if (min == null && max == null) {
      throw ArgumentError('At least one bound (min or max) must be specified');
    }
    if (min != null && max != null && min!.compareTo(max!) > 0) {
      throw ArgumentError(
          'Minimum value must be less than or equal to maximum value');
    }
  }

  @override
  bool validate(T value) {
    if (min != null && value.compareTo(min!) < 0) {
      return false;
    }
    if (max != null && value.compareTo(max!) > 0) {
      return false;
    }
    return true;
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': 'RangeValidator',
      'min': min,
      'max': max,
    };
  }

  /// Creates a RangeValidator from a map representation.
  RangeValidator.fromMap(Map<String, dynamic> map)
      : min = map['min'] as T?,
        max = map['max'] as T?;

  @override
  String get description {
    if (min != null && max != null) {
      return 'Value must be between $min and $max (inclusive)';
    } else if (min != null) {
      return 'Value must be at least $min';
    } else {
      return 'Value must be at most $max';
    }
  }
}

/// Validates that values are within a predefined set of allowed values.
///
/// This validator is perfect for enum-like settings where only specific
/// values are permitted.
///
/// Example:
/// ```dart
/// // Theme selection
/// final themeValidator = EnumValidator<String>(['light', 'dark', 'auto']);
///
/// // Difficulty levels
/// final difficultyValidator = EnumValidator<int>([1, 2, 3]);
/// ```
class EnumValidator<T> extends SettingValidator<T> {
  /// The set of allowed values.
  final Set<T> allowedValues;

  /// Creates an enum validator with the specified allowed values.
  ///
  /// Parameters:
  /// - [allowedValues]: Iterable of values that are considered valid
  ///
  /// Throws [ArgumentError] if allowedValues is empty.
  EnumValidator(Iterable<T> allowedValues)
      : allowedValues = Set<T>.from(allowedValues) {
    if (this.allowedValues.isEmpty) {
      throw ArgumentError('At least one allowed value must be specified');
    }
  }

  @override
  bool validate(T value) {
    return allowedValues.contains(value);
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': 'EnumValidator',
      'allowedValues': allowedValues.toList(),
    };
  }

  /// Creates an EnumValidator from a map representation.
  EnumValidator.fromMap(Map<String, dynamic> map)
      : allowedValues = Set<T>.from(map['allowedValues'] as List);

  @override
  String get description {
    final valuesList = allowedValues.join(', ');
    return 'Value must be one of: $valuesList';
  }
}

/// Validates string length constraints.
///
/// This validator ensures strings meet minimum and/or maximum length requirements.
/// Useful for validating user input fields, API keys, and configuration values.
///
/// Example:
/// ```dart
/// // Username between 3 and 20 characters
/// final usernameValidator = LengthValidator(minLength: 3, maxLength: 20);
///
/// // API key must be exactly 32 characters
/// final apiKeyValidator = LengthValidator(minLength: 32, maxLength: 32);
///
/// // Non-empty string
/// final nonEmptyValidator = LengthValidator(minLength: 1);
/// ```
class LengthValidator extends SettingValidator<String> {
  /// The minimum allowed string length. Null means no minimum constraint.
  final int? minLength;

  /// The maximum allowed string length. Null means no maximum constraint.
  final int? maxLength;

  /// Creates a length validator with optional minimum and maximum length constraints.
  ///
  /// At least one of [minLength] or [maxLength] must be provided.
  ///
  /// Parameters:
  /// - [minLength]: Minimum string length, null for no lower bound
  /// - [maxLength]: Maximum string length, null for no upper bound
  ///
  /// Throws [ArgumentError] if both constraints are null or if minLength > maxLength.
  LengthValidator({this.minLength, this.maxLength}) {
    if (minLength == null && maxLength == null) {
      throw ArgumentError('At least one length constraint must be specified');
    }
    if (minLength != null && minLength! < 0) {
      throw ArgumentError('Minimum length cannot be negative');
    }
    if (maxLength != null && maxLength! < 0) {
      throw ArgumentError('Maximum length cannot be negative');
    }
    if (minLength != null && maxLength != null && minLength! > maxLength!) {
      throw ArgumentError(
          'Minimum length must be less than or equal to maximum length');
    }
  }

  @override
  bool validate(String value) {
    final length = value.length;
    if (minLength != null && length < minLength!) {
      return false;
    }
    if (maxLength != null && length > maxLength!) {
      return false;
    }
    return true;
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': 'LengthValidator',
      'minLength': minLength,
      'maxLength': maxLength,
    };
  }

  /// Creates a LengthValidator from a map representation.
  LengthValidator.fromMap(Map<String, dynamic> map)
      : minLength = map['minLength'] as int?,
        maxLength = map['maxLength'] as int?;

  @override
  String get description {
    if (minLength != null && maxLength != null) {
      if (minLength == maxLength) {
        return 'String must be exactly $minLength characters long';
      } else {
        return 'String must be between $minLength and $maxLength characters long';
      }
    } else if (minLength != null) {
      return 'String must be at least $minLength characters long';
    } else {
      return 'String must be at most $maxLength characters long';
    }
  }
}

/// Validates strings against a regular expression pattern.
///
/// This validator uses regular expressions to validate string format,
/// making it perfect for emails, URLs, phone numbers, and custom formats.
///
/// Example:
/// ```dart
/// // Email validation
/// final emailValidator = RegexValidator(
///   r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
///   description: 'Must be a valid email address',
/// );
///
/// // Hexadecimal color code
/// final hexColorValidator = RegexValidator(
///   r'^#[0-9A-Fa-f]{6}$',
///   description: 'Must be a valid hex color code (e.g., #FF0000)',
/// );
/// ```
class RegexValidator extends SettingValidator<String> {
  /// The regular expression pattern to match against.
  final RegExp pattern;

  /// Custom description for this validator.
  final String? customDescription;

  /// Creates a regex validator with the specified pattern.
  ///
  /// Parameters:
  /// - [pattern]: Regular expression pattern as a string
  /// - [caseSensitive]: Whether the pattern is case sensitive (default: true)
  /// - [multiLine]: Whether ^ and $ match line breaks (default: false)
  /// - [description]: Custom description for error messages
  ///
  /// Example:
  /// ```dart
  /// final validator = RegexValidator(
  ///   r'^\d{3}-\d{3}-\d{4}$',
  ///   description: 'Must be in format XXX-XXX-XXXX',
  /// );
  /// ```
  RegexValidator(
    String pattern, {
    bool caseSensitive = true,
    bool multiLine = false,
    this.customDescription,
  }) : pattern =
            RegExp(pattern, caseSensitive: caseSensitive, multiLine: multiLine);

  /// Creates a regex validator with a pre-compiled RegExp.
  RegexValidator.fromRegExp(this.pattern, {this.customDescription});

  @override
  bool validate(String value) {
    return pattern.hasMatch(value);
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': 'RegexValidator',
      'pattern': pattern.pattern,
      'caseSensitive': pattern.isCaseSensitive,
      'multiLine': pattern.isMultiLine,
      'description': customDescription,
    };
  }

  /// Creates a RegexValidator from a map representation.
  RegexValidator.fromMap(Map<String, dynamic> map)
      : pattern = RegExp(
          map['pattern'] as String,
          caseSensitive: map['caseSensitive'] as bool? ?? true,
          multiLine: map['multiLine'] as bool? ?? false,
        ),
        customDescription = map['description'] as String?;

  @override
  String get description {
    return customDescription ?? 'String must match pattern: ${pattern.pattern}';
  }
}

/// Combines multiple validators using logical operations.
///
/// This validator allows you to create complex validation rules by combining
/// simpler validators with AND or OR logic.
///
/// Example:
/// ```dart
/// // Password must be 8-20 characters AND contain at least one digit
/// final passwordValidator = CompositeValidator<String>.and([
///   LengthValidator(minLength: 8, maxLength: 20),
///   RegexValidator(r'\d', description: 'Must contain at least one digit'),
/// ]);
///
/// // Value must be either in range 1-10 OR exactly 100
/// final specialRangeValidator = CompositeValidator<int>.or([
///   RangeValidator<int>(min: 1, max: 10),
///   EnumValidator<int>([100]),
/// ]);
/// ```
class CompositeValidator<T> extends SettingValidator<T> {
  /// The list of validators to combine.
  final List<SettingValidator<T>> validators;

  /// The logical operation to use (true for AND, false for OR).
  final bool useAndLogic;

  /// Creates a composite validator with the specified logic operation.
  ///
  /// Parameters:
  /// - [validators]: List of validators to combine
  /// - [useAndLogic]: If true, all validators must pass (AND); if false, at least one must pass (OR)
  ///
  /// Throws [ArgumentError] if validators list is empty.
  CompositeValidator(this.validators, {required this.useAndLogic}) {
    if (validators.isEmpty) {
      throw ArgumentError('At least one validator must be provided');
    }
  }

  /// Creates a composite validator that requires ALL validators to pass.
  CompositeValidator.and(this.validators) : useAndLogic = true {
    if (validators.isEmpty) {
      throw ArgumentError('At least one validator must be provided');
    }
  }

  /// Creates a composite validator that requires at least ONE validator to pass.
  CompositeValidator.or(this.validators) : useAndLogic = false {
    if (validators.isEmpty) {
      throw ArgumentError('At least one validator must be provided');
    }
  }

  @override
  bool validate(T value) {
    if (useAndLogic) {
      // AND logic: all validators must pass
      return validators.every((validator) => validator.validate(value));
    } else {
      // OR logic: at least one validator must pass
      return validators.any((validator) => validator.validate(value));
    }
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': 'CompositeValidator',
      'validators': validators.map((v) => v.toMap()).toList(),
      'useAndLogic': useAndLogic,
    };
  }

  /// Creates a CompositeValidator from a map representation.
  CompositeValidator.fromMap(Map<String, dynamic> map)
      : validators = (map['validators'] as List)
            .map((v) => SettingValidator.fromMap(v as Map<String, dynamic>)
                as SettingValidator<T>)
            .toList(),
        useAndLogic = map['useAndLogic'] as bool;

  @override
  String get description {
    final operation = useAndLogic ? 'AND' : 'OR';
    final descriptions =
        validators.map((v) => v.description).join(' $operation ');
    return '($descriptions)';
  }
}

/// Validates string list length constraints.
///
/// This validator ensures string lists meet minimum and/or maximum length requirements.
/// Useful for validating collections like tags, categories, or selected items.
///
/// Example:
/// ```dart
/// // Tags between 1 and 10 items
/// final tagsValidator = ListLengthValidator(minLength: 1, maxLength: 10);
///
/// // At least one category selected
/// final categoryValidator = ListLengthValidator(minLength: 1);
///
/// // Maximum 5 favorite items
/// final favoritesValidator = ListLengthValidator(maxLength: 5);
/// ```
class ListLengthValidator extends SettingValidator<List<String>> {
  /// The minimum allowed list length. Null means no minimum constraint.
  final int? minLength;

  /// The maximum allowed list length. Null means no maximum constraint.
  final int? maxLength;

  /// Creates a list length validator with optional minimum and maximum length constraints.
  ///
  /// At least one of [minLength] or [maxLength] must be provided.
  ///
  /// Parameters:
  /// - [minLength]: Minimum list length, null for no lower bound
  /// - [maxLength]: Maximum list length, null for no upper bound
  ///
  /// Throws [ArgumentError] if both constraints are null or if minLength > maxLength.
  ListLengthValidator({this.minLength, this.maxLength}) {
    if (minLength == null && maxLength == null) {
      throw ArgumentError('At least one length constraint must be specified');
    }
    if (minLength != null && minLength! < 0) {
      throw ArgumentError('Minimum length cannot be negative');
    }
    if (maxLength != null && maxLength! < 0) {
      throw ArgumentError('Maximum length cannot be negative');
    }
    if (minLength != null && maxLength != null && minLength! > maxLength!) {
      throw ArgumentError(
          'Minimum length must be less than or equal to maximum length');
    }
  }

  @override
  bool validate(List<String> value) {
    final length = value.length;
    if (minLength != null && length < minLength!) {
      return false;
    }
    if (maxLength != null && length > maxLength!) {
      return false;
    }
    return true;
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': 'ListLengthValidator',
      'minLength': minLength,
      'maxLength': maxLength,
    };
  }

  /// Creates a ListLengthValidator from a map representation.
  ListLengthValidator.fromMap(Map<String, dynamic> map)
      : minLength = map['minLength'] as int?,
        maxLength = map['maxLength'] as int?;

  @override
  String get description {
    if (minLength != null && maxLength != null) {
      if (minLength == maxLength) {
        return 'List must contain exactly $minLength items';
      } else {
        return 'List must contain between $minLength and $maxLength items';
      }
    } else if (minLength != null) {
      return 'List must contain at least $minLength items';
    } else {
      return 'List must contain at most $maxLength items';
    }
  }
}

/// Validates the content of items within a string list.
///
/// This validator applies a sub-validator to each item in the list,
/// ensuring all items meet specific criteria.
///
/// Example:
/// ```dart
/// // All items must be non-empty
/// final nonEmptyItemsValidator = ListContentValidator(
///   itemValidator: LengthValidator(minLength: 1),
/// );
///
/// // All items must be valid email addresses
/// final emailListValidator = ListContentValidator(
///   itemValidator: CommonValidators.email,
/// );
///
/// // All items must be at least 3 characters and alphanumeric
/// final tagsValidator = ListContentValidator(
///   itemValidator: CompositeValidator<String>.and([
///     LengthValidator(minLength: 3),
///     RegexValidator(r'^[a-zA-Z0-9]+$'),
///   ]),
/// );
/// ```
class ListContentValidator extends SettingValidator<List<String>> {
  /// The validator to apply to each item in the list.
  final SettingValidator<String> itemValidator;

  /// Creates a list content validator that applies the item validator to each list element.
  ///
  /// Parameters:
  /// - [itemValidator]: Validator to apply to each string in the list
  ListContentValidator({required this.itemValidator});

  @override
  bool validate(List<String> value) {
    return value.every((item) => itemValidator.validate(item));
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': 'ListContentValidator',
      'itemValidator': itemValidator.toMap(),
    };
  }

  /// Creates a ListContentValidator from a map representation.
  ListContentValidator.fromMap(Map<String, dynamic> map)
      : itemValidator = SettingValidator.fromMap(
          map['itemValidator'] as Map<String, dynamic>,
        ) as SettingValidator<String>;

  @override
  String get description {
    return 'All items in list must satisfy: ${itemValidator.description}';
  }
}

/// Predefined validators for common use cases.
///
/// This class provides static factory methods for frequently used validators
/// to reduce boilerplate code and improve consistency.
class CommonValidators {
  /// Validates that a string is not empty.
  static LengthValidator get nonEmpty => LengthValidator(minLength: 1);

  /// Validates email addresses using a standard regex pattern.
  static RegexValidator get email => RegexValidator(
        r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
        customDescription: 'Must be a valid email address',
      );

  /// Validates URLs using a standard regex pattern.
  static RegexValidator get url => RegexValidator(
        r'^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$',
        customDescription: 'Must be a valid URL',
      );

  /// Validates hexadecimal color codes (e.g., #FF0000).
  static RegexValidator get hexColor => RegexValidator(
        r'^#[0-9A-Fa-f]{6}$',
        customDescription: 'Must be a valid hex color code (e.g., #FF0000)',
      );

  /// Validates positive integers (greater than 0).
  static RangeValidator<int> get positiveInt => RangeValidator<int>(min: 1);

  /// Validates non-negative integers (0 or greater).
  static RangeValidator<int> get nonNegativeInt => RangeValidator<int>(min: 0);

  /// Validates percentages as doubles between 0.0 and 1.0.
  static RangeValidator<double> get percentage =>
      RangeValidator<double>(min: 0.0, max: 1.0);

  /// Validates volume levels as doubles between 0.0 and 1.0.
  static RangeValidator<double> get volume => percentage;

  /// Creates a validator for port numbers (1-65535).
  static RangeValidator<int> get port =>
      RangeValidator<int>(min: 1, max: 65535);

  /// Validates that a string list is not empty.
  static ListLengthValidator get nonEmptyList => 
      ListLengthValidator(minLength: 1);

  /// Validates that all strings in a list are non-empty.
  static ListContentValidator get nonEmptyStrings => 
      ListContentValidator(itemValidator: nonEmpty);

  /// Creates a validator for string lists with maximum length constraint.
  static ListLengthValidator maxListLength(int maxLength) =>
      ListLengthValidator(maxLength: maxLength);

  /// Creates a validator for string lists with minimum length constraint.
  static ListLengthValidator minListLength(int minLength) =>
      ListLengthValidator(minLength: minLength);

  /// Creates a validator for string lists with specific length range.
  static ListLengthValidator listLengthRange(int minLength, int maxLength) =>
      ListLengthValidator(minLength: minLength, maxLength: maxLength);
}
