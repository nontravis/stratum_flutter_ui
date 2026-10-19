import 'package:stratum_ui/src/components/common/model/widget_setting/widget_setting_key.dart';

/// The fixed literal prefix of every storage key (PD2), stable across a
/// minified or obfuscated build.
const String settingKeyPrefix = 'stratum';

/// Builds the logical key for [name] inside [namespace]'s [key] part.
///
/// The logical key omits the user slot; combine it with [userSettingPrefix]
/// through [storageSettingKey]. Each segment passes through
/// [Uri.encodeComponent] so a `/` or `%` inside it cannot collide with the
/// separator (PD2).
String logicalSettingKey(String namespace, WidgetSettingKey key, String name) {
  final encodedName = _encodeSegment(name, 'name');
  return switch (key) {
    WidgetSettingGlobal() =>
      '${logicalNamespacePrefix(namespace)}g/$encodedName',
    WidgetSettingId(:final id) =>
      '${logicalIdPrefix(namespace, id)}$encodedName',
  };
}

/// The logical-key prefix shared by every part of [namespace].
String logicalNamespacePrefix(String namespace) =>
    '${_encodeSegment(namespace, 'namespace')}/';

/// The logical-key prefix shared by every value of [namespace]'s [id] part.
String logicalIdPrefix(String namespace, String id) =>
    '${logicalNamespacePrefix(namespace)}i/${_encodeSegment(id, 'id')}/';

/// The storage-key prefix for [userId]'s slot: the device box when null.
String userSettingPrefix(String? userId) => userId == null
    ? '$settingKeyPrefix/d/'
    : '$settingKeyPrefix/u/${_encodeSegment(userId, 'userId')}/';

/// Combines [userId]'s slot with [logicalKey] into the full storage key.
String storageSettingKey(String? userId, String logicalKey) =>
    '${userSettingPrefix(userId)}$logicalKey';

/// Whether [value] is one of the five types a setting part stores (PD3).
bool isSettingValue(Object value) => switch (value) {
  bool() || int() || double() || String() => true,
  List<String>() => true,
  _ => false,
};

/// Encodes one key segment, asserting it is non-empty.
String _encodeSegment(String segment, String argumentName) {
  assert(segment.isNotEmpty, '$argumentName must not be empty');
  return Uri.encodeComponent(segment);
}
