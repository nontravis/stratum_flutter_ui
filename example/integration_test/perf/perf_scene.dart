import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'perf_kit.dart';

/// One benchmark scene: what it draws and how a trace drives it
/// (spec section 9.2).
class PerfScene {
  const new(
    this.key, {
    required this.build,
    required this.drive,
    this.check,
  });

  /// The scene's name in the spec's table and the report key's prefix.
  final String key;

  /// Builds the scene with one side's layouts.
  final Widget Function(PerfKit kit) build;

  /// Drives the pumped scene for one traced window.
  final Future<void> Function(WidgetTester tester) drive;

  /// Checks a precondition after the scene is pumped; may pump other
  /// widgets, and leaves the scene pumped.
  final Future<void> Function(WidgetTester tester, PerfKit kit)? check;
}
