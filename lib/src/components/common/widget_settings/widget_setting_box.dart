import 'package:meta/meta.dart';
import 'package:stratum_ui/src/components/common/model/widget_setting/widget_setting_key.dart';
import 'package:stratum_ui/src/components/common/widget_settings/setting_key_codec.dart';
import 'package:stratum_ui/src/components/common/widget_settings/widget_settings_controller.dart';

/// One widget type's settings, reached by its fixed [namespace] (US-02
/// FR-01).
final class StratumWidgetSettingBox {
  @internal
  new(this._controller, this.namespace, {this.onRead});

  final StratumWidgetSettingsController? _controller;

  /// The widget type's fixed, package-prefixed namespace.
  final String namespace;

  /// Called with the logical key of every get made through this box,
  /// before the controller's cache (US-02 FR-04).
  final void Function(String logicalKey)? onRead;

  /// The part every instance of the widget type shares.
  StratumWidgetSettingPart get global => part(const WidgetSettingKey.global());

  /// The part shared by every instance with this [id].
  StratumWidgetSettingPart id(String id) => part(WidgetSettingKey.id(id));

  /// The part [key] names, the global part or an id.
  StratumWidgetSettingPart part(WidgetSettingKey key) =>
      StratumWidgetSettingPart(_controller, namespace, key, onRead: onRead);
}

/// The typed reads and writes of one box part (US-02 FR-03).
///
/// Over a null controller every get is null and every set does nothing.
final class StratumWidgetSettingPart {
  @internal
  new(this._controller, this._namespace, this._key, {this.onRead});

  final StratumWidgetSettingsController? _controller;
  final String _namespace;
  final WidgetSettingKey _key;
  final void Function(String logicalKey)? onRead;

  /// The stored yes-or-no value under [name], else null.
  bool? getBool(String name) => _read<bool>(name);

  /// The stored whole number under [name], else null.
  int? getInt(String name) => _read<int>(name);

  /// The stored number under [name] as a double, else null.
  ///
  /// Reads a stored whole number as that number, since the web keeps
  /// every number as one number type (PD5).
  double? getDouble(String name) => _read<num>(name)?.toDouble();

  /// The stored text under [name], else null.
  String? getString(String name) => _read<String>(name);

  /// The stored list of text under [name], else null.
  ///
  /// The list is unmodifiable: copy it before adding or removing an entry.
  List<String>? getStringList(String name) => _read<List<String>>(name);

  /// Stores [value] as [name]'s yes-or-no value.
  Future<void> setBool(String name, bool value) => _write(name, value);

  /// Stores [value] as [name]'s whole number.
  Future<void> setInt(String name, int value) => _write(name, value);

  /// Stores [value] as [name]'s number.
  Future<void> setDouble(String name, double value) => _write(name, value);

  /// Stores [value] as [name]'s text.
  Future<void> setString(String name, String value) => _write(name, value);

  /// Stores [value] as [name]'s list of text.
  Future<void> setStringList(String name, List<String> value) =>
      _write(name, value);

  /// Removes the stored value under [name].
  Future<void> remove(String name) => _write(name, null);

  String _logicalKey(String name) => logicalSettingKey(_namespace, _key, name);

  T? _read<T>(String name) {
    final logicalKey = _logicalKey(name);
    onRead?.call(logicalKey);
    final value = _controller?.valueOf(logicalKey);
    return value is T ? value : null;
  }

  Future<void> _write(String name, Object? value) {
    final controller = _controller;
    if (controller == null) return Future<void>.value();
    return controller.write(_logicalKey(name), value);
  }
}
