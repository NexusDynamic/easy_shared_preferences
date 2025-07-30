import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'exceptions.dart';
import 'logger.dart';

/// A store that manages the underlying SharedPreferences with caching.
///
/// This class provides a centralized, cached interface to SharedPreferences,
/// eliminating the need for repeated async calls during normal operation.
/// The store initializes asynchronously but provides synchronous access
/// once ready, improving performance for frequent setting access.
///
/// The store is used internally by the settings framework and typically
/// doesn't need to be accessed directly by application code.
///
/// In test environments, it automatically falls back to regular SharedPreferences
/// to ensure compatibility with test mocking frameworks.
///
/// Example internal usage:
/// ```dart
/// final store = SettingsStore();
/// await store.readyFuture; // Wait for initialization
/// bool value = store.prefs.getBool('some.key') ?? false;
/// ```
class SettingsStore {
  static final _logger = EspLogger.forComponent('SettingsStore');

  /// Internal flag tracking whether the store is ready for use.
  bool _ready = false;

  /// Public getter indicating if the store has been initialized and is ready.
  /// When true, the [prefs] getter can be used synchronously.
  bool get ready => _ready;

  /// Future that completes when the store is fully initialized.
  /// Await this future before accessing settings to ensure proper initialization.
  late final Future<bool> readyFuture;

  /// Creates a new SettingsStore instance.
  /// Each instance manages its own SharedPreferences connection.
  SettingsStore({bool forceRegularSharedPreferences = false}) {
    _initializeStore(forceRegularSharedPreferences);
  }

  /// The SharedPreferences instance (cached or regular depending on environment).
  /// Only accessible after initialization is complete.
  late final dynamic _prefs;

  /// Whether we're using the cached version or regular SharedPreferences.
  bool _isUsingCache = true;

  /// Initializes SharedPreferences.
  ///
  /// In debug mode or when [forceRegularSharedPreferences] is true, uses regular
  /// SharedPreferences for better test compatibility. In release mode, uses
  /// SharedPreferencesWithCache for better performance.
  ///
  /// This method:
  /// 1. Creates a completer for the ready future
  /// 2. Chooses appropriate SharedPreferences implementation based on environment
  /// 3. Sets up success and error handling with proper logging
  /// 4. Marks the store as ready when initialization completes
  void _initializeStore(bool forceRegularSharedPreferences) {
    final completer = Completer<bool>();
    readyFuture = completer.future;

    // In debug mode or when forced, use regular SharedPreferences for better test compatibility
    // In release mode, use SharedPreferencesWithCache for better performance
    final useRegularSharedPreferences =
        forceRegularSharedPreferences || kDebugMode;

    _logger.info(
        'Initializing SettingsStore (regular: $useRegularSharedPreferences)');

    if (useRegularSharedPreferences) {
      _isUsingCache = false;
      _logger.fine('Using regular SharedPreferences');
      SharedPreferences.getInstance().then((prefs) {
        _prefs = prefs;
        _ready = true;
        _logger.info(
            'SettingsStore initialized successfully with regular SharedPreferences');
        completer.complete(true);
      }).catchError((error) {
        _ready = false;
        _logger.severe('Failed to initialize SharedPreferences', error);
        completer.completeError(error);
        throw Exception('Failed to initialize SharedPreferences: $error');
      });
    } else {
      _isUsingCache = true;
      _logger.fine('Attempting to use SharedPreferencesWithCache');
      SharedPreferencesWithCache.create(
        cacheOptions: const SharedPreferencesWithCacheOptions(),
      ).then((prefs) {
        _prefs = prefs;
        _ready = true;
        _logger.info(
            'SettingsStore initialized successfully with SharedPreferencesWithCache');
        completer.complete(true);
      }).catchError((error) {
        // If SharedPreferencesWithCache fails, fall back to regular SharedPreferences
        _logger.warning(
            'SharedPreferencesWithCache failed, falling back to regular SharedPreferences',
            error);
        _isUsingCache = false;
        SharedPreferences.getInstance().then((fallbackPrefs) {
          _prefs = fallbackPrefs;
          _ready = true;
          _logger.info(
              'SettingsStore initialized successfully with fallback SharedPreferences');
          completer.complete(true);
        }).catchError((fallbackError) {
          _ready = false;
          _logger.severe(
              'Failed to initialize any SharedPreferences implementation',
              fallbackError);
          completer.completeError(fallbackError);
          throw Exception(
            'Failed to initialize any SharedPreferences: $fallbackError',
          );
        });
      });
    }
  }

  /// Provides access to the SharedPreferences instance.
  ///
  /// This getter should only be called after the store is ready.
  /// Use [ready] to check readiness or await [readyFuture] to ensure
  /// the store is initialized before accessing this property.
  ///
  /// Returns either SharedPreferencesWithCache (production) or
  /// SharedPreferences (test environment) depending on initialization.
  ///
  /// Throws: SettingsNotReadyException if accessed before initialization completes.
  dynamic get prefs {
    if (!_ready) {
      _logger
          .warning('Attempted to access prefs before SettingsStore was ready');
      throw SettingsNotReadyException(
        'SettingsStore is not ready. Please await readyFuture first.',
      );
    }
    return _prefs;
  }

  /// Disposes of the store and releases resources.
  ///
  /// This should be called when the store is no longer needed to prevent
  /// memory leaks. After calling dispose, the store should not be used.
  void dispose() {
    _logger.fine('Disposing SettingsStore');
    _ready = false;
    // Note: SharedPreferences instances don't need explicit disposal
    // but we mark the store as not ready to prevent further use
  }

  /// Returns true if using SharedPreferencesWithCache, false if using regular SharedPreferences.
  bool get isUsingCache => _isUsingCache;
}
