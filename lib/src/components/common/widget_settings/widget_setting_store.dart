import 'dart:collection';

import 'package:stratum_ui/src/components/common/widget_settings/setting_key_codec.dart';

/// The swappable store contract a widget setting controller reads and writes
/// (US-06).
///
/// Every method takes and returns exact storage keys (PD2), never a logical
/// key; the controller builds and interprets them.
abstract interface class StratumWidgetSettingStore {
  /// Returns every stored entry whose key starts with [prefix].
  Future<Map<String, Object>> read(String prefix);

  /// Stores [value] under [key].
  ///
  /// Throws an [ArgumentError] when [value] is not one of the five storable
  /// types (PD3).
  Future<void> write(String key, Object value);

  /// Removes only the entries under [keys].
  Future<void> remove(Set<String> keys);
}

/// The in-memory store a Developer passes in place of the default store, such
/// as in a widget test (US-06 FR-02).
///
/// Starts from a copy of the [values] it is given and keeps them only while
/// it lives.
final class StratumMemorySettingStore implements StratumWidgetSettingStore {
  new({Map<String, Object> values = const {}})
    : _values = Map<String, Object>.of(values);

  final Map<String, Object> _values;

  /// An unmodifiable view of the stored values.
  Map<String, Object> get values => UnmodifiableMapView(_values);

  @override
  Future<Map<String, Object>> read(String prefix) async => {
    for (final entry in _values.entries)
      if (entry.key.startsWith(prefix)) entry.key: entry.value,
  };

  @override
  Future<void> write(String key, Object value) async {
    if (!isSettingValue(value)) {
      throw ArgumentError.value(
        value,
        'value',
        'must be a bool, int, double, String, or List<String>',
      );
    }
    _values[key] = value;
  }

  @override
  Future<void> remove(Set<String> keys) async {
    _values.removeWhere((key, _) => keys.contains(key));
  }
}
