import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_shared_preferences/easy_shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('GlobalSettings Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      // Ensure GlobalSettings is disposed before each test
      GlobalSettings.dispose();
    });

    tearDown(() {
      GlobalSettings.dispose();
    });

    group('Initialization', () {
      test('should initialize with settings groups', () async {
        final groups = [
          GroupConfig(
            key: 'test',
            items: [BoolSetting(key: 'flag', defaultValue: false)],
          ),
        ];

        await GlobalSettings.initialize(groups);

        expect(GlobalSettings.isInitialized, isTrue);
        expect(GlobalSettings.getBool('test.flag'), isFalse);
      });

      test('should throw if already initialized', () async {
        final groups = [
          GroupConfig(
            key: 'test',
            items: [BoolSetting(key: 'flag', defaultValue: false)],
          ),
        ];

        await GlobalSettings.initialize(groups);

        expect(
          () => GlobalSettings.initialize(groups),
          throwsStateError,
        );
      });

      test('should initialize with logging enabled', () async {
        final groups = [
          GroupConfig(
            key: 'test',
            items: [BoolSetting(key: 'flag', defaultValue: false)],
          ),
        ];

        // Should not throw
        await GlobalSettings.initialize(groups, enableLogging: true);

        expect(GlobalSettings.isInitialized, isTrue);
      });
    });

    group('Settings Access', () {
      setUp(() async {
        final groups = [
          GroupConfig(
            key: 'app',
            items: [
              BoolSetting(key: 'darkMode', defaultValue: false),
              IntSetting(key: 'fontSize', defaultValue: 14),
              DoubleSetting(key: 'volume', defaultValue: 0.5),
              StringSetting(key: 'theme', defaultValue: 'light'),
            ],
          ),
        ];

        await GlobalSettings.initialize(groups);
      });

      test('should get and set boolean values', () async {
        expect(GlobalSettings.getBool('app.darkMode'), isFalse);

        await GlobalSettings.setBool('app.darkMode', true);
        expect(GlobalSettings.getBool('app.darkMode'), isTrue);
      });

      test('should get and set integer values', () async {
        expect(GlobalSettings.getInt('app.fontSize'), equals(14));

        await GlobalSettings.setInt('app.fontSize', 16);
        expect(GlobalSettings.getInt('app.fontSize'), equals(16));
      });

      test('should get and set double values', () async {
        expect(GlobalSettings.getDouble('app.volume'), equals(0.5));

        await GlobalSettings.setDouble('app.volume', 0.8);
        expect(GlobalSettings.getDouble('app.volume'), equals(0.8));
      });

      test('should get and set string values', () async {
        expect(GlobalSettings.getString('app.theme'), equals('light'));

        await GlobalSettings.setString('app.theme', 'dark');
        expect(GlobalSettings.getString('app.theme'), equals('dark'));
      });

      test('should get and set dynamic values', () async {
        expect(GlobalSettings.get('app.darkMode'), isFalse);

        await GlobalSettings.set('app.darkMode', true);
        expect(GlobalSettings.get('app.darkMode'), isTrue);
      });

      test('should throw if not initialized', () {
        GlobalSettings.dispose();

        expect(() => GlobalSettings.getBool('app.darkMode'), throwsStateError);
        expect(() => GlobalSettings.setBool('app.darkMode', true), throwsA(isA<StateError>()));
      });
    });

    group('Reset Operations', () {
      setUp(() async {
        final groups = [
          GroupConfig(
            key: 'app',
            items: [
              BoolSetting(key: 'darkMode', defaultValue: false),
              IntSetting(key: 'fontSize', defaultValue: 14),
            ],
          ),
          GroupConfig(
            key: 'game',
            items: [
              BoolSetting(key: 'soundEnabled', defaultValue: true),
            ],
          ),
        ];

        await GlobalSettings.initialize(groups);
      });

      test('should reset individual settings', () async {
        await GlobalSettings.setBool('app.darkMode', true);
        expect(GlobalSettings.getBool('app.darkMode'), isTrue);

        await GlobalSettings.resetSetting('app.darkMode');
        expect(GlobalSettings.getBool('app.darkMode'), isFalse);
      });

      test('should reset entire groups', () async {
        await GlobalSettings.setBool('app.darkMode', true);
        await GlobalSettings.setInt('app.fontSize', 18);

        await GlobalSettings.resetGroup('app');

        expect(GlobalSettings.getBool('app.darkMode'), isFalse);
        expect(GlobalSettings.getInt('app.fontSize'), equals(14));
      });

      test('should reset all settings', () async {
        await GlobalSettings.setBool('app.darkMode', true);
        await GlobalSettings.setBool('game.soundEnabled', false);

        await GlobalSettings.resetAll();

        expect(GlobalSettings.getBool('app.darkMode'), isFalse);
        expect(GlobalSettings.getBool('game.soundEnabled'), isTrue);
      });
    });

    group('Change Callbacks', () {
      setUp(() async {
        final groups = [
          GroupConfig(
            key: 'test',
            items: [BoolSetting(key: 'flag', defaultValue: false)],
          ),
        ];

        await GlobalSettings.initialize(groups);
      });

      test('should call change callbacks', () async {
        final changeEvents = <Map<String, dynamic>>[];
        
        GlobalSettings.addChangeCallback((key, oldValue, newValue) {
          changeEvents.add({
            'key': key,
            'oldValue': oldValue,
            'newValue': newValue,
          });
        });

        await GlobalSettings.setBool('test.flag', true);

        expect(changeEvents.length, equals(1));
        expect(changeEvents[0]['key'], equals('test.flag'));
        expect(changeEvents[0]['oldValue'], equals(false));
        expect(changeEvents[0]['newValue'], equals(true));
      });

      test('should remove change callbacks', () async {
        final changeEvents = <Map<String, dynamic>>[];
        
        void callback(String key, dynamic oldValue, dynamic newValue) {
          changeEvents.add({
            'key': key,
            'oldValue': oldValue,
            'newValue': newValue,
          });
        }

        GlobalSettings.addChangeCallback(callback);
        await GlobalSettings.setBool('test.flag', true);
        expect(changeEvents.length, equals(1));

        final removed = GlobalSettings.removeChangeCallback(callback);
        expect(removed, isTrue);

        await GlobalSettings.setBool('test.flag', false);
        expect(changeEvents.length, equals(1)); // No new events
      });
    });

    group('Group Management', () {
      setUp(() async {
        final groups = [
          GroupConfig(
            key: 'initial',
            items: [BoolSetting(key: 'flag', defaultValue: false)],
          ),
        ];

        await GlobalSettings.initialize(groups);
      });

      test('should add new groups after initialization', () async {
        expect(GlobalSettings.hasGroup('newGroup'), isFalse);

        await GlobalSettings.addGroup('newGroup', [
          IntSetting(key: 'value', defaultValue: 42),
        ]);

        expect(GlobalSettings.hasGroup('newGroup'), isTrue);
        expect(GlobalSettings.getInt('newGroup.value'), equals(42));
      });

      test('should throw when adding duplicate group key', () async {
        await GlobalSettings.addGroup('duplicate', [
          BoolSetting(key: 'flag', defaultValue: false),
        ]);

        expect(
          () => GlobalSettings.addGroup('duplicate', [
            BoolSetting(key: 'other', defaultValue: true),
          ]),
          throwsArgumentError,
        );
      });

      test('should get group keys', () {
        final keys = GlobalSettings.groupKeys.toList();
        expect(keys, contains('initial'));
      });

      test('should get group by key', () {
        final group = GlobalSettings.getGroup('initial');
        expect(group.key, equals('initial'));
      });

      test('should check if group exists', () {
        expect(GlobalSettings.hasGroup('initial'), isTrue);
        expect(GlobalSettings.hasGroup('nonexistent'), isFalse);
      });
    });

    group('Instance Access', () {
      test('should provide access to underlying Settings instance', () async {
        final groups = [
          GroupConfig(
            key: 'test',
            items: [BoolSetting(key: 'flag', defaultValue: false)],
          ),
        ];

        await GlobalSettings.initialize(groups);

        final instance = GlobalSettings.instance;
        expect(instance, isA<Settings>());
        expect(instance.getBool('test.flag'), isFalse);
      });

      test('should throw if accessing instance when not initialized', () {
        GlobalSettings.dispose();
        expect(() => GlobalSettings.instance, throwsStateError);
      });
    });

    group('Disposal', () {
      test('should dispose properly', () async {
        final groups = [
          GroupConfig(
            key: 'test',
            items: [BoolSetting(key: 'flag', defaultValue: false)],
          ),
        ];

        await GlobalSettings.initialize(groups);
        expect(GlobalSettings.isInitialized, isTrue);

        GlobalSettings.dispose();
        expect(GlobalSettings.isInitialized, isFalse);
      });

      test('should allow reinitialization after disposal', () async {
        final groups = [
          GroupConfig(
            key: 'test',
            items: [BoolSetting(key: 'flag', defaultValue: false)],
          ),
        ];

        await GlobalSettings.initialize(groups);
        GlobalSettings.dispose();

        // Should not throw
        await GlobalSettings.initialize(groups);
        expect(GlobalSettings.isInitialized, isTrue);
      });
    });
  });
}