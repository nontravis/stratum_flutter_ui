# Benchmark in One App Run Implementation Plan

> **For agentic workers:** execute per the repository's execute rule; with none, run superpowers:subagent-driven-development in Dependency-table order. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Run a whole ABBA call in one build and one `flutter drive` launch. The app summarizes each two-second trace and prints it, and `perf_abba` writes each summary to disk as it arrives, so 12 runs take about 18 minutes instead of 35 with the same traces, blocks, and verdict rules.

**Architecture:** Task 1 changes the app side. The catalog becomes one list in run order, S2-plain first. `runSteps` builds the warm-up, one ABBA block per scene per run, and the 2 s cool-down after S5. A new `perf_trace.dart` summarizes each trace in the app with flutter_driver's `TimelineSummary`, prints `PERF_RUN` and `PERF_SUMMARY` lines, and drops the timeline. The entry point reads `PERF_FROM`, `PERF_RUNS`, `PERF_SCENES`, and `PERF_FULL` from dart-defines, and the driver only writes `--trace-full` timelines and waits up to an hour. Task 2 rewrites `perf_abba`: one build and one invocation per call, a stdout reader that writes `r<run>/` folders, the short-trace check, the escalation scene list, and `--trace-full`. Its verdict code stays unchanged apart from keys and folders. Task 3 rewrites layout spec sections 9.2, 9.4, and 9.5 from the design and runs a one-run dry run.

**Tech Stack:** Flutter 3.47.3, Dart ^3.13.3, `flutter_test`, `integration_test` and `flutter_driver` (SDK dev dependencies of `example/`), `flutter_lints` (example), macOS desktop in profile mode.

**Spec:** `docs/superpowers/specs/2026-10-02-benchmark-single-app-design.md` (approved by the owner 2026-10-02), which amends `docs/superpowers/specs/2026-10-01-layout-primitives-design.md` section 9 (9.2, 9.4, 9.5). Project memory: `profile/memory/project_stratum_ui_layout_primitives.md` in the NTD OS root, sections dated 2026-10-02. PRD user stories in scope: none (`docs/prds/` holds no benchmark story).

**Anchor base:** master d39aeb6.

**Preconditions:**
- From `example/`, `flutter test --no-pub test/` passes (78 tests) and `flutter analyze --no-pub integration_test test_driver tool test` reports `No issues found!` (verified on d7193f0 and on d39aeb6).
- The owner's work in progress is what `git status --short` shows (Global Constraints), and this plan stages none of it. The counts above hold for d39aeb6 without it; if it changes `lib/` or `example/`, rerun both commands first and shift the test counts the steps quote (84 and 99) by the difference from 78.
- Task 3 needs the macOS desktop with the test window visible for about 3 minutes.

This plan was verified in a scratch worktree on d7193f0 without the owner's work in progress, then reapplied to d39aeb6. Master moved during planning: d39aeb6 changes `focus_group.dart` and `scroll_frame.dart` in `lib/`, adds `example/lib/focus_demo.dart`, and edits layout spec section 6, which none of these steps touch. Two spikes came first (Task 3's section 12 edit records them). (a) The macOS profile app compiles with `package:flutter_driver/flutter_driver.dart` imported in the integration-test target. (b) One `flutter drive` forwarded a 2260-character `print` line and an 8000-character line uncut, each prefixed `flutter: `; the in-app summary took 22 ms. Every task's code compiled, each RED step failed as stated, and each GREEN step passed. After Task 3, the example suite passed 99 tests with `No issues found!`, and `lib/` was unchanged; on d39aeb6, every step's code and edit applied as written, with the same 99 tests and `No issues found!`, and the Step 5 grep found no old wording. The spikes and the dry run ran on d7193f0. The one-run dry run took 161 s with a warm build. A first build after new dart-defines took about 7 minutes under load averages of 29 to 36 on 12 cores.

## Global Constraints

- Work in the main working tree on `master`. Owner work in progress stays out of every commit: every path `git status --short` lists before Task 1 starts. On 2026-10-02 that was the staged rename `assets/themes/example.yaml -> assets/themes/default/theme.yaml`; the staged `lib/src/components/common/utility/slot.dart`, `lib/src/components/common/utility/utility.dart`, `lib/src/components/common/splash_screen.dart`, `lib/src/components/common/style/text_style_builder.dart`, and `lib/src/components/common/pages/page.dart` (deleted in the working tree); the modified `lib/src/components/common/common.dart`, `lib/src/components/common/style/style.dart`, `lib/stratum_ui.dart`, `pubspec.yaml`, and `example/pubspec.lock`; and the untracked `lib/src/components/common/page/`, `example/macos/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/`, and `example/macos/Runner.xcworkspace/xcshareddata/swiftpm/`. The list grew while this plan was written, so trust `git status`, not this line.
- Commit with explicit paths only: `git add -- <paths>`, then `git commit -m "<message>" -- <paths>`. `git commit -- <paths>` commits only those paths, so the owner's staged files stay staged and uncommitted. Write each path literally. Conventional Commits with a scope; no `Co-Authored-By` line and no AI attribution.
- All changes sit under `example/` and in the layout spec; `lib/` does not change (design section 4).
- Constructors use the `new` form: `const new(` for the unnamed constructor. `new.name(` fails with `new_constructor_dot_name`.
- Files under `example/` that import `package:stratum_ui/src/src.dart` start with `// ignore_for_file: implementation_imports`. Imports between `integration_test/`, `test/`, `test_driver/`, and `tool/` files are relative. `tool/perf_abba.dart` runs under `dart run` and imports no Flutter package, so it declares its own copies of the line markers; a test pins them to the app's.
- The app prints with `print`, which `flutter drive` forwards with a `flutter: ` prefix; `flutter_lints` needs `// ignore: avoid_print` on that line.
- Code blocks in this plan analyze clean and are `dart format` clean as written; paste them unchanged. Do not run `dart format` on `example/integration_test/perf/perf_scenes.dart`, which is not formatter-clean at d39aeb6.
- Run tests with `flutter test --no-pub <path>` and the analyzer with `flutter analyze --no-pub <paths>`, from `example/`. Run each RED step one file at a time: a compile error in one file breaks the others in the same run. Run every command in the foreground. A command likely to take over a minute writes to a log under `example/build/perf-logs/` (ignored by git), and the step reads the log's tail.
- Design values, verbatim: the catalog order "S2-plain, S1, S1-fast, S2, S2-box, S3, S4, S5"; "a 2 s cool-down after S5 (blur) before the next run"; the report key "`r<run>.<scene>.<side>.<pair>`"; the summary line "`PERF_SUMMARY ` followed by compact JSON with `key`, `average` (`average_frame_build_time_millis`), `p99Build`, `p99Raster`, and `begins` (each frame's build start in microseconds, relative to the first frame)"; the file "`build/perf/abba/r<run>/<scene>.<side>.<pair>.summary.json`"; "On each `PERF_RUN <run>` line, `perf_abba` records `uptime` into `r<run>/load.txt` and the code state into `r<run>/code.txt`"; the short trace "a trace covering less than the two-second window minus two frames", reason "`short trace`"; the escalation "takes the INCONCLUSIVE scenes, adds S2-plain"; "`n` is at most 4 (16 traces)" for `--trace-full`; "Verdict code unchanged apart from keys and folders".
- Benchmark values that stay (layout spec 9.5): "a cap of 24 runs"; exit codes "0 for PASS, 1 for FAIL or INVALID, and 2 for INCONCLUSIVE"; `code.txt` records "`git rev-parse HEAD` and a hash of `git diff HEAD -- lib example`". Measure under normal multitasking: never wait for a quiet machine and never discard data for load (owner ruling 2026-10-01). Semantics stay off in every scene.
- Never edit `example/integration_test/baseline/` by hand. Freezing the phase 4 tip with `tool/perf_freeze.dart` and updating `BaselineKit` follow this plan in phase 5; they are not part of it.
- Measured numbers go to `profile/memory/project_stratum_ui_layout_primitives.md` in the NTD OS root (outside this repository), never into the spec or the repository.
- `.worktrees/` is git-ignored; never stage it.

## Review Focus

- A 12-run call that runs past the driver's wait: one invocation of 12 runs takes about 18 minutes and 24 runs about 35, and `integrationDriver` waits 20 minutes by default (`integration_test_driver.dart:66` in the SDK). A person expects the call to finish and report, not to die near the end. Pinned in Task 1 ("waits out a 24-run call at 2.6 s per traced step, with half again as margin").
- A summary line as `flutter drive` forwards it: every app `print` arrives prefixed `flutter: `. A person expects every summary to be stored, not ignored as noise. Pinned in Task 2 ("parse back the values the app encodes, behind the flutter: prefix").
- A crash or a failed scene check halfway through a 12-run invocation: a person expects the finished traces to be on disk and judged, losing only the trace in progress. Pinned in Task 2 ("writes a summary before the next line arrives, so a crash loses only the trace in progress"); `_run` judges the stored runs after a non-zero `flutter drive` exit.
- `run --from 13` after a comparison where every scene passed or failed: a person expects a refusal, not a 12-run escalation of S2-plain alone, and never a re-measured FAIL scene. Pinned in Task 2 ("leaves S2-plain alone when no scene is INCONCLUSIVE" and the FAIL case in "measures the INCONCLUSIVE scenes in catalog order, plus S2-plain"); `_run` exits 64 on that list.
- A window hidden for a whole trace, which can leave a summary with one frame or none: a person expects that line reported and skipped, not a crash of the reader. Pinned in Task 2 ("refuse a cut line, a bad key, and fewer than two frames").

## File map

| File | Task | Responsibility |
|---|---|---|
| `example/integration_test/perf/perf_scene.dart`, `example/test/perf/perf_scene_test.dart` | 1 | `PerfStep` with run, run start, and cool-down; `runSteps` replaces `abbaSteps` |
| `example/integration_test/perf/perf_scenes.dart`, `example/test/perf/perf_scenes_test.dart` | 1 | One catalog in run order, S2-plain first; `perfScenesNamed`; `perfGroups` and `perfGroup` removed |
| `example/integration_test/perf/perf_trace.dart` (new), `example/test/perf/perf_trace_test.dart` (new) | 1 | Line markers, `summaryLine`, `runLine`, `printRunLine`, `traceStep` |
| `example/integration_test/layout_perf_test.dart` | 1 | Reads `PERF_FROM`, `PERF_RUNS`, `PERF_SCENES`, and `PERF_FULL`; runs `runSteps` |
| `example/test_driver/perf_driver.dart` | 1 | Writes `--trace-full` timelines only; `driverTimeout` of one hour |
| `example/tool/perf_abba.dart`, `example/test/tool/perf_abba_test.dart` | 2 | One build and one invocation per call; stdout reader; `r<run>/` folders; short-trace check; escalation scenes; `--trace-full` |
| `docs/superpowers/specs/2026-10-01-layout-primitives-design.md` | 3 | Sections 9.2, 9.4, and 9.5, plus the stale tool-test sentence in section 8, evidence in section 12, and a section 13 entry |

## Dependencies

### M1 Dependency table

| task | depends-on | agent |
|-------|------------|-------|
| M1-T1 | — | general-purpose |
| M1-T2 | M1-T1 | general-purpose |
| M1-T3 | M1-T2 | general-purpose |

Run the tasks in this order in the main working tree. Task 2's tests import Task 1's `summaryLine`, `runLine`, and `perfScenes` order. Task 3's dry run needs both. Between the Task 1 and Task 2 commits, `perf_abba run` does not work end to end (the old tool builds group apps the new app ignores); do not run it there.

---

## Milestone M1: Benchmark in one app run

### Task 1 (M1-T1): One app runs every scene and prints a summary per trace

**Agent:** general-purpose
**Implements:** §2 (one app, cool-down, one invocation), §3.1, §3.2, §3.3 (app side), §3.4 (driver side), §3.6 (app and driver side), §4 (app files), §5 (run order and summary line)

Phase 4 relaunched the app 36 times per 12 runs, and half of each 54 s invocation fell outside the traced windows. Here the app runs every run of a call in one launch. It summarizes each trace itself, so no timeline waits in the binding's report data, which the binding sends to the driver in one message after the last test (layout spec section 12). The macOS app runs in the App Sandbox, so it cannot write under `example/build/`; its summaries travel over stdout, which `flutter drive` forwards.

**Files:**
- Modify: `example/integration_test/perf/perf_scene.dart` (whole file)
- Modify: `example/integration_test/perf/perf_scenes.dart` (from the `perfScenes` doc comment to the end)
- Create: `example/integration_test/perf/perf_trace.dart`
- Modify: `example/integration_test/layout_perf_test.dart` (whole file)
- Modify: `example/test_driver/perf_driver.dart` (whole file)
- Test: `example/test/perf/perf_scene_test.dart` (whole file), `example/test/perf/perf_scenes_test.dart` (two edits), `example/test/perf/perf_trace_test.dart` (new)

**Interfaces:**
- Consumes: `PerfScene`, `perfScene`, `perfHost`, `perfStreams`, `settleTime`, `traceWindow`, `CurrentKit`, `BaselineKit`; `IntegrationTestWidgetsFlutterBinding.traceAction` and `reportData`; flutter_driver's `Timeline.fromJson`, `TimelineSummary.summarize`, `summaryJson`, `writeTimelineToFile`; `integrationDriver(timeout:, responseDataCallback:)`.
- Produces, in `integration_test/perf/perf_scene.dart`: `const coolDownTime = Duration(seconds: 2)`; `const coolDownScene = 'S5'`; `PerfStep(PerfScene scene, {required bool baseline, int? run, int? pair, bool startsRun = false, bool coolDown = false})` with `bool traced`, `String reportKey` (`r<run>.<scene>.<side>.<pair>`), and `String name`; `List<PerfStep> runSteps(List<PerfScene> scenes, {required int first, required int count})`. Removed: `abbaSteps`.
- Produces, in `integration_test/perf/perf_scenes.dart`: `perfScenes` in run order (S2-plain, S1, S1-fast, S2, S2-box, S3, S4, S5); `List<PerfScene> perfScenesNamed(String names)` (comma-separated, empty for every scene, `ArgumentError` for an unknown name). Removed: `perfGroups`, `perfGroup`.
- Produces, in `integration_test/perf/perf_trace.dart`: `const runMarker = 'PERF_RUN '`; `const summaryMarker = 'PERF_SUMMARY '`; `String runLine(int run)`; `String summaryLine(String key, Map<String, dynamic> summary)` (from a `TimelineSummary.summaryJson` map); `void printRunLine(int run)`; `Future<void> traceStep(IntegrationTestWidgetsFlutterBinding binding, String key, Future<void> Function() action, {required bool full})`.
- Produces, in `test_driver/perf_driver.dart`: `const driverTimeout = Duration(hours: 1)`; `const fullRoot = 'build/perf/full'`.
- Produces the dart-defines that Task 2's `buildArgs` sets: `PERF_FROM` (int, default 1), `PERF_RUNS` (int, default 1), `PERF_SCENES` (comma-separated, empty for every scene), `PERF_FULL` (bool, default false).

- [ ] **Step 1: Write the failing run-order test**

Replace all of `example/test/perf/perf_scene_test.dart` with:

```dart
import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/perf/perf_scene.dart';
import '../../integration_test/perf/perf_scenes.dart';

void main() {
  group('runSteps', () {
    final steps = runSteps(
      [perfScene('S1'), perfScene('S5')],
      first: 3,
      count: 2,
    );

    test('warms every scene up once per side before the first trace', () {
      expect(
        [for (final step in steps.take(4)) step.name],
        [
          'warm-up S1.base',
          'warm-up S1.cand',
          'warm-up S5.base',
          'warm-up S5.cand',
        ],
      );
      expect(steps.where((step) => !step.traced), hasLength(4));
    });

    test('traces one block per scene per run in list order, numbering runs '
        'from first', () {
      expect(
        [for (final step in steps.skip(4)) step.reportKey],
        [
          'r3.S1.base.1',
          'r3.S1.cand.1',
          'r3.S1.cand.2',
          'r3.S1.base.2',
          'r3.S5.base.1',
          'r3.S5.cand.1',
          'r3.S5.cand.2',
          'r3.S5.base.2',
          'r4.S1.base.1',
          'r4.S1.cand.1',
          'r4.S1.cand.2',
          'r4.S1.base.2',
          'r4.S5.base.1',
          'r4.S5.cand.1',
          'r4.S5.cand.2',
          'r4.S5.base.2',
        ],
      );
      expect(steps.skip(4).every((step) => step.traced), isTrue);
      expect(steps.skip(4).first.name, 'r3.S1.base.1');
    });

    test('opens each run with its first trace', () {
      expect(
        [
          for (final step in steps)
            if (step.startsRun) step.name,
        ],
        ['r3.S1.base.1', 'r4.S1.base.1'],
      );
    });

    test('cools down after S5 only, and not after the last run', () {
      expect(
        [
          for (final step in steps)
            if (step.coolDown) step.name,
        ],
        ['r3.S5.base.2'],
      );
    });

    test('never cools down when the list leaves S5 out', () {
      final steps = runSteps(
        [perfScene('S2-plain'), perfScene('S4')],
        first: 1,
        count: 3,
      );
      expect(steps.where((step) => step.coolDown), isEmpty);
      expect(steps.where((step) => step.traced), hasLength(24));
    });
  });
}
```

- [ ] **Step 2: Write the failing catalog tests**

In `example/test/perf/perf_scenes_test.dart`, replace:

```dart
    test('lists the scenes of spec section 9.1 in table order', () {
      expect(
        [for (final scene in perfScenes) scene.key],
        ['S1', 'S1-fast', 'S2', 'S2-box', 'S2-plain', 'S3', 'S4', 'S5'],
      );
    });
```

with:

```dart
    test('lists the scenes of spec section 9.1 in run order, the S2-plain '
        'null control first', () {
      expect(
        [for (final scene in perfScenes) scene.key],
        ['S2-plain', 'S1', 'S1-fast', 'S2', 'S2-box', 'S3', 'S4', 'S5'],
      );
    });
```

Then add this group at the end of `main`, after the closing `});` of `group('perfScenes', ...)`:

```dart
  group('perfScenesNamed', () {
    List<String> keys(String names) => [
      for (final scene in perfScenesNamed(names)) scene.key,
    ];

    test('gives every scene for an empty list', () {
      expect(keys(''), [for (final scene in perfScenes) scene.key]);
    });

    test('keeps the named scenes in catalog order', () {
      expect(keys('S5,S2-plain,S1'), ['S2-plain', 'S1', 'S5']);
    });

    test('rejects an unknown scene', () {
      expect(() => perfScenesNamed('S2-plain,S9'), throwsArgumentError);
    });
  });
```

- [ ] **Step 3: Write the failing trace test**

Create `example/test/perf/perf_trace_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/perf/perf_scene.dart';
import '../../integration_test/perf/perf_scenes.dart';
import '../../integration_test/perf/perf_trace.dart';
import '../../test_driver/perf_driver.dart' show driverTimeout;

void main() {
  group('summaryLine', () {
    final line = summaryLine('r2.S4.cand.1', {
      'average_frame_build_time_millis': 0.31,
      '99th_percentile_frame_build_time_millis': 1.02,
      '99th_percentile_frame_rasterizer_time_millis': 3.4,
      'frame_begin_times': [5000000, 5006940, 5013880],
      'frame_build_times': [310, 290, 330],
    });

    test('starts with the summary marker and holds compact JSON', () {
      expect(line, startsWith('PERF_SUMMARY {'));
      expect(line.substring(summaryMarker.length), isNot(contains(' ')));
    });

    test('keeps the key, the three metrics, and frame starts relative to the '
        'first frame', () {
      expect(jsonDecode(line.substring(summaryMarker.length)), {
        'key': 'r2.S4.cand.1',
        'average': 0.31,
        'p99Build': 1.02,
        'p99Raster': 3.4,
        'begins': [0, 6940, 13880],
      });
    });
  });

  group('runLine', () {
    test('names the run after the run marker', () {
      expect(runLine(7), 'PERF_RUN 7');
    });
  });

  group('driverTimeout', () {
    test('waits out a 24-run call at 2.6 s per traced step, with half again '
        'as margin', () {
      final traced = runSteps(
        perfScenes,
        first: 1,
        count: 24,
      ).where((step) => step.traced).length;
      expect(traced, 768);
      expect(
        driverTimeout,
        greaterThan(const Duration(milliseconds: 2600) * traced * 1.5),
      );
    });
  });
}
```

- [ ] **Step 4: Run them to verify they fail**

Run, from `example/`, one file at a time:

```bash
flutter test --no-pub test/perf/perf_scene_test.dart
flutter test --no-pub test/perf/perf_scenes_test.dart
flutter test --no-pub test/perf/perf_trace_test.dart
```

Expected: each FAILS at compile time, with `Error: Method not found: 'runSteps'.`, then `Error: Method not found: 'perfScenesNamed'.`, then `Error: Error when reading 'integration_test/perf/perf_trace.dart': No such file or directory`.

- [ ] **Step 5: Write the run order**

Replace all of `example/integration_test/perf/perf_scene.dart` with:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'perf_kit.dart';

/// Untraced pause after S5's block before the next run, so the blur's
/// after-effects stay out of the next run's first traces (spec section 9.4).
const coolDownTime = Duration(seconds: 2);

/// The scene after whose block the app cools down: S5 (blur).
const coolDownScene = 'S5';

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

  /// Pair number within the scene's block, 1 or 2; null for a warm-up step.
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
/// S5's block cools down before the next run.
List<PerfStep> runSteps(
  List<PerfScene> scenes, {
  required int first,
  required int count,
}) {
  final last = first + count - 1;
  return [
    for (final scene in scenes) ...[
      PerfStep(scene, baseline: true),
      PerfStep(scene, baseline: false),
    ],
    for (var run = first; run <= last; run++)
      for (final (index, scene) in scenes.indexed) ...[
        PerfStep(
          scene,
          baseline: true,
          run: run,
          pair: 1,
          startsRun: index == 0,
        ),
        PerfStep(scene, baseline: false, run: run, pair: 1),
        PerfStep(scene, baseline: false, run: run, pair: 2),
        PerfStep(
          scene,
          baseline: true,
          run: run,
          pair: 2,
          coolDown: scene.key == coolDownScene && run < last,
        ),
      ],
  ];
}
```

- [ ] **Step 6: Put the catalog in run order and filter it by name**

In `example/integration_test/perf/perf_scenes.dart`, replace everything from the line `/// Every scene of spec section 9.1, in table order.` to the end of the file with the block below. It moves the unchanged S2-plain entry to the front and replaces `perfGroups` and `perfGroup` with `perfScenesNamed`; every other entry stays as it is.

```dart
/// Every scene of spec section 9.1, in run order: the S2-plain null control
/// first, so each run measures its own noise before the scenes it judges.
/// `tool/perf_abba.dart` lists the same keys in its `catalog`.
final perfScenes = <PerfScene>[
  PerfScene(
    'S2-plain',
    build: (_) => _list(_plainRow),
    drive: _scroll(),
    check: (tester, _) async {
      // Equal row heights give equal list extents, so S2-plain scrolls the
      // same rows as S2-box. The current kit draws S2-box on both sides, so
      // the null control's two sides do identical work before every trace
      // (spec section 9.4).
      final plainExtent = _position(tester).maxScrollExtent;
      await tester.pumpWidget(
        perfHost(_list((index) => _boxRow(const CurrentKit(), index))),
      );
      final boxExtent = _position(tester).maxScrollExtent;
      await tester.pumpWidget(perfHost(_list(_plainRow)));
      expect(plainExtent, closeTo(boxExtent, 0.5));
    },
  ),
  PerfScene(
    'S1',
    build: (kit) => _list((index) => _row(kit, index)),
    drive: _scroll(),
  ),
  PerfScene(
    'S1-fast',
    build: (kit) => _list((index) => _row(kit, index)),
    drive: _scroll(distance: _fastDistance),
    check: (tester, kit) async {
      // The list holds rows only, so its extent divided by the row count
      // is the row height.
      final position = _position(tester);
      final rowHeight =
          (position.maxScrollExtent + position.viewportDimension) / _rowCount;
      expect(rowHeight, lessThan(_fastDistance / 144));
    },
  ),
  PerfScene(
    'S2',
    build: (kit) => _list((index) => _styledRow(kit, index)),
    drive: _scroll(),
  ),
  PerfScene(
    'S2-box',
    build: (kit) => _list((index) => _boxRow(kit, index)),
    drive: _scroll(),
  ),
  PerfScene(
    'S3',
    build: (kit) => _list((index) => _tappableRow(kit, index)),
    drive: _scroll(),
  ),
  PerfScene(
    'S4',
    build: (kit) => AnimatingBoxes(kit: kit),
    drive: (tester) => tester.pump(traceWindow),
  ),
  PerfScene(
    'S5',
    build: (kit) => GlassCards(kit: kit),
    drive: _scroll(distance: 2000),
  ),
];

/// The scene named [key].
PerfScene perfScene(String key) {
  return perfScenes.singleWhere((scene) => scene.key == key);
}

/// The catalog scenes named in [names], a comma-separated list such as
/// `PERF_SCENES` holds, in catalog order; every scene when [names] is empty.
/// Throws an [ArgumentError] for a name that is not in the catalog.
List<PerfScene> perfScenesNamed(String names) {
  if (names.isEmpty) return perfScenes;
  final keys = names.split(',');
  for (final key in keys) {
    if (!perfScenes.any((scene) => scene.key == key)) {
      throw ArgumentError.value(key, 'names', 'no such scene');
    }
  }
  return [
    for (final scene in perfScenes)
      if (keys.contains(scene.key)) scene,
  ];
}
```

- [ ] **Step 7: Write the trace step**

Create `example/integration_test/perf/perf_trace.dart`:

```dart
import 'dart:convert';

import 'package:flutter_driver/flutter_driver.dart' as driver;
import 'package:integration_test/integration_test.dart';

import 'perf_host.dart';

/// Opens the line the app prints when a run starts (spec section 9.4).
/// `tool/perf_abba.dart` reads the same marker.
const runMarker = 'PERF_RUN ';

/// Opens the line the app prints after each trace (spec section 9.4).
/// `tool/perf_abba.dart` reads the same marker.
const summaryMarker = 'PERF_SUMMARY ';

/// The line that opens run [run]: `PERF_RUN <run>`.
String runLine(int run) => '$runMarker$run';

/// The line that reports the trace [key] from a `TimelineSummary.summaryJson`
/// map: [summaryMarker], then compact JSON with the key, the three metrics
/// the verdict reads, and each frame's build start in microseconds,
/// relative to the first frame (spec section 9.4).
String summaryLine(String key, Map<String, dynamic> summary) {
  final begins = (summary['frame_begin_times'] as List).cast<int>();
  final json = jsonEncode({
    'key': key,
    'average': summary['average_frame_build_time_millis'],
    'p99Build': summary['99th_percentile_frame_build_time_millis'],
    'p99Raster': summary['99th_percentile_frame_rasterizer_time_millis'],
    'begins': [for (final begin in begins) begin - begins.first],
  });
  return '$summaryMarker$json';
}

/// Prints [line] for `flutter drive`, which forwards the app's print output
/// with a `flutter: ` prefix.
void _emit(String line) {
  // The benchmark's only channel to the host: the app runs in the App
  // Sandbox and cannot write under `example/build/`.
  // ignore: avoid_print
  print(line);
}

/// Prints the line that opens run [run].
void printRunLine(int run) => _emit(runLine(run));

/// Traces [action] under [key], prints the trace's summary line, and drops
/// its timeline from the binding's report data, so memory stays flat over
/// hundreds of traces. With [full], the timeline stays for the driver to
/// write (`run --trace-full`).
Future<void> traceStep(
  IntegrationTestWidgetsFlutterBinding binding,
  String key,
  Future<void> Function() action, {
  required bool full,
}) async {
  await binding.traceAction(action, streams: perfStreams, reportKey: key);
  final data = binding.reportData!;
  final timeline =
      (full ? data[key] : data.remove(key)) as Map<String, dynamic>;
  final summary = driver.TimelineSummary.summarize(
    driver.Timeline.fromJson(timeline),
  );
  _emit(summaryLine(key, summary.summaryJson));
}
```

- [ ] **Step 8: Run the app's runs from dart-defines**

Replace all of `example/integration_test/layout_perf_test.dart` with:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'perf/perf_host.dart';
import 'perf/perf_kit.dart';
import 'perf/perf_scene.dart';
import 'perf/perf_scenes.dart';
import 'perf/perf_trace.dart';

/// The first run this invocation traces (spec section 9.4).
const _from = int.fromEnvironment('PERF_FROM', defaultValue: 1);

/// How many runs this invocation traces.
const _runs = int.fromEnvironment('PERF_RUNS', defaultValue: 1);

/// The scenes to trace, comma-separated; empty for the whole catalog.
const _scenes = String.fromEnvironment('PERF_SCENES');

/// Whether every timeline stays for the driver (`run --trace-full`).
const _full = bool.fromEnvironment('PERF_FULL');

/// Traces runs of ABBA blocks of the frozen baseline and the current
/// layouts in one app, after an untraced warm-up (spec section 9.4).
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  final steps = runSteps(perfScenesNamed(_scenes), first: _from, count: _runs);
  for (final step in steps) {
    testWidgets(step.name, (tester) async {
      if (step.startsRun) printRunLine(step.run!);
      final PerfKit kit = step.baseline
          ? const BaselineKit()
          : const CurrentKit();
      final scene = step.scene;
      await tester.pumpWidget(perfHost(scene.build(kit)));
      await scene.check?.call(tester, kit);
      await tester.pump(settleTime);
      if (step.traced) {
        await traceStep(
          binding,
          step.reportKey,
          () => scene.drive(tester),
          full: _full,
        );
      } else {
        await scene.drive(tester);
      }
      expect(tester.takeException(), isNull);
      if (step.coolDown) {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(coolDownTime);
      }
    }, semanticsEnabled: false);
  }
}
```

- [ ] **Step 9: Keep the driver for full timelines only**

The coverage check leaves the driver; Task 2 adds it to `perf_abba` as the short-trace check. Replace all of `example/test_driver/perf_driver.dart` with:

```dart
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart' as driver;
import 'package:integration_test/integration_test_driver.dart';

/// Longest wait for the app's tests to end. One invocation holds every run
/// of a call: 12 runs take about 18 minutes and the cap of 24 about 35,
/// past `integrationDriver`'s default of 20 minutes.
const driverTimeout = Duration(hours: 1);

/// Where `run --trace-full` timelines go, relative to `example/`.
const fullRoot = 'build/perf/full';

/// Writes each full timeline the app kept as `<key>.timeline.json` under
/// [fullRoot]. Only `run --trace-full` keeps timelines; every other
/// invocation's report data is empty, because the app sends its summaries
/// over stdout (spec section 9.4).
Future<void> main() {
  return integrationDriver(
    timeout: driverTimeout,
    responseDataCallback: (data) async {
      for (final entry in (data ?? const <String, dynamic>{}).entries) {
        final timeline = driver.Timeline.fromJson(
          entry.value as Map<String, dynamic>,
        );
        await driver.TimelineSummary.summarize(timeline).writeTimelineToFile(
          entry.key,
          destinationDirectory: fullRoot,
          includeSummary: false,
        );
        stdout.writeln('wrote $fullRoot/${entry.key}.timeline.json');
      }
    },
  );
}
```

- [ ] **Step 10: Run them to verify they pass**

Run, from `example/`, one file at a time:

```bash
flutter test --no-pub test/perf/perf_scene_test.dart
flutter test --no-pub test/perf/perf_scenes_test.dart
flutter test --no-pub test/perf/perf_trace_test.dart
```

Expected: PASS, with `+5: All tests passed!`, `+22: All tests passed!`, and `+4: All tests passed!`.

- [ ] **Step 11: Run the example suite and the analyzer**

Run, from `example/`:

```bash
mkdir -p build/perf-logs
flutter test --no-pub test/ > build/perf-logs/p5-t1-suite.log 2>&1; echo "exit $?"
tail -1 build/perf-logs/p5-t1-suite.log
flutter analyze --no-pub integration_test test_driver tool test
```

Expected: `exit 0`, `+84: All tests passed!`, and `No issues found!` (`tool/perf_abba.dart` is still the phase 4 tool and still compiles).

- [ ] **Step 12: Commit**

```bash
cd "<repo>"
git add -- example/integration_test/perf/perf_scene.dart example/integration_test/perf/perf_scenes.dart example/integration_test/perf/perf_trace.dart example/integration_test/layout_perf_test.dart example/test_driver/perf_driver.dart example/test/perf/perf_scene_test.dart example/test/perf/perf_scenes_test.dart example/test/perf/perf_trace_test.dart
git commit -m "feat(example): run every benchmark scene in one app and print a summary per trace" -- example/integration_test/perf/perf_scene.dart example/integration_test/perf/perf_scenes.dart example/integration_test/perf/perf_trace.dart example/integration_test/layout_perf_test.dart example/test_driver/perf_driver.dart example/test/perf/perf_scene_test.dart example/test/perf/perf_scenes_test.dart example/test/perf/perf_trace_test.dart
```

Run: `git show --stat HEAD`
Expected: the eight files above; nothing under `assets/`, `lib/`, or `example/macos/`.

---

### Task 2 (M1-T2): `perf_abba` builds once, drives once, and reads summaries from stdout

**Agent:** general-purpose
**Implements:** §2 (summaries only, one invocation, escalation with S2-plain), §3.3 (reader side), §3.4 (short trace; invalid runs left out), §3.5, §3.6 (`--trace-full`), §4 (`tool/perf_abba.dart`), §5 (`perf_abba` cases), §8 (uncut line, hidden window)

The verdict code stays as phase 4 left it: `ciRank`, `medianInterval`, `blockTraces`, `blockChange`, `lostFrames`, `withinBudget`, `nullGatePasses`, `sceneVerdict`, `overallVerdict`, and `exitCodeOf` keep their bodies. What changes is around them. A run folder is `r<run>` instead of `r<run>g<group>`. A summary file is `<scene>.<side>.<pair>.summary.json` with the app's compact keys. `TraceMetrics` gains `span` for the short-trace check, and `judge` also returns each scene's verdict, which the escalation reads. Their tests change only in keys and folder names; the new cases cover the reader, the short trace, the escalation scenes, and `--trace-full`.

**Files:**
- Modify: `example/tool/perf_abba.dart` (whole file)
- Test: `example/test/tool/perf_abba_test.dart` (whole file)

**Interfaces:**
- Consumes, from Task 1: `runLine` and `summaryLine` in `integration_test/perf/perf_trace.dart` (test only); `perfScenes` in `integration_test/perf/perf_scenes.dart` (test only); the dart-defines `PERF_FROM`, `PERF_RUNS`, `PERF_SCENES`, `PERF_FULL`; the driver's `build/perf/full/` output. On the path: `flutter`, `git`, `shasum`, `uptime`.
- Produces, in `tool/perf_abba.dart`: `const catalog = ['S2-plain', 'S1', 'S1-fast', 'S2', 'S2-box', 'S3', 'S4', 'S5']`; `const maxFullRuns = 4`; `const runMarker = 'PERF_RUN '`; `const summaryMarker = 'PERF_SUMMARY '`; `typedef TraceMetrics = ({double average, double p99Build, double p99Raster, double period, int frames, double span})`; `Trace.run` is the run folder `r<run>`; `String? traceFullError({required String scene, required int runs})`; `List<String> buildArgs({required int from, required int runs, required List<String> scenes, bool full = false})`; `const driveArgs`; `List<String> escalationScenes(Map<String, Verdict> verdicts)`; `int? runMark(String line)`; `Map<String, dynamic>? summaryOf(String line)` (throws `FormatException` on an incomplete summary); `Future<List<String>> recordDrive(Stream<String> lines, {required Directory root, required String code, required Future<String> Function() load, void Function(String line)? echo})`; `bool shortTrace(TraceMetrics metrics)`; `judge(...)` returns `({String text, Verdict verdict, Map<String, Verdict> scenes})`; `metricsOf` reads `average`, `p99Build`, `p99Raster`, and `begins`. The CLI adds `run --trace-full <scene> --runs <n>`. Removed: `groups`, `groupScenes`, `appsRoot`, `runInvalid`, `runOf`, and the group forms of `buildArgs` and `driveArgs`.

- [ ] **Step 1: Write the failing tool test**

Replace all of `example/test/tool/perf_abba_test.dart` with:

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/perf/perf_scenes.dart' show perfScenes;
import '../../integration_test/perf/perf_trace.dart' show runLine, summaryLine;
import '../../tool/perf_abba.dart' hide main;

TraceMetrics _metrics({
  double average = 0.25,
  double p99Build = 0.5,
  double p99Raster = 3.5,
  double period = 6.94,
  int frames = 288,
  double span = 1993,
}) {
  return (
    average: average,
    p99Build: p99Build,
    p99Raster: p99Raster,
    period: period,
    frames: frames,
    span: span,
  );
}

Trace _trace(
  String run,
  String scene,
  String side,
  int pair, {
  double average = 0.25,
  double period = 6.94,
  int frames = 288,
  double span = 1993,
}) {
  return (
    run: run,
    scene: scene,
    side: side,
    pair: pair,
    metrics: _metrics(
      average: average,
      period: period,
      frames: frames,
      span: span,
    ),
  );
}

/// The four traces of one block of [scene] in run folder [run]; each side
/// has the same average in both of its slots.
List<Trace> _block(
  String run,
  String scene, {
  double base = 0.2,
  double cand = 0.2,
}) {
  return [
    _trace(run, scene, 'base', 1, average: base),
    _trace(run, scene, 'cand', 1, average: cand),
    _trace(run, scene, 'cand', 2, average: cand),
    _trace(run, scene, 'base', 2, average: base),
  ];
}

/// Blocks of [scene] over [changes], one block per entry, in run folders
/// r1 on.
List<Trace> _blocks(String scene, List<double> changes) {
  return [
    for (var i = 0; i < changes.length; i++)
      ..._block('r${i + 1}', scene, cand: 0.2 * (1 + changes[i] / 100)),
  ];
}

/// The block changes of the phase 3 S4 RCA (12 values, median −10.1%).
const _rcaS4 = [
  -46.1,
  -4.9,
  -6.5,
  -10.4,
  7.3,
  0.0,
  -48.2,
  -20.7,
  -14.2,
  -9.8,
  -21.6,
  -9.0,
];

void main() {
  group('ciRank', () {
    test('matches spec section 9.5', () {
      expect(ciRank(5), isNull);
      expect(ciRank(6), 1);
      expect(ciRank(12), 3);
      expect(ciRank(24), 7);
      expect(ciRank(36), 12);
      expect(ciRank(72), 28);
    });
  });

  group('medianInterval', () {
    test('gives the RCA S4 interval', () {
      expect(medianInterval(_rcaS4), (lower: -21.6, upper: -4.9));
    });

    test('gives no interval below 6 values', () {
      expect(medianInterval([1, 2, 3, 4, 5]), isNull);
    });
  });

  group('metricsOf', () {
    test(
      'reads the three metrics, the frame count, and the display period',
      () {
        final metrics = metricsOf({
          'average': 0.31,
          'p99Build': 1.02,
          'p99Raster': 3.4,
          'begins': [for (var i = 0; i < 10; i++) i * 6940, 100000],
        });
        expect(metrics.average, 0.31);
        expect(metrics.p99Build, 1.02);
        expect(metrics.p99Raster, 3.4);
        expect(metrics.frames, 11);
        expect(metrics.period, closeTo(6.94, 1e-9));
        expect(metrics.span, closeTo(100, 1e-9));
      },
    );

    test('takes the 10th-percentile gap, which skipped frames do not move', () {
      // Nine of ten gaps skip a frame: the median gap would read 13.88 ms.
      final metrics = metricsOf({
        'average': 0.31,
        'p99Build': 1.02,
        'p99Raster': 3.4,
        'begins': [0, 6940, for (var i = 1; i <= 9; i++) 6940 + i * 13880],
      });
      expect(metrics.period, closeTo(6.94, 1e-9));
    });
  });

  group('traceOf', () {
    test('reads scene, side, and pair from the report key', () {
      final trace = traceOf('r1', 'S2-plain.base.2.summary.json', _metrics());
      expect(trace?.run, 'r1');
      expect(trace?.scene, 'S2-plain');
      expect(trace?.side, 'base');
      expect(trace?.pair, 2);
    });

    test('skips files that are not ABBA summaries', () {
      expect(traceOf('r1', 'S1.summary.json', _metrics()), isNull);
      expect(traceOf('r1', 'S1.left.1.summary.json', _metrics()), isNull);
      expect(traceOf('r1', 'S1.base.1.timeline.json', _metrics()), isNull);
      expect(
        traceOf('r1', 'S1.base.1.timeline_summary.json', _metrics()),
        isNull,
      );
    });
  });

  group('blockTraces', () {
    test('makes one block per run folder and scene', () {
      final blocks = blockTraces([
        ..._block('r1', 'S1', base: 0.2, cand: 0.3),
        ..._block('r1', 'S2-plain'),
        ..._block('r2', 'S1', base: 0.4, cand: 0.4),
        ..._block('r1', 'S2'),
      ]);
      expect(blocks.keys, unorderedEquals(['S1', 'S2', 'S2-plain']));
      expect([
        for (final block in blocks['S1']!) block.cand1.average,
      ], unorderedEquals([0.3, 0.4]));
    });

    test('leaves out a block that misses any of its four traces', () {
      final blocks = blockTraces([
        ..._block('r1', 'S1'),
        ..._block('r2', 'S1').take(3),
      ]);
      expect(blocks['S1'], hasLength(1));
    });
  });

  group('blockChange', () {
    test('compares the sums of the two slots of each side', () {
      final change = blockChange((
        base1: _metrics(average: 0.2),
        cand1: _metrics(average: 0.25),
        cand2: _metrics(average: 0.3),
        base2: _metrics(average: 0.3),
      ));
      expect(change, closeTo(10, 1e-9));
    });
  });

  group('lostFrames', () {
    test('needs 90% of the frames the window holds at its period', () {
      // 2000 ms at 6.94 ms holds 288 frames; 90% is 259.4.
      expect(lostFrames(_metrics(frames: 259)), isTrue);
      expect(lostFrames(_metrics(frames: 260)), isFalse);
      expect(lostFrames(_metrics(period: 16.67, frames: 110)), isFalse);
    });
  });

  group('shortTrace', () {
    test('needs the window minus two frames at its display period', () {
      // 2000 ms less two 6.94 ms frames is 1986.12 ms.
      expect(shortTrace(_metrics(span: 1986)), isTrue);
      expect(shortTrace(_metrics(span: 1986.2)), isFalse);
      expect(shortTrace(_metrics(period: 16.67, span: 1967)), isFalse);
    });
  });

  group('invalidRuns', () {
    test("marks a run invalid when one trace's display period drifts", () {
      expect(
        invalidRuns([
          ..._block('r1', 'S1'),
          _trace('r1', 'S2', 'base', 1),
          _trace('r1', 'S2', 'cand', 1, period: 16.67),
          ..._block('r2', 'S1'),
        ]).keys,
        ['r1'],
      );
    });

    test('marks a run invalid when one whole scene ran on another '
        'display', () {
      expect(
        invalidRuns([
          ..._block('r1', 'S1'),
          ..._block('r1', 'S3'),
          _trace('r1', 'S4', 'base', 1, period: 16.67),
          _trace('r1', 'S4', 'cand', 1, period: 16.67),
          ..._block('r2', 'S1'),
        ]),
        {'r1': 'display period'},
      );
    });

    test('marks a run invalid when all of it ran on another display', () {
      expect(
        invalidRuns([
          ..._block('r1', 'S1'),
          ..._block('r2', 'S1'),
          ..._block('r3', 'S1'),
          _trace('r4', 'S1', 'base', 1, period: 16.67),
          _trace('r4', 'S1', 'cand', 1, period: 16.67),
        ]).keys,
        ['r4'],
      );
    });

    test('marks a run invalid on lost frames and names the side', () {
      expect(
        invalidRuns([
          ..._block('r1', 'S1'),
          _trace('r2', 'S4', 'base', 1),
          _trace('r2', 'S4', 'cand', 1, frames: 120),
          _trace('r3', 'S4', 'base', 1, frames: 19),
          _trace('r3', 'S4', 'cand', 1, frames: 130),
        ]),
        {
          'r2': 'lost frames on current',
          'r3': 'lost frames on baseline and current',
        },
      );
    });

    test('marks a run invalid on a short trace', () {
      expect(
        invalidRuns([
          ..._block('r1', 'S1'),
          _trace('r2', 'S1', 'base', 1),
          _trace('r2', 'S1', 'cand', 1, span: 1900),
        ]),
        {'r2': 'short trace'},
      );
    });
  });

  group('withinBudget', () {
    Block block(double base, double cand) => (
      base1: _metrics(p99Build: base, p99Raster: 3),
      cand1: _metrics(p99Build: cand, p99Raster: 3),
      cand2: _metrics(p99Build: cand, p99Raster: 3),
      base2: _metrics(p99Build: base, p99Raster: 3),
    );

    test('passes below 8.3 ms', () {
      expect(withinBudget([block(1, 7.9)]), isTrue);
    });

    test('fails at or above 8.3 ms when the baseline was below', () {
      expect(withinBudget([block(7, 8.3)]), isFalse);
    });

    test('accepts no worse than a baseline already over budget', () {
      expect(withinBudget([block(9, 8.9)]), isTrue);
      expect(withinBudget([block(9, 9.5)]), isFalse);
    });

    test('checks p99 raster too', () {
      expect(
        withinBudget([
          (
            base1: _metrics(p99Raster: 3),
            cand1: _metrics(p99Raster: 8.4),
            cand2: _metrics(p99Raster: 8.4),
            base2: _metrics(p99Raster: 3),
          ),
        ]),
        isFalse,
      );
    });
  });

  group('nullGatePasses', () {
    test('needs an interval that contains 0', () {
      expect(nullGatePasses((lower: -3, upper: 4)), isTrue);
      expect(nullGatePasses((lower: 0, upper: 4)), isTrue);
      expect(nullGatePasses((lower: 1, upper: 6)), isFalse);
      expect(nullGatePasses(null), isFalse);
    });
  });

  group('sceneVerdict', () {
    test('passes when the upper bound is at most +5%', () {
      expect(
        sceneVerdict(ci: (lower: -21.6, upper: -4.9), p99WithinBudget: true),
        Verdict.pass,
      );
      expect(
        sceneVerdict(ci: (lower: -1, upper: 5), p99WithinBudget: true),
        Verdict.pass,
      );
    });

    test('fails when the lower bound is above +5%', () {
      expect(
        sceneVerdict(ci: (lower: 5.1, upper: 9), p99WithinBudget: true),
        Verdict.fail,
      );
    });

    test('is inconclusive when the interval straddles +5% or is missing', () {
      expect(
        sceneVerdict(ci: (lower: 5, upper: 9), p99WithinBudget: true),
        Verdict.inconclusive,
      );
      expect(
        sceneVerdict(ci: (lower: -2, upper: 8), p99WithinBudget: true),
        Verdict.inconclusive,
      );
      expect(
        sceneVerdict(ci: null, p99WithinBudget: true),
        Verdict.inconclusive,
      );
    });

    test('fails on a missed budget, whatever the average', () {
      expect(
        sceneVerdict(ci: (lower: -20, upper: -5), p99WithinBudget: false),
        Verdict.fail,
      );
      expect(sceneVerdict(ci: null, p99WithinBudget: false), Verdict.fail);
    });
  });

  group('overallVerdict', () {
    test('orders INVALID, FAIL, INCONCLUSIVE, PASS', () {
      expect(
        overallVerdict(nullGate: false, scenes: [Verdict.fail]),
        Verdict.invalid,
      );
      expect(
        overallVerdict(
          nullGate: true,
          scenes: [Verdict.inconclusive, Verdict.fail],
        ),
        Verdict.fail,
      );
      expect(
        overallVerdict(
          nullGate: true,
          scenes: [Verdict.pass, Verdict.inconclusive],
        ),
        Verdict.inconclusive,
      );
      expect(
        overallVerdict(nullGate: true, scenes: [Verdict.pass, Verdict.pass]),
        Verdict.pass,
      );
    });

    test('maps verdicts to exit codes 0, 1, 1, 2', () {
      expect(exitCodeOf(Verdict.pass), 0);
      expect(exitCodeOf(Verdict.fail), 1);
      expect(exitCodeOf(Verdict.invalid), 1);
      expect(exitCodeOf(Verdict.inconclusive), 2);
    });
  });

  group('loadOf', () {
    test('reads the one-minute load average', () {
      expect(
        loadOf('18:27  up 9 days, 5 users, load averages: 16.19 13.38 13.78'),
        16.19,
      );
      expect(
        loadOf(' 10:00:00 up 1 day,  load average: 0.52, 0.40, 0.31'),
        0.52,
      );
      expect(loadOf('no load here'), isNull);
    });
  });

  group('judge', () {
    test('passes S4 on the RCA data behind a quiet null control', () {
      final result = judge(
        [
          ..._blocks('S2-plain', [-3, 2, -1, 4, 0.5, -2]),
          ..._blocks('S4', _rcaS4),
        ],
        loads: [9.1, 16.4],
        scenes: const ['S2-plain', 'S4'],
      );
      expect(result.verdict, Verdict.pass);
      expect(result.text, contains('| scene | blocks |'));
      expect(result.text, contains('| S4 | 12 |'));
      expect(result.text, contains('[-21.6, -4.9]'));
      expect(result.text, contains('| S2-plain (null) | 6 |'));
      expect(result.text, contains('load 9.1–16.4'));
      expect(result.text, contains('overall: PASS'));
    });

    test('is INVALID when the null interval misses 0', () {
      final result = judge(
        [
          ..._blocks('S2-plain', [3, 2, 1, 4, 5, 2]),
          ..._blocks('S4', _rcaS4),
        ],
        loads: const [],
        scenes: const ['S2-plain', 'S4'],
      );
      expect(result.verdict, Verdict.invalid);
      expect(result.text, contains('overall: INVALID'));
    });

    test('leaves an invalid run out and lists it with its reason', () {
      final result = judge(
        [
          ..._blocks('S2-plain', [-3, 2, -1, 4, 0.5, -2]),
          ..._blocks('S4', _rcaS4),
          _trace('r99', 'S4', 'base', 1),
          _trace('r99', 'S4', 'cand', 1, frames: 30),
          _trace('r99', 'S4', 'cand', 2),
          _trace('r99', 'S4', 'base', 2),
        ],
        loads: const [],
        scenes: const ['S2-plain', 'S4'],
      );
      expect(result.text, contains('| S4 | 12 |'));
      expect(
        result.text,
        contains('invalid runs: r99 (lost frames on current)'),
      );
    });

    test('keeps an expected scene without blocks as INCONCLUSIVE', () {
      final result = judge(
        [
          ..._blocks('S2-plain', [-3, 2, -1, 4, 0.5, -2]),
          ..._blocks('S4', _rcaS4),
        ],
        loads: const [],
        scenes: const ['S2-plain', 'S4', 'S5'],
      );
      expect(
        result.text,
        contains('| S5 | 0 | - | - | - | - | - | INCONCLUSIVE |'),
      );
      expect(result.verdict, Verdict.inconclusive);
    });

    test('lists run folders that recorded another code state', () {
      final result = judge(
        [
          ..._blocks('S2-plain', [-3, 2, -1, 4, 0.5, -2]),
          ..._blocks('S4', _rcaS4),
        ],
        loads: const [],
        scenes: const ['S2-plain', 'S4'],
        codeStates: const {'r1': 'abc 111', 'r2': 'abc 111', 'r3': 'def 222'},
      );
      expect(
        result.text,
        contains('code states differ: abc 111 in r1, r2; def 222 in r3'),
      );
    });

    test('gives each judged scene its verdict, S2-plain left out', () {
      final result = judge(
        [
          ..._blocks('S2-plain', [-3, 2, -1, 4, 0.5, -2]),
          ..._blocks('S4', _rcaS4),
          ..._blocks('S1', [-2, 8, 1, 9, 3, 7]),
        ],
        loads: const [],
        scenes: const ['S2-plain', 'S1', 'S4', 'S5'],
      );
      expect(result.scenes, {
        'S1': Verdict.inconclusive,
        'S4': Verdict.pass,
        'S5': Verdict.inconclusive,
      });
    });
  });

  group('codeStateError', () {
    test('accepts runs on the stored code state', () {
      expect(codeStateError(const {}, 'abc 111'), isNull);
      expect(codeStateError(const {'r1': 'abc 111'}, 'abc 111'), isNull);
    });

    test('refuses runs on another code state', () {
      expect(
        codeStateError(const {'r1': 'abc 111', 'r2': 'abc 222'}, 'abc 111'),
        contains('r2'),
      );
    });
  });

  group('runRangeError', () {
    test('accepts runs within the cap of 24 runs', () {
      expect(runRangeError(from: 1, runs: 12), isNull);
      expect(runRangeError(from: 13, runs: 12), isNull);
    });

    test('refuses runs beyond the cap or outside 1', () {
      expect(runRangeError(from: 13, runs: 13), contains('1 to 24'));
      expect(runRangeError(from: 0, runs: 1), isNotNull);
      expect(runRangeError(from: 1, runs: 0), isNotNull);
    });
  });

  group('clashingRuns', () {
    late Directory root;

    setUp(() => root = Directory.systemTemp.createTempSync('abba'));
    tearDown(() => root.deleteSync(recursive: true));

    test('refuses run folders that exist', () {
      Directory('${root.path}/r2').createSync();
      expect(clashingRuns(root, from: 1, runs: 6), ['${root.path}/r2']);
      expect(clashingRuns(root, from: 3, runs: 4), isEmpty);
    });
  });

  group('one app', () {
    test('builds one profile app for the runs and scenes of a call', () {
      expect(buildArgs(from: 13, runs: 12, scenes: const ['S2-plain', 'S4']), [
        'build',
        'macos',
        '--profile',
        '--target=integration_test/layout_perf_test.dart',
        '--dart-define=PERF_FROM=13',
        '--dart-define=PERF_RUNS=12',
        '--dart-define=PERF_SCENES=S2-plain,S4',
        '--dart-define=PERF_FULL=false',
      ]);
      expect(
        buildArgs(from: 1, runs: 2, scenes: const ['S4'], full: true),
        contains('--dart-define=PERF_FULL=true'),
      );
    });

    test('drives the prebuilt app', () {
      expect(
        driveArgs,
        contains(
          '--use-application-binary='
          'build/macos/Build/Products/Profile/stratum_ui_example.app',
        ),
      );
      expect(driveArgs, contains('--endless-trace-buffer'));
      expect(driveArgs, contains('--driver=test_driver/perf_driver.dart'));
      expect(
        driveArgs,
        contains('--target=integration_test/layout_perf_test.dart'),
      );
    });

    test('lists the scenes of perfScenes in run order', () {
      expect(catalog, [for (final scene in perfScenes) scene.key]);
    });
  });

  group('summary lines', () {
    final appSummary = {
      'average_frame_build_time_millis': 0.31,
      '99th_percentile_frame_build_time_millis': 1.02,
      '99th_percentile_frame_rasterizer_time_millis': 3.4,
      'frame_begin_times': [for (var i = 0; i < 288; i++) 7000000 + i * 6940],
    };

    test('parse back the values the app encodes, behind the flutter: '
        'prefix', () {
      final line = 'flutter: ${summaryLine('r3.S2.cand.2', appSummary)}';
      final summary = summaryOf(line)!;
      expect(summary['key'], 'r3.S2.cand.2');
      final metrics = metricsOf(summary);
      expect(metrics.average, 0.31);
      expect(metrics.p99Build, 1.02);
      expect(metrics.p99Raster, 3.4);
      expect(metrics.frames, 288);
      expect(metrics.period, closeTo(6.94, 1e-9));
      expect(metrics.span, closeTo(287 * 6.94, 1e-9));
    });

    test('ignore lines without a marker', () {
      expect(summaryOf('flutter: 00:41 +16: r1.S1.base.1'), isNull);
      expect(runMark('flutter: 00:41 +16: r1.S1.base.1'), isNull);
    });

    test('read the run of a run line', () {
      expect(runMark('flutter: ${runLine(13)}'), 13);
    });

    test('refuse a cut line, a bad key, and fewer than two frames', () {
      final line = summaryLine('r3.S2.cand.2', appSummary);
      expect(
        () => summaryOf(line.substring(0, line.length - 40)),
        throwsFormatException,
      );
      expect(
        () => summaryOf(summaryLine('S2.cand.2', appSummary)),
        throwsFormatException,
      );
      expect(
        () => summaryOf(
          summaryLine('r3.S2.cand.2', {
            ...appSummary,
            'frame_begin_times': [7000000],
          }),
        ),
        throwsFormatException,
      );
    });
  });

  group('recordDrive', () {
    late Directory root;

    setUp(() => root = Directory.systemTemp.createTempSync('abba'));
    tearDown(() => root.deleteSync(recursive: true));

    Map<String, dynamic> summary(int frames) => {
      'average_frame_build_time_millis': 0.31,
      '99th_percentile_frame_build_time_millis': 1.02,
      '99th_percentile_frame_rasterizer_time_millis': 3.4,
      'frame_begin_times': [for (var i = 0; i < frames; i++) i * 6940],
    };

    Future<String> load() async => ' 18:27  up 9 days, load averages: 9.10 ';

    test('writes each summary to its run folder, records load and code per '
        'run, and reports a cut line', () async {
      final cut = summaryLine('r1.S1.cand.1', summary(288));
      final echoed = <String>[];
      final problems = await recordDrive(
        Stream.fromIterable([
          'Resolving dependencies...',
          'flutter: ${runLine(1)}',
          'flutter: ${summaryLine('r1.S1.base.1', summary(288))}',
          'flutter: ${cut.substring(0, 900)}',
          'flutter: ${summaryLine('r1.S1.cand.2', summary(287))}',
        ]),
        root: root,
        code: 'abc 111',
        load: load,
        echo: echoed.add,
      );

      expect(problems, hasLength(1));
      expect(problems.single, startsWith('skipped a summary line'));
      final run = '${root.path}/r1';
      expect(File('$run/code.txt').readAsStringSync(), 'abc 111');
      expect(
        File('$run/load.txt').readAsStringSync(),
        '18:27  up 9 days, load averages: 9.10',
      );
      expect(
        [
          for (final file in Directory(run).listSync())
            file.uri.pathSegments.last,
        ]..sort(),
        [
          'S1.base.1.summary.json',
          'S1.cand.2.summary.json',
          'code.txt',
          'load.txt',
        ],
      );
      final stored = readRuns(root);
      expect([for (final t in stored.traces) t.metrics.frames]..sort(), [
        287,
        288,
      ]);
      expect(stored.loads, [9.1]);
      expect(stored.codeStates, {'r1': 'abc 111'});
      expect(echoed, contains('Resolving dependencies...'));
    });

    test('writes a summary before the next line arrives, so a crash loses '
        'only the trace in progress', () async {
      final lines = StreamController<String>();
      final done = recordDrive(
        lines.stream,
        root: root,
        code: 'abc 111',
        load: load,
        echo: (_) {},
      );
      lines.add(summaryLine('r2.S4.base.1', summary(288)));
      await pumpEventQueue();

      final file = File('${root.path}/r2/S4.base.1.summary.json');
      expect(file.existsSync(), isTrue);
      expect(
        jsonDecode(file.readAsStringSync()),
        containsPair('key', 'r2.S4.base.1'),
      );
      await lines.close();
      expect(await done, isEmpty);
    });
  });

  group('escalationScenes', () {
    test('measures every scene when no run is stored', () {
      final verdicts = judge(const [], loads: const [], scenes: catalog).scenes;
      expect(escalationScenes(verdicts), catalog);
    });

    test(
      'measures the INCONCLUSIVE scenes in catalog order, plus S2-plain',
      () {
        expect(
          escalationScenes({
            'S1': Verdict.pass,
            'S1-fast': Verdict.inconclusive,
            'S2': Verdict.fail,
            'S2-box': Verdict.pass,
            'S3': Verdict.pass,
            'S4': Verdict.inconclusive,
            'S5': Verdict.pass,
          }),
          ['S2-plain', 'S1-fast', 'S4'],
        );
      },
    );

    test('leaves S2-plain alone when no scene is INCONCLUSIVE', () {
      expect(escalationScenes({'S1': Verdict.pass, 'S4': Verdict.fail}), [
        nullScene,
      ]);
    });
  });

  group('traceFullError', () {
    test('accepts one catalog scene for 1 to 4 runs', () {
      expect(traceFullError(scene: 'S4', runs: 1), isNull);
      expect(traceFullError(scene: 'S4', runs: 4), isNull);
    });

    test('refuses more than 4 runs, the 16 traces of one message', () {
      expect(traceFullError(scene: 'S4', runs: 5), contains('1 to 4'));
      expect(traceFullError(scene: 'S4', runs: 0), isNotNull);
    });

    test('refuses a scene outside the catalog', () {
      expect(traceFullError(scene: 'S9', runs: 1), contains('S9'));
    });
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run, from `example/`: `flutter test --no-pub test/tool/perf_abba_test.dart`
Expected: FAIL at compile time, with `Error: A value of type '({double average, int frames, double p99Build, double p99Raster, double period, double span})' can't be returned from a function with return type '({double average, int frames, double p99Build, double p99Raster, double period})'.` and `Error: Method not found: 'shortTrace'.`, among others for `recordDrive`, `summaryOf`, `escalationScenes`, `traceFullError`, and `catalog`.

- [ ] **Step 3: Write the tool**

Replace all of `example/tool/perf_abba.dart` with:

```dart
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

/// Frame budget at 120 Hz, in milliseconds (spec section 9.5).
const budget = 8.3;

/// Largest accepted rise of the average build time, in percent.
const maxAverageRise = 5.0;

/// Largest distance of a trace's display period from its run's median
/// period, or from the comparison's, as a fraction of that median.
const maxPeriodDrift = 0.1;

/// Smallest share of the frames a traced window holds at its display
/// period; a trace with fewer lost frames (spec section 9.5).
const minFrameShare = 0.9;

/// Length of every traced window, in milliseconds: `traceWindow` in
/// `integration_test/perf/perf_host.dart`.
const traceWindowMs = 2000.0;

/// Every scene in run order: the keys of `perfScenes` in
/// `integration_test/perf/perf_scenes.dart`.
const catalog = ['S2-plain', 'S1', 'S1-fast', 'S2', 'S2-box', 'S3', 'S4', 'S5'];

/// Most runs one comparison holds: 24 blocks per scene (spec section 9.5).
const maxRuns = 24;

/// Most runs one `--trace-full` call holds: 16 traces, all the binding
/// sends the driver in one message after the last test.
const maxFullRuns = 4;

/// The null-control scene, judged only by the null gate.
const nullScene = 'S2-plain';

/// Root of the run folders, relative to `example/`.
const abbaRoot = 'build/perf/abba';

/// Opens the line the app prints when a run starts: `runMarker` in
/// `integration_test/perf/perf_trace.dart`.
const runMarker = 'PERF_RUN ';

/// Opens the line the app prints after each trace: `summaryMarker` in
/// `integration_test/perf/perf_trace.dart`.
const summaryMarker = 'PERF_SUMMARY ';

/// Where `flutter build macos --profile` writes the app.
const _builtApp = 'build/macos/Build/Products/Profile/stratum_ui_example.app';

const _target = '--target=integration_test/layout_perf_test.dart';

const _usage =
    'usage: dart run tool/perf_abba.dart report\n'
    '       dart run tool/perf_abba.dart run --runs <n> [--from <first>]\n'
    '       dart run tool/perf_abba.dart run --trace-full <scene> --runs <n>';

/// The verdict of a scene or a comparison (spec section 9.5).
enum Verdict { pass, fail, inconclusive, invalid }

/// The metrics read from one trace's summary. The display period is the
/// 10th percentile of the gaps between frame starts, in milliseconds;
/// [frames] counts the frames the trace holds, and [span] is the time from
/// the first frame's start to the last one's, in milliseconds.
typedef TraceMetrics = ({
  double average,
  double p99Build,
  double p99Raster,
  double period,
  int frames,
  double span,
});

/// One trace: its run folder (`r<run>`) and its report key.
typedef Trace = ({
  String run,
  String scene,
  String side,
  int pair,
  TraceMetrics metrics,
});

/// The four traces of one scene in one run, in the order baseline,
/// current, current, baseline (spec section 9.4).
typedef Block = ({
  TraceMetrics base1,
  TraceMetrics cand1,
  TraceMetrics cand2,
  TraceMetrics base2,
});

/// A 95% interval for the median block change, in percent.
typedef ConfidenceInterval = ({double lower, double upper});

/// Runs and judges the in-process ABBA benchmark (spec sections 9.4 and
/// 9.5).
///
/// Usage, from `example/`:
/// - `dart run tool/perf_abba.dart run --runs 12` builds the profile app
///   once and runs all 12 runs in one `flutter drive` invocation, writing
///   each trace's summary as the app prints it, then reports.
/// - `dart run tool/perf_abba.dart run --from 13 --runs 12` adds the one
///   escalation, up to 24 runs (24 blocks per scene), for the scenes the
///   stored runs leave INCONCLUSIVE, plus S2-plain.
/// - `dart run tool/perf_abba.dart run --trace-full <scene> --runs <n>`
///   keeps the full timelines of one scene for at most 4 runs; it never
///   enters a verdict.
/// - `dart run tool/perf_abba.dart report` judges the stored runs again.
///
/// Prints the report, writes it to `build/perf/abba/report.md`, and exits
/// with 0 for PASS, 1 for FAIL or INVALID, and 2 for INCONCLUSIVE.
Future<void> main(List<String> args) async {
  switch (args) {
    case ['report']:
      exitCode = _report();
    case ['run', ...final options] when _option(options, '--runs') != null:
      final runs = _option(options, '--runs')!;
      final full = _text(options, '--trace-full');
      exitCode = full == null
          ? await _run(from: _option(options, '--from') ?? 1, runs: runs)
          : await _traceFull(scene: full, runs: runs);
    default:
      stderr.writeln(_usage);
      exitCode = 64;
  }
}

String? _text(List<String> options, String name) {
  final index = options.indexOf(name);
  return index < 0 || index + 1 >= options.length ? null : options[index + 1];
}

int? _option(List<String> options, String name) {
  return int.tryParse(_text(options, name) ?? '');
}

/// Why runs [from] to `from + runs - 1` cannot run, or null when they can.
String? runRangeError({required int from, required int runs}) {
  final last = from + runs - 1;
  if (from < 1 || runs < 1 || last > maxRuns) {
    return 'runs $from to $last fall outside 1 to $maxRuns '
        '(24 blocks per scene)';
  }
  return null;
}

/// Why new runs on [current] cannot join the runs stored with [stored]
/// (run folder to code state), or null when every stored run folder
/// recorded [current] (spec section 9.4).
String? codeStateError(Map<String, String> stored, String current) {
  final others = [
    for (final MapEntry(key: folder, value: state) in stored.entries)
      if (state != current) folder,
  ]..sort();
  if (others.isEmpty) return null;
  return '${others.join(', ')} ran on another code state than $current: '
      'rm -rf $abbaRoot for a new comparison';
}

/// Why `run --trace-full [scene] --runs [runs]` cannot run, or null when
/// it can (spec section 9.4).
String? traceFullError({required String scene, required int runs}) {
  if (!catalog.contains(scene)) {
    return 'no scene $scene; the scenes are ${catalog.join(', ')}';
  }
  if (runs < 1 || runs > maxFullRuns) {
    return '--trace-full holds 1 to $maxFullRuns runs '
        '(${maxFullRuns * 4} traces in one message), not $runs';
  }
  return null;
}

/// Arguments that build the profile app for runs [from] to
/// `from + runs - 1` of [scenes]; [full] keeps every timeline.
List<String> buildArgs({
  required int from,
  required int runs,
  required List<String> scenes,
  bool full = false,
}) {
  return [
    'build',
    'macos',
    '--profile',
    _target,
    '--dart-define=PERF_FROM=$from',
    '--dart-define=PERF_RUNS=$runs',
    '--dart-define=PERF_SCENES=${scenes.join(',')}',
    '--dart-define=PERF_FULL=$full',
  ];
}

/// Arguments that run the prebuilt app, so the invocation does not build.
const driveArgs = [
  'drive',
  '--profile',
  '--endless-trace-buffer',
  '-d',
  'macos',
  '--driver=test_driver/perf_driver.dart',
  _target,
  '--use-application-binary=$_builtApp',
];

/// Run folders under [root] that runs [from] to `from + runs - 1` would
/// write into but that exist already.
List<String> clashingRuns(
  Directory root, {
  required int from,
  required int runs,
}) {
  return [
    for (var run = from; run < from + runs; run++)
      if (Directory('${root.path}/r$run').existsSync()) '${root.path}/r$run',
  ];
}

/// The code under test, as `code.txt` records it (spec section 9.4):
/// `git rev-parse HEAD` and a hash of `git diff HEAD -- lib example`, both
/// run from the repository root.
Future<String> codeState() async {
  final head = await Process.run('git', [
    'rev-parse',
    'HEAD',
  ], workingDirectory: '..');
  final diff = await Process.run('sh', [
    '-c',
    'git diff HEAD -- lib example | shasum',
  ], workingDirectory: '..');
  final hash = (diff.stdout as String).split(' ').first;
  return '${(head.stdout as String).trim()} $hash';
}

/// The scenes a call measures (spec section 9.5): each scene that
/// [verdicts] leaves INCONCLUSIVE, plus S2-plain, which the null gate
/// judges over every run, in catalog order. With no stored run every scene
/// is INCONCLUSIVE, so a first call measures the whole catalog.
List<String> escalationScenes(Map<String, Verdict> verdicts) {
  return [
    for (final scene in catalog)
      if (scene == nullScene || verdicts[scene] == Verdict.inconclusive) scene,
  ];
}

/// The run number of a `PERF_RUN <run>` line, or null for any other line.
int? runMark(String line) {
  final index = line.indexOf(runMarker);
  if (index < 0) return null;
  return int.tryParse(line.substring(index + runMarker.length).trim());
}

final _summaryKey = RegExp(r'^r\d+\.[^.]+\.(base|cand)\.[12]$');

/// The summary a `PERF_SUMMARY` line carries, or null for a line without
/// the marker. `flutter drive` prefixes the app's lines with `flutter: `,
/// so the marker may sit anywhere in the line.
///
/// Throws a [FormatException] when the line holds no complete summary: a
/// cut line, a key other than `r<run>.<scene>.<side>.<pair>`, or fewer than
/// two frames.
Map<String, dynamic>? summaryOf(String line) {
  final index = line.indexOf(summaryMarker);
  if (index < 0) return null;
  final payload = line.substring(index + summaryMarker.length);
  final json = jsonDecode(payload);
  if (json
      case {
        'key': final String key,
        'average': num _,
        'p99Build': num _,
        'p99Raster': num _,
        'begins': final List<dynamic> begins,
      }
      when _summaryKey.hasMatch(key) &&
          begins.length >= 2 &&
          begins.every((begin) => begin is num)) {
    return json as Map<String, dynamic>;
  }
  throw FormatException('not a complete summary', _clip(payload));
}

/// Writes each summary line of [lines], the stdout of `flutter drive`, to
/// `r<run>/<scene>.<side>.<pair>.summary.json` under [root] as it arrives,
/// and on each run line records [load] and [code] in that run's folder
/// (spec section 9.4). Hands every other line to [echo], stdout by
/// default. Returns one problem per line that does not parse as a complete
/// summary; that line is skipped.
Future<List<String>> recordDrive(
  Stream<String> lines, {
  required Directory root,
  required String code,
  required Future<String> Function() load,
  void Function(String line)? echo,
}) async {
  final log = echo ?? stdout.writeln;
  final problems = <String>[];
  await for (final line in lines) {
    final run = runMark(line);
    if (run != null) {
      final folder = Directory('${root.path}/r$run')
        ..createSync(recursive: true);
      File('${folder.path}/code.txt').writeAsStringSync(code);
      final uptime = (await load()).trim();
      File('${folder.path}/load.txt').writeAsStringSync(uptime);
      log('run $run: $uptime');
      continue;
    }
    final Map<String, dynamic>? summary;
    try {
      summary = summaryOf(line);
    } on FormatException catch (error) {
      final problem =
          'skipped a summary line that does not parse (${error.message}): '
          '${_clip(line)}';
      problems.add(problem);
      log(problem);
      continue;
    }
    if (summary == null) {
      log(line);
      continue;
    }
    final key = summary['key'] as String;
    final dot = key.indexOf('.');
    final folder = Directory('${root.path}/${key.substring(0, dot)}')
      ..createSync(recursive: true);
    File('${folder.path}/${key.substring(dot + 1)}.summary.json')
        .writeAsStringSync(jsonEncode(summary));
    log('$key: ${(summary['begins'] as List).length} frames');
  }
  return problems;
}

String _clip(String text) {
  return text.length <= 80 ? text : '${text.substring(0, 80)}…';
}

/// Builds the profile app with [args]; false when the build fails.
Future<bool> _build(List<String> args) async {
  final build = await Process.start(
    'flutter',
    args,
    mode: ProcessStartMode.inheritStdio,
  );
  if (await build.exitCode == 0) return true;
  stderr.writeln('flutter build failed');
  return false;
}

Future<String> _uptime() async {
  return (await Process.run('uptime', const [])).stdout as String;
}

Future<int> _run({required int from, required int runs}) async {
  final rangeError = runRangeError(from: from, runs: runs);
  if (rangeError != null) {
    stderr.writeln(rangeError);
    return 64;
  }
  final root = Directory(abbaRoot);
  final clashes = clashingRuns(root, from: from, runs: runs);
  if (clashes.isNotEmpty) {
    stderr.writeln(
      '${clashes.join(', ')} exist: rm -rf $abbaRoot for a new comparison, '
      'or pass --from after the last stored run',
    );
    return 64;
  }
  final code = await codeState();
  final stored = root.existsSync() ? readRuns(root) : null;
  if (stored != null) {
    final stateError = codeStateError(stored.codeStates, code);
    if (stateError != null) {
      stderr.writeln(stateError);
      return 64;
    }
  }
  // The stored runs decide the scenes: every scene on a first call, the
  // INCONCLUSIVE ones plus S2-plain on an escalation (spec section 9.5).
  final judged = judge(
    stored?.traces ?? const [],
    loads: const [],
    scenes: catalog,
  );
  final scenes = escalationScenes(judged.scenes);
  if (scenes.length == 1) {
    stderr.writeln(
      'the stored runs leave no scene INCONCLUSIVE; no run is added',
    );
    return 64;
  }
  // One build and one invocation for the whole call (spec section 9.4).
  if (!await _build(buildArgs(from: from, runs: runs, scenes: scenes))) {
    return 1;
  }
  stdout.writeln(
    'runs $from to ${from + runs - 1} of ${scenes.join(', ')}. '
    'Keep the test window visible until the run ends.',
  );
  final drive = await Process.start('flutter', driveArgs);
  drive.stderr.listen(stderr.add);
  final problems = await recordDrive(
    drive.stdout.transform(utf8.decoder).transform(const LineSplitter()),
    root: root,
    code: code,
    load: _uptime,
  );
  final exit = await drive.exitCode;
  for (final problem in problems) {
    stderr.writeln(problem);
  }
  if (exit != 0) {
    // Every summary the app printed is on disk: judge them.
    stderr.writeln(
      'flutter drive exited $exit; the stored runs are judged, and '
      '--from adds runs after the last stored run',
    );
  }
  return _report();
}

Future<int> _traceFull({required String scene, required int runs}) async {
  final error = traceFullError(scene: scene, runs: runs);
  if (error != null) {
    stderr.writeln(error);
    return 64;
  }
  final args = buildArgs(from: 1, runs: runs, scenes: [scene], full: true);
  if (!await _build(args)) return 1;
  stdout.writeln('Keep the test window visible until the run ends.');
  final drive = await Process.start(
    'flutter',
    driveArgs,
    mode: ProcessStartMode.inheritStdio,
  );
  return drive.exitCode;
}

int _report() {
  final root = Directory(abbaRoot);
  if (!root.existsSync()) {
    stderr.writeln('no runs in $abbaRoot');
    return 64;
  }
  final (:traces, :loads, :codeStates) = readRuns(root);
  final result = judge(
    traces,
    loads: loads,
    scenes: catalog,
    codeStates: codeStates,
  );
  stdout.write(result.text);
  File('$abbaRoot/report.md').writeAsStringSync(result.text);
  return exitCodeOf(result.verdict);
}

/// Reads the metrics of one summary: the JSON of a `PERF_SUMMARY` line, as
/// a `*.summary.json` file holds it.
TraceMetrics metricsOf(Map<String, dynamic> summary) {
  final begins = (summary['begins'] as List).cast<num>();
  double read(String key) => (summary[key] as num).toDouble();
  final gaps = [
    for (var i = 1; i < begins.length; i++) (begins[i] - begins[i - 1]) / 1000,
  ]..sort();
  return (
    average: read('average'),
    p99Build: read('p99Build'),
    p99Raster: read('p99Raster'),
    // Nearest-rank 10th percentile.
    period: gaps[math.max(0, (gaps.length * 0.1).ceil() - 1)],
    frames: begins.length,
    span: (begins.last - begins.first) / 1000,
  );
}

/// The trace in [fileName] of [run], or null when the name is not
/// `<scene>.<side>.<pair>.summary.json`.
Trace? traceOf(String run, String fileName, TraceMetrics metrics) {
  final parts = fileName.split('.');
  if (parts.length != 5 || parts[3] != 'summary' || parts[4] != 'json') {
    return null;
  }
  final [scene, side, pairText, _, _] = parts;
  final pair = int.tryParse(pairText);
  if (pair == null || (side != 'base' && side != 'cand')) return null;
  return (run: run, scene: scene, side: side, pair: pair, metrics: metrics);
}

/// Whether [metrics] holds fewer than [minFrameShare] of the frames its
/// traced window holds at its display period (spec section 9.5).
bool lostFrames(TraceMetrics metrics) {
  return metrics.frames < minFrameShare * traceWindowMs / metrics.period;
}

/// Whether [metrics] covers less than the traced window minus two frames at
/// its display period, which happens when the timeline recorder's buffer
/// drops the first frames (spec section 9.4).
bool shortTrace(TraceMetrics metrics) {
  return metrics.span < traceWindowMs - 2 * metrics.period;
}

/// Runs (`r<run>`) left out of the analysis, each with its reason (spec
/// section 9.5): a trace whose display period differs by more than
/// [maxPeriodDrift] from the run's median period or from the comparison's,
/// which also catches a run whose windows all opened on another display; a
/// trace that lost frames, named by side, because frames lost on the
/// current side only can signal a regression; or a short trace.
Map<String, String> invalidRuns(List<Trace> traces) {
  if (traces.isEmpty) return {};
  final overall = median([for (final t in traces) t.metrics.period]);
  final byRun = <String, List<Trace>>{};
  for (final trace in traces) {
    (byRun[trace.run] ??= []).add(trace);
  }
  final reasons = <String, String>{};
  for (final MapEntry(key: run, value: runTraces) in byRun.entries) {
    final runMedian = median([for (final t in runTraces) t.metrics.period]);
    final drifts = runTraces.any(
      (t) =>
          _drifts(t.metrics.period, runMedian) ||
          _drifts(t.metrics.period, overall),
    );
    final lostSides = {
      for (final t in runTraces)
        if (lostFrames(t.metrics)) t.side == 'base' ? 'baseline' : 'current',
    }.toList()..sort();
    final short = runTraces.any((t) => shortTrace(t.metrics));
    final parts = [
      if (drifts) 'display period',
      if (lostSides.isNotEmpty) 'lost frames on ${lostSides.join(' and ')}',
      if (short) 'short trace',
    ];
    if (parts.isNotEmpty) reasons[run] = parts.join('; ');
  }
  return reasons;
}

bool _drifts(double period, double reference) {
  return (period - reference).abs() > reference * maxPeriodDrift;
}

/// Scene to its blocks: the four traces of the scene in one run.
/// A block that misses any of its four traces is left out.
Map<String, List<Block>> blockTraces(List<Trace> traces) {
  final slots = <(String, String), Map<String, TraceMetrics>>{};
  for (final trace in traces) {
    (slots[(trace.run, trace.scene)] ??= {})['${trace.side}${trace.pair}'] =
        trace.metrics;
  }
  final blocks = <String, List<Block>>{};
  for (final MapEntry(key: (_, scene), value: slot) in slots.entries) {
    if (slot case {
      'base1': final base1,
      'cand1': final cand1,
      'cand2': final cand2,
      'base2': final base2,
    }) {
      (blocks[scene] ??= []).add((
        base1: base1,
        cand1: cand1,
        cand2: cand2,
        base2: base2,
      ));
    }
  }
  return blocks;
}

/// The block's change in average build time, in percent: both current
/// traces against both baseline traces, which cancels an effect of the
/// slot position (spec section 9.5).
double blockChange(Block block) {
  final base = block.base1.average + block.base2.average;
  final cand = block.cand1.average + block.cand2.average;
  return (cand / base - 1) * 100;
}

/// The median of [values], which must not be empty.
double median(List<double> values) {
  final sorted = [...values]..sort();
  final middle = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[middle]
      : (sorted[middle - 1] + sorted[middle]) / 2;
}

/// Rank k of the distribution-free 95% interval [x(k), x(n−k+1)] for the
/// median of [n] values: the largest k with P(Bin(n, ½) ≤ k − 1) ≤ 0.025.
/// Null below 6 values, where no such k exists.
int? ciRank(int n) {
  int? rank;
  var probability = math.pow(0.5, n).toDouble();
  var cumulative = 0.0;
  for (var k = 1; k <= n ~/ 2; k++) {
    cumulative += probability;
    if (cumulative > 0.025) break;
    rank = k;
    probability *= (n - k + 1) / k;
  }
  return rank;
}

/// The 95% interval for the median of [changes], or null below 6 values.
ConfidenceInterval? medianInterval(List<double> changes) {
  final k = ciRank(changes.length);
  if (k == null) return null;
  final sorted = [...changes]..sort();
  return (lower: sorted[k - 1], upper: sorted[sorted.length - k]);
}

List<TraceMetrics> _baseOf(Block b) => [b.base1, b.base2];

List<TraceMetrics> _candOf(Block b) => [b.cand1, b.cand2];

/// Whether the current side keeps the p99 budget for build and for raster
/// (spec section 9.5).
bool withinBudget(List<Block> blocks) {
  bool keeps(double Function(TraceMetrics metrics) metric) {
    double mean(List<TraceMetrics> side) =>
        (metric(side.first) + metric(side.last)) / 2;
    final base = median([for (final b in blocks) ..._baseOf(b).map(metric)]);
    final cand = median([for (final b in blocks) ..._candOf(b).map(metric)]);
    final delta = median([
      for (final b in blocks) mean(_candOf(b)) - mean(_baseOf(b)),
    ]);
    return cand < budget || (base >= budget && delta <= 0);
  }

  return keeps((m) => m.p99Build) && keeps((m) => m.p99Raster);
}

/// Whether the null control's interval exists and contains 0.
bool nullGatePasses(ConfidenceInterval? ci) {
  return ci != null && ci.lower <= 0 && ci.upper >= 0;
}

/// The verdict of one scene other than S2-plain (spec section 9.5).
///
/// [ci] is null when the scene has fewer than 6 blocks.
Verdict sceneVerdict({
  required ConfidenceInterval? ci,
  required bool p99WithinBudget,
}) {
  if (!p99WithinBudget) return Verdict.fail;
  if (ci == null) return Verdict.inconclusive;
  if (ci.upper <= maxAverageRise) return Verdict.pass;
  if (ci.lower > maxAverageRise) return Verdict.fail;
  return Verdict.inconclusive;
}

/// The verdict of a comparison: INVALID, then FAIL, then INCONCLUSIVE,
/// then PASS.
Verdict overallVerdict({
  required bool nullGate,
  required Iterable<Verdict> scenes,
}) {
  if (!nullGate) return Verdict.invalid;
  if (scenes.contains(Verdict.fail)) return Verdict.fail;
  if (scenes.contains(Verdict.inconclusive)) return Verdict.inconclusive;
  return Verdict.pass;
}

/// The exit code for [verdict].
int exitCodeOf(Verdict verdict) {
  return switch (verdict) {
    Verdict.pass => 0,
    Verdict.fail || Verdict.invalid => 1,
    Verdict.inconclusive => 2,
  };
}

/// The one-minute load average in an `uptime` line, or null.
double? loadOf(String uptime) {
  final match = RegExp(r'load averages?: ([\d.]+)').firstMatch(uptime);
  return match == null ? null : double.tryParse(match[1]!);
}

/// Every trace, recorded load, and recorded code state (run folder to
/// state) under [root].
({List<Trace> traces, List<double> loads, Map<String, String> codeStates})
readRuns(Directory root) {
  final traces = <Trace>[];
  final loads = <double>[];
  final codeStates = <String, String>{};
  for (final directory in root.listSync().whereType<Directory>()) {
    final run = directory.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
    final loadFile = File('${directory.path}/load.txt');
    final load = loadFile.existsSync()
        ? loadOf(loadFile.readAsStringSync())
        : null;
    if (load != null) loads.add(load);
    final codeFile = File('${directory.path}/code.txt');
    if (codeFile.existsSync()) {
      codeStates[run] = codeFile.readAsStringSync().trim();
    }
    for (final file in directory.listSync().whereType<File>()) {
      final name = file.uri.pathSegments.last;
      if (!name.endsWith('.summary.json')) continue;
      final summary =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final trace = traceOf(run, name, metricsOf(summary));
      if (trace != null) traces.add(trace);
    }
  }
  return (traces: traces, loads: loads, codeStates: codeStates);
}

/// A report line naming each recorded code state with its run folders, or
/// null when every run folder recorded the same state.
String? codeMismatch(Map<String, String> codeStates) {
  final byState = <String, List<String>>{};
  for (final MapEntry(key: folder, value: state) in codeStates.entries) {
    (byState[state] ??= []).add(folder);
  }
  if (byState.length < 2) return null;
  final states = byState.keys.toList()..sort();
  return 'code states differ: ${[for (final state in states) '$state in ${(byState[state]!..sort()).join(', ')}'].join('; ')}';
}

/// Judges [traces] and returns the report text, the overall verdict, and
/// the verdict of each scene other than S2-plain.
({String text, Verdict verdict, Map<String, Verdict> scenes}) judge(
  List<Trace> traces, {
  required List<double> loads,
  required List<String> scenes,
  Map<String, String> codeStates = const {},
}) {
  final invalid = invalidRuns(traces);
  final valid = [
    for (final trace in traces)
      if (!invalid.containsKey(trace.run)) trace,
  ];
  final blocks = blockTraces(valid);
  final nullCi = medianInterval([
    for (final block in blocks[nullScene] ?? const <Block>[])
      blockChange(block),
  ]);
  final gate = nullGatePasses(nullCi);
  final rows = <String>[];
  final verdicts = <String, Verdict>{};
  for (final scene in {...scenes, ...blocks.keys}.toList()..sort()) {
    final sceneBlocks = blocks[scene] ?? const <Block>[];
    if (sceneBlocks.isEmpty) {
      // An expected scene without valid blocks stays in the report: spec
      // section 9.5 makes fewer than 6 blocks INCONCLUSIVE.
      if (scene != nullScene) verdicts[scene] = Verdict.inconclusive;
      final name = scene == nullScene ? '$scene (null)' : scene;
      final verdict = scene == nullScene ? 'null INVALID' : 'INCONCLUSIVE';
      rows.add('| $name | 0 | - | - | - | - | - | $verdict |');
      continue;
    }
    final ci = medianInterval([for (final b in sceneBlocks) blockChange(b)]);
    final String verdictText;
    if (scene == nullScene) {
      verdictText = gate ? 'null ok' : 'null INVALID';
    } else {
      final verdict = sceneVerdict(
        ci: ci,
        p99WithinBudget: withinBudget(sceneBlocks),
      );
      verdicts[scene] = verdict;
      verdictText = verdict.name.toUpperCase();
    }
    rows.add(_row(scene, sceneBlocks, ci, verdictText));
  }
  final verdict = overallVerdict(nullGate: gate, scenes: verdicts.values);
  final runs = {for (final trace in valid) trace.run};
  final periods = [for (final trace in valid) trace.metrics.period];
  final text = StringBuffer()
    ..writeln(
      'runs ${runs.length}, '
      'load ${_range(loads)}, '
      'interval ${periods.isEmpty ? '-' : _ms(median(periods))} ms, '
      'null resolution '
      '${nullCi == null ? '-' : '±${_pct((nullCi.upper - nullCi.lower) / 2)}%'}',
    );
  if (invalid.isNotEmpty) {
    final names = invalid.keys.toList()..sort();
    text.writeln(
      'invalid runs: '
      '${[for (final run in names) '$run (${invalid[run]})'].join(', ')}',
    );
  }
  final mismatch = codeMismatch(codeStates);
  if (mismatch != null) text.writeln(mismatch);
  text
    ..writeln(
      '| scene | blocks | avg build ms base → cand | median Δ% | 95% CI '
      '| p99 build ms | p99 raster ms | verdict |',
    )
    ..writeln('|---|---|---|---|---|---|---|---|')
    ..writeAll(rows.map((row) => '$row\n'))
    ..writeln('overall: ${verdict.name.toUpperCase()}');
  return (text: text.toString(), verdict: verdict, scenes: verdicts);
}

String _row(
  String scene,
  List<Block> blocks,
  ConfidenceInterval? ci,
  String verdict,
) {
  String sides(double Function(TraceMetrics m) metric) =>
      '${_ms(median([for (final b in blocks) ..._baseOf(b).map(metric)]))} → '
      '${_ms(median([for (final b in blocks) ..._candOf(b).map(metric)]))}';
  final name = scene == nullScene ? '$scene (null)' : scene;
  final change = median([for (final b in blocks) blockChange(b)]);
  final interval = ci == null ? '-' : '[${_pct(ci.lower)}, ${_pct(ci.upper)}]';
  return '| $name | ${blocks.length} | ${sides((m) => m.average)} '
      '| ${_pct(change)} | $interval | ${sides((m) => m.p99Build)} '
      '| ${sides((m) => m.p99Raster)} | $verdict |';
}

String _ms(double value) => value.toStringAsFixed(2);

String _pct(double value) => value.toStringAsFixed(1);

String _range(List<double> values) {
  if (values.isEmpty) return '-';
  final sorted = [...values]..sort();
  return '${sorted.first.toStringAsFixed(1)}–${sorted.last.toStringAsFixed(1)}';
}
```

- [ ] **Step 4: Run it to verify it passes**

Run, from `example/`: `flutter test --no-pub test/tool/perf_abba_test.dart`
Expected: PASS, `+55: All tests passed!`

- [ ] **Step 5: Run the example suite and the analyzer**

Run, from `example/`:

```bash
flutter test --no-pub test/ > build/perf-logs/p5-t2-suite.log 2>&1; echo "exit $?"
tail -1 build/perf-logs/p5-t2-suite.log
flutter analyze --no-pub integration_test test_driver tool test
```

Expected: `exit 0`, `+99: All tests passed!`, and `No issues found!`

- [ ] **Step 6: Commit**

```bash
cd "<repo>"
git add -- example/tool/perf_abba.dart example/test/tool/perf_abba_test.dart
git commit -m "feat(example): build and drive the ABBA benchmark once per call and read summaries from stdout" -- example/tool/perf_abba.dart example/test/tool/perf_abba_test.dart
```

Run: `git show --stat HEAD`
Expected: the two files above and nothing else.

---

### Task 3 (M1-T3): Layout spec section 9 from the design, and the dry run

**Agent:** general-purpose
**Implements:** amendment of layout spec 9.2, 9.4, and 9.5; §1 (dry-run timing), §5 (dry run), §6, §7, §8 (hidden window; evidence)

The design amends layout spec section 9. This task writes the amended subsections from it, sweeps the rest of the spec for the old group wording, and runs one run as the dry run. The design's status line puts the spec rewrite first; the plan puts it last, so the spec describes a tool that exists and passed its dry run.

**Files:**
- Modify: `docs/superpowers/specs/2026-10-01-layout-primitives-design.md` (sections 8, 9.2, 9.4, 9.5, 12, 13)

**Interfaces:**
- Consumes: Task 2's `dart run tool/perf_abba.dart run --runs <n>` and its report; Task 1's app and driver.
- Produces: the amended layout spec; the dry run's wall time, which the main session records in the project memory entry.

- [ ] **Step 1: Rewrite section 9.2**

In the layout spec, replace section 9.2, from its heading `### 9.2 Files` through its last non-blank line, with the block below; the blank line before `### 9.3 Baseline freeze` stays:

````markdown
### 9.2 Files

| Path under `example/` | Role |
|---|---|
| `integration_test/layout_perf_test.dart` | Entry point: reads the first run, the run count, the scene list, and the full-timeline switch from dart-defines, builds the run order, and traces each step |
| `integration_test/perf/perf_host.dart` | The fake theme and `perfHost` |
| `integration_test/perf/perf_scene.dart` | `PerfScene` (`key`, `build(kit)`, `drive`, optional `check`), `PerfStep`, and `runSteps`, the run order |
| `integration_test/perf/perf_scenes.dart` | The scene catalog in run order, S2-plain first: one `PerfScene` per row of the 9.1 table; a new scene is one new entry |
| `integration_test/perf/perf_trace.dart` | Traces a step, summarizes it with `TimelineSummary`, prints the `PERF_RUN` and `PERF_SUMMARY` lines, and drops the timeline unless `run --trace-full` keeps it |
| `integration_test/perf/perf_kit.dart` | `PerfKit` with `row`, `column`, and `container`. `CurrentKit` builds the current API; `BaselineKit` builds the frozen baseline classes. |
| `integration_test/widgets/` | Scene widgets: `AnimatingBoxes` (S4), `GlassCards` and its stripe painter (S5) |
| `integration_test/baseline/` | Frozen baseline classes written by `perf_freeze`; committed |
| `test_driver/perf_driver.dart` | Writes the full timelines that `run --trace-full` keeps; waits up to an hour for the app's tests |
| `tool/perf_freeze.dart` | Freezes the baseline classes (9.3) |
| `tool/perf_abba.dart` | Builds the app and runs one invocation per call, writes each summary line to disk, then pairs, judges, and reports (9.4, 9.5) |

Scenes reach layouts only through the kit, except S2-plain. Moving to a new API changes the two kits and leaves the scenes as they are.
````

- [ ] **Step 2: Rewrite section 9.4**

Replace section 9.4, from its heading `### 9.4 Run protocol` through its last non-blank line, with the block below; the blank line before `### 9.5 Analysis and verdict` stays:

````markdown
### 9.4 Run protocol

- Device: macOS desktop in profile mode decides the pass. A physical iOS or Android device adds data when the owner runs it. Profile mode is disabled on emulators and simulators.
- Trace: two seconds of constant-speed scrolling (S5 scrolls a fixed 2000 px; S4 animates continuously) with semantics off, recording only the `Dart`, `Embedder`, and `GC` timeline streams, under `--endless-trace-buffer`. A trace whose frames cover less than the two-second window minus two frames is a short trace (9.5). Semantics stay off through phase 4, so the metric measures layout work, not accessibility changes.
- Invocation: one call of `perf_abba` builds one profile app (`flutter build macos --profile --target=integration_test/layout_perf_test.dart` with `PERF_FROM=<first run>`, `PERF_RUNS=<run count>`, `PERF_SCENES=<scene list>`, and `PERF_FULL=false` as dart-defines) and launches it once: `flutter drive --profile --endless-trace-buffer -d macos --driver=test_driver/perf_driver.dart --target=integration_test/layout_perf_test.dart --use-application-binary=build/macos/Build/Products/Profile/stratum_ui_example.app`. That one invocation runs every run of the call. The driver waits up to an hour for the app's tests, because 12 runs take about 18 minutes and `integrationDriver` waits 20 minutes by default (section 12).
- Order within an invocation: first a warm-up pass that builds and drives each listed scene once per side without tracing; then, for each run, one block per scene in catalog order (S2-plain, S1, S1-fast, S2, S2-box, S3, S4, S5), each in the order baseline, current, current, baseline. Each side takes one odd and one even slot, so a linear drift and an alternating slot effect cancel within the block (section 9.5). After S5's block, the app shows an empty screen for 2 s without tracing before the next run, so the blur's after-effects stay out of the next run's first traces. S2-plain runs once per run, so every run measures its own noise.
- Each step pumps its scene, runs `check`, pumps 250 ms without tracing, and then traces `drive`. S2-plain's `check` draws S2-box with the current kit on both sides, so the null control's two sides do identical work before every trace. The report key is `r<run>.<scene>.<side>.<pair>`, with side `base` or `cand`.
- Summaries: after each trace, the app summarizes the timeline with flutter_driver's `TimelineSummary`, the code earlier phases ran in the driver, removes the timeline from the binding's report data, and prints one line: `PERF_SUMMARY ` followed by compact JSON with `key`, `average` (`average_frame_build_time_millis`), `p99Build`, `p99Raster`, and `begins` (each frame's build start in microseconds, relative to the first frame). Before a run's first trace it prints `PERF_RUN <run>`. The macOS app runs in the App Sandbox and cannot write under `example/build/`, so the lines travel over the app's stdout, which `flutter drive` forwards with a `flutter: ` prefix. `perf_abba` writes each summary to `build/perf/abba/r<run>/<scene>.<side>.<pair>.summary.json` as it arrives, so a crash loses only the trace in progress, and reports and skips a line that does not parse as a complete summary.
- Full timelines: `run --trace-full <scene> --runs <n>` builds the app with one scene and keeps its timelines in the report data, and the driver writes them as `build/perf/full/<key>.timeline.json`. `n` is at most 4 (16 traces), because the binding sends all report data in one message after the last test (section 12). The mode is diagnostic and never enters a verdict.
- Invalid runs: the app keeps running after a run turns invalid (9.5), and the analysis leaves that run out. A hidden window during a long invocation invalidates every run it overlaps; the report names those runs, and `run --from` adds runs only within the cap.
- Code state: on each `PERF_RUN` line, `perf_abba` records `git rev-parse HEAD` and a hash of `git diff HEAD -- lib example` in the run folder's `code.txt`. `run --from` refuses to add runs whose code state differs from the stored runs, and `report` lists a mismatch. Keep the test window visible: macOS slows a hidden window's frames.
- Load: on each `PERF_RUN` line, `perf_abba` records the `uptime` load averages in the run folder's `load.txt`, and the report shows their range. It never waits for a quiet machine and never discards data for load (owner ruling 2026-10-01).
````

- [ ] **Step 3: Rewrite section 9.5**

Replace section 9.5, from its heading `### 9.5 Analysis and verdict` through the closing fence of its `bash` command block, with the block below; the blank line before `## 10. Phases` stays:

````markdown
### 9.5 Analysis and verdict

- Metrics from `TimelineSummary`: `average_frame_build_time_millis`, `99th_percentile_frame_build_time_millis`, and `99th_percentile_frame_rasterizer_time_millis`.
- A block is the four traces of one scene in one run. Its change in average build time is ((cand.1 + cand.2) / (base.1 + base.2) − 1) × 100%. The phase 3 comparison showed S4 traces alternating by slot (slots 1 and 3 slower than 2 and 4 on both sides), which made per-pair changes bimodal; the block total cancels that effect (owner ruling A, 2026-10-01). A block missing any of its four traces is left out.
- Display check: a trace's display period is the 10th percentile of its frame-start gaps, which skipped frames do not move. A run with any trace whose display period differs by more than 10% from the run's median, or from the whole comparison's median, is invalid. The second test catches a run whose windows all opened on another display.
- Lost-frame check: a trace with fewer than 90% of the frames its window holds at its display period lost frames (a hidden window or a starved machine). Its run is invalid, and the report names the side that lost frames, because frames lost on the current side only can signal a regression.
- Short-trace check: a trace whose frame starts span less than the two-second window minus two frames at its display period lost its first frames from the timeline recorder's buffer. Its run is invalid, with the reason `short trace`.
- The report lists each invalid run with its reason, and the analysis leaves it out. No other data is discarded.
- An expected scene with no valid blocks keeps its row, with 0 blocks and INCONCLUSIVE (S2-plain: null INVALID).
- Confidence interval: the distribution-free 95% interval for the median of the block changes is [x(k), x(n−k+1)] of the sorted changes, where k is the largest rank with P(Bin(n, ½) ≤ k − 1) ≤ 0.025. Fewer than 6 blocks give no interval. 12 blocks give k = 3 (coverage 96.1%), 24 blocks k = 7 (97.7%), 36 blocks k = 12 (97.1%), and 72 blocks k = 28 (95.6%).
- Null gate: the S2-plain interval must contain 0. Otherwise the comparison is INVALID and is run again. Half the width of the S2-plain interval is reported as the comparison's resolution. S2-plain gives one block per run (12 at 12 runs, 24 at 24), so its interval is wider than phase 4's 36 and 72 blocks gave. If the first phase 5 comparison shows a resolution too coarse to trust, the owner decides whether S2-plain runs three times per run.
- Average build, per scene except S2-plain, which only the null gate judges: PASS when the interval's upper bound is at most +5%; FAIL when its lower bound is above +5%; INCONCLUSIVE otherwise, including a scene with fewer than 6 blocks.
- Budget, per scene except S2-plain: the current side's median p99 build and median p99 raster stay below 8.3 ms, or, where the baseline median is already 8.3 ms or more, the median per-block difference of the two sides' mean p99 is at most 0. A scene that misses the budget FAILs, whatever its average-build result.
- Overall: INVALID when the null gate fails; otherwise FAIL when any scene fails; otherwise INCONCLUSIVE when any scene is inconclusive; otherwise PASS. `perf_abba` exits with 0 for PASS, 1 for FAIL or INVALID, and 2 for INCONCLUSIVE.
- Escalation: a comparison starts with 12 runs, which give 12 blocks per scene, S2-plain included (about 18 minutes in one invocation). On INCONCLUSIVE, add 12 runs once, to a cap of 24 runs. `run --from 13 --runs 12` judges the stored runs, measures only the scenes still INCONCLUSIVE plus S2-plain, and builds the app with that scene list, so a scene that passed at 12 runs keeps 12 blocks, an escalated scene has 24, and the null gate judges S2-plain over all 24 runs. `perf_abba` refuses runs beyond the cap, and refuses an escalation when no scene is INCONCLUSIVE. A scene still inconclusive at the cap goes to the owner with its median and interval. The milestone or phase closes on the owner's ruling.
- Pass after phases 3 and 4: an overall PASS, or an owner ruling on the inconclusive scenes at the cap.
- Report: `perf_abba` prints one row per scene (blocks, base and current average build, median change, interval, p99 build, p99 raster, verdict) under a header with the run count, load range, frame interval, and resolution, and writes the same table to `build/perf/abba/report.md`. Measured numbers go to the project memory entry, not into this spec.

Commands, from `example/`:

```bash
dart run tool/perf_freeze.dart <baseline commit> <path>...
rm -rf build/perf/abba
dart run tool/perf_abba.dart run --runs 12
dart run tool/perf_abba.dart run --from 13 --runs 12  # escalation, once
dart run tool/perf_abba.dart report                  # judge stored runs again
dart run tool/perf_abba.dart run --trace-full S4 --runs 2  # full timelines, no verdict
```
````

- [ ] **Step 4: Sweep sections 8, 12, and 13**

In section 8, replace the paragraph that starts `The benchmark tools (section 9) have unit tests` with:

```markdown
The benchmark tools (section 9) have unit tests in `example/test/tool/`: `perf_freeze_test.dart` (a public name is renamed in every copied file, private names and imports stay, the header names the commit) and `perf_abba_test.dart` (blocks by run and scene, and the per-block change; the summary line read back after the `flutter: ` prefix, a cut line skipped and reported, and each summary on disk before the next line; the rank k for 6, 12, 24, 36, and 72 blocks and no interval below 6; the display check on the 10th-percentile frame gap and the separate lost-frame and short-trace checks; each verdict, the budget override, and the overall order INVALID, FAIL, INCONCLUSIVE, PASS; the interval check; the cap; the escalation scenes; the `--trace-full` limit). Run them with `flutter test --no-pub test/tool/` from `example/`.
```

In section 12, replace the bullet that starts ``- `flutter-sdk/packages/integration_test/lib/integration_test.dart:361-362` `` with:

```markdown
- `flutter-sdk/packages/integration_test/lib/integration_test.dart:361-362`: `traceAction` stores the whole timeline under its report key. `flutter-sdk/packages/integration_test/lib/src/_callback_io.dart:36-45`: the binding answers the driver's `request_data` only after every test has ended, with all report data in one message. One stored two-second scene timeline from phase 3 is about 6 MB (pretty-printed). `flutter-sdk/packages/integration_test/lib/integration_test_driver.dart:66`: `integrationDriver` waits 20 minutes by default. A probe on 2026-10-02 built the example's macOS profile app with `package:flutter_driver/flutter_driver.dart` imported in the integration-test target, and one `flutter drive` forwarded a 2260-character summary line and an 8000-character line uncut, each `print` prefixed `flutter: `.
```

At the end of section 13 (the end of the file), after the entry that starts `- 2026-10-02: phase 4 done.`, add:

```markdown
- 2026-10-02: section 9 runs a whole call in one app. Owner rulings: the app summarizes each trace and keeps only the numbers the verdict reads, with `run --trace-full` for one scene's full timelines; one app holds every scene, with a 2 s cool-down after S5; one launch runs all the runs of a call; the escalation measures the scenes still INCONCLUSIVE plus S2-plain. Rejected: one-second traces and several apps at once.
```

- [ ] **Step 5: Check that no old wording is left**

Run, from the repository root:

```bash
grep -n 'g<group>\|per group\|every group\|coverage guard\|perf-apps\|36 for S2-plain\|run, group, and scene' docs/superpowers/specs/2026-10-01-layout-primitives-design.md
```

Expected: no output.

- [ ] **Step 6: Dry run: one run in one invocation**

Keep the test window visible while it runs. Run, from `example/`:

```bash
rm -rf build/perf/abba
mkdir -p build/perf-logs
start=$(date +%s); dart run tool/perf_abba.dart run --runs 1 > build/perf-logs/abba-p5-dry.log 2>&1; echo "exit $? wall $(( $(date +%s) - start )) s"
ls build/perf/abba/r1 | grep -c '\.summary\.json$'
grep -c 'skipped a summary line' build/perf-logs/abba-p5-dry.log
tail -13 build/perf-logs/abba-p5-dry.log
cat build/perf/abba/r1/code.txt
```

Expected: one build and one `flutter drive` invocation finish. The count of summary files is `32` and the count of skipped lines is `0`, so no summary line was cut. The report header reads `runs 1`, and the table has 1 block for every scene, `S2-plain (null)` included. S2-plain's single block gives no interval, so it shows `null INVALID` and the last line is `overall: INVALID`: `exit 1`. On a loaded machine the header may instead read `runs 0` and name `r1` under `invalid runs:` with its reason, with 0 blocks; that also exits 1. Either is a successful dry run. `code.txt` holds the 40-character `HEAD` and the 40-character diff hash on one line.

Wall time: spec section 6's parts for one run give about 173 s (32 traced steps at 2.6 s, 40 s warm-up, 40 s build, 10 s launch). The plan's worktree measured 161 s with a warm build. A build after new dart-defines took about 7 minutes under load averages of 29 to 36. The first dry run in the main tree changes the dart-defines, so expect its build to be the slow one.

Then run: `rm -rf build/perf/abba`

- [ ] **Step 7: Commit the spec**

```bash
cd "<repo>"
git add -- docs/superpowers/specs/2026-10-01-layout-primitives-design.md
git commit -m "docs(layout): run the benchmark as one app per call in section 9" -- docs/superpowers/specs/2026-10-01-layout-primitives-design.md
```

Run: `git show --stat HEAD`
Expected: the layout spec only.

- [ ] **Step 8: Report the dry run**

Report to the main session: the exit line of Step 6 (`exit <code> wall <s> s`), the report's header and `overall:` line, the load in `build/perf-logs/abba-p5-dry.log` (`run 1: ...`), and whether the build was cold. The main session records the numbers in the project memory entry; they stay out of the spec and the repository.

---

## Coverage

Requirement ids name the sections of the design `docs/superpowers/specs/2026-10-02-benchmark-single-app-design.md` (`§1` to `§9`); the amendment row names layout spec section 9.

| requirement | task(s) | note |
|-------------|---------|------|
| §1 goal: 12 runs in about 18 minutes, same precision; verdict tests unchanged apart from keys and folders | M1-T1, M1-T2, M1-T3 | dry-run timing in T3; the 12-run timing is the first phase 5 comparison, after `perf_freeze`, outside this plan |
| §2 ruling: summaries only, `--trace-full` for one scene | M1-T1, M1-T2 | |
| §2 ruling: one app, 2 s cool-down after S5 | M1-T1 | |
| §2 ruling: one invocation runs all runs of a call | M1-T1, M1-T2 | driver waits one hour (Review Focus) |
| §2 ruling: the escalation measures S2-plain | M1-T2 | |
| §3.1 run order inside the app; key `r<run>.<scene>.<side>.<pair>` | M1-T1 | groups removed |
| §3.2 per-trace summary; timeline removed from `reportData` | M1-T1 | |
| §3.3 transport: stdout reader, per-run files, `PERF_RUN` load and code, cut line skipped | M1-T1, M1-T2 | `flutter: ` prefix (Review Focus) |
| §3.4 coverage check moved to `perf_abba` as `short trace`; invalid run left out | M1-T1, M1-T2 | |
| §3.5 escalation: INCONCLUSIVE scenes plus S2-plain, one build, cap 24 | M1-T2 | refuses when no scene is INCONCLUSIVE |
| §3.6 full-timeline mode, at most 4 runs | M1-T1, M1-T2 | driver writes `build/perf/full/<key>.timeline.json` |
| §4 files | M1-T1, M1-T2 | plus `test/perf/perf_trace_test.dart` |
| §5 testing, unit cases | M1-T1, M1-T2 | |
| §5 testing, dry run | M1-T3 | |
| §6 estimates | M1-T3 | measured against the section 6 parts |
| §7 effect on S2-plain blocks | M1-T3 | layout spec 9.5 null-gate text; the owner decides after the first phase 5 comparison |
| §8 risk: line cut by `flutter drive` | M1-T2 | spike (b) passed: 2260 and 8000 characters uncut; no fallback |
| §8 risk: `TimelineSummary` import compiles on macOS | M1-T1 | spike (a) passed; T3's dry run builds it |
| §8 risk: hidden window over a long invocation | M1-T2, M1-T3 | existing display and lost-frame checks name the runs; spec 9.4 text |
| §9 out of scope | — | nothing to build |
| Layout spec 9.2, 9.4, 9.5 amended from the design | M1-T3 | also sections 8, 12, and 13 |
