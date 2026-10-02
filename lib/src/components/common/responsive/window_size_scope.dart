import 'package:flutter/widgets.dart';
import 'package:stratum_ui/src/themes/constant/window_size.dart';

/// Publishes the [WindowSize] of the app window to its descendants.
///
/// Place it once near the root, e.g.
/// `MaterialApp(builder: (context, child) => WindowSizeScope(child: child!))`.
/// Dependents rebuild only when the window crosses a breakpoint, not on every
/// pixel of a window resize or when a phone rotates.
class WindowSizeScope extends StatelessWidget {
  const new({required this.child, super.key});

  final Widget child;

  static WindowSize of(BuildContext context) {
    final windowSize = maybeOf(context);
    if (windowSize == null) {
      throw FlutterError(
        'No WindowSizeScope found in context.\n'
        'Wrap the app with WindowSizeScope, e.g. '
        'MaterialApp(builder: (context, child) => '
        'WindowSizeScope(child: child!)).',
      );
    }
    return windowSize;
  }

  /// The [WindowSize] of the nearest [WindowSizeScope], or null when none is
  /// above [context].
  ///
  /// Registers the same dependency as [of]: the caller rebuilds only when
  /// the window crosses a breakpoint.
  static WindowSize? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_WindowSizeInherited>()
      ?.windowSize;

  @override
  Widget build(BuildContext context) => _WindowSizeInherited(
    windowSize: WindowSize.fromSize(MediaQuery.sizeOf(context)),
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
