# Layout Primitives Phase 3: Layout Family Implementation Plan

> **For agentic workers:** execute per the repository's execute rule; with none, run superpowers:subagent-driven-development in Dependency-table order. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Put the five box layouts on one `BoxLayout` base that takes a `StratumInteraction`, delete the five gesture twins, move `AnimatedStyledBox` onto its own `State` with `AnimationBehavior.preserve` and reduced motion, scroll inside the box, and prove by interleaved benchmark runs that no scene got slower.

**Architecture:** `BoxLayout` (new, `layout/box_layout.dart`) owns the only build pipeline. It builds a bare tier (content plus the semantics, repaint, debug, and keep-alive wrappers, no `AnimatedStyledBox`) when `style`, `ratio`, `rotate`, `transform`, and `interaction` are null and `scrollable` is false, and a box tier around `AnimatedStyledBox` otherwise. Semantics and the `StratumInkWell` tap surface enter through `AnimatedStyledBox.boxBuilder`, inside the margin; scrolling enters through a new `AnimatedStyledBox.scrollBuilder`, between the padding and the fixed decoration, so fill, border, radius, and shadow stay in place while padding and content scroll. The five layouts only declare their own parameters and override `buildContent`. `AnimatedStyledBox` replaces `ImplicitlyAnimatedWidget` with its own `State`, so its controller uses `AnimationBehavior.preserve` and geometry jumps under reduced motion while paint fields fade. The benchmark's A/B baseline is a commit that adds the S1-fast, S2-box, and S2-plain scenes on the old API before any library change; S2-box against S2-plain decides whether the controller is created lazily.

**Tech Stack:** Flutter 3.47.3, Dart ^3.13.3, flutter_test, very_good_analysis 11, freezed (`WidgetStyle.copyWith`), `integration_test` and `flutter_driver` (SDK packages in `example/`), macOS desktop in profile mode.

**Spec:** `docs/superpowers/specs/2026-10-01-layout-primitives-design.md` (sections 1, 2, 3, 4 without the phase 4 fields, 5, 6 "Scrolling inside the box" and "Reduced motion", 7, 8 phase 3 rows, 9, 10 phase 3). PRD user stories in scope: none (`docs/prds/d01_context.md`, `d02_features.md`, and `d03_non_functional.md` are empty).

**Anchor base:** master 208d05e

**Preconditions:**
- `flutter test --no-pub test/src/components/common/ test/src/themes/` passes on master before Task 1.
- The phase 2 harness (`example/integration_test/layout_perf_test.dart`, `example/test_driver/perf_driver.dart`, `example/tool/perf_median.dart`, as of 56ac281) builds and runs on macOS in profile mode.
- The owner's work in progress is the one Global Constraints lists, and none of it is staged by this plan.

## Global Constraints

- Work in the main working tree on `master`. Owner work in progress stays out of every commit: the staged rename `assets/themes/example.yaml -> assets/themes/default/theme.yaml`, any modified figma specs, and the untracked `example/macos/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/` and `example/macos/Runner.xcworkspace/xcshareddata/swiftpm/`.
- Commit with explicit paths only: `git add -- <paths>` (or `git rm -- <paths>` for a deletion), then `git commit -m "<message>" -- <paths>`. Write each path literally in the command; zsh does not word-split a variable into several paths. Conventional Commits with a scope; no `Co-Authored-By` line and no AI attribution.
- Constructors use the `new` form: `const new(` for the unnamed constructor and `const new builder(` for a named one. `new.builder(` fails with `new_constructor_dot_name`.
- Desktop-scrollbar tests wrap the widget in `Theme(data: ThemeData(platform: TargetPlatform.macOS), child: ...)`, because `MaterialScrollBehavior` reads the platform from the theme and the cached fallback theme keeps the first test's platform.
- `ScrollCacheExtent` is exported only by `package:flutter/rendering.dart`; a file that names it adds `import 'package:flutter/rendering.dart' show ScrollCacheExtent;`.
- Layout files and their tests import the barrel `package:stratum_ui/src/src.dart`. `scroll_frame.dart` is not exported by any barrel; `box_layout.dart` imports `package:stratum_ui/src/components/common/layout/scroll_frame.dart` directly. The style unit `animated_styled_box.dart` and its test keep their narrow imports.
- Lints come from very_good_analysis 11: package imports only, sorted directives, constructors before fields, single quotes, lines at most 80 characters in `lib/`. Every new or rewritten file analyzes with no issue.
- Do not run `dart format` on a file the task does not write whole; the repository has formatting drift outside phase 3.
- Phase 4 stays out: no `shortcuts`, `secondaryTapSemanticsLabel`, `StratumFocusGroup`, `focusGroup`, `ScrollFocus`, `focusable`, or `semanticsLabel`; no K1 to K4 keys and no focus keep-alive. `ink_well.dart` does not change in this phase.
- The barrel `lib/src/src.dart` and the example harness compile after every commit: a file leaves `layout/layout.dart` in the commit that deletes it, and the S3 scene moves to the new API in the commit that deletes `GestureRowLayout`.
- Run tests with `flutter test --no-pub <paths>` and the analyzer with `flutter analyze --no-pub <paths>`. Run every command in the foreground. A profile run, or any command likely to take over a minute, writes to a log under `example/build/perf-logs/` (ignored by git through `/*/build/`) or `build/` at the repository root, and the step reads the log's tail.
- Benchmark (spec section 9): macOS desktop in profile mode, `flutter drive --profile --endless-trace-buffer`, semantics off (every scene already passes `semanticsEnabled: false`), the test window on the same display for every run. Compare by interleaved baseline and candidate runs, five each, on the median of the paired differences; the stored medians are a sanity reference only.
- Measured numbers go to `profile/memory/project_stratum_ui_layout_primitives.md` in the NTD OS root (outside this repository), never into the spec or the repository.
- `.worktrees/` is not in `.gitignore`; never stage it, and remove the baseline worktree at the end of Task 10.

## Review Focus

- A layout whose `interaction` sets every field: a person expects each value to reach `StratumInkWell` unchanged; the forwarding function maps 18 fields by hand, the source of the D12 drift. Pinned in Task 5 ("hands every interaction field to the tap surface").
- A layout that toggles `scrollable` while its child holds state (a text field, an expanded tile): a person expects the child to keep its `State`, although the content moves into a `LayoutBuilder` under a `GlobalKey`. Pinned in Task 6 ("toggling scrollable keeps the children State").
- `onEndAnimate` on a layout with an `interaction` and a style without `animationStyle`: a person expects one call per change, because the interaction's 100 ms default makes the change animated. Pinned in Task 5 ("onEndAnimate fires once under the 100 ms default").
- A rounded glass box that scrolls (`borderRadius`, `backgroundBlur`, `scrollable`): a person expects one rounded clip, not a blur clip plus a scroll clip. Pinned in Task 3 ("a rounded, blurred box that scrolls clips once").
- Reduced motion switched on while the app runs: a person expects the next style change to jump geometry, without a restart. Pinned in Task 2 ("reads the flag again on every style change").

## File map

| File | Task | Responsibility |
|---|---|---|
| `example/integration_test/layout_perf_test.dart` | 1, 8 | Scenes S1-fast, S2-box, and S2-plain (Task 1, old API; S2-box and S2-plain decide the lazy controller); S3 on `RowLayout(interaction:)` (Task 8) |
| `example/tool/perf_pairs.dart` | 1 | Paired comparison of two run sets and the section 9 verdict |
| `lib/src/components/common/style/animated_styled_box.dart` | 2, 3, 4 | Own `State`, `preserve`, reduced motion (2); `scrollBuilder` and the one clip (3); lazy controller when Task 1 calls for it (4) |
| `lib/src/components/common/interaction.dart` | 5 | `StratumInteraction` value class |
| `lib/src/components/common/layout/box_layout.dart` | 5, 6 | `BoxLayout` pipeline (5); viewport stretch (6) |
| `lib/src/components/common/layout/column_layout.dart`, `row_layout.dart` | 6 | Column and row on `BoxLayout` |
| `lib/src/components/common/layout/stack_layout.dart`, `wrap_layout.dart` | 7 | Stack and wrap on `BoxLayout` |
| `lib/src/components/common/layout/container_layout.dart` | 8 | Container on `BoxLayout`, without `boxBuilder` |
| `lib/src/components/common/layout/gesture_*_layout.dart` (5 files) | 8 | Deleted |
| `lib/src/components/common/layout/layout.dart`, `lib/src/components/common/common.dart` | 5, 8 | Barrel exports |
| `test/src/components/common/layout/box_layout_test.dart` | 5 | Tiers, tree order, semantics, tap surface |
| `test/src/components/common/interaction_test.dart` | 8 | The nine ported gesture cases and the callback toggle |
| `test/src/components/common/layout/*_layout_test.dart`, `style/animated_styled_box_test.dart` | 2 to 8 | Ported and new cases of spec section 8 |

---

## Milestone M1: Benchmark baseline on the old API

### Task 1 (M1-T1): S1-fast, S2-box, and S2-plain scenes, the pairs tool, and the lazy-controller decision

**Agent:** general-purpose
**Implements:** P3-7, P3-9

**Files:**
- Modify: `example/integration_test/layout_perf_test.dart:122` (add `_plainChildren`, `sceneBoxRow`, and `scenePlainRow` above the S3 builder), `:269` (add the S1-fast test above the S2 test), `:279` (add the S2-box and S2-plain tests above the S3 test)
- Create: `example/tool/perf_pairs.dart`
- No file under `lib/` changes. This task's commit is the A/B baseline that Task 10 checks out. S2's builder and test stay exactly as they are.

**Interfaces:**
- Consumes: `perfHost`, `scrollFor(tester, duration, {distance})`, `_list`, `_cardStyle`, `_streams`, `sceneRow` from the phase 2 harness; the old `RowLayout(style:, mainAxisAlignment:, children:)`; `StyleDecoration(color:, borderRadius:, dropShadow:, innerShadow:)` from `lib/src/components/common/style/style_decoration.dart`.
- Produces: report keys `S1-fast`, `S2-box`, and `S2-plain`; builders `List<Widget> _plainChildren(int index)`, `Widget sceneBoxRow(int index)`, and `Widget scenePlainRow(int index)`; the command `dart run tool/perf_pairs.dart <base> <candidate> [<base scene>=<candidate scene> ...]` that prints one Markdown row per pair with the column `Δ avg %` (median over paired runs of `(candidate − base) / base × 100`) and a `verdict` of `pass`, `FAIL`, or `INVALID interval`; the Task 1 commit, found later by `git log --format=%H -1 --grep='S1-fast, S2-box, and S2-plain'`; the lazy-controller decision in the project memory entry.

Scene decisions (made here so Task 10 compares like with like):
- **S1-fast.** At 4000 px/s and 144 Hz a 40 px row of S1 scrolls in once every 1.4 frames, so most frames build no row and the bare-tier gain hides in the noise (phase 2 review, recorded in the project memory). S1-fast scrolls the same rows at 16000 px/s (about 111 px, close to three rows, per frame at 144 Hz). The test asserts the row height stays under 16000 / 144 px, so a font change that makes rows taller fails loudly instead of measuring less.
- **Decision pair, main session ruling 2026-10-01.** The spec's 10% rule compares S2 with S2-plain, but S2's rows also hold two old `ColumnLayout`s, and each builds its own `AnimatedStyledBox` (D7); those boxes sit in both scenes and shrink the measured gap. The decision therefore compares two scenes whose children are plain Flutter `Column`s (`_plainChildren`, the same columns, alignments, and texts as `_rowChildren`), so the row's `AnimatedStyledBox` is the only one per row. S2 itself stays unchanged as an A/B scene.
- **S2-box.** The old `RowLayout(style: _cardStyle)` around `_plainChildren`: the row box under test.
- **S2-plain.** The same margin, decoration, padding, and plain-Column children as S2-box, drawn with `ConstrainedBox`, `DecoratedBox(StyleDecoration)`, and `ClipRRect` directly instead of through `AnimatedStyledBox`; its `Row` is Flutter's, because the old `RowLayout` always builds an `AnimatedStyledBox` (D7). `_cardStyle` sets no size and no `clipBehavior`, so S2-box's `AnimatedStyledBox` builds no constraint and no clip; S2-plain passes empty constraints and `Clip.none`. These pass-through values are kept (main session ruling 2026-10-01): they keep the spec's widget list while S2-plain paints and lays out the same work as S2-box, so the gap measures only the `AnimatedStyledBox` wrapper. The S2-plain test checks that both lists have the same scroll extent, so the two scenes scroll rows of the same height.

- [ ] **Step 1: Add the S2-box and S2-plain builders**

In `example/integration_test/layout_perf_test.dart`, insert above the line `/// S3: S2 with a tap callback and the 100 ms default style animation.`:

```dart
/// S1's two columns as plain Flutter [Column]s.
///
/// The old `ColumnLayout` builds an [AnimatedStyledBox] of its own (D7),
/// which would sit in both decision scenes and hide the row box's cost.
List<Widget> _plainChildren(int index) {
  return [
    Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Text('Item $index'), const Text('Subtitle')],
    ),
    Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [Text('${index * 3}'), const Text('units')],
    ),
  ];
}

/// S2-box: S2's styled row around plain columns, so the row's
/// [AnimatedStyledBox] is the only one in each row (spec section 2, the
/// lazy-controller threshold).
Widget sceneBoxRow(int index) {
  return RowLayout(
    style: _cardStyle,
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: _plainChildren(index),
  );
}

/// S2-plain: the S2-box row drawn without [AnimatedStyledBox], to measure
/// that widget's own cost.
///
/// The same margin, decoration, padding, and children as S2-box.
/// `_cardStyle` sets no size and no `clipBehavior`, so S2-box paints no
/// clip and adds no constraint; the empty constraints and `Clip.none` keep
/// this tree's painted output and render work equal to S2-box.
Widget scenePlainRow(int index) {
  return Padding(
    padding: _cardStyle.margin!,
    child: ConstrainedBox(
      constraints: const BoxConstraints(),
      child: DecoratedBox(
        decoration: StyleDecoration(
          color: _cardStyle.backgroundColor,
          borderRadius: _cardStyle.borderRadius,
          dropShadow: _cardStyle.dropShadow,
          innerShadow: _cardStyle.innerShadow,
        ),
        child: ClipRRect(
          borderRadius: _cardStyle.borderRadius!,
          clipBehavior: Clip.none,
          child: Padding(
            padding: _cardStyle.padding!,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _plainChildren(index),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The estimated scroll extent of the first [Scrollable]; two lists of
/// rows with the same height report the same value.
double _scrollExtent(WidgetTester tester) {
  return tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position
      .maxScrollExtent;
}
```

- [ ] **Step 2: Add the three traced tests**

In `main()`, insert above `  testWidgets('S2 styled rows', (tester) async {`:

```dart
  testWidgets('S1-fast plain rows at 16000 px/s', (tester) async {
    await tester.pumpWidget(perfHost(_list(sceneRow)));
    // More than one new row per frame at 144 Hz: 16000 px/s over 144
    // frames is 111 px per frame.
    expect(
      tester.getSize(find.byType(RowLayout).first).height,
      lessThan(16000 / 144),
    );
    await binding.traceAction(
      () => scrollFor(tester, traceTime, distance: 16000),
      streams: _streams,
      reportKey: 'S1-fast',
    );
    expect(tester.takeException(), isNull);
  }, semanticsEnabled: false);
```

and above `  testWidgets('S3 tappable rows', (tester) async {`:

```dart
  testWidgets('S2-box styled rows around plain columns', (tester) async {
    await tester.pumpWidget(perfHost(_list(sceneBoxRow)));
    await binding.traceAction(
      () => scrollFor(tester, traceTime),
      streams: _streams,
      reportKey: 'S2-box',
    );
    expect(tester.takeException(), isNull);
  }, semanticsEnabled: false);

  testWidgets('S2-plain: the S2-box rows without AnimatedStyledBox', (
    tester,
  ) async {
    // Equal row heights give equal list extents, so both decision scenes
    // scroll the same rows.
    await tester.pumpWidget(perfHost(_list(sceneBoxRow)));
    final boxExtent = _scrollExtent(tester);
    await tester.pumpWidget(perfHost(_list(scenePlainRow)));
    expect(_scrollExtent(tester), closeTo(boxExtent, 0.5));
    await binding.traceAction(
      () => scrollFor(tester, traceTime),
      streams: _streams,
      reportKey: 'S2-plain',
    );
    expect(tester.takeException(), isNull);
  }, semanticsEnabled: false);
```

- [ ] **Step 3: Write the pairs tool**

Create `example/tool/perf_pairs.dart`:

```dart
import 'dart:convert';
import 'dart:io';

/// Frame budget at 120 Hz, in milliseconds (spec section 9).
const _budget = 8.3;

/// Largest allowed rise of the median average build time, in percent.
const _maxAverageRise = 5.0;

/// Compares two sets of benchmark runs by paired differences.
///
/// Usage:
/// `dart run tool/perf_pairs.dart <base> <candidate> [<base>=<candidate> ...]`
///
/// `<base>` and `<candidate>` each hold the `run<N>/` directories that
/// `test_driver/perf_driver.dart` writes. Run N of the base pairs with run N
/// of the candidate, so interleaved runs pair with their neighbor. Without
/// scene arguments every scene found on both sides pairs with itself; an
/// argument such as `S2-plain=S2-box` pairs two different scenes, for example
/// within one directory. Prints, per pair, the base and candidate medians,
/// the median of the paired differences, and the spec's pass verdict.
void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln(
      'usage: dart run tool/perf_pairs.dart <base> <candidate> '
      '[<base scene>=<candidate scene> ...]',
    );
    exitCode = 64;
    return;
  }
  final base = _readRuns(args[0]);
  final candidate = _readRuns(args[1]);
  final pairs = args.length > 2
      ? [for (final arg in args.skip(2)) arg.split('=')]
      : [
          for (final scene in _scenes(base).intersection(_scenes(candidate)))
            [scene, scene],
        ];
  pairs.sort((a, b) => a.last.compareTo(b.last));
  stdout
    ..writeln(
      '| pair | runs | avg build ms | Δ avg % | p99 build ms | Δ p99 build '
      '| p99 raster ms | Δ p99 raster | interval ms | verdict |',
    )
    ..writeln('|---|---|---|---|---|---|---|---|---|---|');
  for (final [baseScene, candidateScene] in pairs) {
    final runs = [
      for (final run in base.keys)
        if (base[run]![baseScene] != null &&
            candidate[run]?[candidateScene] != null)
          (base[run]![baseScene]!, candidate[run]![candidateScene]!),
    ];
    if (runs.isEmpty) {
      stdout.writeln('| $baseScene=$candidateScene | 0 | no paired runs |');
      continue;
    }
    stdout.writeln(_row('$baseScene=$candidateScene', runs));
  }
}

String _row(String name, List<(_Summary, _Summary)> runs) {
  double medianOf(double Function(_Summary s) metric, {required bool base}) =>
      _median([for (final (b, c) in runs) metric(base ? b : c)]);
  double deltaOf(double Function(_Summary s) metric) =>
      _median([for (final (b, c) in runs) metric(c) - metric(b)]);

  final averageRise = _median([
    for (final (b, c) in runs) (c.average - b.average) / b.average * 100,
  ]);
  final baseBuild = medianOf((s) => s.p99Build, base: true);
  final candidateBuild = medianOf((s) => s.p99Build, base: false);
  final baseRaster = medianOf((s) => s.p99Raster, base: true);
  final candidateRaster = medianOf((s) => s.p99Raster, base: false);
  final buildDelta = deltaOf((s) => s.p99Build);
  final rasterDelta = deltaOf((s) => s.p99Raster);
  final baseInterval = medianOf((s) => s.interval, base: true);
  final candidateInterval = medianOf((s) => s.interval, base: false);

  bool withinBudget(double baseValue, double candidate, double delta) =>
      candidate < _budget || (baseValue >= _budget && delta <= 0);

  final String verdict;
  if ((candidateInterval - baseInterval).abs() > baseInterval * 0.1) {
    verdict = 'INVALID interval';
  } else if (averageRise <= _maxAverageRise &&
      withinBudget(baseBuild, candidateBuild, buildDelta) &&
      withinBudget(baseRaster, candidateRaster, rasterDelta)) {
    verdict = 'pass';
  } else {
    verdict = 'FAIL';
  }
  String ms(double value) => value.toStringAsFixed(2);
  return '| $name | ${runs.length} '
      '| ${ms(medianOf((s) => s.average, base: true))} → '
      '${ms(medianOf((s) => s.average, base: false))} '
      '| ${averageRise.toStringAsFixed(2)} '
      '| ${ms(baseBuild)} → ${ms(candidateBuild)} | ${ms(buildDelta)} '
      '| ${ms(baseRaster)} → ${ms(candidateRaster)} | ${ms(rasterDelta)} '
      '| ${ms(baseInterval)} / ${ms(candidateInterval)} | $verdict |';
}

class _Summary {
  _Summary(Map<String, dynamic> json)
    : average = (json['average_frame_build_time_millis'] as num).toDouble(),
      p99Build = (json['99th_percentile_frame_build_time_millis'] as num)
          .toDouble(),
      p99Raster = (json['99th_percentile_frame_rasterizer_time_millis'] as num)
          .toDouble(),
      interval = _medianInterval(json);

  final double average;
  final double p99Build;
  final double p99Raster;

  /// Median gap between frame starts, in milliseconds.
  final double interval;
}

/// Run directory name, then scene, then that run's summary.
Map<String, Map<String, _Summary>> _readRuns(String root) {
  final runs = <String, Map<String, _Summary>>{};
  final directories = Directory(root).listSync().whereType<Directory>().where(
    (directory) => directory.uri.pathSegments
        .lastWhere((segment) => segment.isNotEmpty)
        .startsWith('run'),
  );
  for (final directory in directories) {
    final name = directory.uri.pathSegments.lastWhere(
      (segment) => segment.isNotEmpty,
    );
    final files = directory.listSync().whereType<File>().where(
      (file) => file.path.endsWith('.timeline_summary.json'),
    );
    runs[name] = {
      for (final file in files)
        file.uri.pathSegments.last.split('.').first: _Summary(
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
        ),
    };
  }
  return runs;
}

Set<String> _scenes(Map<String, Map<String, _Summary>> runs) {
  return {for (final run in runs.values) ...run.keys};
}

double _median(List<double> values) {
  final sorted = [...values]..sort();
  final middle = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[middle]
      : (sorted[middle - 1] + sorted[middle]) / 2;
}

double _medianInterval(Map<String, dynamic> summary) {
  final begins = (summary['frame_begin_times'] as List).cast<num>();
  final intervals = [
    for (var i = 1; i < begins.length; i++) (begins[i] - begins[i - 1]) / 1000,
  ];
  return _median(intervals);
}
```

- [ ] **Step 4: Analyze the harness**

Run: `cd example && flutter analyze --no-pub integration_test test_driver tool`
Expected: `No issues found!`

- [ ] **Step 5: Smoke-run every scene in debug**

Run: `cd example && mkdir -p build/perf-logs && flutter test integration_test/layout_perf_test.dart -d macos > build/perf-logs/smoke-p3-base.log 2>&1; tail -n 3 build/perf-logs/smoke-p3-base.log`
Expected: `All tests passed!` with 8 tests. A failure in the S1-fast row-height check means the rows grew; stop and report the measured height instead of changing the speed. A failure in the S2-plain extent check means S2-plain and S2-box no longer draw rows of the same height; fix `scenePlainRow`, not the threshold.

- [ ] **Step 6: Commit the A/B baseline**

```bash
git add -- example/integration_test/layout_perf_test.dart example/tool/perf_pairs.dart
git commit -m "test(example): add the S1-fast, S2-box, and S2-plain benchmark scenes" -- example/integration_test/layout_perf_test.dart example/tool/perf_pairs.dart
git log --format='%h %s' -1
```

Expected: one commit whose subject contains `S1-fast, S2-box, and S2-plain`; record its hash in the ledger as the A/B baseline. No file under `lib/` is in it (`git show --stat HEAD` lists only the two example files).

- [ ] **Step 7: Run five profile passes on the baseline**

Run each command from `example/`, one after another, each in the foreground:

```bash
rm -rf build/perf && mkdir -p build/perf-logs
PERF_RUN=1 flutter drive --profile --endless-trace-buffer -d macos --driver=test_driver/perf_driver.dart --target=integration_test/layout_perf_test.dart > build/perf-logs/base-run1.log 2>&1; grep -E "frames, span|All tests passed" build/perf-logs/base-run1.log
PERF_RUN=2 flutter drive --profile --endless-trace-buffer -d macos --driver=test_driver/perf_driver.dart --target=integration_test/layout_perf_test.dart > build/perf-logs/base-run2.log 2>&1; grep -E "frames, span|All tests passed" build/perf-logs/base-run2.log
PERF_RUN=3 flutter drive --profile --endless-trace-buffer -d macos --driver=test_driver/perf_driver.dart --target=integration_test/layout_perf_test.dart > build/perf-logs/base-run3.log 2>&1; grep -E "frames, span|All tests passed" build/perf-logs/base-run3.log
PERF_RUN=4 flutter drive --profile --endless-trace-buffer -d macos --driver=test_driver/perf_driver.dart --target=integration_test/layout_perf_test.dart > build/perf-logs/base-run4.log 2>&1; grep -E "frames, span|All tests passed" build/perf-logs/base-run4.log
PERF_RUN=5 flutter drive --profile --endless-trace-buffer -d macos --driver=test_driver/perf_driver.dart --target=integration_test/layout_perf_test.dart > build/perf-logs/base-run5.log 2>&1; grep -E "frames, span|All tests passed" build/perf-logs/base-run5.log
```

Expected for each run: eight lines `S1: … frames, span … ms, frame interval … ms` (keys S1, S1-fast, S2, S2-box, S2-plain, S3, S4, S5), each span close to 2000 ms, and `All tests passed.`. A run that throws the driver's coverage `StateError` is rerun with the same `PERF_RUN`.

- [ ] **Step 8: Decide the lazy controller**

Run: `cd example && dart run tool/perf_median.dart && dart run tool/perf_pairs.dart build/perf build/perf S2-plain=S2-box`
Expected: the median table lists 8 scenes with `runs` = 5 and one frame interval; the pairs tool prints one row `S2-plain=S2-box` with `runs` = 5. Read only its `Δ avg %` column (the median, over the five paired runs, of how far S2-box's average build time sits above S2-plain's); its `verdict` column does not apply to this pair.

Decision rule (spec section 2, fixed before measuring, applied to S2-box by the main session ruling of 2026-10-01): `Δ avg %` above 10.00 means Task 4 runs; 10.00 or below means Task 4 is skipped.

- [ ] **Step 9: Record**

Add a dated section to `profile/memory/project_stratum_ui_layout_primitives.md` (NTD OS root) with: the median table, the `S2-plain=S2-box` row, the decision ("Task 4 runs" or "Task 4 skipped"), the baseline commit hash, the frame interval, the macOS version (`sw_vers -productVersion`), the machine model (`sysctl -n hw.model`), and the load average (`uptime`). Bump its `verified:` date. Note in the ledger: `Task 1: Δ avg % S2-box over S2-plain = <value>; Task 4 <runs|skipped>`.

### M1 Dependency table

| task  | depends-on | agent           |
|-------|------------|-----------------|
| M1-T1 | —          | general-purpose |

---

## Milestone M2: Layout family

### Task 2 (M2-T2): `AnimatedStyledBox` on its own `State`, with `preserve` and reduced motion

**Agent:** general-purpose
**Implements:** P3-6, D14

**Files:**
- Modify: `lib/src/components/common/style/animated_styled_box.dart:9-65` (the widget class, the state class through `build`) and `:240-241` (the tween constructor)
- Test: `test/src/components/common/style/animated_styled_box_test.dart` (new group above `group('AnimatedStyledBox boxBuilder'`, at `:365`)

**Interfaces:**
- Consumes: `WidgetStyle.copyWith` (freezed; a null argument clears the field), `WidgetStyle.lerp`.
- Produces: `class AnimatedStyledBox extends StatefulWidget` with `const new({Key? key, WidgetStyle? style, double? ratio, Matrix4? transform, AlignmentGeometry? transformAlignment, VoidCallback? onEnd, StyledBoxBuilder? boxBuilder, Widget? child})`. The parameter names stay those of today, so `ContainerLayout`'s call (`onEnd:`, `boxBuilder:`) compiles unchanged. The state keeps `_childKey`, `_boxKey`, and `_buildBox(WidgetStyle)`; Task 3 edits `_buildBox` and the constructor, Task 4 replaces the controller members.

- [ ] **Step 1: Write the failing tests**

In `test/src/components/common/style/animated_styled_box_test.dart`, insert this group above `  group('AnimatedStyledBox boxBuilder', () {`:

```dart
  group('AnimatedStyledBox reduced motion', () {
    const linear = AnimationStyle(
      duration: Duration(milliseconds: 100),
      curve: Curves.linear,
    );
    const small = WidgetStyle(
      width: 40,
      height: 20,
      backgroundColor: _red,
      animationStyle: linear,
    );
    const large = WidgetStyle(
      width: 80,
      height: 40,
      backgroundColor: _blue,
      animationStyle: linear,
    );

    void useFeatures(WidgetTester tester, FakeAccessibilityFeatures features) {
      tester.platformDispatcher.accessibilityFeaturesTestValue = features;
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
    }

    testWidgets('a fade keeps its duration under disableAnimations', (
      tester,
    ) async {
      useFeatures(
        tester,
        const FakeAccessibilityFeatures(disableAnimations: true),
      );
      await tester.pumpWidget(
        _host(const WidgetStyle(backgroundColor: _red, animationStyle: linear)),
      );
      await tester.pumpWidget(
        _host(
          const WidgetStyle(backgroundColor: _blue, animationStyle: linear),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      // AnimationBehavior.normal would have cut the fade to 5 ms.
      expect(_fillColor(tester), Color.lerp(_red, _blue, 0.5));
    });

    for (final (name, features) in const [
      ('reduceMotion', FakeAccessibilityFeatures(reduceMotion: true)),
      ('disableAnimations', FakeAccessibilityFeatures(disableAnimations: true)),
    ]) {
      testWidgets('$name: geometry jumps while the color fades', (
        tester,
      ) async {
        useFeatures(tester, features);
        await tester.pumpWidget(_host(small, child: null));
        await tester.pumpWidget(_host(large, child: null));

        expect(tester.getSize(_decorated()), const Size(80, 40));
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.getSize(_decorated()), const Size(80, 40));
        expect(_fillColor(tester), Color.lerp(_red, _blue, 0.5));
      });
    }

    testWidgets('reads the flag again on every style change', (tester) async {
      await tester.pumpWidget(_host(small, child: null));
      await tester.pumpWidget(_host(large, child: null));
      await tester.pumpAndSettle();
      useFeatures(tester, const FakeAccessibilityFeatures(reduceMotion: true));

      await tester.pumpWidget(_host(small, child: null));

      expect(tester.getSize(_decorated()), const Size(40, 20));
    });

    testWidgets('(pin) without a flag the geometry animates', (tester) async {
      await tester.pumpWidget(_host(small, child: null));
      await tester.pumpWidget(_host(large, child: null));
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.getSize(_decorated()), const Size(60, 30));
    });
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test --no-pub test/src/components/common/style/animated_styled_box_test.dart`
Expected: 4 failures. "a fade keeps its duration under disableAnimations" (Expected the half-way purple, Actual blue: the normal behavior cut the fade to 5 ms); "reduceMotion: geometry jumps while the color fades" and "disableAnimations: geometry jumps while the color fades" (Expected `Size(80.0, 40.0)`, Actual `Size(40.0, 20.0)`); "reads the flag again on every style change" (Expected `Size(40.0, 20.0)`, Actual `Size(80.0, 40.0)`). "(pin) without a flag the geometry animates" passes.

- [ ] **Step 3: Rewrite the widget and its state**

In `lib/src/components/common/style/animated_styled_box.dart`, replace everything from the line `/// Paints a [WidgetStyle] around [child] and animates between styles.` down to and including the line `  Widget build(BuildContext context) => _buildBox(_style!.evaluate(animation));` with:

```dart
/// Paints a [WidgetStyle] around [child] and animates between styles.
///
/// Duration and curve come from the target style's
/// [WidgetStyle.animationStyle]; a null value applies the new style in the
/// same frame. A null curve uses [Curves.easeInOutSine], because a linear
/// change looks stiff. `AnimationStyle.reverseDuration` and `reverseCurve`
/// are not used.
///
/// When the platform asks for less motion (`disableAnimations` or
/// `reduceMotion`), size, spacing, and alignment jump to the new style while
/// colors, borders, radius, shadows, blur, and opacity still fade over the
/// full duration. The fade keeps its duration on every platform, because the
/// controller uses [AnimationBehavior.preserve].
class AnimatedStyledBox extends StatefulWidget {
  const new({
    super.key,
    this.style,
    this.ratio,
    this.transform,
    this.transformAlignment,
    this.onEnd,
    this.boxBuilder,
    this.child,
  });

  final WidgetStyle? style;
  final double? ratio;
  final Matrix4? transform;
  final AlignmentGeometry? transformAlignment;

  /// Called when a style animation completes.
  final VoidCallback? onEnd;

  /// Wraps the box after its size constraints and before its margin,
  /// transform, and opacity.
  ///
  /// Receives the style of the current animation frame. The result keeps
  /// its State when wrappers above it come and go.
  final StyledBoxBuilder? boxBuilder;
  final Widget? child;

  @override
  State<AnimatedStyledBox> createState() => _AnimatedStyledBoxState();
}

class _AnimatedStyledBoxState extends State<AnimatedStyledBox>
    with SingleTickerProviderStateMixin {
  final GlobalKey _childKey = GlobalKey(debugLabel: 'AnimatedStyledBox.child');
  final GlobalKey _boxKey = GlobalKey(debugLabel: 'AnimatedStyledBox.box');

  late final AnimationController _controller = AnimationController(
    duration: _duration,
    animationBehavior: AnimationBehavior.preserve,
    vsync: this,
  );
  late CurvedAnimation _animation = CurvedAnimation(
    parent: _controller,
    curve: _curve,
  );
  late final _WidgetStyleTween _style = _WidgetStyleTween(
    begin: _target,
    end: _target,
  );

  WidgetStyle get _target => widget.style ?? const WidgetStyle();

  Duration get _duration =>
      widget.style?.animationStyle?.duration ?? Duration.zero;

  Curve get _curve => widget.style?.animationStyle?.curve ?? _defaultCurve;

  static const Curve _defaultCurve = Curves.easeInOutSine;

  @override
  void initState() {
    super.initState();
    _controller
      ..addListener(_handleTick)
      ..addStatusListener(_handleStatus);
  }

  @override
  void didUpdateWidget(AnimatedStyledBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldCurve = oldWidget.style?.animationStyle?.curve ?? _defaultCurve;
    if (_curve != oldCurve) {
      _animation.dispose();
      _animation = CurvedAnimation(parent: _controller, curve: _curve);
    }
    _controller.duration = _duration;
    final target = _target;
    if (target == _style.end) return;
    var begin = _style.evaluate(_animation);
    if (_reducesMotion) begin = _jumpGeometry(begin, to: target);
    _style
      ..begin = begin
      ..end = target;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _animation.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleTick() => setState(() {});

  void _handleStatus(AnimationStatus status) {
    if (status.isCompleted) widget.onEnd?.call();
  }

  /// Whether the platform asks for less motion. `MediaQueryData` has no
  /// `reduceMotion` field, so the flags come from the view's dispatcher.
  bool get _reducesMotion {
    final features = View.of(context).platformDispatcher.accessibilityFeatures;
    return features.disableAnimations || features.reduceMotion;
  }

  /// [from] with the size, spacing, and alignment of [to], so those fields
  /// stay at their target while the rest of the style fades.
  static WidgetStyle _jumpGeometry(
    WidgetStyle from, {
    required WidgetStyle to,
  }) {
    return from.copyWith(
      width: to.width,
      height: to.height,
      minWidth: to.minWidth,
      maxWidth: to.maxWidth,
      minHeight: to.minHeight,
      maxHeight: to.maxHeight,
      padding: to.padding,
      margin: to.margin,
      alignment: to.alignment,
    );
  }

  @override
  Widget build(BuildContext context) => _buildBox(_style.evaluate(_animation));
```

Then change the tween at the end of the file so it takes an end value:

```dart
class _WidgetStyleTween extends Tween<WidgetStyle> {
  new({super.begin, super.end});

  @override
  WidgetStyle lerp(double t) => WidgetStyle.lerp(begin, end, t)!;
}
```

`_buildBox` and every helper below it stay as they are.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test --no-pub test/src/components/common/`
Expected: `All tests passed!` (the layout tests still build `ContainerLayout`, which passes `onEnd` and `boxBuilder` unchanged).

Run: `flutter analyze --no-pub lib/src/components/common/style/animated_styled_box.dart test/src/components/common/style/animated_styled_box_test.dart`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add -- lib/src/components/common/style/animated_styled_box.dart test/src/components/common/style/animated_styled_box_test.dart
git commit -m "feat(style): give AnimatedStyledBox its own State with reduced motion" -- lib/src/components/common/style/animated_styled_box.dart test/src/components/common/style/animated_styled_box_test.dart
```

---

### Task 3 (M2-T3): `scrollBuilder` hook and the one clip

**Agent:** general-purpose
**Implements:** P3-4, D9, D11

**Files:**
- Modify: `lib/src/components/common/style/animated_styled_box.dart` (typedef at `:7`, constructor and fields from Task 2, `_buildBox` padding block at `:86-89`, the `_clip` call at `:107`, the head of `_clip` at `:187-198`)
- Test: `test/src/components/common/style/animated_styled_box_test.dart` (`_host` at `:14-31`, helpers at `:61`, new group above the boxBuilder group)

**Interfaces:**
- Consumes: the Task 2 `AnimatedStyledBox`.
- Produces: `typedef StyledScrollBuilder = Widget Function(Widget content);` and the parameter `StyledScrollBuilder? scrollBuilder` on `AnimatedStyledBox`, applied to the padded content (`Padding(padding)` around `Align`, `AspectRatio`, and the child) inside `ImageFiltered`, the clip, and the decorations. `_clip` clips with `Clip.antiAlias` when a `scrollBuilder` is present, the style has a `borderRadius`, and the style sets no `clipBehavior`. Task 5's `BoxLayout` passes its scroll view through this hook.

- [ ] **Step 1: Let the test host take a scroll builder**

In `test/src/components/common/style/animated_styled_box_test.dart`, replace `_host` with:

```dart
Widget _host(
  WidgetStyle? style, {
  Widget? child = const SizedBox(width: 40, height: 20),
  double? ratio,
  StyledBoxBuilder? boxBuilder,
  StyledScrollBuilder? scrollBuilder,
}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: AnimatedStyledBox(
        style: style,
        ratio: ratio,
        boxBuilder: boxBuilder,
        scrollBuilder: scrollBuilder,
        child: child,
      ),
    ),
  );
}
```

Below the line `Widget _probe(WidgetStyle style, Widget box) => _BoxProbe(child: box);`, add:

```dart

class _ScrollProbe extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

Widget _scroll(Widget content) => _ScrollProbe(child: content);
```

- [ ] **Step 2: Write the failing tests**

Insert this group above `  group('AnimatedStyledBox boxBuilder', () {`:

```dart
  group('AnimatedStyledBox scrollBuilder', () {
    testWidgets('wraps the padding inside the background', (tester) async {
      await tester.pumpWidget(
        _host(
          const WidgetStyle(
            backgroundColor: Color(0xFFFFFFFF),
            padding: EdgeInsets.all(8),
          ),
          scrollBuilder: _scroll,
        ),
      );

      final scroll = find.byType(_ScrollProbe);
      expect(find.ancestor(of: scroll, matching: _decorated()), findsOneWidget);
      expect(
        find.descendant(of: scroll, matching: find.byType(Padding)),
        findsOneWidget,
      );
    });

    testWidgets('a radius clips the scroll content once with antiAlias', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const WidgetStyle(
            backgroundColor: Color(0xFFFFFFFF),
            borderRadius: _radius,
          ),
          scrollBuilder: _scroll,
        ),
      );

      final clip = tester.widget<ClipRRect>(find.byType(ClipRRect));
      expect(clip.clipBehavior, Clip.antiAlias);
      expect(
        find.ancestor(
          of: find.byType(_ScrollProbe),
          matching: find.byType(ClipRRect),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a rounded, blurred box that scrolls clips once', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const WidgetStyle(
            backgroundColor: Color(0x80FFFFFF),
            borderRadius: _radius,
            backgroundBlur: _blur,
          ),
          scrollBuilder: _scroll,
        ),
      );

      expect(find.byType(ClipRRect), findsOneWidget);
      expect(find.byType(ClipRect), findsNothing);
    });

    testWidgets('an explicit Clip.none wins over the scroll clip', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const WidgetStyle(borderRadius: _radius, clipBehavior: Clip.none),
          scrollBuilder: _scroll,
        ),
      );

      expect(find.byType(ClipRRect), findsNothing);
    });

    testWidgets('(pin) a radius without scrollBuilder adds no clip', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const WidgetStyle(borderRadius: _radius)));

      expect(find.byType(ClipRRect), findsNothing);
    });

    testWidgets('foregroundBlur filters outside the scroll content', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const WidgetStyle(foregroundBlur: _blur), scrollBuilder: _scroll),
      );

      expect(
        find.ancestor(
          of: find.byType(_ScrollProbe),
          matching: find.byType(ImageFiltered),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the child keeps its State when scrollBuilder comes', (
      tester,
    ) async {
      await tester.pumpWidget(_host(null, child: const _Probe()));
      final before = tester.state(find.byType(_Probe));

      await tester.pumpWidget(
        _host(null, child: const _Probe(), scrollBuilder: _scroll),
      );

      expect(tester.state(find.byType(_Probe)), same(before));
    });
  });
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `flutter test --no-pub test/src/components/common/style/animated_styled_box_test.dart`
Expected: FAIL to compile with "Type 'StyledScrollBuilder' not found" and "No named parameter with the name 'scrollBuilder'".

- [ ] **Step 4: Add the hook**

In `lib/src/components/common/style/animated_styled_box.dart`:

Below the `StyledBoxBuilder` typedef, add:

```dart

/// Puts the padded content of an [AnimatedStyledBox] into a scroll view;
/// see [AnimatedStyledBox.scrollBuilder].
typedef StyledScrollBuilder = Widget Function(Widget content);
```

In the constructor, replace `    this.boxBuilder,\n    this.child,` with:

```dart
    this.boxBuilder,
    this.scrollBuilder,
    this.child,
```

Below the field `  final StyledBoxBuilder? boxBuilder;`, add:

```dart

  /// Wraps the padded content in a scroll view inside the box.
  ///
  /// Fill, border, radius, shadow, and blur stay in place while the padding
  /// and the child scroll. With a border radius and no `clipBehavior` in the
  /// style, the box clips the viewport to its corners with
  /// [Clip.antiAlias].
  final StyledScrollBuilder? scrollBuilder;
```

In `_buildBox`, between the padding block and `    final foregroundBlur = style.foregroundBlur;`, add:

```dart
    final scrollBuilder = widget.scrollBuilder;
    if (scrollBuilder != null) current = scrollBuilder(current);
```

Replace the line `    current = _clip(style, hasBlur: blur != null, child: current);` with:

```dart
    current = _clip(
      style,
      hasBlur: blur != null,
      scrolls: scrollBuilder != null,
      child: current,
    );
```

Replace the head of `_clip`, from its doc comment down to and including `    final radius = style.borderRadius;`, with:

```dart
  /// The one clip of the box: when a blur is set, when
  /// [WidgetStyle.clipBehavior] asks for it, or when a rounded box scrolls.
  ///
  /// A blur is always clipped, because an unclipped `BackdropFilter` blurs
  /// everything up to the nearest ancestor clip. A rounded scrolling box
  /// clips with [Clip.antiAlias], which adds no save layer; the scroll view
  /// keeps its own rectangular clip inside it.
  static Widget _clip(
    WidgetStyle style, {
    required bool hasBlur,
    required bool scrolls,
    required Widget child,
  }) {
    final radius = style.borderRadius;
    final requested =
        style.clipBehavior ??
        (scrolls && radius != null ? Clip.antiAlias : Clip.none);
    if (!hasBlur && requested == Clip.none) return child;
```

The rest of `_clip` (`final behavior = …` onward) stays.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test --no-pub test/src/components/common/`
Expected: `All tests passed!`

Run: `flutter analyze --no-pub lib/src/components/common/style/animated_styled_box.dart test/src/components/common/style/animated_styled_box_test.dart`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add -- lib/src/components/common/style/animated_styled_box.dart test/src/components/common/style/animated_styled_box_test.dart
git commit -m "feat(style): add the scrollBuilder hook and one clip to AnimatedStyledBox" -- lib/src/components/common/style/animated_styled_box.dart test/src/components/common/style/animated_styled_box_test.dart
```

---

### Task 4 (M2-T4): Lazy animation controller (only when Task 1 recorded S2-box more than 10.00% above S2-plain)

**Agent:** general-purpose
**Implements:** P3-7

Run this task only when the ledger line from Task 1 Step 9 reads `Task 4 runs`. Otherwise tick every step as skipped and write `Task 4: skipped (Δ avg % = <value>)` in the ledger.

**Files:**
- Modify: `lib/src/components/common/style/animated_styled_box.dart` (the controller members of `_AnimatedStyledBoxState` from Task 2, and `build`)
- Test: `test/src/components/common/style/animated_styled_box_test.dart` (imports at `:1`, new group above the reduced-motion group)

**Interfaces:**
- Consumes: the Task 3 `AnimatedStyledBox`.
- Produces: no API change. The state creates its `AnimationController` (still `AnimationBehavior.preserve`) on the first change whose style has a non-zero duration; until then it reads progress from `kAlwaysCompleteAnimation`, so `build` shows the target style.

- [ ] **Step 1: Write the failing tests**

In `test/src/components/common/style/animated_styled_box_test.dart`, add `import 'package:flutter/foundation.dart';` above `import 'package:flutter/widgets.dart';`, and insert this group above `  group('AnimatedStyledBox reduced motion', () {`:

```dart
  group('AnimatedStyledBox controller', () {
    late int created;

    void count(ObjectEvent event) {
      if (event is ObjectCreated && event.object is AnimationController) {
        created++;
      }
    }

    setUp(() {
      created = 0;
      FlutterMemoryAllocations.instance.addListener(count);
    });

    tearDown(() => FlutterMemoryAllocations.instance.removeListener(count));

    testWidgets('a style without animation creates no controller', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const WidgetStyle(backgroundColor: _red)));
      await tester.pumpWidget(_host(const WidgetStyle(backgroundColor: _blue)));

      expect(_fillColor(tester), _blue);
      expect(created, 0);
    });

    testWidgets('the first animated change creates one controller', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const WidgetStyle(backgroundColor: _red)));
      await tester.pumpWidget(
        _host(const WidgetStyle(backgroundColor: _blue, animationStyle: _slow)),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(created, 1);
      expect(_fillColor(tester), isNot(_blue));
      await tester.pumpAndSettle();
      expect(_fillColor(tester), _blue);
    });
  });
```

`FlutterMemoryAllocations` reports every `AnimationController` the framework creates in debug mode, so the count observes the controller without exposing private state.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test --no-pub test/src/components/common/style/animated_styled_box_test.dart`
Expected: 1 failure, "a style without animation creates no controller": Expected `<0>`, Actual `<1>`.

- [ ] **Step 3: Create the controller on the first animated change**

In `_AnimatedStyledBoxState`, replace everything from `  late final AnimationController _controller = AnimationController(` down to, not including, `  void _handleTick() => setState(() {});` with:

```dart
  // Created on the first animated change, so a box whose style never
  // animates builds no controller and no ticker.
  AnimationController? _controller;
  CurvedAnimation? _animation;
  late final _WidgetStyleTween _style = _WidgetStyleTween(
    begin: _target,
    end: _target,
  );

  WidgetStyle get _target => widget.style ?? const WidgetStyle();

  Duration get _duration =>
      widget.style?.animationStyle?.duration ?? Duration.zero;

  Curve get _curve => widget.style?.animationStyle?.curve ?? _defaultCurve;

  static const Curve _defaultCurve = Curves.easeInOutSine;

  /// The animation progress; complete while no controller exists.
  Animation<double> get _progress => _animation ?? kAlwaysCompleteAnimation;

  @override
  void didUpdateWidget(AnimatedStyledBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    final controller = _controller;
    if (controller != null) {
      final oldCurve = oldWidget.style?.animationStyle?.curve ?? _defaultCurve;
      if (_curve != oldCurve) {
        _animation?.dispose();
        _animation = CurvedAnimation(parent: controller, curve: _curve);
      }
      controller.duration = _duration;
    }
    final target = _target;
    if (target == _style.end) return;
    var begin = _style.evaluate(_progress);
    if (_reducesMotion) begin = _jumpGeometry(begin, to: target);
    _style
      ..begin = begin
      ..end = target;
    if (controller == null && _duration == Duration.zero) return;
    (controller ?? _createController()).forward(from: 0);
  }

  AnimationController _createController() {
    final controller =
        AnimationController(
            duration: _duration,
            animationBehavior: AnimationBehavior.preserve,
            vsync: this,
          )
          ..addListener(_handleTick)
          ..addStatusListener(_handleStatus);
    _controller = controller;
    _animation = CurvedAnimation(parent: controller, curve: _curve);
    return controller;
  }

  @override
  void dispose() {
    _animation?.dispose();
    _controller?.dispose();
    super.dispose();
  }
```

and replace the `build` method with:

```dart
  @override
  Widget build(BuildContext context) => _buildBox(_style.evaluate(_progress));
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test --no-pub test/src/components/common/`
Expected: `All tests passed!`

Run: `flutter analyze --no-pub lib/src/components/common/style/animated_styled_box.dart test/src/components/common/style/animated_styled_box_test.dart`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add -- lib/src/components/common/style/animated_styled_box.dart test/src/components/common/style/animated_styled_box_test.dart
git commit -m "perf(style): create the AnimatedStyledBox controller on the first animation" -- lib/src/components/common/style/animated_styled_box.dart test/src/components/common/style/animated_styled_box_test.dart
```

---

### Task 5 (M2-T5): `StratumInteraction` and `BoxLayout`

**Agent:** general-purpose
**Implements:** P3-1, P3-3, P3-4, D7, D10, D12, D13

**Files:**
- Create: `lib/src/components/common/interaction.dart`
- Create: `lib/src/components/common/layout/box_layout.dart`
- Modify: `lib/src/components/common/common.dart:3` (export), `lib/src/components/common/layout/layout.dart:1` (export)
- Test: `test/src/components/common/layout/box_layout_test.dart` (new)

**Interfaces:**
- Consumes: `AnimatedStyledBox` with `boxBuilder` and `scrollBuilder` (Tasks 2 and 3); `ScrollFrame({bool? showScrollbar, required Widget child})` from `layout/scroll_frame.dart` (phase 1); `StratumInkWell` (`ink_well.dart`, unchanged); `WidgetPerformanceMonitor`; `FocusType` (`themes/constant/focus_type.dart`).
- Produces:
  - `class StratumInteraction` with `const new({GestureTapCallback? onTap, GestureTapCallback? onDoubleTap, GestureLongPressCallback? onLongPress, GestureTapCallback? onSecondaryTap, ValueChanged<bool>? onHover, ValueChanged<bool>? onHighlightChanged, MouseCursor? mouseCursor, bool enableFeedback = true, bool disabledPressAnimation = false, FocusNode? focusNode, FocusType focusType = FocusType.focusedVisible, bool showFocusOnPrimary = true, bool canRequestFocus = true, bool autofocus = false, ValueChanged<bool>? onFocusChange, bool disabled = false, WidgetStatesController? statesController, bool excludeFromSemantics = false})`.
  - `abstract class BoxLayout extends StatelessWidget` with `const new({Key? key, WidgetStyle? style, double? ratio, double? rotate, Matrix4? transform, AlignmentGeometry? transformAlignment, bool keepAlive = false, bool repaintBoundary = false, bool debug = false, SemanticsProperties? semantics, VoidCallback? onEndAnimate, StratumInteraction? interaction, bool scrollable = false})`; `@nonVirtual Widget build(BuildContext)`; `@protected Widget buildContent(BuildContext)`; `@protected Axis get scrollDirection` (default `Axis.vertical`). Subclasses forward the base parameters as `super.<name>`.
  - Private to the file: `_isBare`, `_effectiveStyle` (adds the 100 ms `AnimationStyle` when `interaction` is set and the style has none), `_boxBuilder` (tap surface, else semantics, else null), `_buildScroll(Widget content)` (Task 6 replaces it), `_KeepAlive`.

- [ ] **Step 1: Write the failing test**

Create `test/src/components/common/layout/box_layout_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import '../fakes/fake_stratum_theme.dart';

const _content = SizedBox(width: 40, height: 20);

void _noop() {}

/// The smallest [BoxLayout]: its content is a fixed box.
class _Layout extends BoxLayout {
  const new({
    super.style,
    super.ratio,
    super.rotate,
    super.transform,
    super.keepAlive,
    super.repaintBoundary,
    super.debug,
    super.semantics,
    super.onEndAnimate,
    super.interaction,
    super.scrollable,
    this.axis = Axis.vertical,
  });

  final Axis axis;

  @override
  Axis get scrollDirection => axis;

  @override
  Widget buildContent(BuildContext context) => _content;
}

Finder _inLayout(Finder matching) {
  return find.descendant(of: find.byType(_Layout), matching: matching);
}

void main() {
  group('BoxLayout bare tier', () {
    testWidgets('builds no AnimatedStyledBox and no StatefulElement', (
      tester,
    ) async {
      await tester.pumpWidget(themedHost(const _Layout()));

      expect(find.byType(AnimatedStyledBox), findsNothing);
      expect(
        _inLayout(find.byElementPredicate((e) => e is StatefulElement)),
        findsNothing,
      );
      expect(tester.getSize(find.byType(_Layout)), const Size(40, 20));
    });

    testWidgets('semantics, repaintBoundary, debug, and keepAlive stay bare', (
      tester,
    ) async {
      await tester.pumpWidget(
        themedHost(
          const _Layout(
            semantics: SemanticsProperties(label: 'box'),
            repaintBoundary: true,
            debug: true,
            keepAlive: true,
          ),
        ),
      );

      expect(find.byType(AnimatedStyledBox), findsNothing);
      expect(_inLayout(find.byType(RepaintBoundary)), findsOneWidget);
      expect(_inLayout(find.byType(WidgetPerformanceMonitor)), findsOneWidget);
      expect(find.bySemanticsLabel('box'), findsOneWidget);
    });
  });

  group('BoxLayout box tier', () {
    final rules = <String, _Layout>{
      'style': const _Layout(style: WidgetStyle()),
      'ratio': const _Layout(ratio: 2),
      'rotate': const _Layout(rotate: 0),
      'transform': _Layout(transform: Matrix4.identity()),
      'interaction': const _Layout(interaction: StratumInteraction()),
      'scrollable': const _Layout(scrollable: true),
    };
    for (final MapEntry(key: name, value: layout) in rules.entries) {
      testWidgets('$name alone builds the box', (tester) async {
        await tester.pumpWidget(themedHost(layout));

        expect(find.byType(AnimatedStyledBox), findsOneWidget);
      });
    }

    testWidgets('wraps from outside in: keepAlive, debug, repaint, rotate', (
      tester,
    ) async {
      await tester.pumpWidget(
        themedHost(
          const _Layout(
            style: WidgetStyle(),
            rotate: 90,
            repaintBoundary: true,
            debug: true,
            keepAlive: true,
          ),
        ),
      );

      final box = find.byType(AnimatedStyledBox);
      final rotate = find.ancestor(of: box, matching: find.byType(Transform));
      final repaint = _inLayout(find.byType(RepaintBoundary));
      final monitor = _inLayout(find.byType(WidgetPerformanceMonitor));
      expect(rotate, findsOneWidget);
      expect(repaint, findsOneWidget);
      expect(find.ancestor(of: rotate, matching: repaint), findsOneWidget);
      expect(find.ancestor(of: repaint, matching: monitor), findsOneWidget);
    });

    testWidgets('the semantic rect equals the box and excludes the margin', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        themedHost(
          const _Layout(
            style: WidgetStyle(
              width: 40,
              height: 20,
              margin: EdgeInsets.all(8),
            ),
            semantics: SemanticsProperties(label: 'box'),
          ),
        ),
      );

      expect(tester.getSize(find.byType(_Layout)), const Size(56, 36));
      final node = tester.getSemantics(find.bySemanticsLabel('box'));
      expect(node.rect.size, const Size(40, 20));
      handle.dispose();
    });

    testWidgets('an interaction without callbacks adds no tap surface', (
      tester,
    ) async {
      await tester.pumpWidget(
        themedHost(const _Layout(interaction: StratumInteraction())),
      );

      expect(find.byType(StratumInkWell), findsNothing);
    });

    final surfaces = <String, StratumInteraction>{
      'onTap': const StratumInteraction(onTap: _noop),
      'onDoubleTap': const StratumInteraction(onDoubleTap: _noop),
      'onLongPress': const StratumInteraction(onLongPress: _noop),
      'onSecondaryTap': const StratumInteraction(onSecondaryTap: _noop),
      'onHover': StratumInteraction(onHover: (_) {}),
      'onHighlightChanged': StratumInteraction(onHighlightChanged: (_) {}),
      'onFocusChange': StratumInteraction(onFocusChange: (_) {}),
    };
    for (final MapEntry(key: name, value: interaction) in surfaces.entries) {
      testWidgets('$name builds the tap surface', (tester) async {
        await tester.pumpWidget(themedHost(_Layout(interaction: interaction)));

        expect(find.byType(StratumInkWell), findsOneWidget);
      });
    }

    testWidgets('hands every interaction field to the tap surface', (
      tester,
    ) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      final states = WidgetStatesController();
      addTearDown(states.dispose);
      void hover(bool value) {}
      void highlight(bool value) {}
      void focus(bool value) {}
      void doubleTap() {}
      void longPress() {}
      void secondaryTap() {}
      const label = SemanticsProperties(label: 'box');
      await tester.pumpWidget(
        themedHost(
          _Layout(
            style: const WidgetStyle(
              borderRadius: BorderRadius.all(Radius.circular(6)),
            ),
            semantics: label,
            interaction: StratumInteraction(
              onTap: _noop,
              onDoubleTap: doubleTap,
              onLongPress: longPress,
              onSecondaryTap: secondaryTap,
              onHover: hover,
              onHighlightChanged: highlight,
              mouseCursor: SystemMouseCursors.grab,
              enableFeedback: false,
              disabledPressAnimation: true,
              focusNode: node,
              focusType: FocusType.focused,
              showFocusOnPrimary: false,
              canRequestFocus: false,
              autofocus: true,
              onFocusChange: focus,
              disabled: true,
              statesController: states,
              excludeFromSemantics: true,
            ),
          ),
        ),
      );

      final ink = tester.widget<StratumInkWell>(find.byType(StratumInkWell));
      expect(ink.onTap, _noop);
      expect(ink.onDoubleTap, doubleTap);
      expect(ink.onLongPress, longPress);
      expect(ink.onSecondaryTap, secondaryTap);
      expect(ink.onHover, hover);
      expect(ink.onHighlightChanged, highlight);
      expect(ink.mouseCursor, SystemMouseCursors.grab);
      expect(ink.enableFeedback, isFalse);
      expect(ink.disabledPressAnimation, isTrue);
      expect(ink.focusNode, same(node));
      expect(ink.focusType, FocusType.focused);
      expect(ink.showFocusOnPrimary, isFalse);
      expect(ink.canRequestFocus, isFalse);
      expect(ink.autofocus, isTrue);
      expect(ink.onFocusChange, focus);
      expect(ink.disabled, isTrue);
      expect(ink.statesController, same(states));
      expect(ink.excludeFromSemantics, isTrue);
      expect(ink.semantics, same(label));
      expect(ink.borderRadius, const BorderRadius.all(Radius.circular(6)));
    });

    testWidgets('an interaction animates a style over 100 ms by default', (
      tester,
    ) async {
      await tester.pumpWidget(
        themedHost(
          const _Layout(
            style: WidgetStyle(width: 40),
            interaction: StratumInteraction(),
          ),
        ),
      );

      final box = tester.widget<AnimatedStyledBox>(
        find.byType(AnimatedStyledBox),
      );
      expect(
        box.style?.animationStyle?.duration,
        const Duration(milliseconds: 100),
      );
    });

    testWidgets("an interaction keeps the style's own animation", (
      tester,
    ) async {
      const own = AnimationStyle(duration: Duration(milliseconds: 300));
      await tester.pumpWidget(
        themedHost(
          const _Layout(
            style: WidgetStyle(animationStyle: own),
            interaction: StratumInteraction(),
          ),
        ),
      );

      final box = tester.widget<AnimatedStyledBox>(
        find.byType(AnimatedStyledBox),
      );
      expect(box.style?.animationStyle, own);
    });

    testWidgets('onEndAnimate fires once under the 100 ms default', (
      tester,
    ) async {
      var ends = 0;
      Widget build(Color color) => themedHost(
        _Layout(
          style: WidgetStyle(backgroundColor: color),
          interaction: const StratumInteraction(),
          onEndAnimate: () => ends++,
        ),
      );

      await tester.pumpWidget(build(const Color(0xFFFF0000)));
      await tester.pumpWidget(build(const Color(0xFF0000FF)));
      await tester.pumpAndSettle();

      expect(ends, 1);
    });

    testWidgets('onEndAnimate reaches only an animated style', (tester) async {
      await tester.pumpWidget(
        themedHost(const _Layout(style: WidgetStyle(), onEndAnimate: _noop)),
      );
      expect(
        tester.widget<AnimatedStyledBox>(find.byType(AnimatedStyledBox)).onEnd,
        isNull,
      );

      await tester.pumpWidget(
        themedHost(
          const _Layout(
            style: WidgetStyle(
              animationStyle: AnimationStyle(
                duration: Duration(milliseconds: 100),
              ),
            ),
            onEndAnimate: _noop,
          ),
        ),
      );
      expect(
        tester.widget<AnimatedStyledBox>(find.byType(AnimatedStyledBox)).onEnd,
        _noop,
      );
    });
  });

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

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test --no-pub test/src/components/common/layout/box_layout_test.dart`
Expected: FAIL to compile with "Type 'BoxLayout' not found" and "Method not found: 'StratumInteraction'".

- [ ] **Step 3: Add `StratumInteraction`**

Create `lib/src/components/common/interaction.dart`:

```dart
import 'package:stratum_ui/src/src.dart';

/// The pointer, focus, and semantics settings of a layout's tap surface.
///
/// A layout passes these to [StratumInkWell], one field to one parameter.
/// It builds the tap surface only when at least one of [onTap],
/// [onDoubleTap], [onLongPress], [onSecondaryTap], [onHover],
/// [onHighlightChanged], or [onFocusChange] is set. A value with none of
/// them still animates the layout's style over 100 ms and adds no tap
/// surface, so pass `const StratumInteraction()` when callbacks come and go:
/// switching `interaction` between null and a value remounts the content.
///
/// The class does not override `==`: callbacks compare by identity.
@immutable
class StratumInteraction {
  const new({
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.onSecondaryTap,
    this.onHover,
    this.onHighlightChanged,
    this.mouseCursor,
    this.enableFeedback = true,
    this.disabledPressAnimation = false,
    this.focusNode,
    this.focusType = FocusType.focusedVisible,
    this.showFocusOnPrimary = true,
    this.canRequestFocus = true,
    this.autofocus = false,
    this.onFocusChange,
    this.disabled = false,
    this.statesController,
    this.excludeFromSemantics = false,
  });

  final GestureTapCallback? onTap;

  /// Has no keyboard or screen-reader path; never make a function
  /// reachable only by double tap (WCAG 2.1.1).
  final GestureTapCallback? onDoubleTap;
  final GestureLongPressCallback? onLongPress;
  final GestureTapCallback? onSecondaryTap;
  final ValueChanged<bool>? onHover;
  final ValueChanged<bool>? onHighlightChanged;
  final MouseCursor? mouseCursor;
  final bool enableFeedback;
  final bool disabledPressAnimation;
  final FocusNode? focusNode;
  final FocusType focusType;
  final bool showFocusOnPrimary;
  final bool canRequestFocus;
  final bool autofocus;
  final ValueChanged<bool>? onFocusChange;

  /// Turns off every callback; the layout then reads as a dimmed button.
  final bool disabled;
  final WidgetStatesController? statesController;
  final bool excludeFromSemantics;
}
```

In `lib/src/components/common/common.dart`, add `export 'interaction.dart';` below `export 'ink_well.dart';`.

- [ ] **Step 4: Add `BoxLayout`**

Create `lib/src/components/common/layout/box_layout.dart`:

```dart
import 'dart:math' as math;

import 'package:stratum_ui/src/components/common/layout/scroll_frame.dart';
import 'package:stratum_ui/src/src.dart';

/// The base of the box layouts: one build pipeline for style, transforms,
/// interaction, semantics, and scrolling.
///
/// A subclass declares its own parameters and overrides [buildContent].
/// When [style], [ratio], [rotate], [transform], and [interaction] are null
/// and [scrollable] is false, the layout builds the bare tier: the content
/// with only the [semantics], [repaintBoundary], [debug], and [keepAlive]
/// wrappers, and no [AnimatedStyledBox]. Otherwise it builds the box tier
/// around an [AnimatedStyledBox].
///
/// The tier depends on whether a parameter is null, never on its content.
/// Switching a parameter between null and a value remounts the content, so
/// pass `const WidgetStyle()` or `const StratumInteraction()` up front when a
/// value can appear later.
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
    this.scrollable = false,
  });

  /// Every visual value of the box: spacing, size, fill, border, shadows,
  /// blur, opacity, and animation.
  final WidgetStyle? style;

  /// Width divided by height for the content; ignored unless greater
  /// than 0.
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
  /// [scrollDirection], while fill, border, radius, and shadow stay in
  /// place.
  final bool scrollable;

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

  /// The axis that [scrollable] scrolls along.
  @protected
  Axis get scrollDirection => Axis.vertical;

  bool get _isBare =>
      style == null &&
      ratio == null &&
      rotate == null &&
      transform == null &&
      interaction == null &&
      !scrollable;

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
    Widget current = AnimatedStyledBox(
      style: style,
      ratio: aspect != null && aspect > 0 ? aspect : null,
      transform: transform,
      transformAlignment: transformAlignment,
      onEnd: duration > Duration.zero ? onEndAnimate : null,
      boxBuilder: _boxBuilder,
      scrollBuilder: scrollable ? _buildScroll : null,
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

  /// Scrolls [content], the padding and the layout's content, inside the
  /// box along [scrollDirection].
  Widget _buildScroll(Widget content) {
    return ScrollFrame(
      child: SingleChildScrollView(
        scrollDirection: scrollDirection,
        child: content,
      ),
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

In `lib/src/components/common/layout/layout.dart`, add `export 'box_layout.dart';` as the first line.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test --no-pub test/src/components/common/`
Expected: `All tests passed!`

Run: `flutter analyze --no-pub lib/src/components/common/interaction.dart lib/src/components/common/layout/box_layout.dart test/src/components/common/layout/box_layout_test.dart`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add -- lib/src/components/common/interaction.dart lib/src/components/common/common.dart lib/src/components/common/layout/box_layout.dart lib/src/components/common/layout/layout.dart test/src/components/common/layout/box_layout_test.dart
git commit -m "feat(layout): add BoxLayout and StratumInteraction" -- lib/src/components/common/interaction.dart lib/src/components/common/common.dart lib/src/components/common/layout/box_layout.dart lib/src/components/common/layout/layout.dart test/src/components/common/layout/box_layout_test.dart
```

---

### Task 6 (M2-T6): `ColumnLayout` and `RowLayout` on `BoxLayout`, with the viewport stretch

**Agent:** general-purpose
**Implements:** P3-2, P3-4, D7, D8, D9, D11, D12, D17

**Files:**
- Modify (rewrite): `lib/src/components/common/layout/column_layout.dart:1-141`, `lib/src/components/common/layout/row_layout.dart:1-119`
- Modify: `lib/src/components/common/layout/box_layout.dart` (`_buildScroll` from Task 5)
- Test (rewrite): `test/src/components/common/layout/column_layout_test.dart:1-105`, `test/src/components/common/layout/row_layout_test.dart:1-62`

**Interfaces:**
- Consumes: `BoxLayout` (Task 5), `StratumInteraction`.
- Produces: `ColumnLayout` and `RowLayout`, each `const new({Key? key, <BoxLayout parameters as super.>, MainAxisAlignment mainAxisAlignment = MainAxisAlignment.start, MainAxisSize mainAxisSize = MainAxisSize.max, CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center, TextDirection? textDirection, VerticalDirection verticalDirection = VerticalDirection.down, TextBaseline? textBaseline, bool crossAxisIntrinsic = false, double? gap, required List<Widget> children})`. `RowLayout.scrollDirection` is `Axis.horizontal`. `BoxLayout._buildScroll` now stretches short content to a finite viewport. The example harness's calls (`ColumnLayout(mainAxisSize:, crossAxisAlignment:, children:)`, `RowLayout(style:, mainAxisAlignment:, children:)`) keep compiling.

- [ ] **Step 1: Write the failing tests**

Replace `test/src/components/common/layout/column_layout_test.dart` with:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

const _radius = BorderRadius.all(Radius.circular(8));
const _a = ValueKey<String>('a');
const _b = ValueKey<String>('b');

Widget _host(Widget child) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Center(child: child),
  );
}

/// Gives [child] a bounded viewport of [size].
Widget _sized(Size size, Widget child) {
  return _host(SizedBox.fromSize(size: size, child: child));
}

Finder _decoration() {
  return find.byWidgetPredicate(
    (widget) => widget is DecoratedBox && widget.decoration is StyleDecoration,
  );
}

void main() {
  group('ColumnLayout', () {
    testWidgets('passes its style to AnimatedStyledBox', (tester) async {
      const style = WidgetStyle(padding: EdgeInsets.all(8));
      await tester.pumpWidget(
        _host(
          const ColumnLayout(style: style, children: [SizedBox(height: 20)]),
        ),
      );

      final box = tester.widget<AnimatedStyledBox>(
        find.byType(AnimatedStyledBox),
      );
      expect(box.style, style);
    });

    testWidgets('builds no AnimatedStyledBox without box values', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const ColumnLayout(children: [SizedBox(height: 20)])),
      );

      expect(find.byType(AnimatedStyledBox), findsNothing);
      expect(find.byType(Column), findsOneWidget);
    });

    testWidgets('a height in the style makes the column fill it', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const ColumnLayout(
            style: WidgetStyle(height: 200),
            mainAxisSize: MainAxisSize.min,
            children: [SizedBox(height: 20)],
          ),
        ),
      );

      final column = tester.widget<Column>(find.byType(Column));
      expect(column.mainAxisSize, MainAxisSize.max);
    });

    testWidgets('crossAxisIntrinsic applies only without a style width', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const ColumnLayout(
            crossAxisIntrinsic: true,
            children: [SizedBox(height: 20)],
          ),
        ),
      );
      expect(find.byType(IntrinsicWidth), findsOneWidget);

      await tester.pumpWidget(
        _host(
          const ColumnLayout(
            crossAxisIntrinsic: true,
            style: WidgetStyle(width: 100),
            children: [SizedBox(height: 20)],
          ),
        ),
      );
      expect(find.byType(IntrinsicWidth), findsNothing);
    });

    testWidgets('gap becomes Column.spacing, also with an interaction', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const ColumnLayout(
            gap: 8,
            interaction: StratumInteraction(),
            children: [SizedBox(height: 20), SizedBox(height: 20)],
          ),
        ),
      );

      final column = tester.widget<Column>(find.byType(Column));
      expect(column.spacing, 8);
      expect(column.children, hasLength(2));
    });

    testWidgets('forwards onEndAnimate', (tester) async {
      var ends = 0;
      Widget build(Color color) {
        return _host(
          ColumnLayout(
            style: WidgetStyle(
              backgroundColor: color,
              animationStyle: const AnimationStyle(
                duration: Duration(milliseconds: 100),
              ),
            ),
            onEndAnimate: () => ends++,
            children: const [SizedBox(height: 20)],
          ),
        );
      }

      await tester.pumpWidget(build(const Color(0xFFFF0000)));
      await tester.pumpWidget(build(const Color(0xFF0000FF)));
      await tester.pumpAndSettle();

      expect(ends, 1);
    });
  });

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

class _Probe extends StatefulWidget {
  const new();

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  Widget build(BuildContext context) => const SizedBox(width: 40, height: 20);
}
```

Replace `test/src/components/common/layout/row_layout_test.dart` with:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

const _a = ValueKey<String>('a');
const _b = ValueKey<String>('b');

Widget _host(Widget child) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Center(child: child),
  );
}

void main() {
  group('RowLayout', () {
    testWidgets('passes its style to AnimatedStyledBox', (tester) async {
      const style = WidgetStyle(padding: EdgeInsets.all(8));
      await tester.pumpWidget(
        _host(const RowLayout(style: style, children: [SizedBox(width: 20)])),
      );

      final box = tester.widget<AnimatedStyledBox>(
        find.byType(AnimatedStyledBox),
      );
      expect(box.style, style);
    });

    testWidgets('builds no AnimatedStyledBox without box values', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const RowLayout(children: [SizedBox(width: 20)])),
      );

      expect(find.byType(AnimatedStyledBox), findsNothing);
      expect(find.byType(Row), findsOneWidget);
    });

    testWidgets('a width in the style makes the row fill it', (tester) async {
      await tester.pumpWidget(
        _host(
          const RowLayout(
            style: WidgetStyle(width: 200),
            mainAxisSize: MainAxisSize.min,
            children: [SizedBox(width: 20)],
          ),
        ),
      );

      final row = tester.widget<Row>(find.byType(Row));
      expect(row.mainAxisSize, MainAxisSize.max);
    });

    testWidgets('crossAxisIntrinsic applies only without a style height', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const RowLayout(
            crossAxisIntrinsic: true,
            children: [SizedBox(width: 20)],
          ),
        ),
      );
      expect(find.byType(IntrinsicHeight), findsOneWidget);

      await tester.pumpWidget(
        _host(
          const RowLayout(
            crossAxisIntrinsic: true,
            style: WidgetStyle(height: 100),
            children: [SizedBox(width: 20)],
          ),
        ),
      );
      expect(find.byType(IntrinsicHeight), findsNothing);
    });

    testWidgets('gap becomes Row.spacing, also with an interaction', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const RowLayout(
            gap: 8,
            interaction: StratumInteraction(),
            children: [SizedBox(width: 20), SizedBox(width: 20)],
          ),
        ),
      );

      final row = tester.widget<Row>(find.byType(Row));
      expect(row.spacing, 8);
      expect(row.children, hasLength(2));
    });
  });

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

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test --no-pub test/src/components/common/layout/column_layout_test.dart test/src/components/common/layout/row_layout_test.dart`
Expected: FAIL to compile with "No named parameter with the name 'interaction'" in both files.

- [ ] **Step 3: Rewrite the column and the row**

Replace `lib/src/components/common/layout/column_layout.dart` with:

```dart
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
    super.scrollable,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.max,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.textDirection,
    this.verticalDirection = VerticalDirection.down,
    this.textBaseline,
    this.crossAxisIntrinsic = false,
    this.gap,
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
  final List<Widget> children;

  @override
  Widget buildContent(BuildContext context) {
    final style = this.style;
    final fills = style?.height != null || style?.maxHeight != null;
    final Widget column = Column(
      mainAxisAlignment: mainAxisAlignment,
      mainAxisSize: fills ? MainAxisSize.max : mainAxisSize,
      crossAxisAlignment: crossAxisAlignment,
      textDirection: textDirection,
      verticalDirection: verticalDirection,
      textBaseline: textBaseline,
      spacing: gap ?? 0,
      children: children,
    );
    if (!crossAxisIntrinsic || style?.width != null) return column;
    return IntrinsicWidth(child: column);
  }
}
```

Replace `lib/src/components/common/layout/row_layout.dart` with:

```dart
import 'package:stratum_ui/src/src.dart';

/// A [Row] on [BoxLayout]: style, interaction, semantics, and scrolling
/// come from the base class.
///
/// A width or max width in [style] forces [MainAxisSize.max], so the row
/// fills the width it is given. [gap] becomes [Row.spacing], and
/// `scrollable` scrolls horizontally.
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
    super.scrollable,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.max,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.textDirection,
    this.verticalDirection = VerticalDirection.down,
    this.textBaseline,
    this.crossAxisIntrinsic = false,
    this.gap,
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
  final List<Widget> children;

  @override
  Axis get scrollDirection => Axis.horizontal;

  @override
  Widget buildContent(BuildContext context) {
    final style = this.style;
    final fills = style?.width != null || style?.maxWidth != null;
    final Widget row = Row(
      mainAxisAlignment: mainAxisAlignment,
      mainAxisSize: fills ? MainAxisSize.max : mainAxisSize,
      crossAxisAlignment: crossAxisAlignment,
      textDirection: textDirection,
      verticalDirection: verticalDirection,
      textBaseline: textBaseline,
      spacing: gap ?? 0,
      children: children,
    );
    if (!crossAxisIntrinsic || style?.height != null) return row;
    return IntrinsicHeight(child: row);
  }
}
```

- [ ] **Step 4: Run the tests to see the stretch fail**

Run: `flutter test --no-pub test/src/components/common/layout/column_layout_test.dart test/src/components/common/layout/row_layout_test.dart`
Expected: 2 failures, "(pin) short content fills a bounded viewport" (column) and "short content fills a bounded viewport" (row): Expected `<290>`, Actual `<50.0>`. The old column stretched through a `LayoutBuilder` outside the box; `BoxLayout` does not stretch yet.

- [ ] **Step 5: Stretch short content to a finite viewport**

In `lib/src/components/common/layout/box_layout.dart`, replace the method `_buildScroll` and its doc comment with:

```dart
  /// Scrolls [content] (the padding and the layout's content) inside the
  /// box. Short content stretches to the viewport, so `spaceBetween` and
  /// `end` alignments still work; in a parent that is unbounded along the
  /// axis the layout sizes to its content instead.
  Widget _buildScroll(Widget content) {
    final axis = scrollDirection;
    return ScrollFrame(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final extent = axis == Axis.vertical
              ? constraints.maxHeight
              : constraints.maxWidth;
          final min = extent.isFinite ? extent : 0.0;
          return SingleChildScrollView(
            scrollDirection: axis,
            child: ConstrainedBox(
              constraints: axis == Axis.vertical
                  ? BoxConstraints(minHeight: min)
                  : BoxConstraints(minWidth: min),
              child: content,
            ),
          );
        },
      ),
    );
  }
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `flutter test --no-pub test/src/components/common/`
Expected: `All tests passed!`

Run: `flutter analyze --no-pub lib/src/components/common/layout/box_layout.dart lib/src/components/common/layout/column_layout.dart lib/src/components/common/layout/row_layout.dart test/src/components/common/layout/column_layout_test.dart test/src/components/common/layout/row_layout_test.dart`
Expected: `No issues found!`

Run: `cd example && flutter analyze --no-pub integration_test`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add -- lib/src/components/common/layout/box_layout.dart lib/src/components/common/layout/column_layout.dart lib/src/components/common/layout/row_layout.dart test/src/components/common/layout/column_layout_test.dart test/src/components/common/layout/row_layout_test.dart
git commit -m "feat(layout): move ColumnLayout and RowLayout onto BoxLayout" -- lib/src/components/common/layout/box_layout.dart lib/src/components/common/layout/column_layout.dart lib/src/components/common/layout/row_layout.dart test/src/components/common/layout/column_layout_test.dart test/src/components/common/layout/row_layout_test.dart
```

---

### Task 7 (M2-T7): `StackLayout` and `WrapLayout` on `BoxLayout`

**Agent:** general-purpose
**Implements:** P3-2, D1, D11, D12

**Files:**
- Modify (rewrite): `lib/src/components/common/layout/stack_layout.dart:1-100`, `lib/src/components/common/layout/wrap_layout.dart:1-123`
- Test (rewrite): `test/src/components/common/layout/stack_layout_test.dart:1-72`, `test/src/components/common/layout/wrap_layout_test.dart:1-57`

**Interfaces:**
- Consumes: `BoxLayout` (Task 5).
- Produces: `StackLayout` with `const new({Key? key, <BoxLayout parameters as super.>, AlignmentGeometry alignment = AlignmentDirectional.topStart, StackFit fit = StackFit.loose, TextDirection? textDirection, Clip clipBehavior = Clip.hardEdge, required List<Widget> children})`; `WrapLayout` with `const new({Key? key, <BoxLayout parameters as super.>, Axis direction = Axis.horizontal, WrapAlignment alignment = WrapAlignment.start, double? gap, double? runGap, WrapAlignment runAlignment = WrapAlignment.start, WrapCrossAlignment crossAxisAlignment = WrapCrossAlignment.start, TextDirection? textDirection, VerticalDirection verticalDirection = VerticalDirection.down, Clip clipBehavior = Clip.none, required List<Widget> children})`. `WrapLayout` drops `spacing` and `runSpacing`; `WrapLayout.scrollDirection` is `flipAxis(direction)`.

- [ ] **Step 1: Write the failing tests**

Replace `test/src/components/common/layout/stack_layout_test.dart` with:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

const _style = WidgetStyle(backgroundColor: Color(0xFFFFFFFF));

Widget _host(Widget child) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Center(child: child),
  );
}

void main() {
  group('StackLayout', () {
    testWidgets('builds no AnimatedStyledBox without box values', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const StackLayout(children: [SizedBox(width: 20, height: 20)])),
      );

      expect(find.byType(AnimatedStyledBox), findsNothing);
      expect(find.byType(Stack), findsOneWidget);
    });

    testWidgets('passes its style to AnimatedStyledBox', (tester) async {
      await tester.pumpWidget(
        _host(
          const StackLayout(
            style: _style,
            children: [SizedBox(width: 20, height: 20)],
          ),
        ),
      );

      final box = tester.widget<AnimatedStyledBox>(
        find.byType(AnimatedStyledBox),
      );
      expect(box.style, _style);
    });

    testWidgets('semantics alone add a node without a box', (tester) async {
      await tester.pumpWidget(
        _host(
          const StackLayout(
            semantics: SemanticsProperties(label: 'stack'),
            children: [SizedBox(width: 20, height: 20)],
          ),
        ),
      );

      expect(find.byType(AnimatedStyledBox), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.label == 'stack',
        ),
        findsOneWidget,
      );
    });

    testWidgets('keeps clipBehavior and alignment on the Stack', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const StackLayout(
            style: _style,
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [SizedBox(width: 20, height: 20)],
          ),
        ),
      );

      final stack = tester.widget<Stack>(find.byType(Stack));
      expect(stack.clipBehavior, Clip.none);
      expect(stack.alignment, Alignment.center);
      final box = tester.widget<AnimatedStyledBox>(
        find.byType(AnimatedStyledBox),
      );
      expect(box.style?.clipBehavior, isNull);
    });

    testWidgets('(pin) clips the Stack with Clip.hardEdge by default', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const StackLayout(children: [SizedBox(width: 20, height: 20)])),
      );

      expect(
        tester.widget<Stack>(find.byType(Stack)).clipBehavior,
        Clip.hardEdge,
      );
    });

    testWidgets('scrolls vertically inside the box', (tester) async {
      await tester.pumpWidget(
        _host(
          const SizedBox(
            width: 100,
            height: 100,
            child: StackLayout(
              scrollable: true,
              style: _style,
              children: [SizedBox(width: 20, height: 400)],
            ),
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
        Axis.vertical,
      );
    });
  });
}
```

Replace `test/src/components/common/layout/wrap_layout_test.dart` with:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

const _style = WidgetStyle(backgroundColor: Color(0xFFFFFFFF));
const _first = ValueKey<int>(0);
const _third = ValueKey<int>(2);

Widget _host(Widget child) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Center(child: child),
  );
}

List<Widget> _tiles() {
  return [
    for (var i = 0; i < 4; i++)
      SizedBox(key: ValueKey<int>(i), width: 40, height: 40),
  ];
}

void main() {
  group('WrapLayout', () {
    testWidgets('builds no AnimatedStyledBox without box values', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const WrapLayout(children: [SizedBox(width: 20, height: 20)])),
      );

      expect(find.byType(AnimatedStyledBox), findsNothing);
      expect(find.byType(Wrap), findsOneWidget);
    });

    testWidgets('passes its style to AnimatedStyledBox', (tester) async {
      await tester.pumpWidget(
        _host(
          const WrapLayout(
            style: _style,
            children: [SizedBox(width: 20, height: 20)],
          ),
        ),
      );

      final box = tester.widget<AnimatedStyledBox>(
        find.byType(AnimatedStyledBox),
      );
      expect(box.style, _style);
    });

    testWidgets('keeps clipBehavior and alignment on the Wrap', (tester) async {
      await tester.pumpWidget(
        _host(
          const WrapLayout(
            style: _style,
            clipBehavior: Clip.hardEdge,
            alignment: WrapAlignment.center,
            children: [SizedBox(width: 20, height: 20)],
          ),
        ),
      );

      final wrap = tester.widget<Wrap>(find.byType(Wrap));
      expect(wrap.clipBehavior, Clip.hardEdge);
      expect(wrap.alignment, WrapAlignment.center);
    });

    testWidgets('gap and runGap become spacing and runSpacing', (tester) async {
      await tester.pumpWidget(
        _host(WrapLayout(gap: 4, runGap: 12, children: _tiles())),
      );

      final wrap = tester.widget<Wrap>(find.byType(Wrap));
      expect(wrap.spacing, 4);
      expect(wrap.runSpacing, 12);
    });

    testWidgets('a null runGap falls back to gap', (tester) async {
      await tester.pumpWidget(_host(WrapLayout(gap: 6, children: _tiles())));

      expect(tester.widget<Wrap>(find.byType(Wrap)).runSpacing, 6);
    });
  });

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

- [ ] **Step 2: Run the tests to verify they fail**

Run the two files one at a time; when one file of a run fails to compile, the runner also reports "The Dart compiler exited unexpectedly" for the other.

Run: `flutter test --no-pub test/src/components/common/layout/wrap_layout_test.dart`
Expected: FAIL to compile with "No named parameter with the name 'runGap'".

Run: `flutter test --no-pub test/src/components/common/layout/stack_layout_test.dart`
Expected: 2 failures, "semantics alone add a node without a box" (the old stack wraps semantics in `ContainerLayout`, so an `AnimatedStyledBox` exists) and "scrolls vertically inside the box" (the old scroll view sits outside the box).

- [ ] **Step 3: Rewrite the stack and the wrap**

Replace `lib/src/components/common/layout/stack_layout.dart` with:

```dart
import 'package:stratum_ui/src/src.dart';

/// A [Stack] on [BoxLayout]: style, interaction, semantics, and scrolling
/// come from the base class.
///
/// [clipBehavior] clips the stack's own children; the box clips through
/// `style.clipBehavior`. `scrollable` scrolls vertically.
class StackLayout extends BoxLayout {
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
    super.scrollable,
    this.alignment = AlignmentDirectional.topStart,
    this.fit = StackFit.loose,
    this.textDirection,
    this.clipBehavior = Clip.hardEdge,
    required this.children,
  });

  final AlignmentGeometry alignment;
  final StackFit fit;
  final TextDirection? textDirection;
  final Clip clipBehavior;
  final List<Widget> children;

  @override
  Widget buildContent(BuildContext context) {
    return Stack(
      alignment: alignment,
      textDirection: textDirection,
      fit: fit,
      clipBehavior: clipBehavior,
      children: children,
    );
  }
}
```

Replace `lib/src/components/common/layout/wrap_layout.dart` with:

```dart
import 'package:stratum_ui/src/src.dart';

/// A [Wrap] on [BoxLayout]: style, interaction, semantics, and scrolling
/// come from the base class.
///
/// `scrollable` scrolls across [direction], so a horizontal wrap keeps its
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
    super.scrollable,
    this.direction = Axis.horizontal,
    this.alignment = WrapAlignment.start,
    this.gap,
    this.runGap,
    this.runAlignment = WrapAlignment.start,
    this.crossAxisAlignment = WrapCrossAlignment.start,
    this.textDirection,
    this.verticalDirection = VerticalDirection.down,
    this.clipBehavior = Clip.none,
    required this.children,
  });

  final Axis direction;
  final WrapAlignment alignment;

  /// Space between children in a run.
  final double? gap;

  /// Space between runs; null uses [gap].
  final double? runGap;
  final WrapAlignment runAlignment;
  final WrapCrossAlignment crossAxisAlignment;
  final TextDirection? textDirection;
  final VerticalDirection verticalDirection;
  final Clip clipBehavior;
  final List<Widget> children;

  @override
  Axis get scrollDirection => flipAxis(direction);

  @override
  Widget buildContent(BuildContext context) {
    final gap = this.gap ?? 0;
    return Wrap(
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
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test --no-pub test/src/components/common/`
Expected: `All tests passed!`

Run: `flutter analyze --no-pub lib/src/components/common/layout/stack_layout.dart lib/src/components/common/layout/wrap_layout.dart test/src/components/common/layout/stack_layout_test.dart test/src/components/common/layout/wrap_layout_test.dart`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add -- lib/src/components/common/layout/stack_layout.dart lib/src/components/common/layout/wrap_layout.dart test/src/components/common/layout/stack_layout_test.dart test/src/components/common/layout/wrap_layout_test.dart
git commit -m "feat(layout): move StackLayout and WrapLayout onto BoxLayout" -- lib/src/components/common/layout/stack_layout.dart lib/src/components/common/layout/wrap_layout.dart test/src/components/common/layout/stack_layout_test.dart test/src/components/common/layout/wrap_layout_test.dart
```

---

### Task 8 (M2-T8): `ContainerLayout` on `BoxLayout`; delete the gesture twins

**Agent:** general-purpose
**Implements:** P3-2, P3-5, D8, D10, D12, D13

**Files:**
- Modify (rewrite): `lib/src/components/common/layout/container_layout.dart:1-117`
- Modify: `lib/src/components/common/layout/layout.dart` (drop the `gesture_container_layout.dart` export)
- Delete: `lib/src/components/common/layout/gesture_column_layout.dart`, `gesture_container_layout.dart`, `gesture_row_layout.dart`, `gesture_stack_layout.dart`, `gesture_wrap_layout.dart`; `test/src/components/common/layout/gesture_layout_test.dart`
- Modify: `test/src/components/common/layout/container_layout_test.dart:47-63` (drop the `boxBuilder` case) and `:201` (two new cases above it)
- Create: `test/src/components/common/interaction_test.dart`
- Modify: `example/integration_test/layout_perf_test.dart:1-7` (imports) and `:122-130` (the S3 builder)

**Interfaces:**
- Consumes: `BoxLayout`, `StratumInteraction` (Task 5); `ColumnLayout`, `RowLayout` (Task 6); `StackLayout`, `WrapLayout` (Task 7); `themedHost` from `test/src/components/common/fakes/fake_stratum_theme.dart`.
- Produces: `ContainerLayout` with `const new({Key? key, <BoxLayout parameters as super.>, Widget? child})`, no `boxBuilder`; `layout/layout.dart` exports `box_layout.dart`, the five box layouts, and the three scroll views; the S3 scene builds `RowLayout(style: _cardStyle, interaction: StratumInteraction(onTap: () {}), …)`. After this commit no file under `lib/` declares a `Gesture*Layout` class.

- [ ] **Step 1: Port the gesture tests**

Create `test/src/components/common/interaction_test.dart` (the nine cases of `gesture_layout_test.dart` on `interaction:`, plus the callback toggle for every layout):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import 'fakes/fake_stratum_theme.dart';

const _child = SizedBox(width: 40, height: 20);

void _noop() {}

class _Probe extends StatefulWidget {
  const new();

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  Widget build(BuildContext context) => _child;
}

typedef _Build = Widget Function({
  required StratumInteraction interaction,
  WidgetStyle? style,
  Widget child,
});

/// Every box layout with `interaction`, `style`, and one `child`.
final _layouts = <String, _Build>{
  'ContainerLayout': ({required interaction, style, child = _child}) =>
      ContainerLayout(interaction: interaction, style: style, child: child),
  'ColumnLayout': ({required interaction, style, child = _child}) =>
      ColumnLayout(
        interaction: interaction,
        style: style,
        mainAxisSize: MainAxisSize.min,
        children: [child],
      ),
  'RowLayout': ({required interaction, style, child = _child}) => RowLayout(
    interaction: interaction,
    style: style,
    mainAxisSize: MainAxisSize.min,
    children: [child],
  ),
  'StackLayout': ({required interaction, style, child = _child}) =>
      StackLayout(interaction: interaction, style: style, children: [child]),
  'WrapLayout': ({required interaction, style, child = _child}) =>
      WrapLayout(interaction: interaction, style: style, children: [child]),
};

Finder _semantics(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is Semantics && widget.properties.label == label,
  );
}

void main() {
  group('ContainerLayout interaction', () {
    testWidgets('keeps semantics inside the box without callbacks', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        themedHost(
          const ContainerLayout(
            interaction: StratumInteraction(),
            semantics: SemanticsProperties(label: 'card'),
            child: _child,
          ),
        ),
      );

      expect(find.byType(StratumInkWell), findsNothing);
      expect(
        find.descendant(
          of: find.byType(AnimatedStyledBox),
          matching: _semantics('card'),
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('card'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('toggling onTap with semantics keeps the child State', (
      tester,
    ) async {
      Widget build(GestureTapCallback? onTap) => themedHost(
        ContainerLayout(
          semantics: const SemanticsProperties(label: 'card'),
          interaction: StratumInteraction(onTap: onTap),
          child: const _Probe(),
        ),
      );

      await tester.pumpWidget(build(null));
      final before = tester.state(find.byType(_Probe));
      await tester.pumpWidget(build(_noop));

      expect(tester.state(find.byType(_Probe)), same(before));
    });

    testWidgets('keeps the margin outside the ink well', (tester) async {
      await tester.pumpWidget(
        themedHost(
          const ContainerLayout(
            style: WidgetStyle(
              width: 40,
              height: 20,
              margin: EdgeInsets.all(8),
            ),
            interaction: StratumInteraction(onTap: _noop),
            child: SizedBox.expand(),
          ),
        ),
      );

      expect(tester.getSize(find.byType(StratumInkWell)), const Size(40, 20));
      expect(tester.getSize(find.byType(ContainerLayout)), const Size(56, 36));
    });

    testWidgets('puts the ink well under the rotation', (tester) async {
      await tester.pumpWidget(
        themedHost(
          const ContainerLayout(
            rotate: 45,
            interaction: StratumInteraction(onTap: _noop),
            child: _child,
          ),
        ),
      );

      expect(
        find.ancestor(
          of: find.byType(StratumInkWell),
          matching: find.byType(Transform),
        ),
        findsOneWidget,
      );
    });

    testWidgets('gives the style radius and semantics to the ink well', (
      tester,
    ) async {
      const radius = BorderRadius.all(Radius.circular(8));
      await tester.pumpWidget(
        themedHost(
          const ContainerLayout(
            style: WidgetStyle(borderRadius: radius),
            semantics: SemanticsProperties(label: 'card'),
            interaction: StratumInteraction(onTap: _noop),
            child: _child,
          ),
        ),
      );

      final inkWell = tester.widget<StratumInkWell>(
        find.byType(StratumInkWell),
      );
      expect(inkWell.borderRadius, radius);
      expect(inkWell.semantics?.label, 'card');
      expect(
        find.ancestor(
          of: find.byType(StratumInkWell),
          matching: _semantics('card'),
        ),
        findsNothing,
      );
    });
  });

  group('layout interaction', () {
    for (final MapEntry(key: name, value: build) in _layouts.entries) {
      testWidgets('$name forwards onSecondaryTap', (tester) async {
        var count = 0;
        await tester.pumpWidget(
          themedHost(
            build(
              interaction: StratumInteraction(onSecondaryTap: () => count++),
            ),
          ),
        );

        await tester.tap(
          find.byType(StratumInkWell),
          buttons: kSecondaryMouseButton,
          kind: PointerDeviceKind.mouse,
        );
        await tester.pumpAndSettle();

        expect(count, 1);
      });

      testWidgets('$name reads as a dimmed button when disabled', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          themedHost(
            build(
              interaction: const StratumInteraction(
                onTap: _noop,
                disabled: true,
              ),
            ),
          ),
        );

        expect(
          tester.getSemantics(find.byType(StratumInkWell)),
          isSemantics(
            isButton: true,
            hasEnabledState: true,
            isEnabled: false,
            hasTapAction: false,
          ),
        );
        handle.dispose();
      });

      testWidgets('$name keeps the child State as callbacks come and go', (
        tester,
      ) async {
        Widget host(GestureTapCallback? onTap) => themedHost(
          build(
            interaction: StratumInteraction(onTap: onTap),
            child: const _Probe(),
          ),
        );

        await tester.pumpWidget(host(null));
        final before = tester.state(find.byType(_Probe));
        await tester.pumpWidget(host(_noop));
        expect(find.byType(StratumInkWell), findsOneWidget);
        expect(tester.state(find.byType(_Probe)), same(before));

        await tester.pumpWidget(host(null));
        expect(find.byType(StratumInkWell), findsNothing);
        expect(tester.state(find.byType(_Probe)), same(before));
      });

      testWidgets('$name animates a style over 100 ms without callbacks', (
        tester,
      ) async {
        await tester.pumpWidget(
          themedHost(
            build(
              interaction: const StratumInteraction(),
              style: const WidgetStyle(width: 40, height: 20),
            ),
          ),
        );

        final box = tester.widget<AnimatedStyledBox>(
          find.byType(AnimatedStyledBox),
        );
        expect(
          box.style?.animationStyle?.duration,
          const Duration(milliseconds: 100),
        );
      });
    }
  });
}
```

Case map from `gesture_layout_test.dart`: the five `GestureContainerLayout` cases become the "ContainerLayout interaction" group; "forwards onSecondaryTap" and "reads as a dimmed button when disabled" run for all five layouts; the stack-and-wrap cases ("keeps the children State when onTap toggles", "animates a style over 100 ms without callbacks") now run for all five layouts, the first one extended to remove the last callback as well.

- [ ] **Step 2: Update the container test**

In `test/src/components/common/layout/container_layout_test.dart`, delete the case `testWidgets('hands boxBuilder to AnimatedStyledBox', …)` (the public `boxBuilder` is gone; `animated_styled_box_test.dart` still covers the hook). Insert above `    testWidgets('semantics, repaintBoundary, and debug add their wrappers',`:

```dart
    testWidgets('semantics sit inside the margin (D10)', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          const ContainerLayout(
            style: WidgetStyle(
              width: 40,
              height: 20,
              margin: EdgeInsets.all(8),
            ),
            semantics: SemanticsProperties(label: 'card'),
            child: SizedBox.expand(),
          ),
        ),
      );

      final node = tester.getSemantics(find.bySemanticsLabel('card'));
      expect(node.rect.size, const Size(40, 20));
      handle.dispose();
    });

    testWidgets('(pin) a null child builds an empty box', (tester) async {
      await tester.pumpWidget(_host(const ContainerLayout()));

      expect(tester.getSize(find.byType(ContainerLayout)), Size.zero);
    });
```

- [ ] **Step 3: Run the tests to verify they fail**

Run the two files one at a time, as in Task 7.

Run: `flutter test --no-pub test/src/components/common/interaction_test.dart`
Expected: FAIL to compile with "No named parameter with the name 'interaction'" (on `ContainerLayout`).

Run: `flutter test --no-pub test/src/components/common/layout/container_layout_test.dart`
Expected: 1 failure, "semantics sit inside the margin (D10)": Expected `Size(40.0, 20.0)`, Actual `Size(56.0, 36.0)`.

- [ ] **Step 4: Rewrite the container**

Replace `lib/src/components/common/layout/container_layout.dart` with:

```dart
import 'package:stratum_ui/src/src.dart';

/// A box that paints a [WidgetStyle] around [child].
///
/// Every visual value (spacing, size, fill, border, shadows, blur, opacity,
/// and animation) comes from `style`, which [AnimatedStyledBox] builds and
/// animates. The other parameters come from [BoxLayout] and cover what a
/// style cannot: per-instance layout, interaction, behavior, and
/// accessibility.
class ContainerLayout extends BoxLayout {
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
    super.scrollable,
    this.child,
  });

  final Widget? child;

  @override
  Widget buildContent(BuildContext context) {
    return child ?? const SizedBox.shrink();
  }
}
```

- [ ] **Step 5: Delete the gesture twins and update the barrel**

```bash
git rm -- lib/src/components/common/layout/gesture_column_layout.dart lib/src/components/common/layout/gesture_container_layout.dart lib/src/components/common/layout/gesture_row_layout.dart lib/src/components/common/layout/gesture_stack_layout.dart lib/src/components/common/layout/gesture_wrap_layout.dart test/src/components/common/layout/gesture_layout_test.dart
```

Replace `lib/src/components/common/layout/layout.dart` with:

```dart
export 'box_layout.dart';
export 'column_layout.dart';
export 'container_layout.dart';
export 'custom_scroll_view_layout.dart';
export 'grid_view_layout.dart';
export 'list_view_layout.dart';
export 'row_layout.dart';
export 'stack_layout.dart';
export 'wrap_layout.dart';
```

- [ ] **Step 6: Move the S3 scene to the new API**

In `example/integration_test/layout_perf_test.dart`, replace the first seven lines (the comment, the `ignore_for_file`, and the four imports) with:

```dart
// The harness imports the src barrel, which also exports the theme types
// the fake theme implements.
// ignore_for_file: implementation_imports
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stratum_ui/src/src.dart';
```

and replace `sceneTappableRow` with:

```dart
/// S3: S2 with a tap callback and the 100 ms default style animation.
Widget sceneTappableRow(int index) {
  return RowLayout(
    style: _cardStyle,
    interaction: StratumInteraction(onTap: () {}),
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: _rowChildren(index),
  );
}
```

No other scene builder changes: S1, S1-fast, S2, S2-box, S2-plain, S4, and S5 already call only `RowLayout`, `ColumnLayout`, and `ContainerLayout` parameters that keep their names.

- [ ] **Step 7: Run the tests to verify they pass**

Run: `flutter test --no-pub test/src/components/common/`
Expected: `All tests passed!`

Run: `flutter analyze --no-pub lib/src/components/common/layout/ test/src/components/common/interaction_test.dart test/src/components/common/layout/container_layout_test.dart`
Expected: `No issues found!`

Run: `cd example && flutter analyze --no-pub integration_test test_driver tool`
Expected: `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add -- lib/src/components/common/layout/container_layout.dart lib/src/components/common/layout/layout.dart test/src/components/common/interaction_test.dart test/src/components/common/layout/container_layout_test.dart example/integration_test/layout_perf_test.dart
git commit -m "refactor(layout): replace the gesture layouts with StratumInteraction" -- lib/src/components/common/layout/container_layout.dart lib/src/components/common/layout/layout.dart lib/src/components/common/layout/gesture_column_layout.dart lib/src/components/common/layout/gesture_container_layout.dart lib/src/components/common/layout/gesture_row_layout.dart lib/src/components/common/layout/gesture_stack_layout.dart lib/src/components/common/layout/gesture_wrap_layout.dart test/src/components/common/interaction_test.dart test/src/components/common/layout/container_layout_test.dart test/src/components/common/layout/gesture_layout_test.dart example/integration_test/layout_perf_test.dart
git show --stat HEAD
```

Expected: the stat lists the eleven paths above (six deletions) and nothing under `assets/` or `example/macos/`.

---

### Task 9 (M2-T9): Phase 3 library gate

**Agent:** general-purpose
**Implements:** P3-5, P3-8

**Files:**
- No change. This task runs the spec's phase gates and fixes nothing; a failure goes back to the task that owns the file.

**Interfaces:**
- Consumes: Tasks 2 to 8 (and Task 4 when it ran).
- Produces: the ledger evidence that Task 10 starts from.

- [ ] **Step 1: Run the phase test command**

Run: `flutter test --no-pub test/src/components/common/ test/src/themes/ > build/p3-tests.log 2>&1; tail -n 1 build/p3-tests.log`
Expected: `All tests passed!`

- [ ] **Step 2: Analyze the library**

Run: `flutter analyze --no-pub lib > build/p3-analyze.log 2>&1; grep -c ' error • ' build/p3-analyze.log`
Expected: `0`.

- [ ] **Step 3: Check the success criteria of spec section 1**

Run: `grep -rnE 'class (Gesture[A-Za-z]*Layout|App[A-Za-z]*View|NoGlowScrollBehavior)\b|buildViewportChrome' lib`
Expected: no output.

Run: `grep -rn 'Gesture[A-Za-z]*Layout' lib test example/lib example/integration_test`
Expected: no output.

- [ ] **Step 4: Record**

Write in the ledger: `Task 9: tests <count> pass, lib 0 errors, no Gesture*Layout`, with the count from the log's last line.

### M2 Dependency table

| task  | depends-on          | agent           |
|-------|---------------------|-----------------|
| M2-T2 | —                   | general-purpose |
| M2-T3 | M2-T2               | general-purpose |
| M2-T4 | M2-T3               | general-purpose |
| M2-T5 | M2-T3               | general-purpose |
| M2-T6 | M2-T5               | general-purpose |
| M2-T7 | M2-T5               | general-purpose |
| M2-T8 | M2-T6, M2-T7        | general-purpose |
| M2-T9 | M2-T4, M2-T8        | general-purpose |

M2-T4 counts as done when Task 1 skipped it. M2-T6 and M2-T7 touch different files; run them one after the other in the main working tree.

---

## Milestone M3: Benchmark A/B

### Task 10 (M3-T10): Interleaved A/B runs against the Task 1 baseline

**Agent:** general-purpose
**Implements:** P3-9

**Files:**
- No repository change. Creates and removes the worktree `.worktrees/p3-baseline`; writes results to `profile/memory/project_stratum_ui_layout_primitives.md` and `profile/memory/ROADMAP.md` in the NTD OS root.

**Interfaces:**
- Consumes: the Task 1 commit (old API, with S1-fast, S2-box, S2-plain, and `tool/perf_pairs.dart`); HEAD after Task 9 (new API; the scene builders moved in Task 8); `dart run tool/perf_pairs.dart <base> <candidate>`.
- Produces: the paired verdict per scene that decides the phase 3 done-when.

- [ ] **Step 1: Smoke-run the candidate harness in debug**

Run: `cd example && mkdir -p build/perf-logs && flutter test integration_test/layout_perf_test.dart -d macos > build/perf-logs/smoke-p3-candidate.log 2>&1; tail -n 3 build/perf-logs/smoke-p3-candidate.log`
Expected: `All tests passed!` with 8 tests.

Run: `grep -n 'Gesture\|interaction: StratumInteraction' example/integration_test/layout_perf_test.dart`
Expected: one line, the S3 builder's `interaction: StratumInteraction(onTap: () {}),`.

- [ ] **Step 2: Check out the baseline in a worktree**

Run from the repository root:

```bash
git worktree add --detach .worktrees/p3-baseline "$(git log --format=%H -1 --grep='S1-fast, S2-box, and S2-plain')"
cd .worktrees/p3-baseline/example && flutter pub get && grep -c 'GestureRowLayout(' integration_test/layout_perf_test.dart
```

Expected: `HEAD is now at <hash> test(example): add the S1-fast, S2-box, and S2-plain benchmark scenes`, `Got dependencies!`, and `1` (the baseline still builds S3 with `GestureRowLayout`). The hash equals the one Task 1 recorded.

- [ ] **Step 3: Clear old output on both sides**

Run from the repository root: `rm -rf example/build/perf .worktrees/p3-baseline/example/build/perf && mkdir -p example/build/perf-logs .worktrees/p3-baseline/example/build/perf-logs`
Expected: no output.

- [ ] **Step 4: Run five interleaved pairs**

Run each command from the repository root, in this order, each in the foreground, with no change to displays or window placement between runs:

```bash
(cd .worktrees/p3-baseline/example && PERF_RUN=1 flutter drive --profile --endless-trace-buffer -d macos --driver=test_driver/perf_driver.dart --target=integration_test/layout_perf_test.dart > build/perf-logs/run1.log 2>&1; grep -E "frames, span|All tests passed" build/perf-logs/run1.log)
(cd example && PERF_RUN=1 flutter drive --profile --endless-trace-buffer -d macos --driver=test_driver/perf_driver.dart --target=integration_test/layout_perf_test.dart > build/perf-logs/run1.log 2>&1; grep -E "frames, span|All tests passed" build/perf-logs/run1.log)
(cd .worktrees/p3-baseline/example && PERF_RUN=2 flutter drive --profile --endless-trace-buffer -d macos --driver=test_driver/perf_driver.dart --target=integration_test/layout_perf_test.dart > build/perf-logs/run2.log 2>&1; grep -E "frames, span|All tests passed" build/perf-logs/run2.log)
(cd example && PERF_RUN=2 flutter drive --profile --endless-trace-buffer -d macos --driver=test_driver/perf_driver.dart --target=integration_test/layout_perf_test.dart > build/perf-logs/run2.log 2>&1; grep -E "frames, span|All tests passed" build/perf-logs/run2.log)
(cd .worktrees/p3-baseline/example && PERF_RUN=3 flutter drive --profile --endless-trace-buffer -d macos --driver=test_driver/perf_driver.dart --target=integration_test/layout_perf_test.dart > build/perf-logs/run3.log 2>&1; grep -E "frames, span|All tests passed" build/perf-logs/run3.log)
(cd example && PERF_RUN=3 flutter drive --profile --endless-trace-buffer -d macos --driver=test_driver/perf_driver.dart --target=integration_test/layout_perf_test.dart > build/perf-logs/run3.log 2>&1; grep -E "frames, span|All tests passed" build/perf-logs/run3.log)
(cd .worktrees/p3-baseline/example && PERF_RUN=4 flutter drive --profile --endless-trace-buffer -d macos --driver=test_driver/perf_driver.dart --target=integration_test/layout_perf_test.dart > build/perf-logs/run4.log 2>&1; grep -E "frames, span|All tests passed" build/perf-logs/run4.log)
(cd example && PERF_RUN=4 flutter drive --profile --endless-trace-buffer -d macos --driver=test_driver/perf_driver.dart --target=integration_test/layout_perf_test.dart > build/perf-logs/run4.log 2>&1; grep -E "frames, span|All tests passed" build/perf-logs/run4.log)
(cd .worktrees/p3-baseline/example && PERF_RUN=5 flutter drive --profile --endless-trace-buffer -d macos --driver=test_driver/perf_driver.dart --target=integration_test/layout_perf_test.dart > build/perf-logs/run5.log 2>&1; grep -E "frames, span|All tests passed" build/perf-logs/run5.log)
(cd example && PERF_RUN=5 flutter drive --profile --endless-trace-buffer -d macos --driver=test_driver/perf_driver.dart --target=integration_test/layout_perf_test.dart > build/perf-logs/run5.log 2>&1; grep -E "frames, span|All tests passed" build/perf-logs/run5.log)
```

Expected for each run: eight lines `<scene>: <n> frames, span <about 2000> ms, frame interval <x> ms` (S1, S1-fast, S2, S2-box, S2-plain, S3, S4, S5) and `All tests passed.`. A run that throws the driver's coverage `StateError` is rerun with the same `PERF_RUN` before the next command.

- [ ] **Step 5: Compare by paired differences**

Run: `cd example && dart run tool/perf_pairs.dart ../.worktrees/p3-baseline/example/build/perf build/perf`
Expected: 8 rows (S1, S1-fast, S2, S2-box, S2-plain, S3, S4, S5), each with `runs` = 5, one frame interval on both sides of every row, and `pass` in every `verdict` cell. The verdict is spec section 9's rule on the medians: p99 build and p99 raster below 8.3 ms (or, when the baseline already exceeds 8.3 ms, a median paired difference of 0 or less), and a median rise of the average build time of at most 5%.

When any row reads `FAIL` or `INVALID interval`, stop: keep the worktree, record the table, and report it to the owner. This task tunes nothing.

Run: `cd example && dart run tool/perf_median.dart && cd ../.worktrees/p3-baseline/example && dart run tool/perf_median.dart`
Expected: two median tables (candidate, then baseline), 8 scenes each, `runs` = 5.

- [ ] **Step 6: Record**

Add a dated section to `profile/memory/project_stratum_ui_layout_primitives.md` with the `perf_pairs` table, both median tables, the baseline and candidate commit hashes, whether Task 4 ran, the frame interval, and the load average (`uptime`); bump `verified:`. When every row passed, delete the milestone `### p3-layout-family` from the phase `stratum-layout-primitives` in `profile/memory/ROADMAP.md` and bump its `updated:` date, per the memory-roadmap rule.

- [ ] **Step 7: Remove the baseline worktree**

Run from the repository root: `git worktree remove .worktrees/p3-baseline && rmdir .worktrees && git worktree list`
Expected: one worktree, the main one on `master`. When `git worktree remove` refuses because of untracked build output in the worktree, rerun it with `--force`; the worktree holds no work of its own.

### M3 Dependency table

| task   | depends-on | agent           |
|--------|------------|-----------------|
| M3-T10 | —          | general-purpose |

---

## Coverage

Requirement ids: `P3-1` to `P3-9` name the phase 3 row of spec section 10 (work items and done-when); `D<n>` are the defects of spec section 3 that phase 3 fixes. D2 to D6 closed in phase 1; D15 and D16 belong to phase 4.

| requirement | task(s) | note |
|-------------|---------|------|
| P3-1 `BoxLayout` (sections 4, 5) | M2-T5 | |
| P3-2 the five layouts on `BoxLayout` (section 4) | M2-T6, M2-T7, M2-T8 | |
| P3-3 `StratumInteraction` without phase 4 fields (section 4) | M2-T5 | `shortcuts` and `secondaryTapSemanticsLabel` wait for phase 4 |
| P3-4 `scrollBuilder` with `ScrollFrame` and no keys (sections 5, 6) | M2-T3, M2-T5, M2-T6 | |
| P3-5 gesture twins deleted (sections 1, 4) | M2-T8, M2-T9 | |
| P3-6 `AnimatedStyledBox` state rewrite with `preserve` and reduced motion (sections 2, 6) | M2-T2 | |
| P3-7 S2 versus S2-plain decision (sections 2, 9) | M1-T1, M2-T4 | decided on S2-box versus S2-plain (main session ruling 2026-10-01); M2-T4 runs only above 10% |
| P3-8 phase 3 tests pass (sections 8, 10) | M2-T9 | |
| P3-9 benchmark passes (sections 9, 10) | M1-T1, M3-T10 | |
| D1 wrap scrolls along `direction` | M2-T7 | |
| D7 column and row always build `AnimatedStyledBox` | M2-T5, M2-T6 | |
| D8 gesture column and row insert `Gap` widgets | M2-T6, M2-T8 | |
| D9 scrollable column and row use `Clip.none` | M2-T3, M2-T6 | |
| D10 container semantics outside the margin | M2-T5, M2-T8 | |
| D11 scroll wrapper outside the box | M2-T3, M2-T6, M2-T7 | |
| D12 parameter drift between twins | M2-T5, M2-T6, M2-T7, M2-T8 | |
| D13 `layout.dart` exports | M2-T5, M2-T8 | |
| D14 reduced motion differs by platform | M2-T2 | |
| D17 infinite minimum in an unbounded parent | M2-T6 | |
