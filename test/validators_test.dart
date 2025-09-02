import 'package:flutter_test/flutter_test.dart';
import 'package:easy_shared_preferences/src/validators.dart';

void main() {
  group('RangeValidator', () {
    test('should validate values within range', () {
      final validator = RangeValidator<int>(min: 0, max: 100);

      expect(validator.validate(0), isTrue);
      expect(validator.validate(50), isTrue);
      expect(validator.validate(100), isTrue);
      expect(validator.validate(-1), isFalse);
      expect(validator.validate(101), isFalse);
    });

    test('should validate with only minimum bound', () {
      final validator = RangeValidator<int>(min: 0);

      expect(validator.validate(0), isTrue);
      expect(validator.validate(100), isTrue);
      expect(validator.validate(-1), isFalse);
    });

    test('should validate with only maximum bound', () {
      final validator = RangeValidator<int>(max: 100);

      expect(validator.validate(0), isTrue);
      expect(validator.validate(100), isTrue);
      expect(validator.validate(101), isFalse);
    });

    test('should work with double values', () {
      final validator = RangeValidator<double>(min: 0.0, max: 1.0);

      expect(validator.validate(0.0), isTrue);
      expect(validator.validate(0.5), isTrue);
      expect(validator.validate(1.0), isTrue);
      expect(validator.validate(-0.1), isFalse);
      expect(validator.validate(1.1), isFalse);
    });

    test('should serialize and deserialize correctly', () {
      final validator = RangeValidator<int>(min: 0, max: 100);
      final map = validator.toMap();
      final restored = RangeValidator<int>.fromMap(map);

      expect(restored.min, equals(0));
      expect(restored.max, equals(100));
      expect(restored.validate(50), isTrue);
      expect(restored.validate(-1), isFalse);
    });

    test('should provide correct description', () {
      final validator1 = RangeValidator<int>(min: 0, max: 100);
      expect(validator1.description, contains('between 0 and 100'));

      final validator2 = RangeValidator<int>(min: 0);
      expect(validator2.description, contains('at least 0'));

      final validator3 = RangeValidator<int>(max: 100);
      expect(validator3.description, contains('at most 100'));
    });
  });

  group('EnumValidator', () {
    test('should validate allowed values', () {
      final validator = EnumValidator<String>(['light', 'dark', 'auto']);

      expect(validator.validate('light'), isTrue);
      expect(validator.validate('dark'), isTrue);
      expect(validator.validate('auto'), isTrue);
      expect(validator.validate('invalid'), isFalse);
    });

    test('should work with different types', () {
      final validator = EnumValidator<int>([1, 2, 3]);

      expect(validator.validate(1), isTrue);
      expect(validator.validate(2), isTrue);
      expect(validator.validate(3), isTrue);
      expect(validator.validate(4), isFalse);
    });

    test('should serialize and deserialize correctly', () {
      final validator = EnumValidator<String>(['light', 'dark']);
      final map = validator.toMap();
      final restored = EnumValidator<String>.fromMap(map);

      expect(restored.validate('light'), isTrue);
      expect(restored.validate('dark'), isTrue);
      expect(restored.validate('invalid'), isFalse);
    });

    test('should provide correct description', () {
      final validator = EnumValidator<String>(['light', 'dark', 'auto']);
      final description = validator.description;

      expect(description, contains('light'));
      expect(description, contains('dark'));
      expect(description, contains('auto'));
    });
  });

  group('LengthValidator', () {
    test('should validate string length', () {
      final validator = LengthValidator(minLength: 3, maxLength: 10);

      expect(validator.validate('abc'), isTrue);
      expect(validator.validate('hello'), isTrue);
      expect(validator.validate('1234567890'), isTrue);
      expect(validator.validate('ab'), isFalse);
      expect(validator.validate('12345678901'), isFalse);
    });

    test('should validate with only minimum length', () {
      final validator = LengthValidator(minLength: 3);

      expect(validator.validate('abc'), isTrue);
      expect(validator.validate('very long string'), isTrue);
      expect(validator.validate('ab'), isFalse);
    });

    test('should validate with only maximum length', () {
      final validator = LengthValidator(maxLength: 10);

      expect(validator.validate(''), isTrue);
      expect(validator.validate('hello'), isTrue);
      expect(validator.validate('1234567890'), isTrue);
      expect(validator.validate('12345678901'), isFalse);
    });

    test('should serialize and deserialize correctly', () {
      final validator = LengthValidator(minLength: 3, maxLength: 10);
      final map = validator.toMap();
      final restored = LengthValidator.fromMap(map);

      expect(restored.minLength, equals(3));
      expect(restored.maxLength, equals(10));
      expect(restored.validate('hello'), isTrue);
      expect(restored.validate('ab'), isFalse);
    });
  });

  group('RegexValidator', () {
    test('should validate against regex pattern', () {
      final validator = RegexValidator(r'^\d{3}-\d{3}-\d{4}$');

      expect(validator.validate('123-456-7890'), isTrue);
      expect(validator.validate('987-654-3210'), isTrue);
      expect(validator.validate('123-45-6789'), isFalse);
      expect(validator.validate('not-a-phone'), isFalse);
    });

    test('should work with case sensitivity', () {
      final caseSensitive = RegexValidator(r'^[A-Z]+$');
      final caseInsensitive = RegexValidator(r'^[A-Z]+$', caseSensitive: false);

      expect(caseSensitive.validate('HELLO'), isTrue);
      expect(caseSensitive.validate('hello'), isFalse);

      expect(caseInsensitive.validate('HELLO'), isTrue);
      expect(caseInsensitive.validate('hello'), isTrue);
    });

    test('should serialize and deserialize correctly', () {
      final validator = RegexValidator(
        r'^\d{3}-\d{3}-\d{4}$',
        customDescription: 'Phone number format',
      );
      final map = validator.toMap();
      final restored = RegexValidator.fromMap(map);

      expect(restored.validate('123-456-7890'), isTrue);
      expect(restored.validate('invalid'), isFalse);
      expect(restored.customDescription, equals('Phone number format'));
    });
  });

  group('CompositeValidator', () {
    test('should combine validators with AND logic', () {
      final validator = CompositeValidator<String>.and([
        LengthValidator(minLength: 3, maxLength: 10),
        RegexValidator(r'^[a-zA-Z]+$'),
      ]);

      expect(validator.validate('hello'), isTrue); // Both pass
      expect(validator.validate('ab'), isFalse); // Length fails
      expect(validator.validate('hello123'), isFalse); // Regex fails
      expect(validator.validate('verylongstring'), isFalse); // Length fails
    });

    test('should combine validators with OR logic', () {
      final validator = CompositeValidator<int>.or([
        RangeValidator<int>(min: 1, max: 10),
        EnumValidator<int>([100, 200]),
      ]);

      expect(validator.validate(5), isTrue); // First validator passes
      expect(validator.validate(100), isTrue); // Second validator passes
      expect(validator.validate(50), isFalse); // Neither passes
    });

    test('should serialize and deserialize correctly', () {
      final validator = CompositeValidator<String>.and([
        LengthValidator(minLength: 3),
        RegexValidator(r'^[a-zA-Z]+$'),
      ]);

      final map = validator.toMap();
      final restored = CompositeValidator<String>.fromMap(map);

      expect(restored.validate('hello'), isTrue);
      expect(restored.validate('ab'), isFalse);
      expect(restored.useAndLogic, isTrue);
    });
  });

  group('CommonValidators', () {
    test('nonEmpty should validate non-empty strings', () {
      final validator = CommonValidators.nonEmpty;

      expect(validator.validate('hello'), isTrue);
      expect(validator.validate('a'), isTrue);
      expect(validator.validate(''), isFalse);
    });

    test('email should validate email addresses', () {
      final validator = CommonValidators.email;

      expect(validator.validate('test@example.com'), isTrue);
      expect(validator.validate('user.name+tag@domain.co.uk'), isTrue);
      expect(validator.validate('invalid-email'), isFalse);
      expect(validator.validate('@domain.com'), isFalse);
      expect(validator.validate('test@'), isFalse);
    });

    test('url should validate URLs', () {
      final validator = CommonValidators.url;

      expect(validator.validate('https://example.com'), isTrue);
      expect(validator.validate('http://www.google.com'), isTrue);
      expect(validator.validate('https://sub.domain.com/path'), isTrue);
      expect(validator.validate('not-a-url'), isFalse);
      expect(validator.validate('ftp://example.com'), isFalse);
    });

    test('hexColor should validate hex color codes', () {
      final validator = CommonValidators.hexColor;

      expect(validator.validate('#FF0000'), isTrue);
      expect(validator.validate('#00ff00'), isTrue);
      expect(validator.validate('#123ABC'), isTrue);
      expect(validator.validate('FF0000'), isFalse); // Missing #
      expect(validator.validate('#FF00'), isFalse); // Too short
      expect(validator.validate('#GG0000'), isFalse); // Invalid hex
    });

    test('positiveInt should validate positive integers', () {
      final validator = CommonValidators.positiveInt;

      expect(validator.validate(1), isTrue);
      expect(validator.validate(100), isTrue);
      expect(validator.validate(0), isFalse);
      expect(validator.validate(-1), isFalse);
    });

    test('percentage should validate percentages', () {
      final validator = CommonValidators.percentage;

      expect(validator.validate(0.0), isTrue);
      expect(validator.validate(0.5), isTrue);
      expect(validator.validate(1.0), isTrue);
      expect(validator.validate(-0.1), isFalse);
      expect(validator.validate(1.1), isFalse);
    });
  });
}
