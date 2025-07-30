/// Enhanced type system for settings with both compile-time safety and runtime flexibility.
///
/// This module provides multiple access patterns:
/// 1. Strongly typed access: `settings.get<bool>('game.sound')`
/// 2. Dynamic access: `settings.getValue('game.sound')`
/// 3. Convenience methods: `settings.getBool('game.sound')`
/// 4. Generic access: `settings['game.sound']`
library;

import 'setting.dart';
import 'settings_group.dart';
import 'exceptions.dart';

/// Interface for type-safe setting access with performance optimizations.
///
/// This mixin provides the unified API for accessing settings with different
/// type safety guarantees and performance characteristics.
mixin TypedSettingAccess {
  /// Get the settings group by key for internal access.
  SettingsGroup getGroup(String key);

  /// Parse a storage key into group and setting components.
  ({String group, String setting}) parseStorageKey(String storageKey);

  /// **Type-Safe Access (Recommended for known types)**
  ///
  /// Provides compile-time type checking and best performance.
  /// Use when you know the exact type at compile time.
  ///
  /// Examples:
  /// ```dart
  /// bool soundEnabled = settings.get<bool>('game.soundEnabled');
  /// int difficulty = settings.get<int>('game.difficulty');
  /// String theme = settings.get<String>('ui.theme');
  /// ```
  T get<T>(String storageKey) {
    final parsed = parseStorageKey(storageKey);
    final group = getGroup(parsed.group);
    return group.get<T>(parsed.setting);
  }

  /// **Dynamic Access (Flexible but less performant)**
  ///
  /// Uses runtime type resolution. Convenient but slower than typed access.
  /// Use when types are not known at compile time or for generic code.
  ///
  /// Example:
  /// ```dart
  /// dynamic value = settings.getValue('some.key');
  /// ```
  dynamic getValue(String storageKey) {
    final parsed = parseStorageKey(storageKey);
    final group = getGroup(parsed.group);
    return group.getValue(parsed.setting);
  }

  /// **Convenience Methods (Best of both worlds)**
  ///
  /// Type-safe with optimized implementations for common types.
  /// These avoid generic overhead while maintaining type safety.
  ///
  /// Use these for the best balance of safety and performance.

  /// Get a boolean setting value.
  /// Optimized path that avoids generic type resolution.
  bool getBool(String storageKey) {
    final parsed = parseStorageKey(storageKey);
    final group = getGroup(parsed.group);
    final setting = group[parsed.setting];

    if (setting == null) {
      throw SettingNotFoundException('No setting found for key: $storageKey');
    }

    if (setting is! BoolSetting) {
      throw ArgumentError('Setting $storageKey is not a boolean setting');
    }

    return group.getValueUnvalidated<bool>(setting);
  }

  /// Get an integer setting value.
  /// Optimized path that avoids generic type resolution.
  int getInt(String storageKey) {
    final parsed = parseStorageKey(storageKey);
    final group = getGroup(parsed.group);
    final setting = group[parsed.setting];

    if (setting == null) {
      throw SettingNotFoundException('No setting found for key: $storageKey');
    }

    if (setting is! IntSetting) {
      throw ArgumentError('Setting $storageKey is not an integer setting');
    }

    return group.getValueUnvalidated<int>(setting);
  }

  /// Get a double setting value.
  /// Optimized path that avoids generic type resolution.
  double getDouble(String storageKey) {
    final parsed = parseStorageKey(storageKey);
    final group = getGroup(parsed.group);
    final setting = group[parsed.setting];

    if (setting == null) {
      throw SettingNotFoundException('No setting found for key: $storageKey');
    }

    if (setting is! DoubleSetting) {
      throw ArgumentError('Setting $storageKey is not a double setting');
    }

    return group.getValueUnvalidated<double>(setting);
  }

  /// Get a string setting value.
  /// Optimized path that avoids generic type resolution.
  String getString(String storageKey) {
    final parsed = parseStorageKey(storageKey);
    final group = getGroup(parsed.group);
    final setting = group[parsed.setting];

    if (setting == null) {
      throw SettingNotFoundException('No setting found for key: $storageKey');
    }

    if (setting is! StringSetting) {
      throw ArgumentError('Setting $storageKey is not a string setting');
    }

    return group.getValueUnvalidated<String>(setting);
  }

  /// Get a string list setting value.
  /// Optimized path that avoids generic type resolution.
  List<String> getStringList(String storageKey) {
    final parsed = parseStorageKey(storageKey);
    final group = getGroup(parsed.group);
    final setting = group[parsed.setting];

    if (setting == null) {
      throw SettingNotFoundException('No setting found for key: $storageKey');
    }

    if (setting is! StringListSetting) {
      throw ArgumentError('Setting $storageKey is not a string list setting');
    }

    return group.getValueUnvalidated<List<String>>(setting);
  }

  /// **Generic Access (For maximum flexibility)**
  ///
  /// Allows array-like access for generic programming.
  /// Returns dynamic type, so type checking is deferred to runtime.
  ///
  /// Example:
  /// ```dart
  /// dynamic value = settings['game.soundEnabled'];
  /// ```
  dynamic operator [](String storageKey) => getValue(storageKey);

  /// **Setting Modification Methods**
  ///
  /// These methods include validation and are optimized for each type.

  /// Set a boolean setting value with validation.
  Future<void> setBool(String storageKey, bool value) async {
    final parsed = parseStorageKey(storageKey);
    final group = getGroup(parsed.group);
    await group.setValue(parsed.setting, value);
  }

  /// Set an integer setting value with validation.
  Future<void> setInt(String storageKey, int value) async {
    final parsed = parseStorageKey(storageKey);
    final group = getGroup(parsed.group);
    await group.setValue(parsed.setting, value);
  }

  /// Set a double setting value with validation.
  Future<void> setDouble(String storageKey, double value) async {
    final parsed = parseStorageKey(storageKey);
    final group = getGroup(parsed.group);
    await group.setValue(parsed.setting, value);
  }

  /// Set a string setting value with validation.
  Future<void> setString(String storageKey, String value) async {
    final parsed = parseStorageKey(storageKey);
    final group = getGroup(parsed.group);
    await group.setValue(parsed.setting, value);
  }

  /// Set s string list setting value with validation.
  Future<void> setStringList(String storageKey, List<String> value) async {
    final parsed = parseStorageKey(storageKey);
    final group = getGroup(parsed.group);
    await group.setValue(parsed.setting, value);
  }

  /// Set a typed setting value with validation.
  Future<void> set<T>(String storageKey, T value) async {
    final parsed = parseStorageKey(storageKey);
    final group = getGroup(parsed.group);
    await group.setValue(parsed.setting, value);
  }

  /// Set a dynamic setting value with validation.
  Future<void> setValue(String storageKey, dynamic value) async {
    final parsed = parseStorageKey(storageKey);
    final group = getGroup(parsed.group);
    await group.setValue(parsed.setting, value);
  }
}

/// Extension to provide performance hints and type information.
extension SettingTypeInfo on TypedSettingAccess {
  /// Get the type information for a setting without reading its value.
  /// Useful for generic code that needs to handle different types differently.
  SettingType getSettingType(String storageKey) {
    final parsed = parseStorageKey(storageKey);
    final group = getGroup(parsed.group);
    final setting = group[parsed.setting];

    if (setting == null) {
      throw SettingNotFoundException('No setting found for key: $storageKey');
    }

    return setting.type;
  }

  /// Check if a setting exists without reading its value.
  bool hasSetting(String storageKey) {
    try {
      final parsed = parseStorageKey(storageKey);
      final group = getGroup(parsed.group);
      return group[parsed.setting] != null;
    } catch (e) {
      return false;
    }
  }

  /// Get validation description for a setting.
  /// Returns null if no validator or validator has no description.
  String? getValidationDescription(String storageKey) {
    try {
      final parsed = parseStorageKey(storageKey);
      final group = getGroup(parsed.group);
      final setting = group[parsed.setting];
      return setting?.validationDescription;
    } catch (e) {
      return null;
    }
  }
}
