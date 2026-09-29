import 'package:flutter/widgets.dart';

/// Publishes whether the on-screen keyboard is open to its descendants.
///
/// Place it once near the root, above any `Scaffold`, e.g.
/// `MaterialApp(builder: (context, child) =>
/// KeyboardVisibilityScope(child: child!))`.
/// A `Scaffold` removes the bottom view inset from its body's [MediaQuery],
/// so a read below it would always see a closed keyboard. Dependents rebuild
/// only when the keyboard opens or closes, not on every animation frame.
class KeyboardVisibilityScope extends StatelessWidget {
  const new({required this.child, super.key});

  final Widget child;

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

  @override
  Widget build(BuildContext context) => _KeyboardVisibilityInherited(
    isVisible: MediaQuery.viewInsetsOf(context).bottom > 0,
    child: child,
  );
}

class _KeyboardVisibilityInherited extends InheritedWidget {
  const new({required this.isVisible, required super.child});

  final bool isVisible;

  @override
  bool updateShouldNotify(_KeyboardVisibilityInherited oldWidget) =>
      isVisible != oldWidget.isVisible;
}
