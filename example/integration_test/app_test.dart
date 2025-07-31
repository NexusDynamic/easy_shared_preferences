import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:easy_shared_preferences/easy_shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Easy Shared Preferences Integration Tests', () {
    late SettingsStore store;
    late EasySettings settings;

    setUp(() async {
      // Initialize store and settings for each test
      store = SettingsStore();
      settings = EasySettings(store: store);

      // Clear any existing data
      await store.readyFuture;
      await store.prefs.clear();
    });

    tearDown(() async {
      settings.dispose();
    });

    testWidgets('Basic settings operations work across platforms',
        (tester) async {
      // Test basic setting types
      final testGroup = SettingsGroup(
        key: 'integration_test',
        items: [
          BoolSetting(key: 'testBool', defaultValue: false),
          IntSetting(key: 'testInt', defaultValue: 0),
          DoubleSetting(key: 'testDouble', defaultValue: 0.0),
          StringSetting(key: 'testString', defaultValue: 'default'),
        ],
        store: store,
      );

      settings.register(testGroup);
      await settings.init();

      // Test reading default values
      expect(settings.getBool('integration_test.testBool'), false);
      expect(settings.getInt('integration_test.testInt'), 0);
      expect(settings.getDouble('integration_test.testDouble'), 0.0);
      expect(settings.getString('integration_test.testString'), 'default');

      // Test setting new values
      await settings.setBool('integration_test.testBool', true);
      await settings.setInt('integration_test.testInt', 42);
      await settings.setDouble('integration_test.testDouble', 3.14);
      await settings.setString('integration_test.testString', 'updated');

      // Verify values were set
      expect(settings.getBool('integration_test.testBool'), true);
      expect(settings.getInt('integration_test.testInt'), 42);
      expect(settings.getDouble('integration_test.testDouble'), 3.14);
      expect(settings.getString('integration_test.testString'), 'updated');

      // Test persistence across store recreation
      settings.dispose();

      final newStore = SettingsStore();
      final newSettings = EasySettings(store: newStore);
      final newTestGroup = SettingsGroup(
        key: 'integration_test',
        items: [
          BoolSetting(key: 'testBool', defaultValue: false),
          IntSetting(key: 'testInt', defaultValue: 0),
          DoubleSetting(key: 'testDouble', defaultValue: 0.0),
          StringSetting(key: 'testString', defaultValue: 'default'),
        ],
        store: newStore,
      );

      newSettings.register(newTestGroup);
      await newSettings.init();

      // Values should persist
      expect(newSettings.getBool('integration_test.testBool'), true);
      expect(newSettings.getInt('integration_test.testInt'), 42);
      expect(newSettings.getDouble('integration_test.testDouble'), 3.14);
      expect(newSettings.getString('integration_test.testString'), 'updated');

      newSettings.dispose();
    });

    testWidgets('New List<String> support works across platforms',
        (tester) async {
      final listGroup = SettingsGroup(
        key: 'list_test',
        items: [
          StringListSetting(
            key: 'tags',
            defaultValue: ['default', 'tags'],
          ),
          StringListSetting(
            key: 'emptyList',
            defaultValue: [],
          ),
        ],
        store: store,
      );

      settings.register(listGroup);
      await settings.init();

      // Test default values
      expect(settings.getStringList('list_test.tags'), ['default', 'tags']);
      expect(settings.getStringList('list_test.emptyList'), []);

      // Test setting new values
      await settings
          .setStringList('list_test.tags', ['flutter', 'dart', 'mobile']);
      await settings
          .setStringList('list_test.emptyList', ['now', 'has', 'values']);

      // Verify values
      expect(settings.getStringList('list_test.tags'),
          ['flutter', 'dart', 'mobile']);
      expect(settings.getStringList('list_test.emptyList'),
          ['now', 'has', 'values']);

      // Test empty list
      await settings.setStringList('list_test.tags', []);
      expect(settings.getStringList('list_test.tags'), []);
    });

    testWidgets('Validation system works across platforms', (tester) async {
      final validationGroup = SettingsGroup(
        key: 'validation_test',
        items: [
          IntSetting(
            key: 'rangeInt',
            defaultValue: 5,
            validator: RangeValidator<int>(min: 1, max: 10),
          ),
          DoubleSetting(
            key: 'percentage',
            defaultValue: 0.5,
            validator: CommonValidators.percentage,
          ),
          StringSetting(
            key: 'email',
            defaultValue: 'test@example.com',
            validator: CommonValidators.email,
          ),
          StringListSetting(
            key: 'limitedList',
            defaultValue: ['item1'],
            validator: ListLengthValidator(minLength: 1, maxLength: 3),
          ),
        ],
        store: store,
      );

      settings.register(validationGroup);
      await settings.init();

      // Test valid values work
      await settings.setInt('validation_test.rangeInt', 7);
      await settings.setDouble('validation_test.percentage', 0.8);
      await settings.setString('validation_test.email', 'valid@email.com');
      await settings
          .setStringList('validation_test.limitedList', ['item1', 'item2']);

      expect(settings.getInt('validation_test.rangeInt'), 7);
      expect(settings.getDouble('validation_test.percentage'), 0.8);
      expect(settings.getString('validation_test.email'), 'valid@email.com');
      expect(settings.getStringList('validation_test.limitedList'),
          ['item1', 'item2']);

      // Test invalid values throw exceptions
      expect(
        () => settings.setInt('validation_test.rangeInt', 15),
        throwsA(isA<SettingValidationException>()),
      );
      expect(
        () => settings.setDouble('validation_test.percentage', 1.5),
        throwsA(isA<SettingValidationException>()),
      );
      expect(
        () => settings.setString('validation_test.email', 'invalid-email'),
        throwsA(isA<SettingValidationException>()),
      );
      expect(
        () => settings.setStringList('validation_test.limitedList', []),
        throwsA(isA<SettingValidationException>()),
      );
    });

    testWidgets('Validation error recovery works across platforms',
        (tester) async {
      // Pre-populate store with invalid values
      await store.readyFuture;
      await store.prefs.setInt('recovery_test.clampedInt', 15); // Invalid: > 10
      await store.prefs
          .setString('recovery_test.fallbackString', 'invalid_value');

      final recoveryGroup = SettingsGroup(
        key: 'recovery_test',
        items: [
          IntSetting(
            key: 'clampedInt',
            defaultValue: 5,
            validator: RangeValidator<int>(min: 1, max: 10),
            onValidationError: (key, invalidValue, error) {
              // Clamp invalid values to valid range
              if (invalidValue is int) {
                if (invalidValue < 1) return 1;
                if (invalidValue > 10) return 10;
              }
              return null; // Use default if can't recover
            },
          ),
          StringSetting(
            key: 'fallbackString',
            defaultValue: 'default_value',
            validator: EnumValidator<String>(['option1', 'option2', 'option3']),
            onValidationError: (key, invalidValue, error) {
              // Always fall back to default
              return null;
            },
          ),
        ],
        store: store,
      );

      settings.register(recoveryGroup);
      await settings.init();

      // Should recover the clamped value
      expect(settings.getInt('recovery_test.clampedInt'), 10);

      // Should fall back to default
      expect(
          settings.getString('recovery_test.fallbackString'), 'default_value');
    });

    testWidgets('Stream notifications work across platforms', (tester) async {
      final streamGroup = SettingsGroup(
        key: 'stream_test',
        items: [
          BoolSetting(key: 'watchedBool', defaultValue: false),
          StringSetting(key: 'watchedString', defaultValue: 'initial'),
        ],
        store: store,
      );

      settings.register(streamGroup);
      await settings.init();

      final boolEvents = <bool>[];
      final stringEvents = <String>[];

      final boolSub = streamGroup['watchedBool']!.stream.listen((value) {
        boolEvents.add(value as bool);
      });

      final stringSub = streamGroup['watchedString']!.stream.listen((value) {
        stringEvents.add(value as String);
      });

      // Make changes
      await settings.setBool('stream_test.watchedBool', true);
      await settings.setString('stream_test.watchedString', 'changed');
      await settings.setBool('stream_test.watchedBool', false);

      // Wait for stream events
      await tester.pump(const Duration(milliseconds: 100));

      expect(boolEvents, [true, false]);
      expect(stringEvents, ['changed']);

      await boolSub.cancel();
      await stringSub.cancel();
    });

    testWidgets('Global settings work across platforms', (tester) async {
      // Test GlobalSettings functionality
      await GlobalSettings.initialize([
        GroupConfig(
          key: 'global_test',
          items: [
            BoolSetting(key: 'globalBool', defaultValue: false),
            StringListSetting(key: 'globalList', defaultValue: ['global']),
          ],
        ),
      ]);

      // Test global access
      expect(GlobalSettings.getBool('global_test.globalBool'), false);
      expect(
          GlobalSettings.getStringList('global_test.globalList'), ['global']);

      // Test global setting
      await GlobalSettings.setBool('global_test.globalBool', true);
      await GlobalSettings.setStringList(
          'global_test.globalList', ['updated', 'list']);

      expect(GlobalSettings.getBool('global_test.globalBool'), true);
      expect(GlobalSettings.getStringList('global_test.globalList'),
          ['updated', 'list']);

      GlobalSettings.dispose();
    });

    testWidgets('Batch operations work across platforms', (tester) async {
      final batchGroup = SettingsGroup(
        key: 'batch_test',
        items: [
          BoolSetting(key: 'bool1', defaultValue: false),
          BoolSetting(key: 'bool2', defaultValue: false),
          IntSetting(key: 'int1', defaultValue: 0),
          StringSetting(key: 'string1', defaultValue: 'default'),
        ],
        store: store,
      );

      settings.register(batchGroup);
      await settings.init();

      // Test batch setting
      await settings.setMultiple({
        'batch_test.bool1': true,
        'batch_test.bool2': true,
        'batch_test.int1': 100,
        'batch_test.string1': 'batch_updated',
      });

      expect(settings.getBool('batch_test.bool1'), true);
      expect(settings.getBool('batch_test.bool2'), true);
      expect(settings.getInt('batch_test.int1'), 100);
      expect(settings.getString('batch_test.string1'), 'batch_updated');

      // Test batch reset
      await settings.resetGroup('batch_test');

      expect(settings.getBool('batch_test.bool1'), false);
      expect(settings.getBool('batch_test.bool2'), false);
      expect(settings.getInt('batch_test.int1'), 0);
      expect(settings.getString('batch_test.string1'), 'default');
    });

    testWidgets('Error handling works across platforms', (tester) async {
      final errorGroup = SettingsGroup(
        key: 'error_test',
        items: [
          BoolSetting(key: 'testSetting', defaultValue: true),
        ],
        store: store,
      );

      settings.register(errorGroup);
      await settings.init();

      // Test non-existent setting
      expect(
        () => settings.getBool('error_test.nonExistent'),
        throwsA(isA<SettingNotFoundException>()),
      );

      // Test non-configurable setting
      final nonConfigGroup = SettingsGroup(
        key: 'non_config_test',
        items: [
          BoolSetting(
            key: 'readonly',
            defaultValue: true,
            userConfigurable: false,
          ),
        ],
        store: store,
      );

      settings.register(nonConfigGroup);
      await settings.init();

      expect(
        () => settings.setBool('non_config_test.readonly', false),
        throwsA(isA<SettingNotConfigurableException>()),
      );
    });

    testWidgets('Platform-specific features work', (tester) async {
      // Test that the library works on the current platform
      debugPrint('Running on platform: ${defaultTargetPlatform.name}');

      // Create a comprehensive test group
      final platformGroup = SettingsGroup(
        key: 'platform_test',
        items: [
          BoolSetting(key: 'bool', defaultValue: false),
          IntSetting(key: 'int', defaultValue: 0),
          DoubleSetting(key: 'double', defaultValue: 0.0),
          StringSetting(key: 'string', defaultValue: ''),
          StringListSetting(key: 'stringList', defaultValue: []),
        ],
        store: store,
      );

      settings.register(platformGroup);
      await settings.init();

      // Test all supported types on current platform
      await settings.setBool('platform_test.bool', true);
      await settings.setInt('platform_test.int', 42);
      await settings.setDouble('platform_test.double', 3.14159);
      await settings.setString(
          'platform_test.string', 'Platform: ${defaultTargetPlatform.name}');
      await settings.setStringList('platform_test.stringList', [
        'item1',
        'item2',
        'platform:${defaultTargetPlatform.name}',
      ]);

      // Verify all types work
      expect(settings.getBool('platform_test.bool'), true);
      expect(settings.getInt('platform_test.int'), 42);
      expect(settings.getDouble('platform_test.double'), 3.14159);
      expect(settings.getString('platform_test.string'),
          'Platform: ${defaultTargetPlatform.name}');
      expect(settings.getStringList('platform_test.stringList'), [
        'item1',
        'item2',
        'platform:${defaultTargetPlatform.name}',
      ]);

      debugPrint('✓ All setting types work on ${defaultTargetPlatform.name}');
    });

    testWidgets('Performance test - rapid operations', (tester) async {
      final perfGroup = SettingsGroup(
        key: 'perf_test',
        items: [
          IntSetting(key: 'counter', defaultValue: 0),
          StringListSetting(key: 'items', defaultValue: []),
        ],
        store: store,
      );

      settings.register(perfGroup);
      await settings.init();

      final stopwatch = Stopwatch()..start();

      // Perform rapid operations
      for (int i = 0; i < 100; i++) {
        await settings.setInt('perf_test.counter', i);
        await settings.setStringList(
            'perf_test.items', List.generate(i % 10, (index) => 'item$index'));
      }

      stopwatch.stop();
      debugPrint(
          '100 rapid operations completed in ${stopwatch.elapsedMilliseconds}ms');

      // Verify final state
      expect(settings.getInt('perf_test.counter'), 99);
      expect(settings.getStringList('perf_test.items'),
          List.generate(9, (index) => 'item$index'));

      // Performance should be reasonable (less than 5 seconds for 100 operations)
      expect(stopwatch.elapsedMilliseconds, lessThan(5000));
    });
  });
}
