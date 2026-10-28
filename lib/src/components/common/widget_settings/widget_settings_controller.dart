import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:stratum_ui/src/components/common/widget_settings/setting_key_codec.dart';
import 'package:stratum_ui/src/components/common/widget_settings/shared_preferences_setting_store.dart';
import 'package:stratum_ui/src/components/common/widget_settings/widget_setting_box.dart';
import 'package:stratum_ui/src/components/common/widget_settings/widget_setting_store.dart';

/// Loads and holds the current user's widget settings, swappable store
/// included (US-02 FR-01, FR-03; US-03; US-05; US-06).
///
/// Starts over the device box (no signed-in user) with no values loaded.
/// [preload] or [load] must run before any reader calls [box]; a read
/// before that fails a debug assert. Every store call runs in call order
/// on one queue, so a reset after a write removes it (PD12); a failed
/// write or removal keeps the session's value and reports once through
/// [FlutterError.reportError], and a failed read at load yields an empty
/// box and one report (PD12). A write of a value equal to the cached one
/// neither notifies nor calls the store (PD13). A disposed controller
/// notifies nothing, whatever call reaches it, and a pending [switchUser]
/// swaps nothing either (US-04 FR-01, FR-02).
final class StratumWidgetSettingsController extends ChangeNotifier {
  new({StratumWidgetSettingStore? store})
    : _store = store ?? StratumSharedPreferencesSettingStore();

  static const String _notLoadedMessage =
      'StratumWidgetSettingsController was read before load: await '
      'StratumWidgetSettingsController.preload() before runApp, or place '
      'the reader under StratumApplication or StratumSplashScreen.';

  final StratumWidgetSettingStore _store;
  final Map<String, Object> _cache = {};
  Future<void> _queueTail = Future<void>.value();
  Future<void>? _loading;
  bool _isLoaded = false;
  bool _isDisposed = false;
  String? _userId;
  Set<String>? _changedKeys;
  int _switchToken = 0;

  /// Makes a controller and awaits its [load] before returning it.
  static Future<StratumWidgetSettingsController> preload({
    StratumWidgetSettingStore? store,
  }) async {
    final controller = StratumWidgetSettingsController(store: store);
    await controller.load();
    return controller;
  }

  /// Whether [load] has run, successfully or not.
  bool get isLoaded => _isLoaded;

  /// The signed-in user's id, else null for the device box.
  String? get userId => _userId;

  /// The logical keys the last notify changed; null means every key.
  @internal
  Set<String>? get changedKeys => _changedKeys;

  /// Reads the current slot's keys once; later calls are a no-op.
  ///
  /// Memoizes the first call, so a second call made before the first ends
  /// awaits that same read instead of starting its own, which would
  /// otherwise land after and revert a write made in between (US-03
  /// FR-01). A read the store refuses yields an empty cache and one
  /// report, so the app starts with every default (PD12). A controller
  /// disposed while the read is pending caches nothing from it.
  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    final prefix = userSettingPrefix(_userId);
    try {
      final values = await _queue(() => _store.read(prefix));
      if (!_isDisposed) {
        _cache.addEntries(
          values.entries.map(
            (entry) => MapEntry(
              entry.key.substring(prefix.length),
              _cacheable(entry.value),
            ),
          ),
        );
      }
    } on Object catch (error, stack) {
      _report(error, stack, 'while loading the widget settings');
    }
    _isLoaded = true;
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  /// The box [namespace] reads and writes through, with no scope
  /// dependency tracking.
  StratumWidgetSettingBox box(String namespace) =>
      StratumWidgetSettingBox(this, namespace);

  /// The cached value under [logicalKey], else null.
  ///
  /// Asserts [isLoaded]; a release build reads null before load.
  @internal
  Object? valueOf(String logicalKey) {
    assert(isLoaded, _notLoadedMessage);
    if (!isLoaded) return null;
    return _cache[logicalKey];
  }

  /// Stores [value] under [logicalKey], null removing it.
  ///
  /// A no-op when [value] equals the cached value (PD13). Updates the
  /// cache and notifies before the store call, unless disposed; the store
  /// call runs on the queue and never throws (PD12). Caches a list by an
  /// unmodifiable copy, so a caller's later mutation of its own list never
  /// reaches the cache (US-02 FR-03). Asserts [isLoaded]; a release build
  /// is a no-op before load.
  @internal
  Future<void> write(String logicalKey, Object? value) async {
    assert(isLoaded, _notLoadedMessage);
    if (!isLoaded) return;
    if (_sameValue(_cache[logicalKey], value)) return;
    if (!_isDisposed) {
      if (value == null) {
        _cache.remove(logicalKey);
      } else {
        _cache[logicalKey] = _cacheable(value);
      }
      _notifyChanged({logicalKey});
    }
    final storageKey = storageSettingKey(_userId, logicalKey);
    try {
      await _queue(
        () => value == null
            ? _store.remove({storageKey})
            : _store.write(storageKey, value),
      );
    } on Object catch (error, stack) {
      _report(error, stack, 'while saving a widget setting');
    }
  }

  /// Resets every value under [namespace]'s [id] part.
  Future<void> resetId(String namespace, String id) =>
      _reset(logicalIdPrefix(namespace, id));

  /// Resets every value of [namespace], every id part included.
  Future<void> resetType(String namespace) =>
      _reset(logicalNamespacePrefix(namespace));

  /// Resets every value of the current slot.
  Future<void> resetAll() => _reset('');

  /// Switches to [userId]'s box, or the device box for null (US-04 FR-01).
  ///
  /// Awaits [load] first. Loads the new box through the store queue while
  /// every reader keeps the shown box, then swaps the cache and [userId]
  /// and notifies once; each call takes the next token, and only the
  /// latest token's load swaps, so of two quick switches the last one
  /// wins and the earlier load is dropped. A switch to the current user
  /// reads nothing and drops a pending switch. A write made before the
  /// swap goes to the user shown when it was made (s03 INV-7). A
  /// read the store refuses swaps to an empty box with one report.
  Future<void> switchUser(String? userId) async {
    await load();
    final token = ++_switchToken;
    if (userId == _userId) return;
    final prefix = userSettingPrefix(userId);
    var values = const <String, Object>{};
    try {
      values = await _queue(() => _store.read(prefix));
    } on Object catch (error, stack) {
      _report(error, stack, 'while switching the widget settings user');
    }
    if (_isDisposed || token != _switchToken) return;
    _cache
      ..clear()
      ..addEntries(
        values.entries.map(
          (entry) => MapEntry(
            entry.key.substring(prefix.length),
            _cacheable(entry.value),
          ),
        ),
      );
    _userId = userId;
    _notifyChanged(null);
  }

  /// Clears every stored setting of [userId] (US-04 FR-02).
  ///
  /// Removes every storage key a store read finds under that user's
  /// prefix, leaving the device box and every other user's keys in place.
  /// For the current user it also clears the shown cache and notifies
  /// once with the keys it held, unless disposed, in which case it clears
  /// and notifies nothing.
  Future<void> clearUser(String userId) async {
    final prefix = userSettingPrefix(userId);
    if (userId == _userId && !_isDisposed) {
      final cleared = _cache.keys.toSet();
      _cache.clear();
      _notifyChanged(cleared);
    }
    try {
      await _queue(() async {
        final stored = await _store.read(prefix);
        if (stored.isNotEmpty) await _store.remove(stored.keys.toSet());
      });
    } on Object catch (error, stack) {
      _report(error, stack, 'while clearing a widget settings user');
    }
  }

  /// Drops the cached keys under [logicalPrefix], notifies with exactly
  /// those, then queues removal of every storage key under the prefix the
  /// cache or a store read holds (s03 INV-8); unless disposed, which
  /// drops and notifies nothing but still queues the removal.
  Future<void> _reset(String logicalPrefix) async {
    assert(isLoaded, _notLoadedMessage);
    if (!isLoaded) return;
    final removed = {
      for (final key in _cache.keys)
        if (key.startsWith(logicalPrefix)) key,
    };
    if (!_isDisposed) {
      _cache.removeWhere((key, _) => removed.contains(key));
      _notifyChanged(removed);
    }
    final userId = _userId;
    final storagePrefix = storageSettingKey(userId, logicalPrefix);
    try {
      await _queue(() async {
        final discovered = await _store.read(storagePrefix);
        final storageKeys = {
          for (final key in removed) storageSettingKey(userId, key),
          ...discovered.keys,
        };
        if (storageKeys.isNotEmpty) await _store.remove(storageKeys);
      });
    } on Object catch (error, stack) {
      _report(error, stack, 'while resetting the widget settings');
    }
  }

  /// Sets [changedKeys] to [keys] and notifies once; the one gate every
  /// mutating call routes its notify through, so a disposed controller
  /// notifies nothing (PD12, s03 INV-7).
  void _notifyChanged(Set<String>? keys) {
    if (_isDisposed) return;
    _changedKeys = keys;
    notifyListeners();
  }

  /// Whether [a] and [b], the cached and the written value, are equal; a
  /// list compares by [listEquals] (PD13).
  bool _sameValue(Object? a, Object? b) {
    if (a is List<String> && b is List<String>) return listEquals(a, b);
    return a == b;
  }

  /// The value the cache keeps for [value]: an unmodifiable copy for a
  /// list, so neither a caller's nor the store's own list instance is
  /// ever the cache's (US-02 FR-03).
  Object _cacheable(Object value) =>
      value is List<String> ? List<String>.unmodifiable(value) : value;

  /// Chains [action] after every earlier call on the store, in call order,
  /// so a reset after a write removes it (PD12); never leaves the queue
  /// rejected, whatever [action] throws.
  Future<T> _queue<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _queueTail = _queueTail.then((_) async {
      try {
        completer.complete(await action());
      } on Object catch (error, stack) {
        completer.completeError(error, stack);
      }
    });
    return completer.future;
  }

  /// Reports [error] once through [FlutterError.reportError], named with
  /// [context] and the package library.
  void _report(Object error, StackTrace stack, String context) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'stratum_ui',
        context: ErrorDescription(context),
      ),
    );
  }
}
