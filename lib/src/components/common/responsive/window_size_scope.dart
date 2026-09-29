import 'package:flutter/widgets.dart';
import 'package:stratum_ui/src/themes/model/window_size.dart';

/// Publishes the [WindowSize] of the app window to its descendants.
///
/// Place it once near the root, e.g.
/// `MaterialApp(builder: (context, child) => WindowSizeScope(child: child!))`.
/// Dependents rebuild only when the width crosses a breakpoint, not on every
/// pixel of a window resize.
class WindowSizeScope extends StatelessWidget {
  const new({required this.child, super.key});

  final Widget child;

  static WindowSize of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_WindowSizeInherited>();
    if (scope == null) {
      throw FlutterError(
        'No WindowSizeScope found in context.\n'
        'Wrap the app with WindowSizeScope, e.g. '
        'MaterialApp(builder: (context, child) => '
        'WindowSizeScope(child: child!)).',
      );
    }
    return scope.windowSize;
  }

  @override
  Widget build(BuildContext context) => _WindowSizeInherited(
    windowSize: WindowSize.fromWidth(MediaQuery.widthOf(context)),
    child: child,
  );
}

class _WindowSizeInherited extends InheritedWidget {
  const new({required this.windowSize, required super.child});

  final WindowSize windowSize;

  @override
  bool updateShouldNotify(_WindowSizeInherited oldWidget) =>
      windowSize != oldWidget.windowSize;
}
