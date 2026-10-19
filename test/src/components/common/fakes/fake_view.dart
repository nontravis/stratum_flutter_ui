import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

/// A second window for a multi-view test, after Flutter's own `FakeView`
/// (`packages/flutter/test/widgets/multi_view_testing.dart`, Flutter
/// 3.47.3). It shares the platform dispatcher and the display of the
/// view it wraps, so its device pixel ratio follows that view's, and it
/// keeps a physical size of its own. It renders nothing and sends no
/// semantics to the engine, which watches the test's own view only.
class FakeView extends TestFlutterView {
  /// Wraps [view] as a window of its own, [viewId].
  new(FlutterView view, {this.viewId = 100})
    : super(
        view: view,
        platformDispatcher: view.platformDispatcher as TestPlatformDispatcher,
        display: view.display as TestDisplay,
      );

  @override
  final int viewId;

  /// Renders nothing: the engine renders the test view's scene alone.
  @override
  void render(Scene scene, {Size? size}) {}

  /// Sends nothing: the engine keeps the test view's semantics alone.
  @override
  void updateSemantics(SemanticsUpdate update) {}
}
