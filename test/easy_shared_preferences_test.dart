import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_shared_preferences/easy_shared_preferences.dart';

void main() {
  // Set up Flutter test environment
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('Settings Framework Tests', () {
    late Settings appSettings;
    late SettingsStore store;
    
    setUp(() async {
      // Clear SharedPreferences before each test using the simpler mock approach
      // This is compatible with both SharedPreferences and SharedPreferencesWithCache
      SharedPreferences.setMockInitialValues({});

      // Create fresh instances for each test
      store = SettingsStore(forceRegularSharedPreferences: true);
      appSettings = Settings(store: store);
    });

    tearDown(() async {
      // Clear settings registry first
      appSettings.dispose();

      // Clear SharedPreferences data
      try {
        SharedPreferences.setMockInitialValues({});
      } catch (e) {
        // Ignore SharedPreferences clearing errors in tests
      }
    });

    group('Exception Classes', () {
      test('SettingNotFoundException should format message correctly', () {
        const exception = SettingNotFoundException('Test setting not found');

        expect(exception.message, equals('Test setting not found'));
        expect(
          exception.toString(),
          equals('SettingNotFoundException: Test setting not found'),
        );
      });

      test(
        'SettingNotConfigurableException should format message correctly',
        () {
          const exception = SettingNotConfigurableException(
            'Setting cannot be modified',
          );

          expect(exception.message, equals('Setting cannot be modified'));
          expect(
            exception.toString(),
            equals(
              'SettingNotConfigurableException: Setting cannot be modified',
            ),
          );
        },
      );

      test('SettingValidationException should format message correctly', () {
        const exception = SettingValidationException('Value validation failed');

        expect(exception.message, equals('Value validation failed'));
        expect(
          exception.toString(),
          equals('SettingValidationException: Value validation failed'),
        );
      });

      test('SettingsNotReadyException should format message correctly', () {
        const exception = SettingsNotReadyException('Settings not initialized');

        expect(exception.message, equals('Settings not initialized'));
        expect(
          exception.toString(),
          equals('SettingsNotReadyException: Settings not initialized'),
        );
      });
    });

    group('Setting Types', () {
      test('BoolSetting should create with correct properties', () {
        final setting = BoolSetting(
          key: 'testBool',
          defaultValue: true,
          userConfigurable: false,
        );

        expect(setting.key, equals('testBool'));
        expect(setting.defaultValue, equals(true));
        expect(setting.type, equals(SettingType.bool));
        expect(setting.userConfigurable, equals(false));
        expect(setting.validator, isNull);
      });

      test('IntSetting should create with validator', () {
        final setting = IntSetting(
          key: 'testInt',
          defaultValue: 10,
          validator: (value) => value >= 0 && value <= 100,
        );

        expect(setting.key, equals('testInt'));
        expect(setting.defaultValue, equals(10));
        expect(setting.type, equals(SettingType.int));
        expect(setting.userConfigurable, equals(true)); // default
        expect(setting.validator, isNotNull);

        // Test validator function
        expect(setting.validator!(50), isTrue);
        expect(setting.validator!(-1), isFalse);
        expect(setting.validator!(150), isFalse);
      });

      test('DoubleSetting should validate range correctly', () {
        final setting = DoubleSetting(
          key: 'volume',
          defaultValue: 0.5,
          validator: (value) => value >= 0.0 && value <= 1.0,
        );

        expect(setting.key, equals('volume'));
        expect(setting.defaultValue, equals(0.5));
        expect(setting.type, equals(SettingType.double));

        // Test validator
        expect(setting.validator!(0.0), isTrue);
        expect(setting.validator!(1.0), isTrue);
        expect(setting.validator!(0.75), isTrue);
        expect(setting.validator!(-0.1), isFalse);
        expect(setting.validator!(1.1), isFalse);
      });

      test('StringSetting should validate enum values', () {
        final setting = StringSetting(
          key: 'theme',
          defaultValue: 'light',
          validator: (value) => ['light', 'dark', 'auto'].contains(value),
        );

        expect(setting.key, equals('theme'));
        expect(setting.defaultValue, equals('light'));
        expect(setting.type, equals(SettingType.string));

        // Test validator
        expect(setting.validator!('light'), isTrue);
        expect(setting.validator!('dark'), isTrue);
        expect(setting.validator!('auto'), isTrue);
        expect(setting.validator!('invalid'), isFalse);
      });
    });

    group('Setting Streams and Notifications', () {
      test('Setting should have stream property', () {
        final setting = BoolSetting(key: 'testStream', defaultValue: false);

        expect(setting.stream, isA<Stream<bool>>());
        setting.dispose();
      });

      test('Setting dispose should close stream', () async {
        final setting = StringSetting(key: 'disposeTest', defaultValue: 'test');

        bool streamClosed = false;
        final subscription = setting.stream.listen(
          (value) {},
          onDone: () => streamClosed = true,
        );

        setting.dispose();
        await Future.delayed(Duration(milliseconds: 10));

        expect(streamClosed, isTrue);
        await subscription.cancel();
      });
    });

    group('SettingsGroup', () {
      test('should create group with multiple settings', () {
        final group = SettingsGroup(
          key: 'test_group',
          items: [
            BoolSetting(key: 'setting1', defaultValue: true),
            IntSetting(key: 'setting2', defaultValue: 42),
            StringSetting(key: 'setting3', defaultValue: 'test'),
          ],
          store: store,
        );

        expect(group.length, equals(3));
        expect(group.keys, containsAll(['setting1', 'setting2', 'setting3']));
      });

      test('should provide map-like access to settings', () {
        final boolSetting = BoolSetting(key: 'enabled', defaultValue: true);
        final intSetting = IntSetting(key: 'count', defaultValue: 5);

        final group = SettingsGroup(
          key: 'access_test',
          items: [boolSetting, intSetting],
          store: store,
        );

        expect(group['enabled'], equals(boolSetting));
        expect(group['count'], equals(intSetting));
      });

      test('should be null if settingsgroup does not exist', () {
        final group = SettingsGroup(
          key: 'null_test',
          items: [BoolSetting(key: 'existing', defaultValue: true)],
          store: store,
        );

        expect(group['nonexistent'], isNull);
      });
    });

    group('SettingsGroup Integration', () {
      test('should initialize and store default values', () async {
        final gameSettings = SettingsGroup.forTesting(
          key: 'game',
          items: [
            BoolSetting(key: 'soundEnabled', defaultValue: true),
            DoubleSetting(key: 'volume', defaultValue: 0.8),
            IntSetting(key: 'maxRetries', defaultValue: 3),
            StringSetting(key: 'difficulty', defaultValue: 'normal'),
          ],
        );

        await gameSettings.readyFuture;

        expect(gameSettings.ready, isTrue);
        expect(gameSettings.get<bool>('soundEnabled'), isTrue);
        expect(gameSettings.get<double>('volume'), equals(0.8));
        expect(gameSettings.get<int>('maxRetries'), equals(3));
        expect(gameSettings.get<String>('difficulty'), equals('normal'));
      });

      test('should set and get values correctly', () async {
        final settings = SettingsGroup.forTesting(
          key: 'test',
          items: [
            BoolSetting(key: 'flag', defaultValue: false),
            IntSetting(key: 'number', defaultValue: 0),
          ],
        );

        await settings.readyFuture;

        await settings.setValue('flag', true);
        await settings.setValue('number', 42);

        expect(settings.get<bool>('flag'), isTrue);
        expect(settings.get<int>('number'), equals(42));
      });

      test('should validate values before setting', () async {
        final settings = SettingsGroup.forTesting(
          key: 'validation',
          items: [
            IntSetting(
              key: 'percentage',
              defaultValue: 50,
              validator: (value) => value >= 0 && value <= 100,
            ),
          ],
        );

        await settings.readyFuture;

        // Valid value should work
        await settings.setValue('percentage', 75);
        expect(settings.get<int>('percentage'), equals(75));

        // Invalid value should throw
        expect(
          () => settings.setValue('percentage', 150),
          throwsA(isA<SettingValidationException>()),
        );
      });

      test(
        'should prevent modification of non-configurable settings',
        () async {
          final settings = SettingsGroup.forTesting(
            key: 'system',
            items: [
              BoolSetting(
                key: 'readonly',
                defaultValue: true,
                userConfigurable: false,
              ),
            ],
          );

          await settings.readyFuture;

          expect(
            () => settings.setValue('readonly', false),
            throwsA(isA<SettingNotConfigurableException>()),
          );
        },
      );

      test('should throw when accessing before ready', () {
        final settings = SettingsGroup.forTesting(
          key: 'notready',
          items: [BoolSetting(key: 'test', defaultValue: true)],
        );

        expect(
          () => settings.get<bool>('test'),
          throwsA(isA<SettingsNotReadyException>()),
        );
      });

      test('should throw for non-existent settings', () async {
        final settings = SettingsGroup.forTesting(
          key: 'missing',
          items: [BoolSetting(key: 'exists', defaultValue: true)],
        );

        await settings.readyFuture;

        expect(
          () => settings.get<bool>('nonexistent'),
          throwsA(isA<SettingNotFoundException>()),
        );
      });

      test('should reset individual setting to default', () async {
        final settings = SettingsGroup.forTesting(
          key: 'reset',
          items: [IntSetting(key: 'counter', defaultValue: 0)],
        );

        await settings.readyFuture;

        // Change value
        await settings.setValue('counter', 42);
        expect(settings.get<int>('counter'), equals(42));

        // Reset to default
        await settings.reset('counter');
        expect(settings.get<int>('counter'), equals(0));
      });

      test('should reset all settings in group', () async {
        final settings = SettingsGroup.forTesting(
          key: 'resetall',
          items: [
            BoolSetting(key: 'flag', defaultValue: false),
            IntSetting(key: 'number', defaultValue: 10),
            StringSetting(key: 'text', defaultValue: 'default'),
          ],
        );

        await settings.readyFuture;

        // Change all values
        await settings.setValue('flag', true);
        await settings.setValue('number', 99);
        await settings.setValue('text', 'changed');

        // Verify changes
        expect(settings.get<bool>('flag'), isTrue);
        expect(settings.get<int>('number'), equals(99));
        expect(settings.get<String>('text'), equals('changed'));

        // Reset all
        await settings.resetAll();

        // Verify defaults restored
        expect(settings.get<bool>('flag'), isFalse);
        expect(settings.get<int>('number'), equals(10));
        expect(settings.get<String>('text'), equals('default'));
      });

      test('should notify changes on setting streams', () async {
        final settings = SettingsGroup.forTesting(
          key: 'notify',
          items: [BoolSetting(key: 'notifiable', defaultValue: false)],
        );

        await settings.readyFuture;

        final events = <bool>[];
        final subscription = settings['notifiable']!.stream.listen((value) {
          events.add(value as bool);
        });

        await settings.setValue('notifiable', true);
        await settings.setValue('notifiable', false);

        await Future.delayed(Duration(milliseconds: 50));

        expect(events, equals([true, false]));

        await subscription.cancel();
      });
    });

    group('Concurrent Access and Thread Safety', () {
      test('should handle concurrent setting modifications', () async {
        final settings = SettingsGroup.forTesting(
          key: 'concurrent',
          items: [IntSetting(key: 'counter', defaultValue: 0)],
        );

        appSettings.register(settings);
        await appSettings.init();

        // Simulate concurrent modifications
        final futures = List.generate(10, (i) async {
          await appSettings.setInt('concurrent.counter', i);
          return appSettings.getInt('concurrent.counter');
        });

        final results = await Future.wait(futures);

        // At least one operation should complete successfully
        expect(results.any((result) => result >= 0), isTrue);

        appSettings.dispose();
      });

      test('should handle concurrent stream listeners', () async {
        final settings = SettingsGroup.forTesting(
          key: 'streams',
          items: [BoolSetting(key: 'flag', defaultValue: false)],
        );

        appSettings.register(settings);
        await appSettings.init();

        final events1 = <bool>[];
        final events2 = <bool>[];

        final sub1 = settings['flag']!.stream.listen(
              (value) => events1.add(value as bool),
            );
        final sub2 = settings['flag']!.stream.listen(
              (value) => events2.add(value as bool),
            );

        await appSettings.setBool('streams.flag', true);
        await appSettings.setBool('streams.flag', false);

        await Future.delayed(Duration(milliseconds: 50));

        expect(events1, equals([true, false]));
        expect(events2, equals([true, false]));

        await sub1.cancel();
        await sub2.cancel();
        appSettings.dispose();
      });
    });

    group('Error Recovery and Edge Cases', () {
      test('should handle missing keys gracefully', () async {
        final settings = SettingsGroup.forTesting(
          key: 'missing',
          items: [BoolSetting(key: 'exists', defaultValue: true)],
        );

        appSettings.register(settings);
        await appSettings.init();

        // Simulate missing key in storage
        await store.readyFuture;
        await store.prefs.remove('missing.exists');

        // Should fall back to default value
        expect(appSettings.getBool('missing.exists'), isTrue);

        appSettings.dispose();
      });

      test('should handle type mismatches in storage (default)', () async {
        final settings = SettingsGroup.forTesting(
          key: 'typemismatch',
          items: [IntSetting(key: 'number', defaultValue: 42)],
        );

        appSettings.register(settings);
        await appSettings.init();

        // Manually set wrong type in storage
        await store.readyFuture;
        await store.prefs.setString('typemismatch.number', 'not-a-number');

        // Should handle type mismatch gracefully
        expect(
          appSettings.getInt('typemismatch.number'),
          equals(42), // Should return default value
        );

        appSettings.dispose();
      });

      test('should handle validation during initialization', () async {
        // Create setting with validator
        final settings = SettingsGroup.forTesting(
          key: 'initvalidation',
          items: [
            IntSetting(
              key: 'validated',
              defaultValue: 50,
              validator: (value) => value >= 0 && value <= 100,
            ),
          ],
        );

        // Pre-populate with invalid value
        await store.readyFuture;
        await store.prefs.setInt('initvalidation.validated', 150);

        appSettings.register(settings);
        await appSettings.init();

        // Should use default value when stored value is invalid
        expect(appSettings.getInt('initvalidation.validated'), equals(50));

        appSettings.dispose();
      });
    });

    group('SharedPreferences Integration', () {
      test('should work with regular SharedPreferences in tests', () async {
        final settings = SettingsGroup.forTesting(
          key: 'regular',
          items: [StringSetting(key: 'text', defaultValue: 'default')],
        );

        appSettings.register(settings);
        await appSettings.init();

        await appSettings.setString('regular.text', 'test-value');
        expect(appSettings.getString('regular.text'), equals('test-value'));

        appSettings.dispose();
      });

      test('should persist across multiple initializations', () async {
        // First initialization
        final settings1 = SettingsGroup.forTesting(
          key: 'persist-test',
          items: [BoolSetting(key: 'flag', defaultValue: false)],
        );

        appSettings.register(settings1);
        await appSettings.init();
        await appSettings.setBool('persist-test.flag', true);
        appSettings.dispose();

        // Create new Settings instance and store for second initialization
        final newStore = SettingsStore(forceRegularSharedPreferences: true);
        final newSettings = Settings(store: newStore);
        
        // Second initialization with same structure
        final settings2 = SettingsGroup.forTesting(
          key: 'persist-test',
          items: [BoolSetting(key: 'flag', defaultValue: false)],
        );

        newSettings.register(settings2);
        await newSettings.init();

        // Value should persist
        expect(newSettings.getBool('persist-test.flag'), isTrue);

        // Clean up
        newSettings.dispose();
      });
    });

    group('Global Settings Manager', () {
      test('should register and initialize multiple groups', () async {
        final gameSettings = SettingsGroup.forTesting(
          key: 'game',
          items: [BoolSetting(key: 'sound', defaultValue: true)],
        );

        final uiSettings = SettingsGroup.forTesting(
          key: 'ui',
          items: [StringSetting(key: 'theme', defaultValue: 'light')],
        );

        appSettings.register(gameSettings);
        appSettings.register(uiSettings);

        await appSettings.init();

        expect(appSettings.groups.length, equals(2));
        expect(appSettings.groupKeys, containsAll(['game', 'ui']));

        // Clean up for other tests
        appSettings.dispose();
      });

      test('should prevent duplicate group registration', () {
        final settings1 = SettingsGroup.forTesting(
          key: 'duplicate',
          items: [BoolSetting(key: 'test', defaultValue: true)],
        );

        final settings2 = SettingsGroup.forTesting(
          key: 'duplicate', // Same key
          items: [IntSetting(key: 'other', defaultValue: 42)],
        );

        appSettings.register(settings1);

        expect(
          () => appSettings.register(settings2),
          throwsA(isA<ArgumentError>()),
        );

        appSettings.dispose();
      });

      test('should access settings using dot notation', () async {
        final gameSettings = SettingsGroup.forTesting(
          key: 'game',
          items: [
            BoolSetting(key: 'soundEnabled', defaultValue: true),
            DoubleSetting(key: 'volume', defaultValue: 0.8),
          ],
        );

        appSettings.register(gameSettings);
        await appSettings.init();

        expect(appSettings.getBool('game.soundEnabled'), isTrue);
        expect(appSettings.getDouble('game.volume'), equals(0.8));
        expect(appSettings.get<bool>('game.soundEnabled'), isTrue);
        // Dynamic access operator not available in static context
        expect(appSettings.get<dynamic>('game.soundEnabled'), isTrue);
      });

      test('should set values using dot notation', () async {
        final uiSettings = SettingsGroup.forTesting(
          key: 'ui',
          items: [
            StringSetting(key: 'theme', defaultValue: 'light'),
            IntSetting(key: 'fontSize', defaultValue: 14),
          ],
        );

        appSettings.register(uiSettings);
        await appSettings.init();

        await appSettings.setString('ui.theme', 'dark');
        await appSettings.setInt('ui.fontSize', 16);

        expect(appSettings.getString('ui.theme'), equals('dark'));
        expect(appSettings.getInt('ui.fontSize'), equals(16));
      });

      test('should support batch operations', () async {
        final settings = SettingsGroup.forTesting(
          key: 'batch',
          items: [
            BoolSetting(key: 'flag1', defaultValue: false),
            BoolSetting(key: 'flag2', defaultValue: false),
            IntSetting(key: 'number', defaultValue: 0),
            StringSetting(key: 'text', defaultValue: 'default'),
          ],
        );

        appSettings.register(settings);
        await appSettings.init();

        // Batch set multiple values
        await appSettings.setMultiple({
          'batch.flag1': true,
          'batch.flag2': true,
          'batch.number': 42,
          'batch.text': 'batch updated',
        });

        // Verify all changes
        expect(appSettings.getBool('batch.flag1'), isTrue);
        expect(appSettings.getBool('batch.flag2'), isTrue);
        expect(appSettings.getInt('batch.number'), equals(42));
        expect(appSettings.getString('batch.text'), equals('batch updated'));
      });

      test('should reset individual settings globally', () async {
        final testSettings = SettingsGroup.forTesting(
          key: 'globalreset',
          items: [IntSetting(key: 'value', defaultValue: 100)],
        );

        appSettings.register(testSettings);
        await appSettings.init();

        await appSettings.setInt('globalreset.value', 999);
        expect(appSettings.getInt('globalreset.value'), equals(999));

        await appSettings.resetSetting('globalreset.value');
        expect(appSettings.getInt('globalreset.value'), equals(100));
      });

      test('should reset entire groups globally', () async {
        final groupSettings = SettingsGroup.forTesting(
          key: 'groupreset',
          items: [
            BoolSetting(key: 'flag', defaultValue: false),
            IntSetting(key: 'count', defaultValue: 5),
          ],
        );

        appSettings.register(groupSettings);
        await appSettings.init();

        // Change values
        await appSettings.setBool('groupreset.flag', true);
        await appSettings.setInt('groupreset.count', 25);

        // Reset entire group
        await appSettings.resetGroup('groupreset');

        // Verify defaults restored
        expect(appSettings.getBool('groupreset.flag'), isFalse);
        expect(appSettings.getInt('groupreset.count'), equals(5));
      });

      test('should reset all settings globally', () async {
        final group1 = SettingsGroup.forTesting(
          key: 'group1',
          items: [BoolSetting(key: 'setting', defaultValue: false)],
        );

        final group2 = SettingsGroup.forTesting(
          key: 'group2',
          items: [IntSetting(key: 'setting', defaultValue: 10)],
        );

        appSettings.register(group1);
        appSettings.register(group2);
        await appSettings.init();

        // Change values in both groups
        await appSettings.setBool('group1.setting', true);
        await appSettings.setInt('group2.setting', 50);

        // Reset everything
        await appSettings.resetAll();

        // Verify all defaults restored
        expect(appSettings.getBool('group1.setting'), isFalse);
        expect(appSettings.getInt('group2.setting'), equals(10));
      });

      test('should handle invalid storage keys', () async {
        final testSettings = SettingsGroup.forTesting(
          key: 'invalid',
          items: [BoolSetting(key: 'test', defaultValue: true)],
        );

        appSettings.register(testSettings);
        await appSettings.init();

        // Missing dot notation
        expect(
          () => appSettings.getBool('invalidkey'),
          throwsA(isA<ArgumentError>()),
        );

        // Non-existent group
        expect(
          () => appSettings.getBool('nonexistent.setting'),
          throwsA(isA<SettingNotFoundException>()),
        );

        // Non-existent setting in valid group
        expect(
          () => appSettings.getBool('invalid.nonexistent'),
          throwsA(isA<SettingNotFoundException>()),
        );
      });

      test('should dispose all resources properly', () async {
        final testSettings = SettingsGroup.forTesting(
          key: 'dispose',
          items: [BoolSetting(key: 'test', defaultValue: true)],
        );

        appSettings.register(testSettings);
        await appSettings.init();

        // This should not throw
        appSettings.dispose();
      });

      test('should call change callbacks when settings change', () async {
        final testSettings = SettingsGroup.forTesting(
          key: 'callbacks',
          items: [BoolSetting(key: 'flag', defaultValue: false)],
        );

        appSettings.register(testSettings);
        await appSettings.init();

        final changeEvents = <Map<String, dynamic>>[];
        appSettings.addChangeCallback((key, oldValue, newValue) {
          changeEvents.add({
            'key': key,
            'oldValue': oldValue,
            'newValue': newValue,
          });
        });

        await appSettings.setBool('callbacks.flag', true);
        await appSettings.setBool('callbacks.flag', false);

        expect(changeEvents.length, equals(2));
        expect(changeEvents[0]['key'], equals('callbacks.flag'));
        expect(changeEvents[0]['oldValue'], equals(false));
        expect(changeEvents[0]['newValue'], equals(true));
        expect(changeEvents[1]['key'], equals('callbacks.flag'));
        expect(changeEvents[1]['oldValue'], equals(true));
        expect(changeEvents[1]['newValue'], equals(false));
      });

      test('should call change callbacks on reset operations', () async {
        final testSettings = SettingsGroup.forTesting(
          key: 'resetcallbacks',
          items: [IntSetting(key: 'counter', defaultValue: 0)],
        );

        appSettings.register(testSettings);
        await appSettings.init();

        // Change from default
        await appSettings.setInt('resetcallbacks.counter', 42);

        final changeEvents = <Map<String, dynamic>>[];
        appSettings.addChangeCallback((key, oldValue, newValue) {
          changeEvents.add({
            'key': key,
            'oldValue': oldValue,
            'newValue': newValue,
          });
        });

        await appSettings.resetSetting('resetcallbacks.counter');

        expect(changeEvents.length, equals(1));
        expect(changeEvents[0]['key'], equals('resetcallbacks.counter'));
        expect(changeEvents[0]['oldValue'], equals(42));
        expect(changeEvents[0]['newValue'], equals(0));
      });
    });

    group('Type Safety and Error Handling', () {
      test('should enforce type safety in get operations', () async {
        final settings = SettingsGroup.forTesting(
          key: 'types',
          items: [
            BoolSetting(key: 'flag', defaultValue: true),
            IntSetting(key: 'number', defaultValue: 42),
          ],
        );

        appSettings.register(settings);
        await appSettings.init();

        // Correct types should work
        expect(appSettings.getBool('types.flag'), isTrue);
        expect(appSettings.getInt('types.number'), equals(42));

        // Wrong types should throw
        expect(
          () => appSettings.getInt('types.flag'), // flag is bool, not int
          throwsA(isA<ArgumentError>()),
        );

        expect(
          () => appSettings.getBool('types.number'), // number is int, not bool
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should handle validation errors properly', () async {
        final settings = SettingsGroup.forTesting(
          key: 'validation',
          items: [
            DoubleSetting(
              key: 'percentage',
              defaultValue: 0.5,
              validator: (value) => value >= 0.0 && value <= 1.0,
            ),
          ],
        );

        appSettings.register(settings);
        await appSettings.init();

        // Valid values should work
        await appSettings.setDouble('validation.percentage', 0.75);
        expect(appSettings.getDouble('validation.percentage'), equals(0.75));

        // Invalid values should throw with descriptive message
        try {
          await appSettings.setDouble('validation.percentage', 1.5);
          fail('Should have thrown SettingValidationException');
        } catch (e) {
          expect(e, isA<SettingValidationException>());
          expect(e.toString(), contains('Invalid value'));
          expect(e.toString(), contains('1.5'));
        }
      });

      test('should preserve original values on validation failure', () async {
        final settings = SettingsGroup.forTesting(
          key: 'preserve',
          items: [
            IntSetting(
              key: 'bounded',
              defaultValue: 50,
              validator: (value) => value >= 0 && value <= 100,
            ),
          ],
        );

        appSettings.register(settings);
        await appSettings.init();

        // Set a valid value
        await appSettings.setInt('preserve.bounded', 75);
        expect(appSettings.getInt('preserve.bounded'), equals(75));

        // Attempt invalid value
        try {
          await appSettings.setInt('preserve.bounded', 150);
        } catch (e) {
          // Validation should fail, value should remain unchanged
          expect(appSettings.getInt('preserve.bounded'), equals(75));
        }
      });
    });

    group('Persistence and Storage', () {
      test('should persist values across instances', () async {
        // Create initial settings and set values
        final settings1 = SettingsGroup.forTesting(
          key: 'persist',
          items: [
            BoolSetting(key: 'flag', defaultValue: false),
            StringSetting(key: 'text', defaultValue: 'default'),
          ],
        );

        appSettings.register(settings1);
        await appSettings.init();

        await appSettings.setBool('persist.flag', true);
        await appSettings.setString('persist.text', 'persisted');

        // Dispose current instance
        appSettings.dispose();

        // Create new Settings instance and store
        final newStore = SettingsStore(forceRegularSharedPreferences: true);
        final newSettings = Settings(store: newStore);
        
        // Create new instance with same key structure
        final settings2 = SettingsGroup.forTesting(
          key: 'persist',
          items: [
            BoolSetting(key: 'flag', defaultValue: false),
            StringSetting(key: 'text', defaultValue: 'default'),
          ],
        );

        newSettings.register(settings2);
        await newSettings.init();

        // Values should be persisted
        expect(newSettings.getBool('persist.flag'), isTrue);
        expect(newSettings.getString('persist.text'), equals('persisted'));
        
        // Clean up
        newSettings.dispose();
      });

      test('should use default values for new settings', () async {
        // Create settings with some values
        final initialSettings = SettingsGroup.forTesting(
          key: 'expand',
          items: [BoolSetting(key: 'existing', defaultValue: false)],
        );

        appSettings.register(initialSettings);
        await appSettings.init();

        await appSettings.setBool('expand.existing', true);
        appSettings.dispose();

        // Create new Settings instance and store
        final newStore = SettingsStore(forceRegularSharedPreferences: true);
        final newSettings = Settings(store: newStore);
        
        // Create expanded settings with new setting
        final expandedSettings = SettingsGroup.forTesting(
          key: 'expand',
          items: [
            BoolSetting(key: 'existing', defaultValue: false),
            IntSetting(key: 'newSetting', defaultValue: 42), // New setting
          ],
        );

        newSettings.register(expandedSettings);
        await newSettings.init();

        // Existing setting should retain value
        expect(newSettings.getBool('expand.existing'), isTrue);

        // New setting should use default
        expect(newSettings.getInt('expand.newSetting'), equals(42));
        
        // Clean up
        newSettings.dispose();
      });
    });
  });
}
