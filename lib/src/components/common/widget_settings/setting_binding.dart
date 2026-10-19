import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'package:stratum_ui/src/components/common/model/widget_setting/widget_setting_key.dart';
import 'package:stratum_ui/src/components/common/widget_settings/setting_key_codec.dart';
import 'package:stratum_ui/src/components/common/widget_settings/widget_settings_controller.dart';
import 'package:stratum_ui/src/components/common/widget_settings/widget_settings_scope.dart';

/// Binds a layout's named values to one key of the settings above it
/// (FO-10 US-01, PD7).
///
/// - [attach] and [rekey] run in the build phase, so they hand the stored
///   values back for a silent restore instead of pushing them.
/// - A later store change to one of its keys calls `onStored`, outside the
///   build phase. [save] does nothing meanwhile, and the notify its own
///   [save] causes calls nothing, so no write loop forms (M15).
@internal
final class WidgetSettingBinding {
  new({
    required String namespace,
    required List<String> names,
    required void Function(Map<String, Object?> stored) onStored,
  }) : _namespace = namespace,
       _names = names,
       _onStored = onStored;

  static const String _noScopeMessage =
      'A widget setting key needs a StratumWidgetSettings above: place the '
      'widget under StratumApplication, StratumSplashScreen, or your own '
      'StratumWidgetSettings.';

  final String _namespace;
  final List<String> _names;
  final void Function(Map<String, Object?> stored) _onStored;

  StratumWidgetSettingsController? _controller;
  WidgetSettingKey? _key;

  /// The logical key of each of [_names] under [_key], in order.
  List<String> _logicalKeys = const [];

  /// The controller this binding listens to: [_controller] while bound.
  StratumWidgetSettingsController? _listened;

  bool _pushing = false;
  bool _saving = false;

  /// Resolves the settings above [context] and binds [key], from
  /// `didChangeDependencies`.
  ///
  /// Returns the stored values when the controller or [key] changed and
  /// [key] is non-null, else null. Asserts a scope above a non-null [key].
  Map<String, Object?>? attach(BuildContext context, WidgetSettingKey? key) {
    final controller = StratumWidgetSettings.maybeControllerOf(context);
    assert(key == null || controller != null, _noScopeMessage);
    if (controller == _controller && key == _key) return null;
    _controller = controller;
    return _bind(key);
  }

  /// Binds [key] in place of the last one, from `didUpdateWidget`.
  ///
  /// Returns the stored values when [key] changed and is non-null, else
  /// null; a null [key] stops reading and saving.
  Map<String, Object?>? rekey(WidgetSettingKey? key) {
    if (key == _key) return null;
    assert(key == null || _controller != null, _noScopeMessage);
    return _bind(key);
  }

  /// The stored value of each name, null where none is stored or while
  /// unbound.
  Map<String, Object?> stored() {
    final controller = _controller;
    if (_key == null || controller == null) {
      return {for (final name in _names) name: null};
    }
    return {
      for (final (index, name) in _names.indexed)
        name: controller.valueOf(_logicalKeys[index]),
    };
  }

  /// Stores [value] as [name]'s value, null removing it.
  ///
  /// Does nothing while unbound or inside `onStored`, since a push is no
  /// settled change (M15).
  void save(String name, Object? value) {
    final controller = _controller;
    final key = _key;
    if (controller == null || key == null || _pushing) return;
    _saving = true;
    try {
      unawaited(
        controller.write(logicalSettingKey(_namespace, key, name), value),
      );
    } finally {
      _saving = false;
    }
  }

  /// Stops listening to the settings.
  void dispose() => _listen(null);

  /// Takes [key] and listens while bound; returns the stored values when
  /// bound, else null.
  Map<String, Object?>? _bind(WidgetSettingKey? key) {
    _key = key;
    _logicalKeys = key == null
        ? const []
        : [for (final name in _names) logicalSettingKey(_namespace, key, name)];
    final bound = key == null ? null : _controller;
    _listen(bound);
    return bound == null ? null : stored();
  }

  /// Moves the listener to [controller], none when null.
  void _listen(StratumWidgetSettingsController? controller) {
    if (controller == _listened) return;
    _listened?.removeListener(_onNotify);
    controller?.addListener(_onNotify);
    _listened = controller;
  }

  /// Pushes the stored values through `onStored` when a notify changed one
  /// of its keys or every key; a notify of its own [save] already holds
  /// the layout's value, so it pushes nothing.
  void _onNotify() {
    if (_saving) return;
    final changed = _listened?.changedKeys;
    if (changed != null && !_logicalKeys.any(changed.contains)) return;
    _pushing = true;
    try {
      _onStored(stored());
    } finally {
      _pushing = false;
    }
  }
}
