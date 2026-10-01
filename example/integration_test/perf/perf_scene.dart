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

/// One test of an invocation: a scene on one side, traced or as warm-up.
class PerfStep {
  const new(this.scene, {required this.baseline, this.pair});

  /// The scene this step draws.
  final PerfScene scene;

  /// Whether the step draws with the frozen baseline.
  final bool baseline;

  /// Pair number within the scene's block, 1 or 2; null for a warm-up step.
  final int? pair;

  /// Whether the step records a trace.
  bool get traced => pair != null;

  String get _side => baseline ? 'base' : 'cand';

  /// The report key `<scene>.<side>.<pair>` (spec section 9.4).
  String get reportKey => '${scene.key}.$_side.$pair';

  /// The test name: the report key, or `warm-up <scene>.<side>`.
  String get name => traced ? reportKey : 'warm-up ${scene.key}.$_side';
}

/// The steps of one invocation (spec section 9.4): an untraced warm-up of
/// every scene on both sides, then one block per scene in the order
/// baseline, current, current, baseline, which yields one pair led by
/// each side.
List<PerfStep> abbaSteps(List<PerfScene> scenes) {
  return [
    for (final scene in scenes) ...[
      PerfStep(scene, baseline: true),
      PerfStep(scene, baseline: false),
    ],
    for (final scene in scenes) ...[
      PerfStep(scene, baseline: true, pair: 1),
      PerfStep(scene, baseline: false, pair: 1),
      PerfStep(scene, baseline: false, pair: 2),
      PerfStep(scene, baseline: true, pair: 2),
    ],
  ];
}
