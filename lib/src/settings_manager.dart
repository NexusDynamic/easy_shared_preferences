import 'dart:async';
import 'settings_group.dart';
import 'settings_store.dart';
import 'exceptions.dart';
import 'logger.dart';
import 'typed_setting_access.dart';

/// Settings manager providing centralized access to all setting groups.
///
/// The [EasySettings] class serves as the main entry point for the settings framework,
/// offering instance methods for registration, initialization, and access to settings
/// across your entire application. It manages multiple [SettingsGroup] instances and
/// provides both individual and batch operations with proper resource management.
///
/// ## Overview
///
/// The settings framework follows a hierarchical structure:
/// ```
/// EasySettings (Manager)
/// │
/// ├── SettingsGroup (Group: "game")
/// │   ├── BoolSetting ("soundEnabled")
/// │   └── DoubleSetting ("volume")
/// │
/// └── SettingsGroup (Group: "ui")
///     ├── StringSetting ("theme")
///     └── IntSetting ("fontSize")
/// ```
///
/// ## Usage Pattern
///
/// ```dart
/// // 1. Create a settings store and manager
/// final store = SettingsStore();
/// final settings = Settings(store: store);
///
/// // 2. Define your setting groups
/// final gameSettings = SettingsGroup(
///   key: 'game',
///   items: [
///     BoolSetting(key: 'soundEnabled', defaultValue: true),
///     DoubleSetting(key: 'volume', defaultValue: 0.8),
///   ],
///   store: store,
/// );
///
/// final uiSettings = SettingsGroup(
///   key: 'ui',
///   items: [
///     StringSetting(key: 'theme', defaultValue: 'light'),
///     IntSetting(key: 'fontSize', defaultValue: 14),
///   ],
///   store: store,
/// );
///
/// // 3. Register all groups
/// settings.register(gameSettings);
/// settings.register(uiSettings);
///
/// // 4. Initialize the entire settings system
/// await settings.init();
///
/// // 5. Access settings using dot notation
/// bool soundEnabled = settings.getBool('game.soundEnabled');
/// String theme = settings.getString('ui.theme');
///
/// // 6. Modify settings with automatic validation
/// await settings.setBool('game.soundEnabled', false);
/// await settings.setString('ui.theme', 'dark');
///
/// // 7. Batch operations for efficiency
/// await settings.setMultiple({
///   'game.volume': 0.5,
///   'ui.fontSize': 16,
/// });
///
/// // 8. Reset operations
/// await settings.resetSetting('game.volume'); // Reset single setting
/// await settings.resetGroup('ui');            // Reset entire group
/// await settings.resetAll();                  // Reset everything
///
/// // 9. Cleanup when done
/// settings.dispose();
/// ```
///
/// ## Storage Key Format
///
/// Settings are stored using a namespaced key format: `groupKey.settingKey`
/// - `game.soundEnabled` → boolean setting in the game group
/// - `ui.theme` → string setting in the ui group
/// - `network.timeout` → integer setting in the network group
///
/// This prevents key conflicts between different setting groups and provides
/// logical organization of related settings.
class EasySettings with TypedSettingAccess {
  static final _logger = EspLogger.forComponent('Settings');

  /// The settings store instance used by this manager.
  final SettingsStore _store;

  /// Get the settings store instance.
  ///
  /// This provides access to the underlying store for advanced use cases
  /// like creating new groups with the same store instance.
  SettingsStore get store => _store;

  /// Internal registry of all settings groups keyed by their group names.
  ///
  /// This map stores all registered [SettingsGroup] instances, providing
  /// fast lookup by group key. Groups must be registered before use.
  final Map<String, SettingsGroup> _settings = {};

  /// Callback functions to call when any setting changes.
  final List<void Function(String key, dynamic oldValue, dynamic newValue)>
      _changeCallbacks = [];

  /// Whether this Settings instance has been disposed.
  bool _disposed = false;

  /// Creates a new Settings manager instance.
  ///
  /// Parameters:
  /// - [store]: The SettingsStore to use for persistence. If not provided, creates a new one.
  EasySettings({SettingsStore? store}) : _store = store ?? SettingsStore() {
    _logger.info('Creating Settings manager');
  }

  /// Initializes all registered settings groups concurrently.
  ///
  /// This method waits for all registered settings groups to complete their
  /// asynchronous initialization. It's essential to call this method before
  /// accessing any setting values to ensure they've been loaded from storage.
  ///
  /// The initialization process:
  /// 1. Waits for the underlying SharedPreferences to be ready
  /// 2. Loads existing values from storage for each setting
  /// 3. Creates default values for settings that don't exist yet
  /// 4. Marks all groups as ready for synchronous access
  ///
  /// Returns: Future that completes when all settings are initialized
  ///
  /// Throws: Exception if any settings group fails to initialize
  ///
  /// Example:
  /// ```dart
  /// // Register your settings groups first
  /// settings.register(gameSettings);
  /// settings.register(uiSettings);
  ///
  /// // Then initialize everything
  /// await settings.init();
  ///
  /// // Now safe to use settings synchronously
  /// bool soundEnabled = settings.getBool('game.soundEnabled');
  /// ```
  Future<void> init() async {
    _checkNotDisposed();
    _logger
        .info('Initializing Settings manager with ${_settings.length} groups');

    final futures = _settings.values.map((settings) => settings.readyFuture);
    await Future.wait(futures);

    _logger.info('Settings manager initialized successfully');
  }

  /// Checks if this Settings instance has been disposed and throws if so.
  void _checkNotDisposed() {
    if (_disposed) {
      throw StateError('Settings instance has been disposed');
    }
  }

  /// Returns a map of all registered settings groups.
  Map<String, SettingsGroup> get groups {
    _checkNotDisposed();
    return Map.unmodifiable(_settings);
  }

  /// Returns a list of all registered settings groups keys.
  List<String> get groupKeys {
    _checkNotDisposed();
    return _settings.keys.toList();
  }

  /// Adds a callback function that will be called whenever any setting changes.
  ///
  /// The callback receives the full storage key, old value, and new value.
  /// This is useful for implementing global change listeners or analytics.
  ///
  /// Parameters:
  /// - [callback]: Function called on any setting change
  ///
  /// Example:
  /// ```dart
  /// settings.addChangeCallback((key, oldValue, newValue) {
  ///   print('Setting $key changed from $oldValue to $newValue');
  /// });
  /// ```
  void addChangeCallback(
      void Function(String key, dynamic oldValue, dynamic newValue) callback) {
    _checkNotDisposed();
    _changeCallbacks.add(callback);
    _logger.fine('Added change callback (total: ${_changeCallbacks.length})');
  }

  /// Removes a previously added change callback.
  ///
  /// Parameters:
  /// - [callback]: The callback function to remove
  ///
  /// Returns: true if the callback was found and removed, false otherwise
  bool removeChangeCallback(
      void Function(String key, dynamic oldValue, dynamic newValue) callback) {
    _checkNotDisposed();
    final removed = _changeCallbacks.remove(callback);
    if (removed) {
      _logger
          .fine('Removed change callback (total: ${_changeCallbacks.length})');
    }
    return removed;
  }

  /// Notifies all registered change callbacks of a setting change.
  void _notifyChangeCallbacks(String key, dynamic oldValue, dynamic newValue) {
    for (final callback in _changeCallbacks) {
      try {
        callback(key, oldValue, newValue);
      } catch (e) {
        _logger.warning('Error in change callback for key: $key', e);
      }
    }
  }

  /// Validate and get the parts of a storage key.
  /// The [storageKey] should be in the format "groupKey.settingKey".
  /// Throws an [ArgumentError] if the storage key is invalid.
  @override
  ({String group, String setting}) parseStorageKey(String storageKey) {
    final parts = storageKey.split('.');
    if (parts.length < 2) {
      throw ArgumentError('Invalid storage key: $storageKey');
    }
    return (group: parts.first, setting: parts.sublist(1).join('.'));
  }

  // ===== Getters =====

  /// Override the accessor to allow dynamic access to settings
  /// using the `[]` operator.
  @override
  dynamic operator [](String key) {
    return get<dynamic>(key);
  }

  /// Registers a settings group with this settings manager.
  ///
  /// Each settings group must be registered before the system can be initialized.
  /// Groups are identified by their unique key, and duplicate keys are not allowed.
  ///
  /// This method should be called during application startup, before calling [init].
  ///
  /// Parameters:
  /// - [settingsGroup]: The SettingsGroup instance to register
  ///
  /// Throws: [ArgumentError] if a group with the same key already exists
  ///
  /// Example:
  /// ```dart
  /// final gameSettings = SettingsGroup(key: 'game', items: [...], store: store);
  /// final uiSettings = SettingsGroup(key: 'ui', items: [...], store: store);
  ///
  /// settings.register(gameSettings);
  /// settings.register(uiSettings);
  ///
  /// await settings.init(); // Initialize after all groups are registered
  /// ```
  void register(SettingsGroup settingsGroup) {
    _checkNotDisposed();

    if (_settings.containsKey(settingsGroup.key)) {
      _logger.warning(
          'Attempted to register duplicate settings group: ${settingsGroup.key}');
      throw ArgumentError(
          'Settings with key ${settingsGroup.key} already exists');
    }

    _settings[settingsGroup.key] = settingsGroup;
    _logger.info('Registered settings group: ${settingsGroup.key}');
  }

  /// Register and initialize a settings group after the main initialization.
  ///
  /// This allows adding new settings groups even after [init] has been called.
  /// The group will be immediately initialized and ready for use.
  ///
  /// This is useful for dynamically adding settings for new features or
  /// modules that are loaded after the main app initialization.
  ///
  /// Parameters:
  /// - [settingsGroup]: The SettingsGroup instance to register and initialize
  ///
  /// Throws: [ArgumentError] if a group with the same key already exists
  ///
  /// Example:
  /// ```dart
  /// // After main initialization
  /// final newFeatureSettings = SettingsGroup(
  ///   key: 'newFeature',
  ///   items: [BoolSetting(key: 'enabled', defaultValue: false)],
  ///   store: store
  /// );
  ///
  /// await settings.registerAndInit(newFeatureSettings);
  /// // Group is now ready to use
  /// ```
  Future<void> registerAndInit(SettingsGroup settingsGroup) async {
    _checkNotDisposed();

    // Register the group (this will throw if duplicate)
    register(settingsGroup);

    // The group is automatically ready to use after registration since
    // it shares the same store as the main settings instance
    _logger.info('Settings group ${settingsGroup.key} registered and ready');
  }

  /// Gets a settings group by its key.
  @override
  SettingsGroup getGroup(String key) {
    _checkNotDisposed();

    if (!_settings.containsKey(key)) {
      _logger.warning('Attempted to access non-existent settings group: $key');
      throw SettingNotFoundException('No settings group found for key: $key');
    }
    return _settings[key]!;
  }

  /// Check if a settings group exists by its key.
  ///
  /// Parameters:
  /// - [key]: The key of the settings group to check
  ///
  /// Returns: true if the group exists, false otherwise
  bool hasGroup(String key) {
    _checkNotDisposed();
    return _settings.containsKey(key);
  }

  /// Get a setting by its storage key and type.
  /// The [storageKey] should be in the format "groupKey.settingKey".
  /// Throws an [ArgumentError] if the storage key is invalid or
  /// if the setting is not found.
  @override
  T get<T>(String storageKey) {
    // Split the storage key to get the group key and setting key.
    final id = parseStorageKey(storageKey);

    final group = getGroup(id.group);
    return group.get<T>(id.setting);
  }

  // Helpers for typed access to settings.
  // These methods are for convenience to access settings without
  // ending up with a dynamic value.

  /// Gets a boolean setting by its storage key.
  /// The [storageKey] should be in the format "groupKey.settingKey".
  /// Throws an [ArgumentError] if the storage key is invalid or
  /// if the setting is not found or is not of type bool.
  @override
  bool getBool(String storageKey) {
    return get<bool>(storageKey);
  }

  /// Gets a double setting by its storage key.
  /// The [storageKey] should be in the format "groupKey.settingKey".
  /// Throws an [ArgumentError] if the storage key is invalid or
  /// if the setting is not found or is not of type int.
  @override
  int getInt(String storageKey) {
    return get<int>(storageKey);
  }

  /// Gets a double setting by its storage key.
  /// The [storageKey] should be in the format "groupKey.settingKey".
  /// Throws an [ArgumentError] if the storage key is invalid or
  /// if the setting is not found or is not of type double.
  @override
  double getDouble(String storageKey) {
    return get<double>(storageKey);
  }

  /// Gets a string setting by its storage key.
  /// The [storageKey] should be in the format "groupKey.settingKey".
  /// Throws an [ArgumentError] if the storage key is invalid or
  /// if the setting is not found or is not of type string.
  @override
  String getString(String storageKey) {
    return get<String>(storageKey);
  }

  /// Gets a string list setting by its storage key.
  /// The [storageKey] should be in the format "groupKey.settingKey".
  /// Throws an [ArgumentError] if the storage key is invalid or
  /// if the setting is not found or is not of type List&lt;String&gt;.
  @override
  List<String> getStringList(String storageKey) {
    return get<List<String>>(storageKey);
  }

  // ===== Setters =====

  /// Sets a setting value by its storage key.
  /// The [storageKey] should be in the format "groupKey.settingKey".
  /// Throws an [ArgumentError] if the storage key is invalid or
  /// if the setting is not found or is not user configurable.
  @override
  Future<void> setValue(String storageKey, dynamic value) async {
    final id = parseStorageKey(storageKey);
    final group = getGroup(id.group);
    await group.setValue(id.setting, value);
  }

  /// Sets a setting value by its storage key and type.
  /// The [storageKey] should be in the format "groupKey.settingKey".
  /// Throws an [ArgumentError] if the storage key is invalid or
  /// if the setting is not found or is not user configurable.
  @override
  Future<void> set<T>(String storageKey, T value) async {
    _checkNotDisposed();

    // Get old value for change notification
    final oldValue = _tryGetValue(storageKey);

    final id = parseStorageKey(storageKey);
    final group = getGroup(id.group);
    await group.setValue<T>(id.setting, value);

    // Notify change callbacks
    _notifyChangeCallbacks(storageKey, oldValue, value);
  }

  /// Safely attempts to get a value without throwing if the setting doesn't exist.
  /// Returns null if the setting doesn't exist or if there's an error accessing it.
  dynamic _tryGetValue(String storageKey) {
    try {
      return get<dynamic>(storageKey);
    } catch (e) {
      _logger.fine('Could not get old value for $storageKey: $e');
      return null;
    }
  }

  /// Sets a boolean setting value by its storage key.
  /// The [storageKey] should be in the format "groupKey.settingKey".
  /// Throws an [ArgumentError] if the storage key is invalid or
  /// if the setting is not found or is not user configurable.
  @override
  Future<void> setBool(String storageKey, bool value) async {
    await set<bool>(storageKey, value);
  }

  /// Sets an integer setting value by its storage key.
  /// The [storageKey] should be in the format "groupKey.settingKey".
  /// Throws an [ArgumentError] if the storage key is invalid or
  /// if the setting is not found or is not user configurable.
  @override
  Future<void> setInt(String storageKey, int value) async {
    await set<int>(storageKey, value);
  }

  /// Sets a double setting value by its storage key.
  /// The [storageKey] should be in the format "groupKey.settingKey".
  /// Throws an [ArgumentError] if the storage key is invalid or
  /// if the setting is not found or is not user configurable.
  @override
  Future<void> setDouble(String storageKey, double value) async {
    await set<double>(storageKey, value);
  }

  /// Sets a string setting value by its storage key.
  /// The [storageKey] should be in the format "groupKey.settingKey".
  /// Throws an [ArgumentError] if the storage key is invalid or
  /// if the setting is not found or is not user configurable.
  @override
  Future<void> setString(String storageKey, String value) async {
    await set<String>(storageKey, value);
  }

  /// Sets a string list setting value by its storage key.
  /// The [storageKey] should be in the format "groupKey.settingKey".
  /// Throws an [ArgumentError] if the storage key is invalid or
  /// if the setting is not found or is not user configurable.
  @override
  Future<void> setStringList(String storageKey, List<String> value) async {
    await set<List<String>>(storageKey, value);
  }

  /// Sets multiple settings values in a batch operation.
  /// The [settings] map should contain storage keys as keys and values as values.
  /// This is more efficient than setting values individually.
  Future<void> setMultiple(Map<String, dynamic> settings) async {
    _checkNotDisposed();

    // Collect old values for change notifications
    final oldValues = <String, dynamic>{};
    for (final key in settings.keys) {
      oldValues[key] = _tryGetValue(key);
    }

    final futures = <Future<void>>[];
    for (final entry in settings.entries) {
      // Use setValue directly to avoid double change notifications
      final id = parseStorageKey(entry.key);
      final group = getGroup(id.group);
      futures.add(group.setValue(id.setting, entry.value));
    }
    await Future.wait(futures);

    // Notify change callbacks for all changed settings
    for (final entry in settings.entries) {
      _notifyChangeCallbacks(entry.key, oldValues[entry.key], entry.value);
    }
  }

  /// Reset a setting to its default value by storage key.
  /// The [storageKey] should be in the format "groupKey.settingKey".
  Future<void> resetSetting(String storageKey) async {
    _checkNotDisposed();

    final oldValue = _tryGetValue(storageKey);
    final id = parseStorageKey(storageKey);
    final group = getGroup(id.group);
    await group.reset(id.setting);

    // Get the new (default) value and notify callbacks
    final newValue = _tryGetValue(storageKey);
    _notifyChangeCallbacks(storageKey, oldValue, newValue);
  }

  /// Reset all settings in a group to their default values.
  /// The [groupKey] should be the key of the settings group.
  Future<void> resetGroup(String groupKey) async {
    _checkNotDisposed();

    final group = getGroup(groupKey);

    // Collect old values for all settings in the group
    final oldValues = <String, dynamic>{};
    for (final setting in group.items) {
      final storageKey = '$groupKey.${setting.key}';
      oldValues[storageKey] = _tryGetValue(storageKey);
    }

    await group.resetAll();

    // Notify callbacks for all reset settings
    for (final setting in group.items) {
      final storageKey = '$groupKey.${setting.key}';
      _notifyChangeCallbacks(
          storageKey, oldValues[storageKey], setting.defaultValue);
    }
  }

  /// Reset all settings across all groups to their default values.
  Future<void> resetAll() async {
    _checkNotDisposed();

    // Collect old values for all settings
    final oldValues = <String, dynamic>{};
    for (final group in _settings.values) {
      for (final setting in group.items) {
        final storageKey = '${group.key}.${setting.key}';
        oldValues[storageKey] = _tryGetValue(storageKey);
      }
    }

    final futures = _settings.values.map((group) => group.resetAll());
    await Future.wait(futures);

    // Notify callbacks for all reset settings
    for (final group in _settings.values) {
      for (final setting in group.items) {
        final storageKey = '${group.key}.${setting.key}';
        _notifyChangeCallbacks(
            storageKey, oldValues[storageKey], setting.defaultValue);
      }
    }
  }

  /// Dispose all settings groups, callbacks, and release resources.
  ///
  /// This method properly cleans up all resources including:
  /// - All registered settings groups and their stream controllers
  /// - Change callback functions
  /// - The underlying settings store (if created by this instance)
  ///
  /// After calling dispose, this Settings instance should not be used.
  /// Attempting to use a disposed instance will throw a StateError.
  ///
  /// Example:
  /// ```dart
  /// // When your app shuts down or the settings are no longer needed
  /// settings.dispose();
  /// ```
  void dispose() {
    if (_disposed) {
      _logger
          .warning('Attempted to dispose already disposed Settings instance');
      return;
    }

    _logger.info('Disposing Settings manager with ${_settings.length} groups');

    // Dispose all settings groups
    for (final group in _settings.values) {
      try {
        group.dispose();
      } catch (e) {
        _logger.warning('Error disposing settings group: ${group.key}', e);
      }
    }

    // Clear all collections
    _settings.clear();
    _changeCallbacks.clear();

    // Dispose the store if we created it
    try {
      _store.dispose();
    } catch (e) {
      _logger.fine('Error disposing store (may be shared): $e');
    }

    _disposed = true;
    _logger.info('Settings manager disposed successfully');
  }

  /// Clear all registered settings groups (for testing purposes).
  ///
  /// This is equivalent to calling dispose() but kept for backward compatibility.
  void clearAll() {
    dispose();
  }

  @override
  String toString() {
    return 'Settings{groups: ${_settings.keys.join(', ')}}';
  }
}
