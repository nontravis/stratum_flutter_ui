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
/// neither notifies nor calls the store (PD13).
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
  bool _isLoaded = false;
  String? _userId;
  Set<String>? _changedKeys;

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
  /// A read the store refuses yields an empty cache and one report, so the
  /// app starts with every default (PD12).
  Future<void> load() async {
    if (_isLoaded) return;
    final prefix = userSettingPrefix(_userId);
    try {
      final values = await _queue(() => _store.read(prefix));
      _cache.addEntries(
        values.entries.map(
          (entry) => MapEntry(entry.key.substring(prefix.length), entry.value),
        ),
      );
    } on Object catch (error, stack) {
      _report(error, stack, 'while loading the widget settings');
    }
    _isLoaded = true;
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
  /// cache and notifies before the store call, which runs on the queue and
  /// never throws (PD12). Asserts [isLoaded]; a release build is a no-op
  /// before load.
  @internal
  Future<void> write(String logicalKey, Object? value) async {
    assert(isLoaded, _notLoadedMessage);
    if (!isLoaded) return;
    if (_sameValue(_cache[logicalKey], value)) return;
    if (value == null) {
      _cache.remove(logicalKey);
    } else {
      _cache[logicalKey] = value;
    }
    _changedKeys = {logicalKey};
    notifyListeners();
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

  /// Drops the cached keys under [logicalPrefix], notifies with exactly
  /// those, then queues removal of every storage key under the prefix the
  /// cache or a store read holds (s03 invariant 8).
  Future<void> _reset(String logicalPrefix) async {
    assert(isLoaded, _notLoadedMessage);
    if (!isLoaded) return;
    final removed = {
      for (final key in _cache.keys)
        if (key.startsWith(logicalPrefix)) key,
    };
    _cache.removeWhere((key, _) => removed.contains(key));
    _changedKeys = removed;
    notifyListeners();
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

  /// Whether [a] and [b], the cached and the written value, are equal; a
  /// list compares by [listEquals] (PD13).
  bool _sameValue(Object? a, Object? b) {
    if (a is List<String> && b is List<String>) return listEquals(a, b);
    return a == b;
  }

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
