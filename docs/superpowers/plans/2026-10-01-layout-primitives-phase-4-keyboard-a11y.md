# Layout Primitives Phase 4: Keyboard and Accessibility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the layout family keyboard and screen-reader paths on desktop and web (context-menu key, focus-scoped shortcuts, roving focus groups, focusable scroll views), replace `scrollable: bool` with `scroll: StratumScroll`, honor the app's reduced-motion setting, and show with the per-block ABBA benchmark that no scene got slower than the phase 3 tip.

**Architecture:** Task 1 first fixes the benchmark tool (per-block estimate, display-period, lost-frame, S2-plain, and code-state checks) and freezes the phase 3 tip as the baseline, so every later library change is measured against it. `StratumScroll` (new, `common/model/scroll.dart`) replaces `scrollable` on the five box layouts; `BoxLayout` builds a private `_BoxScrollView` in the `scrollBuilder` hook, with an opt-in `fillViewport` stretch, and `AnimatedStyledBox` moves `ratio` to the viewport when a scroll view is present. `StratumInkWell` gains the context-menu key and Shift+F10 (K1), a focus-scoped `shortcuts` map built as one `CallbackShortcuts` (K2, with an outer `Focus` when no activation callback exists), and a focus keep-alive. `StratumFocusGroup` (K3, `layout/focus_group.dart`) wraps a column, row, or wrap in a `FocusTraversalGroup` whose policy sorts the group down to one Tab stop, plus its own arrow, Home, and End handler. `ScrollFocus` (K4, `layout/scroll_frame.dart`) owns the viewport node, keys, and ring outside the box's clip and hands the scroll view its controller through an inherited scope. A non-exported `common/text_entry_guard.dart` holds the one check that K2, K3, and K4 use to leave keys to a focused text field.

**Tech Stack:** Flutter 3.47.3, Dart ^3.13.3, `flutter_test`, very_good_analysis 11 (library), `flutter_lints` (example), `integration_test` and `flutter_driver` (SDK packages in `example/`), macOS desktop in profile mode.

**Spec:** `docs/superpowers/specs/2026-10-01-layout-primitives-design.md`: the phase 4 items of sections 2, 4, 5, 6, 7, 8, 9 (9.2 to 9.5), 10, 11, and 12, and the last entry of section 13. Project memory: `profile/memory/project_stratum_ui_layout_primitives.md` in the NTD OS root, sections "Phase 4 brainstorm rulings" and "Phase 3 ABBA rerun". PRD user stories in scope: none (`docs/prds/` holds no phase 4 story).

**Anchor base:** master fe31fdc. Its `lib/` equals the phase 3 tip e5f84d0 (`git log e5f84d0..fe31fdc -- lib` is empty).

**Preconditions:**
- `flutter test --no-pub test/src/components/common/ test/src/themes/` passes on the anchor: 472 tests (verified on fe31fdc).
- From `example/`, `flutter test --no-pub test/` passes (71 tests) and `flutter analyze --no-pub integration_test test_driver tool test` reports `No issues found!` (verified on fe31fdc).
- `flutter analyze --no-pub lib` reports 0 errors; its 50 infos sit in files this plan does not touch.
- The owner's work in progress is the one Global Constraints lists, and none of it is staged by this plan.

This plan was verified in a scratch worktree on fe31fdc: every task's code compiled, each RED step failed as stated, and each GREEN step passed. After Task 8 the library suite passed 540 tests, `flutter analyze --no-pub lib` reported 0 errors (the same 50 infos), and the example suite passed 78 tests with `No issues found!`. No profile benchmark was run while writing it.

## Global Constraints

- Work in the main working tree on `master`. Owner work in progress stays out of every commit: the staged rename `assets/themes/example.yaml -> assets/themes/default/theme.yaml`; the staged `lib/src/components/common/utility/slot.dart` and `lib/src/components/common/utility/utility.dart`; the modified `lib/src/components/common/common.dart`, `lib/stratum_ui.dart`, `pubspec.yaml`, and `example/pubspec.lock`; and the untracked `example/macos/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/` and `example/macos/Runner.xcworkspace/xcshareddata/swiftpm/`.
- Commit with explicit paths only: `git add -- <paths>` (or `git rm -- <paths>`), then `git commit -m "<message>" -- <paths>`. `git commit -- <paths>` commits only those paths, so the owner's staged files stay staged and uncommitted. Write each path literally; zsh does not word-split a variable into several paths. Conventional Commits with a scope; no `Co-Authored-By` line and no AI attribution.
- Constructors use the `new` form: `const new(` for the unnamed constructor and `const new builder(` for a named one. `new.builder(` fails with `new_constructor_dot_name`.
- Desktop-scrollbar tests wrap the widget in `Theme(data: ThemeData(platform: TargetPlatform.macOS), child: ...)`, because `MaterialScrollBehavior` reads the platform from the theme and the cached fallback theme keeps the first test's platform.
- `ScrollCacheExtent` is exported only by `package:flutter/rendering.dart`; a file that names it adds `import 'package:flutter/rendering.dart' show ScrollCacheExtent;`.
- Library files and their tests import the barrel `package:stratum_ui/src/src.dart`. Three library files are exported by no barrel and are imported directly where needed: `layout/scroll_frame.dart`, `layout/focus_group.dart` (the barrel `layout/layout.dart` exports only its `StratumFocusGroup`), and `common/text_entry_guard.dart`. `style/animated_styled_box.dart` and its test keep their narrow imports.
- Lints in `lib/` come from very_good_analysis 11: package imports only, sorted directives, constructors before fields, single quotes, lines at most 80 characters. Every new or changed file analyzes with no new issue.
- Do not run `dart format` on a file the task does not write whole; the repository has formatting drift outside phase 4. Code blocks in this plan analyze clean as written; paste them unchanged.
- Files under `example/` that import `package:stratum_ui/src/src.dart` start with `// ignore_for_file: implementation_imports`. Imports between `integration_test/`, `test/`, and `tool/` files are relative.
- Run tests with `flutter test --no-pub <path>` and the analyzer with `flutter analyze --no-pub <paths>`. Run each RED step one file at a time: a compile error in one file breaks the others in the same run. Run every command in the foreground. A command likely to take over a minute writes to a log under `build/` at the repository root or `example/build/perf-logs/` (both ignored by git), and the step reads the log's tail.
- Spec values, verbatim: `StratumScroll` holds `direction`, `fillViewport` (default false), `reverse`, `controller`, `primary`, `physics`, `showScrollbar`, `keyboardDismissBehavior`, and `restorationId`, with `assert(!(controller != null && (primary ?? false)))`; `focusable: null` resolves through `defaultScrollFocusable({required bool isWeb, required TargetPlatform platform})`, which returns `isWeb || {macOS, windows, linux}.contains(platform)`; K4 scrolls a line of 50 px and a page of 0.8 of the viewport; End "jumps again after each frame until the extent stops changing, at most three times"; the semantics label falls back from `secondaryTapSemanticsLabel` to `MaterialLocalizations.showMenuTooltip` to `'Show menu'`.
- Benchmark values, verbatim (spec 9.4, 9.5): a block is "the four traces of one scene in one invocation"; its change is "((cand.1 + cand.2) / (base.1 + base.2) − 1) × 100%"; the display period is "the 10th percentile of its frame-start gaps"; a run is invalid when a display period "differs by more than 10% from the run's median, or from the whole comparison's median", or when a trace has "fewer than 90% of the frames its window holds at its display period"; "a comparison starts with 12 runs"; "a cap of 24 runs (24 blocks per scene)"; exit codes "0 for PASS, 1 for FAIL or INVALID, and 2 for INCONCLUSIVE"; `code.txt` records "`git rev-parse HEAD` and a hash of `git diff HEAD -- lib example`". Measure under normal multitasking: never wait for a quiet machine and never discard data for load (owner ruling 2026-10-01). Semantics stay off in every scene.
- Never edit `example/integration_test/baseline/` by hand; run `tool/perf_freeze.dart` again.
- Measured numbers go to `profile/memory/project_stratum_ui_layout_primitives.md` in the NTD OS root (outside this repository), never into the spec or the repository.
- `.worktrees/` is git-ignored; never stage it.

## Review Focus

- A tappable box that also scrolls (`interaction` with `onTap` and `scroll` set) on desktop: a person expects one Tab stop, the tap surface, whose arrows scroll the box, and no second node from `ScrollFocus`. Pinned in Task 7 ("a tappable scrolling box scrolls by keys on its tap surface").
- A Ctrl or Cmd binding in `shortcuts` while a text field inside the surface has focus: a person expects the command to fire, because only unmodified keys belong to the field. Pinned in Task 5 ("an unmodified binding is skipped inside a TextField", which also asserts that the control binding fires).
- A chat list with `reverse: true`: a person expects Home to show the first item (offset 0), not the item at the top of the screen. Pinned in Task 7 ("Home goes to the first item of a reversed list").
- A row with `onSecondaryTap` whose `disabled` flag toggles while a child holds state: a person expects the child to keep its `State`, because the K1 bindings must not change the tree. Pinned in Task 4 ("toggling disabled keeps the child State" in the context-menu group).
- A desktop scroll view with no `StratumThemeApplication` above it: a person expects it to take focus and scroll by keyboard instead of throwing, because `FocusSpread` reads the theme. Pinned in Task 7 ("a desktop list without a theme takes focus and builds no ring").

## File map

| File | Task | Responsibility |
|---|---|---|
| `example/tool/perf_abba.dart`, `example/test/tool/perf_abba_test.dart` | 1 | Per-block estimate, display-period and lost-frame checks, code state, cap of 24 runs |
| `example/integration_test/perf/perf_scenes.dart`, `example/test/perf/perf_scenes_test.dart` | 1 | S2-plain's check draws S2-box with the current kit |
| `example/integration_test/baseline/` (generated), `example/integration_test/perf/perf_kit.dart`, `example/test/perf/perf_kit_test.dart` | 1 | Frozen fe31fdc layouts and the `BaselineKit` on them |
| `lib/src/components/common/model/scroll.dart`, `model/model.dart` | 2 | `StratumScroll` and its export |
| `lib/src/components/common/layout/box_layout.dart` | 2, 4, 5, 7 | `scroll` and `_BoxScrollView` (2); forwards `secondaryTapSemanticsLabel` (4) and `shortcuts` (5); `ScrollFocus` in `boxBuilder` (7) |
| `lib/src/components/common/layout/{column,row,stack,wrap,container}_layout.dart` | 2, 6 | `super.scroll` (2); `focusGroup` on column, row, and wrap (6) |
| `lib/src/components/common/style/animated_styled_box.dart` | 2, 3 | Viewport `AspectRatio` (2); `MediaQuery` reduced-motion read (3) |
| `lib/src/components/common/ink_well.dart`, `model/interaction.dart` | 4, 5 | K1 (4); K2, shortcut-only focus, keep-alive (5) |
| `lib/src/components/common/text_entry_guard.dart` | 5 | `primaryFocusInEditableText`, not exported |
| `lib/src/components/common/layout/focus_group.dart`, `layout/layout.dart` | 6 | `StratumFocusGroup`, `FocusGroupFrame`, and the traversal policy |
| `lib/src/components/common/layout/scroll_frame.dart` | 7 | `defaultScrollFocusable` and `ScrollFocus` |
| `lib/src/components/common/layout/{list_view,grid_view,custom_scroll_view}_layout.dart` | 7 | `focusable`, `semanticsLabel`, and `ScrollFocus` around the box |
| `test/src/components/common/model/scroll_test.dart` | 2 | `StratumScroll` assertion |
| `test/src/components/common/layout/{box,column,row,stack,wrap}_layout_test.dart` | 2, 4, 5 | Ported `scrollable` cases and the new scroll cases |
| `test/src/components/common/style/animated_styled_box_test.dart` | 2, 3 | Viewport ratio; `MediaQuery` reduced motion |
| `test/src/components/common/ink_well_test.dart` | 4, 5 | K1, K2, shortcut-only focus, keep-alive |
| `test/src/components/common/layout/focus_group_test.dart` | 6 | K3 |
| `test/src/components/common/layout/scroll_frame_test.dart` | 7 | K4 |
| `test/src/components/common/layout/a11y_guidelines_test.dart` | 8 | Guideline checks |

## Dependencies

| task | depends-on | agent |
|------|------------|-------|
| T1 | — | general-purpose |
| T2 | T1 | general-purpose |
| T3 | T2 | general-purpose |
| T4 | T3 | general-purpose |
| T5 | T4 | general-purpose |
| T6 | T5 | general-purpose |
| T7 | T6 | general-purpose |
| T8 | T7 | general-purpose |
| T9 | T8 | main session |

Run the tasks in this order in the main working tree. T2 to T7 edit shared files (`box_layout.dart` in T2, T4, T5, and T7; `ink_well.dart` in T4 and T5; the layouts in T2 and T6), and T6 and T7 use T5's text-entry guard. T1 freezes from commit fe31fdc, so its baseline does not depend on later library changes, but it lands first so the tool is ready before the code it measures moves (owner-approved order).

---
### Task 1: Per-block benchmark estimate, run checks, and the phase 3 tip baseline

**Agent:** general-purpose
**Implements:** P4-1

The phase 3 comparison showed S4 traces alternating by slot (slots 1 and 3 slower than 2 and 4 on both sides), which made per-pair changes bimodal; the block total cancels that effect (owner ruling A, 2026-10-01). The median frame gap read a run whose frames collapsed (19 to 130 per window) as a display change; the 10th-percentile gap keeps the display period, and a separate frame count catches lost frames and names the side that lost them.

**Files:**
- Modify: `example/tool/perf_abba.dart` (whole file)
- Modify: `example/test/tool/perf_abba_test.dart` (whole file)
- Modify: `example/integration_test/perf/perf_scenes.dart` (S2-plain's `check`)
- Modify: `example/test/perf/perf_scenes_test.dart` (one new test)
- Regenerate: `example/integration_test/baseline/` with `tool/perf_freeze.dart`: seven frozen files of fe31fdc and `baseline.dart`; `gesture_row_layout.dart` and `gesture_container_layout.dart` disappear
- Modify: `example/integration_test/perf/perf_kit.dart` (whole file)
- Modify: `example/test/perf/perf_kit_test.dart` (whole file)

**Interfaces:**
- Consumes: `perfScene`, `perfHost`, `CurrentKit`, and the test's `_RefusingKit`; the `perf_freeze` CLI; `git` and `shasum` on the path.
- Produces, in `tool/perf_abba.dart`: `typedef TraceMetrics = ({double average, double p99Build, double p99Raster, double period, int frames})`; `typedef Block = ({TraceMetrics base1, TraceMetrics cand1, TraceMetrics cand2, TraceMetrics base2})`; `Map<String, List<Block>> blockTraces(List<Trace> traces)`; `double blockChange(Block block)`; `bool lostFrames(TraceMetrics metrics)`; `Map<String, String> invalidRuns(List<Trace> traces)` (run `r<n>` to its reason); `bool runInvalid(List<Trace> traces, int run)`; `bool withinBudget(List<Block> blocks)`; `String? codeStateError(Map<String, String> stored, String current)`; `String? codeMismatch(Map<String, String> codeStates)`; `Future<String> codeState()`; `readRuns` also returns `codeStates`; `judge(..., {Map<String, String> codeStates = const {}})`; `const maxRuns = 24`, `minFrameShare = 0.9`, `maxPeriodDrift = 0.1`, `traceWindowMs = 2000.0`. Removed: `TracePair`, `pairTraces`, `averageChange`, `runLostFrames`, `maxIntervalDrift`.
- Produces, in `integration_test/perf/perf_kit.dart`: `BaselineKit.row` builds `BaselineRowLayout(interaction: BaselineStratumInteraction(onTap: onTap))` for a tap and `BaselineRowLayout(interaction: null)` otherwise.
- Produces the frozen classes `BaselineAnimatedStyledBox`, `BaselineBoxLayout`, `BaselineColumnLayout`, `BaselineContainerLayout`, `BaselineRowLayout`, `BaselineStratumInkWell`, `BaselineStratumInteraction` (typedefs `BaselineStyledBoxBuilder`, `BaselineStyledScrollBuilder`), which Task 9 measures against.

- [ ] **Step 1: Write the failing tool test**

Replace all of `example/test/tool/perf_abba_test.dart` with:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/perf_abba.dart' hide main;

TraceMetrics _metrics({
  double average = 0.25,
  double p99Build = 0.5,
  double p99Raster = 3.5,
  double period = 6.94,
  int frames = 288,
}) {
  return (
    average: average,
    p99Build: p99Build,
    p99Raster: p99Raster,
    period: period,
    frames: frames,
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
}) {
  return (
    run: run,
    scene: scene,
    side: side,
    pair: pair,
    metrics: _metrics(average: average, period: period, frames: frames),
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
/// r1g1 on.
List<Trace> _blocks(String scene, List<double> changes) {
  return [
    for (var i = 0; i < changes.length; i++)
      ..._block('r${i + 1}g1', scene, cand: 0.2 * (1 + changes[i] / 100)),
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
          'average_frame_build_time_millis': 0.31,
          '99th_percentile_frame_build_time_millis': 1.02,
          '99th_percentile_frame_rasterizer_time_millis': 3.4,
          'frame_begin_times': [for (var i = 0; i < 10; i++) i * 6940, 100000],
        });
        expect(metrics.average, 0.31);
        expect(metrics.p99Build, 1.02);
        expect(metrics.p99Raster, 3.4);
        expect(metrics.frames, 11);
        expect(metrics.period, closeTo(6.94, 1e-9));
      },
    );

    test('takes the 10th-percentile gap, which skipped frames do not move', () {
      // Nine of ten gaps skip a frame: the median gap would read 13.88 ms.
      final metrics = metricsOf({
        'average_frame_build_time_millis': 0.31,
        '99th_percentile_frame_build_time_millis': 1.02,
        '99th_percentile_frame_rasterizer_time_millis': 3.4,
        'frame_begin_times': [
          0,
          6940,
          for (var i = 1; i <= 9; i++) 6940 + i * 13880,
        ],
      });
      expect(metrics.period, closeTo(6.94, 1e-9));
    });
  });

  group('traceOf', () {
    test('reads scene, side, and pair from the report key', () {
      final trace = traceOf(
        'r1g2',
        'S2-plain.base.2.timeline_summary.json',
        _metrics(),
      );
      expect(trace?.run, 'r1g2');
      expect(trace?.scene, 'S2-plain');
      expect(trace?.side, 'base');
      expect(trace?.pair, 2);
    });

    test('skips files that are not ABBA summaries', () {
      expect(traceOf('r1g1', 'S1.timeline_summary.json', _metrics()), isNull);
      expect(
        traceOf('r1g1', 'S1.left.1.timeline_summary.json', _metrics()),
        isNull,
      );
      expect(traceOf('r1g1', 'S1.base.1.timeline.json', _metrics()), isNull);
    });
  });

  group('blockTraces', () {
    test('makes one block per run folder and scene', () {
      final blocks = blockTraces([
        ..._block('r1g1', 'S1', base: 0.2, cand: 0.3),
        ..._block('r1g2', 'S2-plain'),
        ..._block('r2g1', 'S1', base: 0.4, cand: 0.4),
        ..._block('r1g1', 'S2'),
      ]);
      expect(blocks.keys, unorderedEquals(['S1', 'S2', 'S2-plain']));
      expect([
        for (final block in blocks['S1']!) block.cand1.average,
      ], unorderedEquals([0.3, 0.4]));
    });

    test('leaves out a block that misses any of its four traces', () {
      final blocks = blockTraces([
        ..._block('r1g1', 'S1'),
        ..._block('r2g1', 'S1').take(3),
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

  group('invalidRuns', () {
    test("marks a run invalid when one trace's display period drifts", () {
      expect(
        invalidRuns([
          ..._block('r1g1', 'S1'),
          _trace('r1g1', 'S2', 'base', 1),
          _trace('r1g1', 'S2', 'cand', 1, period: 16.67),
          ..._block('r2g1', 'S1'),
        ]).keys,
        ['r1'],
      );
    });

    test('marks a run invalid when one whole invocation ran on another '
        'display', () {
      expect(
        invalidRuns([
          ..._block('r1g1', 'S1'),
          ..._block('r1g2', 'S3'),
          _trace('r1g3', 'S4', 'base', 1, period: 16.67),
          _trace('r1g3', 'S4', 'cand', 1, period: 16.67),
          ..._block('r2g1', 'S1'),
        ]),
        {'r1': 'display period'},
      );
    });

    test('marks a run invalid when all of it ran on another display', () {
      expect(
        invalidRuns([
          ..._block('r1g1', 'S1'),
          ..._block('r2g1', 'S1'),
          ..._block('r3g1', 'S1'),
          _trace('r4g1', 'S1', 'base', 1, period: 16.67),
          _trace('r4g1', 'S1', 'cand', 1, period: 16.67),
        ]).keys,
        ['r4'],
      );
    });

    test('marks a run invalid on lost frames and names the side', () {
      expect(
        invalidRuns([
          ..._block('r1g1', 'S1'),
          _trace('r2g1', 'S4', 'base', 1),
          _trace('r2g1', 'S4', 'cand', 1, frames: 120),
          _trace('r3g1', 'S4', 'base', 1, frames: 19),
          _trace('r3g1', 'S4', 'cand', 1, frames: 130),
        ]),
        {
          'r2': 'lost frames on current',
          'r3': 'lost frames on baseline and current',
        },
      );
    });
  });

  group('runInvalid', () {
    test('is true once a trace of the run lost frames', () {
      final traces = [
        ..._block('r6g1', 'S1'),
        _trace('r7g1', 'S1', 'base', 1),
        _trace('r7g1', 'S1', 'cand', 1, frames: 40),
      ];
      expect(runInvalid(traces, 7), isTrue);
      expect(runInvalid(traces, 6), isFalse);
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
          _trace('r99g1', 'S4', 'base', 1),
          _trace('r99g1', 'S4', 'cand', 1, frames: 30),
          _trace('r99g1', 'S4', 'cand', 2),
          _trace('r99g1', 'S4', 'base', 2),
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
        codeStates: const {
          'r1g1': 'abc 111',
          'r2g1': 'abc 111',
          'r3g1': 'def 222',
        },
      );
      expect(
        result.text,
        contains('code states differ: abc 111 in r1g1, r2g1; def 222 in r3g1'),
      );
    });
  });

  group('codeStateError', () {
    test('accepts runs on the stored code state', () {
      expect(codeStateError(const {}, 'abc 111'), isNull);
      expect(codeStateError(const {'r1g1': 'abc 111'}, 'abc 111'), isNull);
    });

    test('refuses runs on another code state', () {
      expect(
        codeStateError(const {'r1g1': 'abc 111', 'r1g2': 'abc 222'}, 'abc 111'),
        contains('r1g2'),
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
      Directory('${root.path}/r2g3').createSync();
      expect(clashingRuns(root, from: 1, runs: 6), ['${root.path}/r2g3']);
      expect(clashingRuns(root, from: 3, runs: 4), isEmpty);
    });
  });

  group('prebuilt apps', () {
    test('builds one profile app per group with its PERF_GROUP', () {
      expect(buildArgs(2), [
        'build',
        'macos',
        '--profile',
        '--target=integration_test/layout_perf_test.dart',
        '--dart-define=PERF_GROUP=2',
      ]);
    });

    test('drives a group on its prebuilt app', () {
      final args = driveArgs(3);
      expect(args, contains('--use-application-binary=build/perf-apps/g3.app'));
      expect(args, contains('--endless-trace-buffer'));
      expect(args, contains('--driver=test_driver/perf_driver.dart'));
      expect(args, contains('--target=integration_test/layout_perf_test.dart'));
    });
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run, from `example/`: `flutter test --no-pub test/tool/perf_abba_test.dart`
Expected: FAIL at compile time, with `Error: A value of type '({double average, int frames, double p99Build, double p99Raster, double period})' can't be returned from a function with return type '({double average, double interval, double p99Build, double p99Raster})'` and `Error: Method not found: 'blockTraces'`.

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

/// Scene groups per run: the keys of `perfGroups` in
/// `integration_test/perf/perf_scenes.dart`.
const groups = [1, 2, 3];

/// Scenes per group: `perfGroups` in
/// `integration_test/perf/perf_scenes.dart`.
const groupScenes = <int, List<String>>{
  1: ['S2-plain', 'S1', 'S1-fast', 'S2'],
  2: ['S2-plain', 'S2-box', 'S3'],
  3: ['S2-plain', 'S4', 'S5'],
};

/// Most runs one comparison holds: 24 blocks per scene (spec section 9.5).
const maxRuns = 24;

/// The null-control scene, judged only by the null gate.
const nullScene = 'S2-plain';

/// Root of the run folders, relative to `example/`.
const abbaRoot = 'build/perf/abba';

/// Folder of the prebuilt profile apps, one per group, relative to
/// `example/`.
const appsRoot = 'build/perf-apps';

/// Where `flutter build macos --profile` writes the app.
const _builtApp = 'build/macos/Build/Products/Profile/stratum_ui_example.app';

const _target = '--target=integration_test/layout_perf_test.dart';

const _usage =
    'usage: dart run tool/perf_abba.dart report\n'
    '       dart run tool/perf_abba.dart run --runs <n> [--from <first>]';

/// The verdict of a scene or a comparison (spec section 9.5).
enum Verdict { pass, fail, inconclusive, invalid }

/// The metrics read from one `TimelineSummary`. The display period is the
/// 10th percentile of the gaps between frame starts, in milliseconds;
/// [frames] counts the frames the trace holds.
typedef TraceMetrics = ({
  double average,
  double p99Build,
  double p99Raster,
  double period,
  int frames,
});

/// One trace: its run folder (`r<run>g<group>`) and its report key.
typedef Trace = ({
  String run,
  String scene,
  String side,
  int pair,
  TraceMetrics metrics,
});

/// The four traces of one scene in one invocation, in the order baseline,
/// current, current, baseline (spec section 9.4).
typedef Block = ({
  TraceMetrics base1,
  TraceMetrics cand1,
  TraceMetrics cand2,
  TraceMetrics base2,
});

/// A 95% interval for the median block change, in percent.
typedef ConfidenceInterval = ({double lower, double upper});

/// Runs and judges the in-process ABBA benchmark (spec section 9.5).
///
/// Usage, from `example/`:
/// - `dart run tool/perf_abba.dart run --runs 12` runs `flutter drive` once
///   per run and group, recording `uptime` and the code state before each,
///   then reports.
/// - `dart run tool/perf_abba.dart run --from 13 --runs 12` adds the one
///   escalation, up to 24 runs (24 blocks per scene).
/// - `dart run tool/perf_abba.dart report` judges the stored runs again.
///
/// Prints the report, writes it to `build/perf/abba/report.md`, and exits
/// with 0 for PASS, 1 for FAIL or INVALID, and 2 for INCONCLUSIVE.
Future<void> main(List<String> args) async {
  switch (args) {
    case ['report']:
      exitCode = _report();
    case ['run', ...final options] when _option(options, '--runs') != null:
      exitCode = await _run(
        from: _option(options, '--from') ?? 1,
        runs: _option(options, '--runs')!,
      );
    default:
      stderr.writeln(_usage);
      exitCode = 64;
  }
}

int? _option(List<String> options, String name) {
  final index = options.indexOf(name);
  return index < 0 || index + 1 >= options.length
      ? null
      : int.tryParse(options[index + 1]);
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

/// Arguments that build [group]'s profile app with its `PERF_GROUP`.
List<String> buildArgs(int group) {
  return [
    'build',
    'macos',
    '--profile',
    _target,
    '--dart-define=PERF_GROUP=$group',
  ];
}

/// Arguments that run [group] on its prebuilt app, so no invocation builds.
List<String> driveArgs(int group) {
  return [
    'drive',
    '--profile',
    '--endless-trace-buffer',
    '-d',
    'macos',
    '--driver=test_driver/perf_driver.dart',
    _target,
    '--use-application-binary=$appsRoot/g$group.app',
  ];
}

/// Whether run [run] already holds a trace that leaves the whole run out
/// (spec section 9.5).
bool runInvalid(List<Trace> traces, int run) {
  return invalidRuns(traces).containsKey('r$run');
}

/// Run folders under [root] that runs [from] to `from + runs - 1` would
/// write into but that exist already.
List<String> clashingRuns(
  Directory root, {
  required int from,
  required int runs,
}) {
  return [
    for (var run = from; run < from + runs; run++)
      for (final group in groups)
        if (Directory('${root.path}/r${run}g$group').existsSync())
          '${root.path}/r${run}g$group',
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

Future<int> _run({required int from, required int runs}) async {
  final rangeError = runRangeError(from: from, runs: runs);
  if (rangeError != null) {
    stderr.writeln(rangeError);
    return 64;
  }
  final clashes = clashingRuns(Directory(abbaRoot), from: from, runs: runs);
  if (clashes.isNotEmpty) {
    stderr.writeln(
      '${clashes.join(', ')} exist: rm -rf $abbaRoot for a new comparison, '
      'or pass --from after the last stored run',
    );
    return 64;
  }
  final code = await codeState();
  final root = Directory(abbaRoot);
  if (root.existsSync()) {
    final stateError = codeStateError(readRuns(root).codeStates, code);
    if (stateError != null) {
      stderr.writeln(stateError);
      return 64;
    }
  }
  // One build per group for the whole call: every invocation of a group
  // then runs the same binary, and no invocation pays for a build.
  for (final group in groups) {
    final build = await Process.start(
      'flutter',
      buildArgs(group),
      mode: ProcessStartMode.inheritStdio,
    );
    if (await build.exitCode != 0) {
      stderr.writeln('flutter build failed for group $group');
      return 1;
    }
    final app = '$appsRoot/g$group.app';
    final copy = await Process.run('sh', [
      '-c',
      'rm -rf "$app" && mkdir -p $appsRoot && cp -R "$_builtApp" "$app"',
    ]);
    if (copy.exitCode != 0) {
      stderr.writeln('could not copy the group $group app: ${copy.stderr}');
      return 1;
    }
  }
  stdout.writeln('Keep the test window visible until the run ends.');
  for (var run = from; run < from + runs; run++) {
    for (final group in groups) {
      final directory = Directory('$abbaRoot/r${run}g$group')
        ..createSync(recursive: true);
      File('${directory.path}/code.txt').writeAsStringSync(code);
      final uptime = await Process.run('uptime', const []);
      final load = (uptime.stdout as String).trim();
      File('${directory.path}/load.txt').writeAsStringSync(load);
      stdout.writeln('run $run group $group: $load');
      final drive = await Process.start(
        'flutter',
        driveArgs(group),
        environment: {'PERF_RUN': '$run', 'PERF_GROUP': '$group'},
        mode: ProcessStartMode.inheritStdio,
      );
      final exit = await drive.exitCode;
      if (exit != 0) {
        stderr.writeln(
          'flutter drive exited $exit on run $run group $group; '
          'rm -rf $abbaRoot/r${run}g* and pass --from $run to continue',
        );
        return 1;
      }
      if (runInvalid(readRuns(root).traces, run)) {
        stderr.writeln(
          'run $run is invalid after group $group '
          '(${invalidRuns(readRuns(root).traces)['r$run']}); '
          'its other groups are skipped',
        );
        break;
      }
    }
  }
  return _report();
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
    scenes: [for (final keys in groupScenes.values) ...keys],
    codeStates: codeStates,
  );
  stdout.write(result.text);
  File('$abbaRoot/report.md').writeAsStringSync(result.text);
  return exitCodeOf(result.verdict);
}

/// Reads the metrics of one `*.timeline_summary.json` map.
TraceMetrics metricsOf(Map<String, dynamic> summary) {
  final begins = (summary['frame_begin_times'] as List).cast<num>();
  double read(String key) => (summary[key] as num).toDouble();
  final gaps = [
    for (var i = 1; i < begins.length; i++) (begins[i] - begins[i - 1]) / 1000,
  ]..sort();
  return (
    average: read('average_frame_build_time_millis'),
    p99Build: read('99th_percentile_frame_build_time_millis'),
    p99Raster: read('99th_percentile_frame_rasterizer_time_millis'),
    // Nearest-rank 10th percentile.
    period: gaps[math.max(0, (gaps.length * 0.1).ceil() - 1)],
    frames: begins.length,
  );
}

/// The trace in [fileName] of [run], or null when the name is not
/// `<scene>.<side>.<pair>.timeline_summary.json`.
Trace? traceOf(String run, String fileName, TraceMetrics metrics) {
  final parts = fileName.split('.');
  if (parts.length != 5 ||
      parts[3] != 'timeline_summary' ||
      parts[4] != 'json') {
    return null;
  }
  final [scene, side, pairText, _, _] = parts;
  final pair = int.tryParse(pairText);
  if (pair == null || (side != 'base' && side != 'cand')) return null;
  return (run: run, scene: scene, side: side, pair: pair, metrics: metrics);
}

/// The run `r<run>` that a run folder `r<run>g<group>` belongs to.
String runOf(String folder) => folder.split('g').first;

/// Whether [metrics] holds fewer than [minFrameShare] of the frames its
/// traced window holds at its display period (spec section 9.5).
bool lostFrames(TraceMetrics metrics) {
  return metrics.frames < minFrameShare * traceWindowMs / metrics.period;
}

/// Runs (`r<run>`, every group of the run) left out of the analysis, each
/// with its reason (spec section 9.5): a trace whose display period differs
/// by more than [maxPeriodDrift] from the run's median period or from the
/// comparison's, which also catches a run whose windows all opened on
/// another display; or a trace that lost frames, named by side, because
/// frames lost on the current side only can signal a regression.
Map<String, String> invalidRuns(List<Trace> traces) {
  if (traces.isEmpty) return {};
  final overall = median([for (final t in traces) t.metrics.period]);
  final byRun = <String, List<Trace>>{};
  for (final trace in traces) {
    (byRun[runOf(trace.run)] ??= []).add(trace);
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
    final parts = [
      if (drifts) 'display period',
      if (lostSides.isNotEmpty) 'lost frames on ${lostSides.join(' and ')}',
    ];
    if (parts.isNotEmpty) reasons[run] = parts.join('; ');
  }
  return reasons;
}

bool _drifts(double period, double reference) {
  return (period - reference).abs() > reference * maxPeriodDrift;
}

/// Scene to its blocks: the four traces of the scene in one run folder.
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
      if (!name.endsWith('.timeline_summary.json')) continue;
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

/// Judges [traces] and returns the report text and the overall verdict.
({String text, Verdict verdict}) judge(
  List<Trace> traces, {
  required List<double> loads,
  required List<String> scenes,
  Map<String, String> codeStates = const {},
}) {
  final invalid = invalidRuns(traces);
  final valid = [
    for (final trace in traces)
      if (!invalid.containsKey(runOf(trace.run))) trace,
  ];
  final blocks = blockTraces(valid);
  final nullCi = medianInterval([
    for (final block in blocks[nullScene] ?? const <Block>[])
      blockChange(block),
  ]);
  final gate = nullGatePasses(nullCi);
  final rows = <String>[];
  final verdicts = <Verdict>[];
  for (final scene in {...scenes, ...blocks.keys}.toList()..sort()) {
    final sceneBlocks = blocks[scene] ?? const <Block>[];
    if (sceneBlocks.isEmpty) {
      // An expected scene without valid blocks stays in the report: spec
      // section 9.5 makes fewer than 6 blocks INCONCLUSIVE.
      if (scene != nullScene) verdicts.add(Verdict.inconclusive);
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
      verdicts.add(verdict);
      verdictText = verdict.name.toUpperCase();
    }
    rows.add(_row(scene, sceneBlocks, ci, verdictText));
  }
  final verdict = overallVerdict(nullGate: gate, scenes: verdicts);
  final runs = {for (final trace in valid) runOf(trace.run)};
  final invocations = {for (final trace in valid) trace.run};
  final periods = [for (final trace in valid) trace.metrics.period];
  final text = StringBuffer()
    ..writeln(
      'runs ${runs.length} (${invocations.length} invocations), '
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
  return (text: text.toString(), verdict: verdict);
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

The 10th percentile is the nearest-rank one: `gaps[max(0, ceil(0.1 n) − 1)]` of the sorted gaps, so one gap in ten at the display rate still reads the display period. `codeState` runs `git` and `shasum` from the repository root (`workingDirectory: '..'`), because `git diff -- lib example` takes paths relative to the working directory.

- [ ] **Step 4: Run it to verify it passes**

Run: `flutter test --no-pub test/tool/perf_abba_test.dart`
Expected: PASS, `+40: All tests passed!`

- [ ] **Step 5: Write the failing S2-plain check test**

In `example/test/perf/perf_scenes_test.dart`, replace:

```dart
      expect(tester.takeException(), isNull);
      expect(find.byType(AnimatedStyledBox), findsNothing);
    });
  });
}
```

with:

```dart
      expect(tester.takeException(), isNull);
      expect(find.byType(AnimatedStyledBox), findsNothing);
    });

    testWidgets("S2-plain's check draws S2-box with the current kit on both "
        'sides', (tester) async {
      final scene = perfScene('S2-plain');
      await tester.pumpWidget(perfHost(scene.build(const _RefusingKit())));

      await scene.check!(tester, const _RefusingKit());

      expect(tester.takeException(), isNull);
      expect(find.byType(AnimatedStyledBox), findsNothing);
    });
  });
}
```

- [ ] **Step 6: Run it to verify it fails**

Run: `flutter test --no-pub test/perf/perf_scenes_test.dart`
Expected: FAIL, `Bad state: row called` in the new test: the check draws S2-box through the step's kit, so the null control's two sides did different work before every trace.

- [ ] **Step 7: Draw S2-box with the current kit**

In `example/integration_test/perf/perf_scenes.dart`, replace:

```dart
    check: (tester, kit) async {
      // Equal row heights give equal list extents, so S2-plain scrolls the
      // same rows as S2-box.
      final plainExtent = _position(tester).maxScrollExtent;
      await tester.pumpWidget(perfHost(_list((index) => _boxRow(kit, index))));
```

with:

```dart
    check: (tester, _) async {
      // Equal row heights give equal list extents, so S2-plain scrolls the
      // same rows as S2-box. The current kit draws S2-box on both sides, so
      // the null control's two sides do identical work before every trace
      // (spec section 9.4).
      final plainExtent = _position(tester).maxScrollExtent;
      await tester.pumpWidget(
        perfHost(_list((index) => _boxRow(const CurrentKit(), index))),
      );
```

- [ ] **Step 8: Run it to verify it passes**

Run: `flutter test --no-pub test/perf/perf_scenes_test.dart`
Expected: PASS, `+19: All tests passed!`

- [ ] **Step 9: Commit the tool**

```bash
cd "<repo>"
git add -- example/tool/perf_abba.dart example/test/tool/perf_abba_test.dart example/integration_test/perf/perf_scenes.dart example/test/perf/perf_scenes_test.dart
git commit -m "feat(example): judge the ABBA benchmark per block with display, frame, and code checks" -- example/tool/perf_abba.dart example/test/tool/perf_abba_test.dart example/integration_test/perf/perf_scenes.dart example/test/perf/perf_scenes_test.dart
```

- [ ] **Step 10: Freeze the phase 3 tip**

The copy set is every file phase 4 changes that a scene reaches (spec section 9.3): the box and its three layouts, and, for S3's tap surface, `StratumInkWell` and `StratumInteraction`. `scroll_frame.dart` stays shared: the frozen `BaselineBoxLayout` imports it for `ScrollFrame`, whose API phase 4 keeps, and no scene scrolls a box layout.

Run, from `example/`:

```bash
dart run tool/perf_freeze.dart fe31fdc lib/src/components/common/style/animated_styled_box.dart lib/src/components/common/layout/box_layout.dart lib/src/components/common/layout/container_layout.dart lib/src/components/common/layout/column_layout.dart lib/src/components/common/layout/row_layout.dart lib/src/components/common/ink_well.dart lib/src/components/common/model/interaction.dart
```

Expected (last line): `froze 7 files from fe31fdc; renamed AnimatedStyledBox, BoxLayout, ColumnLayout, ContainerLayout, RowLayout, StratumInkWell, StratumInteraction, StyledBoxBuilder, StyledScrollBuilder`

- [ ] **Step 11: Analyze the frozen folder**

Run: `flutter analyze --no-pub integration_test/baseline`
Expected: `No issues found!` An error here means the copy set misses a file: add the file that declares the missing name to Step 10's command, rerun Step 10, and record the change for spec section 9.3.

- [ ] **Step 12: Write the failing kit test**

Replace all of `example/test/perf/perf_kit_test.dart` with:

```dart
// ignore_for_file: implementation_imports
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import '../../integration_test/baseline/baseline.dart';
import '../../integration_test/perf/perf_kit.dart';

void main() {
  void onTap() {}

  group('CurrentKit', () {
    test('passes the tap to RowLayout through its interaction', () {
      final row = const CurrentKit().row(
        onTap: onTap,
        mainAxisAlignment: MainAxisAlignment.end,
        children: const [],
      );
      expect(
        row,
        isA<RowLayout>()
            .having((r) => r.interaction?.onTap, 'interaction.onTap', onTap)
            .having(
              (r) => r.mainAxisAlignment,
              'mainAxisAlignment',
              MainAxisAlignment.end,
            ),
      );
    });

    test('builds a RowLayout without interaction when there is no tap', () {
      final row = const CurrentKit().row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: const [],
      );
      expect(
        row,
        isA<RowLayout>().having((r) => r.interaction, 'interaction', isNull),
      );
    });
  });

  group('BaselineKit', () {
    test('builds BaselineRowLayout without interaction when there is no '
        'tap', () {
      final row = const BaselineKit().row(
        style: const WidgetStyle(),
        mainAxisAlignment: MainAxisAlignment.end,
        children: const [],
      );
      expect(
        row,
        isA<BaselineRowLayout>()
            .having(
              (r) => r.mainAxisAlignment,
              'mainAxisAlignment',
              MainAxisAlignment.end,
            )
            .having((r) => r.interaction, 'interaction', isNull),
      );
    });

    test('passes the tap to BaselineRowLayout through its interaction', () {
      final row = const BaselineKit().row(
        onTap: onTap,
        mainAxisAlignment: MainAxisAlignment.start,
        children: const [],
      );
      expect(
        row,
        isA<BaselineRowLayout>().having(
          (r) => r.interaction,
          'interaction',
          isA<BaselineStratumInteraction>().having(
            (i) => i.onTap,
            'onTap',
            onTap,
          ),
        ),
      );
    });

    test('builds BaselineColumnLayout and BaselineContainerLayout', () {
      const kit = BaselineKit();
      expect(
        kit.column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: const [],
        ),
        isA<BaselineColumnLayout>()
            .having((c) => c.mainAxisSize, 'mainAxisSize', MainAxisSize.min)
            .having(
              (c) => c.crossAxisAlignment,
              'crossAxisAlignment',
              CrossAxisAlignment.end,
            ),
      );
      expect(
        kit.container(style: const WidgetStyle(width: 4)),
        isA<BaselineContainerLayout>().having(
          (c) => c.style,
          'style',
          const WidgetStyle(width: 4),
        ),
      );
    });
  });
}
```

- [ ] **Step 13: Run it to verify it fails**

Run: `flutter test --no-pub test/perf/perf_kit_test.dart`
Expected: FAIL at compile time, with `integration_test/perf/perf_kit.dart:90:12: Error: The method 'BaselineGestureRowLayout' isn't defined for the type 'BaselineKit'.`: the freeze removed the phase 2 gesture twin that the kit still draws.

- [ ] **Step 14: Point `BaselineKit` at the frozen phase 3 layouts**

Replace all of `example/integration_test/perf/perf_kit.dart` with:

```dart
// ignore_for_file: implementation_imports
import 'package:stratum_ui/src/src.dart';

import '../baseline/baseline.dart';

/// The layouts one side of the comparison draws with (spec section 9.2).
///
/// Scenes reach layouts only through a kit, so moving to a new layout API
/// changes the kits and leaves the scenes as they are.
abstract interface class PerfKit {
  /// A row; a non-null [onTap] makes it a tap surface with the default
  /// 100 ms style animation.
  Widget row({
    WidgetStyle? style,
    VoidCallback? onTap,
    required MainAxisAlignment mainAxisAlignment,
    required List<Widget> children,
  });

  /// A column without style.
  Widget column({
    required MainAxisSize mainAxisSize,
    required CrossAxisAlignment crossAxisAlignment,
    required List<Widget> children,
  });

  /// A box with [style] around [child].
  Widget container({WidgetStyle? style, Widget? child});
}

/// The layouts of the code under test.
class CurrentKit implements PerfKit {
  const new();

  @override
  Widget row({
    WidgetStyle? style,
    VoidCallback? onTap,
    required MainAxisAlignment mainAxisAlignment,
    required List<Widget> children,
  }) {
    return RowLayout(
      style: style,
      interaction: onTap == null ? null : StratumInteraction(onTap: onTap),
      mainAxisAlignment: mainAxisAlignment,
      children: children,
    );
  }

  @override
  Widget column({
    required MainAxisSize mainAxisSize,
    required CrossAxisAlignment crossAxisAlignment,
    required List<Widget> children,
  }) {
    return ColumnLayout(
      mainAxisSize: mainAxisSize,
      crossAxisAlignment: crossAxisAlignment,
      children: children,
    );
  }

  @override
  Widget container({WidgetStyle? style, Widget? child}) {
    return ContainerLayout(style: style, child: child);
  }
}

/// The layouts of the frozen baseline (spec section 9.3).
///
/// Phase 4's baseline is fe31fdc, the phase 3 tip: a tappable row is a
/// `BaselineRowLayout` with a `BaselineStratumInteraction`.
class BaselineKit implements PerfKit {
  const new();

  @override
  Widget row({
    WidgetStyle? style,
    VoidCallback? onTap,
    required MainAxisAlignment mainAxisAlignment,
    required List<Widget> children,
  }) {
    return BaselineRowLayout(
      style: style,
      interaction: onTap == null
          ? null
          : BaselineStratumInteraction(onTap: onTap),
      mainAxisAlignment: mainAxisAlignment,
      children: children,
    );
  }

  @override
  Widget column({
    required MainAxisSize mainAxisSize,
    required CrossAxisAlignment crossAxisAlignment,
    required List<Widget> children,
  }) {
    return BaselineColumnLayout(
      mainAxisSize: mainAxisSize,
      crossAxisAlignment: crossAxisAlignment,
      children: children,
    );
  }

  @override
  Widget container({WidgetStyle? style, Widget? child}) {
    return BaselineContainerLayout(style: style, child: child);
  }
}
```

- [ ] **Step 15: Run the example suite and the analyzer**

Run: `flutter test --no-pub test/`
Expected: PASS, `+78: All tests passed!`

Run: `flutter analyze --no-pub integration_test test_driver tool test`
Expected: `No issues found!`

- [ ] **Step 16: Dry run: one run of three invocations**

Keep the test window visible while it runs. Run, from `example/`:

```bash
rm -rf build/perf/abba
mkdir -p build/perf-logs
dart run tool/perf_abba.dart run --runs 1 > build/perf-logs/abba-p4-dry.log 2>&1; echo "exit $?"
tail -16 build/perf-logs/abba-p4-dry.log
cat build/perf/abba/r1g1/code.txt
```

Expected: three builds and three `flutter drive` invocations finish; the report header reads `runs 1 (3 invocations)`, or names `r1` under `invalid runs:` with its reason; the table has a `blocks` column with 1 block for S1, S1-fast, S2, S2-box, S3, S4, and S5 and 3 for S2-plain; every scene is `INCONCLUSIVE` (no interval below 6 blocks); the exit is 2 (`overall: INCONCLUSIVE`) or 1 (`overall: INVALID`). `code.txt` holds the 40-character `HEAD` and the 40-character diff hash on one line. Either exit is a successful dry run.

Then run: `rm -rf build/perf/abba`

- [ ] **Step 17: Commit the baseline**

```bash
cd "<repo>"
git add -- example/integration_test/baseline example/integration_test/perf/perf_kit.dart example/test/perf/perf_kit_test.dart
git commit -m "perf(example): freeze the phase 3 tip as the phase 4 benchmark baseline" -- example/integration_test/baseline example/integration_test/perf/perf_kit.dart example/test/perf/perf_kit_test.dart
```

Run: `git show --stat HEAD`
Expected: the seven frozen files and `baseline.dart`, the two deleted gesture files, `perf_kit.dart`, and `perf_kit_test.dart`; nothing under `assets/`, `lib/`, or `example/macos/`.

---
### Task 2: `StratumScroll`, `fillViewport`, `direction`, and the viewport ratio

**Agent:** general-purpose
**Implements:** P4-2

`scroll: StratumScroll?` replaces `scrollable: bool` on the five box layouts (owner ruling C, 2026-10-01). `fillViewport` (default false) is the one stretch switch; the phase 3 rule that column and row stretch at `MainAxisSize.max` and stack and wrap always stretch is gone, because a scrolling `StackLayout` or `WrapLayout` threw "LayoutBuilder does not support returning intrinsic dimensions." inside `AlertDialog` content (spec section 12). With `scroll`, `ratio` shapes the visible frame instead of the scrolled content.

**Files:**
- Create: `lib/src/components/common/model/scroll.dart`
- Modify: `lib/src/components/common/model/model.dart` (whole file)
- Modify: `lib/src/components/common/layout/box_layout.dart` (whole file)
- Modify: `lib/src/components/common/layout/column_layout.dart`, `row_layout.dart`, `stack_layout.dart`, `wrap_layout.dart`, `container_layout.dart` (`super.scroll`, docs, and the removed `stretchesToViewport` override)
- Modify: `lib/src/components/common/style/animated_styled_box.dart` (where `ratio` goes)
- Create: `test/src/components/common/model/scroll_test.dart`
- Modify: `test/src/components/common/layout/box_layout_test.dart`, `column_layout_test.dart`, `row_layout_test.dart`, `stack_layout_test.dart`, `wrap_layout_test.dart`, `test/src/components/common/style/animated_styled_box_test.dart`

**Interfaces:**
- Consumes: `ScrollFrame` and `resolveScrollBehavior` (phase 1, `layout/scroll_frame.dart`); `AnimatedStyledBox.scrollBuilder` (phase 3).
- Produces: `class StratumScroll` (`const new({Axis? direction, bool fillViewport = false, bool reverse = false, ScrollController? controller, bool? primary, ScrollPhysics? physics, bool? showScrollbar, ScrollViewKeyboardDismissBehavior? keyboardDismissBehavior, String? restorationId})`), exported by `model/model.dart`; `BoxLayout.scroll` (`StratumScroll?`) and `super.scroll` on the five layouts; private `_BoxScrollView({required StratumScroll scroll, required Axis axis, required Widget child})` in `box_layout.dart`, which Task 7 extends with `linked`; `BoxLayout._buildScroll(StratumScroll scroll, Widget content)`, which Task 7 extends with `{required bool linked}`. Removed: `BoxLayout.scrollable`, `BoxLayout.stretchesToViewport`.

- [ ] **Step 1: Write the failing model test**

Create `test/src/components/common/model/scroll_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

void main() {
  group('StratumScroll', () {
    test('defaults to the layout axis, no stretch, and no reverse', () {
      const scroll = StratumScroll();

      expect(scroll.direction, isNull);
      expect(scroll.fillViewport, isFalse);
      expect(scroll.reverse, isFalse);
      expect(scroll.primary, isNull);
      expect(scroll.showScrollbar, isNull);
    });

    test('a controller with primary: true fails its assertion', () {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      expect(
        () => StratumScroll(controller: controller, primary: true),
        throwsAssertionError,
      );
    });
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test --no-pub test/src/components/common/model/scroll_test.dart`
Expected: FAIL at compile time, with `Error: Method not found: 'StratumScroll'.`

- [ ] **Step 3: Write `StratumScroll`**

Create `lib/src/components/common/model/scroll.dart`:

```dart
import 'package:stratum_ui/src/src.dart';

/// How a box layout scrolls its padding and content inside the box.
///
/// Fill, border, radius, and shadow stay in place while the padding and
/// the content scroll, as Figma overflow scrolling does; a layout with a
/// null `scroll` does not scroll. [reverse], [controller], [primary],
/// [keyboardDismissBehavior], and [restorationId] reach the
/// [SingleChildScrollView] unchanged.
///
/// The class does not override `==`: a controller compares by identity.
@immutable
class StratumScroll {
  const new({
    this.direction,
    this.fillViewport = false,
    this.reverse = false,
    this.controller,
    this.primary,
    this.physics,
    this.showScrollbar,
    this.keyboardDismissBehavior,
    this.restorationId,
  }) : assert(
         !(controller != null && (primary ?? false)),
         'A primary scroll view takes its controller from the '
         'PrimaryScrollController; pass controller or primary: true, '
         'not both',
       );

  /// The scroll axis; null keeps the layout's own axis: vertical, or
  /// horizontal for a row, or across `direction` for a wrap.
  final Axis? direction;

  /// Stretches content shorter than the viewport to the viewport, minus
  /// the padding, so `spaceBetween` and `end` alignments work.
  ///
  /// A stretching layout builds a [LayoutBuilder], which is not supported
  /// under [IntrinsicWidth], [IntrinsicHeight], `AlertDialog` content, or a
  /// parent's `crossAxisIntrinsic`. Only a finite viewport stretches: in a
  /// parent unbounded along the scroll axis the layout sizes to its
  /// content. Flipping this value between builds resets the scroll offset.
  final bool fillViewport;
  final bool reverse;
  final ScrollController? controller;
  final bool? primary;

  /// Applies on top of the theme's physics.
  final ScrollPhysics? physics;

  /// Null keeps the scroll behavior's choice: a scrollbar on desktop.
  final bool? showScrollbar;
  final ScrollViewKeyboardDismissBehavior? keyboardDismissBehavior;
  final String? restorationId;
}
```

The assertion repeats `SingleChildScrollView`'s own (`widgets/single_child_scroll_view.dart:163-168` in the SDK), so a bad pair fails where the caller builds it.

Replace all of `lib/src/components/common/model/model.dart` with:

```dart
export 'image_blur_filter.dart';
export 'interaction.dart';
export 'scroll.dart';
export 'widget_style.dart';
```

- [ ] **Step 4: Run it to verify it passes**

Run: `flutter test --no-pub test/src/components/common/model/scroll_test.dart`
Expected: PASS, `+2: All tests passed!`

- [ ] **Step 5: Write the failing viewport-ratio test**

In `test/src/components/common/style/animated_styled_box_test.dart`, replace:

```dart
    testWidgets('the child keeps its State when scrollBuilder comes', (
```

with:

```dart
    testWidgets('ratio shapes the viewport outside the decorations', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const WidgetStyle(
            backgroundColor: Color(0xFFFFFFFF),
            padding: EdgeInsets.all(8),
          ),
          ratio: 2,
          scrollBuilder: _scroll,
        ),
      );

      final ratio = find.byType(AspectRatio);
      expect(ratio, findsOneWidget);
      expect(find.ancestor(of: _decorated(), matching: ratio), findsOneWidget);
      expect(
        find.descendant(of: find.byType(_ScrollProbe), matching: ratio),
        findsNothing,
      );
    });

    testWidgets('(pin) without scrollBuilder ratio wraps the child', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const WidgetStyle(backgroundColor: Color(0xFFFFFFFF)), ratio: 2),
      );

      expect(
        find.ancestor(
          of: find.byType(AspectRatio),
          matching: _decorated(),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the child keeps its State when scrollBuilder comes', (
```

- [ ] **Step 6: Run it to verify it fails**

Run: `flutter test --no-pub test/src/components/common/style/animated_styled_box_test.dart`
Expected: FAIL in `ratio shapes the viewport outside the decorations`, with `Expected: exactly one matching candidate` and `Actual: _AncestorWidgetFinder:<Found 0 widgets with type "AspectRatio" that are ancestors of`. The `(pin)` case passes.

- [ ] **Step 7: Move `ratio` to the viewport when a scroll view is present**

In `lib/src/components/common/style/animated_styled_box.dart`, replace:

```dart
  final WidgetStyle? style;
  final double? ratio;
```

with:

```dart
  final WidgetStyle? style;

  /// Width divided by height. Shapes the child, or, with a
  /// [scrollBuilder], the viewport: the visible frame takes the ratio and
  /// the content scrolls inside it.
  final double? ratio;
```

Replace:

```dart
    final ratio = widget.ratio;
    if (ratio != null) {
      current = AspectRatio(aspectRatio: ratio, child: current);
    }
```

with:

```dart
    final ratio = widget.ratio;
    final scrollBuilder = widget.scrollBuilder;
    // Without a scroll view the ratio shapes the content; with one it
    // shapes the viewport, below.
    if (ratio != null && scrollBuilder == null) {
      current = AspectRatio(aspectRatio: ratio, child: current);
    }
```

Replace:

```dart
    final scrollBuilder = widget.scrollBuilder;
    if (scrollBuilder != null) {
```

with:

```dart
    if (scrollBuilder != null) {
```

Replace:

```dart
    final constraints = _constraints(style);
    if (constraints != null) {
      current = ConstrainedBox(constraints: constraints, child: current);
    }
```

with:

```dart
    if (ratio != null && scrollBuilder != null) {
      current = AspectRatio(aspectRatio: ratio, child: current);
    }
    final constraints = _constraints(style);
    if (constraints != null) {
      current = ConstrainedBox(constraints: constraints, child: current);
    }
```

The viewport `AspectRatio` now sits between the size constraints and the decorations (spec section 5), so the fill and border take the ratio and the padding and content scroll inside it.

- [ ] **Step 8: Run it to verify it passes**

Run: `flutter test --no-pub test/src/components/common/style/animated_styled_box_test.dart`
Expected: PASS, `+41: All tests passed!`

- [ ] **Step 9: Port `box_layout_test.dart` and add the scroll cases**

In `test/src/components/common/layout/box_layout_test.dart`, replace:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';
```

with:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/layout/scroll_frame.dart';
import 'package:stratum_ui/src/src.dart';
```

Replace:

```dart
    super.interaction,
    super.scrollable,
    this.axis = Axis.vertical,
```

with:

```dart
    super.interaction,
    super.scroll,
    this.axis = Axis.vertical,
```

Replace:

```dart
      'scrollable': const _Layout(scrollable: true),
```

with:

```dart
      'scroll': const _Layout(scroll: StratumScroll()),
```

Replace:

```dart
  group('BoxLayout scrollable', () {
    testWidgets('scrolls inside the box along scrollDirection', (tester) async {
      await tester.pumpWidget(
        themedHost(
          const _Layout(
            style: WidgetStyle(backgroundColor: Color(0xFFFFFFFF)),
            scrollable: true,
            axis: Axis.horizontal,
          ),
        ),
      );

      final scroll = find.byType(SingleChildScrollView);
      expect(
        find.ancestor(of: scroll, matching: find.byType(AnimatedStyledBox)),
        findsOneWidget,
      );
      expect(
        tester.widget<SingleChildScrollView>(scroll).scrollDirection,
        Axis.horizontal,
      );
      expect(
        find.ancestor(of: scroll, matching: find.byType(ScrollConfiguration)),
        findsWidgets,
      );
    });
  });
}
```

with:

```dart
  group('BoxLayout scroll', () {
    testWidgets('scrolls inside the box along scrollDirection', (tester) async {
      await tester.pumpWidget(
        themedHost(
          const _Layout(
            style: WidgetStyle(backgroundColor: Color(0xFFFFFFFF)),
            scroll: StratumScroll(),
            axis: Axis.horizontal,
          ),
        ),
      );

      final scroll = find.byType(SingleChildScrollView);
      expect(
        find.ancestor(of: scroll, matching: find.byType(AnimatedStyledBox)),
        findsOneWidget,
      );
      expect(
        tester.widget<SingleChildScrollView>(scroll).scrollDirection,
        Axis.horizontal,
      );
      expect(
        find.ancestor(of: scroll, matching: find.byType(ScrollConfiguration)),
        findsWidgets,
      );
    });

    testWidgets('a null scroll builds no scroll view', (tester) async {
      await tester.pumpWidget(themedHost(const _Layout(style: WidgetStyle())));

      expect(find.byType(SingleChildScrollView), findsNothing);
      expect(find.byType(ScrollFrame), findsNothing);
    });

    testWidgets('every StratumScroll field reaches the scroll view', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      const physics = BouncingScrollPhysics();
      await tester.pumpWidget(
        themedHost(
          _Layout(
            scroll: StratumScroll(
              direction: Axis.horizontal,
              reverse: true,
              controller: controller,
              primary: false,
              physics: physics,
              showScrollbar: false,
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              restorationId: 'box',
            ),
          ),
        ),
      );

      final view = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      expect(view.scrollDirection, Axis.horizontal);
      expect(view.reverse, isTrue);
      expect(view.controller, same(controller));
      expect(view.primary, isFalse);
      expect(view.physics, same(physics));
      expect(
        view.keyboardDismissBehavior,
        ScrollViewKeyboardDismissBehavior.onDrag,
      );
      expect(view.restorationId, 'box');
      expect(
        tester.widget<ScrollFrame>(find.byType(ScrollFrame)).showScrollbar,
        isFalse,
      );
    });

    testWidgets('scroll.physics applies on top of the theme', (tester) async {
      await tester.pumpWidget(
        themedHost(
          const SizedBox(
            width: 100,
            height: 100,
            child: ColumnLayout(
              scroll: StratumScroll(physics: BouncingScrollPhysics()),
              children: [SizedBox(height: 500)],
            ),
          ),
        ),
      );

      final types = <Type>[];
      for (
        ScrollPhysics? physics = tester
            .state<ScrollableState>(find.byType(Scrollable))
            .position
            .physics;
        physics != null;
        physics = physics.parent
      ) {
        types.add(physics.runtimeType);
      }
      expect(
        types,
        containsAll([BouncingScrollPhysics, ClampingScrollPhysics]),
      );
    });

    final horizontal = <String, Widget>{
      'ContainerLayout': const ContainerLayout(
        scroll: StratumScroll(direction: Axis.horizontal),
        child: SizedBox(width: 500, height: 20),
      ),
      'StackLayout': const StackLayout(
        scroll: StratumScroll(direction: Axis.horizontal),
        children: [SizedBox(width: 500, height: 20)],
      ),
    };
    for (final MapEntry(key: name, value: layout) in horizontal.entries) {
      testWidgets('direction: Axis.horizontal scrolls a $name sideways', (
        tester,
      ) async {
        await tester.pumpWidget(
          themedHost(SizedBox(width: 100, height: 50, child: layout)),
        );

        expect(
          tester
              .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
              .scrollDirection,
          Axis.horizontal,
        );
        expect(
          tester
              .state<ScrollableState>(find.byType(Scrollable))
              .position
              .maxScrollExtent,
          400,
        );
      });
    }

    final dialogs = <String, Widget>{
      'StackLayout': const StackLayout(
        scroll: StratumScroll(),
        children: [SizedBox(width: 200, height: 40)],
      ),
      'WrapLayout': const WrapLayout(
        scroll: StratumScroll(),
        children: [SizedBox(width: 200, height: 40)],
      ),
      'ColumnLayout': const ColumnLayout(
        scroll: StratumScroll(),
        children: [SizedBox(width: 200, height: 40)],
      ),
    };
    for (final MapEntry(key: name, value: layout) in dialogs.entries) {
      testWidgets('a scrolling $name lays out inside AlertDialog content', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(home: AlertDialog(content: layout)),
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(SingleChildScrollView), findsOneWidget);
      });
    }

    testWidgets('ratio with scroll shapes the frame and scrolls the content', (
      tester,
    ) async {
      await tester.pumpWidget(
        themedHost(
          const SizedBox(
            width: 320,
            child: ColumnLayout(
              ratio: 16 / 9,
              style: WidgetStyle(backgroundColor: Color(0xFFFFFFFF)),
              scroll: StratumScroll(),
              children: [SizedBox(height: 600)],
            ),
          ),
        ),
      );

      expect(tester.getSize(find.byType(ColumnLayout)), const Size(320, 180));
      expect(
        tester
            .state<ScrollableState>(find.byType(Scrollable))
            .position
            .maxScrollExtent,
        420,
      );
    });

    testWidgets('changing reverse or showScrollbar keeps the scroll offset', (
      tester,
    ) async {
      Widget build({bool reverse = false, bool? showScrollbar}) {
        return themedHost(
          SizedBox(
            width: 100,
            height: 100,
            child: ColumnLayout(
              style: const WidgetStyle(),
              scroll: StratumScroll(
                reverse: reverse,
                showScrollbar: showScrollbar,
              ),
              children: const [SizedBox(height: 500)],
            ),
          ),
        );
      }

      double pixels() => tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position
          .pixels;

      await tester.pumpWidget(build());
      tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position
          .jumpTo(100);
      await tester.pump();

      await tester.pumpWidget(build(showScrollbar: false));
      expect(pixels(), 100);

      await tester.pumpWidget(build(showScrollbar: false, reverse: true));
      expect(pixels(), 100);
    });
  });
}
```

- [ ] **Step 10: Port the four layout tests**

In `test/src/components/common/layout/column_layout_test.dart`, replace:

```dart
  group('ColumnLayout scrollable', () {
    testWidgets('a scrollable column with a style height lays out', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const ColumnLayout(
            scrollable: true,
            style: WidgetStyle(height: 200),
            children: [SizedBox(height: 100)],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('toggling scrollable keeps the children State', (tester) async {
      Widget build({required bool scrollable}) => _sized(
        const Size(100, 100),
        ColumnLayout(
          style: const WidgetStyle(),
          scrollable: scrollable,
          children: const [_Probe()],
        ),
      );

      await tester.pumpWidget(build(scrollable: false));
      final before = tester.state(find.byType(_Probe));
      await tester.pumpWidget(build(scrollable: true));
      expect(tester.state(find.byType(_Probe)), same(before));

      await tester.pumpWidget(build(scrollable: false));
      expect(tester.takeException(), isNull);
      expect(tester.state(find.byType(_Probe)), same(before));
    });

    testWidgets('(pin) short content fills a bounded viewport', (tester) async {
      await tester.pumpWidget(
        _sized(
          const Size(100, 300),
          const ColumnLayout(
            scrollable: true,
            style: WidgetStyle(padding: EdgeInsets.all(10)),
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(key: _a, height: 20),
              SizedBox(key: _b, height: 20),
            ],
          ),
        ),
      );

      final top = tester.getTopLeft(find.byType(ColumnLayout)).dy;
      expect(tester.getTopLeft(find.byKey(_a)).dy - top, 10);
      expect(tester.getBottomLeft(find.byKey(_b)).dy - top, 290);
    });

    testWidgets(
      'a min-size scrollable column keeps its content height (ruling A)',
      (tester) async {
        await tester.pumpWidget(
          _host(
            const ColumnLayout(
              scrollable: true,
              mainAxisSize: MainAxisSize.min,
              children: [SizedBox(height: 50)],
            ),
          ),
        );

        expect(tester.getSize(find.byType(ColumnLayout)).height, 50);
      },
    );

    testWidgets('an unbounded parent sizes it to the content (D17)', (
      tester,
    ) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            children: [
              ColumnLayout(scrollable: true, children: [SizedBox(height: 50)]),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(ColumnLayout)).height, 50);
    });

    testWidgets('the decoration stays in place while the content scrolls', (
      tester,
    ) async {
      await tester.pumpWidget(
        _sized(
          const Size(100, 200),
          const ColumnLayout(
            scrollable: true,
            style: WidgetStyle(
              backgroundColor: Color(0xFFFFFFFF),
              padding: EdgeInsets.all(10),
            ),
            children: [SizedBox(key: _a, height: 500)],
          ),
        ),
      );
      final box = tester.getRect(_decoration());
      final content = tester.getTopLeft(find.byKey(_a)).dy;

      tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position
          .jumpTo(100);
      await tester.pump();

      expect(tester.getRect(_decoration()), box);
      expect(tester.getTopLeft(find.byKey(_a)).dy, content - 100);
    });

    testWidgets('the scroll position survives a style or interaction change', (
      tester,
    ) async {
      Widget build({Border? border, StratumInteraction? interaction}) {
        return themedHost(
          SizedBox.fromSize(
            size: const Size(100, 200),
            child: ColumnLayout(
              scrollable: true,
              style: WidgetStyle(border: border),
              interaction: interaction,
              children: const [SizedBox(height: 500)],
            ),
          ),
        );
      }

      await tester.pumpWidget(build());
      tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position
          .jumpTo(100);
      await tester.pump();

      await tester.pumpWidget(build(border: Border.all()));
      expect(
        tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
        100,
      );

      await tester.pumpWidget(
        build(
          border: Border.all(),
          interaction: StratumInteraction(onTap: () {}),
        ),
      );
      expect(
        tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
        100,
      );
    });

    testWidgets('a rounded scrollable box builds exactly one clip', (
      tester,
    ) async {
      await tester.pumpWidget(
        _sized(
          const Size(100, 200),
          const ColumnLayout(
            scrollable: true,
            style: WidgetStyle(
              backgroundColor: Color(0xFFFFFFFF),
              borderRadius: _radius,
            ),
            children: [SizedBox(height: 500)],
          ),
        ),
      );

      expect(find.byType(ClipRect), findsNothing);
      final clip = tester.widget<ClipRRect>(find.byType(ClipRRect));
      expect(clip.clipBehavior, Clip.antiAlias);
      final scroll = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      expect(scroll.clipBehavior, Clip.hardEdge);
    });
  });
}


```

with:

```dart
  group('ColumnLayout scroll', () {
    testWidgets('a scrolling column with a style height lays out', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const ColumnLayout(
            scroll: StratumScroll(),
            style: WidgetStyle(height: 200),
            children: [SizedBox(height: 100)],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('toggling scroll keeps the children State', (tester) async {
      Widget build({required bool scrolls}) => _sized(
        const Size(100, 100),
        ColumnLayout(
          style: const WidgetStyle(),
          scroll: scrolls ? const StratumScroll() : null,
          children: const [_Probe()],
        ),
      );

      await tester.pumpWidget(build(scrolls: false));
      final before = tester.state(find.byType(_Probe));
      await tester.pumpWidget(build(scrolls: true));
      expect(tester.state(find.byType(_Probe)), same(before));

      await tester.pumpWidget(build(scrolls: false));
      expect(tester.takeException(), isNull);
      expect(tester.state(find.byType(_Probe)), same(before));
    });

    testWidgets('fillViewport stretches short content to the viewport', (
      tester,
    ) async {
      await tester.pumpWidget(
        _sized(
          const Size(100, 300),
          const ColumnLayout(
            scroll: StratumScroll(fillViewport: true),
            style: WidgetStyle(padding: EdgeInsets.all(10)),
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(key: _a, height: 20),
              SizedBox(key: _b, height: 20),
            ],
          ),
        ),
      );

      final top = tester.getTopLeft(find.byType(ColumnLayout)).dy;
      expect(tester.getTopLeft(find.byKey(_a)).dy - top, 10);
      expect(tester.getBottomLeft(find.byKey(_b)).dy - top, 290);
    });

    testWidgets('without fillViewport a max-size column keeps its content '
        'height', (tester) async {
      await tester.pumpWidget(
        _sized(
          const Size(100, 300),
          const Align(
            alignment: Alignment.topCenter,
            child: ColumnLayout(
              scroll: StratumScroll(),
              children: [SizedBox(height: 50)],
            ),
          ),
        ),
      );

      expect(tester.getSize(find.byType(ColumnLayout)).height, 50);
    });

    testWidgets('an unbounded parent sizes it to the content (D17)', (
      tester,
    ) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            children: [
              ColumnLayout(
                scroll: StratumScroll(fillViewport: true),
                children: [SizedBox(height: 50)],
              ),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(ColumnLayout)).height, 50);
    });

    testWidgets('the decoration stays in place while the content scrolls', (
      tester,
    ) async {
      await tester.pumpWidget(
        _sized(
          const Size(100, 200),
          const ColumnLayout(
            scroll: StratumScroll(),
            style: WidgetStyle(
              backgroundColor: Color(0xFFFFFFFF),
              padding: EdgeInsets.all(10),
            ),
            children: [SizedBox(key: _a, height: 500)],
          ),
        ),
      );
      final box = tester.getRect(_decoration());
      final content = tester.getTopLeft(find.byKey(_a)).dy;

      tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position
          .jumpTo(100);
      await tester.pump();

      expect(tester.getRect(_decoration()), box);
      expect(tester.getTopLeft(find.byKey(_a)).dy, content - 100);
    });

    testWidgets('the scroll position survives a style or interaction change', (
      tester,
    ) async {
      Widget build({Border? border, StratumInteraction? interaction}) {
        return themedHost(
          SizedBox.fromSize(
            size: const Size(100, 200),
            child: ColumnLayout(
              scroll: const StratumScroll(),
              style: WidgetStyle(border: border),
              interaction: interaction,
              children: const [SizedBox(height: 500)],
            ),
          ),
        );
      }

      await tester.pumpWidget(build());
      tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position
          .jumpTo(100);
      await tester.pump();

      await tester.pumpWidget(build(border: Border.all()));
      expect(
        tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
        100,
      );

      await tester.pumpWidget(
        build(
          border: Border.all(),
          interaction: StratumInteraction(onTap: () {}),
        ),
      );
      expect(
        tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
        100,
      );
    });

    testWidgets('a rounded scrolling box builds exactly one clip', (
      tester,
    ) async {
      await tester.pumpWidget(
        _sized(
          const Size(100, 200),
          const ColumnLayout(
            scroll: StratumScroll(),
            style: WidgetStyle(
              backgroundColor: Color(0xFFFFFFFF),
              borderRadius: _radius,
            ),
            children: [SizedBox(height: 500)],
          ),
        ),
      );

      expect(find.byType(ClipRect), findsNothing);
      final clip = tester.widget<ClipRRect>(find.byType(ClipRRect));
      expect(clip.clipBehavior, Clip.antiAlias);
      final scroll = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      expect(scroll.clipBehavior, Clip.hardEdge);
    });
  });
}


```

The phase 3 stretch case becomes `fillViewport stretches short content to the viewport`, and the D17 case now runs with `fillViewport: true`, the only path that builds the `LayoutBuilder`. The new `without fillViewport a max-size column keeps its content height` pins the changed default: phase 3 stretched a max-size column to the viewport.

In `test/src/components/common/layout/row_layout_test.dart`, replace:

```dart
  group('RowLayout scrollable', () {
    testWidgets('scrolls horizontally inside the box', (tester) async {
      await tester.pumpWidget(
        _host(
          const SizedBox(
            width: 100,
            height: 50,
            child: RowLayout(
              scrollable: true,
              style: WidgetStyle(backgroundColor: Color(0xFFFFFFFF)),
              children: [SizedBox(width: 500, height: 20)],
            ),
          ),
        ),
      );

      final scroll = find.byType(SingleChildScrollView);
      expect(
        tester.widget<SingleChildScrollView>(scroll).scrollDirection,
        Axis.horizontal,
      );
      expect(
        find.ancestor(of: scroll, matching: find.byType(DecoratedBox)),
        findsWidgets,
      );
    });

    testWidgets('short content fills a bounded viewport', (tester) async {
      await tester.pumpWidget(
        _host(
          const SizedBox(
            width: 300,
            height: 50,
            child: RowLayout(
              scrollable: true,
              style: WidgetStyle(padding: EdgeInsets.all(10)),
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(key: _a, width: 20),
                SizedBox(key: _b, width: 20),
              ],
            ),
          ),
        ),
      );

      final left = tester.getTopLeft(find.byType(RowLayout)).dx;
      expect(tester.getTopLeft(find.byKey(_a)).dx - left, 10);
      expect(tester.getTopRight(find.byKey(_b)).dx - left, 290);
    });

    testWidgets(
      'a min-size scrollable row in a Center keeps width 50 (ruling A)',
      (tester) async {
        await tester.pumpWidget(
          _host(
            const RowLayout(
              scrollable: true,
              mainAxisSize: MainAxisSize.min,
              children: [SizedBox(width: 50, height: 20)],
            ),
          ),
        );

        expect(tester.getSize(find.byType(RowLayout)).width, 50);
      },
    );

    testWidgets(
      'a min-size scrollable row inside IntrinsicHeight builds with no '
      'exception (ruling A)',
      (tester) async {
        await tester.pumpWidget(
          _host(
            const IntrinsicHeight(
              child: RowLayout(
                scrollable: true,
                mainAxisSize: MainAxisSize.min,
                children: [SizedBox(width: 50, height: 20)],
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('an unbounded parent sizes it to the content', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            children: [
              RowLayout(
                scrollable: true,
                children: [SizedBox(width: 50, height: 20)],
              ),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(RowLayout)).width, 50);
    });
  });
}
```

with:

```dart
  group('RowLayout scroll', () {
    testWidgets('scrolls horizontally inside the box', (tester) async {
      await tester.pumpWidget(
        _host(
          const SizedBox(
            width: 100,
            height: 50,
            child: RowLayout(
              scroll: StratumScroll(),
              style: WidgetStyle(backgroundColor: Color(0xFFFFFFFF)),
              children: [SizedBox(width: 500, height: 20)],
            ),
          ),
        ),
      );

      final scroll = find.byType(SingleChildScrollView);
      expect(
        tester.widget<SingleChildScrollView>(scroll).scrollDirection,
        Axis.horizontal,
      );
      expect(
        find.ancestor(of: scroll, matching: find.byType(DecoratedBox)),
        findsWidgets,
      );
    });

    testWidgets('fillViewport stretches short content to the viewport', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const SizedBox(
            width: 300,
            height: 50,
            child: RowLayout(
              scroll: StratumScroll(fillViewport: true),
              style: WidgetStyle(padding: EdgeInsets.all(10)),
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(key: _a, width: 20),
                SizedBox(key: _b, width: 20),
              ],
            ),
          ),
        ),
      );

      final left = tester.getTopLeft(find.byType(RowLayout)).dx;
      expect(tester.getTopLeft(find.byKey(_a)).dx - left, 10);
      expect(tester.getTopRight(find.byKey(_b)).dx - left, 290);
    });

    testWidgets('without fillViewport a max-size row keeps its content '
        'width', (tester) async {
      await tester.pumpWidget(
        _host(
          const RowLayout(
            scroll: StratumScroll(),
            children: [SizedBox(width: 50, height: 20)],
          ),
        ),
      );

      expect(tester.getSize(find.byType(RowLayout)).width, 50);
    });

    testWidgets('a scrolling row inside IntrinsicHeight lays out without '
        'fillViewport', (tester) async {
      await tester.pumpWidget(
        _host(
          const IntrinsicHeight(
            child: RowLayout(
              scroll: StratumScroll(),
              children: [SizedBox(width: 50, height: 20)],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('an unbounded parent sizes it to the content', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            children: [
              RowLayout(
                scroll: StratumScroll(fillViewport: true),
                children: [SizedBox(width: 50, height: 20)],
              ),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(RowLayout)).width, 50);
    });
  });
}
```

In `test/src/components/common/layout/stack_layout_test.dart`, replace:

```dart
            child: StackLayout(
              scrollable: true,
```

with:

```dart
            child: StackLayout(
              scroll: StratumScroll(),
```

In `test/src/components/common/layout/wrap_layout_test.dart`, replace:

```dart
  group('WrapLayout scrollable', () {
    testWidgets('a horizontal wrap scrolls vertically and still wraps (D1)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 100,
            height: 60,
            child: WrapLayout(scrollable: true, children: _tiles()),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(
        tester
            .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
            .scrollDirection,
        Axis.vertical,
      );
      expect(
        tester.getTopLeft(find.byKey(_third)).dy,
        greaterThan(tester.getTopLeft(find.byKey(_first)).dy),
      );
    });

    testWidgets('a vertical wrap scrolls horizontally', (tester) async {
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 60,
            height: 100,
            child: WrapLayout(
              direction: Axis.vertical,
              scrollable: true,
              children: _tiles(),
            ),
          ),
        ),
      );

      expect(
        tester
            .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
            .scrollDirection,
        Axis.horizontal,
      );
      expect(
        tester.getTopLeft(find.byKey(_third)).dx,
        greaterThan(tester.getTopLeft(find.byKey(_first)).dx),
      );
    });
  });
}
```

with:

```dart
  group('WrapLayout scroll', () {
    testWidgets('a horizontal wrap scrolls vertically and still wraps (D1)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 100,
            height: 60,
            child: WrapLayout(
              scroll: const StratumScroll(),
              children: _tiles(),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(
        tester
            .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
            .scrollDirection,
        Axis.vertical,
      );
      expect(
        tester.getTopLeft(find.byKey(_third)).dy,
        greaterThan(tester.getTopLeft(find.byKey(_first)).dy),
      );
    });

    testWidgets('a vertical wrap scrolls horizontally', (tester) async {
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 60,
            height: 100,
            child: WrapLayout(
              direction: Axis.vertical,
              scroll: const StratumScroll(),
              children: _tiles(),
            ),
          ),
        ),
      );

      expect(
        tester
            .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
            .scrollDirection,
        Axis.horizontal,
      );
      expect(
        tester.getTopLeft(find.byKey(_third)).dx,
        greaterThan(tester.getTopLeft(find.byKey(_first)).dx),
      );
    });
  });
}
```

Run: `grep -rn "scrollable" test/src/components/common`
Expected: no output.

- [ ] **Step 11: Run the box test to verify it fails**

Run: `flutter test --no-pub test/src/components/common/layout/box_layout_test.dart`
Expected: FAIL at compile time, with `Error: The super constructor has no corresponding named parameter.` and `Error: No named parameter with the name 'scroll'.`

- [ ] **Step 12: Rewrite `BoxLayout` on `StratumScroll`**

Replace all of `lib/src/components/common/layout/box_layout.dart` with:

```dart
import 'dart:math' as math;

import 'package:stratum_ui/src/components/common/layout/scroll_frame.dart';
import 'package:stratum_ui/src/src.dart';

/// The base of the box layouts: one build pipeline for style, transforms,
/// interaction, semantics, and scrolling.
///
/// A subclass declares its own parameters and overrides [buildContent].
/// When [style], [ratio], [rotate], [transform], [interaction], and
/// [scroll] are null, the layout builds the bare tier: the content with
/// only the [semantics], [repaintBoundary], [debug], and [keepAlive]
/// wrappers, and no [AnimatedStyledBox]. Otherwise it builds the box tier
/// around an [AnimatedStyledBox].
///
/// The tier depends on whether a parameter is null, never on its content.
/// Content remounts when the tier changes (switching [scroll] between null
/// and a value on an otherwise bare layout counts), when [rotate] switches
/// between null and a value, when [repaintBoundary], [debug], or
/// [keepAlive] changes, or, on a bare layout, when [semantics] switches
/// between null and a value. Pass `const WidgetStyle()` or
/// `const StratumInteraction()` up front when a value can appear later; a
/// layout that toggles [scroll] passes `const WidgetStyle()` so the toggle
/// stays inside the box tier.
///
/// Inside the box tier, a scrolling layout's scroll position survives a
/// [style], [interaction], [semantics], or [StratumScroll] field change;
/// only a tier change, a new [StratumScroll.controller], or a flip of
/// [StratumScroll.fillViewport] resets it.
abstract class BoxLayout extends StatelessWidget {
  const new({
    super.key,
    this.style,
    this.ratio,
    this.rotate,
    this.transform,
    this.transformAlignment,
    this.keepAlive = false,
    this.repaintBoundary = false,
    this.debug = false,
    this.semantics,
    this.onEndAnimate,
    this.interaction,
    this.scroll,
  });

  /// Every visual value of the box: spacing, size, fill, border, shadows,
  /// blur, opacity, and animation.
  final WidgetStyle? style;

  /// Width divided by height, ignored unless greater than 0: of the
  /// content, or, with [scroll], of the visible frame, while the content
  /// scrolls inside it.
  final double? ratio;

  /// Clockwise rotation in degrees.
  final double? rotate;
  final Matrix4? transform;
  final AlignmentGeometry? transformAlignment;

  /// Keeps this layout alive when a lazy list scrolls it away.
  final bool keepAlive;
  final bool repaintBoundary;
  final bool debug;

  /// Semantics of the box, inside its margin. With a tap surface they
  /// replace the surface's button role.
  final SemanticsProperties? semantics;

  /// Called when a style animation completes; an instant change does not
  /// call it.
  final VoidCallback? onEndAnimate;

  /// Pointer, focus, and semantics settings of the tap surface; see
  /// [StratumInteraction].
  final StratumInteraction? interaction;

  /// Scrolls the padding and content inside the box along
  /// [StratumScroll.direction], else [scrollDirection], while fill, border,
  /// radius, and shadow stay in place. Null does not scroll.
  final StratumScroll? scroll;

  static const _interactionAnimation = AnimationStyle(
    duration: Duration(milliseconds: 100),
  );

  @nonVirtual
  @override
  Widget build(BuildContext context) {
    var current = _isBare ? _buildBare(context) : _buildBox(context);
    if (repaintBoundary) current = RepaintBoundary(child: current);
    if (debug) current = WidgetPerformanceMonitor(child: current);
    if (keepAlive) current = _KeepAlive(child: current);
    return current;
  }

  /// The layout's own content: a Column, Row, Stack, Wrap, or child.
  @protected
  Widget buildContent(BuildContext context);

  /// The axis that [scroll] scrolls along when [StratumScroll.direction]
  /// is null.
  @protected
  Axis get scrollDirection => Axis.vertical;

  bool get _isBare =>
      style == null &&
      ratio == null &&
      rotate == null &&
      transform == null &&
      interaction == null &&
      scroll == null;

  Widget _buildBare(BuildContext context) {
    final content = buildContent(context);
    final properties = semantics;
    if (properties == null) return content;
    return Semantics.fromProperties(properties: properties, child: content);
  }

  Widget _buildBox(BuildContext context) {
    final style = _effectiveStyle;
    final aspect = ratio;
    final duration = style?.animationStyle?.duration ?? Duration.zero;
    final scroll = this.scroll;
    Widget current = AnimatedStyledBox(
      style: style,
      ratio: aspect != null && aspect > 0 ? aspect : null,
      transform: transform,
      transformAlignment: transformAlignment,
      onEnd: duration > Duration.zero ? onEndAnimate : null,
      boxBuilder: _boxBuilder,
      scrollBuilder: scroll == null
          ? null
          : (content) => _buildScroll(scroll, content),
      child: buildContent(context),
    );
    final degrees = rotate;
    if (degrees != null) {
      current = Transform.rotate(
        angle: degrees * math.pi / 180,
        child: current,
      );
    }
    return current;
  }

  /// The style, with a 100 ms animation when an interaction is set and the
  /// style has no animation of its own.
  WidgetStyle? get _effectiveStyle {
    final style = this.style;
    if (style == null || interaction == null) return style;
    if (style.animationStyle != null) return style;
    return style.copyWith(animationStyle: _interactionAnimation);
  }

  StyledBoxBuilder? get _boxBuilder {
    final interaction = this.interaction;
    if (interaction != null && _needsTapSurface(interaction)) {
      return (style, box) => _buildInkWell(interaction, style, box);
    }
    if (semantics != null) return _buildSemantics;
    return null;
  }

  static bool _needsTapSurface(StratumInteraction interaction) =>
      interaction.onTap != null ||
      interaction.onDoubleTap != null ||
      interaction.onLongPress != null ||
      interaction.onSecondaryTap != null ||
      interaction.onHover != null ||
      interaction.onHighlightChanged != null ||
      interaction.onFocusChange != null;

  Widget _buildSemantics(WidgetStyle style, Widget box) {
    return Semantics.fromProperties(properties: semantics!, child: box);
  }

  Widget _buildInkWell(
    StratumInteraction interaction,
    WidgetStyle style,
    Widget box,
  ) {
    return StratumInkWell(
      borderRadius: style.borderRadius,
      onTap: interaction.onTap,
      onDoubleTap: interaction.onDoubleTap,
      onLongPress: interaction.onLongPress,
      onSecondaryTap: interaction.onSecondaryTap,
      onHover: interaction.onHover,
      onHighlightChanged: interaction.onHighlightChanged,
      mouseCursor: interaction.mouseCursor,
      enableFeedback: interaction.enableFeedback,
      disabledPressAnimation: interaction.disabledPressAnimation,
      focusNode: interaction.focusNode,
      focusType: interaction.focusType,
      showFocusOnPrimary: interaction.showFocusOnPrimary,
      canRequestFocus: interaction.canRequestFocus,
      autofocus: interaction.autofocus,
      onFocusChange: interaction.onFocusChange,
      disabled: interaction.disabled,
      statesController: interaction.statesController,
      excludeFromSemantics: interaction.excludeFromSemantics,
      semantics: semantics,
      child: box,
    );
  }

  /// Scrolls [content] (the padding and the layout's content) inside the
  /// box, as [scroll] says.
  Widget _buildScroll(StratumScroll scroll, Widget content) {
    return ScrollFrame(
      showScrollbar: scroll.showScrollbar,
      child: _BoxScrollView(
        scroll: scroll,
        axis: scroll.direction ?? scrollDirection,
        child: content,
      ),
    );
  }
}

/// The [SingleChildScrollView] of a scrolling box layout.
///
/// With [StratumScroll.fillViewport], content shorter than a finite
/// viewport stretches to it through a [LayoutBuilder]; in a parent that is
/// unbounded along [axis] the content keeps its own size (D17).
class _BoxScrollView extends StatelessWidget {
  const new({required this.scroll, required this.axis, required this.child});

  final StratumScroll scroll;
  final Axis axis;
  final Widget child;

  Widget _view(Widget content) {
    return SingleChildScrollView(
      scrollDirection: axis,
      reverse: scroll.reverse,
      controller: scroll.controller,
      primary: scroll.primary,
      physics: scroll.physics,
      keyboardDismissBehavior: scroll.keyboardDismissBehavior,
      restorationId: scroll.restorationId,
      child: content,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!scroll.fillViewport) return _view(child);
    return LayoutBuilder(
      builder: (context, constraints) {
        final extent = axis == Axis.vertical
            ? constraints.maxHeight
            : constraints.maxWidth;
        final min = extent.isFinite ? extent : 0.0;
        return _view(
          ConstrainedBox(
            constraints: axis == Axis.vertical
                ? BoxConstraints(minHeight: min)
                : BoxConstraints(minWidth: min),
            child: child,
          ),
        );
      },
    );
  }
}

/// Keeps [child] alive inside a lazy list; does nothing elsewhere.
class _KeepAlive extends StatefulWidget {
  const new({required this.child});

  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
```

`_BoxScrollView` builds the `LayoutBuilder` only for `fillViewport: true`; without it the `SingleChildScrollView` keeps its content's size and reports intrinsic sizes (`RenderSingleChildViewport` forwards them), so the layout works under `AlertDialog`, `IntrinsicWidth`, and `IntrinsicHeight`. A non-finite viewport gives a minimum of 0, so an unbounded parent never sets an infinite minimum (D17).

In `lib/src/components/common/layout/column_layout.dart` and `lib/src/components/common/layout/row_layout.dart`, replace (once in each file):

```dart
    super.interaction,
    super.scrollable,
```

with:

```dart
    super.interaction,
    super.scroll,
```

and replace (once in each file):

```dart
  @override
  bool get stretchesToViewport => _mainAxisSize == MainAxisSize.max;

  @override
  Widget buildContent(BuildContext context) {
```

with:

```dart
  @override
  Widget buildContent(BuildContext context) {
```

In `lib/src/components/common/layout/row_layout.dart`, replace:

```dart
/// fills the width it is given. [gap] becomes [Row.spacing], and
/// `scrollable` scrolls horizontally.
```

with:

```dart
/// fills the width it is given. [gap] becomes [Row.spacing], and `scroll`
/// scrolls horizontally unless its `direction` says otherwise.
```

In `lib/src/components/common/layout/stack_layout.dart`, replace:

```dart
/// `style.clipBehavior`. `scrollable` scrolls vertically.
```

with:

```dart
/// `style.clipBehavior`. `scroll` scrolls vertically unless its `direction`
/// says otherwise.
```

In `lib/src/components/common/layout/wrap_layout.dart`, replace:

```dart
/// `scrollable` scrolls across [direction], so a horizontal wrap keeps its
```

with:

```dart
/// `scroll` scrolls across [direction], so a horizontal wrap keeps its
```

In `lib/src/components/common/layout/stack_layout.dart`, `lib/src/components/common/layout/wrap_layout.dart`, and `lib/src/components/common/layout/container_layout.dart`, replace (once in each file):

```dart
    super.interaction,
    super.scrollable,
```

with:

```dart
    super.interaction,
    super.scroll,
```

Run: `grep -rn "scrollable\|stretchesToViewport" lib/src/components/common`
Expected: no output.

- [ ] **Step 13: Run the ported tests to verify they pass**

Run each file on its own:

```bash
flutter test --no-pub test/src/components/common/layout/box_layout_test.dart
flutter test --no-pub test/src/components/common/layout/column_layout_test.dart
flutter test --no-pub test/src/components/common/layout/row_layout_test.dart
flutter test --no-pub test/src/components/common/layout/stack_layout_test.dart
flutter test --no-pub test/src/components/common/layout/wrap_layout_test.dart
```

Expected: PASS with `+36`, `+14`, `+10`, `+7`, and `+7` tests.

- [ ] **Step 14: Analyze and run the phase suite**

Run: `flutter analyze --no-pub lib/src/components/common/layout lib/src/components/common/model/scroll.dart lib/src/components/common/style test/src/components/common/layout test/src/components/common/model/scroll_test.dart test/src/components/common/style`
Expected: `22 issues found.`, all infos older than this phase: 16 in `list_view_layout_test.dart`, 4 in `grid_view_layout_test.dart`, 1 in `custom_scroll_view_layout_test.dart`, and the `scale` deprecation at `box_layout_test.dart:98`, in a phase 3 line. None is in code this task wrote.

Run: `mkdir -p build && flutter test --no-pub test/src/components/common/ test/src/themes/ > build/p4-t2.log 2>&1; tail -n 1 build/p4-t2.log`
Expected: `+486: All tests passed!`

- [ ] **Step 15: Commit**

```bash
cd "<repo>"
git add -- lib/src/components/common/model/scroll.dart lib/src/components/common/model/model.dart lib/src/components/common/layout/box_layout.dart lib/src/components/common/layout/column_layout.dart lib/src/components/common/layout/row_layout.dart lib/src/components/common/layout/stack_layout.dart lib/src/components/common/layout/wrap_layout.dart lib/src/components/common/layout/container_layout.dart lib/src/components/common/style/animated_styled_box.dart test/src/components/common/model/scroll_test.dart test/src/components/common/layout/box_layout_test.dart test/src/components/common/layout/column_layout_test.dart test/src/components/common/layout/row_layout_test.dart test/src/components/common/layout/stack_layout_test.dart test/src/components/common/layout/wrap_layout_test.dart test/src/components/common/style/animated_styled_box_test.dart
git commit -m "feat(layout): scroll box layouts through StratumScroll with an opt-in viewport fill" -- lib/src/components/common/model/scroll.dart lib/src/components/common/model/model.dart lib/src/components/common/layout/box_layout.dart lib/src/components/common/layout/column_layout.dart lib/src/components/common/layout/row_layout.dart lib/src/components/common/layout/stack_layout.dart lib/src/components/common/layout/wrap_layout.dart lib/src/components/common/layout/container_layout.dart lib/src/components/common/style/animated_styled_box.dart test/src/components/common/model/scroll_test.dart test/src/components/common/layout/box_layout_test.dart test/src/components/common/layout/column_layout_test.dart test/src/components/common/layout/row_layout_test.dart test/src/components/common/layout/stack_layout_test.dart test/src/components/common/layout/wrap_layout_test.dart test/src/components/common/style/animated_styled_box_test.dart
```

---
### Task 3: Reduced motion reads the app's `MediaQuery`

**Agent:** general-purpose
**Implements:** P4-3

Phase 3 read only the platform flags, so an app that sets `MediaQueryData.disableAnimations` itself, or a test, never reached the box (owner ruling A, 2026-10-01). `MediaQueryData` has no `reduceMotion` field (`widgets/media_query.dart:668-669` in the SDK), so that flag still comes from the view's dispatcher.

**Files:**
- Modify: `lib/src/components/common/style/animated_styled_box.dart` (`_reducesMotion` and the class doc)
- Modify: `test/src/components/common/style/animated_styled_box_test.dart` (two cases in `AnimatedStyledBox reduced motion`)

**Interfaces:**
- Consumes: `MediaQuery.maybeDisableAnimationsOf(BuildContext)` (`widgets/media_query.dart:2026`), which returns null when no `MediaQuery` above sets the aspect.
- Produces: no new names.

- [ ] **Step 1: Write the failing test**

In `test/src/components/common/style/animated_styled_box_test.dart`, replace:

```dart
    testWidgets('(pin) without a flag the geometry animates', (tester) async {
```

with:

```dart
    testWidgets("the app's MediaQuery disableAnimations makes geometry jump", (
      tester,
    ) async {
      Widget build(WidgetStyle style) => MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: _host(style, child: null),
      );

      await tester.pumpWidget(build(small));
      await tester.pumpWidget(build(large));

      expect(tester.getSize(_decorated()), const Size(80, 40));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.getSize(_decorated()), const Size(80, 40));
      expect(_fillColor(tester), Color.lerp(_red, _blue, 0.5));
    });

    testWidgets('(pin) the platform reduceMotion still applies under a '
        'MediaQuery without disableAnimations', (tester) async {
      useFeatures(tester, const FakeAccessibilityFeatures(reduceMotion: true));
      Widget build(WidgetStyle style) => MediaQuery(
        data: const MediaQueryData(),
        child: _host(style, child: null),
      );

      await tester.pumpWidget(build(small));
      await tester.pumpWidget(build(large));
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.getSize(_decorated()), const Size(80, 40));
    });

    testWidgets('(pin) without a flag the geometry animates', (tester) async {
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test --no-pub test/src/components/common/style/animated_styled_box_test.dart`
Expected: FAIL in `the app's MediaQuery disableAnimations makes geometry jump`, with `Expected: Size:<Size(80.0, 40.0)>` and `Actual: _DebugSize:<Size(40.0, 20.0)>`: the geometry still animates. The `(pin)` case passes.

- [ ] **Step 3: Read `disableAnimations` from the `MediaQuery`**

In `lib/src/components/common/style/animated_styled_box.dart`, replace:

```dart
  /// Whether the platform asks for less motion. `MediaQueryData` has no
  /// `reduceMotion` field, so the flags come from the view's dispatcher.
  bool get _reducesMotion {
    final features = View.of(context).platformDispatcher.accessibilityFeatures;
    return features.disableAnimations || features.reduceMotion;
  }
```

with:

```dart
  /// Whether the app or the platform asks for less motion.
  ///
  /// `disableAnimations` comes from the nearest [MediaQuery], so an app or
  /// a test that sets it reaches the box, else from the platform.
  /// `MediaQueryData` has no `reduceMotion` field, so that flag always
  /// comes from the view's dispatcher.
  bool get _reducesMotion {
    final features = View.of(context).platformDispatcher.accessibilityFeatures;
    final disable =
        MediaQuery.maybeDisableAnimationsOf(context) ??
        features.disableAnimations;
    return disable || features.reduceMotion;
  }
```

Replace:

```dart
/// When the platform asks for less motion (`disableAnimations` or
/// `reduceMotion`), size, spacing, and alignment jump to the new style while
/// colors, gradients, images, borders, radius, shadows, blur, and opacity
/// still fade over the full duration.
```

with:

```dart
/// When the app's [MediaQuery] or the platform asks for less motion
/// (`disableAnimations`, or the platform's `reduceMotion`), size, spacing,
/// and alignment jump to the new style while colors, gradients, images,
/// borders, radius, shadows, blur, and opacity still fade over the full
/// duration.
```

`_reducesMotion` runs in `didUpdateWidget`, where an inherited lookup is allowed, so the box reads the flag again on every style change, as the phase 3 pin `reads the flag again on every style change` requires. The root `View` builds its `MediaQuery` from the platform's accessibility features, so the platform `disableAnimations` path keeps working through the `MediaQuery` read.

- [ ] **Step 4: Run it to verify it passes**

Run: `flutter test --no-pub test/src/components/common/style/animated_styled_box_test.dart`
Expected: PASS, `+43: All tests passed!`

- [ ] **Step 5: Run the phase suite**

Run: `flutter test --no-pub test/src/components/common/ test/src/themes/ > build/p4-t3.log 2>&1; tail -n 1 build/p4-t3.log`
Expected: `+488: All tests passed!`

- [ ] **Step 6: Commit**

```bash
cd "<repo>"
git add -- lib/src/components/common/style/animated_styled_box.dart test/src/components/common/style/animated_styled_box_test.dart
git commit -m "feat(style): honor the app's MediaQuery disableAnimations in AnimatedStyledBox" -- lib/src/components/common/style/animated_styled_box.dart test/src/components/common/style/animated_styled_box_test.dart
```

---
### Task 4: K1, the context-menu key and Shift+F10

**Agent:** general-purpose
**Implements:** P4-4, D15 (secondary tap by keyboard and screen reader)

No key reached `onSecondaryTap`, and screen readers reached only tap and long press among the activation actions (`widgets/gesture_detector.dart:1715-1718` in the SDK). `StratumInkWell` now binds the context-menu key and Shift+F10 while its node or a descendant has focus, on every platform, and adds a custom semantics action. Neither `WidgetsApp.defaultShortcuts` nor `DefaultTextEditingShortcuts` binds either key (spec section 12), so the binding takes nothing from the app.

**Files:**
- Modify: `lib/src/components/common/ink_well.dart`
- Modify: `lib/src/components/common/model/interaction.dart`
- Modify: `lib/src/components/common/layout/box_layout.dart` (forward one field)
- Modify: `test/src/components/common/ink_well_test.dart` (helpers and the group `StratumInkWell context-menu key`)
- Modify: `test/src/components/common/layout/box_layout_test.dart` (`hands every interaction field to the tap surface`)

**Interfaces:**
- Consumes: `CallbackShortcuts` (`widgets/shortcuts.dart:1182-1236`: it wraps its child in a `Focus(canRequestFocus: false, skipTraversal: true)` whose `onKeyEvent` sees every key that bubbles up from a focused descendant); `MaterialLocalizations.showMenuTooltip` (`material/material_localizations.dart:93`; the default English value is `'Show menu'`, `:1110`); `LogicalKeyboardKey.contextMenu` (`services/keyboard_key.g.dart:895`).
- Produces: `StratumInkWell.secondaryTapSemanticsLabel` and `StratumInteraction.secondaryTapSemanticsLabel` (`String?`); private `_StratumInkWellState._bindings` (`Map<ShortcutActivator, VoidCallback>`) and `_contextMenuKeys`, which Task 5 extends with `shortcuts`.

- [ ] **Step 1: Write the failing tests**

In `test/src/components/common/ink_well_test.dart`, replace:

```dart
Future<TestGesture> _mouse(WidgetTester tester) async {
```

with:

```dart
/// Material localizations whose menu tooltip differs from the default.
class _MenuLocalizations extends DefaultMaterialLocalizations {
  const new();

  @override
  String get showMenuTooltip => 'Open menu';
}

class _MenuLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const new();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      SynchronousFuture(const _MenuLocalizations());

  @override
  bool shouldReload(_MenuLocalizationsDelegate old) => false;
}

Future<void> _shiftF10(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.f10);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
}

Future<TestGesture> _mouse(WidgetTester tester) async {
```

Replace:

```dart
      expect(hovers, [true, false]);
    });
  });
}
```

with:

```dart
      expect(hovers, [true, false]);
    });
  });

  group('StratumInkWell context-menu key', () {
    testWidgets('the context-menu key and Shift+F10 call onSecondaryTap', (
      tester,
    ) async {
      var calls = 0;
      final node = _node();
      await tester.pumpWidget(
        themedHost(
          StratumInkWell(
            onSecondaryTap: () => calls++,
            focusNode: node,
            child: _box,
          ),
        ),
      );
      node.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
      await _shiftF10(tester);

      expect(calls, 2);
    });

    testWidgets('neither key fires while disabled', (tester) async {
      var calls = 0;
      final inner = _node();
      await tester.pumpWidget(
        themedHost(
          StratumInkWell(
            onSecondaryTap: () => calls++,
            disabled: true,
            child: Focus(focusNode: inner, child: _box),
          ),
        ),
      );
      inner.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
      await _shiftF10(tester);

      expect(calls, 0);
    });

    testWidgets('the semantics action takes secondaryTapSemanticsLabel', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        themedHost(
          const StratumInkWell(
            onSecondaryTap: _noop,
            secondaryTapSemanticsLabel: 'Row options',
            child: _box,
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byType(StratumInkWell)),
        isSemantics(
          customActions: [const CustomSemanticsAction(label: 'Row options')],
        ),
      );
      handle.dispose();
    });

    testWidgets('the semantics action falls back to showMenuTooltip', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        Localizations(
          locale: const Locale('en'),
          delegates: const [
            _MenuLocalizationsDelegate(),
            DefaultWidgetsLocalizations.delegate,
          ],
          child: themedHost(
            const StratumInkWell(onSecondaryTap: _noop, child: _box),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byType(StratumInkWell)),
        isSemantics(
          customActions: [const CustomSemanticsAction(label: 'Open menu')],
        ),
      );
      handle.dispose();
    });

    testWidgets("without localizations the semantics action reads 'Show "
        "menu'", (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        themedHost(const StratumInkWell(onSecondaryTap: _noop, child: _box)),
      );

      expect(
        tester.getSemantics(find.byType(StratumInkWell)),
        isSemantics(
          customActions: [const CustomSemanticsAction(label: 'Show menu')],
        ),
      );
      handle.dispose();
    });

    testWidgets('toggling disabled keeps the child State', (tester) async {
      Widget build({required bool disabled}) => themedHost(
        StratumInkWell(
          onSecondaryTap: _noop,
          disabled: disabled,
          child: const _Probe(),
        ),
      );

      await tester.pumpWidget(build(disabled: false));
      final before = tester.state(find.byType(_Probe));
      await tester.pumpWidget(build(disabled: true));

      expect(tester.state(find.byType(_Probe)), same(before));
    });

    testWidgets('a disabled surface has no semantics action', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        themedHost(
          const StratumInkWell(
            onSecondaryTap: _noop,
            disabled: true,
            child: _box,
          ),
        ),
      );

      final data = tester
          .getSemantics(find.byType(StratumInkWell))
          .getSemanticsData();
      expect(data.customSemanticsActionIds ?? const <int>[], isEmpty);
      handle.dispose();
    });
  });
}
```

The disabled case focuses a node inside the surface: a disabled surface takes no focus itself, so only a focused descendant can send a key past the bindings.

In `test/src/components/common/layout/box_layout_test.dart`, replace:

```dart
              statesController: states,
              excludeFromSemantics: true,
            ),
```

with:

```dart
              statesController: states,
              excludeFromSemantics: true,
              secondaryTapSemanticsLabel: 'Options',
            ),
```

Replace:

```dart
      expect(ink.excludeFromSemantics, isTrue);
      expect(ink.semantics, same(label));
```

with:

```dart
      expect(ink.excludeFromSemantics, isTrue);
      expect(ink.secondaryTapSemanticsLabel, 'Options');
      expect(ink.semantics, same(label));
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test --no-pub test/src/components/common/ink_well_test.dart`
Expected: FAIL at compile time, with `Error: No named parameter with the name 'secondaryTapSemanticsLabel'.`

Run: `flutter test --no-pub test/src/components/common/layout/box_layout_test.dart`
Expected: FAIL at compile time, with `Error: No named parameter with the name 'secondaryTapSemanticsLabel'.`

- [ ] **Step 3: Bind the keys and add the semantics action**

In `lib/src/components/common/ink_well.dart`, replace:

```dart
/// * a [FocusSpread] ring, shown per [focusType];
/// * a semantics node with a button role and a disabled flag.
```

with:

```dart
/// * a [FocusSpread] ring, shown per [focusType];
/// * a semantics node with a button role and a disabled flag;
/// * the context-menu key and Shift+F10 for [onSecondaryTap], and a custom
///   semantics action for it, so keyboard and screen-reader users reach
///   the secondary tap (K1).
```

Replace:

```dart
    this.semantics,
    this.excludeFromSemantics = false,
    this.enableFeedback = true,
  });
```

with:

```dart
    this.semantics,
    this.excludeFromSemantics = false,
    this.enableFeedback = true,
    this.secondaryTapSemanticsLabel,
  });
```

Replace:

```dart
  final GestureTapCallback? onTap;
  final GestureTapCallback? onDoubleTap;
  final GestureLongPressCallback? onLongPress;
  final GestureTapCallback? onSecondaryTap;
```

with:

```dart
  final GestureTapCallback? onTap;

  /// Has no keyboard or screen-reader path; never make a function
  /// reachable only by double tap (WCAG 2.1.1).
  final GestureTapCallback? onDoubleTap;
  final GestureLongPressCallback? onLongPress;

  /// Also called by the context-menu key and Shift+F10 while this widget
  /// has focus, and by a custom semantics action labeled
  /// [secondaryTapSemanticsLabel].
  final GestureTapCallback? onSecondaryTap;
```

Replace:

```dart
  /// Plays the platform click and long-press feedback.
  final bool enableFeedback;

  @override
  State<StratumInkWell> createState() => _StratumInkWellState();
}

class _StratumInkWellState extends State<StratumInkWell> {
```

with:

```dart
  /// Plays the platform click and long-press feedback.
  final bool enableFeedback;

  /// Label of the semantics action for [onSecondaryTap]; null uses
  /// `MaterialLocalizations.showMenuTooltip` when material localizations
  /// are present, else `'Show menu'`.
  final String? secondaryTapSemanticsLabel;

  @override
  State<StratumInkWell> createState() => _StratumInkWellState();
}

class _StratumInkWellState extends State<StratumInkWell> {
  /// The keys that open a context menu (K1).
  static const _contextMenuKeys = [
    SingleActivator(LogicalKeyboardKey.contextMenu),
    SingleActivator(LogicalKeyboardKey.f10, shift: true),
  ];

```

Replace:

```dart
    widget.onTap?.call();
  }

```

with:

```dart
    widget.onTap?.call();
  }

  /// The key bindings while this widget or a descendant has focus; none
  /// while disabled.
  Map<ShortcutActivator, VoidCallback> get _bindings {
    final secondary = widget.onSecondaryTap;
    if (widget.disabled || secondary == null) return const {};
    return {for (final key in _contextMenuKeys) key: secondary};
  }

  String _secondaryTapLabel(BuildContext context) {
    return widget.secondaryTapSemanticsLabel ??
        Localizations.of<MaterialLocalizations>(
          context,
          MaterialLocalizations,
        )?.showMenuTooltip ??
        'Show menu';
  }

```

Replace:

```dart
    result = Material(type: MaterialType.transparency, child: result);
```

with:

```dart
    result = Material(type: MaterialType.transparency, child: result);
    // Built from onSecondaryTap alone, not from disabled, so toggling
    // disabled never changes the structure below.
    if (widget.onSecondaryTap != null) {
      result = CallbackShortcuts(bindings: _bindings, child: result);
    }
```

Replace:

```dart
      final hasActivation = _hasActivation;
      result = Semantics(
        container: true,
        enabled: hasActivation ? !disabled : null,
        button: hasActivation && properties == null ? true : null,
        child: result,
      );
```

with:

```dart
      final hasActivation = _hasActivation;
      final secondary = widget.onSecondaryTap;
      result = Semantics(
        container: true,
        enabled: hasActivation ? !disabled : null,
        button: hasActivation && properties == null ? true : null,
        customSemanticsActions: secondary == null || disabled
            ? null
            : {
                CustomSemanticsAction(label: _secondaryTapLabel(context)):
                    secondary,
              },
        child: result,
      );
```

`CallbackShortcuts` sits above `InkWell`'s `Focus`, so its node is the parent of the surface's node and sees the keys while the surface or anything inside it has focus. While disabled it keeps an empty map instead of disappearing, so the `InkWell` element below never remounts.

In `lib/src/components/common/model/interaction.dart`, replace:

```dart
    this.statesController,
    this.excludeFromSemantics = false,
  });
```

with:

```dart
    this.statesController,
    this.excludeFromSemantics = false,
    this.secondaryTapSemanticsLabel,
  });
```

Replace:

```dart
  final GestureLongPressCallback? onLongPress;
  final GestureTapCallback? onSecondaryTap;
```

with:

```dart
  final GestureLongPressCallback? onLongPress;

  /// Also reached by the context-menu key, Shift+F10, and a semantics
  /// action labeled [secondaryTapSemanticsLabel].
  final GestureTapCallback? onSecondaryTap;
```

Replace:

```dart
  final WidgetStatesController? statesController;
  final bool excludeFromSemantics;
}
```

with:

```dart
  final WidgetStatesController? statesController;
  final bool excludeFromSemantics;

  /// Label of the semantics action for [onSecondaryTap]; null uses the
  /// material "Show menu" tooltip.
  final String? secondaryTapSemanticsLabel;
}
```

In `lib/src/components/common/layout/box_layout.dart`, replace:

```dart
      excludeFromSemantics: interaction.excludeFromSemantics,
      semantics: semantics,
```

with:

```dart
      excludeFromSemantics: interaction.excludeFromSemantics,
      secondaryTapSemanticsLabel: interaction.secondaryTapSemanticsLabel,
      semantics: semantics,
```

- [ ] **Step 4: Run them to verify they pass**

Run: `flutter test --no-pub test/src/components/common/ink_well_test.dart`
Expected: PASS, `+43: All tests passed!`

Run: `flutter test --no-pub test/src/components/common/layout/box_layout_test.dart`
Expected: PASS, `+36: All tests passed!`

- [ ] **Step 5: Analyze and run the phase suite**

Run: `flutter analyze --no-pub lib/src/components/common/ink_well.dart lib/src/components/common/model/interaction.dart lib/src/components/common/layout/box_layout.dart test/src/components/common/ink_well_test.dart`
Expected: `No issues found!`

Run: `flutter test --no-pub test/src/components/common/ test/src/themes/ > build/p4-t4.log 2>&1; tail -n 1 build/p4-t4.log`
Expected: `+495: All tests passed!`

- [ ] **Step 6: Commit**

```bash
cd "<repo>"
git add -- lib/src/components/common/ink_well.dart lib/src/components/common/model/interaction.dart lib/src/components/common/layout/box_layout.dart test/src/components/common/ink_well_test.dart test/src/components/common/layout/box_layout_test.dart
git commit -m "feat(ink-well): open the secondary tap with the context-menu key, Shift+F10, and a semantics action" -- lib/src/components/common/ink_well.dart lib/src/components/common/model/interaction.dart lib/src/components/common/layout/box_layout.dart test/src/components/common/ink_well_test.dart test/src/components/common/layout/box_layout_test.dart
```

---
### Task 5: K2 shortcuts, shortcut-only focus, and the focus keep-alive

**Agent:** general-purpose
**Implements:** P4-5, P4-6, D15 (focus-scoped shortcut API), D16

`shortcuts` builds one `CallbackShortcuts` with the K1 keys, so a binding fires while the tap surface or a descendant has focus and never while disabled. A binding without a control, meta, or alt modifier is wrapped in a private activator that declines while primary focus is inside an `EditableText`: text-editing shortcuts sit at the app root (`widgets/app.dart:1818-1823` wraps `DefaultTextEditingShortcuts`), so any binding between a text field and the root would take its keys. `InkWell` grants focus only when `enabled && canRequestFocus` (`material/ink_well.dart:1333-1336`), so a surface with shortcuts and no activation callback moves its node to an outer `Focus`. `StratumInkWell` keeps a focused item alive the way `EditableText` does (`widgets/editable_text.dart:2638`), because `InkWell` keeps itself alive only while a highlight exists (`material/ink_well.dart:993`), which touch highlight mode never builds (`:1142-1152`).

**Files:**
- Create: `lib/src/components/common/text_entry_guard.dart`
- Modify: `lib/src/components/common/ink_well.dart`
- Modify: `lib/src/components/common/model/interaction.dart`
- Modify: `lib/src/components/common/layout/box_layout.dart` (tap-surface rule and one forwarded field)
- Modify: `test/src/components/common/ink_well_test.dart` (helpers, groups `StratumInkWell shortcuts` and `StratumInkWell focus keep-alive`)
- Modify: `test/src/components/common/layout/box_layout_test.dart` (two cases)

**Interfaces:**
- Consumes: Task 4's `_bindings` and `_contextMenuKeys`.
- Produces: `bool primaryFocusInEditableText()` in `common/text_entry_guard.dart` (not exported; Tasks 6 and 7 import it directly); `StratumInkWell.shortcuts` and `StratumInteraction.shortcuts` (`Map<ShortcutActivator, VoidCallback>`, default `const {}`); `BoxLayout` builds the tap surface for a non-empty `shortcuts`; `_StratumInkWellState` mixes in `AutomaticKeepAliveClientMixin` with `wantKeepAlive => _focusNode.hasFocus`.

- [ ] **Step 1: Write the failing tests**

In `test/src/components/common/ink_well_test.dart`, replace:

```dart
Future<void> _shiftF10(WidgetTester tester) async {
```

with:

```dart
/// [child] under a [MaterialApp], which a [TextField] needs.
Widget _appHost(Widget child) {
  return MaterialApp(home: Material(child: themedHost(child)));
}

Future<void> _controlK(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
}

const _keyA = SingleActivator(LogicalKeyboardKey.keyA);
const _controlKey = SingleActivator(LogicalKeyboardKey.keyK, control: true);

Future<void> _shiftF10(WidgetTester tester) async {
```

Replace:

```dart
      expect(data.customSemanticsActionIds ?? const <int>[], isEmpty);
      handle.dispose();
    });
  });
}
```

with:

```dart
      expect(data.customSemanticsActionIds ?? const <int>[], isEmpty);
      handle.dispose();
    });
  });

  group('StratumInkWell shortcuts', () {
    testWidgets('a binding fires only while the surface has focus', (
      tester,
    ) async {
      var calls = 0;
      final node = _node();
      await tester.pumpWidget(
        themedHost(
          StratumInkWell(
            onTap: _noop,
            shortcuts: {_controlKey: () => calls++},
            focusNode: node,
            child: _box,
          ),
        ),
      );

      await _controlK(tester);
      expect(calls, 0);

      node.requestFocus();
      await tester.pump();
      await _controlK(tester);
      expect(calls, 1);
    });

    testWidgets('a binding never fires while disabled', (tester) async {
      var calls = 0;
      final inner = _node();
      await tester.pumpWidget(
        themedHost(
          StratumInkWell(
            onTap: _noop,
            disabled: true,
            shortcuts: {_controlKey: () => calls++},
            child: Focus(focusNode: inner, child: _box),
          ),
        ),
      );
      inner.requestFocus();
      await tester.pump();

      await _controlK(tester);

      expect(calls, 0);
    });

    testWidgets('an empty map builds no CallbackShortcuts', (tester) async {
      await tester.pumpWidget(
        themedHost(const StratumInkWell(onTap: _noop, child: _box)),
      );
      expect(find.byType(CallbackShortcuts), findsNothing);

      await tester.pumpWidget(
        themedHost(
          const StratumInkWell(
            onTap: _noop,
            shortcuts: {_keyA: _noop},
            child: _box,
          ),
        ),
      );
      expect(find.byType(CallbackShortcuts), findsOneWidget);
    });

    testWidgets('an unmodified binding is skipped inside a TextField', (
      tester,
    ) async {
      var letters = 0;
      var commands = 0;
      final field = _node();
      await tester.pumpWidget(
        _appHost(
          StratumInkWell(
            onTap: _noop,
            shortcuts: {
              _keyA: () => letters++,
              _controlKey: () => commands++,
            },
            child: SizedBox(width: 200, child: TextField(focusNode: field)),
          ),
        ),
      );
      field.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await _controlK(tester);

      expect(letters, 0);
      expect(commands, 1);
    });

    testWidgets('a shortcut-only surface takes focus on the caller node', (
      tester,
    ) async {
      _useHighlightStrategy(FocusHighlightStrategy.alwaysTraditional);
      final handle = tester.ensureSemantics();
      var calls = 0;
      final node = _node();
      await tester.pumpWidget(
        themedHost(
          StratumInkWell(
            shortcuts: {_keyA: () => calls++},
            focusNode: node,
            child: _box,
          ),
        ),
      );

      node.requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);

      expect(node.hasPrimaryFocus, isTrue);
      expect(calls, 1);
      expect(_ring(tester), isTrue);
      expect(
        tester.getSemantics(find.byType(StratumInkWell)),
        isSemantics(isButton: false, isFocusable: true, isFocused: true),
      );
      handle.dispose();
    });
  });

  group('StratumInkWell focus keep-alive', () {
    final surfaces = <String, Widget Function(FocusNode node)>{
      'a focused tap surface': (node) => StratumInkWell(
        onTap: _noop,
        focusNode: node,
        child: const SizedBox(height: 100),
      ),
      'a shortcut-only surface': (node) => StratumInkWell(
        shortcuts: const {_keyA: _noop},
        focusNode: node,
        child: const SizedBox(height: 100),
      ),
    };
    for (final MapEntry(key: name, value: surface) in surfaces.entries) {
      testWidgets('$name survives scrolling past the cache extent in touch '
          'mode', (tester) async {
        _useHighlightStrategy(FocusHighlightStrategy.alwaysTouch);
        final node = _node();
        final controller = ScrollController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          themedHost(
            SizedBox(
              height: 300,
              child: ListView.builder(
                controller: controller,
                itemCount: 100,
                itemBuilder: (context, index) => index == 0
                    ? surface(node)
                    : const SizedBox(height: 100),
              ),
            ),
          ),
        );
        node.requestFocus();
        await tester.pump();

        controller.jumpTo(5000);
        await tester.pump();

        expect(node.hasFocus, isTrue);
        expect(
          find.byType(StratumInkWell, skipOffstage: false),
          findsOneWidget,
        );
      });
    }
  });
}
```

The keep-alive cases put the focused surface first in a 300 px `ListView.builder` of 100 px items and jump 5000 px, far past the default cache extent, in `FocusHighlightStrategy.alwaysTouch`.

In `test/src/components/common/layout/box_layout_test.dart`, replace:

```dart
      'onFocusChange': StratumInteraction(onFocusChange: (_) {}),
    };
```

with:

```dart
      'onFocusChange': StratumInteraction(onFocusChange: (_) {}),
      'shortcuts': const StratumInteraction(
        shortcuts: {SingleActivator(LogicalKeyboardKey.keyA): _noop},
      ),
    };
```

Replace:

```dart
      const label = SemanticsProperties(label: 'box');
```

with:

```dart
      const label = SemanticsProperties(label: 'box');
      const shortcuts = {SingleActivator(LogicalKeyboardKey.keyA): _noop};
```

Replace:

```dart
              secondaryTapSemanticsLabel: 'Options',
            ),
```

with:

```dart
              secondaryTapSemanticsLabel: 'Options',
              shortcuts: shortcuts,
            ),
```

Replace:

```dart
      expect(ink.secondaryTapSemanticsLabel, 'Options');
```

with:

```dart
      expect(ink.secondaryTapSemanticsLabel, 'Options');
      expect(ink.shortcuts, same(shortcuts));
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test --no-pub test/src/components/common/ink_well_test.dart`
Expected: FAIL at compile time, with `Error: No named parameter with the name 'shortcuts'.`

Run: `flutter test --no-pub test/src/components/common/layout/box_layout_test.dart`
Expected: FAIL at compile time, with `Error: No named parameter with the name 'shortcuts'.`

Before this task, the first keep-alive case fails on its own: on the Task 4 code, a focused `StratumInkWell` scrolled past the cache extent in touch mode is disposed and `node.hasFocus` reads `false` (verified while writing this plan).

- [ ] **Step 3: Write the text-entry guard**

Create `lib/src/components/common/text_entry_guard.dart`:

```dart
import 'package:stratum_ui/src/src.dart';

/// Whether primary focus is inside an [EditableText].
///
/// Text-editing shortcuts sit at the app root, so a key binding between a
/// text field and the root would take Home, End, arrows, and letters from
/// it. K2 bindings without a control, meta, or alt modifier, and every K3
/// and K4 key, are skipped while this holds (spec section 6, text-entry
/// guard).
bool primaryFocusInEditableText() {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return false;
  return context.widget is EditableText ||
      context.findAncestorWidgetOfExactType<EditableText>() != null;
}
```

`EditableText` attaches its node through a `Focus` inside its own subtree (`widgets/editable_text.dart:5903-5906`), so the primary node's context finds the `EditableText` as an ancestor.

- [ ] **Step 4: Add `shortcuts`, shortcut-only focus, and the keep-alive**

In `lib/src/components/common/ink_well.dart`, replace:

```dart
import 'package:stratum_ui/src/src.dart';
```

with:

```dart
import 'package:stratum_ui/src/components/common/text_entry_guard.dart';
import 'package:stratum_ui/src/src.dart';
```

Replace:

```dart
///   the secondary tap (K1).
```

with:

```dart
///   the secondary tap (K1);
/// * focus-scoped [shortcuts] (K2);
/// * a keep-alive while it has focus, so a lazy list never disposes the
///   focused item.
```

Replace:

```dart
    this.secondaryTapSemanticsLabel,
  });

  final Widget child;
```

with:

```dart
    this.secondaryTapSemanticsLabel,
    this.shortcuts = const {},
  });

  final Widget child;
```

Replace:

```dart
  /// reachable only by double tap (WCAG 2.1.1).
  final GestureTapCallback? onDoubleTap;
```

with:

```dart
  /// reachable only by double tap (WCAG 2.1.1). Bind a key in [shortcuts]
  /// as its keyboard alternative.
  final GestureTapCallback? onDoubleTap;
```

Replace:

```dart
  final String? secondaryTapSemanticsLabel;

  @override
  State<StratumInkWell> createState() => _StratumInkWellState();
}

class _StratumInkWellState extends State<StratumInkWell> {
```

with:

```dart
  final String? secondaryTapSemanticsLabel;

  /// Key bindings that fire while this widget or a descendant has focus,
  /// never while [disabled]. A binding without a control, meta, or alt
  /// modifier is skipped while focus is inside a text field, so typing
  /// still reaches the field (WCAG 2.1.4). With no activation callback the
  /// focus node moves to an outer [Focus], because [InkWell] grants focus
  /// only to an enabled surface; the node then reports focusable and no
  /// button role. An empty map builds nothing.
  final Map<ShortcutActivator, VoidCallback> shortcuts;

  @override
  State<StratumInkWell> createState() => _StratumInkWellState();
}

class _StratumInkWellState extends State<StratumInkWell>
    with AutomaticKeepAliveClientMixin<StratumInkWell> {
```

Replace:

```dart
      widget.onSecondaryTap != null;

  bool get _canFocus =>
```

with:

```dart
      widget.onSecondaryTap != null;

  /// Whether the focus node sits on an outer [Focus] instead of [InkWell]:
  /// shortcuts with no activation callback (K2).
  bool get _shortcutOnly => !_hasActivation && widget.shortcuts.isNotEmpty;

  /// Keeps a focused item alive in a lazy list, also in touch highlight
  /// mode and for a shortcut-only node, where [InkWell] builds no focus
  /// highlight that would keep it alive (D16).
  @override
  bool get wantKeepAlive => _focusNode.hasFocus;

  bool get _canFocus =>
```

Replace:

```dart
      _focusNode.addListener(_handleFocusChange);
    }
    if (oldWidget.statesController != null &&
```

with:

```dart
      _focusNode.addListener(_handleFocusChange);
      updateKeepAlive();
    }
    if (oldWidget.statesController != null &&
```

Replace:

```dart
  void _handleFocusChange() {
    if (_hasRing) setState(() {});
  }
```

with:

```dart
  void _handleFocusChange() {
    updateKeepAlive();
    if (_hasRing) setState(() {});
  }
```

Replace:

```dart
  Map<ShortcutActivator, VoidCallback> get _bindings {
    final secondary = widget.onSecondaryTap;
    if (widget.disabled || secondary == null) return const {};
    return {for (final key in _contextMenuKeys) key: secondary};
  }
```

with:

```dart
  Map<ShortcutActivator, VoidCallback> get _bindings {
    if (widget.disabled) return const {};
    final secondary = widget.onSecondaryTap;
    return {
      if (secondary != null)
        for (final key in _contextMenuKeys) key: secondary,
      for (final MapEntry(key: activator, value: callback)
          in widget.shortcuts.entries)
        _guarded(activator): callback,
    };
  }

  /// [activator], skipped inside a text field unless it holds a control,
  /// meta, or alt modifier (text-entry guard).
  static ShortcutActivator _guarded(ShortcutActivator activator) {
    if (_hasCommandModifier(activator)) return activator;
    return _TextEntryGuard(activator);
  }

  static final _commandKeys = <LogicalKeyboardKey>{
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.controlRight,
    LogicalKeyboardKey.meta,
    LogicalKeyboardKey.metaLeft,
    LogicalKeyboardKey.metaRight,
    LogicalKeyboardKey.alt,
    LogicalKeyboardKey.altLeft,
    LogicalKeyboardKey.altRight,
  };

  static bool _hasCommandModifier(ShortcutActivator activator) {
    return switch (activator) {
      SingleActivator(:final control, :final meta, :final alt) =>
        control || meta || alt,
      CharacterActivator(:final control, :final meta, :final alt) =>
        control || meta || alt,
      LogicalKeySet(:final keys) => keys.any(_commandKeys.contains),
      _ => false,
    };
  }
```

`_commandKeys` is `final`, not `const`: `LogicalKeyboardKey` overrides `==`, so a const set of keys fails with "does not have a primitive equality".

Replace:

```dart
  Widget build(BuildContext context) {
    final colors = context.theme.color;
    final disabled = widget.disabled;
    final canFocus = _canFocus;
    final onHover = widget.onHover;
```

with:

```dart
  Widget build(BuildContext context) {
    super.build(context);
    final colors = context.theme.color;
    final disabled = widget.disabled;
    final canFocus = _canFocus;
    final onHover = widget.onHover;
    final shortcutOnly = _shortcutOnly;
```

Replace:

```dart
      onFocusChange: widget.onFocusChange,
      mouseCursor:
          widget.mouseCursor ??
          (disabled ? SystemMouseCursors.forbidden : null),
      focusNode: _focusNode,
      canRequestFocus: canFocus,
      autofocus: widget.autofocus && canFocus,
```

with:

```dart
      onFocusChange: shortcutOnly ? null : widget.onFocusChange,
      mouseCursor:
          widget.mouseCursor ??
          (disabled ? SystemMouseCursors.forbidden : null),
      focusNode: shortcutOnly ? null : _focusNode,
      canRequestFocus: !shortcutOnly && canFocus,
      autofocus: !shortcutOnly && widget.autofocus && canFocus,
```

Replace:

```dart
    // Built from onSecondaryTap alone, not from disabled, so toggling
    // disabled never changes the structure below.
    if (widget.onSecondaryTap != null) {
      result = CallbackShortcuts(bindings: _bindings, child: result);
    }
```

with:

```dart
    if (shortcutOnly) {
      // InkWell grants focus only when enabled and forces canRequestFocus
      // off on a node it receives otherwise, so the node lives here.
      result = Focus(
        focusNode: _focusNode,
        canRequestFocus: canFocus,
        autofocus: widget.autofocus && canFocus,
        onFocusChange: widget.onFocusChange,
        child: result,
      );
    }
    // Built from onSecondaryTap and shortcuts, not from disabled, so
    // toggling disabled never changes the structure below.
    if (widget.onSecondaryTap != null || widget.shortcuts.isNotEmpty) {
      result = CallbackShortcuts(bindings: _bindings, child: result);
    }
```

Replace:

```dart
/// Paints the hover and press overlay over [child] from [states].
```

with:

```dart
/// [activator], skipped while primary focus is inside an [EditableText],
/// so the key reaches the text field's own shortcuts.
class _TextEntryGuard extends ShortcutActivator {
  const new(this.activator);

  final ShortcutActivator activator;

  @override
  Iterable<LogicalKeyboardKey>? get triggers => activator.triggers;

  @override
  bool accepts(KeyEvent event, HardwareKeyboard state) {
    return !primaryFocusInEditableText() && activator.accepts(event, state);
  }

  @override
  String debugDescribeKeys() => activator.debugDescribeKeys();
}

/// Paints the hover and press overlay over [child] from [states].
```

`CallbackShortcuts` asks each activator whether it accepts the event (`widgets/shortcuts.dart:1212-1218`); the guard's refusal leaves the key unhandled, so it bubbles on to the root's text-editing shortcuts. The shortcut-only `Focus` keeps the node's `focusable` flag through its own semantics, and no activation callback means no button flag.

In `lib/src/components/common/model/interaction.dart`, replace:

```dart
/// The pointer, focus, and semantics settings of a layout's tap surface.
///
/// A layout passes these to [StratumInkWell], one field to one parameter.
/// It builds the tap surface only when at least one of [onTap],
/// [onDoubleTap], [onLongPress], [onSecondaryTap], [onHover],
/// [onHighlightChanged], or [onFocusChange] is set. A value with none of
/// them still animates the layout's style over 100 ms and adds no tap
/// surface, so pass `const StratumInteraction()` when callbacks come and go:
/// switching `interaction` between null and a value remounts the content on
/// an otherwise bare layout; see `BoxLayout`'s tier rule for the full case.
```

with:

```dart
/// The pointer, focus, keyboard, and semantics settings of a layout's tap
/// surface.
///
/// A layout passes these to [StratumInkWell], one field to one parameter.
/// It builds the tap surface only when at least one of [onTap],
/// [onDoubleTap], [onLongPress], [onSecondaryTap], [onHover],
/// [onHighlightChanged], or [onFocusChange] is set, or [shortcuts] is not
/// empty. A value with none of them still animates the layout's style over
/// 100 ms and adds no tap surface, so pass `const StratumInteraction()`
/// when callbacks come and go: switching `interaction` between null and a
/// value remounts the content on an otherwise bare layout; see
/// `BoxLayout`'s tier rule for the full case.
```

Replace:

```dart
    this.secondaryTapSemanticsLabel,
  });
```

with:

```dart
    this.secondaryTapSemanticsLabel,
    this.shortcuts = const {},
  });
```

Replace:

```dart
  /// reachable only by double tap (WCAG 2.1.1).
  final GestureTapCallback? onDoubleTap;
```

with:

```dart
  /// reachable only by double tap (WCAG 2.1.1). Bind a key in [shortcuts]
  /// as its keyboard alternative.
  final GestureTapCallback? onDoubleTap;
```

Replace:

```dart
  final String? secondaryTapSemanticsLabel;
}
```

with:

```dart
  final String? secondaryTapSemanticsLabel;

  /// Key bindings that fire while the tap surface or a descendant has
  /// focus; see `StratumInkWell.shortcuts`.
  final Map<ShortcutActivator, VoidCallback> shortcuts;
}
```

In `lib/src/components/common/layout/box_layout.dart`, replace:

```dart
      interaction.onFocusChange != null;
```

with:

```dart
      interaction.onFocusChange != null ||
      interaction.shortcuts.isNotEmpty;
```

Replace:

```dart
      secondaryTapSemanticsLabel: interaction.secondaryTapSemanticsLabel,
      semantics: semantics,
```

with:

```dart
      secondaryTapSemanticsLabel: interaction.secondaryTapSemanticsLabel,
      shortcuts: interaction.shortcuts,
      semantics: semantics,
```

- [ ] **Step 5: Run them to verify they pass**

Run: `flutter test --no-pub test/src/components/common/ink_well_test.dart`
Expected: PASS, `+50: All tests passed!`

Run: `flutter test --no-pub test/src/components/common/layout/box_layout_test.dart`
Expected: PASS, `+37: All tests passed!`

- [ ] **Step 6: Analyze and run the phase suite**

Run: `flutter analyze --no-pub lib/src/components/common/ink_well.dart lib/src/components/common/text_entry_guard.dart lib/src/components/common/model/interaction.dart lib/src/components/common/layout/box_layout.dart test/src/components/common/ink_well_test.dart`
Expected: `No issues found!`

Run: `flutter test --no-pub test/src/components/common/ test/src/themes/ > build/p4-t5.log 2>&1; tail -n 1 build/p4-t5.log`
Expected: `+503: All tests passed!`

- [ ] **Step 7: Commit**

```bash
cd "<repo>"
git add -- lib/src/components/common/text_entry_guard.dart lib/src/components/common/ink_well.dart lib/src/components/common/model/interaction.dart lib/src/components/common/layout/box_layout.dart test/src/components/common/ink_well_test.dart test/src/components/common/layout/box_layout_test.dart
git commit -m "feat(ink-well): add focus-scoped shortcuts and keep a focused surface alive" -- lib/src/components/common/text_entry_guard.dart lib/src/components/common/ink_well.dart lib/src/components/common/model/interaction.dart lib/src/components/common/layout/box_layout.dart test/src/components/common/ink_well_test.dart test/src/components/common/layout/box_layout_test.dart
```

---
### Task 6: K3, `StratumFocusGroup`

**Agent:** general-purpose
**Implements:** P4-7, D15 (roving group)

`FocusGroupFrame` wraps a column's, row's, or wrap's content in a `FocusTraversalGroup` with a private policy and a non-focusable `Focus` whose `onKeyEvent` handles the group's keys. Flutter sorts each traversal group's members with that group's own policy and then walks the sorted list (`widgets/focus_traversal.dart:503-573`); the policy returns one member (the one holding the current node, else the one that last held focus, else the first in reading order), so Tab enters the group once and the next Tab leaves it. Returning fewer members passes the SDK's check, which only forbids nodes that `traversalDescendants` would not hold (`:551-571`). A `FocusTraversalPolicy` is `@immutable`, so the frame's `State` keeps the last focused node and hands the policy a getter.

**Files:**
- Create: `lib/src/components/common/layout/focus_group.dart`
- Modify: `lib/src/components/common/layout/layout.dart` (whole file)
- Modify: `lib/src/components/common/layout/column_layout.dart`, `row_layout.dart`, `wrap_layout.dart` (whole files)
- Create: `test/src/components/common/layout/focus_group_test.dart`

**Interfaces:**
- Consumes: Task 5's `primaryFocusInEditableText()`; `FocusNode.rect` (`widgets/focus_manager.dart:861-878`, global coordinates); `ReadingOrderTraversalPolicy` (`widgets/focus_traversal.dart:1566`); `Scrollable.ensureVisible`.
- Produces: `class StratumFocusGroup` (`const new({SemanticsRole? role, bool loop = false})`), exported by `layout/layout.dart` (`show StratumFocusGroup`); `enum FocusGroupAxis { vertical, horizontal, wrap }` and `class FocusGroupFrame extends StatefulWidget` (`const new({Key? key, required StratumFocusGroup group, required FocusGroupAxis axis, TextDirection? textDirection, required Widget child})`), both not exported; `focusGroup` (`StratumFocusGroup?`) on `ColumnLayout`, `RowLayout`, and `WrapLayout`.

- [ ] **Step 1: Write the failing test**

Create `test/src/components/common/layout/focus_group_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import '../fakes/fake_stratum_theme.dart';

const _dot = SizedBox(width: 10, height: 10);

void _noop() {}

FocusNode _node([String? label]) {
  final node = FocusNode(debugLabel: label);
  addTearDown(node.dispose);
  return node;
}

/// [count] focus nodes, disposed after the test.
List<FocusNode> _nodes([int count = 3]) {
  return [for (var i = 0; i < count; i++) _node('item $i')];
}

/// A 40 px tappable item on [node].
Widget _item(FocusNode node, {SemanticsProperties? semantics}) {
  return ContainerLayout(
    style: const WidgetStyle(width: 40, height: 40),
    semantics: semantics,
    interaction: StratumInteraction(onTap: _noop, focusNode: node),
  );
}

/// [child] between a focusable box before it and one after it, under the
/// app's default Tab, arrow, and activation keys.
Widget _host(Widget child, {required FocusNode before, FocusNode? after}) {
  return themedHost(
    Shortcuts(
      shortcuts: WidgetsApp.defaultShortcuts,
      child: Actions(
        actions: WidgetsApp.defaultActions,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Focus(focusNode: before, child: _dot),
            child,
            if (after != null) Focus(focusNode: after, child: _dot),
          ],
        ),
      ),
    ),
  );
}

Future<void> _focus(WidgetTester tester, FocusNode node) async {
  node.requestFocus();
  await tester.pump();
}

Future<bool> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  final handled = await tester.sendKeyEvent(key);
  await tester.pump();
  return handled;
}

Future<void> _shiftTab(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.pump();
}

void main() {
  group('StratumFocusGroup Tab', () {
    testWidgets('Tab enters the group once, on the first item', (tester) async {
      final before = _node();
      final after = _node();
      final items = _nodes();
      await tester.pumpWidget(
        _host(
          RowLayout(
            mainAxisSize: MainAxisSize.min,
            focusGroup: const StratumFocusGroup(),
            children: [for (final node in items) _item(node)],
          ),
          before: before,
          after: after,
        ),
      );
      await _focus(tester, before);

      await _key(tester, LogicalKeyboardKey.tab);
      expect(items[0].hasPrimaryFocus, isTrue);

      await _key(tester, LogicalKeyboardKey.tab);
      expect(after.hasPrimaryFocus, isTrue);
    });

    testWidgets('Tab returns to the item that last held focus', (tester) async {
      final before = _node();
      final after = _node();
      final items = _nodes();
      await tester.pumpWidget(
        _host(
          RowLayout(
            mainAxisSize: MainAxisSize.min,
            focusGroup: const StratumFocusGroup(),
            children: [for (final node in items) _item(node)],
          ),
          before: before,
          after: after,
        ),
      );
      await _focus(tester, items[2]);

      await _key(tester, LogicalKeyboardKey.tab);
      expect(after.hasPrimaryFocus, isTrue);
      await _shiftTab(tester);
      expect(items[2].hasPrimaryFocus, isTrue);

      await _focus(tester, before);
      await _key(tester, LogicalKeyboardKey.tab);
      expect(items[2].hasPrimaryFocus, isTrue);
    });

    testWidgets('Tab and Shift+Tab leave the group from any item', (
      tester,
    ) async {
      final before = _node();
      final after = _node();
      final items = _nodes();
      await tester.pumpWidget(
        _host(
          ColumnLayout(
            mainAxisSize: MainAxisSize.min,
            focusGroup: const StratumFocusGroup(),
            children: [for (final node in items) _item(node)],
          ),
          before: before,
          after: after,
        ),
      );

      await _focus(tester, items[1]);
      await _key(tester, LogicalKeyboardKey.tab);
      expect(after.hasPrimaryFocus, isTrue);

      await _focus(tester, items[1]);
      await _shiftTab(tester);
      expect(before.hasPrimaryFocus, isTrue);
    });
  });

  group('StratumFocusGroup arrows', () {
    testWidgets('Left and Right move by screen position in a row', (
      tester,
    ) async {
      final before = _node();
      final items = _nodes();
      await tester.pumpWidget(
        _host(
          RowLayout(
            mainAxisSize: MainAxisSize.min,
            focusGroup: const StratumFocusGroup(),
            children: [for (final node in items) _item(node)],
          ),
          before: before,
        ),
      );
      await _focus(tester, items[0]);

      expect(await _key(tester, LogicalKeyboardKey.arrowRight), isTrue);
      expect(items[1].hasPrimaryFocus, isTrue);
      await _key(tester, LogicalKeyboardKey.arrowRight);
      await _key(tester, LogicalKeyboardKey.arrowRight);
      expect(items[2].hasPrimaryFocus, isTrue);
      await _key(tester, LogicalKeyboardKey.arrowLeft);
      expect(items[1].hasPrimaryFocus, isTrue);
    });

    testWidgets('Left moves to the item on the left in a row under RTL', (
      tester,
    ) async {
      final before = _node();
      final items = _nodes();
      await tester.pumpWidget(
        _host(
          RowLayout(
            mainAxisSize: MainAxisSize.min,
            textDirection: TextDirection.rtl,
            focusGroup: const StratumFocusGroup(),
            children: [for (final node in items) _item(node)],
          ),
          before: before,
        ),
      );
      await _focus(tester, items[0]);

      await _key(tester, LogicalKeyboardKey.arrowLeft);
      expect(items[1].hasPrimaryFocus, isTrue);
      await _key(tester, LogicalKeyboardKey.arrowRight);
      expect(items[0].hasPrimaryFocus, isTrue);
    });

    testWidgets('Up moves to the item above in a column laid out upwards', (
      tester,
    ) async {
      final before = _node();
      final items = _nodes();
      await tester.pumpWidget(
        _host(
          ColumnLayout(
            mainAxisSize: MainAxisSize.min,
            verticalDirection: VerticalDirection.up,
            focusGroup: const StratumFocusGroup(),
            children: [for (final node in items) _item(node)],
          ),
          before: before,
        ),
      );
      await _focus(tester, items[0]);

      await _key(tester, LogicalKeyboardKey.arrowUp);
      expect(items[1].hasPrimaryFocus, isTrue);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(items[0].hasPrimaryFocus, isTrue);
    });

    testWidgets('arrows across the axis are left to Flutter', (tester) async {
      final before = _node();
      final items = _nodes();
      await tester.pumpWidget(
        _host(
          RowLayout(
            mainAxisSize: MainAxisSize.min,
            focusGroup: const StratumFocusGroup(),
            children: [for (final node in items) _item(node)],
          ),
          before: before,
        ),
      );
      await _focus(tester, items[1]);

      await _key(tester, LogicalKeyboardKey.arrowUp);

      // Flutter's directional focus moved up, out of the group.
      expect(before.hasPrimaryFocus, isTrue);
    });

    testWidgets('Up and Down move to the nearest item of the next run in a '
        'wrap', (tester) async {
      final before = _node();
      final items = _nodes(5);
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 100,
            child: WrapLayout(
              gap: 4,
              focusGroup: const StratumFocusGroup(),
              children: [for (final node in items) _item(node)],
            ),
          ),
          before: before,
        ),
      );
      // Runs: items 0 and 1, items 2 and 3, item 4.
      await _focus(tester, items[1]);

      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(items[3].hasPrimaryFocus, isTrue);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(items[4].hasPrimaryFocus, isTrue);
      await _key(tester, LogicalKeyboardKey.arrowUp);
      expect(items[2].hasPrimaryFocus, isTrue);
      await _key(tester, LogicalKeyboardKey.arrowLeft);
      expect(items[1].hasPrimaryFocus, isTrue);
      await _key(tester, LogicalKeyboardKey.arrowRight);
      expect(items[2].hasPrimaryFocus, isTrue);
    });

    testWidgets('Home and End move to the first and last item', (tester) async {
      final before = _node();
      final items = _nodes();
      await tester.pumpWidget(
        _host(
          RowLayout(
            mainAxisSize: MainAxisSize.min,
            focusGroup: const StratumFocusGroup(),
            children: [for (final node in items) _item(node)],
          ),
          before: before,
        ),
      );
      await _focus(tester, items[1]);

      await _key(tester, LogicalKeyboardKey.end);
      expect(items[2].hasPrimaryFocus, isTrue);
      await _key(tester, LogicalKeyboardKey.home);
      expect(items[0].hasPrimaryFocus, isTrue);
    });

    testWidgets('loop wraps past either end; without it focus stays', (
      tester,
    ) async {
      final before = _node();
      final items = _nodes();
      Widget build({required bool loop}) => _host(
        RowLayout(
          mainAxisSize: MainAxisSize.min,
          focusGroup: StratumFocusGroup(loop: loop),
          children: [for (final node in items) _item(node)],
        ),
        before: before,
      );

      await tester.pumpWidget(build(loop: false));
      await _focus(tester, items[2]);
      await _key(tester, LogicalKeyboardKey.arrowRight);
      expect(items[2].hasPrimaryFocus, isTrue);

      await tester.pumpWidget(build(loop: true));
      await _key(tester, LogicalKeyboardKey.arrowRight);
      expect(items[0].hasPrimaryFocus, isTrue);
      await _key(tester, LogicalKeyboardKey.arrowLeft);
      expect(items[2].hasPrimaryFocus, isTrue);
    });

    testWidgets('group keys are skipped inside a TextField', (tester) async {
      final field = _node();
      final items = _nodes(1);
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: themedHost(
              ColumnLayout(
                mainAxisSize: MainAxisSize.min,
                focusGroup: const StratumFocusGroup(),
                children: [
                  SizedBox(width: 200, child: TextField(focusNode: field)),
                  _item(items[0]),
                ],
              ),
            ),
          ),
        ),
      );
      await _focus(tester, field);

      await _key(tester, LogicalKeyboardKey.arrowDown);
      await _key(tester, LogicalKeyboardKey.end);

      expect(field.hasPrimaryFocus, isTrue);
    });
  });

  group('StratumFocusGroup role', () {
    testWidgets('tabBar over items with role tab passes the debug check', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final before = _node();
      final items = _nodes(2);
      await tester.pumpWidget(
        _host(
          RowLayout(
            mainAxisSize: MainAxisSize.min,
            focusGroup: const StratumFocusGroup(role: SemanticsRole.tabBar),
            children: [
              for (var i = 0; i < items.length; i++)
                _item(
                  items[i],
                  semantics: SemanticsProperties(
                    role: SemanticsRole.tab,
                    selected: i == 0,
                    label: 'Tab $i',
                  ),
                ),
            ],
          ),
          before: before,
        ),
      );

      expect(tester.takeException(), isNull);
      handle.dispose();
    });

    testWidgets('tabBar over items without role tab fails the debug check', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final before = _node();
      final items = _nodes(2);
      await tester.pumpWidget(
        _host(
          RowLayout(
            mainAxisSize: MainAxisSize.min,
            focusGroup: const StratumFocusGroup(role: SemanticsRole.tabBar),
            children: [for (final node in items) _item(node)],
          ),
          before: before,
        ),
      );

      expect(
        tester.takeException().toString(),
        contains('Children of TabBar must have the tab role'),
      );
      handle.dispose();
    });
  });
}
```

The host puts the app's default shortcuts and actions above the group, as `WidgetsApp` does, so Tab, Shift+Tab, and the arrows the group leaves unhandled reach Flutter's own traversal. `_key` returns whether a key was handled. The second role case is the control: it shows that the debug check runs in these tests, so the first case's pass means something.

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test --no-pub test/src/components/common/layout/focus_group_test.dart`
Expected: FAIL at compile time, with `Error: Couldn't find constructor 'StratumFocusGroup'.` and `Error: No named parameter with the name 'focusGroup'.`

- [ ] **Step 3: Write the focus group**

Create `lib/src/components/common/layout/focus_group.dart`:

```dart
import 'package:stratum_ui/src/components/common/text_entry_guard.dart';
import 'package:stratum_ui/src/src.dart';

/// Makes the focusable children of a [ColumnLayout], [RowLayout], or
/// [WrapLayout] one roving Tab stop (K3).
///
/// * Tab enters the group once and lands on the item that last held focus,
///   or on the first item; Tab and Shift+Tab then leave it (WCAG 2.1.2).
/// * Arrows along the layout axis move to the next item on screen in the
///   pressed direction: Left and Right in a row, Up and Down in a column,
///   also under right-to-left text and [VerticalDirection.up]. In a wrap,
///   Left and Right move in reading order, and Up and Down move to the
///   nearest item of the adjacent run.
/// * Arrows across the axis keep Flutter's default.
/// * Home and End move to the first and last item in reading order.
/// * With [loop], moving past either end wraps around.
///
/// The group binds its own keys, so they work the same on web, and skips
/// them while focus is inside a text field. It covers built children only;
/// a lazy list uses Tab and its own keyboard scrolling instead.
@immutable
class StratumFocusGroup {
  const new({this.role, this.loop = false});

  /// The semantics role of the group node.
  ///
  /// Flutter's debug checks constrain the items, which take their role
  /// through their own `semantics:` (`SemanticsProperties(role: ...)`):
  /// `tabBar` needs at least one item and every item with role `tab`;
  /// `menu` and `menuBar` need at least one item, and a `menuItem` must sit
  /// under one of them; `radioGroup` allows at most one checked item;
  /// `list` has no check. Set `menu`, `menuBar`, or `tabBar` only when
  /// items exist.
  final SemanticsRole? role;

  /// Whether arrows wrap from the last item to the first and back.
  final bool loop;
}

/// How a [FocusGroupFrame] lays its items out on screen.
enum FocusGroupAxis { vertical, horizontal, wrap }

/// Builds a [StratumFocusGroup] around a layout's content.
///
/// Not exported: [ColumnLayout], [RowLayout], and [WrapLayout] build it
/// from their `focusGroup`.
class FocusGroupFrame extends StatefulWidget {
  const new({
    super.key,
    required this.group,
    required this.axis,
    this.textDirection,
    required this.child,
  });

  final StratumFocusGroup group;
  final FocusGroupAxis axis;

  /// The layout's own text direction; null reads the ambient
  /// [Directionality].
  final TextDirection? textDirection;
  final Widget child;

  @override
  State<FocusGroupFrame> createState() => _FocusGroupFrameState();
}

class _FocusGroupFrameState extends State<FocusGroupFrame> {
  /// The node inside the group that last held primary focus.
  FocusNode? _last;
  late final _policy = _FocusGroupPolicy(() => _last);
  final _keys = FocusNode(
    debugLabel: 'StratumFocusGroup',
    canRequestFocus: false,
    skipTraversal: true,
  );

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_trackFocus);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_trackFocus);
    _keys.dispose();
    super.dispose();
  }

  /// Remembers the node inside the group that last held primary focus.
  void _trackFocus() {
    final primary = FocusManager.instance.primaryFocus;
    if (primary != null && primary.ancestors.contains(_keys)) {
      _last = primary;
    }
  }

  bool get _rtl {
    final direction =
        widget.textDirection ??
        Directionality.maybeOf(context) ??
        TextDirection.ltr;
    return direction == TextDirection.rtl;
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isShiftPressed ||
        keyboard.isControlPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed ||
        primaryFocusInEditableText()) {
      return KeyEventResult.ignored;
    }
    final items = [
      for (final item in node.traversalDescendants)
        if (item.context != null) item,
    ];
    final current = _current(items);
    if (current == null) return KeyEventResult.ignored;
    final reading = _readingOrder(items, rtl: _rtl);
    final target = _target(event.logicalKey, current, items, reading);
    if (target == null) return KeyEventResult.ignored;
    if (target != current) {
      final forward = reading.indexOf(target) > reading.indexOf(current);
      target.requestFocus();
      Scrollable.ensureVisible(
        target.context!,
        alignmentPolicy: forward
            ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
            : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      );
    }
    return KeyEventResult.handled;
  }

  /// The item that holds primary focus or contains it.
  static FocusNode? _current(List<FocusNode> items) {
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null) return null;
    if (items.contains(primary)) return primary;
    for (final item in items) {
      if (item.hasFocus) return item;
    }
    return null;
  }

  /// The item [key] moves to, [current] when the key is handled without a
  /// move, or null when the group leaves [key] to Flutter.
  FocusNode? _target(
    LogicalKeyboardKey key,
    FocusNode current,
    List<FocusNode> items,
    List<FocusNode> reading,
  ) {
    if (key == LogicalKeyboardKey.home) return reading.first;
    if (key == LogicalKeyboardKey.end) return reading.last;
    final loop = widget.group.loop;
    switch (widget.axis) {
      case FocusGroupAxis.vertical:
        final step = _step(
          key,
          forward: LogicalKeyboardKey.arrowDown,
          back: LogicalKeyboardKey.arrowUp,
        );
        if (step == 0) return null;
        return _move(_onScreen(items, Axis.vertical), current, step, loop);
      case FocusGroupAxis.horizontal:
        final step = _step(
          key,
          forward: LogicalKeyboardKey.arrowRight,
          back: LogicalKeyboardKey.arrowLeft,
        );
        if (step == 0) return null;
        return _move(_onScreen(items, Axis.horizontal), current, step, loop);
      case FocusGroupAxis.wrap:
        final across = _step(
          key,
          forward: LogicalKeyboardKey.arrowRight,
          back: LogicalKeyboardKey.arrowLeft,
        );
        if (across != 0) {
          return _move(reading, current, _rtl ? -across : across, loop);
        }
        final down = _step(
          key,
          forward: LogicalKeyboardKey.arrowDown,
          back: LogicalKeyboardKey.arrowUp,
        );
        if (down == 0) return null;
        return _adjacentRun(items, current, down) ?? current;
    }
  }

  static int _step(
    LogicalKeyboardKey key, {
    required LogicalKeyboardKey forward,
    required LogicalKeyboardKey back,
  }) {
    if (key == forward) return 1;
    if (key == back) return -1;
    return 0;
  }

  /// The item [step] places after [current] in [order]; past either end it
  /// wraps with [loop] and otherwise stays on [current].
  static FocusNode _move(
    List<FocusNode> order,
    FocusNode current,
    int step,
    bool loop,
  ) {
    final next = order.indexOf(current) + step;
    if (next >= 0 && next < order.length) return order[next];
    if (!loop) return current;
    return order[next < 0 ? order.length - 1 : 0];
  }

  /// [items] by the center of their rect along [axis], left to right or
  /// top to bottom.
  static List<FocusNode> _onScreen(List<FocusNode> items, Axis axis) {
    double center(FocusNode node) =>
        axis == Axis.horizontal ? node.rect.center.dx : node.rect.center.dy;
    return [...items]..sort((a, b) => center(a).compareTo(center(b)));
  }

  /// [items] grouped into runs: items whose rects overlap vertically.
  static List<List<FocusNode>> _runs(List<FocusNode> items) {
    final sorted = [...items]..sort((a, b) => a.rect.top.compareTo(b.rect.top));
    final runs = <List<FocusNode>>[];
    var bottom = double.negativeInfinity;
    for (final item in sorted) {
      if (runs.isEmpty || item.rect.top >= bottom) {
        runs.add([item]);
        bottom = item.rect.bottom;
      } else {
        runs.last.add(item);
        if (item.rect.bottom > bottom) bottom = item.rect.bottom;
      }
    }
    return runs;
  }

  /// [items] in reading order: runs from top to bottom, each from left to
  /// right, or from right to left under [rtl].
  static List<FocusNode> _readingOrder(
    List<FocusNode> items, {
    required bool rtl,
  }) {
    final order = <FocusNode>[];
    for (final run in _runs(items)) {
      final row = _onScreen(run, Axis.horizontal);
      order.addAll(rtl ? row.reversed : row);
    }
    return order;
  }

  /// The item of the run below ([down] 1) or above ([down] -1) the run of
  /// [current] whose center is nearest to [current]'s, or null at the edge.
  static FocusNode? _adjacentRun(
    List<FocusNode> items,
    FocusNode current,
    int down,
  ) {
    final runs = _runs(items);
    final index = runs.indexWhere((run) => run.contains(current));
    final next = index + down;
    if (index < 0 || next < 0 || next >= runs.length) return null;
    final x = current.rect.center.dx;
    return runs[next].reduce(
      (a, b) =>
          (a.rect.center.dx - x).abs() <= (b.rect.center.dx - x).abs() ? a : b,
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget result = FocusTraversalGroup(
      policy: _policy,
      child: Focus(
        focusNode: _keys,
        includeSemantics: false,
        onKeyEvent: _handleKey,
        child: widget.child,
      ),
    );
    final role = widget.group.role;
    if (role != null) {
      result = Semantics(container: true, role: role, child: result);
    }
    return result;
  }
}

/// Sorts a group's members down to one: the member that holds the current
/// node, else the one that last held focus, else the first in reading
/// order. Tab then enters the group once and leaves it from any item.
class _FocusGroupPolicy extends ReadingOrderTraversalPolicy {
  new(this.lastFocused);

  /// The node inside the group that last held primary focus.
  final ValueGetter<FocusNode?> lastFocused;

  @override
  Iterable<FocusNode> sortDescendants(
    Iterable<FocusNode> descendants,
    FocusNode currentNode,
  ) {
    final members = descendants.toList();
    if (members.isEmpty) return members;
    FocusNode? holding(FocusNode? node) {
      if (node == null) return null;
      for (final member in members) {
        if (member == node || node.ancestors.contains(member)) return member;
      }
      return null;
    }

    final entry =
        holding(currentNode) ??
        holding(lastFocused()) ??
        super.sortDescendants(members, currentNode).first;
    return [entry];
  }
}
```

Runs are items whose rects overlap vertically, so one rule gives reading order for a row (one run), a column (one item per run), and a wrap. Along-axis arrows sort by the item centers on screen, so a row under right-to-left text and a column laid out upwards still move in the pressed direction. The group's semantics node carries `role` only when it is set (`semantics/semantics.dart:266-296` in the SDK holds the `tab` and `tabBar` checks, which throw at `:4092`).

Replace all of `lib/src/components/common/layout/layout.dart` with:

```dart
export 'box_layout.dart';
export 'column_layout.dart';
export 'container_layout.dart';
export 'custom_scroll_view_layout.dart';
export 'focus_group.dart' show StratumFocusGroup;
export 'grid_view_layout.dart';
export 'list_view_layout.dart';
export 'row_layout.dart';
export 'stack_layout.dart';
export 'wrap_layout.dart';
```

- [ ] **Step 4: Give column, row, and wrap a `focusGroup`**

Replace all of `lib/src/components/common/layout/column_layout.dart` with:

```dart
import 'package:stratum_ui/src/components/common/layout/focus_group.dart';
import 'package:stratum_ui/src/src.dart';

/// A [Column] on [BoxLayout]: style, interaction, semantics, and scrolling
/// come from the base class.
///
/// A height or max height in [style] forces [MainAxisSize.max], so the
/// column fills the height it is given. [gap] becomes [Column.spacing].
class ColumnLayout extends BoxLayout {
  const new({
    super.key,
    super.style,
    super.ratio,
    super.rotate,
    super.transform,
    super.transformAlignment,
    super.keepAlive,
    super.repaintBoundary,
    super.debug,
    super.semantics,
    super.onEndAnimate,
    super.interaction,
    super.scroll,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.max,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.textDirection,
    this.verticalDirection = VerticalDirection.down,
    this.textBaseline,
    this.crossAxisIntrinsic = false,
    this.gap,
    this.focusGroup,
    required this.children,
  });

  final MainAxisAlignment mainAxisAlignment;
  final MainAxisSize mainAxisSize;
  final CrossAxisAlignment crossAxisAlignment;
  final TextDirection? textDirection;
  final VerticalDirection verticalDirection;
  final TextBaseline? textBaseline;

  /// Sizes the column to its widest child through [IntrinsicWidth], unless
  /// [style] sets a width.
  final bool crossAxisIntrinsic;

  /// Space between children.
  final double? gap;

  /// Makes the focusable children one roving Tab stop with arrow, Home,
  /// and End keys; see [StratumFocusGroup]. Switching between null and a
  /// value remounts the children.
  final StratumFocusGroup? focusGroup;
  final List<Widget> children;

  MainAxisSize get _mainAxisSize {
    final style = this.style;
    final fills = style?.height != null || style?.maxHeight != null;
    return fills ? MainAxisSize.max : mainAxisSize;
  }

  @override
  Widget buildContent(BuildContext context) {
    final style = this.style;
    final Widget column = Column(
      mainAxisAlignment: mainAxisAlignment,
      mainAxisSize: _mainAxisSize,
      crossAxisAlignment: crossAxisAlignment,
      textDirection: textDirection,
      verticalDirection: verticalDirection,
      textBaseline: textBaseline,
      spacing: gap ?? 0,
      children: children,
    );
    final content = crossAxisIntrinsic && style?.width == null
        ? IntrinsicWidth(child: column)
        : column;
    final group = focusGroup;
    if (group == null) return content;
    return FocusGroupFrame(
      group: group,
      axis: FocusGroupAxis.vertical,
      textDirection: textDirection,
      child: content,
    );
  }
}
```

Replace all of `lib/src/components/common/layout/row_layout.dart` with:

```dart
import 'package:stratum_ui/src/components/common/layout/focus_group.dart';
import 'package:stratum_ui/src/src.dart';

/// A [Row] on [BoxLayout]: style, interaction, semantics, and scrolling
/// come from the base class.
///
/// A width or max width in [style] forces [MainAxisSize.max], so the row
/// fills the width it is given. [gap] becomes [Row.spacing], and `scroll`
/// scrolls horizontally unless its `direction` says otherwise.
class RowLayout extends BoxLayout {
  const new({
    super.key,
    super.style,
    super.ratio,
    super.rotate,
    super.transform,
    super.transformAlignment,
    super.keepAlive,
    super.repaintBoundary,
    super.debug,
    super.semantics,
    super.onEndAnimate,
    super.interaction,
    super.scroll,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.max,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.textDirection,
    this.verticalDirection = VerticalDirection.down,
    this.textBaseline,
    this.crossAxisIntrinsic = false,
    this.gap,
    this.focusGroup,
    required this.children,
  });

  final MainAxisAlignment mainAxisAlignment;
  final MainAxisSize mainAxisSize;
  final CrossAxisAlignment crossAxisAlignment;
  final TextDirection? textDirection;
  final VerticalDirection verticalDirection;
  final TextBaseline? textBaseline;

  /// Sizes the row to its tallest child through [IntrinsicHeight], unless
  /// [style] sets a height.
  final bool crossAxisIntrinsic;

  /// Space between children.
  final double? gap;

  /// Makes the focusable children one roving Tab stop with arrow, Home,
  /// and End keys; see [StratumFocusGroup]. Switching between null and a
  /// value remounts the children.
  final StratumFocusGroup? focusGroup;
  final List<Widget> children;

  @override
  Axis get scrollDirection => Axis.horizontal;

  MainAxisSize get _mainAxisSize {
    final style = this.style;
    final fills = style?.width != null || style?.maxWidth != null;
    return fills ? MainAxisSize.max : mainAxisSize;
  }

  @override
  Widget buildContent(BuildContext context) {
    final style = this.style;
    final Widget row = Row(
      mainAxisAlignment: mainAxisAlignment,
      mainAxisSize: _mainAxisSize,
      crossAxisAlignment: crossAxisAlignment,
      textDirection: textDirection,
      verticalDirection: verticalDirection,
      textBaseline: textBaseline,
      spacing: gap ?? 0,
      children: children,
    );
    final content = crossAxisIntrinsic && style?.height == null
        ? IntrinsicHeight(child: row)
        : row;
    final group = focusGroup;
    if (group == null) return content;
    return FocusGroupFrame(
      group: group,
      axis: FocusGroupAxis.horizontal,
      textDirection: textDirection,
      child: content,
    );
  }
}
```

Replace all of `lib/src/components/common/layout/wrap_layout.dart` with:

```dart
import 'package:stratum_ui/src/components/common/layout/focus_group.dart';
import 'package:stratum_ui/src/src.dart';

/// A [Wrap] on [BoxLayout]: style, interaction, semantics, and scrolling
/// come from the base class.
///
/// `scroll` scrolls across [direction], so a horizontal wrap keeps its
/// width, wraps into runs, and scrolls vertically.
class WrapLayout extends BoxLayout {
  const new({
    super.key,
    super.style,
    super.ratio,
    super.rotate,
    super.transform,
    super.transformAlignment,
    super.keepAlive,
    super.repaintBoundary,
    super.debug,
    super.semantics,
    super.onEndAnimate,
    super.interaction,
    super.scroll,
    this.direction = Axis.horizontal,
    this.alignment = WrapAlignment.start,
    this.gap,
    this.runGap,
    this.runAlignment = WrapAlignment.start,
    this.crossAxisAlignment = WrapCrossAlignment.start,
    this.textDirection,
    this.verticalDirection = VerticalDirection.down,
    this.clipBehavior = Clip.none,
    this.focusGroup,
    required this.children,
  });

  final Axis direction;

  /// Aligns children along [direction] inside each run;
  /// [WidgetStyle.alignment] places the whole wrap inside the box's padded
  /// content instead.
  final WrapAlignment alignment;

  /// Space between children in a run.
  final double? gap;

  /// Space between runs; null uses [gap].
  final double? runGap;
  final WrapAlignment runAlignment;
  final WrapCrossAlignment crossAxisAlignment;
  final TextDirection? textDirection;
  final VerticalDirection verticalDirection;

  /// Clips the wrap's children that overflow its bounds;
  /// [WidgetStyle.clipBehavior] cuts at the box edge instead.
  final Clip clipBehavior;

  /// Makes the focusable children one roving Tab stop with arrow, Home,
  /// and End keys; see [StratumFocusGroup]. Switching between null and a
  /// value remounts the children.
  final StratumFocusGroup? focusGroup;
  final List<Widget> children;

  @override
  Axis get scrollDirection => flipAxis(direction);

  @override
  Widget buildContent(BuildContext context) {
    final gap = this.gap ?? 0;
    final Widget wrap = Wrap(
      direction: direction,
      alignment: alignment,
      spacing: gap,
      runSpacing: runGap ?? gap,
      runAlignment: runAlignment,
      crossAxisAlignment: crossAxisAlignment,
      textDirection: textDirection,
      verticalDirection: verticalDirection,
      clipBehavior: clipBehavior,
      children: children,
    );
    final group = focusGroup;
    if (group == null) return wrap;
    return FocusGroupFrame(
      group: group,
      axis: FocusGroupAxis.wrap,
      textDirection: textDirection,
      child: wrap,
    );
  }
}
```

The frame wraps the content inside the box, so the group's semantics node sits inside the padding, around the items. Switching `focusGroup` between null and a value changes the content's root widget and remounts the children, as the dartdoc says.

- [ ] **Step 5: Run it to verify it passes**

Run: `flutter test --no-pub test/src/components/common/layout/focus_group_test.dart`
Expected: PASS, `+13: All tests passed!`

- [ ] **Step 6: Analyze and run the phase suite**

Run: `flutter analyze --no-pub lib/src/components/common/layout test/src/components/common/layout/focus_group_test.dart`
Expected: `No issues found!`

Run: `flutter test --no-pub test/src/components/common/ test/src/themes/ > build/p4-t6.log 2>&1; tail -n 1 build/p4-t6.log`
Expected: `+516: All tests passed!`

- [ ] **Step 7: Commit**

```bash
cd "<repo>"
git add -- lib/src/components/common/layout/focus_group.dart lib/src/components/common/layout/layout.dart lib/src/components/common/layout/column_layout.dart lib/src/components/common/layout/row_layout.dart lib/src/components/common/layout/wrap_layout.dart test/src/components/common/layout/focus_group_test.dart
git commit -m "feat(layout): add StratumFocusGroup, a roving Tab stop with arrow, Home, and End keys" -- lib/src/components/common/layout/focus_group.dart lib/src/components/common/layout/layout.dart lib/src/components/common/layout/column_layout.dart lib/src/components/common/layout/row_layout.dart lib/src/components/common/layout/wrap_layout.dart test/src/components/common/layout/focus_group_test.dart
```

---
### Task 7: K4, `ScrollFocus` for scroll views and box layouts

**Agent:** general-purpose
**Implements:** P4-8, D15 (keyboard scrolling without a focusable item, Home and End)

On desktop a list with no focusable item could not scroll by keyboard, and Home and End did nothing. `ScrollFocus` sits outside the box's clip, owns the viewport node, and scrolls through a controller: its node sits above the `Scrollable`, where `ScrollAction` cannot find one through `Scrollable.maybeOf` (`widgets/scrollable_helpers.dart:410-421`). The controller rule keeps the automatic primary controller on iOS and Android (`widgets/primary_scroll_controller.dart:24-28`, `:125-137`): `ScrollFocus` mirrors the scroll views' own rule, `primary ?? (controller == null && PrimaryScrollController.shouldInherit(context, axis))` (`widgets/scroll_view.dart:507-509`, `widgets/single_child_scroll_view.dart:253-255`), and creates an internal controller only when it would not inherit and `focusable` is true.

Two choices go past the spec's text. `FocusSpread` reads the theme (`focus_spread.dart:33,41`), so a scroll view without a `StratumThemeApplication`, which section 7 says must still work, takes focus and scrolls with no ring. Page Up and Page Down scroll along a horizontal axis too, where Flutter's `ScrollAction` returns 0 for a vertical intent on a horizontal scrollable (`widgets/scrollable_helpers.dart:452-458`).

**Files:**
- Modify: `lib/src/components/common/layout/scroll_frame.dart` (whole file: adds `defaultScrollFocusable` and `ScrollFocus`)
- Modify: `lib/src/components/common/layout/list_view_layout.dart`, `grid_view_layout.dart`, `custom_scroll_view_layout.dart` (whole files)
- Modify: `lib/src/components/common/layout/box_layout.dart` (`ScrollFocus` in `boxBuilder`, the linked controller)
- Modify: `test/src/components/common/layout/scroll_frame_test.dart` (whole file)

**Interfaces:**
- Consumes: Task 2's `StratumScroll`, `_BoxScrollView`, `_buildScroll`; Task 5's `primaryFocusInEditableText()`; `FocusSpread`; `kIsWeb` and `defaultTargetPlatform` (the latter follows `debugDefaultTargetPlatformOverride`, which `TargetPlatformVariant` sets).
- Produces: `bool defaultScrollFocusable({required bool isWeb, required TargetPlatform platform})`; `class ScrollFocus extends StatefulWidget` (`const new({Key? key, required bool focusable, required Axis axis, ScrollController? controller, bool? primary, String? semanticsLabel, BorderRadiusGeometry? borderRadius, bool ownsFocus = true, required Widget child})`) with `static ScrollController? controllerOf(BuildContext context)`; the viewport node's `debugLabel` is `'ScrollFocus'`; `focusable` (`bool?`) and `semanticsLabel` (`String?`) on `ListViewLayout.builder`, `GridViewLayout.builder`, and `CustomScrollViewLayout`. All in files no barrel exports, except the three scroll views.

- [ ] **Step 1: Write the failing test**

Replace all of `test/src/components/common/layout/scroll_frame_test.dart` with:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/layout/scroll_frame.dart';
import 'package:stratum_ui/src/src.dart';

import '../fakes/fake_stratum_theme.dart';

class _BouncingBehavior extends ScrollBehavior {
  const new();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics();
}

List<Type> _physicsChain(WidgetTester tester) {
  final state = tester.state<ScrollableState>(find.byType(Scrollable).first);
  final chain = <Type>[];
  for (
    ScrollPhysics? physics = state.position.physics;
    physics != null;
    physics = physics.parent
  ) {
    chain.add(physics.runtimeType);
  }
  return chain;
}

Widget _framed({bool? showScrollbar}) {
  return SizedBox(
    width: 200,
    height: 300,
    child: ScrollFrame(
      showScrollbar: showScrollbar,
      child: ListView(children: const [SizedBox(height: 2000)]),
    ),
  );
}

/// [MaterialScrollBehavior] reads the platform from [Theme], and the
/// fallback theme keeps the platform of the first test, so desktop cases
/// set it here.
Widget _macOSTheme(Widget child) {
  return Theme(
    data: ThemeData(platform: TargetPlatform.macOS),
    child: child,
  );
}

Widget _bouncingOutside(Widget child) {
  return ScrollConfiguration(behavior: const _BouncingBehavior(), child: child);
}

FocusNode _node() {
  final node = FocusNode();
  addTearDown(node.dispose);
  return node;
}

ScrollController _controller() {
  final controller = ScrollController();
  addTearDown(controller.dispose);
  return controller;
}

void _useTraditionalHighlight() {
  FocusManager.instance.highlightStrategy =
      FocusHighlightStrategy.alwaysTraditional;
  addTearDown(
    () => FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.automatic,
  );
}

/// [child], 200 by 300, after a focusable box, under the app's default
/// Tab, arrow, and activation keys.
Widget _keyboardHost(Widget child, {required FocusNode before}) {
  return Shortcuts(
    shortcuts: WidgetsApp.defaultShortcuts,
    child: Actions(
      actions: WidgetsApp.defaultActions,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Focus(
            focusNode: before,
            child: const SizedBox(width: 10, height: 10),
          ),
          SizedBox(width: 200, height: 300, child: child),
        ],
      ),
    ),
  );
}

Widget _item(BuildContext context, int index) {
  return SizedBox(key: ValueKey(index), height: 40);
}

/// Tabs from [before] to the next stop: the viewport of the scroll view.
Future<void> _tabIn(WidgetTester tester, FocusNode before) async {
  before.requestFocus();
  await tester.pump();
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.pump();
}

bool _viewportFocused() =>
    FocusManager.instance.primaryFocus?.debugLabel == 'ScrollFocus';

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

double _pixels(WidgetTester tester) => tester
    .state<ScrollableState>(find.byType(Scrollable).first)
    .position
    .pixels;

void main() {
  group('ScrollFrame', () {
    testWidgets('lets theme physics win over an outer ScrollConfiguration', (
      tester,
    ) async {
      await tester.pumpWidget(themedHost(_bouncingOutside(_framed())));

      final chain = _physicsChain(tester);
      expect(chain, contains(ClampingScrollPhysics));
      expect(chain, isNot(contains(BouncingScrollPhysics)));
    });

    testWidgets('uses the outer ScrollConfiguration without a theme', (
      tester,
    ) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(child: _bouncingOutside(_framed())),
        ),
      );

      expect(_physicsChain(tester), contains(BouncingScrollPhysics));
    });

    testWidgets('removes the scrollbar when showScrollbar is false', (
      tester,
    ) async {
      await tester.pumpWidget(
        themedHost(_macOSTheme(_framed(showScrollbar: false))),
      );

      expect(find.byType(Scrollbar), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('keeps the desktop scrollbar when showScrollbar is null', (
      tester,
    ) async {
      await tester.pumpWidget(themedHost(_macOSTheme(_framed())));

      expect(find.byType(Scrollbar), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  });

  group('ScrollFrame.boxStyle', () {
    test('moves the padding out of the box', () {
      final box = ScrollFrame.boxStyle(
        const WidgetStyle(
          padding: EdgeInsets.all(8),
          backgroundColor: Color(0xFF000000),
        ),
      );

      expect(box.padding, isNull);
      expect(box.backgroundColor, const Color(0xFF000000));
      expect(box.clipBehavior, isNull);
    });

    test('clips a rounded box with antiAlias', () {
      final box = ScrollFrame.boxStyle(
        const WidgetStyle(borderRadius: BorderRadius.all(Radius.circular(8))),
      );

      expect(box.clipBehavior, Clip.antiAlias);
    });

    test('keeps an explicit clipBehavior on a rounded box', () {
      final box = ScrollFrame.boxStyle(
        const WidgetStyle(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          clipBehavior: Clip.none,
        ),
      );

      expect(box.clipBehavior, Clip.none);
    });
  });

  group('defaultScrollFocusable', () {
    test('is true on web and desktop and false on mobile', () {
      expect(
        defaultScrollFocusable(isWeb: true, platform: TargetPlatform.android),
        isTrue,
      );
      for (final platform in [
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
      ]) {
        expect(
          defaultScrollFocusable(isWeb: false, platform: platform),
          isTrue,
        );
      }
      for (final platform in [
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.fuchsia,
      ]) {
        expect(
          defaultScrollFocusable(isWeb: false, platform: platform),
          isFalse,
        );
      }
    });
  });

  group('ScrollFocus', () {
    testWidgets(
      'the viewport takes focus, carries its label, and shows an unclipped '
      'ring',
      (tester) async {
        _useTraditionalHighlight();
        final handle = tester.ensureSemantics();
        final before = _node();
        await tester.pumpWidget(
          themedHost(
            _keyboardHost(
              const ListViewLayout.builder(
                style: WidgetStyle(
                  backgroundColor: Color(0xFFFFFFFF),
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                semanticsLabel: 'Results',
                itemCount: 50,
                itemBuilder: _item,
              ),
              before: before,
            ),
          ),
        );

        await _tabIn(tester, before);

        expect(_viewportFocused(), isTrue);
        expect(
          tester.widget<FocusSpread>(find.byType(FocusSpread)).focus,
          isTrue,
        );
        expect(
          find.ancestor(
            of: find.byType(FocusSpread),
            matching: find.byType(ClipRRect),
          ),
          findsNothing,
        );
        expect(
          tester.getSemantics(find.bySemanticsLabel('Results')),
          isSemantics(label: 'Results', isFocusable: true, isFocused: true),
        );
        handle.dispose();
      },
      variant: TargetPlatformVariant.desktop(),
    );

    testWidgets(
      'arrows, Page Down, Home, and End scroll the focused viewport',
      (tester) async {
        final before = _node();
        await tester.pumpWidget(
          themedHost(
            _keyboardHost(
              const ListViewLayout.builder(itemCount: 50, itemBuilder: _item),
              before: before,
            ),
          ),
        );
        await _tabIn(tester, before);

        await _key(tester, LogicalKeyboardKey.arrowDown);
        expect(_pixels(tester), 50);
        await _key(tester, LogicalKeyboardKey.pageDown);
        expect(_pixels(tester), 50 + 0.8 * 300);
        await _key(tester, LogicalKeyboardKey.arrowUp);
        expect(_pixels(tester), 0.8 * 300);
        await _key(tester, LogicalKeyboardKey.end);
        expect(_pixels(tester), 50 * 40 - 300);
        await _key(tester, LogicalKeyboardKey.home);
        expect(_pixels(tester), 0);
      },
      variant: TargetPlatformVariant.desktop(),
    );

    testWidgets('Home goes to the first item of a reversed list', (
      tester,
    ) async {
      final before = _node();
      await tester.pumpWidget(
        themedHost(
          _keyboardHost(
            const ListViewLayout.builder(
              reverse: true,
              itemCount: 50,
              itemBuilder: _item,
            ),
            before: before,
          ),
        ),
      );
      await _tabIn(tester, before);

      await _key(tester, LogicalKeyboardKey.end);
      expect(_pixels(tester), 50 * 40 - 300);
      await _key(tester, LogicalKeyboardKey.home);
      expect(_pixels(tester), 0);
      expect(find.byKey(const ValueKey(0)), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('End reaches the true end of a lazy list', (tester) async {
      final before = _node();
      await tester.pumpWidget(
        themedHost(
          _keyboardHost(
            ListViewLayout.builder(
              itemCount: 200,
              itemBuilder: (context, index) =>
                  SizedBox(key: ValueKey(index), height: index < 20 ? 20 : 200),
            ),
            before: before,
          ),
        ),
      );
      await _tabIn(tester, before);

      await _key(tester, LogicalKeyboardKey.end);

      final position = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position;
      expect(position.pixels, position.maxScrollExtent);
      expect(find.byKey(const ValueKey(199)), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('Page Down scrolls while a button item holds focus', (
      tester,
    ) async {
      final before = _node();
      final button = _node();
      await tester.pumpWidget(
        themedHost(
          _keyboardHost(
            ListViewLayout.builder(
              itemCount: 50,
              itemBuilder: (context, index) => index == 0
                  ? StratumInkWell(
                      onTap: () {},
                      focusNode: button,
                      child: const SizedBox(height: 40),
                    )
                  : _item(context, index),
            ),
            before: before,
          ),
        ),
      );
      button.requestFocus();
      await tester.pump();

      await _key(tester, LogicalKeyboardKey.pageDown);

      expect(_pixels(tester), 0.8 * 300);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets(
      'Home and End inside a TextField item leave the list where it is',
      (tester) async {
        final field = _node();
        await tester.pumpWidget(
          MaterialApp(
            home: Material(
              child: themedHost(
                SizedBox(
                  width: 200,
                  height: 300,
                  child: ListViewLayout.builder(
                    itemCount: 50,
                    itemBuilder: (context, index) => index == 0
                        ? TextField(focusNode: field)
                        : _item(context, index),
                  ),
                ),
              ),
            ),
          ),
        );
        field.requestFocus();
        await tester.pump();

        await _key(tester, LogicalKeyboardKey.end);
        await _key(tester, LogicalKeyboardKey.pageDown);

        expect(_pixels(tester), 0);
        expect(field.hasPrimaryFocus, isTrue);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

    testWidgets(
      'a list with primary: null on iOS scrolls the PrimaryScrollController',
      (tester) async {
        final before = _node();
        final primary = _controller();
        await tester.pumpWidget(
          themedHost(
            PrimaryScrollController(
              controller: primary,
              child: _keyboardHost(
                const ListViewLayout.builder(
                  focusable: true,
                  itemCount: 50,
                  itemBuilder: _item,
                ),
                before: before,
              ),
            ),
          ),
        );
        await _tabIn(tester, before);

        await _key(tester, LogicalKeyboardKey.end);

        expect(primary.hasClients, isTrue);
        expect(primary.position.pixels, 50 * 40 - 300);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets("a box layout's keys scroll through StratumScroll.controller", (
      tester,
    ) async {
      final before = _node();
      final controller = _controller();
      await tester.pumpWidget(
        themedHost(
          _keyboardHost(
            ColumnLayout(
              style: const WidgetStyle(backgroundColor: Color(0xFFFFFFFF)),
              scroll: StratumScroll(controller: controller),
              children: const [SizedBox(height: 2000)],
            ),
            before: before,
          ),
        ),
      );
      await _tabIn(tester, before);

      await _key(tester, LogicalKeyboardKey.arrowDown);

      expect(_viewportFocused(), isTrue);
      expect(controller.offset, 50);
    }, variant: TargetPlatformVariant.desktop());

    testWidgets(
      'Left and Right scroll a horizontal box layout; Down does not',
      (tester) async {
        final before = _node();
        await tester.pumpWidget(
          themedHost(
            _keyboardHost(
              const RowLayout(
                scroll: StratumScroll(),
                children: [SizedBox(width: 2000, height: 20)],
              ),
              before: before,
            ),
          ),
        );
        await _tabIn(tester, before);

        await _key(tester, LogicalKeyboardKey.arrowRight);
        expect(_pixels(tester), 50);
        await _key(tester, LogicalKeyboardKey.arrowDown);
        expect(_pixels(tester), 50);
        await _key(tester, LogicalKeyboardKey.arrowLeft);
        expect(_pixels(tester), 0);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

    testWidgets('a tappable scrolling box scrolls by keys on its tap surface', (
      tester,
    ) async {
      final before = _node();
      final surface = _node();
      await tester.pumpWidget(
        themedHost(
          _keyboardHost(
            ColumnLayout(
              style: const WidgetStyle(),
              interaction: StratumInteraction(onTap: () {}, focusNode: surface),
              scroll: const StratumScroll(),
              children: const [SizedBox(height: 2000)],
            ),
            before: before,
          ),
        ),
      );
      await _tabIn(tester, before);

      await _key(tester, LogicalKeyboardKey.arrowDown);

      expect(surface.hasPrimaryFocus, isTrue);
      expect(_pixels(tester), 50);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Focus && widget.focusNode?.debugLabel == 'ScrollFocus',
        ),
        findsNothing,
      );
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets(
      'a desktop list without a theme takes focus and builds no ring',
      (tester) async {
        final before = _node();
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: _keyboardHost(
                const ListViewLayout.builder(itemCount: 50, itemBuilder: _item),
                before: before,
              ),
            ),
          ),
        );
        await _tabIn(tester, before);

        await _key(tester, LogicalKeyboardKey.arrowDown);

        expect(tester.takeException(), isNull);
        expect(_viewportFocused(), isTrue);
        expect(find.byType(FocusSpread), findsNothing);
        expect(_pixels(tester), 50);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.linux),
    );

    testWidgets(
      '(pin) a mobile list is no Tab stop and keeps its own controller',
      (tester) async {
        await tester.pumpWidget(
          themedHost(
            const SizedBox(
              width: 200,
              height: 300,
              child: ListViewLayout.builder(itemCount: 50, itemBuilder: _item),
            ),
          ),
        );

        expect(find.byType(FocusSpread), findsNothing);
        expect(
          tester.widget<ListView>(find.byType(ListView)).controller,
          isNull,
        );
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  });
}
```

The first seven cases are the phase 1 ones, unchanged. `_keyboardHost` adds the app's default shortcuts and actions and a focusable box before the scroll view, so `_tabIn` reaches the viewport with a real Tab. Viewports are 300 px tall and items 40 px, so a page is 240 px and the end of 50 items is at 1700 px. The lazy-list case has 20 items of 20 px and 180 of 200 px: the first estimate of the extent is far too short, and a single jump stops short of item 199.

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test --no-pub test/src/components/common/layout/scroll_frame_test.dart`
Expected: FAIL at compile time, with errors that include `Error: Method not found: 'defaultScrollFocusable'.`

- [ ] **Step 3: Write `ScrollFocus`**

Replace all of `lib/src/components/common/layout/scroll_frame.dart` with:

```dart
import 'package:stratum_ui/src/components/common/text_entry_guard.dart';
import 'package:stratum_ui/src/src.dart';

/// The scroll behavior for a layout scroll view at [context].
///
/// Starts from the theme's `scrollBehavior` with the theme's `physics` when
/// a [StratumThemeApplication] is above [context]. Without a theme it
/// starts from the [ScrollConfiguration] above the outermost [ScrollFrame],
/// so an outer frame's choices never reach an inner one. A null
/// [scrollbars] keeps the behavior's own choice, which shows a scrollbar on
/// desktop. A scroll view's own `physics` parameter applies on top of the
/// result.
ScrollBehavior resolveScrollBehavior(
  BuildContext context, {
  bool? scrollbars,
}) {
  final theme = StratumThemeApplication.maybeOf(context);
  final behavior =
      theme?.scrollBehavior ??
      _ScrollFrameScope.maybeBaseOf(context) ??
      ScrollConfiguration.of(context);
  return behavior.copyWith(physics: theme?.physics, scrollbars: scrollbars);
}

/// Applies [resolveScrollBehavior] to the scroll view in [child].
///
/// The behavior also reaches Flutter scroll views inside the items. Layout
/// scroll views among them resolve their own behavior, from the theme or
/// from the configuration above the outermost frame.
class ScrollFrame extends StatelessWidget {
  const new({super.key, this.showScrollbar, required this.child});

  /// Null keeps the behavior's choice: a scrollbar on desktop.
  final bool? showScrollbar;
  final Widget child;

  /// The style of the box around a viewport.
  ///
  /// The padding moves into the scroll view so it scrolls with the
  /// content, and a rounded box clips the viewport to its corners unless
  /// the style sets its own `clipBehavior`.
  static WidgetStyle boxStyle(WidgetStyle style) {
    return style.copyWith(
      padding: null,
      clipBehavior:
          style.clipBehavior ??
          (style.borderRadius == null ? null : Clip.antiAlias),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _ScrollFrameScope(
      base:
          _ScrollFrameScope.maybeBaseOf(context) ??
          ScrollConfiguration.of(context),
      child: ScrollConfiguration(
        behavior: resolveScrollBehavior(context, scrollbars: showScrollbar),
        child: child,
      ),
    );
  }
}

/// Carries the [ScrollConfiguration] that was above the outermost
/// [ScrollFrame] down to the frames nested inside it.
class _ScrollFrameScope extends InheritedWidget {
  const new({required this.base, required super.child});

  final ScrollBehavior base;

  static ScrollBehavior? maybeBaseOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_ScrollFrameScope>()
        ?.base;
  }

  @override
  bool updateShouldNotify(_ScrollFrameScope oldWidget) =>
      base != oldWidget.base;
}

/// Whether a scroll view takes keyboard focus when its `focusable` is null:
/// on web, mobile web included, and on desktop. Every scroller is then a
/// Tab stop, as in Firefox.
bool defaultScrollFocusable({
  required bool isWeb,
  required TargetPlatform platform,
}) {
  return isWeb ||
      const {
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
      }.contains(platform);
}

/// Keyboard scrolling for one scroll view (K4): the focus node, the keys,
/// and the focus ring.
///
/// Sits outside the box's clip, so the ring, which paints outside the box,
/// stays visible: around the box of a scroll view, and in `boxBuilder` for
/// a box layout with `scroll`. With [ownsFocus] false it wraps a tap
/// surface, creates no node, and acts on keys that bubble up from the
/// surface's node.
///
/// While the viewport node holds focus, the arrows along [axis] scroll
/// 50 px, Page Up and Page Down scroll 0.8 of the viewport, and Home and
/// End jump to the first and last item. While an item inside holds focus,
/// the arrows keep Flutter's default, and Page Up, Page Down, Home, and
/// End still scroll. No key acts while focus is inside a text field.
///
/// The scroll view reads its controller through [controllerOf]: the
/// caller's [controller]; else none when it inherits the
/// [PrimaryScrollController], which the keys then use; else, when
/// [focusable], an internal one.
class ScrollFocus extends StatefulWidget {
  const new({
    super.key,
    required this.focusable,
    required this.axis,
    this.controller,
    this.primary,
    this.semanticsLabel,
    this.borderRadius,
    this.ownsFocus = true,
    required this.child,
  });

  /// Whether the viewport takes focus and handles keys; false passes
  /// [child] through.
  final bool focusable;

  /// The scroll axis the arrows act along.
  final Axis axis;
  final ScrollController? controller;
  final bool? primary;

  /// Names the viewport node that a screen reader announces on focus.
  final String? semanticsLabel;

  /// Shape of the focus ring.
  final BorderRadiusGeometry? borderRadius;

  /// Whether this widget owns the viewport node; false when it wraps a tap
  /// surface whose node takes focus instead.
  final bool ownsFocus;
  final Widget child;

  /// The controller that the scroll view below the nearest [ScrollFocus]
  /// passes on; null lets it inherit the [PrimaryScrollController] or make
  /// its own.
  static ScrollController? controllerOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_ScrollFocusScope>()
        ?.controller;
  }

  @override
  State<ScrollFocus> createState() => _ScrollFocusState();
}

class _ScrollFocusState extends State<ScrollFocus> {
  // Created on first use and kept until dispose, as StratumInkWell keeps
  // its node.
  FocusNode? _node;
  ScrollController? _internalController;

  FocusNode get _focusNode =>
      _node ??= FocusNode(debugLabel: 'ScrollFocus')
        ..addListener(_handleFocusChange);

  /// Whether the scroll view attaches to the [PrimaryScrollController], by
  /// the rule of `ScrollView` and `SingleChildScrollView`.
  bool get _inheritsPrimary =>
      widget.primary ??
      (widget.controller == null &&
          PrimaryScrollController.shouldInherit(context, widget.axis));

  /// The controller handed to the scroll view.
  ScrollController? get _viewController {
    final controller = widget.controller;
    if (controller != null) return controller;
    if (!widget.focusable || _inheritsPrimary) return null;
    return _internalController ??= ScrollController();
  }

  /// The controller the keys scroll through.
  ScrollController? get _keyController {
    final view = _viewController;
    if (view != null) return view;
    return _inheritsPrimary ? PrimaryScrollController.maybeOf(context) : null;
  }

  bool get _ringVisible =>
      _focusNode.hasPrimaryFocus &&
      FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(_handleHighlightMode);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_handleHighlightMode);
    _node?.dispose();
    _internalController?.dispose();
    super.dispose();
  }

  void _handleFocusChange() => setState(() {});

  void _handleHighlightMode(FocusHighlightMode mode) {
    if (_node?.hasPrimaryFocus ?? false) setState(() {});
  }

  /// Whether the viewport itself holds focus: the own node, or the tap
  /// surface's node, which no focusable node separates from [handler].
  bool _viewportFocused(FocusNode handler) {
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null) return false;
    if (primary == handler) return true;
    if (widget.ownsFocus) return false;
    for (final ancestor in primary.ancestors) {
      if (ancestor == handler) return true;
      if (ancestor.canRequestFocus && !ancestor.skipTraversal) return false;
    }
    return false;
  }

  KeyEventResult _handleKey(FocusNode handler, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isShiftPressed ||
        keyboard.isControlPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed ||
        primaryFocusInEditableText()) {
      return KeyEventResult.ignored;
    }
    final controller = _keyController;
    if (controller == null || controller.positions.length != 1) {
      return KeyEventResult.ignored;
    }
    final position = controller.position;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.home) {
      position.jumpTo(position.minScrollExtent);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end) {
      _jumpToEnd(controller, position, 3);
      return KeyEventResult.handled;
    }
    final vertical = position.axis == Axis.vertical;
    final page =
        key == LogicalKeyboardKey.pageUp || key == LogicalKeyboardKey.pageDown;
    final AxisDirection? direction;
    if (key == LogicalKeyboardKey.pageUp) {
      direction = vertical ? AxisDirection.up : AxisDirection.left;
    } else if (key == LogicalKeyboardKey.pageDown) {
      direction = vertical ? AxisDirection.down : AxisDirection.right;
    } else if (!_viewportFocused(handler)) {
      direction = null;
    } else {
      direction = switch (key) {
        LogicalKeyboardKey.arrowUp => AxisDirection.up,
        LogicalKeyboardKey.arrowDown => AxisDirection.down,
        LogicalKeyboardKey.arrowLeft => AxisDirection.left,
        LogicalKeyboardKey.arrowRight => AxisDirection.right,
        _ => null,
      };
    }
    if (direction == null || axisDirectionToAxis(direction) != position.axis) {
      return KeyEventResult.ignored;
    }
    // The amounts of Flutter's ScrollAction: a line is 50 px and a page is
    // 0.8 of the viewport.
    final amount = page ? 0.8 * position.viewportDimension : 50.0;
    final delta = direction == position.axisDirection ? amount : -amount;
    position.moveTo(
      position.pixels + delta,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeInOut,
    );
    return KeyEventResult.handled;
  }

  /// Jumps to the end. A lazy list only estimates its extent, so it jumps
  /// again after each frame until the extent stops changing, at most
  /// [retries] more times.
  void _jumpToEnd(
    ScrollController controller,
    ScrollPosition position,
    int retries,
  ) {
    final extent = position.maxScrollExtent;
    position.jumpTo(extent);
    if (retries == 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !controller.positions.contains(position)) return;
      if (position.maxScrollExtent != extent) {
        _jumpToEnd(controller, position, retries - 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget result = _ScrollFocusScope(
      controller: _viewController,
      child: widget.child,
    );
    if (!widget.focusable) return result;
    if (!widget.ownsFocus) {
      return Focus(
        canRequestFocus: false,
        skipTraversal: true,
        includeSemantics: false,
        onKeyEvent: _handleKey,
        child: result,
      );
    }
    result = Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKey,
      child: result,
    );
    // FocusSpread reads the theme; without one the viewport has no ring.
    if (StratumThemeApplication.maybeOf(context) != null) {
      result = FocusSpread(
        focus: _ringVisible,
        borderRadius: widget.borderRadius,
        child: result,
      );
    }
    return Semantics(
      container: true,
      label: widget.semanticsLabel,
      child: result,
    );
  }
}

/// Hands [ScrollFocus]'s controller to the scroll view below it.
class _ScrollFocusScope extends InheritedWidget {
  const new({required this.controller, required super.child});

  final ScrollController? controller;

  @override
  bool updateShouldNotify(_ScrollFocusScope oldWidget) =>
      controller != oldWidget.controller;
}
```

Home and End use `jumpTo`, so no motion plays. End jumps again after each frame while `maxScrollExtent` keeps changing, at most three more times, because a lazy list only estimates its extent. The arrow and page amounts are `ScrollAction`'s (`widgets/scrollable_helpers.dart:444-447`), with its 100 ms `easeInOut` move (`:512-516`). In tap-surface mode (`ownsFocus: false`) the handler acts as the viewport whenever no focusable node separates the primary node from it, which is true for the surface's own node and false for an item inside.

- [ ] **Step 4: Wrap the scroll views**

Replace all of `lib/src/components/common/layout/list_view_layout.dart` with:

```dart
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:stratum_ui/src/components/common/layout/scroll_frame.dart';
import 'package:stratum_ui/src/src.dart';

/// A lazy list that scrolls inside a [WidgetStyle] box.
///
/// The box (fill, border, radius, and shadow) stays in place while the
/// items scroll. `style.padding` becomes the list padding, so it scrolls
/// with the items. Scroll behavior and physics come from
/// [resolveScrollBehavior]; [physics] applies on top of them. A [focusable]
/// list is a Tab stop that scrolls by keyboard; see [ScrollFocus].
class ListViewLayout extends StatelessWidget {
  const new builder({
    super.key,
    this.style,
    this.gap,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.controller,
    this.primary,
    this.physics,
    this.showScrollbar,
    this.shrinkWrap = false,
    this.itemExtent,
    this.prototypeItem,
    required this.itemCount,
    required this.itemBuilder,
    this.findChildIndexCallback,
    this.addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
    this.addSemanticIndexes = true,
    this.scrollCacheExtent,
    this.semanticChildCount,
    this.dragStartBehavior = DragStartBehavior.start,
    this.keyboardDismissBehavior,
    this.restorationId,
    this.clipBehavior = Clip.hardEdge,
    this.focusable,
    this.semanticsLabel,
  }) : assert(
         gap == null ||
             (itemCount != null &&
                 itemExtent == null &&
                 prototypeItem == null &&
                 semanticChildCount == null),
         'gap needs an itemCount and takes no itemExtent, prototypeItem, '
         'or semanticChildCount',
       );

  final WidgetStyle? style;

  /// Space between items along [scrollDirection].
  final double? gap;
  final Axis scrollDirection;
  final bool reverse;
  final ScrollController? controller;
  final bool? primary;
  final ScrollPhysics? physics;

  /// Null keeps the scroll behavior's choice: a scrollbar on desktop.
  final bool? showScrollbar;
  final bool shrinkWrap;
  final double? itemExtent;
  final Widget? prototypeItem;
  final int? itemCount;
  final NullableIndexedWidgetBuilder itemBuilder;

  /// Returns item indices, without separators, also when [gap] is set.
  final ChildIndexGetter? findChildIndexCallback;
  final bool addAutomaticKeepAlives;
  final bool addRepaintBoundaries;
  final bool addSemanticIndexes;
  final ScrollCacheExtent? scrollCacheExtent;
  final int? semanticChildCount;
  final DragStartBehavior dragStartBehavior;
  final ScrollViewKeyboardDismissBehavior? keyboardDismissBehavior;
  final String? restorationId;
  final Clip clipBehavior;

  /// Whether the list is a Tab stop that scrolls by keyboard; null means
  /// on web and desktop ([defaultScrollFocusable]).
  final bool? focusable;

  /// Names the focusable list for a screen reader.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final style = this.style;
    Widget list = ScrollFrame(
      showScrollbar: showScrollbar,
      child: Builder(
        builder: (context) =>
            _buildList(ScrollFocus.controllerOf(context), style?.padding),
      ),
    );
    if (style != null) {
      list = ContainerLayout(style: ScrollFrame.boxStyle(style), child: list);
    }
    return ScrollFocus(
      focusable:
          focusable ??
          defaultScrollFocusable(
            isWeb: kIsWeb,
            platform: defaultTargetPlatform,
          ),
      axis: scrollDirection,
      controller: controller,
      primary: primary,
      semanticsLabel: semanticsLabel,
      borderRadius: style?.borderRadius,
      child: list,
    );
  }

  Widget _buildList(ScrollController? controller, EdgeInsetsGeometry? padding) {
    final gap = this.gap;
    if (gap != null) {
      return ListView.separated(
        scrollDirection: scrollDirection,
        reverse: reverse,
        controller: controller,
        primary: primary,
        physics: physics,
        shrinkWrap: shrinkWrap,
        padding: padding,
        itemBuilder: itemBuilder,
        findItemIndexCallback: findChildIndexCallback,
        separatorBuilder: (context, index) => scrollDirection == Axis.vertical
            ? SizedBox(height: gap)
            : SizedBox(width: gap),
        itemCount: itemCount!,
        addAutomaticKeepAlives: addAutomaticKeepAlives,
        addRepaintBoundaries: addRepaintBoundaries,
        addSemanticIndexes: addSemanticIndexes,
        scrollCacheExtent: scrollCacheExtent,
        dragStartBehavior: dragStartBehavior,
        keyboardDismissBehavior: keyboardDismissBehavior,
        restorationId: restorationId,
        clipBehavior: clipBehavior,
      );
    }
    return ListView.builder(
      scrollDirection: scrollDirection,
      reverse: reverse,
      controller: controller,
      primary: primary,
      physics: physics,
      shrinkWrap: shrinkWrap,
      padding: padding,
      itemExtent: itemExtent,
      prototypeItem: prototypeItem,
      itemBuilder: itemBuilder,
      findChildIndexCallback: findChildIndexCallback,
      itemCount: itemCount,
      addAutomaticKeepAlives: addAutomaticKeepAlives,
      addRepaintBoundaries: addRepaintBoundaries,
      addSemanticIndexes: addSemanticIndexes,
      scrollCacheExtent: scrollCacheExtent,
      semanticChildCount: semanticChildCount,
      dragStartBehavior: dragStartBehavior,
      keyboardDismissBehavior: keyboardDismissBehavior,
      restorationId: restorationId,
      clipBehavior: clipBehavior,
    );
  }
}
```

Replace all of `lib/src/components/common/layout/grid_view_layout.dart` with:

```dart
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:stratum_ui/src/components/common/layout/scroll_frame.dart';
import 'package:stratum_ui/src/src.dart';

/// A lazy grid that scrolls inside a [WidgetStyle] box.
///
/// The box (fill, border, radius, and shadow) stays in place while the
/// items scroll. `style.padding` becomes the grid padding, so it scrolls
/// with the items. Scroll behavior and physics come from
/// [resolveScrollBehavior]; [physics] applies on top of them. A [focusable]
/// grid is a Tab stop that scrolls by keyboard; see [ScrollFocus].
class GridViewLayout extends StatelessWidget {
  const new builder({
    super.key,
    this.style,
    required this.gridDelegate,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.controller,
    this.primary,
    this.physics,
    this.showScrollbar,
    this.shrinkWrap = false,
    required this.itemCount,
    required this.itemBuilder,
    this.findChildIndexCallback,
    this.addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
    this.addSemanticIndexes = true,
    this.scrollCacheExtent,
    this.semanticChildCount,
    this.dragStartBehavior = DragStartBehavior.start,
    this.keyboardDismissBehavior,
    this.restorationId,
    this.clipBehavior = Clip.hardEdge,
    this.focusable,
    this.semanticsLabel,
  });

  final WidgetStyle? style;
  final SliverGridDelegate gridDelegate;
  final Axis scrollDirection;
  final bool reverse;
  final ScrollController? controller;
  final bool? primary;
  final ScrollPhysics? physics;

  /// Null keeps the scroll behavior's choice: a scrollbar on desktop.
  final bool? showScrollbar;
  final bool shrinkWrap;
  final int? itemCount;
  final NullableIndexedWidgetBuilder itemBuilder;
  final ChildIndexGetter? findChildIndexCallback;
  final bool addAutomaticKeepAlives;
  final bool addRepaintBoundaries;
  final bool addSemanticIndexes;
  final ScrollCacheExtent? scrollCacheExtent;
  final int? semanticChildCount;
  final DragStartBehavior dragStartBehavior;
  final ScrollViewKeyboardDismissBehavior? keyboardDismissBehavior;
  final String? restorationId;
  final Clip clipBehavior;

  /// Whether the grid is a Tab stop that scrolls by keyboard; null means
  /// on web and desktop ([defaultScrollFocusable]).
  final bool? focusable;

  /// Names the focusable grid for a screen reader.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final style = this.style;
    Widget grid = ScrollFrame(
      showScrollbar: showScrollbar,
      child: Builder(
        builder: (context) => GridView.builder(
          gridDelegate: gridDelegate,
          scrollDirection: scrollDirection,
          reverse: reverse,
          controller: ScrollFocus.controllerOf(context),
          primary: primary,
          physics: physics,
          shrinkWrap: shrinkWrap,
          padding: style?.padding,
          itemBuilder: itemBuilder,
          findChildIndexCallback: findChildIndexCallback,
          itemCount: itemCount,
          addAutomaticKeepAlives: addAutomaticKeepAlives,
          addRepaintBoundaries: addRepaintBoundaries,
          addSemanticIndexes: addSemanticIndexes,
          scrollCacheExtent: scrollCacheExtent,
          semanticChildCount: semanticChildCount,
          dragStartBehavior: dragStartBehavior,
          keyboardDismissBehavior: keyboardDismissBehavior,
          restorationId: restorationId,
          clipBehavior: clipBehavior,
        ),
      ),
    );
    if (style != null) {
      grid = ContainerLayout(style: ScrollFrame.boxStyle(style), child: grid);
    }
    return ScrollFocus(
      focusable:
          focusable ??
          defaultScrollFocusable(
            isWeb: kIsWeb,
            platform: defaultTargetPlatform,
          ),
      axis: scrollDirection,
      controller: controller,
      primary: primary,
      semanticsLabel: semanticsLabel,
      borderRadius: style?.borderRadius,
      child: grid,
    );
  }
}
```

Replace all of `lib/src/components/common/layout/custom_scroll_view_layout.dart` with:

```dart
import 'package:stratum_ui/src/components/common/layout/scroll_frame.dart';
import 'package:stratum_ui/src/src.dart';

/// A [CustomScrollView] that scrolls inside a [WidgetStyle] box.
///
/// Takes either [slivers] or [children]; [children] go into one lazy
/// [SliverList]. The box (fill, border, radius, and shadow) stays in place
/// while the content scrolls. In children mode `style.padding` becomes a
/// [SliverPadding], so it scrolls with the content; with [slivers], wrap
/// them in a [SliverPadding] yourself, because grouping several slivers
/// changes how pinned headers behave. A [focusable] view is a Tab stop
/// that scrolls by keyboard; see [ScrollFocus].
class CustomScrollViewLayout extends StatelessWidget {
  const new({
    super.key,
    this.style,
    this.slivers,
    this.children,
    this.controller,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.shrinkWrap = false,
    this.physics,
    this.showScrollbar,
    this.focusable,
    this.semanticsLabel,
  }) : assert(
         (slivers == null) != (children == null),
         'Pass exactly one of slivers and children',
       );

  final WidgetStyle? style;
  final List<Widget>? slivers;
  final List<Widget>? children;
  final ScrollController? controller;
  final Axis scrollDirection;
  final bool reverse;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  /// Null keeps the scroll behavior's choice: a scrollbar on desktop.
  final bool? showScrollbar;

  /// Whether the view is a Tab stop that scrolls by keyboard; null means
  /// on web and desktop ([defaultScrollFocusable]).
  final bool? focusable;

  /// Names the focusable view for a screen reader.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final style = this.style;
    final slivers = this.slivers;
    assert(
      slivers == null || style?.padding == null,
      'style.padding applies to children only; wrap slivers in a '
      'SliverPadding instead',
    );
    Widget view = ScrollFrame(
      showScrollbar: showScrollbar,
      child: Builder(
        builder: (context) => CustomScrollView(
          controller: ScrollFocus.controllerOf(context),
          scrollDirection: scrollDirection,
          reverse: reverse,
          shrinkWrap: shrinkWrap,
          physics: physics,
          semanticChildCount: slivers == null ? children!.length : null,
          slivers: slivers ?? [_buildChildrenSliver(style?.padding)],
        ),
      ),
    );
    if (style != null) {
      view = ContainerLayout(style: ScrollFrame.boxStyle(style), child: view);
    }
    return ScrollFocus(
      focusable:
          focusable ??
          defaultScrollFocusable(
            isWeb: kIsWeb,
            platform: defaultTargetPlatform,
          ),
      axis: scrollDirection,
      controller: controller,
      semanticsLabel: semanticsLabel,
      borderRadius: style?.borderRadius,
      child: view,
    );
  }

  Widget _buildChildrenSliver(EdgeInsetsGeometry? padding) {
    final sliver = SliverList.list(children: children!);
    if (padding == null) return sliver;
    return SliverPadding(padding: padding, sliver: sliver);
  }
}
```

`ScrollFocus` goes around the box, or around `ScrollFrame` when `style` is null (spec section 5, "Scroll views after each phase"). The scroll view reads its controller through a `Builder` below `ScrollFocus`, so a nested layout scroll view reads its own `ScrollFocus`, never an outer one.

- [ ] **Step 5: Put `ScrollFocus` in a scrolling box layout's `boxBuilder`**

In `lib/src/components/common/layout/box_layout.dart`, replace:

```dart
    final scroll = this.scroll;
    Widget current = AnimatedStyledBox(
      style: style,
      ratio: aspect != null && aspect > 0 ? aspect : null,
      transform: transform,
      transformAlignment: transformAlignment,
      onEnd: duration > Duration.zero ? onEndAnimate : null,
      boxBuilder: _boxBuilder,
      scrollBuilder: scroll == null
          ? null
          : (content) => _buildScroll(scroll, content),
```

with:

```dart
    final scroll = this.scroll;
    // Box layouts take no focusable parameter: a scrolling box is a Tab
    // stop on web and desktop.
    final focusable =
        scroll != null &&
        defaultScrollFocusable(isWeb: kIsWeb, platform: defaultTargetPlatform);
    Widget current = AnimatedStyledBox(
      style: style,
      ratio: aspect != null && aspect > 0 ? aspect : null,
      transform: transform,
      transformAlignment: transformAlignment,
      onEnd: duration > Duration.zero ? onEndAnimate : null,
      boxBuilder: focusable ? _focusBuilder(scroll) : _boxBuilder,
      scrollBuilder: scroll == null
          ? null
          : (content) => _buildScroll(scroll, content, linked: focusable),
```

Replace:

```dart
  static bool _needsTapSurface(StratumInteraction interaction) =>
```

with:

```dart
  /// [_boxBuilder] inside a [ScrollFocus], which sits outside the clip so
  /// its ring stays visible. With a tap surface, the surface's node takes
  /// focus and [ScrollFocus] creates none.
  StyledBoxBuilder _focusBuilder(StratumScroll scroll) {
    final inner = _boxBuilder;
    final interaction = this.interaction;
    final hasSurface = interaction != null && _needsTapSurface(interaction);
    return (style, box) => ScrollFocus(
      focusable: true,
      axis: scroll.direction ?? scrollDirection,
      controller: scroll.controller,
      primary: scroll.primary,
      borderRadius: style.borderRadius,
      ownsFocus: !hasSurface,
      child: inner == null ? box : inner(style, box),
    );
  }

  static bool _needsTapSurface(StratumInteraction interaction) =>
```

Replace:

```dart
  /// box, as [scroll] says.
  Widget _buildScroll(StratumScroll scroll, Widget content) {
    return ScrollFrame(
      showScrollbar: scroll.showScrollbar,
      child: _BoxScrollView(
        scroll: scroll,
        axis: scroll.direction ?? scrollDirection,
        child: content,
      ),
    );
```

with:

```dart
  /// box, as [scroll] says. A [linked] scroll view takes its controller
  /// from the [ScrollFocus] that [_focusBuilder] builds.
  Widget _buildScroll(
    StratumScroll scroll,
    Widget content, {
    required bool linked,
  }) {
    return ScrollFrame(
      showScrollbar: scroll.showScrollbar,
      child: _BoxScrollView(
        scroll: scroll,
        axis: scroll.direction ?? scrollDirection,
        linked: linked,
        child: content,
      ),
    );
```

Replace:

```dart
  const new({required this.scroll, required this.axis, required this.child});

  final StratumScroll scroll;
  final Axis axis;
  final Widget child;

  Widget _view(Widget content) {
    return SingleChildScrollView(
      scrollDirection: axis,
      reverse: scroll.reverse,
      controller: scroll.controller,
```

with:

```dart
  const new({
    required this.scroll,
    required this.axis,
    required this.linked,
    required this.child,
  });

  final StratumScroll scroll;
  final Axis axis;

  /// Whether a [ScrollFocus] above hands over the controller.
  final bool linked;
  final Widget child;

  Widget _view(BuildContext context, Widget content) {
    return SingleChildScrollView(
      scrollDirection: axis,
      reverse: scroll.reverse,
      controller: linked
          ? ScrollFocus.controllerOf(context)
          : scroll.controller,
```

Replace:

```dart
    if (!scroll.fillViewport) return _view(child);
```

with:

```dart
    if (!scroll.fillViewport) return _view(context, child);
```

Replace:

```dart
        return _view(
          ConstrainedBox(
```

with:

```dart
        return _view(
          context,
          ConstrainedBox(
```

A box layout reads its controller from the scope only when `ScrollFocus` is there (`linked`); on mobile no `ScrollFocus` exists, and an inherited lookup would find an outer list's scope instead.

- [ ] **Step 6: Run it to verify it passes**

Run: `flutter test --no-pub test/src/components/common/layout/scroll_frame_test.dart`
Expected: PASS, `+26: All tests passed!`

The desktop cases run once per desktop platform (`TargetPlatformVariant.desktop()`).

- [ ] **Step 7: Analyze and run the phase suite**

Run: `flutter analyze --no-pub lib/src/components/common/layout test/src/components/common/layout/scroll_frame_test.dart`
Expected: `No issues found!`

Run: `flutter test --no-pub test/src/components/common/ test/src/themes/ > build/p4-t7.log 2>&1; tail -n 1 build/p4-t7.log`
Expected: `+535: All tests passed!` The phase 1 macOS cases of `list_view_layout_test.dart` now build a focusable `ScrollFocus`, the theme-less one without a ring.

- [ ] **Step 8: Commit**

```bash
cd "<repo>"
git add -- lib/src/components/common/layout/scroll_frame.dart lib/src/components/common/layout/list_view_layout.dart lib/src/components/common/layout/grid_view_layout.dart lib/src/components/common/layout/custom_scroll_view_layout.dart lib/src/components/common/layout/box_layout.dart test/src/components/common/layout/scroll_frame_test.dart
git commit -m "feat(layout): make scroll views and scrolling boxes focusable with keyboard scrolling" -- lib/src/components/common/layout/scroll_frame.dart lib/src/components/common/layout/list_view_layout.dart lib/src/components/common/layout/grid_view_layout.dart lib/src/components/common/layout/custom_scroll_view_layout.dart lib/src/components/common/layout/box_layout.dart test/src/components/common/layout/scroll_frame_test.dart
```

---
### Task 8: Accessibility guideline tests

**Agent:** general-purpose
**Implements:** P4-9

These cases guard behavior that phase 3 and Tasks 2 to 7 already give a tappable row, so they pass from the start; no library file changes. Each guideline gets a control case that must miss it, which shows the guideline measures the row rather than skipping it: `MinimumTapTargetGuideline` skips a node that touches the screen edge (`flutter_test/lib/src/accessibility.dart:172-175`), so every row is 300 px wide inside the centered host.

**Files:**
- Create: `test/src/components/common/layout/a11y_guidelines_test.dart`

**Interfaces:**
- Consumes: `meetsGuideline`, `doesNotMeetGuideline` (`flutter_test/lib/src/matchers.dart:1300`, `:1308`), `labeledTapTargetGuideline`, `androidTapTargetGuideline` (`flutter_test/lib/src/accessibility.dart:825`, `:785`).
- Produces: nothing new.

- [ ] **Step 1: Write the guideline tests**

Create `test/src/components/common/layout/a11y_guidelines_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import '../fakes/fake_stratum_theme.dart';

void _noop() {}

/// A tappable list row, 300 px wide: a title and a subtitle, at least
/// [minHeight] tall. It stays clear of the screen edges, where the target
/// size guideline skips a node as possibly scrolled off.
Widget _row({double minHeight = 48, bool labeled = true}) {
  final row = RowLayout(
    style: WidgetStyle(
      minHeight: minHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
    ),
    interaction: const StratumInteraction(onTap: _noop),
    children: [
      if (labeled)
        const ColumnLayout(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Text('Wi-Fi'), Text('Connected')],
        )
      else
        const SizedBox(width: 100, height: 20),
    ],
  );
  return SizedBox(width: 300, child: row);
}

void main() {
  group('accessibility guidelines', () {
    testWidgets('a tappable row has a label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(themedHost(_row()));

      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('a tappable row without text has no label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(themedHost(_row(labeled: false)));

      await expectLater(
        tester,
        doesNotMeetGuideline(labeledTapTargetGuideline),
      );
      handle.dispose();
    });

    testWidgets('a 48 px tappable row meets the Android target size', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(themedHost(_row()));

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('a 40 px tappable row misses the Android target size', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        themedHost(SizedBox(height: 40, child: _row(minHeight: 0))),
      );

      await expectLater(
        tester,
        doesNotMeetGuideline(androidTapTargetGuideline),
      );
      handle.dispose();
    });

    testWidgets('(pin) a 48 px row of two lines grows at twice the text '
        'size without overflow', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: themedHost(_row()),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(RowLayout)).height, greaterThan(48));
    });
  });
}
```

- [ ] **Step 2: Run them**

Run: `flutter test --no-pub test/src/components/common/layout/a11y_guidelines_test.dart`
Expected: PASS, `+5: All tests passed!` The two control cases (`a tappable row without text has no label`, `a 40 px tappable row misses the Android target size`) pass only because the guideline fails them, which is what makes the two positive cases meaningful.

- [ ] **Step 3: Run the phase 4 gates**

Run: `flutter test --no-pub test/src/components/common/ test/src/themes/ > build/p4-tests.log 2>&1; tail -n 1 build/p4-tests.log`
Expected: `+540: All tests passed!`

Run: `flutter analyze --no-pub lib > build/p4-analyze.log 2>&1; grep -c ' error • ' build/p4-analyze.log; tail -n 1 build/p4-analyze.log`
Expected: `0`, then `50 issues found.` (the infos that predate phase 4).

Run, from `example/`: `flutter test --no-pub test/` and `flutter analyze --no-pub integration_test test_driver tool test`
Expected: `+78: All tests passed!` and `No issues found!`

Run: `grep -rnE 'class (Gesture[A-Za-z]*Layout|App[A-Za-z]*View|NoGlowScrollBehavior)\b|buildViewportChrome|scrollable' lib`
Expected: no output.

- [ ] **Step 4: Commit**

```bash
cd "<repo>"
git add -- test/src/components/common/layout/a11y_guidelines_test.dart
git commit -m "test(layout): check a tappable row against the label and tap-target guidelines" -- test/src/components/common/layout/a11y_guidelines_test.dart
```

---
### Task 9: Benchmark comparison against the phase 3 tip, and records

**Agent:** main session
**Implements:** P4-10, P4-11

The main session runs this task: it waits on a long background run, may need owner rulings, and writes outside the repository. The comparison measures HEAD after Task 8 against the fe31fdc layouts that Task 1 froze.

**Files:**
- Modify: `docs/superpowers/specs/2026-10-01-layout-primitives-design.md` (status line, sections 4, 6, 9.3, and 13)
- Modify, outside the repository: `profile/memory/project_stratum_ui_layout_primitives.md` and `profile/memory/ROADMAP.md` in the NTD OS root

**Interfaces:**
- Consumes: Task 1's `dart run tool/perf_abba.dart run --runs <n> [--from <first>]` and its exit codes; Task 8's gate results.
- Produces: the phase 4 benchmark verdict in the project memory entry; the closed `p4-keyboard-a11y` milestone.

- [ ] **Step 1: Check the harness at HEAD**

Run, from `example/`: `flutter test --no-pub test/perf/ && flutter analyze --no-pub integration_test`
Expected: `All tests passed!` and `No issues found!` Both kits still build every scene on HEAD's library.

- [ ] **Step 2: Start the comparison in the background**

Do not commit, edit `lib/` or `example/`, or let anyone else do so until Step 3 ends: `perf_abba` records `git rev-parse HEAD` and a hash of `git diff HEAD -- lib example` per run folder, and `run --from` refuses runs on another code state. The owner's uncommitted files under `lib/` count toward that hash. Keep the test window visible.

Run in the background (watch-lane), from `example/`:

```bash
rm -rf build/perf/abba && mkdir -p build/perf-logs && dart run tool/perf_abba.dart run --runs 12 > build/perf-logs/abba-p4.log 2>&1; echo "exit $?" >> build/perf-logs/abba-p4.log
```

At about 54 s per invocation, 36 invocations plus three builds take about 35 minutes.

- [ ] **Step 3: Read the verdict and act on it**

Run: `tail -20 build/perf-logs/abba-p4.log`

Act on the last line:
- `exit 0` (PASS): go to Step 4.
- `exit 2` (INCONCLUSIVE): run `dart run tool/perf_abba.dart run --from 13 --runs 12 > build/perf-logs/abba-p4-escalation.log 2>&1; echo "exit $?" >> build/perf-logs/abba-p4-escalation.log` in the background, then read its tail. When it ends in `exit 2` again, the cap of 24 runs is reached: show the owner the report, with each inconclusive scene's median and interval, and wait for a ruling (spec section 9.5).
- `exit 1` with `overall: INVALID`: run Step 2 again once. A second INVALID goes to the owner with the report.
- `exit 1` with `overall: FAIL`: show the owner the report and the failing rows; change no library code. The per-phase split of the stored `build/perf/abba/r*g*/<scene>.<side>.<pair>.timeline.json` files is the next diagnostic.
- `invalid runs:` naming `lost frames on current` only: tell the owner, because frames lost on the current side alone can signal a regression (spec section 9.5).
- A `code states differ:` line: the code moved during the run. Clear the runs (`rm -rf build/perf/abba`) and start Step 2 again.

- [ ] **Step 4: Keep the report**

Run: `cat build/perf/abba/report.md`

- [ ] **Step 5: Record the verdict in project memory**

In `profile/memory/project_stratum_ui_layout_primitives.md` (NTD OS root), add a section above "2026-10-01 — Phase 4 brainstorm rulings (spec amended in fe31fdc)":

```markdown
## <ISO date> — Phase 4 done; ABBA against the phase 3 tip: <PASS | owner ruling>

**Fact:** Phase 4 is on master, commits <first>..<last> (StratumScroll, MediaQuery reduced motion, K1 to K4, focus keep-alive, guideline tests); 540 library tests and 78 example tests pass, lib 0 errors. `perf_abba` compared fe31fdc (frozen, seven files) against <HEAD short hash> in <runs> runs, load <range>, interval <ms> ms, null resolution ±<x>%. <One line per scene from report.md: scene, blocks, median Δ%, interval, verdict.> <Invalid runs and reasons, if any.>
**Why:** Done-when of the `p4-keyboard-a11y` milestone (spec section 10).
**How to apply:** Phase 5 (more primitives) freezes the commit it starts from with `perf_freeze` and updates `BaselineKit`; S4 and S5 stay watch items.
```

Bump `verified:` in the frontmatter to the current date.

- [ ] **Step 6: Sync the spec**

In `docs/superpowers/specs/2026-10-01-layout-primitives-design.md`, replace:

```markdown
phase 4 design amended the same day (`StratumScroll`, section 13); phase 4 next.
```

with:

```markdown
phase 4 design amended the same day (`StratumScroll`, section 13); phase 4 done on <ISO date>.
```

Replace:

```markdown
| `layout/focus_group.dart` | new: `StratumFocusGroup` and its traversal policy (phase 4) |
```

with:

```markdown
| `layout/focus_group.dart` | new: `StratumFocusGroup`, exported; `FocusGroupFrame` and its traversal policy, not exported (phase 4) |
| `common/text_entry_guard.dart` | new, not exported: `primaryFocusInEditableText`, the text-entry guard that K2, K3, and K4 share (phase 4) |
```

Replace:

```markdown
- **Jumps.** Home and End use `jumpTo`, so no motion plays.
```

with:

```markdown
- **Without a theme.** `FocusSpread` reads the theme, so without a `StratumThemeApplication` the viewport takes focus and scrolls but draws no ring. Page Up and Page Down also act along a horizontal axis, where Flutter's `ScrollAction` does nothing.
- **Jumps.** Home and End use `jumpTo`, so no motion plays.
```

Replace:

```markdown
The old `GestureRowLayout` builds a `GestureContainerLayout`, which phase 3 removed. Each later phase freezes the commit it starts from and updates `BaselineKit`.
```

with:

```markdown
The old `GestureRowLayout` builds a `GestureContainerLayout`, which phase 3 removed. Each later phase freezes the commit it starts from and updates `BaselineKit`. Phase 4 freezes seven files of fe31fdc: `style/animated_styled_box.dart`, `layout/box_layout.dart`, `layout/container_layout.dart`, `layout/column_layout.dart`, `layout/row_layout.dart`, `ink_well.dart`, and `model/interaction.dart`; `layout/scroll_frame.dart` stays shared, because phase 4 keeps `ScrollFrame` and no scene scrolls a box layout.
```

At the end of section 13, add:

```markdown
- <ISO date>: phase 4 done. The plan added the non-exported `common/text_entry_guard.dart`, drew no viewport ring without a theme, and let Page Up and Page Down scroll a horizontal axis. Benchmark: <PASS, or the owner's ruling on the inconclusive scenes>; numbers in the project memory entry.
```

Run, from the repository root:

```bash
git add -- docs/superpowers/specs/2026-10-01-layout-primitives-design.md
git commit -m "docs(layout): close phase 4 in the layout primitives design" -- docs/superpowers/specs/2026-10-01-layout-primitives-design.md
```

- [ ] **Step 7: Close the roadmap milestone**

In `profile/memory/ROADMAP.md` (NTD OS root), re-read the file, then delete the milestone `### p4-keyboard-a11y` (its `done-when` holds). The phase `## stratum-layout-primitives` then has no milestone left, so delete it too, delete the `after: stratum-layout-primitives` line of `## stratum-layout-more-primitives`, and bump `updated:`, per the memory-roadmap rule. The project entry stays live: `stratum-layout-more-primitives` still links it under `memory:`.

---

## Coverage

Requirement ids: `P4-1` to `P4-11` name the phase 4 row of spec section 10 and the phase 4 rows of section 8; `D15` and `D16` are the defects of spec section 3 that phase 4 fixes.

| requirement | task(s) | note |
|-------------|---------|------|
| P4-1 per-block estimate; display-period, lost-frame, S2-plain, and code-state fixes; cap of 24 runs (9.4, 9.5) | T1 | the phase 3 tip frozen and `BaselineKit` updated in the same task (9.3) |
| P4-2 `StratumScroll` with `fillViewport`, `direction`, and the viewport `ratio` (2, 4, 5, 6, 7) | T2 | AlertDialog, D17, and stretch cases ported |
| P4-3 reduced motion reads `MediaQuery` (2, 6) | T3 | |
| P4-4 K1 context-menu key, Shift+F10, semantics action (6) | T4 | |
| P4-5 K2 `shortcuts`, text-entry guard, shortcut-only focus (6) | T5 | guard shared with T6 and T7 |
| P4-6 focus keep-alive (6) | T5 | D16 |
| P4-7 K3 `StratumFocusGroup` and roles (4, 6) | T6 | |
| P4-8 K4 `ScrollFocus`, `focusable`, `semanticsLabel`, controller rule (4, 5, 6) | T7 | |
| P4-9 guideline tests (8) | T8 | pass from the start, with control cases |
| P4-10 phase 4 tests pass (8, 10) | T2 to T8 | gates in T8 |
| P4-11 the benchmark still passes (9, 10) | T1, T9 | |
| D15 keyboard and assistive gaps | T4, T5, T6, T7 | |
| D16 focused item disposed in a lazy list | T5 | |
