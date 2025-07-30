// ignore_for_file: avoid_print

import 'package:easy_shared_preferences/easy_shared_preferences.dart';
import 'package:flutter/material.dart';

/// Example demonstrating the different type access patterns.
///
/// This shows the performance and safety tradeoffs of different approaches.
void main() async {
  // Initialize settings
  WidgetsFlutterBinding.ensureInitialized();
  final store = SettingsStore();
  final settings = Settings(store: store);

  final gameSettings = SettingsGroup(
    key: 'game',
    items: [
      BoolSetting(key: 'soundEnabled', defaultValue: true),
      DoubleSetting(
        key: 'volume',
        defaultValue: 0.8,
        validator: CommonValidators.percentage,
      ),
      IntSetting(
        key: 'difficulty',
        defaultValue: 1,
        validator: RangeValidator<int>(min: 1, max: 3),
      ),
      StringSetting(
        key: 'playerName',
        defaultValue: 'Player',
        validator: LengthValidator(minLength: 1, maxLength: 20),
      ),
    ],
    store: store,
  );

  settings.register(gameSettings);
  await settings.init();

  print('=== Different Type Access Patterns ===\n');

  // 1. **Convenience Methods (Recommended)**
  // Best performance + type safety for common types
  print('1. Convenience Methods (Fast + Type Safe):');
  final soundEnabled = settings.getBool('game.soundEnabled');
  final volume = settings.getDouble('game.volume');
  final difficulty = settings.getInt('game.difficulty');
  final playerName = settings.getString('game.playerName');

  print('  Sound: $soundEnabled (${soundEnabled.runtimeType})');
  print('  Volume: $volume (${volume.runtimeType})');
  print('  Difficulty: $difficulty (${difficulty.runtimeType})');
  print('  Player: $playerName (${playerName.runtimeType})');

  // 2. **Generic Typed Access**
  // Type-safe but slightly more overhead due to generics
  print('\n2. Generic Typed Access (Type Safe):');
  final soundEnabled2 = settings.get<bool>('game.soundEnabled');
  final volume2 = settings.get<double>('game.volume');
  final difficulty2 = settings.get<int>('game.difficulty');
  final playerName2 = settings.get<String>('game.playerName');

  print('  Sound: $soundEnabled2 (${soundEnabled2.runtimeType})');
  print('  Volume: $volume2 (${volume2.runtimeType})');
  print('  Difficulty: $difficulty2 (${difficulty2.runtimeType})');
  print('  Player: $playerName2 (${playerName2.runtimeType})');

  // 3. **Dynamic Access**
  // Most flexible but slowest
  print('\n3. Dynamic Access (Flexible but Slower):');
  final soundEnabled3 = settings.getValue('game.soundEnabled');
  final volume3 = settings.getValue('game.volume');
  final difficulty3 = settings.getValue('game.difficulty');
  final playerName3 = settings.getValue('game.playerName');

  print('  Sound: $soundEnabled3 (${soundEnabled3.runtimeType})');
  print('  Volume: $volume3 (${volume3.runtimeType})');
  print('  Difficulty: $difficulty3 (${difficulty3.runtimeType})');
  print('  Player: $playerName3 (${playerName3.runtimeType})');

  // 4. **Array-like Access**
  // Convenient and easy to use
  print('\n4. Array-like Access (Generic Programming):');
  final soundEnabled4 = settings['game.soundEnabled'];
  final volume4 = settings['game.volume'];
  final difficulty4 = settings['game.difficulty'];
  final playerName4 = settings['game.playerName'];

  print('  Sound: $soundEnabled4 (${soundEnabled4.runtimeType})');
  print('  Volume: $volume4 (${volume4.runtimeType})');
  print('  Difficulty: $difficulty4 (${difficulty4.runtimeType})');
  print('  Player: $playerName4 (${playerName4.runtimeType})');

  print('\n=== Setting Values with Validation ===\n');

  // All setting methods include validation
  try {
    await settings.setDouble('game.volume', 0.5);
    print('✅ Valid volume set: ${settings.getDouble('game.volume')}');

    await settings.setDouble('game.volume', 1.5); // Should fail validation
  } catch (e) {
    print('❌ Invalid volume rejected: $e');
  }

  try {
    await settings.setInt('game.difficulty', 2);
    print('✅ Valid difficulty set: ${settings.getInt('game.difficulty')}');

    await settings.setInt('game.difficulty', 5); // Should fail validation
  } catch (e) {
    print('❌ Invalid difficulty rejected: $e');
  }

  print('\n=== Type Information and Validation ===\n');

  // Get type information without reading values
  print('Setting types:');
  print('  game.soundEnabled: ${settings.getSettingType('game.soundEnabled')}');
  print('  game.volume: ${settings.getSettingType('game.volume')}');
  print('  game.difficulty: ${settings.getSettingType('game.difficulty')}');
  print('  game.playerName: ${settings.getSettingType('game.playerName')}');

  // Get validation descriptions
  print('\nValidation rules:');
  print('  Volume: ${settings.getValidationDescription('game.volume')}');
  print(
      '  Difficulty: ${settings.getValidationDescription('game.difficulty')}');
  print(
      '  Player Name: ${settings.getValidationDescription('game.playerName')}');

  // Check if settings exist
  print('\nSetting existence:');
  print(
      '  game.soundEnabled exists: ${settings.hasSetting('game.soundEnabled')}');
  print(
      '  game.nonexistent exists: ${settings.hasSetting('game.nonexistent')}');

  settings.dispose();
}

/// Example of how to choose the right access pattern for different use cases.
void accessPatternGuidelines() {
  print('''
=== Access Pattern Guidelines ===

**Use Convenience Methods When:**
   - You know the exact type at compile time
   - Performance is critical (hot paths, frequent access)
   - You want the best type safety with minimal overhead
   
   Example: settings.getBool('game.soundEnabled')

**Use Generic Typed Access When:**
   - Writing generic code that works with multiple types
   - You want type safety but need more flexibility
   - Performance is important but not critical
   
   Example: T getValue<T>(String key) => settings.get<T>(key);

**Use Dynamic Access When:**
   - Types are determined at runtime
   - Building configuration systems or admin panels
   - Flexibility is more important than performance
   
   Example: settings.getValue(userProvidedKey)

**Use Array-like Access When:**
   - Implementing generic data binding
   - Building UI that works with any setting type
   - Prototyping or quick scripting
   
   Example: settings[configKey]

**Performance Ranking (fastest to slowest):**
   1. Convenience methods (getBool, getInt, etc.)
   2. Generic typed access (get<T>)
   3. Dynamic access (getValue)
   4. Array-like access (settings[key])
''');
}
