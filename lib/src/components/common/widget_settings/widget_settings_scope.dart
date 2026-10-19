import 'package:flutter/widgets.dart';
import 'package:stratum_ui/src/components/common/widget_settings/widget_setting_box.dart';
import 'package:stratum_ui/src/components/common/widget_settings/widget_settings_controller.dart';

/// Publishes a [StratumWidgetSettingsController] to its descendants (US-02
/// FR-04; US-03 FR-01, FR-02; PD6).
///
/// Wraps [child] with no render effect of its own. A write, a reset, or a
/// user switch rebuilds only the descendants that read the logical key it
/// changed (RF4); a controller swap rebuilds every dependent once,
/// [maybeControllerOf] readers included.
class StratumWidgetSettings extends StatefulWidget {
  const new({super.key, required this.controller, required this.child});

  /// The controller every descendant reads and writes through.
  final StratumWidgetSettingsController controller;

  final Widget child;

  static const String _noScopeMessage =
      'No StratumWidgetSettings found above this context: place it under '
      'StratumApplication, StratumSplashScreen, or your own '
      'StratumWidgetSettings.';

  /// The box [namespace] reads and writes through; each get depends on its
  /// own logical key, so a write rebuilds only the readers of that key
  /// (US-02 FR-04).
  ///
  /// Debug-asserts a [StratumWidgetSettings] is above; a release build
  /// reads a box over a null controller.
  static StratumWidgetSettingBox of(
    BuildContext context, {
    required String namespace,
  }) {
    final scope = context.getInheritedWidgetOfExactType<_WidgetSettingsScope>();
    assert(scope != null, _noScopeMessage);
    return StratumWidgetSettingBox(
      scope?.controller,
      namespace,
      onRead: (logicalKey) => InheritedModel.inheritFrom<_WidgetSettingsScope>(
        context,
        aspect: logicalKey,
      ),
    );
  }

  /// The nearest [StratumWidgetSettingsController] above [context].
  ///
  /// Depends on the controller instance only: the caller rebuilds when a
  /// [StratumWidgetSettings] above swaps its controller, never on a write
  /// or a user switch.
  static StratumWidgetSettingsController controllerOf(BuildContext context) {
    final controller = maybeControllerOf(context);
    if (controller != null) return controller;
    throw FlutterError(
      'StratumWidgetSettings.controllerOf() was called with a context that '
      'has no StratumWidgetSettings above it.\n'
      'Call it from a widget inside a StratumWidgetSettings scope.',
    );
  }

  /// The nearest [StratumWidgetSettingsController] above [context], else
  /// null.
  ///
  /// Depends on the controller instance only, as [controllerOf].
  static StratumWidgetSettingsController? maybeControllerOf(
    BuildContext context,
  ) => InheritedModel.inheritFrom<_WidgetSettingsScope>(
    context,
    aspect: '',
  )?.controller;

  @override
  State<StratumWidgetSettings> createState() => _StratumWidgetSettingsState();
}

class _StratumWidgetSettingsState extends State<StratumWidgetSettings> {
  /// The logical keys a notify changed since the last build; null means
  /// every key (PD6).
  Set<String>? _pendingKeys = const <String>{};

  /// Bumped on every build that carries a pending change, so
  /// [_WidgetSettingsScope.updateShouldNotify] can tell two builds with an
  /// unchanged controller apart.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerNotify);
  }

  @override
  void didUpdateWidget(StratumWidgetSettings oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_onControllerNotify);
      widget.controller.addListener(_onControllerNotify);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerNotify);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pending = _pendingKeys;
    if (pending == null || pending.isNotEmpty) _generation++;
    final scope = _WidgetSettingsScope(
      controller: widget.controller,
      changedKeys: pending,
      generation: _generation,
      child: widget.child,
    );
    _pendingKeys = const <String>{};
    return scope;
  }

  /// Merges the controller's [StratumWidgetSettingsController.changedKeys]
  /// of this notify into the pending set; null absorbs, so one full
  /// invalidation stays full until the next build clears it (PD6).
  void _onControllerNotify() {
    final changed = widget.controller.changedKeys;
    final pending = _pendingKeys;
    setState(() {
      _pendingKeys = pending == null || changed == null
          ? null
          : {...pending, ...changed};
    });
  }
}

/// The fields of [_StratumWidgetSettingsState]'s build, one dependency
/// aspect per logical key, plus `''` for the controller instance (PD6).
class _WidgetSettingsScope extends InheritedModel<String> {
  const new({
    required this.controller,
    required this.changedKeys,
    required this.generation,
    required super.child,
  });

  final StratumWidgetSettingsController controller;

  /// The logical keys this build's notifies changed; null means every key.
  final Set<String>? changedKeys;

  /// Bumped on every build that carries a pending change (PD6).
  final int generation;

  @override
  bool updateShouldNotify(_WidgetSettingsScope oldWidget) =>
      controller != oldWidget.controller || generation != oldWidget.generation;

  @override
  bool updateShouldNotifyDependent(
    _WidgetSettingsScope oldWidget,
    Set<String> dependencies,
  ) {
    if (controller != oldWidget.controller) return true;
    final keys = changedKeys;
    return dependencies.any(
      (aspect) => aspect.isNotEmpty && (keys == null || keys.contains(aspect)),
    );
  }
}
