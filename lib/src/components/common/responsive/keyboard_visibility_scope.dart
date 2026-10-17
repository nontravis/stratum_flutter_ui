import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';

/// Publishes whether the on-screen keyboard is open to its descendants.
///
/// - Place the scope once near the app root. Its position does not change
///   the value.
/// - `StratumThemeApplication` inserts one when none is above.
/// - On an Android or iOS host the value is the OS flag. It reads true even
///   while `context.deviceWindow.keyboardHeight` reads 0. It reads false in
///   Android's floating or split keyboard mode and with a hardware keyboard.
/// - On web, macOS, Windows, Linux, and the `flutter test` host the value is
///   `false`, and no platform channel opens.
/// - Dependents rebuild only on open or close.
class KeyboardVisibilityScope extends StatefulWidget {
  const new({required this.child, super.key});

  final Widget child;

  static final ValueNotifier<bool?> _forced = ValueNotifier<bool?>(null);

  // WORKAROUND: flutter_keyboard_visibility's method-channel default opens its
  // EventChannel on every host, so a dependent's first runAsync or golden test
  // in a file fails with MissingPluginException; remove when the package opens
  // its EventChannel only on Android and iOS hosts.
  static bool get _mobileHost =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static bool of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_KeyboardVisibilityInherited>();
    if (scope == null) {
      throw FlutterError(
        'No KeyboardVisibilityScope found in context.\n'
        'Wrap the app with KeyboardVisibilityScope, e.g. '
        'MaterialApp(builder: (context, child) => '
        'KeyboardVisibilityScope(child: child!)).',
      );
    }
    return scope.isVisible;
  }

  /// Whether a [KeyboardVisibilityScope] is above [context]; registers no
  /// dependency.
  static bool hasScope(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_KeyboardVisibilityInherited>() !=
      null;

  /// Forces the published value on every host.
  ///
  /// The forced value wins on every host. One `pump()` shows it on a mounted
  /// scope. It holds across tests until a test sets it again, so reset it
  /// with `false` in a tear-down. It is process-lifetime state: it also
  /// survives a hot reload, until a hot restart or relaunch.
  @visibleForTesting
  static void setVisibleForTesting(bool isVisible) => _forced.value = isVisible;

  @override
  State<KeyboardVisibilityScope> createState() =>
      _KeyboardVisibilityScopeState();
}

class _KeyboardVisibilityScopeState extends State<KeyboardVisibilityScope> {
  bool _osVisible = false;
  StreamSubscription<bool>? _osSubscription;

  @override
  void initState() {
    super.initState();
    KeyboardVisibilityScope._forced.addListener(_handleForcedChange);
    if (KeyboardVisibilityScope._mobileHost) {
      final controller = KeyboardVisibilityController();
      _osVisible = controller.isVisible;
      _osSubscription = controller.onChange.listen((isVisible) {
        if (!mounted) return;
        setState(() => _osVisible = isVisible);
      });
    }
  }

  void _handleForcedChange() => setState(() {});

  @override
  void dispose() {
    KeyboardVisibilityScope._forced.removeListener(_handleForcedChange);
    unawaited(_osSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _KeyboardVisibilityInherited(
    isVisible: KeyboardVisibilityScope._forced.value ?? _osVisible,
    child: widget.child,
  );
}

class _KeyboardVisibilityInherited extends InheritedWidget {
  const new({required this.isVisible, required super.child});

  final bool isVisible;

  @override
  bool updateShouldNotify(_KeyboardVisibilityInherited oldWidget) =>
      isVisible != oldWidget.isVisible;
}
