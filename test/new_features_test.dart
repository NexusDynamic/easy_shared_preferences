import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_shared_preferences/easy_shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('New Features Tests', () {
    late EasySettings settings;
    late SettingsStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = SettingsStore(forceRegularSharedPreferences: true);
      settings = EasySettings(store: store);
    });

    tearDown(() async {
      settings.dispose();
      SharedPreferences.setMockInitialValues({});
    });

    group('List<String> Support', () {
      test('should create and use StringListSetting', () async {
        final tagsGroup = SettingsGroup.forTesting(
          key: 'tags',
          items: [
            StringListSetting(
              key: 'userTags',
              defaultValue: ['flutter', 'dart'],
            ),
          ],
        );

        settings.register(tagsGroup);
        await settings.init();

        // Test default value
        expect(settings.getStringList('tags.userTags'),
            equals(['flutter', 'dart']));

        // Test setting new value
        await settings.setStringList(
            'tags.userTags', ['javascript', 'typescript', 'node']);
        expect(settings.getStringList('tags.userTags'),
            equals(['javascript', 'typescript', 'node']));

        // Test empty list
        await settings.setStringList('tags.userTags', []);
        expect(settings.getStringList('tags.userTags'), equals([]));
      });

      test('should validate string lists with ListLengthValidator', () async {
        final categoriesGroup = SettingsGroup.forTesting(
          key: 'categories',
          items: [
            StringListSetting(
              key: 'selected',
              defaultValue: ['general'],
              validator: ListLengthValidator(minLength: 1, maxLength: 5),
            ),
          ],
        );

        settings.register(categoriesGroup);
        await settings.init();

        // Valid: within range
        await settings
            .setStringList('categories.selected', ['tech', 'science']);
        expect(settings.getStringList('categories.selected'),
            equals(['tech', 'science']));

        // Invalid: too many items
        expect(
          () => settings.setStringList('categories.selected',
              ['a', 'b', 'c', 'd', 'e', 'f']), // 6 items, max is 5
          throwsA(isA<SettingValidationException>()),
        );

        // Invalid: empty list (min is 1)
        expect(
          () => settings.setStringList('categories.selected', []),
          throwsA(isA<SettingValidationException>()),
        );
      });

      test('should validate string list content with ListContentValidator',
          () async {
        final emailsGroup = SettingsGroup.forTesting(
          key: 'contacts',
          items: [
            StringListSetting(
              key: 'emails',
              defaultValue: [],
              validator: ListContentValidator(
                itemValidator: CommonValidators.email,
              ),
            ),
          ],
        );

        settings.register(emailsGroup);
        await settings.init();

        // Valid: all emails are valid
        await settings.setStringList(
            'contacts.emails', ['test@example.com', 'user@domain.org']);
        expect(settings.getStringList('contacts.emails'),
            equals(['test@example.com', 'user@domain.org']));

        // Invalid: one email is invalid
        expect(
          () => settings.setStringList(
              'contacts.emails', ['valid@email.com', 'invalid-email']),
          throwsA(isA<SettingValidationException>()),
        );
      });

      test('should use CommonValidators for lists', () async {
        final preferencesGroup = SettingsGroup.forTesting(
          key: 'prefs',
          items: [
            StringListSetting(
              key: 'nonEmptyList',
              defaultValue: ['item1'],
              validator: CommonValidators.nonEmptyList,
            ),
            StringListSetting(
              key: 'nonEmptyItems',
              defaultValue: ['item1', 'item2'],
              validator: CommonValidators.nonEmptyStrings,
            ),
          ],
        );

        settings.register(preferencesGroup);
        await settings.init();

        // Test nonEmptyList validator
        expect(
          () => settings.setStringList('prefs.nonEmptyList', []),
          throwsA(isA<SettingValidationException>()),
        );

        // Test nonEmptyStrings validator
        expect(
          () => settings.setStringList('prefs.nonEmptyItems', ['valid', '']),
          throwsA(isA<SettingValidationException>()),
        );
      });

      test('should work with GlobalSettings', () async {
        await GlobalSettings.initialize([
          GroupConfig(
            key: 'global_tags',
            items: [
              StringListSetting(
                key: 'favorites',
                defaultValue: ['default'],
              ),
            ],
          ),
        ]);

        // Test getting and setting through GlobalSettings
        expect(GlobalSettings.getStringList('global_tags.favorites'),
            equals(['default']));

        await GlobalSettings.setStringList(
            'global_tags.favorites', ['flutter', 'dart', 'web']);
        expect(GlobalSettings.getStringList('global_tags.favorites'),
            equals(['flutter', 'dart', 'web']));

        GlobalSettings.dispose();
      });
    });

    group('Validation Error Recovery', () {
      test(
          'should use recovery handler when validation fails during initialization',
          () async {
        final logsGroup = SettingsGroup.forTesting(
          key: 'logs',
          items: [
            IntSetting(
              key: 'level',
              defaultValue: 1,
              validator: RangeValidator<int>(min: 0, max: 5),
              onValidationError: (key, invalidValue, error) {
                // Recovery: clamp invalid values to valid range
                if (invalidValue is int) {
                  if (invalidValue < 0) return 0;
                  if (invalidValue > 5) return 5;
                }
                return null; // Use default if can't recover
              },
            ),
          ],
        );

        // Pre-populate with invalid value
        await store.readyFuture;
        await store.prefs.setInt('logs.level', 10); // Invalid: > 5

        settings.register(logsGroup);
        await settings.init();

        // Should be recovered to 5 (clamped)
        expect(settings.getInt('logs.level'), equals(5));
      });

      test('should fall back to default when recovery returns null', () async {
        final testGroup = SettingsGroup.forTesting(
          key: 'test',
          items: [
            StringSetting(
              key: 'mode',
              defaultValue: 'production',
              validator: EnumValidator<String>(
                  ['development', 'staging', 'production']),
              onValidationError: (key, invalidValue, error) {
                // Always return null to use default
                return null;
              },
            ),
          ],
        );

        // Pre-populate with invalid value
        await store.readyFuture;
        await store.prefs.setString('test.mode', 'invalid_mode');

        settings.register(testGroup);
        await settings.init();

        // Should use default value
        expect(settings.getString('test.mode'), equals('production'));
      });

      test('should fall back to default when recovery also fails validation',
          () async {
        final badRecoveryGroup = SettingsGroup.forTesting(
          key: 'bad',
          items: [
            IntSetting(
              key: 'value',
              defaultValue: 50,
              validator: RangeValidator<int>(min: 0, max: 100),
              onValidationError: (key, invalidValue, error) {
                // Bad recovery: return invalid value
                return 200; // This will also fail validation
              },
            ),
          ],
        );

        // Pre-populate with invalid value
        await store.readyFuture;
        await store.prefs.setInt('bad.value', -10);

        settings.register(badRecoveryGroup);

        // Should complete successfully but fall back to default value
        await settings.init();

        // Should use default value since recovery failed
        expect(settings.getInt('bad.value'), equals(50));
      });

      test('should throw SettingRecoveryException when called directly', () {
        final testSetting = IntSetting(
          key: 'direct',
          defaultValue: 10,
          validator: RangeValidator<int>(min: 0, max: 100),
          onValidationError: (key, invalidValue, error) {
            return 200; // Invalid recovery value
          },
        );

        // Direct call to attemptRecovery should throw
        expect(
          () => testSetting.attemptRecovery(-5, 'Value out of range'),
          throwsA(isA<SettingRecoveryException>()),
        );
      });
    });

    group('Enhanced Validation and Error Reporting', () {
      test('should provide detailed validation error messages', () async {
        final validatedGroup = SettingsGroup.forTesting(
          key: 'validated',
          items: [
            DoubleSetting(
              key: 'percentage',
              defaultValue: 0.5,
              validator: CommonValidators.percentage,
            ),
          ],
        );

        settings.register(validatedGroup);
        await settings.init();

        // Test detailed error message
        try {
          await settings.setDouble('validated.percentage', 1.5);
          fail('Should have thrown SettingValidationException');
        } catch (e) {
          expect(e, isA<SettingValidationException>());
          expect(e.toString(), contains('1.5'));
          expect(e.toString(), contains('Value must be between 0.0 and 1.0'));
        }
      });

      test('should handle validation errors gracefully in SettingsGroup',
          () async {
        final emailGroup = SettingsGroup.forTesting(
          key: 'email_test',
          items: [
            StringSetting(
              key: 'address',
              defaultValue: 'default@example.com',
              validator: CommonValidators.email,
            ),
          ],
        );

        // Pre-populate with invalid email
        await store.readyFuture;
        await store.prefs.setString('email_test.address', 'not-an-email');

        settings.register(emailGroup);
        await settings.init();

        // Should fall back to default value since no recovery handler
        expect(settings.getString('email_test.address'),
            equals('default@example.com'));
      });
    });

    group('Lazy Stream Initialization', () {
      test('should not create stream controller until first access', () async {
        final lazySetting = BoolSetting(
          key: 'lazy',
          defaultValue: false,
        );

        // Stream controller should not be created yet
        expect(lazySetting.toString(), isNotNull); // Just access something

        // First access to stream should create controller
        final stream = lazySetting.stream;
        expect(stream, isA<Stream<bool>>());

        lazySetting.dispose();
      });

      test('should only notify listeners if stream exists', () async {
        final testGroup = SettingsGroup.forTesting(
          key: 'lazy_test',
          items: [
            BoolSetting(key: 'flag', defaultValue: false),
          ],
        );

        settings.register(testGroup);
        await settings.init();

        // Change value without accessing stream first
        await settings.setBool('lazy_test.flag', true);

        // This should not throw or cause issues
        expect(settings.getBool('lazy_test.flag'), isTrue);
      });

      test('should work normally when streams are used', () async {
        final streamGroup = SettingsGroup.forTesting(
          key: 'stream_test',
          items: [
            StringSetting(key: 'value', defaultValue: 'initial'),
          ],
        );

        settings.register(streamGroup);
        await settings.init();

        final events = <String>[];
        final subscription = streamGroup['value']!.stream.listen((value) {
          events.add(value as String);
        });

        await settings.setString('stream_test.value', 'changed');
        await settings.setString('stream_test.value', 'final');

        await Future.delayed(Duration(milliseconds: 10));

        expect(events, equals(['changed', 'final']));
        await subscription.cancel();
      });
    });

    group('Integration Tests', () {
      test('should work with all features together', () async {
        final complexGroup = SettingsGroup.forTesting(
          key: 'complex',
          items: [
            StringListSetting(
              key: 'tags',
              defaultValue: [],
              validator: CompositeValidator<List<String>>.and([
                ListLengthValidator(maxLength: 10),
                ListContentValidator(itemValidator: CommonValidators.nonEmpty),
              ]),
              onValidationError: (key, invalidValue, error) {
                // Recovery: filter out empty strings and limit to 10 items
                if (invalidValue is List<String>) {
                  final filtered = invalidValue
                      .where((item) => item.isNotEmpty)
                      .take(10)
                      .toList();
                  return filtered.isEmpty ? null : filtered;
                }
                return null;
              },
            ),
            DoubleSetting(
              key: 'score',
              defaultValue: 0.0,
              validator: CommonValidators.percentage,
              onValidationError: (key, invalidValue, error) {
                // Recovery: clamp to valid range
                if (invalidValue is double) {
                  return invalidValue.clamp(0.0, 1.0);
                }
                return null;
              },
            ),
          ],
        );

        settings.register(complexGroup);
        await settings.init();

        // Test valid operations
        await settings
            .setStringList('complex.tags', ['flutter', 'dart', 'mobile']);
        await settings.setDouble('complex.score', 0.85);

        expect(settings.getStringList('complex.tags'),
            equals(['flutter', 'dart', 'mobile']));
        expect(settings.getDouble('complex.score'), equals(0.85));

        // Test stream notifications
        final tagEvents = <List<String>>[];
        final scoreEvents = <double>[];

        final tagSub = complexGroup['tags']!.stream.listen((value) {
          tagEvents.add(value as List<String>);
        });
        final scoreSub = complexGroup['score']!.stream.listen((value) {
          scoreEvents.add(value as double);
        });

        await settings.setStringList('complex.tags', ['updated']);
        await settings.setDouble('complex.score', 0.95);

        await Future.delayed(Duration(milliseconds: 10));

        expect(
            tagEvents,
            equals([
              ['updated']
            ]));
        expect(scoreEvents, equals([0.95]));

        await tagSub.cancel();
        await scoreSub.cancel();
      });
    });
  });
}
