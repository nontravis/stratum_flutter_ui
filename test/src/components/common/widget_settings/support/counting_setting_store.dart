import 'dart:async';

import 'package:stratum_ui/src/components/common/widget_settings/widget_setting_store.dart';

/// A counting, failure-injecting [StratumWidgetSettingStore] for tests.
///
/// Wraps a [StratumMemorySettingStore] seeded with [values]; later tasks
/// drive the controller's call-order queue and failure reporting through it.
final class CountingSettingStore implements StratumWidgetSettingStore {
  new([Map<String, Object> values = const {}])
    : _store = StratumMemorySettingStore(values: values);

  final StratumMemorySettingStore _store;
  final List<Completer<void>> _pendingHolds = [];

  /// The number of attempted reads; a failed call still counts, and a held
  /// read counts once released.
  int reads = 0;

  /// The number of attempted writes; a failed call still counts.
  int writes = 0;

  /// The number of attempted removals; a failed call still counts.
  int removes = 0;

  /// Whether the next read throws `StateError('read failed')`.
  bool failReads = false;

  /// Whether the next write throws `StateError('write failed')`.
  bool failWrites = false;

  /// Whether the next removal throws `StateError('remove failed')`.
  bool failRemoves = false;

  /// The stored values, as on the wrapped memory store.
  Map<String, Object> get values => _store.values;

  /// Holds the next read not yet held, in call order.
  ///
  /// Each call queues one more hold; a read awaits the oldest unresolved hold
  /// before it proceeds. Complete the returned [Completer] to release it.
  Completer<void> holdNextRead() {
    final hold = Completer<void>();
    _pendingHolds.add(hold);
    return hold;
  }

  @override
  Future<Map<String, Object>> read(String prefix) async {
    if (_pendingHolds.isNotEmpty) {
      await _pendingHolds.removeAt(0).future;
    }
    reads++;
    if (failReads) throw StateError('read failed');
    return _store.read(prefix);
  }

  @override
  Future<void> write(String key, Object value) async {
    writes++;
    if (failWrites) throw StateError('write failed');
    return _store.write(key, value);
  }

  @override
  Future<void> remove(Set<String> keys) async {
    removes++;
    if (failRemoves) throw StateError('remove failed');
    return _store.remove(keys);
  }
}
