import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'perf_kit.dart';

/// Untraced pause after S5's block before the next run, so the blur's
/// after-effects stay out of the next run's first traces (spec section 9.4).
const coolDownTime = Duration(seconds: 2);

/// The scene after whose block the app cools down: S5 (blur).
const coolDownScene = 'S5';

/// The null control, which runs [nullBlocks] blocks in every run.
const nullScene = 'S2-plain';

/// S2-plain's blocks per run: at the start, before the first of
/// [middleScenes], and at the end, after S5's cool-down, so the null gate
/// sees drift across the whole run (phase 5 design, section 8.4).
const nullBlocks = 3;

/// The scenes before the first of which S2-plain's middle block runs.
const middleScenes = {'S3', 'S4', 'S5'};

/// One benchmark scene: what it draws and how a trace drives it
/// (spec section 9.2).
class PerfScene {
  const new(this.key, {required this.build, required this.drive, this.check});

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

/// One test of the invocation: a scene on one side, traced in a run or
/// drawn untraced as warm-up.
class PerfStep {
  const new(
    this.scene, {
    required this.baseline,
    this.run,
    this.pair,
    this.startsRun = false,
    this.coolDown = false,
  });

  /// The scene this step draws.
  final PerfScene scene;

  /// Whether the step draws with the frozen baseline.
  final bool baseline;

  /// The run this step traces in; null for a warm-up step.
  final int? run;

  /// Pair number, 1 or 2 within the scene's block; S2-plain's blocks number
  /// their pairs on, 1 to 6. Null for a warm-up step.
  final int? pair;

  /// Whether the step is its run's first trace, before which the app prints
  /// the run line.
  final bool startsRun;

  /// Whether the app cools down for [coolDownTime] after the step's trace.
  final bool coolDown;

  /// Whether the step records a trace.
  bool get traced => pair != null;

  String get _side => baseline ? 'base' : 'cand';

  /// The report key `r<run>.<scene>.<side>.<pair>` (spec section 9.4).
  String get reportKey => 'r$run.${scene.key}.$_side.$pair';

  /// The test name: the report key, or `warm-up <scene>.<side>`.
  String get name => traced ? reportKey : 'warm-up ${scene.key}.$_side';
}

/// The steps of one invocation (spec section 9.4): an untraced warm-up of
/// every scene on both sides, then runs [first] to `first + count - 1`,
/// each one block per scene in [scenes]' order. A block runs baseline,
/// current, current, baseline, which yields one pair led by each side.
/// S2-plain, when listed, runs [nullBlocks] blocks per run: first, before
/// the first of [middleScenes] (else before its last block), and last,
/// with pairs 1 to 6. S5's block cools down before the next run, and in
/// every run when an S2-plain block follows it.
List<PerfStep> runSteps(
  List<PerfScene> scenes, {
  required int first,
  required int count,
}) {
  final last = first + count - 1;
  final order = _blockOrder(scenes);
  final hasNull = scenes.any((scene) => scene.key == nullScene);
  return [
    for (final scene in scenes) ...[
      PerfStep(scene, baseline: true),
      PerfStep(scene, baseline: false),
    ],
    for (var run = first; run <= last; run++)
      for (final (index, (scene, block)) in order.indexed) ...[
        PerfStep(
          scene,
          baseline: true,
          run: run,
          pair: 2 * block - 1,
          startsRun: index == 0,
        ),
        PerfStep(scene, baseline: false, run: run, pair: 2 * block - 1),
        PerfStep(scene, baseline: false, run: run, pair: 2 * block),
        PerfStep(
          scene,
          baseline: true,
          run: run,
          pair: 2 * block,
          coolDown: scene.key == coolDownScene && (hasNull || run < last),
        ),
      ],
  ];
}

/// The blocks of one run: each scene with its block number, 1 for every
/// scene but S2-plain, whose [nullBlocks] blocks take 1 to 3.
List<(PerfScene, int)> _blockOrder(List<PerfScene> scenes) {
  final nulls = scenes.where((scene) => scene.key == nullScene);
  final others = [
    for (final scene in scenes)
      if (scene.key != nullScene) (scene, 1),
  ];
  if (nulls.isEmpty) return others;
  final control = nulls.first;
  final middle = others.indexWhere(
    (entry) => middleScenes.contains(entry.$1.key),
  );
  return [
    (control, 1),
    ...others.take(middle < 0 ? others.length : middle),
    (control, 2),
    ...others.skip(middle < 0 ? others.length : middle),
    (control, nullBlocks),
  ];
}
