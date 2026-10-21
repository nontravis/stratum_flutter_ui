import 'package:shared_preferences/shared_preferences.dart';
import 'package:stratum_ui/src/components/common/widget_settings/setting_key_codec.dart';
import 'package:stratum_ui/src/components/common/widget_settings/widget_setting_store.dart';

/// The default [StratumWidgetSettingStore], over `shared_preferences`'s
/// `SharedPreferencesAsync` (US-06 FR-01).
///
/// `shared_preferences` backs onto six platform stores: Android
/// `SharedPreferences`, iOS and macOS `NSUserDefaults`, Linux and Windows a
/// JSON settings file, and the web `window.localStorage`. A full web
/// storage quota refuses a write there; this store neither catches nor
/// reports that (PD12 is the controller's job).
final class StratumSharedPreferencesSettingStore
    implements StratumWidgetSettingStore {
  new();

  late final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  @override
  Future<Map<String, Object>> read(String prefix) async {
    final keys = await _preferences.getKeys();
    final kept = keys.where((key) => key.startsWith(prefix)).toSet();
    if (kept.isEmpty) return {};
    final values = await _preferences.getAll(allowList: kept);
    return {
      for (final entry in values.entries)
        if (entry.value != null) entry.key: entry.value!,
    };
  }

  @override
  Future<void> write(String key, Object value) async {
    if (!isSettingValue(value)) {
      throw ArgumentError.value(
        value,
        'value',
        'must be a bool, int, double, String, or List<String>',
      );
    }
    switch (value) {
      case final bool typed:
        await _preferences.setBool(key, typed);
      case final int typed:
        await _preferences.setInt(key, typed);
      case final double typed:
        await _preferences.setDouble(key, typed);
      case final String typed:
        await _preferences.setString(key, typed);
      case final List<String> typed:
        await _preferences.setStringList(key, typed);
    }
  }

  @override
  Future<void> remove(Set<String> keys) async {
    if (keys.isEmpty) return;
    await _preferences.clear(allowList: keys);
  }
}
