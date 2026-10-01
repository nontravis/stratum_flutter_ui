# Layout Primitives Phase 2: Benchmark Baseline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the profile-mode benchmark harness in `example/` and record baseline medians for scenes S1 to S5 on the current (pre-refactor) layouts.

**Architecture:** `example/integration_test/layout_perf_test.dart` pumps each scene inside `binding.traceAction(reportKey: 'S<n>')`. `example/test_driver/perf_driver.dart` turns each report into a `TimelineSummary` file under `build/perf/run<PERF_RUN>/`. `example/tool/perf_median.dart` reads every run and prints the median of three metrics per scene. Each scene's widget tree lives in one builder function, so phase 3 only swaps those functions to the new API.

**Tech Stack:** Flutter 3.47.3, `integration_test` and `flutter_driver` (Flutter SDK packages, `sdk: flutter`), macOS desktop in profile mode.

**Spec:** `docs/superpowers/specs/2026-10-01-layout-primitives-design.md` (section 9; section 10 phase 2)

## Global Constraints

- Owner approval needed at plan review: add `integration_test` and `flutter_driver` as `dev_dependencies` of `example/pubspec.yaml`, both `sdk: flutter`. They are SDK packages, not pub.dev packages; no other dependency is added.
- Work in the main working tree on master; commit with explicit paths only (`git add -- <paths>` then `git commit -m "<message>" -- <paths>`); Conventional Commits with a scope; no attribution line. The owner's staged `assets/themes/` rename and modified figma specs stay out of every commit.
- Scenes use the current API only: `RowLayout`, `ColumnLayout`, `ContainerLayout`, `GestureRowLayout`, `WidgetStyle`, `ImageBlurFilter`. Do not change any file under `lib/`.
- `StratumInkWell` reads `context.theme.color`, so the harness wraps scenes in a `StratumThemeApplication` with a minimal theme built on `Fake` from `flutter_test`, and in a `MaterialApp`, so `Theme.of(context).platform` is real.
- Device: macOS desktop in profile mode decides; profile mode is disabled on simulators and emulators.
- Each scene runs three times; the median counts. Medians go to `profile/memory/project_stratum_ui_layout_primitives.md`, never into the spec or the repository.
- Metrics: `average_frame_build_time_millis`, `99th_percentile_frame_build_time_millis`, `99th_percentile_frame_rasterizer_time_millis`.
- S2-plain is a phase 3 scene and is not built here.

## Review Focus

- A scene whose tree throws during the trace (for example a missing theme): a person expects the run to fail loudly, not to record a summary of an error screen. Pinned in Task 2 by the debug-mode smoke run of every scene.
- A run whose `PERF_RUN` is unset overwrites another run: a person expects each run in its own directory. Pinned in Task 1 (`run0` default plus explicit `PERF_RUN=1..3` in Task 4).
- A scene that never scrolls (fling on a list shorter than the viewport): a person expects real frames. Pinned in Task 2 by 1000 rows and 20 cards taller than the window.
- A median across an even number of runs: a person expects the middle value of three runs. Pinned in Task 3 by requiring exactly three runs per scene and printing the run count.
- An animation scene that settles early: a person expects frames for the whole five seconds. Pinned in Task 2 by a periodic timer that toggles the style every 300 ms.

---

### Task 1: Harness skeleton and driver

**Files:**
- Modify: `example/pubspec.yaml` (`dev_dependencies`)
- Create: `example/test_driver/perf_driver.dart`
- Create: `example/integration_test/layout_perf_test.dart` (skeleton with the theme fake and host)

**Interfaces:**
- Produces: `Widget perfHost(Widget child)`; `Future<void> flingFor(WidgetTester tester, Duration duration)`; driver output `build/perf/run<PERF_RUN>/<key>.timeline_summary.json`.

- [ ] **Step 1: Add the SDK dev dependencies**

In `example/pubspec.yaml`, under `dev_dependencies:` after `flutter_test: sdk: flutter`, add:

```yaml
  integration_test:
    sdk: flutter
  flutter_driver:
    sdk: flutter
```

Run: `cd example && flutter pub get`
Expected: `Got dependencies!` with no version conflict.

- [ ] **Step 2: Write the driver**

Create `example/test_driver/perf_driver.dart`:

```dart
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart' as driver;
import 'package:integration_test/integration_test_driver.dart';

/// Writes one timeline summary per trace key into
/// `build/perf/run<PERF_RUN>/`, so repeated runs never overwrite each other.
Future<void> main() {
  final run = Platform.environment['PERF_RUN'] ?? '0';
  return integrationDriver(
    responseDataCallback: (data) async {
      if (data == null) return;
      for (final entry in data.entries) {
        final timeline = driver.Timeline.fromJson(
          entry.value as Map<String, dynamic>,
        );
        await driver.TimelineSummary.summarize(timeline).writeTimelineToFile(
          entry.key,
          destinationDirectory: 'build/perf/run$run',
          pretty: true,
        );
      }
    },
  );
}
```

- [ ] **Step 3: Write the test skeleton**

Create `example/integration_test/layout_perf_test.dart`:

```dart
// The harness measures the layouts through their src paths, because the
// gesture layouts are not exported by the layout barrel.
// ignore_for_file: implementation_imports
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stratum_ui/src/src.dart';

class _PerfTransparent extends Fake implements TransparentColors {
  @override
  Color get t0 => const Color(0x00000000);
}

class _PerfColors extends Fake implements BaseThemeColor {
  @override
  Color get overlayHover => const Color(0x11000000);

  @override
  Color get overlayActive => const Color(0x22000000);

  @override
  Color get borderBrand => const Color(0xFF0000FF);

  @override
  TransparentColors get transparent => _PerfTransparent();
}

/// Answers only what the measured widgets read.
class _PerfTheme extends Fake implements StratumThemeData {
  @override
  final BaseThemeColor color = _PerfColors();

  @override
  ScrollBehavior get scrollBehavior => const StratumScrollBehavior();

  @override
  ScrollPhysics get physics => const ClampingScrollPhysics();
}

final _theme = _PerfTheme();

/// Places a scene in a [MaterialApp] (a real [Theme] platform) under a
/// [StratumThemeApplication].
Widget perfHost(Widget child) {
  return MaterialApp(
    home: StratumThemeApplication(
      themeMode: ThemeMode.light,
      lightTheme: _theme,
      darkTheme: null,
      child: Scaffold(body: child),
    ),
  );
}

/// Flings the first [Scrollable] up and down until [duration] has passed.
Future<void> flingFor(WidgetTester tester, Duration duration) async {
  final scrollable = find.byType(Scrollable).first;
  final watch = Stopwatch()..start();
  var down = true;
  while (watch.elapsed < duration) {
    await tester.fling(scrollable, Offset(0, down ? -600 : 600), 3000);
    await tester.pumpAndSettle();
    down = !down;
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('harness builds an empty host', (tester) async {
    await tester.pumpWidget(perfHost(const SizedBox()));
    await binding.traceAction(
      () async => tester.pump(const Duration(milliseconds: 100)),
      reportKey: 'S0',
    );
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
```

- [ ] **Step 4: Run it in debug on macOS**

Run: `cd example && flutter test integration_test/layout_perf_test.dart -d macos`
Expected: `All tests passed!`. If the build fails, stop and record the decisive error line; macOS profile runs depend on this build.

- [ ] **Step 5: Run the driver once in profile**

Run: `cd example && PERF_RUN=0 flutter drive --profile -d macos --driver=test_driver/perf_driver.dart --target=integration_test/layout_perf_test.dart`
Expected: exit 0 and the file `example/build/perf/run0/S0.timeline_summary.json` exists with the key `average_frame_build_time_millis`.

- [ ] **Step 6: Commit**

```bash
git add -- example/pubspec.yaml example/pubspec.lock example/test_driver/perf_driver.dart example/integration_test/layout_perf_test.dart
git commit -m "test(example): add the profile-mode benchmark harness" -- example/pubspec.yaml example/pubspec.lock example/test_driver/perf_driver.dart example/integration_test/layout_perf_test.dart
```

---

### Task 2: Scenes S1 to S5 on the current API

**Files:**
- Modify: `example/integration_test/layout_perf_test.dart` (add scene builders and five traced tests; remove the `S0` test)

**Interfaces:**
- Consumes: `perfHost`, `flingFor` (Task 1).
- Produces: report keys `S1`, `S2`, `S3`, `S4`, `S5`; builder functions `sceneRow`, `sceneStyledRow`, `sceneTappableRow`, `AnimatingBoxes`, `GlassCards`, which phase 3 rewrites to the new API.

- [ ] **Step 1: Add the scene builders**

Add this import after the `package:stratum_ui/src/src.dart` import:

```dart
import 'package:stratum_ui/src/components/common/layout/gesture_row_layout.dart';
```

Add these declarations above `void main()`:

```dart
const _rowCount = 1000;

const _cardStyle = WidgetStyle(
  padding: EdgeInsets.all(12),
  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
  backgroundColor: Color(0xFFFFFFFF),
  borderRadius: BorderRadius.all(Radius.circular(12)),
  dropShadow: [
    BoxShadow(color: Color(0x22000000), blurRadius: 8, offset: Offset(0, 2)),
  ],
  innerShadow: [BoxShadow(color: Color(0x11000000), blurRadius: 4)],
);

List<Widget> _rowChildren(int index) {
  return [
    ColumnLayout(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Text('Item $index'), const Text('Subtitle')],
    ),
    ColumnLayout(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [Text('${index * 3}'), const Text('units')],
    ),
  ];
}

/// S1: a row of two columns with text, no style.
Widget sceneRow(int index) {
  return RowLayout(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: _rowChildren(index),
  );
}

/// S2: S1 with fill, radius, drop shadow, and inner shadow.
Widget sceneStyledRow(int index) {
  return RowLayout(
    style: _cardStyle,
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: _rowChildren(index),
  );
}

/// S3: S2 with a tap callback and the 100 ms default style animation.
Widget sceneTappableRow(int index) {
  return GestureRowLayout(
    style: _cardStyle,
    onTap: () {},
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: _rowChildren(index),
  );
}

Widget _list(Widget Function(int index) row) {
  return ListView.builder(
    itemCount: _rowCount,
    itemBuilder: (context, index) => row(index),
  );
}

/// S4: 50 boxes that toggle their style every 300 ms.
class AnimatingBoxes extends StatefulWidget {
  const AnimatingBoxes({super.key});

  @override
  State<AnimatingBoxes> createState() => _AnimatingBoxesState();
}

class _AnimatingBoxesState extends State<AnimatingBoxes> {
  static const _a = WidgetStyle(
    width: 48,
    height: 48,
    backgroundColor: Color(0xFF2962FF),
    borderRadius: BorderRadius.all(Radius.circular(4)),
    animationStyle: AnimationStyle(duration: Duration(milliseconds: 250)),
  );
  static const _b = WidgetStyle(
    width: 64,
    height: 64,
    backgroundColor: Color(0xFFFF6D00),
    borderRadius: BorderRadius.all(Radius.circular(32)),
    dropShadow: [BoxShadow(color: Color(0x44000000), blurRadius: 12)],
    animationStyle: AnimationStyle(duration: Duration(milliseconds: 250)),
  );

  late final Timer _timer;
  var _flip = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(milliseconds: 300),
      (_) => setState(() => _flip = !_flip),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < 50; i++)
          ContainerLayout(style: (i.isEven ^ _flip) ? _a : _b),
      ],
    );
  }
}

/// S5: 20 glass cards in one [BackdropGroup] over a painted background.
class GlassCards extends StatelessWidget {
  const GlassCards({super.key});

  static const _glass = WidgetStyle(
    height: 120,
    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    backgroundColor: Color(0x33FFFFFF),
    borderRadius: BorderRadius.all(Radius.circular(16)),
    backgroundBlur: ImageBlurFilter(sigmaX: 12, sigmaY: 12),
  );

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: CustomPaint(painter: _Stripes())),
        BackdropGroup(
          child: ListView.builder(
            itemCount: 20,
            itemBuilder: (context, index) =>
                ContainerLayout(style: _glass, child: Text('Card $index')),
          ),
        ),
      ],
    );
  }
}

class _Stripes extends CustomPainter {
  const _Stripes();

  @override
  void paint(Canvas canvas, Size size) {
    const colors = [
      Color(0xFFE53935),
      Color(0xFF43A047),
      Color(0xFF1E88E5),
      Color(0xFFFDD835),
    ];
    final paint = Paint()..strokeWidth = 24;
    for (var x = -size.height; x < size.width; x += 32) {
      paint.color = colors[(x ~/ 32) % colors.length];
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_Stripes oldDelegate) => false;
}
```

- [ ] **Step 2: Replace the `S0` test with the five traced scenes**

Replace the body of `main()` after `final binding = ...;` with:

```dart
  const flingTime = Duration(seconds: 5);

  testWidgets('S1 plain rows', (tester) async {
    await tester.pumpWidget(perfHost(_list(sceneRow)));
    await binding.traceAction(
      () => flingFor(tester, flingTime),
      reportKey: 'S1',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('S2 styled rows', (tester) async {
    await tester.pumpWidget(perfHost(_list(sceneStyledRow)));
    await binding.traceAction(
      () => flingFor(tester, flingTime),
      reportKey: 'S2',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('S3 tappable rows', (tester) async {
    await tester.pumpWidget(perfHost(_list(sceneTappableRow)));
    await binding.traceAction(
      () => flingFor(tester, flingTime),
      reportKey: 'S3',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('S4 animating boxes', (tester) async {
    await tester.pumpWidget(perfHost(const AnimatingBoxes()));
    await binding.traceAction(
      () => tester.pump(flingTime),
      reportKey: 'S4',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('S5 glass cards', (tester) async {
    await tester.pumpWidget(perfHost(const GlassCards()));
    await binding.traceAction(
      () => flingFor(tester, flingTime),
      reportKey: 'S5',
    );
    expect(tester.takeException(), isNull);
  });
```

- [ ] **Step 3: Smoke-run every scene in debug**

Run: `cd example && flutter test integration_test/layout_perf_test.dart -d macos`
Expected: `All tests passed!` (5 tests). A failure here is a scene bug; fix the scene, not the measured layouts.

- [ ] **Step 4: Commit**

```bash
git add -- example/integration_test/layout_perf_test.dart
git commit -m "test(example): add benchmark scenes S1 to S5 on the current layouts" -- example/integration_test/layout_perf_test.dart
```

---

### Task 3: Median tool

**Files:**
- Create: `example/tool/perf_median.dart`

**Interfaces:**
- Consumes: `build/perf/run*/<key>.timeline_summary.json` (Task 1 driver).
- Produces: a Markdown table on stdout: scene, median average build, median p99 build, median p99 raster, run count.

- [ ] **Step 1: Write the tool**

Create `example/tool/perf_median.dart`:

```dart
import 'dart:convert';
import 'dart:io';

const _metrics = [
  'average_frame_build_time_millis',
  '99th_percentile_frame_build_time_millis',
  '99th_percentile_frame_rasterizer_time_millis',
];

/// Prints the median of each metric per scene across `build/perf/run*/`.
void main() {
  final values = <String, Map<String, List<double>>>{};
  final runs = Directory('build/perf').listSync().whereType<Directory>();
  for (final run in runs) {
    final summaries = run.listSync().whereType<File>().where(
      (file) => file.path.endsWith('.timeline_summary.json'),
    );
    for (final file in summaries) {
      final scene = file.uri.pathSegments.last.split('.').first;
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final perScene = values.putIfAbsent(scene, () => {});
      for (final metric in _metrics) {
        perScene
            .putIfAbsent(metric, () => [])
            .add((json[metric] as num).toDouble());
      }
    }
  }
  stdout
    ..writeln('| Scene | avg build ms | p99 build ms | p99 raster ms | runs |')
    ..writeln('|---|---|---|---|---|');
  for (final scene in values.keys.toList()..sort()) {
    final perScene = values[scene]!;
    String median(String metric) {
      final sorted = [...perScene[metric]!]..sort();
      return sorted[sorted.length ~/ 2].toStringAsFixed(2);
    }

    stdout.writeln(
      '| $scene | ${median(_metrics[0])} | ${median(_metrics[1])} '
      '| ${median(_metrics[2])} | ${perScene[_metrics[0]]!.length} |',
    );
  }
}
```

- [ ] **Step 2: Run it on the Task 1 output**

Run: `cd example && dart run tool/perf_median.dart`
Expected: a table with one row, `S0`, and `runs` = 1.

- [ ] **Step 3: Commit**

```bash
git add -- example/tool/perf_median.dart
git commit -m "test(example): add the benchmark median tool" -- example/tool/perf_median.dart
```

---

### Task 4: Record the baseline

**Files:**
- No repository change. Write the medians to `profile/memory/project_stratum_ui_layout_primitives.md`.

**Interfaces:**
- Consumes: Tasks 1 to 3.
- Produces: the baseline table that phases 3 and 4 compare against.

- [ ] **Step 1: Clear old output**

Run: `cd example && rm -rf build/perf`
Expected: no output.

- [ ] **Step 2: Run three profile passes**

Run each, one after another, with no other heavy process running:

```bash
cd example
PERF_RUN=1 flutter drive --profile -d macos --driver=test_driver/perf_driver.dart --target=integration_test/layout_perf_test.dart
PERF_RUN=2 flutter drive --profile -d macos --driver=test_driver/perf_driver.dart --target=integration_test/layout_perf_test.dart
PERF_RUN=3 flutter drive --profile -d macos --driver=test_driver/perf_driver.dart --target=integration_test/layout_perf_test.dart
```

Expected: each exits 0; `build/perf/run1`, `run2`, and `run3` each hold five `S<n>.timeline_summary.json` files.

- [ ] **Step 3: Compute the medians**

Run: `cd example && dart run tool/perf_median.dart`
Expected: rows S1 to S5, each with `runs` = 3.

- [ ] **Step 4: Record**

Add a dated section to `profile/memory/project_stratum_ui_layout_primitives.md` with the table, the macOS version (`sw_vers -productVersion`), the machine model (`sysctl -n hw.model`), the display refresh rate, and the commit the scenes ran on. Then delete the roadmap milestone `p2-benchmark-baseline`.

---

### Task 5: Performance overlay toggle in the example app

Added 2026-10-01 at the owner's request: live monitoring uses Flutter's built-in `showPerformanceOverlay` instead of a pub.dev package (owner chose this over `flutter_perf_monitor`, `fluttrace`, and `statsfl`).

**Files:**
- Modify: `example/lib/main.dart` (`StratumWebViewExampleApp`)

**Interfaces:**
- Produces: an app-bar action (`Icons.speed`, tooltip `Performance overlay`) that toggles `MaterialApp.showPerformanceOverlay`. The benchmark host builds its own `MaterialApp` and never shows the overlay.

- [ ] **Step 1: Make the app stateful and add the toggle**

Turn `StratumWebViewExampleApp` into a `StatefulWidget` whose state holds `var _showOverlay = false;`, pass `showPerformanceOverlay: _showOverlay` to `MaterialApp`, and add to the `AppBar`:

```dart
actions: [
  IconButton(
    icon: const Icon(Icons.speed),
    tooltip: 'Performance overlay',
    isSelected: _showOverlay,
    onPressed: () => setState(() => _showOverlay = !_showOverlay),
  ),
],
```

- [ ] **Step 2: Verify**

Run: `cd example && flutter analyze --no-pub lib/main.dart`
Expected: no errors. The example has no widget-test harness (its web view needs a platform implementation), so the toggle is checked by the analyzer and by eye on the macOS build.

- [ ] **Step 3: Commit**

```bash
git add -- example/lib/main.dart
git commit -m "feat(example): add a performance overlay toggle" -- example/lib/main.dart
```
