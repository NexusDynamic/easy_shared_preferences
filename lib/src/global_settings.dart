/// Global settings manager for convenient app-wide access to settings.
///
/// This provides a way to configure settings once in main() and access them
/// anywhere in the app without passing instances around, while still maintaining
/// proper dependency injection principles.
///
/// Example usage:
/// ```dart
/// void main() async {
///   // Set up global settings early in main()
///   await GlobalSettings.initialize([
///     SettingsGroup(key: 'app', items: [...]),
///     SettingsGroup(key: 'user', items: [...]),
///   ]);
///
///   runApp(MyApp());
/// }
///
/// // Later, anywhere in your app:
/// class MyWidget extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     final isDarkMode = GlobalSettings.getBool('app.darkMode');
///     return Container(/* ... */);
///   }
/// }
/// ```
library;

import 'dart:async';
import 'settings_manager.dart';
import 'settings_group.dart';
import 'settings_store.dart';
import 'setting.dart';
import 'logger.dart';

/// Configuration for a settings group used in GlobalSettings initialization.
///
/// This class holds the key and items for a settings group without requiring
/// a store instance, which will be provided by GlobalSettings.
class GroupConfig {
  /// The unique key for the settings group.
  final String key;

  /// The list of settings to include in the group.
  final List<Setting> items;

  /// Creates a new group configuration.
  ///
  /// Parameters:
  /// - [key]: The unique key for the settings group
  /// - [items]: The list of settings to include in the group
  const GroupConfig({
    required this.key,
    required this.items,
  });
}

/// Helper class that eliminates duplication by providing a single method
/// to check initialization and delegate to the underlying instance.
class _GlobalSettingsDelegate {
  static Settings? _instance;

  /// Get the instance and ensure it's initialized
  static Settings get instance {
    if (_instance == null) {
      throw StateError(
          'GlobalSettings has not been initialized. Call GlobalSettings.initialize() first.');
    }
    return _instance!;
  }

  /// Set the instance (internal use only)
  static void _setInstance(Settings? instance) {
    _instance = instance;
  }
}

/// Global settings manager that provides convenient app-wide access to settings.
///
/// This class maintains a global instance while preserving dependency injection
/// principles. It allows you to configure settings once and access them anywhere.
class GlobalSettings {
  static final _logger = EspLogger.forComponent('GlobalSettings');

  /// Private constructor to prevent direct instantiation
  GlobalSettings._();

  /// Initialize the global settings with the provided group configurations.
  ///
  /// This should be called once, typically in your main() function, before
  /// running your app. All settings groups should be provided at initialization.
  ///
  /// Parameters:
  /// - [groupConfigs]: List of group configurations (key and items)
  /// - [store]: Optional custom settings store (defaults to new SettingsStore)
  /// - [enableLogging]: Whether to enable logging (defaults to false)
  ///
  /// Throws [StateError] if already initialized.
  ///
  /// Example:
  /// ```dart
  /// await GlobalSettings.initialize([
  ///   GroupConfig(key: 'app', items: [
  ///     BoolSetting(key: 'darkMode', defaultValue: false),
  ///   ]),
  /// ]);
  /// ```
  static Future<void> initialize(
    List<GroupConfig> groupConfigs, {
    SettingsStore? store,
    bool enableLogging = false,
  }) async {
    if (_GlobalSettingsDelegate._instance != null) {
      throw StateError(
          'GlobalSettings is already initialized. Call dispose() first if you need to reinitialize.');
    }

    if (enableLogging) {
      EspLogger.enableLogging();
    }

    _logger
        .info('Initializing GlobalSettings with ${groupConfigs.length} groups');

    Settings? tempInstance;
    try {
      final settingsStore = store ?? SettingsStore();
      tempInstance = Settings(store: settingsStore);

      // Create and register all groups
      for (final config in groupConfigs) {
        final group = SettingsGroup(
          key: config.key,
          items: config.items,
          store: settingsStore,
        );
        tempInstance.register(group);
      }

      // Initialize the settings system
      await tempInstance.init();

      // Only set the instance after successful initialization
      _GlobalSettingsDelegate._setInstance(tempInstance);

      _logger.info('GlobalSettings initialized successfully');
    } catch (e) {
      _logger.severe('Failed to initialize GlobalSettings', e);

      // Clean up partial initialization
      if (tempInstance != null) {
        try {
          tempInstance.dispose();
        } catch (disposeError) {
          _logger.warning(
              'Error disposing partial GlobalSettings initialization',
              disposeError);
        }
      }

      rethrow;
    }
  }

  /// Add a new settings group after initialization.
  ///
  /// This allows you to register additional settings groups even after
  /// the initial setup. The group will be created with the same store
  /// as the global settings and automatically initialized.
  ///
  /// Parameters:
  /// - [key]: The unique key for the settings group
  /// - [items]: List of settings to include in the group
  ///
  /// Throws [StateError] if not initialized.
  /// Throws [ArgumentError] if a group with the same key already exists.
  ///
  /// Example:
  /// ```dart
  /// await GlobalSettings.addGroup('newFeature', [
  ///   BoolSetting(key: 'enabled', defaultValue: false),
  /// ]);
  /// ```
  static Future<void> addGroup(String key, List<Setting> items) async {
    final instance = _GlobalSettingsDelegate.instance;

    _logger.info('Adding new settings group: $key');

    // Create the group with the same store as the global settings
    final group = SettingsGroup(
      key: key,
      items: items,
      store: instance.store,
    );

    await instance.registerAndInit(group);
    _logger.info('Settings group $key added successfully');
  }

  /// Check if GlobalSettings has been initialized.
  static bool get isInitialized => _GlobalSettingsDelegate._instance != null;

  /// Get the underlying Settings instance.
  ///
  /// This provides access to the full Settings API for advanced use cases.
  /// Most users should use the convenience methods instead.
  ///
  /// Throws [StateError] if not initialized.
  static Settings get instance => _GlobalSettingsDelegate.instance;

  /// Dispose the global settings and cleanup all resources.
  ///
  /// This should be called when your app is shutting down or when you
  /// need to reinitialize the settings system.
  static void dispose() {
    if (_GlobalSettingsDelegate._instance != null) {
      _logger.info('Disposing GlobalSettings');
      _GlobalSettingsDelegate._instance!.dispose();
      _GlobalSettingsDelegate._setInstance(null);
      _logger.info('GlobalSettings disposed');
    }
  }

  // All static convenience methods use the delegate pattern for clean, DRY code

  static bool getBool(String storageKey) =>
      _GlobalSettingsDelegate.instance.getBool(storageKey);
  static Future<void> setBool(String storageKey, bool value) =>
      _GlobalSettingsDelegate.instance.setBool(storageKey, value);
  static int getInt(String storageKey) =>
      _GlobalSettingsDelegate.instance.getInt(storageKey);
  static Future<void> setInt(String storageKey, int value) =>
      _GlobalSettingsDelegate.instance.setInt(storageKey, value);
  static double getDouble(String storageKey) =>
      _GlobalSettingsDelegate.instance.getDouble(storageKey);
  static Future<void> setDouble(String storageKey, double value) =>
      _GlobalSettingsDelegate.instance.setDouble(storageKey, value);
  static String getString(String storageKey) =>
      _GlobalSettingsDelegate.instance.getString(storageKey);
  static Future<void> setString(String storageKey, String value) =>
      _GlobalSettingsDelegate.instance.setString(storageKey, value);
  static List<String> getStringList(String storageKey) =>
      _GlobalSettingsDelegate.instance.getStringList(storageKey);
  static Future<void> setStringList(String storageKey, List<String> value) =>
      _GlobalSettingsDelegate.instance.setStringList(storageKey, value);
  static T get<T>(String storageKey) =>
      _GlobalSettingsDelegate.instance.get<T>(storageKey);
  static Future<void> set(String storageKey, dynamic value) =>
      _GlobalSettingsDelegate.instance.setValue(storageKey, value);
  static Future<void> setMultiple(Map<String, dynamic> values) =>
      _GlobalSettingsDelegate.instance.setMultiple(values);
  static Future<void> resetSetting(String storageKey) =>
      _GlobalSettingsDelegate.instance.resetSetting(storageKey);
  static Future<void> resetGroup(String groupKey) =>
      _GlobalSettingsDelegate.instance.resetGroup(groupKey);
  static Future<void> resetAll() => _GlobalSettingsDelegate.instance.resetAll();
  static void addChangeCallback(
          void Function(String key, dynamic oldValue, dynamic newValue)
              callback) =>
      _GlobalSettingsDelegate.instance.addChangeCallback(callback);
  static bool removeChangeCallback(
          void Function(String key, dynamic oldValue, dynamic newValue)
              callback) =>
      _GlobalSettingsDelegate.instance.removeChangeCallback(callback);
  static SettingsGroup getGroup(String groupKey) =>
      _GlobalSettingsDelegate.instance.getGroup(groupKey);
  static bool hasGroup(String groupKey) =>
      _GlobalSettingsDelegate.instance.hasGroup(groupKey);
  static List<String> get groupKeys =>
      _GlobalSettingsDelegate.instance.groupKeys;
}
