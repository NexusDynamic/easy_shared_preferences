# Easy Shared Preferences

[![Pub Publisher](https://img.shields.io/pub/publisher/easy_shared_preferences?style=flat-square)](https://pub.dev/publishers/zeyus.com/packages)
[![Pub Version](https://img.shields.io/pub/v/easy_shared_preferences)](https://pub.dev/packages/easy_shared_preferences)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![tests](https://github.com/NexusDynamic/easy_shared_preferences/actions/workflows/tests.yaml/badge.svg)](https://github.com/NexusDynamic/easy_shared_preferences/actions/workflows/tests.yaml)


A game or app settings oriented wrapper API for [shared_preferences](https://pub.dev/packages/shared_preferences) (with cache), type-safe settings framework for Flutter applications with automatic validation, change notifications, and modular design.

**Note**: The same warnings and caveats apply as with the original `shared_preferences` package, such as not using it for sensitive data or large datasets.

## Features

- **Optional Type Safety**. Compile-time type checking for all setting values  
- **Instance or Global/Static Usage**. Use settings as a singleton or create an instance (e.g. in isolates)
- **Validation**. Optional validators ensure data integrity  
- **Change Notifications**. Listen for changes in settings values  
- **Hierarchical Organization**. Group related settings together (e.g. app settings, UI settings) 
- **Automatic Persistence** Settings are automatically saved to device storage (obviously with the same caveats as [shared_preferences](https://pub.dev/packages/shared_preferences))

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  easy_shared_preferences: <latest_version>
```

Then run:

```bash
flutter pub get
```

## Quick Start

### 1. Create Store and Manager

#### 1.1. Global/Static Usage
```dart
import 'package:easy_shared_preferences/easy_shared_preferences.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize global settings early in main()
  await GlobalSettings.initialize([
    // Game settings group
    GroupConfig(
      key: 'game',
      items: [
        BoolSetting(key: 'soundEnabled', defaultValue: true),
        DoubleSetting(
          key: 'volume',
          defaultValue: 0.8,
          validator: (value) => value >= 0.0 && value <= 1.0,
        ),
        IntSetting(
          key: 'difficulty',
          defaultValue: 1,
          validator: (value) => value >= 1 && value <= 3,
        ),
      ],
    ),
    // UI settings group
    GroupConfig(
      key: 'ui',
      items: [
        StringSetting(
          key: 'theme',
          defaultValue: 'light',
          validator: (value) => ['light', 'dark', 'auto'].contains(value),
        ),
        BoolSetting(key: 'showAnimations', defaultValue: true),
        IntSetting(
          key: 'fontSize',
          defaultValue: 14,
          validator: (value) => value >= 12 && value <= 24,
        ),
      ],
    ),
  ], enableLogging: true);
  // Now you can use GlobalSettings anywhere in your app
  // For example, to get a setting value:
  bool soundEnabled = GlobalSettings.getBool('game.soundEnabled');
  runApp(MyApp());
}
```

#### 1.2. Instance Usage
```dart
import 'package:easy_shared_preferences/easy_shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Create the settings store and manager
  final store = SettingsStore();
  final settings = Settings(store: store);
  
  // Define your settings groups
  final gameSettings = SettingsGroup(
    key: 'game',
    items: [
      BoolSetting(key: 'soundEnabled', defaultValue: true),
      DoubleSetting(
        key: 'volume', 
        defaultValue: 0.8,
        validator: CommonValidators.percentage.validate,
      ),
      IntSetting(key: 'difficulty', defaultValue: 1),
    ],
    store: store,
  );

  final uiSettings = SettingsGroup(
    key: 'ui',
    items: [
      StringSetting(
        key: 'theme', 
        defaultValue: 'light',
        validator: EnumValidator<String>(['light', 'dark', 'auto']).validate,
      ),
      BoolSetting(key: 'notifications', defaultValue: true),
    ],
    store: store,
  );
  
  // Register and initialize
  settings.register(gameSettings);
  settings.register(uiSettings);
  await settings.init();
  
  runApp(MyApp());
}
```

### 2. Use Your Settings

```dart
// Read settings
bool soundEnabled = settings.getBool('game.soundEnabled');
double volume = settings.getDouble('game.volume');
String theme = settings.getString('ui.theme');

// Write settings
await settings.setBool('game.soundEnabled', false);
await settings.setDouble('game.volume', 0.5);
await settings.setString('ui.theme', 'dark');

// Batch operations
await settings.setMultiple({
  'game.soundEnabled': false,
  'game.volume': 0.3,
  'ui.theme': 'dark',
});

// Change callbacks
settings.addChangeCallback((key, oldValue, newValue) {
  print('Setting $key changed from $oldValue to $newValue');
});

// Don't forget to dispose when done!
settings.dispose();
```

## Advanced Usage

### Validation

Settings support optional validation using built-in validator classes:

```dart
final volumeSetting = DoubleSetting(
  key: 'volume',
  defaultValue: 0.5,
  validator: CommonValidators.percentage.validate, // 0.0 to 1.0
);

final themeSetting = StringSetting(
  key: 'theme',
  defaultValue: 'light',
  validator: EnumValidator<String>(['light', 'dark', 'auto']).validate,
);

final emailSetting = StringSetting(
  key: 'email',
  defaultValue: '',
  validator: CommonValidators.email.validate,
);

final passwordSetting = StringSetting(
  key: 'password',
  defaultValue: '',
  validator: CompositeValidator<String>.and([
    LengthValidator(minLength: 8, maxLength: 50),
    RegexValidator(r'\d', customDescription: 'Must contain at least one digit'),
  ]).validate,
);
```

### Change Notifications

Listen to setting changes with streams:

```dart
gameSettings['soundEnabled']?.stream.listen((enabled) {
  print('Sound ${enabled ? 'enabled' : 'disabled'}');
  updateAudioEngine(enabled);
});

uiSettings['theme']?.stream.listen((theme) {
  print('Theme changed to: $theme');
  updateAppTheme(theme);
});
```

### Non-Configurable Settings

Some settings can be marked as read-only:

```dart
final systemSetting = BoolSetting(
  key: 'debugMode',
  defaultValue: false,
  userConfigurable: false, // Cannot be modified by user code
);
```

### Reset Operations

```dart
// Reset a single setting
await settings.resetSetting('game.volume');

// Reset an entire group
await settings.resetGroup('ui');

// Reset all settings
await settings.resetAll();
```

## Testing

The framework includes built-in testing support:

```dart
void main() {
  group('Settings Tests', () {
    late Settings settings;
    
    setUp(() {
      settings = Settings();
      settings.register(SettingsGroup.forTesting(
        key: 'test',
        items: [
          BoolSetting(key: 'testFlag', defaultValue: false),
        ],
      ));
    });
    
    test('should set and get values correctly', () async {
      await settings.init();
      
      await settings.setBool('test.testFlag', true);
      expect(settings.getBool('test.testFlag'), true);
    });
  });
}
```

## API Reference

### Settings Types

- `BoolSetting`: Boolean values (true/false)
- `IntSetting`: Integer numbers
- `DoubleSetting`: Floating-point numbers
- `StringSetting`: Text values
- `StringListSetting`: List of strings

### Main API

- `Settings()`: Main settings manager
- `SettingsGroup()`: Container for related settings
- `settings.register()`: Register a settings group
- `settings.init()`: Initialize the settings system
- `settings.getBool()`, `getInt()`, `getDouble()`, `getString()`, `getStringList()`: Type-safe getters
- `settings.setBool()`, `setInt()`, `setDouble()`, `setString()`, `setStringList()`: Type-safe setters
- `settings.setMultiple()`: Batch operations
- `settings.resetSetting()`, `resetGroup()`, `resetAll()`: Reset operations

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
