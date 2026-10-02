import 'package:flutter/foundation.dart';
import 'package:stratum_ui/src/themes/constant/window_size.dart';

/// A theme value that may differ per [WindowSize].
///
/// `theme.yaml` writes one value for every window size (`md: 16`) or a map
/// of the window sizes it names (`md: { mobile: 16, desktop: 32 }`).
///
/// Two instances are equal when they give the same value on every window
/// size, so `.all(8)` equals a map that names all five sizes with 8.
@immutable
class StratumByWindowSize<T> {
  /// The entries a `theme.yaml` map wrote; asserts [values] is not empty.
  new(Map<WindowSize, T> values)
    : assert(values.isNotEmpty, 'A window-size map needs at least one entry.'),
      _all = null,
      _values = Map.unmodifiable(values);

  /// One value for every window size: a scalar token in `theme.yaml`.
  const new all(T value) : this._(value, null);

  const new _(this._all, this._values);

  final T? _all;
  final Map<WindowSize, T>? _values;

  /// [size]'s own entry; else the entry of the nearest smaller window size
  /// that has one; else the entry of the smallest window size that has one
  /// (OQ11). `{mobile: 16, desktop: 32}` gives 16 on watch and tablet.
  T valueFor(WindowSize size) {
    final values = _values;
    if (values == null) return _all as T;
    for (var index = size.index; index >= 0; index--) {
      final candidate = WindowSize.values[index];
      if (values.containsKey(candidate)) return values[candidate] as T;
    }
    return values[WindowSize.values.firstWhere(values.containsKey)] as T;
  }

  @override
  bool operator ==(Object other) =>
      other is StratumByWindowSize<T> &&
      WindowSize.values.every((size) => other.valueFor(size) == valueFor(size));

  @override
  int get hashCode => Object.hashAll(WindowSize.values.map(valueFor));

  @override
  String toString() {
    final values = {
      for (final size in WindowSize.values) size.name: valueFor(size),
    };
    return 'StratumByWindowSize($values)';
  }
}
