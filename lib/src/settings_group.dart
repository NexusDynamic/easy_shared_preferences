import 'dart:convert';
import 'dart:async';
import 'dart:collection';
import 'package:easy_shared_preferences/src/global_settings.dart';
import 'package:logging/logging.dart';

import 'exceptions.dart';
import 'settings_store.dart';
import 'setting.dart';
import 'logger.dart';

/// A comprehensive settings group that manages related settings with persistence,
/// initialization, and type-safe access.
///
/// [SettingsGroup] extends [UnmodifiableMapBase] to provide convenient
/// map-like access to settings while managing their persistence and validation.
/// Each group has a unique key namespace and handles its own initialization.
///
/// Usage pattern:
/// ```dart
/// // 1. Define your settings group
/// final gameSettings = SettingsGroup(
///   key: 'game',
///   items: [
///     BoolSetting(key: 'soundEnabled', defaultValue: true),
///     DoubleSetting(key: 'volume', defaultValue: 0.8),
///   ],
/// );
///
/// // 2. Register with the global settings manager
/// Settings.register(gameSettings);
///
/// // 3. Wait for initialization
/// await gameSettings.readyFuture;
///
/// // 4. Use the settings
/// bool soundEnabled = gameSettings.get<bool>('soundEnabled');
/// await gameSettings.setValue('volume', 0.5);
/// ```
class SettingsGroup extends UnmodifiableMapBase<String, Setting> {
  static final _logger = EspLogger.forComponent('SettingsGroup');

  /// Reference to the settings store for persistence.
  ///
  /// This store handles the actual reading and writing of values
  /// to SharedPreferences with caching for performance.
  final SettingsStore _store;

  /// Whether this group owns the store and should dispose it.
  /// True for testing groups, false for injected stores.
  final bool _ownsStore;

  /// Mutex to prevent race conditions during concurrent access.
  final _accessMutex = <String, Completer<void>>{};

  /// Timeout for async operations to prevent hanging.
  final Duration _operationTimeout;

  /// Unique identifier for this settings group.
  ///
  /// This key is used as a namespace prefix for all settings in this group.
  /// For example, if key is 'game' and a setting key is 'volume',
  /// the stored key becomes 'game.volume'.
  ///
  /// Should be descriptive and unique across your application.
  final String key;

  /// Immutable set of all settings contained in this group.
  ///
  /// This set is created during construction and cannot be modified afterward.
  /// It contains all the setting objects that belong to this group.
  late final Set<Setting<dynamic>> items;

  /// Internal cache of setting keys for efficient lookups.
  ///
  /// This set contains the string keys of all settings in the group,
  /// providing O(1) key existence checks and fast iteration.
  late final Set<String> _keys;

  /// Internal flag tracking initialization status.
  bool _ready = false;

  /// Public property indicating whether this settings group is ready for use.
  ///
  /// When false, accessing setting values will throw [SettingsNotReadyException].
  /// When true, all settings have been loaded and are available synchronously.
  bool get ready => _ready;

  /// Internal completer that completes when initialization finishes.
  late Completer<bool> _readyCompleter;

  /// Future that completes when all settings in this group are initialized.
  ///
  /// Await this future before accessing setting values to ensure they've
  /// been loaded from storage. The future completes with true on success
  /// or throws an exception if initialization fails.
  ///
  /// Example:
  /// ```dart
  /// await gameSettings.readyFuture;
  /// // Now safe to access settings synchronously
  /// bool soundEnabled = gameSettings.get<bool>('soundEnabled');
  /// ```
  Future<bool> get readyFuture => _readyCompleter.future;

  /// Creates a new settings group with the given key and settings.
  ///
  /// The provided [items] are converted to an immutable set, and their
  /// keys are extracted for efficient access. Duplicate keys within
  /// the same group are not allowed and will cause undefined behavior.
  ///
  /// Parameters:
  /// - [key]: Unique identifier for this settings group
  /// - [items]: Collection of settings to include in this group
  /// - [store]: The SettingsStore instance to use for persistence
  /// - [operationTimeout]: Timeout for async operations (default: 30 seconds)
  ///
  /// Example:
  /// ```dart
  /// final store = SettingsStore();
  /// final group = SettingsGroup(
  ///   key: 'game',
  ///   items: [
  ///     BoolSetting(key: 'notifications', defaultValue: true),
  ///     IntSetting(key: 'timeout', defaultValue: 30),
  ///   ],
  ///   store: store,
  /// );
  /// ```
  SettingsGroup({
    required this.key,
    required Iterable<Setting> items,
    required SettingsStore store,
    Duration operationTimeout = const Duration(seconds: 30),
  })  : _store = store,
        _ownsStore = false,
        _operationTimeout = operationTimeout {
    this.items = Set<Setting>.from(items);
    _keys = items.map((item) => item.key).toSet();
    _readyCompleter = Completer<bool>();

    _logger.info('Creating SettingsGroup: $key with ${items.length} items');

    // Initialize the settings in the storage if they haven't been set yet.
    _init();
  }

  /// Creates a new settings group optimized for testing.
  /// This constructor creates its own SettingsStore with regular SharedPreferences
  /// instead of SharedPreferencesWithCache to avoid test compatibility issues.
  SettingsGroup.forTesting({
    required this.key,
    required Iterable<Setting> items,
    Duration operationTimeout = const Duration(seconds: 30),
  })  : _store = SettingsStore(forceRegularSharedPreferences: true),
        _ownsStore = true,
        _operationTimeout = operationTimeout {
    this.items = Set<Setting>.from(items);
    _keys = items.map((item) => item.key).toSet();
    _readyCompleter = Completer<bool>();

    _logger.info(
        'Creating SettingsGroup for testing: $key with ${items.length} items');

    // Initialize the settings in the storage if they haven't been set yet.
    _init();
  }

  /// Retrieves a setting by its key.
  ///
  /// This operator provides map-like access to settings within the group.
  /// The return type is [Setting<dynamic>] to accommodate different setting types.
  ///
  /// Parameters:
  /// - [key]: The string key of the setting to retrieve
  ///
  /// Returns: The setting object with the specified key or null if not found.
  ///
  /// Example:
  /// ```dart
  /// Setting volumeSetting = audioGroup['volume'];
  /// BoolSetting enabledSetting = audioGroup['enabled'] as BoolSetting;
  /// ```
  @override
  Setting<dynamic>? operator [](Object? key) {
    try {
      return items.firstWhere((item) => item.key == key);
    } catch (_) {
      return null;
    }
  }

  /// Returns an iterable of all setting keys in this group.
  ///
  /// This property provides the keys needed for map-like iteration
  /// and key existence checking.
  ///
  /// Returns: Iterable containing all setting keys as strings
  @override
  Iterable<String> get keys => _keys;

  /// Returns the number of settings in this group.
  ///
  /// This count includes all settings regardless of their type
  /// or configurability status.
  ///
  /// Returns: Integer count of settings in the group
  @override
  int get length => _keys.length;

  /// Executes an operation with mutex protection to prevent race conditions.
  ///
  /// This method ensures that only one operation can access a given key at a time,
  /// preventing race conditions during concurrent setting modifications.
  Future<T> _withMutex<T>(String key, Future<T> Function() operation) async {
    // Check if there's already an operation in progress for this key
    if (_accessMutex.containsKey(key)) {
      _logger.fine('Waiting for mutex for key: $key');
      await _accessMutex[key]!.future;
    }

    // Create a new completer for this operation
    final completer = Completer<void>();
    _accessMutex[key] = completer;

    try {
      _logger.fine('Acquired mutex for key: $key');
      final result = await operation().timeout(_operationTimeout);
      return result;
    } catch (e) {
      _logger.warning('Operation failed for key: $key', e);
      rethrow;
    } finally {
      // Release the mutex
      _accessMutex.remove(key);
      completer.complete();
      _logger.fine('Released mutex for key: $key');
    }
  }

  /// Initializes the settings by checking if they are set in the storage.
  /// If not, it sets them with their default values.
  /// This is called in the constructor to ensure settings are ready to use.
  /// It waits for the store to be ready before proceeding, but there is no
  /// guarantee that the settings are initialized before the first access.
  /// If you need to ensure settings are initialized before use, you should
  /// await the [readyFuture] before accessing any settings.
  Future<void> _init() async {
    try {
      _logger.info('Initializing SettingsGroup: $key');

      if (!_store.ready) {
        _logger.fine('Waiting for SettingsStore to be ready');
        await _store.readyFuture.timeout(_operationTimeout);
      }

      for (final Setting setting in items) {
        final storageKey = _storageKey(setting.key);
        _logger.fine('Initializing setting: $storageKey');

        if (!_store.prefs.containsKey(storageKey)) {
          // If the setting is not set, initialize it with the default value.
          _logger.fine('Setting default value for: $storageKey');
          await _set(storageKey, setting, null, force: true);
        } else {
          // Validate existing value and attempt recovery if invalid
          try {
            final currentValue = _get(setting);
            if (setting.validator != null) {
              final validationResult = setting.validateWithResult(currentValue);
              if (!validationResult.isValid) {
                _logger.warning(
                    'Validation failed for stored value in $storageKey: ${validationResult.errorDescription}');

                // Attempt recovery using the error handler
                try {
                  final recoveredValue = setting.attemptRecovery(
                    currentValue,
                    validationResult.errorDescription!,
                  );

                  if (recoveredValue != null) {
                    _logger.info(
                        'Successfully recovered invalid value for $storageKey, using recovered value');
                    await _set(storageKey, setting, recoveredValue,
                        force: true);
                  } else {
                    _logger.info(
                        'No recovery possible for $storageKey, using default value');
                    await _set(storageKey, setting, null,
                        force: true); // null -> uses default
                  }
                } catch (recoveryError) {
                  _logger.severe(
                      'Recovery failed for $storageKey, using default value: $recoveryError');
                  await _set(storageKey, setting, null,
                      force: true); // null -> uses default
                }
              } else {
                _logger.fine(
                    'Successfully validated existing value for: $storageKey');
              }
            } else {
              _logger.fine('No validation required for: $storageKey');
            }
          } catch (e) {
            // If there's an error reading the current value, use default
            _logger.warning(
                'Error reading stored value for $storageKey, using default value: $e');
            await _set(storageKey, setting, null,
                force: true); // null -> uses default
          }
        }
      }

      _ready = true;
      _logger.info('SettingsGroup initialized successfully: $key');
      _readyCompleter.complete(true);
    } catch (error) {
      _ready = false;
      _logger.severe('Failed to initialize SettingsGroup: $key', error);
      _readyCompleter.completeError(error);
      rethrow;
    }
  }

  /// Sets the value of a setting by its key.
  Future<void> setValue<T>(String key, T value) async {
    await _waitUntilReady();

    return _withMutex(key, () async {
      if (_logger.isLoggable(Level.FINE)) {
        _logger.fine('Setting value for key: $key to: $value');
      }

      final setting = this[key];
      if (setting == null) {
        _logger.warning(
            'Attempted to set non-existent setting: $key in group: ${this.key}');
        throw SettingNotFoundException(
          'No setting in ${this.key} found for key: $key',
        );
      }

      final storageKey = _storageKey(setting.key);
      if (!setting.userConfigurable) {
        _logger.warning(
            'Attempted to modify non-configurable setting: $storageKey');
        throw SettingNotConfigurableException(
          'Setting $storageKey is not user configurable',
        );
      }

      // Validate the value if a validator is provided
      if (setting is Setting<T> && setting.validator != null) {
        final validationResult = setting.validateWithResult(value);
        if (!validationResult.isValid) {
          _logger.warning(
              'Validation failed for setting $storageKey with value: $value - ${validationResult.errorDescription}');
          throw SettingValidationException(
            'Invalid value for setting $storageKey: $value - ${validationResult.errorDescription}',
          );
        }
      }

      await _set(storageKey, setting, value);
      _logger.info('Successfully set value for $storageKey');

      // Notify change listeners
      if (setting is Setting<T>) {
        setting.notifyChange(value);
        _logger.fine('Notified change listeners for: $storageKey');
      }
    });
  }

  /// Convenience method to get a typed value of a setting by its key.
  /// Throws an error if the setting is not found or if the type does not match.
  T get<T>(String key) {
    _readySync();
    if (T == dynamic) {
      return getValue(key);
    }
    final setting = this[key];
    if (setting == null) {
      throw SettingNotFoundException(
        'No setting in ${this.key} found for key: $key',
      );
    }
    if (setting is! Setting<T>) {
      throw ArgumentError(
        'Setting $key is not of type ${T.runtimeType}, but ${setting.type}',
      );
    }

    return _get<T>(setting);
  }

  /// Gets the value of a setting by its key.
  dynamic getValue(String key) {
    _readySync();
    final setting = this[key];
    if (setting == null) {
      throw SettingNotFoundException(
        'No setting in ${this.key} found for key: $key',
      );
    }

    return _get(setting);
  }

  /// Ensures that the settings are ready before accessing them.
  /// Throws a [SettingsNotReadyException] if the settings are not ready.
  void _readySync() {
    if (!_ready) {
      throw SettingsNotReadyException(
        'Settings are not ready. Please await readyFuture.',
      );
    }
  }

  /// Waits until the settings are ready.
  /// This is useful for asynchronous operations that need to ensure
  /// settings are initialized.
  Future<void> _waitUntilReady() async {
    if (!_ready) {
      await _readyCompleter.future;
    }
  }

  /// Constructs a storage key for the given key in this settings group.
  /// This is used to namespace the settings keys to avoid conflicts.
  /// For example, if the group key is "game" and the setting key is
  /// "fullscreen", the storage key will be "game.fullscreen".
  String _storageKey(String key) {
    return "${this.key}.$key";
  }

  /// Fast path for getting values without validation during reads.
  /// Values are assumed to be valid since we validate on writes and initialization.
  ///
  /// This method is internal but exposed for performance optimizations in typed access patterns.
  T getValueUnvalidated<T>(Setting<T> setting) {
    final storageKey = _storageKey(setting.key);
    if (!_store.prefs.containsKey(storageKey)) {
      return setting.defaultValue;
    }

    try {
      switch (T) {
        case const (bool):
          return _store.prefs.getBool(storageKey) as T? ?? setting.defaultValue;
        case const (int):
          return _store.prefs.getInt(storageKey) as T? ?? setting.defaultValue;
        case const (double):
          return _store.prefs.getDouble(storageKey) as T? ??
              setting.defaultValue;
        case const (String):
          return _store.prefs.getString(storageKey) as T? ??
              setting.defaultValue;
        case const (List<String>):
          return _store.prefs.getStringList(storageKey) as T? ??
              setting.defaultValue;
        case const (dynamic):
          switch (setting.type) {
            case SettingType.bool:
              return _store.prefs.getBool(storageKey) as T? ??
                  setting.defaultValue;
            case SettingType.int:
              return _store.prefs.getInt(storageKey) as T? ??
                  setting.defaultValue;
            case SettingType.double:
              return _store.prefs.getDouble(storageKey) as T? ??
                  setting.defaultValue;
            case SettingType.string:
              return _store.prefs.getString(storageKey) as T? ??
                  setting.defaultValue;
            case SettingType.stringList:
              return _store.prefs.getStringList(storageKey) as T? ??
                  setting.defaultValue;
          }
        default:
          throw ArgumentError('Unsupported setting type: ${T.runtimeType}');
      }
    } catch (e) {
      // If there's a type mismatch or other error, return default value
      if (_logger.isLoggable(Level.WARNING)) {
        _logger.warning('Error reading setting $storageKey, using default', e);
      }
      return setting.defaultValue;
    }
  }

  /// Gets the value of a setting by its key and type.
  /// Uses fast unvalidated access since values are validated on writes and initialization.
  T _get<T>(Setting<T> setting) {
    return getValueUnvalidated<T>(setting);
  }

  /// Sets the value of a setting by its key and type.
  /// Throws an error if the setting is not found or if the type does not match.
  /// This method is used internally to set the value of a setting.
  /// If [force] is true, it will set the value even if the setting is
  /// not user configurable.
  /// If [value] is null, it will use the default value of the setting.
  /// If the setting is not user configurable and [force] is false,
  /// it will throw an error.
  Future<void> _set<T>(
    String storageKey,
    Setting<T> setting,
    T? value, {
    bool force = false,
  }) async {
    if (!force && !setting.userConfigurable) {
      throw SettingNotConfigurableException(
        'Setting $storageKey is not user configurable',
      );
    }
    if (!force && !_store.prefs.containsKey(storageKey)) {
      throw SettingNotFoundException('No setting found for: $storageKey');
    }

    switch (T) {
      case const (bool):
        value ??= setting.defaultValue;
        return _setBool(storageKey, value as bool);
      case const (int):
        value ??= setting.defaultValue;
        return _setInt(storageKey, value as int);
      case const (double):
        value ??= setting.defaultValue;
        return _setDouble(storageKey, value as double);
      case const (String):
        value ??= setting.defaultValue;
        return _setString(storageKey, value as String);
      case const (List<String>):
        value ??= setting.defaultValue;
        return _setStringList(storageKey, value as List<String>);
      case const (dynamic):
        // If the type is dynamic, we can return any value.
        // This is a fallback for when the type is not known at compile time.
        // it is less efficient, but let's face it, you probably should not be
        // updating settings 1000s of times per second.
        value ??= setting.defaultValue;

        switch (setting.type) {
          case SettingType.bool:
            return _setBool(storageKey, value as bool);
          case SettingType.int:
            return _setInt(storageKey, value as int);
          case SettingType.double:
            return _setDouble(storageKey, value as double);
          case SettingType.string:
            return _setString(storageKey, value as String);
          case SettingType.stringList:
            return _setStringList(storageKey, value as List<String>);
        }
      default:
        throw ArgumentError('Unsupported setting type: ${T.runtimeType}');
    }
  }

  /// Sets a boolean value for the given storage key.
  Future<void> _setBool(String storageKey, bool value) async {
    await _store.prefs.setBool(storageKey, value);
  }

  /// Sets an integer value for the given storage key.
  Future<void> _setInt(String storageKey, int value) async {
    await _store.prefs.setInt(storageKey, value);
  }

  /// Sets a double value for the given storage key.
  Future<void> _setDouble(String storageKey, double value) async {
    await _store.prefs.setDouble(storageKey, value);
  }

  /// Sets a string value for the given storage key.
  Future<void> _setString(String storageKey, String value) async {
    await _store.prefs.setString(storageKey, value);
  }

  /// Sets a string list value for the given storage key.
  Future<void> _setStringList(String storageKey, List<String> value) async {
    await _store.prefs.setStringList(storageKey, value);
  }

  /// Reset a setting to its default value.
  Future<void> reset(String key) async {
    await _waitUntilReady();
    final setting = this[key];
    if (setting == null) {
      throw SettingNotFoundException(
        'No setting in ${this.key} found for key: $key',
      );
    }
    final storageKey = _storageKey(setting.key);
    await _set(storageKey, setting, null, force: true);

    // Notify change listeners
    setting.notifyChange(setting.defaultValue);
  }

  /// Reset all settings in this group to their default values.
  Future<void> resetAll() async {
    await _waitUntilReady();
    for (final setting in items) {
      final storageKey = _storageKey(setting.key);
      await _set(storageKey, setting, null, force: true);
      setting.notifyChange(setting.defaultValue);
    }
  }

  /// Dispose all stream controllers for settings in this group and cleanup resources.
  void dispose() {
    _logger.info('Disposing SettingsGroup: $key');

    // Dispose all settings and their stream controllers
    for (final setting in items) {
      setting.dispose();
    }

    // Clear any pending mutex operations
    for (final completer in _accessMutex.values) {
      if (!completer.isCompleted) {
        completer.completeError(
            Exception('SettingsGroup disposed while operation was pending'));
      }
    }
    _accessMutex.clear();

    // Only dispose the store if we own it (created in forTesting constructor)
    if (_ownsStore) {
      try {
        _store.dispose();
        _logger.fine('Disposed owned store for group: $key');
      } catch (e) {
        _logger.warning('Error disposing owned store for group: $key', e);
      }
    }

    _ready = false;
    _logger.fine('SettingsGroup disposed: $key');
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};
    for (final setting in items) {
      map[setting.key] = _get(setting);
    }
    return map;
  }

  /// Creates a JSON string representation of this settings group.
  String toJson() {
    final map = toMap();
    return jsonEncode(map);
  }

  /// Creates a settings group from a Map representation.
  /// Note: This does not initialize the settings in storage.
  /// You must call _init() manually after creating the group.
  static SettingsGroup fromMap({
    required String key,
    required Map<String, dynamic> map,
    required SettingsStore store,
    Duration operationTimeout = const Duration(seconds: 30),
  }) {
    final items = <Setting>[];
    map.forEach((settingKey, value) {
      if (value is bool) {
        items.add(BoolSetting(key: settingKey, defaultValue: value));
      } else if (value is int) {
        items.add(IntSetting(key: settingKey, defaultValue: value));
      } else if (value is double) {
        items.add(DoubleSetting(key: settingKey, defaultValue: value));
      } else if (value is String) {
        items.add(StringSetting(key: settingKey, defaultValue: value));
      } else if (value is List<String>) {
        items.add(StringListSetting(key: settingKey, defaultValue: value));
      } else {
        throw ArgumentError(
            'Unsupported setting type for key: $settingKey, value: $value');
      }
    });
    return SettingsGroup(
      key: key,
      items: items,
      store: store,
      operationTimeout: operationTimeout,
    );
  }

  /// Creates a settings group from a JSON string representation.
  /// Note: This does not initialize the settings in storage.
  /// You must call _init() manually after creating the group.
  static SettingsGroup fromJson({
    required String key,
    required String json,
    required SettingsStore store,
    Duration operationTimeout = const Duration(seconds: 30),
  }) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    return fromMap(
      key: key,
      map: map,
      store: store,
      operationTimeout: operationTimeout,
    );
  }

  /// updates the settings in this group from a Map representation.
  /// Only updates settings that already exist in this group.
  /// Does not add new settings or remove existing ones.
  Future<void> updateFromMap(Map<String, dynamic> map) async {
    await _waitUntilReady();
    for (final entry in map.entries) {
      final setting = this[entry.key];
      if (setting != null) {
        await setValue(entry.key, entry.value);
      } else {
        _logger.warning(
            'Attempted to update non-existent setting: ${entry.key} in group: $key');
      }
    }
  }

  /// Returns a string representation of this settings group.
  @override
  String toString() {
    return 'SettingsGroup($key, items: ${items.length}, ready: $_ready)';
  }

  /// Converts this SettingsGroup to a GroupConfig for serialization or re-initialization.
  GroupConfig toConfig() {
    return GroupConfig(key: key, items: items);
  }

  /// Converts this SettingsGroup to a JSON string representation of its configuration.
  String toConfigJson() {
    final config = toConfig();
    return config.toJson();
  }

  /// Converts this SettingsGroup to a Map representation of its configuration.
  Map<String, dynamic> toConfigMap() {
    final config = toConfig();
    return config.toMap();
  }
}
