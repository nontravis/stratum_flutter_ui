# Layout Primitives Benchmark: In-Process ABBA Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the benchmark harness with a declarative in-process ABBA comparison of frozen baseline classes against the current layouts, then rerun the phase 3 comparison (fd59ffa against HEAD) to a verdict.

**Architecture:** Scenes become entries of one catalog (`perf/perf_scenes.dart`) that draw through a `PerfKit`; `CurrentKit` builds the current API and `BaselineKit` builds `Baseline*` copies that `tool/perf_freeze.dart` writes from `git show` into `integration_test/baseline/`. The entry test `layout_perf_test.dart` traces one scene group per `flutter drive` invocation: an untraced warm-up, then one block per scene in the order baseline, current, current, baseline. `tool/perf_abba.dart` loops the invocations, pairs the summaries, and judges each scene on a distribution-free 95% interval of the median paired change, gated by the S2-plain null control.

**Tech Stack:** Flutter 3.47.3, Dart ^3.13.3, `flutter_test`, `integration_test` and `flutter_driver` (SDK packages in `example/`), `flutter_lints` in `example/`, macOS desktop in profile mode.

**Spec:** `docs/superpowers/specs/2026-10-01-layout-primitives-design.md`, section 9 (9.1 to 9.5) and the section 8 paragraph on the benchmark tools; commits 2f3eac6 and f73c674. Project memory: `profile/memory/project_stratum_ui_layout_primitives.md` in the NTD OS root, section "2026-10-01 — Benchmark section 9 amended to in-process ABBA".

**Anchor base:** master f73c674

**Preconditions:**
- `flutter analyze --no-pub integration_test test_driver tool`, run from `example/`, reports "No issues found!" (verified on f73c674).
- A trial freeze of the six phase 3 files with the Task 2 algorithm analyzed clean on f73c674.

## Global Constraints

- Work in the main working tree on `master`. Owner work in progress stays out of every commit: the staged rename `assets/themes/example.yaml -> assets/themes/default/theme.yaml` and the untracked `example/macos/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/` and `example/macos/Runner.xcworkspace/xcshareddata/swiftpm/`.
- Commit with explicit paths only: `git add -- <paths>` (or `git rm -- <paths>`), then `git commit -m "<message>" -- <paths>`. Write each path literally. Conventional Commits with a scope; no `Co-Authored-By` line and no AI attribution.
- New classes use the `new` constructor form: `const new(` for the unnamed constructor. Avoid named constructors; use records and top-level functions instead.
- Files under `example/` that import `package:stratum_ui/src/src.dart` start with `// ignore_for_file: implementation_imports`. Imports between `integration_test/`, `test/`, and `tool/` files are relative.
- Run every command from `example/` unless a step says otherwise. Run `flutter test --no-pub <one file>` for each RED step, one file at a time: a compile error in one file breaks the others.
- Any command likely to take over a minute writes to a log under `example/build/perf-logs/` (ignored through `/*/build/`), and the step reads the log's tail. The full comparison in Task 6 runs in the background.
- Spec values, verbatim: "One invocation holds at most 16 traces"; groups "g1 is S2-plain, S1, S1-fast, and S2; g2 is S2-plain, S2-box, and S3; g3 is S2-plain, S4, and S5"; block order "baseline, current, current, baseline"; settle "pumps 250 ms without tracing"; report key `<scene>.<side>.<pair>` with side `base` or `cand`; run directory `build/perf/abba/r<run>g<group>/`; interval check "differs by more than 10% from the run's median interval"; interval "[x(k), x(n−k+1)] … P(Bin(n, ½) ≤ k − 1) ≤ 0.025"; "Fewer than 6 pairs give no interval"; PASS "upper bound is at most +5%", FAIL "lower bound is above +5%"; budget 8.3 ms; exit codes "0 for PASS, 1 for FAIL or INVALID, and 2 for INCONCLUSIVE"; "a cap of 24 pairs per scene".
- Trace settings stay as they are: two-second window, semantics off, streams `Dart`, `Embedder`, and `GC`, `--endless-trace-buffer`, coverage guard in the driver.
- Measure under normal multitasking: never wait for a quiet machine and never discard data for load (owner ruling 2026-10-01).
- A frozen file is verbatim except the header, the baseline import, and the `Baseline` prefix. Never edit `integration_test/baseline/` by hand; run the tool again.
- Measured numbers go to the project memory entry in the NTD OS root, never into the spec or the repository.

## Review Focus

- A rename that hits part of a longer name (`RowLayout` inside `GestureRowLayout`, `AnimatedStyledBox` inside `_AnimatedStyledBoxState`): a person expects only whole identifiers to change. Pinned in Task 2 ("renames whole identifiers only").
- S2-plain drawn through a kit by a later edit: the null control would stop being identical on both sides without any visible failure. Pinned in Task 1 ("S2-plain never calls the kit").
- A second `run` into a folder that already holds runs: a person expects the tool to refuse rather than mix two comparisons. Pinned in Task 5 ("refuses run folders that exist").
- An invocation that dies mid-group and leaves a trace without its partner: a person expects that trace to be left out, not paired with a neighbor. Pinned in Task 4 ("leaves a trace without its partner out").
- A run whose window opened on the 60 Hz display: a person expects the whole run to be left out and listed, not averaged in. Pinned in Task 4 ("marks a run invalid when one trace's interval drifts").

## Dependencies

| Task | After |
|---|---|
| 1 Declarative harness | — |
| 2 `perf_freeze` | — |
| 3 Baseline, kit, ABBA runner | 1, 2 |
| 4 `perf_abba` analysis | — |
| 5 `perf_abba run`, driver, dry run | 3, 4 |
| 6 Phase 3 comparison and records | 5 |

---

### Task 1: Declarative harness with the current kit

Behavior-preserving refactor: the same eight traces with the same report keys, drawn through `CurrentKit` from a scene catalog.

**Files:**
- Create: `example/integration_test/perf/perf_host.dart`
- Create: `example/integration_test/perf/perf_kit.dart`
- Create: `example/integration_test/perf/perf_scene.dart`
- Create: `example/integration_test/perf/perf_scenes.dart`
- Create: `example/integration_test/widgets/animating_boxes.dart`
- Create: `example/integration_test/widgets/glass_cards.dart`
- Modify: `example/integration_test/layout_perf_test.dart` (whole file)
- Test: `example/test/perf/perf_scenes_test.dart`

**Interfaces:**
- Consumes: `RowLayout`, `ColumnLayout`, `ContainerLayout`, `StratumInteraction`, `WidgetStyle`, `StyleDecoration`, `StratumThemeApplication` from `package:stratum_ui/src/src.dart`.
- Produces: `const traceWindow`, `const perfStreams`, `Widget perfHost(Widget child)`, `Future<void> scrollFor(WidgetTester tester, Duration duration, {double distance = 4000})` in `perf_host.dart`; `abstract interface class PerfKit` with `row({WidgetStyle? style, VoidCallback? onTap, required MainAxisAlignment mainAxisAlignment, required List<Widget> children})`, `column({required MainAxisSize mainAxisSize, required CrossAxisAlignment crossAxisAlignment, required List<Widget> children})`, `container({WidgetStyle? style, Widget? child})`, and `class CurrentKit implements PerfKit` in `perf_kit.dart`; `class PerfScene` (`key`, `build`, `drive`, `check`) in `perf_scene.dart`; `final List<PerfScene> perfScenes` and `PerfScene perfScene(String key)` in `perf_scenes.dart`; `AnimatingBoxes({required PerfKit kit})` and `GlassCards({required PerfKit kit})`.

- [ ] **Step 1: Write the failing test**

Create `example/test/perf/perf_scenes_test.dart`:

```dart
// ignore_for_file: implementation_imports
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import '../../integration_test/perf/perf_host.dart';
import '../../integration_test/perf/perf_kit.dart';
import '../../integration_test/perf/perf_scenes.dart';

/// A kit that fails the test when a scene draws through it.
class _RefusingKit implements PerfKit {
  const new();

  @override
  Widget row({
    WidgetStyle? style,
    VoidCallback? onTap,
    required MainAxisAlignment mainAxisAlignment,
    required List<Widget> children,
  }) => throw StateError('row called');

  @override
  Widget column({
    required MainAxisSize mainAxisSize,
    required CrossAxisAlignment crossAxisAlignment,
    required List<Widget> children,
  }) => throw StateError('column called');

  @override
  Widget container({WidgetStyle? style, Widget? child}) =>
      throw StateError('container called');
}

void main() {
  group('perfScenes', () {
    test('lists the scenes of spec section 9.1 in table order', () {
      expect(
        [for (final scene in perfScenes) scene.key],
        ['S1', 'S1-fast', 'S2', 'S2-box', 'S2-plain', 'S3', 'S4', 'S5'],
      );
    });

    for (final scene in perfScenes) {
      testWidgets('${scene.key} builds and passes its check with '
          'CurrentKit', (tester) async {
        const kit = CurrentKit();
        await tester.pumpWidget(perfHost(scene.build(kit)));
        await scene.check?.call(tester, kit);
        expect(tester.takeException(), isNull);
        // Unmounts S4, whose periodic timer must not outlive the test.
        await tester.pumpWidget(const SizedBox());
      });
    }

    testWidgets('S2-plain never calls the kit', (tester) async {
      await tester.pumpWidget(
        perfHost(perfScene('S2-plain').build(const _RefusingKit())),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(AnimatedStyledBox), findsNothing);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test --no-pub test/perf/perf_scenes_test.dart`
Expected: FAIL at compile time: `Error when reading 'integration_test/perf/perf_host.dart': No such file or directory`.

- [ ] **Step 3: Create `perf/perf_host.dart`**

The fake theme, `perfHost`, and `scrollFor` move verbatim from `layout_perf_test.dart`; the window and stream constants move out of `main`.

```dart
// The harness imports the src barrel, which also exports the theme types
// the fake theme implements.
// ignore_for_file: implementation_imports
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

/// Length of every traced window. Two seconds fit the timeline recorder's
/// buffer at 144 Hz; a longer trace loses its first frames.
const traceWindow = Duration(seconds: 2);

/// Timeline streams that carry the `Frame` (Dart) and `GPURasterizer::Draw`
/// (Embedder) events. The default `all` adds the API stream, whose events
/// fill the recorder's buffer and push the traced frames out of it.
const perfStreams = ['Dart', 'Embedder', 'GC'];

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

/// Scrolls the first [Scrollable] down for half of [duration] and back up
/// for the other half at a constant speed, so every traced frame is a
/// scroll frame and every run scrolls the same way.
Future<void> scrollFor(
  WidgetTester tester,
  Duration duration, {
  double distance = 4000,
}) async {
  final position = tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position;
  expect(position.maxScrollExtent, greaterThanOrEqualTo(distance));
  final half = duration ~/ 2;
  await position.animateTo(distance, duration: half, curve: Curves.linear);
  await position.animateTo(0, duration: half, curve: Curves.linear);
}
```

- [ ] **Step 4: Create `perf/perf_kit.dart`**

```dart
// ignore_for_file: implementation_imports
import 'package:stratum_ui/src/src.dart';

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
```

- [ ] **Step 5: Create `perf/perf_scene.dart`**

```dart
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
```

- [ ] **Step 6: Create `widgets/animating_boxes.dart`**

```dart
// ignore_for_file: implementation_imports
import 'package:stratum_ui/src/src.dart';

import '../perf/perf_kit.dart';

/// S4: 50 boxes that toggle their style every 250 ms, as long as their
/// animation, so every traced frame animates.
class AnimatingBoxes extends StatefulWidget {
  const new({super.key, required this.kit});

  /// The layouts the boxes draw with.
  final PerfKit kit;

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
      const Duration(milliseconds: 250),
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
          widget.kit.container(style: (i.isEven ^ _flip) ? _a : _b),
      ],
    );
  }
}
```

- [ ] **Step 7: Create `widgets/glass_cards.dart`**

```dart
// ignore_for_file: implementation_imports
import 'package:stratum_ui/src/src.dart';

import '../perf/perf_kit.dart';

/// S5: 20 glass cards in one [BackdropGroup] over a painted background.
class GlassCards extends StatelessWidget {
  const new({super.key, required this.kit});

  /// The layouts the cards draw with.
  final PerfKit kit;

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
                kit.container(style: _glass, child: Text('Card $index')),
          ),
        ),
      ],
    );
  }
}

class _Stripes extends CustomPainter {
  const new();

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

- [ ] **Step 8: Create `perf/perf_scenes.dart`**

```dart
// ignore_for_file: implementation_imports
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import '../widgets/animating_boxes.dart';
import '../widgets/glass_cards.dart';
import 'perf_host.dart';
import 'perf_kit.dart';
import 'perf_scene.dart';

const _rowCount = 1000;

/// S1-fast's scroll distance per traced second half: more than one new
/// row per frame at 144 Hz (111 px per frame).
const _fastDistance = 16000.0;

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

List<Widget> _rowChildren(PerfKit kit, int index) {
  return [
    kit.column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Text('Item $index'), const Text('Subtitle')],
    ),
    kit.column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [Text('${index * 3}'), const Text('units')],
    ),
  ];
}

/// S1's two columns as plain Flutter [Column]s, so a row's box is the only
/// layout box in S2-box and S2-plain.
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

/// S1: a row of two columns with text, no style.
Widget _row(PerfKit kit, int index) {
  return kit.row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: _rowChildren(kit, index),
  );
}

/// S2: S1 with fill, radius, drop shadow, and inner shadow.
Widget _styledRow(PerfKit kit, int index) {
  return kit.row(
    style: _cardStyle,
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: _rowChildren(kit, index),
  );
}

/// S2-box: S2's styled row around plain columns.
Widget _boxRow(PerfKit kit, int index) {
  return kit.row(
    style: _cardStyle,
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: _plainChildren(index),
  );
}

/// S3: S2 with a tap callback and the 100 ms default style animation.
Widget _tappableRow(PerfKit kit, int index) {
  return kit.row(
    style: _cardStyle,
    onTap: () {},
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: _rowChildren(kit, index),
  );
}

/// S2-plain: the S2-box row drawn without [AnimatedStyledBox] and without
/// a kit, so both sides run the same code (the null control).
///
/// The same margin, decoration, padding, and children as S2-box.
/// `_cardStyle` sets no size and no `clipBehavior`, so S2-box builds no
/// `RenderConstrainedBox` and no `RenderClipRRect`; S2-plain builds both as
/// pass-through render objects.
Widget _plainRow(int index) {
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

Widget _list(Widget Function(int index) row) {
  return ListView.builder(
    itemCount: _rowCount,
    itemBuilder: (context, index) => row(index),
  );
}

/// The position of the first [Scrollable].
ScrollPosition _position(WidgetTester tester) {
  return tester.state<ScrollableState>(find.byType(Scrollable).first).position;
}

/// Scrolls one traced window down [distance] and back.
Future<void> Function(WidgetTester tester) _scroll({
  double distance = 4000,
}) {
  return (tester) => scrollFor(tester, traceWindow, distance: distance);
}

/// Every scene of spec section 9.1, in table order.
final perfScenes = <PerfScene>[
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
    'S2-plain',
    build: (_) => _list(_plainRow),
    drive: _scroll(),
    check: (tester, kit) async {
      // Equal row heights give equal list extents, so S2-plain scrolls the
      // same rows as S2-box.
      final plainExtent = _position(tester).maxScrollExtent;
      await tester.pumpWidget(perfHost(_list((index) => _boxRow(kit, index))));
      final boxExtent = _position(tester).maxScrollExtent;
      await tester.pumpWidget(perfHost(_list(_plainRow)));
      expect(plainExtent, closeTo(boxExtent, 0.5));
    },
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
```

- [ ] **Step 9: Run the test to verify it passes**

Run: `flutter test --no-pub test/perf/perf_scenes_test.dart`
Expected: PASS, 10 tests (one order test, eight scene tests, one S2-plain test).

- [ ] **Step 10: Replace `layout_perf_test.dart`**

Overwrite `example/integration_test/layout_perf_test.dart` with:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'perf/perf_host.dart';
import 'perf/perf_kit.dart';
import 'perf/perf_scenes.dart';

/// Traces every scene of the catalog with the current layouts.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  const kit = CurrentKit();

  for (final scene in perfScenes) {
    testWidgets(scene.key, (tester) async {
      await tester.pumpWidget(perfHost(scene.build(kit)));
      await scene.check?.call(tester, kit);
      await binding.traceAction(
        () => scene.drive(tester),
        streams: perfStreams,
        reportKey: scene.key,
      );
      expect(tester.takeException(), isNull);
    }, semanticsEnabled: false);
  }
}
```

- [ ] **Step 11: Analyze and smoke-run the harness in debug mode**

Run: `flutter analyze --no-pub integration_test test`
Expected: `No issues found!`

Run: `mkdir -p build/perf-logs && flutter test --no-pub integration_test/layout_perf_test.dart -d macos > build/perf-logs/task1-smoke.log 2>&1; echo "exit $?"; tail -5 build/perf-logs/task1-smoke.log`
Expected: `exit 0` and `All tests passed!` with 8 tests (S1, S1-fast, S2, S2-box, S2-plain, S3, S4, S5).

- [ ] **Step 12: Commit**

```bash
cd "<repo>"
git add -- example/integration_test/layout_perf_test.dart example/integration_test/perf example/integration_test/widgets example/test/perf/perf_scenes_test.dart
git commit -m "refactor(example): declare the benchmark scenes in a catalog drawn through a kit" -- example/integration_test/layout_perf_test.dart example/integration_test/perf example/integration_test/widgets example/test/perf/perf_scenes_test.dart
```

---

### Task 2: `perf_freeze` tool

**Files:**
- Create: `example/tool/perf_freeze.dart`
- Test: `example/test/tool/perf_freeze_test.dart`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `const baselinePrefix = 'Baseline'`, `const baselineDirectory = 'integration_test/baseline'`, `const baselineBarrel = 'baseline.dart'`, `Set<String> declaredNames(Iterable<String> sources)`, `String renameAll(String source, Set<String> names)`, `Map<String, String> freeze({required String commit, required Map<String, String> sources})` (file name to content, barrel included), and the CLI `dart run tool/perf_freeze.dart <commit> <path>...`.

- [ ] **Step 1: Write the failing test**

Create `example/test/tool/perf_freeze_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import '../../tool/perf_freeze.dart' hide main;

const _row = '''
import 'package:stratum_ui/src/src.dart';

/// Wraps an [AnimatedStyledBox]; see [GestureRowLayout] for taps.
class RowLayout extends StatelessWidget {
  const RowLayout({super.key});

  @override
  Widget build(BuildContext context) => const AnimatedStyledBox();
}

class _RowLayoutState {}
''';

const _box = '''
import 'package:stratum_ui/src/components/common/model/widget_style.dart';

typedef StyledBoxBuilder = Widget Function(WidgetStyle style, Widget box);

abstract class AnimatedStyledBox extends StatefulWidget {}

class _AnimatedStyledBoxState {}

extension on Widget {}
''';

void main() {
  group('declaredNames', () {
    test('finds public classes and typedefs, never private names or '
        'unnamed extensions', () {
      expect(declaredNames([_row, _box]), {
        'RowLayout',
        'StyledBoxBuilder',
        'AnimatedStyledBox',
      });
    });
  });

  group('renameAll', () {
    test('renames declarations, constructors, uses, and doc references', () {
      final renamed = renameAll(_row, {'RowLayout', 'AnimatedStyledBox'});
      expect(renamed, contains('class BaselineRowLayout extends'));
      expect(renamed, contains('const BaselineRowLayout({super.key});'));
      expect(renamed, contains('=> const BaselineAnimatedStyledBox();'));
      expect(renamed, contains('/// Wraps an [BaselineAnimatedStyledBox];'));
    });

    test('renames whole identifiers only', () {
      final renamed = renameAll(_row, {'RowLayout'});
      expect(renamed, contains('[GestureRowLayout]'));
      expect(renamed, contains('class _RowLayoutState {}'));
      expect(renamed, contains("import 'package:stratum_ui/src/src.dart';"));
      expect(
        renameAll(_box, {'AnimatedStyledBox'}),
        contains('class _AnimatedStyledBoxState {}'),
      );
    });
  });

  group('freeze', () {
    final files = freeze(
      commit: 'fd59ffa',
      sources: {
        'lib/a/row_layout.dart': _row,
        'lib/b/animated_styled_box.dart': _box,
      },
    );

    test('writes one file per source and a barrel that exports them', () {
      expect(files.keys, [
        'row_layout.dart',
        'animated_styled_box.dart',
        'baseline.dart',
      ]);
      expect(
        files['baseline.dart'],
        contains(
          "export 'row_layout.dart';\nexport 'animated_styled_box.dart';\n",
        ),
      );
    });

    test('names the commit and path in the header and imports the barrel '
        'before the source', () {
      final row = files['row_layout.dart']!;
      expect(
        row,
        startsWith(
          '// Frozen by tool/perf_freeze.dart from '
          'fd59ffa:lib/a/row_layout.dart.',
        ),
      );
      expect(
        row.indexOf("import 'baseline.dart';"),
        lessThan(row.indexOf("import 'package:stratum_ui/src/src.dart';")),
      );
      expect(row, contains('const BaselineAnimatedStyledBox()'));
    });

    test('rejects two sources with one file name', () {
      expect(
        () => freeze(
          commit: 'fd59ffa',
          sources: {'lib/a/row_layout.dart': _row, 'lib/b/row_layout.dart': _row},
        ),
        throwsArgumentError,
      );
    });

    test('rejects a source named like the barrel', () {
      expect(
        () => freeze(commit: 'fd59ffa', sources: {'lib/baseline.dart': _row}),
        throwsArgumentError,
      );
    });

    test('rejects a library or part directive', () {
      expect(
        () => freeze(
          commit: 'fd59ffa',
          sources: {'lib/a/row_layout.dart': 'library row;\n$_row'},
        ),
        throwsArgumentError,
      );
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test --no-pub test/tool/perf_freeze_test.dart`
Expected: FAIL at compile time: `Error when reading 'tool/perf_freeze.dart': No such file or directory`.

- [ ] **Step 3: Write `tool/perf_freeze.dart`**

```dart
import 'dart:io';

/// Prefix of every public top-level name that a frozen file declares.
const baselinePrefix = 'Baseline';

/// Folder of the frozen files, relative to `example/`.
const baselineDirectory = 'integration_test/baseline';

/// The barrel that exports every frozen file; each frozen file imports it.
const baselineBarrel = 'baseline.dart';

final _declaration = RegExp(
  r'^(?:(?:abstract|base|final|sealed|interface|mixin)\s+)*'
  r'(?:class|mixin|enum|extension\s+type|extension|typedef)\s+([A-Z]\w*)',
  multiLine: true,
);

final _directive = RegExp(r'^(?:library|part)\b', multiLine: true);

/// Freezes baseline classes for the in-process benchmark (spec section 9.3).
///
/// Usage, from `example/`:
/// `dart run tool/perf_freeze.dart <commit> <path>...`
///
/// Each path is relative to the repository root. Replaces the content of
/// `integration_test/baseline/` with one frozen file per path and a barrel
/// that exports them. Run `flutter analyze` on the folder afterwards: an
/// error there means the copy set misses a file.
Future<void> main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln('usage: dart run tool/perf_freeze.dart <commit> <path>...');
    exitCode = 64;
    return;
  }
  final commit = await _resolve(args.first);
  final sources = {
    for (final path in args.skip(1)) path: await _show(commit, path),
  };
  final files = freeze(commit: commit, sources: sources);
  final directory = Directory(baselineDirectory);
  if (directory.existsSync()) directory.deleteSync(recursive: true);
  directory.createSync(recursive: true);
  for (final MapEntry(key: name, value: content) in files.entries) {
    File('${directory.path}/$name').writeAsStringSync(content);
  }
  final names = declaredNames(sources.values).toList()..sort();
  stdout.writeln(
    'froze ${sources.length} files from $commit; renamed ${names.join(', ')}',
  );
}

/// Public top-level names declared in [sources].
Set<String> declaredNames(Iterable<String> sources) {
  return {
    for (final source in sources)
      for (final match in _declaration.allMatches(source)) match[1]!,
  };
}

/// [source] with [baselinePrefix] before every whole identifier in [names].
String renameAll(String source, Set<String> names) {
  if (names.isEmpty) return source;
  final pattern = RegExp('\\b(${names.join('|')})\\b');
  return source.replaceAllMapped(
    pattern,
    (match) => '$baselinePrefix${match[1]}',
  );
}

/// File name to content for each frozen source and for the barrel.
///
/// [sources] maps a repository path to its content at [commit]. Throws an
/// [ArgumentError] when two paths share a file name, a path is named like
/// the barrel, or a source has a library or part directive.
Map<String, String> freeze({
  required String commit,
  required Map<String, String> sources,
}) {
  final names = declaredNames(sources.values);
  final files = <String, String>{};
  for (final MapEntry(key: path, value: source) in sources.entries) {
    final name = path.split('/').last;
    if (name == baselineBarrel || files.containsKey(name)) {
      throw ArgumentError.value(path, 'sources', 'duplicate file name $name');
    }
    if (_directive.hasMatch(source)) {
      throw ArgumentError.value(path, 'sources', 'library or part directive');
    }
    files[name] =
        '${_header('$commit:$path')}'
        '// ignore_for_file: type=lint, unused_import\n'
        "import '$baselineBarrel';\n"
        '\n'
        '${renameAll(source, names)}';
  }
  files[baselineBarrel] =
      '${_header(commit)}\n'
      '${[for (final name in files.keys) "export '$name';\n"].join()}';
  return files;
}

String _header(String origin) {
  return '// Frozen by tool/perf_freeze.dart from $origin. Do not edit; run\n'
      '// the tool again. Verbatim except this header, the baseline import,\n'
      '// and the $baselinePrefix prefix on the names the frozen files '
      'declare.\n';
}

Future<String> _resolve(String commit) async {
  return (await _git(['rev-parse', '--short', commit])).trim();
}

Future<String> _show(String commit, String path) {
  return _git(['show', '$commit:$path']);
}

Future<String> _git(List<String> args) async {
  final result = await Process.run('git', args);
  if (result.exitCode != 0) {
    throw ProcessException('git', args, '${result.stderr}', result.exitCode);
  }
  return result.stdout as String;
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test --no-pub test/tool/perf_freeze_test.dart`
Expected: PASS, 8 tests.

- [ ] **Step 5: Analyze**

Run: `flutter analyze --no-pub tool test/tool`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
cd "<repo>"
git add -- example/tool/perf_freeze.dart example/test/tool/perf_freeze_test.dart
git commit -m "feat(example): add perf_freeze to copy baseline classes into the benchmark" -- example/tool/perf_freeze.dart example/test/tool/perf_freeze_test.dart
```

---

### Task 3: Frozen fd59ffa baseline, `BaselineKit`, and the ABBA runner

**Files:**
- Create (generated): `example/integration_test/baseline/` (six frozen files and `baseline.dart`)
- Modify: `example/integration_test/perf/perf_kit.dart` (append `BaselineKit`)
- Modify: `example/integration_test/perf/perf_host.dart` (append `settleTime`)
- Modify: `example/integration_test/perf/perf_scene.dart` (append `PerfStep` and `abbaSteps`)
- Modify: `example/integration_test/perf/perf_scenes.dart` (append `perfGroups` and `perfGroup`)
- Modify: `example/integration_test/layout_perf_test.dart` (whole file)
- Test: `example/test/perf/perf_kit_test.dart`, `example/test/perf/perf_scene_test.dart`, `example/test/perf/perf_scenes_test.dart`

**Interfaces:**
- Consumes: Task 1's `PerfKit`, `CurrentKit`, `PerfScene`, `perfScenes`, `perfScene`, `perfHost`, `traceWindow`, `perfStreams`; Task 2's CLI.
- Produces: `class BaselineKit implements PerfKit` (`const new()`); `const settleTime = Duration(milliseconds: 250)`; `class PerfStep` (`scene`, `baseline`, `pair`, `traced`, `reportKey`, `name`); `List<PerfStep> abbaSteps(List<PerfScene> scenes)`; `const Map<int, List<String>> perfGroups` with keys 1, 2, 3; `List<PerfScene> perfGroup(int group)`; the runner reads `--dart-define=PERF_GROUP`.

- [ ] **Step 1: Freeze the six phase 3 files of fd59ffa**

Run:

```bash
dart run tool/perf_freeze.dart fd59ffa lib/src/components/common/style/animated_styled_box.dart lib/src/components/common/layout/container_layout.dart lib/src/components/common/layout/column_layout.dart lib/src/components/common/layout/row_layout.dart lib/src/components/common/layout/gesture_row_layout.dart lib/src/components/common/layout/gesture_container_layout.dart
```

Expected: `froze 6 files from fd59ffa; renamed AnimatedStyledBox, ColumnLayout, ContainerLayout, GestureContainerLayout, GestureRowLayout, RowLayout, StyledBoxBuilder`

- [ ] **Step 2: Analyze the frozen folder**

Run: `flutter analyze --no-pub integration_test/baseline`
Expected: `No issues found!` An error here means the copy set misses a file (spec section 9.3): add the file that declares the missing name to Step 1's command, rerun Step 1, and record the change for the spec.

- [ ] **Step 3: Write the failing kit test**

Create `example/test/perf/perf_kit_test.dart`:

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
            .having((r) => r.mainAxisAlignment, 'mainAxisAlignment',
                MainAxisAlignment.end),
      );
    });

    test('builds a RowLayout without interaction when there is no tap', () {
      final row = const CurrentKit().row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: const [],
      );
      expect(row, isA<RowLayout>().having((r) => r.interaction, 'interaction',
          isNull));
    });
  });

  group('BaselineKit', () {
    test('builds BaselineRowLayout when there is no tap', () {
      final row = const BaselineKit().row(
        style: const WidgetStyle(),
        mainAxisAlignment: MainAxisAlignment.end,
        children: const [],
      );
      expect(
        row,
        isA<BaselineRowLayout>().having(
          (r) => r.mainAxisAlignment,
          'mainAxisAlignment',
          MainAxisAlignment.end,
        ),
      );
    });

    test('builds BaselineGestureRowLayout with the tap', () {
      final row = const BaselineKit().row(
        onTap: onTap,
        mainAxisAlignment: MainAxisAlignment.start,
        children: const [],
      );
      expect(
        row,
        isA<BaselineGestureRowLayout>().having((r) => r.onTap, 'onTap', onTap),
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
            .having((c) => c.crossAxisAlignment, 'crossAxisAlignment',
                CrossAxisAlignment.end),
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

- [ ] **Step 4: Run the kit test to verify it fails**

Run: `flutter test --no-pub test/perf/perf_kit_test.dart`
Expected: FAIL at compile time: `Method not found: 'BaselineKit'` (or `The name 'BaselineKit' isn't a class`).

- [ ] **Step 5: Append `BaselineKit` to `perf/perf_kit.dart`**

Add the import below the existing `src.dart` import:

```dart
import '../baseline/baseline.dart';
```

Append at the end of the file:

```dart
/// The layouts of the frozen baseline (spec section 9.3).
///
/// Phase 3's baseline is fd59ffa, where a tappable row is a separate
/// `GestureRowLayout`.
class BaselineKit implements PerfKit {
  const new();

  @override
  Widget row({
    WidgetStyle? style,
    VoidCallback? onTap,
    required MainAxisAlignment mainAxisAlignment,
    required List<Widget> children,
  }) {
    if (onTap == null) {
      return BaselineRowLayout(
        style: style,
        mainAxisAlignment: mainAxisAlignment,
        children: children,
      );
    }
    return BaselineGestureRowLayout(
      style: style,
      onTap: onTap,
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

- [ ] **Step 6: Run the kit test to verify it passes**

Run: `flutter test --no-pub test/perf/perf_kit_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 7: Build every scene on both kits**

In `example/test/perf/perf_scenes_test.dart`, replace the `for (final scene in perfScenes) { testWidgets(... CurrentKit ...) }` loop with:

```dart
    for (final kit in const <PerfKit>[CurrentKit(), BaselineKit()]) {
      for (final scene in perfScenes) {
        testWidgets('${scene.key} builds and passes its check with '
            '${kit.runtimeType}', (tester) async {
          await tester.pumpWidget(perfHost(scene.build(kit)));
          await scene.check?.call(tester, kit);
          expect(tester.takeException(), isNull);
          // Unmounts S4, whose periodic timer must not outlive the test.
          await tester.pumpWidget(const SizedBox());
        });
      }
    }
```

Run: `flutter test --no-pub test/perf/perf_scenes_test.dart`
Expected: PASS, 18 tests.

- [ ] **Step 8: Write the failing run-order test**

Create `example/test/perf/perf_scene_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/perf/perf_scene.dart';
import '../../integration_test/perf/perf_scenes.dart';

void main() {
  group('abbaSteps', () {
    final steps = abbaSteps([perfScene('S1'), perfScene('S4')]);

    test('warms every scene up on both sides before the first trace', () {
      expect([for (final step in steps.take(4)) step.name], [
        'warm-up S1.base',
        'warm-up S1.cand',
        'warm-up S4.base',
        'warm-up S4.cand',
      ]);
      expect(steps.take(4).any((step) => step.traced), isFalse);
    });

    test('traces one block per scene: baseline, current, current, '
        'baseline', () {
      expect([for (final step in steps.skip(4)) step.reportKey], [
        'S1.base.1',
        'S1.cand.1',
        'S1.cand.2',
        'S1.base.2',
        'S4.base.1',
        'S4.cand.1',
        'S4.cand.2',
        'S4.base.2',
      ]);
      expect(steps.skip(4).every((step) => step.traced), isTrue);
      expect(steps.skip(4).first.name, 'S1.base.1');
    });
  });

  group('perfGroups', () {
    test('covers every catalog scene, with S2-plain first in each group',
        () {
      expect(perfGroups.keys, [1, 2, 3]);
      expect(
        {for (final keys in perfGroups.values) ...keys},
        {for (final scene in perfScenes) scene.key},
      );
      for (final keys in perfGroups.values) {
        expect(keys.first, 'S2-plain');
      }
    });

    test('keeps every invocation within 16 traces', () {
      for (final group in perfGroups.keys) {
        final traced = abbaSteps(perfGroup(group)).where((s) => s.traced);
        expect(traced.length, lessThanOrEqualTo(16), reason: 'group $group');
      }
    });

    test('rejects an unknown group', () {
      expect(() => perfGroup(4), throwsArgumentError);
    });
  });
}
```

- [ ] **Step 9: Run the run-order test to verify it fails**

Run: `flutter test --no-pub test/perf/perf_scene_test.dart`
Expected: FAIL at compile time: `Method not found: 'abbaSteps'`.

- [ ] **Step 10: Append `PerfStep` and `abbaSteps` to `perf/perf_scene.dart`**

```dart
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
```

- [ ] **Step 11: Append `perfGroups` and `perfGroup` to `perf/perf_scenes.dart`**

```dart
/// Scene groups, one per invocation (spec section 9.4). Each group starts
/// with the S2-plain null control and stays within 16 traces, because the
/// binding sends every timeline to the driver in one message.
///
/// `tool/perf_abba.dart` lists the same keys in its `groups`.
const perfGroups = <int, List<String>>{
  1: ['S2-plain', 'S1', 'S1-fast', 'S2'],
  2: ['S2-plain', 'S2-box', 'S3'],
  3: ['S2-plain', 'S4', 'S5'],
};

/// The scenes of [group], in run order.
List<PerfScene> perfGroup(int group) {
  final keys = perfGroups[group];
  if (keys == null) {
    throw ArgumentError.value(group, 'group', 'no such scene group');
  }
  return [for (final key in keys) perfScene(key)];
}
```

- [ ] **Step 12: Run the run-order test to verify it passes**

Run: `flutter test --no-pub test/perf/perf_scene_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 13: Append `settleTime` to `perf/perf_host.dart`**

Below `perfStreams`:

```dart
/// Untraced time between pumping a scene and tracing it, so the first
/// build and the previous scene's teardown stay out of the window.
const settleTime = Duration(milliseconds: 250);
```

- [ ] **Step 14: Turn `layout_perf_test.dart` into the ABBA runner**

Overwrite `example/integration_test/layout_perf_test.dart` with:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'perf/perf_host.dart';
import 'perf/perf_kit.dart';
import 'perf/perf_scene.dart';
import 'perf/perf_scenes.dart';

/// The scene group this invocation traces (spec section 9.4).
const _group = int.fromEnvironment('PERF_GROUP', defaultValue: 1);

/// Traces one scene group in ABBA blocks of the frozen baseline and the
/// current layouts, after an untraced warm-up (spec section 9.4).
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  for (final step in abbaSteps(perfGroup(_group))) {
    testWidgets(step.name, (tester) async {
      final PerfKit kit = step.baseline
          ? const BaselineKit()
          : const CurrentKit();
      final scene = step.scene;
      await tester.pumpWidget(perfHost(scene.build(kit)));
      await scene.check?.call(tester, kit);
      await tester.pump(settleTime);
      if (step.traced) {
        await binding.traceAction(
          () => scene.drive(tester),
          streams: perfStreams,
          reportKey: step.reportKey,
        );
      } else {
        await scene.drive(tester);
      }
      expect(tester.takeException(), isNull);
    }, semanticsEnabled: false);
  }
}
```

- [ ] **Step 15: Analyze and smoke-run each group in debug mode**

Run: `flutter analyze --no-pub integration_test test`
Expected: `No issues found!`

Run, one group at a time:

```bash
for g in 1 2 3; do flutter test --no-pub integration_test/layout_perf_test.dart -d macos --dart-define=PERF_GROUP=$g > build/perf-logs/task3-g$g.log 2>&1; echo "group $g exit $?"; tail -3 build/perf-logs/task3-g$g.log; done
```

Expected: each group exits 0 with `All tests passed!`: group 1 runs 24 tests (8 warm-up, 16 traced), groups 2 and 3 run 18 each (6 warm-up, 12 traced).

- [ ] **Step 16: Commit**

```bash
cd "<repo>"
git add -- example/integration_test/baseline example/integration_test/perf example/integration_test/layout_perf_test.dart example/test/perf
git commit -m "feat(example): trace the benchmark in ABBA blocks against the frozen fd59ffa layouts" -- example/integration_test/baseline example/integration_test/perf example/integration_test/layout_perf_test.dart example/test/perf
```

---

### Task 4: `perf_abba` analysis and verdict

`sceneVerdict` is the owner's contribution (learning mode): the implementer writes the stub and its tests, then stops and asks the owner to fill it in.

**Files:**
- Create: `example/tool/perf_abba.dart`
- Test: `example/test/tool/perf_abba_test.dart`

**Interfaces:**
- Consumes: nothing from earlier tasks (the summary JSON keys of `TimelineSummary`).
- Produces, in `tool/perf_abba.dart`: constants `budget`, `maxAverageRise`, `maxIntervalDrift`, `groups` (`[1, 2, 3]`), `maxRuns` (12), `nullScene`, `abbaRoot`; `enum Verdict { pass, fail, inconclusive, invalid }`; record types `TraceMetrics`, `Trace`, `TracePair`, `ConfidenceInterval`; functions `metricsOf`, `traceOf`, `invalidRuns`, `pairTraces`, `averageChange`, `median`, `ciRank`, `medianInterval`, `withinBudget`, `nullGatePasses`, `sceneVerdict`, `overallVerdict`, `exitCodeOf`, `loadOf`, `readRuns`, `judge`; the CLI command `report`. Task 5 adds `run`.

- [ ] **Step 1: Write the failing test**

Create `example/test/tool/perf_abba_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import '../../tool/perf_abba.dart' hide main;

TraceMetrics _metrics({
  double average = 0.25,
  double p99Build = 0.5,
  double p99Raster = 3.5,
  double interval = 6.94,
}) {
  return (
    average: average,
    p99Build: p99Build,
    p99Raster: p99Raster,
    interval: interval,
  );
}

Trace _trace(
  String run,
  String scene,
  String side,
  int pair, {
  double average = 0.25,
  double interval = 6.94,
}) {
  return (
    run: run,
    scene: scene,
    side: side,
    pair: pair,
    metrics: _metrics(average: average, interval: interval),
  );
}

/// Pairs of [scene] over [changes], one pair per entry, in runs r1g1 on.
List<Trace> _pairs(String scene, List<double> changes) {
  return [
    for (var i = 0; i < changes.length; i++) ...[
      _trace('r${i + 1}g1', scene, 'base', 1, average: 0.2),
      _trace(
        'r${i + 1}g1',
        scene,
        'cand',
        1,
        average: 0.2 * (1 + changes[i] / 100),
      ),
    ],
  ];
}

/// The paired changes of the phase 3 S4 RCA (12 pairs, median −10.1%).
const _rcaS4 = [
  -46.1, -4.9, -6.5, -10.4, 7.3, 0.0, -48.2, -20.7, -14.2, -9.8, -21.6, -9.0,
];

void main() {
  group('ciRank', () {
    test('matches spec section 9.5', () {
      expect(ciRank(5), isNull);
      expect(ciRank(6), 1);
      expect(ciRank(12), 3);
      expect(ciRank(24), 7);
      expect(ciRank(36), 12);
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
    test('reads the three metrics and the median frame interval', () {
      final metrics = metricsOf({
        'average_frame_build_time_millis': 0.31,
        '99th_percentile_frame_build_time_millis': 1.02,
        '99th_percentile_frame_rasterizer_time_millis': 3.4,
        'frame_begin_times': [0, 6940, 13880, 20820, 40000],
      });
      expect(metrics.average, 0.31);
      expect(metrics.p99Build, 1.02);
      expect(metrics.p99Raster, 3.4);
      expect(metrics.interval, closeTo(6.94, 1e-9));
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

  group('pairTraces', () {
    test('pairs base and cand by run, scene, and pair number', () {
      final pairs = pairTraces([
        _trace('r1g1', 'S1', 'base', 1, average: 0.20),
        _trace('r1g1', 'S1', 'cand', 1, average: 0.22),
        _trace('r1g1', 'S1', 'cand', 2, average: 0.30),
        _trace('r1g1', 'S1', 'base', 2, average: 0.25),
        _trace('r2g1', 'S1', 'base', 1, average: 0.40),
        _trace('r2g1', 'S1', 'cand', 1, average: 0.38),
      ]);
      expect(
        [for (final pair in pairs['S1']!) (pair.base.average, pair.cand.average)],
        unorderedEquals([(0.20, 0.22), (0.25, 0.30), (0.40, 0.38)]),
      );
    });

    test('leaves a trace without its partner out', () {
      final pairs = pairTraces([
        _trace('r1g1', 'S1', 'base', 1),
        _trace('r1g1', 'S1', 'cand', 1),
        _trace('r1g1', 'S1', 'cand', 2),
      ]);
      expect(pairs['S1'], hasLength(1));
    });
  });

  group('invalidRuns', () {
    test('marks a run invalid when one trace\'s interval drifts', () {
      expect(
        invalidRuns([
          _trace('r1g1', 'S1', 'base', 1),
          _trace('r1g1', 'S1', 'cand', 1),
          _trace('r1g1', 'S2', 'base', 1),
          _trace('r1g1', 'S2', 'cand', 1, interval: 16.67),
          _trace('r2g1', 'S1', 'base', 1),
          _trace('r2g1', 'S1', 'cand', 1, interval: 7.3),
        ]),
        {'r1g1'},
      );
    });
  });

  group('averageChange', () {
    test('is the percent change from base to cand', () {
      expect(
        averageChange((base: _metrics(average: 0.2), cand: _metrics(average: 0.21))),
        closeTo(5, 1e-9),
      );
    });
  });

  group('withinBudget', () {
    TracePair pair(double base, double cand) => (
      base: _metrics(p99Build: base, p99Raster: 3),
      cand: _metrics(p99Build: cand, p99Raster: 3),
    );

    test('passes below 8.3 ms', () {
      expect(withinBudget([pair(1, 7.9)]), isTrue);
    });

    test('fails at or above 8.3 ms when the baseline was below', () {
      expect(withinBudget([pair(7, 8.3)]), isFalse);
    });

    test('accepts no worse than a baseline already over budget', () {
      expect(withinBudget([pair(9, 8.9)]), isTrue);
      expect(withinBudget([pair(9, 9.5)]), isFalse);
    });

    test('checks p99 raster too', () {
      expect(
        withinBudget([
          (
            base: _metrics(p99Raster: 3),
            cand: _metrics(p99Raster: 8.4),
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

    test('is inconclusive when the interval straddles +5% or is missing',
        () {
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
      expect(
        sceneVerdict(ci: null, p99WithinBudget: false),
        Verdict.fail,
      );
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
      expect(loadOf(' 10:00:00 up 1 day,  load average: 0.52, 0.40, 0.31'),
          0.52);
      expect(loadOf('no load here'), isNull);
    });
  });

  group('judge', () {
    test('passes S4 on the RCA data behind a quiet null control', () {
      final result = judge([
        ..._pairs('S2-plain', [-3, 2, -1, 4, 0.5, -2]),
        ..._pairs('S4', _rcaS4),
      ], loads: [9.1, 16.4]);
      expect(result.verdict, Verdict.pass);
      expect(result.text, contains('| S4 | 12 |'));
      expect(result.text, contains('[-21.6, -4.9]'));
      expect(result.text, contains('| S2-plain (null) | 6 |'));
      expect(result.text, contains('load 9.1–16.4'));
      expect(result.text, contains('overall: PASS'));
    });

    test('is INVALID when the null interval misses 0', () {
      final result = judge([
        ..._pairs('S2-plain', [3, 2, 1, 4, 5, 2]),
        ..._pairs('S4', _rcaS4),
      ], loads: const []);
      expect(result.verdict, Verdict.invalid);
      expect(result.text, contains('overall: INVALID'));
    });

    test('leaves an invalid run out and lists it', () {
      final result = judge([
        ..._pairs('S2-plain', [-3, 2, -1, 4, 0.5, -2]),
        ..._pairs('S4', _rcaS4),
        _trace('r99g1', 'S4', 'base', 1),
        _trace('r99g1', 'S4', 'cand', 1, interval: 16.67),
        _trace('r99g1', 'S4', 'base', 2),
        _trace('r99g1', 'S4', 'cand', 2),
      ], loads: const []);
      expect(result.text, contains('| S4 | 12 |'));
      expect(result.text, contains('invalid runs: r99g1'));
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test --no-pub test/tool/perf_abba_test.dart`
Expected: FAIL at compile time: `Error when reading 'tool/perf_abba.dart': No such file or directory`.

- [ ] **Step 3: Write `tool/perf_abba.dart` with a `sceneVerdict` stub**

```dart
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

/// Frame budget at 120 Hz, in milliseconds (spec section 9.5).
const budget = 8.3;

/// Largest accepted rise of the average build time, in percent.
const maxAverageRise = 5.0;

/// Largest distance of a trace's frame interval from its run's median
/// interval, as a fraction of the median.
const maxIntervalDrift = 0.1;

/// Scene groups per run: the keys of `perfGroups` in
/// `integration_test/perf/perf_scenes.dart`.
const groups = [1, 2, 3];

/// Most runs one comparison holds: 24 pairs per scene (spec section 9.5).
const maxRuns = 12;

/// The null-control scene, judged only by the null gate.
const nullScene = 'S2-plain';

/// Root of the run folders, relative to `example/`.
const abbaRoot = 'build/perf/abba';

const _usage =
    'usage: dart run tool/perf_abba.dart report\n'
    '       dart run tool/perf_abba.dart run --runs <n> [--from <first>]';

/// The verdict of a scene or a comparison (spec section 9.5).
enum Verdict { pass, fail, inconclusive, invalid }

/// The metrics read from one `TimelineSummary`; the interval is the median
/// gap between frame starts, in milliseconds.
typedef TraceMetrics = ({
  double average,
  double p99Build,
  double p99Raster,
  double interval,
});

/// One trace: its run folder (`r<run>g<group>`) and its report key.
typedef Trace = ({
  String run,
  String scene,
  String side,
  int pair,
  TraceMetrics metrics,
});

/// A baseline trace and the current trace it pairs with.
typedef TracePair = ({TraceMetrics base, TraceMetrics cand});

/// A 95% interval for the median paired change, in percent.
typedef ConfidenceInterval = ({double lower, double upper});

/// Judges the in-process ABBA benchmark (spec section 9.5).
///
/// Usage, from `example/`: `dart run tool/perf_abba.dart report` judges
/// the runs stored under `build/perf/abba/`, prints the report, writes it
/// to `build/perf/abba/report.md`, and exits with 0 for PASS, 1 for FAIL or
/// INVALID, and 2 for INCONCLUSIVE.
Future<void> main(List<String> args) async {
  switch (args) {
    case ['report']:
      exitCode = _report();
    default:
      stderr.writeln(_usage);
      exitCode = 64;
  }
}

int _report() {
  final root = Directory(abbaRoot);
  if (!root.existsSync()) {
    stderr.writeln('no runs in $abbaRoot');
    return 64;
  }
  final (:traces, :loads) = readRuns(root);
  final result = judge(traces, loads: loads);
  stdout.write(result.text);
  File('$abbaRoot/report.md').writeAsStringSync(result.text);
  return exitCodeOf(result.verdict);
}

/// Reads the metrics of one `*.timeline_summary.json` map.
TraceMetrics metricsOf(Map<String, dynamic> summary) {
  final begins = (summary['frame_begin_times'] as List).cast<num>();
  double read(String key) => (summary[key] as num).toDouble();
  return (
    average: read('average_frame_build_time_millis'),
    p99Build: read('99th_percentile_frame_build_time_millis'),
    p99Raster: read('99th_percentile_frame_rasterizer_time_millis'),
    interval: median([
      for (var i = 1; i < begins.length; i++)
        (begins[i] - begins[i - 1]) / 1000,
    ]),
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

/// Runs with a trace whose frame interval differs by more than
/// [maxIntervalDrift] from the run's median interval.
Set<String> invalidRuns(List<Trace> traces) {
  final byRun = <String, List<Trace>>{};
  for (final trace in traces) {
    (byRun[trace.run] ??= []).add(trace);
  }
  return {
    for (final MapEntry(key: run, value: runTraces) in byRun.entries)
      if (_drifts(runTraces)) run,
  };
}

bool _drifts(List<Trace> traces) {
  final middle = median([for (final t in traces) t.metrics.interval]);
  return traces.any(
    (t) => (t.metrics.interval - middle).abs() > middle * maxIntervalDrift,
  );
}

/// Scene to its pairs: the `base` and `cand` traces with the same run,
/// scene, and pair number. A trace without its partner is left out.
Map<String, List<TracePair>> pairTraces(List<Trace> traces) {
  final sides = <(String, String, int), Map<String, TraceMetrics>>{};
  for (final trace in traces) {
    (sides[(trace.run, trace.scene, trace.pair)] ??= {})[trace.side] =
        trace.metrics;
  }
  final pairs = <String, List<TracePair>>{};
  for (final MapEntry(key: (_, scene, _), value: bySide) in sides.entries) {
    final base = bySide['base'];
    final cand = bySide['cand'];
    if (base != null && cand != null) {
      (pairs[scene] ??= []).add((base: base, cand: cand));
    }
  }
  return pairs;
}

/// The pair's change in average build time, in percent.
double averageChange(TracePair pair) {
  return (pair.cand.average / pair.base.average - 1) * 100;
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

/// Whether the current side keeps the p99 budget for build and for raster
/// (spec section 9.5).
bool withinBudget(List<TracePair> pairs) {
  bool keeps(double Function(TraceMetrics metrics) metric) {
    final base = median([for (final p in pairs) metric(p.base)]);
    final cand = median([for (final p in pairs) metric(p.cand)]);
    final delta = median([
      for (final p in pairs) metric(p.cand) - metric(p.base),
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
/// [ci] is null when the scene has fewer than 6 pairs.
Verdict sceneVerdict({
  required ConfidenceInterval? ci,
  required bool p99WithinBudget,
}) {
  // TODO(owner): spec section 9.5, average build and budget rules.
  throw UnimplementedError('sceneVerdict');
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

/// Every trace and recorded load under [root].
({List<Trace> traces, List<double> loads}) readRuns(Directory root) {
  final traces = <Trace>[];
  final loads = <double>[];
  for (final directory in root.listSync().whereType<Directory>()) {
    final run = directory.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
    final loadFile = File('${directory.path}/load.txt');
    final load = loadFile.existsSync()
        ? loadOf(loadFile.readAsStringSync())
        : null;
    if (load != null) loads.add(load);
    for (final file in directory.listSync().whereType<File>()) {
      final name = file.uri.pathSegments.last;
      if (!name.endsWith('.timeline_summary.json')) continue;
      final summary =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final trace = traceOf(run, name, metricsOf(summary));
      if (trace != null) traces.add(trace);
    }
  }
  return (traces: traces, loads: loads);
}

/// Judges [traces] and returns the report text and the overall verdict.
({String text, Verdict verdict}) judge(
  List<Trace> traces, {
  required List<double> loads,
}) {
  final invalid = invalidRuns(traces);
  final valid = [
    for (final trace in traces)
      if (!invalid.contains(trace.run)) trace,
  ];
  final pairs = pairTraces(valid);
  final nullCi = medianInterval([
    for (final pair in pairs[nullScene] ?? const <TracePair>[])
      averageChange(pair),
  ]);
  final gate = nullGatePasses(nullCi);
  final rows = <String>[];
  final verdicts = <Verdict>[];
  for (final scene in pairs.keys.toList()..sort()) {
    final scenePairs = pairs[scene]!;
    final ci = medianInterval([for (final p in scenePairs) averageChange(p)]);
    final String verdictText;
    if (scene == nullScene) {
      verdictText = gate ? 'null ok' : 'null INVALID';
    } else {
      final verdict = sceneVerdict(
        ci: ci,
        p99WithinBudget: withinBudget(scenePairs),
      );
      verdicts.add(verdict);
      verdictText = verdict.name.toUpperCase();
    }
    rows.add(_row(scene, scenePairs, ci, verdictText));
  }
  final verdict = overallVerdict(nullGate: gate, scenes: verdicts);
  final runs = {for (final trace in valid) trace.run.split('g').first};
  final invocations = {for (final trace in valid) trace.run};
  final intervals = [for (final trace in valid) trace.metrics.interval];
  final text = StringBuffer()
    ..writeln(
      'runs ${runs.length} (${invocations.length} invocations), '
      'load ${_range(loads)}, '
      'interval ${intervals.isEmpty ? '-' : _ms(median(intervals))} ms, '
      'null resolution '
      '${nullCi == null ? '-' : '±${_pct((nullCi.upper - nullCi.lower) / 2)}%'}',
    );
  if (invalid.isNotEmpty) {
    text.writeln('invalid runs: ${(invalid.toList()..sort()).join(', ')}');
  }
  text
    ..writeln(
      '| scene | pairs | avg build ms base → cand | median Δ% | 95% CI '
      '| p99 build ms | p99 raster ms | verdict |',
    )
    ..writeln('|---|---|---|---|---|---|---|---|')
    ..writeAll(rows.map((row) => '$row\n'))
    ..writeln('overall: ${verdict.name.toUpperCase()}');
  return (text: text.toString(), verdict: verdict);
}

String _row(
  String scene,
  List<TracePair> pairs,
  ConfidenceInterval? ci,
  String verdict,
) {
  String sides(double Function(TraceMetrics m) metric) =>
      '${_ms(median([for (final p in pairs) metric(p.base)]))} → '
      '${_ms(median([for (final p in pairs) metric(p.cand)]))}';
  final name = scene == nullScene ? '$scene (null)' : scene;
  final change = median([for (final p in pairs) averageChange(p)]);
  final interval = ci == null
      ? '-'
      : '[${_pct(ci.lower)}, ${_pct(ci.upper)}]';
  return '| $name | ${pairs.length} | ${sides((m) => m.average)} '
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

- [ ] **Step 4: Run the test to see only the `sceneVerdict` cases fail**

Run: `flutter test --no-pub test/tool/perf_abba_test.dart`
Expected: FAIL. The `sceneVerdict` group (4 tests) and the `judge` group (3 tests) fail with `UnimplementedError: sceneVerdict`; every other test passes.

- [ ] **Step 5: Owner contribution: `sceneVerdict`**

Stop and ask the owner to replace the stub body in `example/tool/perf_abba.dart`. Give them this brief:

> `sceneVerdict` decides one scene from its average-build interval and its p99 budget check. The spec fixes the rules (section 9.5): PASS when `ci.upper <= maxAverageRise`; FAIL when `ci.lower > maxAverageRise`; INCONCLUSIVE otherwise, including `ci == null` (fewer than 6 pairs); a missed budget FAILs whatever the interval says. The `sceneVerdict` group in `test/tool/perf_abba_test.dart` pins every case. About 5 to 8 lines.

If the owner declines, use this body, which the spec requires:

```dart
  if (!p99WithinBudget) return Verdict.fail;
  if (ci == null) return Verdict.inconclusive;
  if (ci.upper <= maxAverageRise) return Verdict.pass;
  if (ci.lower > maxAverageRise) return Verdict.fail;
  return Verdict.inconclusive;
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `flutter test --no-pub test/tool/perf_abba_test.dart`
Expected: PASS, 25 tests.

- [ ] **Step 7: Analyze**

Run: `flutter analyze --no-pub tool test/tool`
Expected: `No issues found!`

- [ ] **Step 8: Commit**

```bash
cd "<repo>"
git add -- example/tool/perf_abba.dart example/test/tool/perf_abba_test.dart
git commit -m "feat(example): judge ABBA benchmark runs on a median confidence interval" -- example/tool/perf_abba.dart example/test/tool/perf_abba_test.dart
```

---

### Task 5: `perf_abba run`, the driver's run folders, and a dry run

**Files:**
- Modify: `example/tool/perf_abba.dart` (`main`, new `runRangeError`, `clashingRuns`, `_run`, `_option`)
- Modify: `example/test_driver/perf_driver.dart:1-30`
- Delete: `example/tool/perf_pairs.dart`, `example/tool/perf_median.dart`
- Test: `example/test/tool/perf_abba_test.dart`, `example/test/perf/perf_scene_test.dart`

**Interfaces:**
- Consumes: Task 3's runner (`--dart-define=PERF_GROUP`, report keys) and `perfGroups`; Task 4's `abbaRoot`, `groups`, `maxRuns`, `_report`.
- Produces: `String? runRangeError({required int from, required int runs})`, `List<String> clashingRuns(Directory root, {required int from, required int runs})`, and the CLI `dart run tool/perf_abba.dart run --runs <n> [--from <first>]`; the driver writes to `build/perf/abba/r<PERF_RUN>g<PERF_GROUP>/`.

- [ ] **Step 1: Write the failing tests**

Append to the `main` of `example/test/tool/perf_abba_test.dart` (add `import 'dart:io';` at the top):

```dart
  group('runRangeError', () {
    test('accepts runs within the cap of 24 pairs', () {
      expect(runRangeError(from: 1, runs: 6), isNull);
      expect(runRangeError(from: 7, runs: 6), isNull);
    });

    test('refuses runs beyond the cap or outside 1', () {
      expect(runRangeError(from: 7, runs: 7), contains('1 to 12'));
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
      expect(
        clashingRuns(root, from: 1, runs: 6),
        ['${root.path}/r2g3'],
      );
      expect(clashingRuns(root, from: 3, runs: 4), isEmpty);
    });
  });
```

Append to the `perfGroups` group of `example/test/perf/perf_scene_test.dart` (add `import '../../tool/perf_abba.dart' show groups;` at the top):

```dart
    test('matches the groups perf_abba runs', () {
      expect(perfGroups.keys, groups);
    });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test --no-pub test/tool/perf_abba_test.dart`
Expected: FAIL at compile time: `Method not found: 'runRangeError'`.

Run: `flutter test --no-pub test/perf/perf_scene_test.dart`
Expected: PASS, 6 tests (`groups` exists since Task 4; this test pins the two lists together).

- [ ] **Step 3: Add `run` to `tool/perf_abba.dart`**

Replace `main` and its doc comment with:

```dart
/// Runs and judges the in-process ABBA benchmark (spec section 9.5).
///
/// Usage, from `example/`:
/// - `dart run tool/perf_abba.dart run --runs 6` runs `flutter drive` once
///   per run and group, recording `uptime` before each, then reports.
/// - `dart run tool/perf_abba.dart run --from 7 --runs 6` adds the one
///   escalation, up to 12 runs (24 pairs per scene).
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
        '(24 pairs per scene)';
  }
  return null;
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
  for (var run = from; run < from + runs; run++) {
    for (final group in groups) {
      final directory = Directory('$abbaRoot/r${run}g$group')
        ..createSync(recursive: true);
      final uptime = await Process.run('uptime', const []);
      final load = (uptime.stdout as String).trim();
      File('${directory.path}/load.txt').writeAsStringSync(load);
      stdout.writeln('run $run group $group: $load');
      final drive = await Process.start(
        'flutter',
        [
          'drive',
          '--profile',
          '--endless-trace-buffer',
          '-d',
          'macos',
          '--driver=test_driver/perf_driver.dart',
          '--target=integration_test/layout_perf_test.dart',
          '--dart-define=PERF_GROUP=$group',
        ],
        environment: {'PERF_RUN': '$run', 'PERF_GROUP': '$group'},
        mode: ProcessStartMode.inheritStdio,
      );
      final code = await drive.exitCode;
      if (code != 0) {
        stderr.writeln(
          'flutter drive exited $code on run $run group $group; '
          'rm -rf $abbaRoot/r${run}g* and pass --from $run to continue',
        );
        return 1;
      }
    }
  }
  return _report();
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test --no-pub test/tool/perf_abba_test.dart`
Expected: PASS, 28 tests.

- [ ] **Step 5: Point the driver at the run folders**

In `example/test_driver/perf_driver.dart`, replace lines 1 to 30 (the imports, `_traceWindow`, and `main`) with:

```dart
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart' as driver;
import 'package:integration_test/integration_test_driver.dart';

/// Length of every traced window: `traceWindow` in
/// `integration_test/perf/perf_host.dart`.
const _traceWindow = Duration(seconds: 2);

/// Writes one timeline and one summary per report key into
/// `build/perf/abba/r<PERF_RUN>g<PERF_GROUP>/`, the run folder that
/// `tool/perf_abba.dart` reads.
Future<void> main() {
  final run = Platform.environment['PERF_RUN'] ?? '0';
  final group = Platform.environment['PERF_GROUP'] ?? '0';
  return integrationDriver(
    responseDataCallback: (data) async {
      if (data == null) return;
      for (final entry in data.entries) {
        final timeline = driver.Timeline.fromJson(
          entry.value as Map<String, dynamic>,
        );
        final summary = driver.TimelineSummary.summarize(timeline);
        _checkCoverage(entry.key, summary.summaryJson);
        await summary.writeTimelineToFile(
          entry.key,
          destinationDirectory: 'build/perf/abba/r${run}g$group',
        );
      }
    },
  );
}
```

`_checkCoverage` stays as it is. `pretty` now takes its default, false.

- [ ] **Step 6: Delete the tools of the old method**

Run: `cd "<repo>" && git rm -q -- example/tool/perf_pairs.dart example/tool/perf_median.dart`

- [ ] **Step 7: Analyze**

Run: `flutter analyze --no-pub integration_test test_driver tool test`
Expected: `No issues found!`

- [ ] **Step 8: Dry run: one run of three invocations**

Run:

```bash
rm -rf build/perf/abba
mkdir -p build/perf-logs
/usr/bin/time -p dart run tool/perf_abba.dart run --runs 1 > build/perf-logs/abba-dry.log 2>&1; echo "exit $?"
tail -20 build/perf-logs/abba-dry.log
du -sh build/perf/abba
```

Expected: three `flutter drive` invocations finish; the report lists S1, S1-fast, S2, S2-box, S3, S4, and S5 with 2 pairs and S2-plain with 6; every scene is `INCONCLUSIVE` (no interval below 6 pairs); `overall: INCONCLUSIVE` with exit 2, or `overall: INVALID` with exit 1 when the six S2-plain changes share one sign. Either exit is a successful dry run.

If group 1 (16 traces) fails while the driver reads the report data, split it: in `perf/perf_scenes.dart` set `perfGroups` to `{1: ['S2-plain', 'S1', 'S1-fast'], 2: ['S2-plain', 'S2'], 3: ['S2-plain', 'S2-box', 'S3'], 4: ['S2-plain', 'S4', 'S5']}`, set `groups` in `tool/perf_abba.dart` to `[1, 2, 3, 4]`, change the `perfGroups.keys` expectation in `perf_scene_test.dart` to `[1, 2, 3, 4]`, rerun this step, and record the change for spec section 9.4.

- [ ] **Step 9: Record the dry-run measurements**

From the log, note the `real` seconds, divided by 3 for one invocation, and the `du` size of one run. Main session: add them to the project memory entry (Task 6, Step 4), and tell the owner if a 6-run comparison would take over 45 minutes.

Then run: `rm -rf build/perf/abba`

- [ ] **Step 10: Commit**

```bash
cd "<repo>"
git add -- example/tool/perf_abba.dart example/test/tool/perf_abba_test.dart example/test/perf/perf_scene_test.dart example/test_driver/perf_driver.dart
git commit -m "feat(example): run the ABBA benchmark per group and drop the separate-run tools" -- example/tool/perf_abba.dart example/test/tool/perf_abba_test.dart example/test/perf/perf_scene_test.dart example/test_driver/perf_driver.dart example/tool/perf_pairs.dart example/tool/perf_median.dart
```

If Step 8 split the groups, add `example/integration_test/perf/perf_scenes.dart` to both path lists.

---

### Task 6: Phase 3 comparison and records

The main session runs this task: it waits on a long background run, may need owner rulings, and writes outside the repository.

**Files:**
- Modify: `.claude/agent-memory/core-pack-root-cause-analyst-agent/project_benchmark_noise.md`, `.claude/agent-memory/core-pack-root-cause-analyst-agent/MEMORY.md` (first commit of both)
- Modify, outside the repository: `profile/memory/project_stratum_ui_layout_primitives.md` and `profile/memory/ROADMAP.md` in the NTD OS root

**Interfaces:**
- Consumes: Task 5's CLI and exit codes.
- Produces: the phase 3 verdict in the project memory entry; the closed `benchmark-in-process` milestone.

- [ ] **Step 1: Start the comparison in the background**

Run in the background (watch-lane), from `example/`:

```bash
rm -rf build/perf/abba && dart run tool/perf_abba.dart run --runs 6 > build/perf-logs/abba-p3.log 2>&1; echo "exit $?" >> build/perf-logs/abba-p3.log
```

- [ ] **Step 2: Read the verdict**

Run: `tail -16 build/perf-logs/abba-p3.log`

Act on the last line:
- `exit 0` (PASS): go to Step 4.
- `exit 2` (INCONCLUSIVE): run `dart run tool/perf_abba.dart run --from 7 --runs 6 > build/perf-logs/abba-p3-escalation.log 2>&1; echo "exit $?" >> build/perf-logs/abba-p3-escalation.log` in the background, then read its tail. If it ends in `exit 2` again, show the owner the report and wait for a ruling on the inconclusive scenes (spec section 9.5).
- `exit 1` with `overall: INVALID`: rerun Step 1 once. A second INVALID goes to the owner.
- `exit 1` with `overall: FAIL`: show the owner the report and the failing rows; do not change library code. The per-phase split in the stored `build/perf/abba/r*g*/*.timeline.json` files is the next diagnostic.

- [ ] **Step 3: Keep the report**

Run: `cat build/perf/abba/report.md`

- [ ] **Step 4: Record the verdict in project memory**

In `profile/memory/project_stratum_ui_layout_primitives.md` (NTD OS root), add a section above "2026-10-01 — Benchmark section 9 amended to in-process ABBA":

```markdown
## <ISO date> — Phase 3 ABBA rerun: <PASS | owner ruling>

**Fact:** `perf_abba` compared fd59ffa (frozen) against <HEAD short hash> in <runs> runs, load <range>, interval <ms> ms, null resolution ±<x>%. <One line per scene from report.md: scene, median Δ%, interval, verdict.> Dry run: <seconds> s per invocation, <size> per run.
**Why:** Done-when of the `benchmark-in-process` milestone (spec section 9).
**How to apply:** Phase 4 freezes the phase 3 tip (the commit it starts from) with `perf_freeze`, updates `BaselineKit` to that API, and runs the same comparison for its done-when.
```

Bump `verified:` in the frontmatter to the current date.

- [ ] **Step 5: Close the roadmap milestone**

In `profile/memory/ROADMAP.md` (NTD OS root), re-read the file, then delete the `### benchmark-in-process` milestone (its `done-when` holds), delete the `after: benchmark-in-process` line of `### p4-keyboard-a11y`, and bump `updated:`.

- [ ] **Step 6: Commit the root-cause agent's memory**

In `.claude/agent-memory/core-pack-root-cause-analyst-agent/project_benchmark_noise.md`, replace the last paragraph with:

```markdown
**How to apply:** when a benchmark scene fails, first split the stored `example/build/perf/abba/r*g*/<scene>.<side>.<pair>.timeline.json` into per-phase means. If engine and raster phases rise as much as BUILD, suspect the environment. The benchmark itself compares in one process (spec section 9 of `docs/superpowers/specs/2026-10-01-layout-primitives-design.md`, tools `example/tool/perf_freeze.dart` and `example/tool/perf_abba.dart`), and its S2-plain null control shows each invocation's noise. See [[stratum-layout-primitives]].
```

Set `verified:` to the current date. In `MEMORY.md` of the same folder, replace the index line with:

```markdown
- [Benchmark noise on the shared Mac](project_benchmark_noise.md) — sub-ms deltas are noise-dominated; split phases, then trust the spec section 9 in-process ABBA verdict
```

Run:

```bash
cd "<repo>"
git add -- .claude/agent-memory/core-pack-root-cause-analyst-agent
git commit -m "chore(agents): keep the root-cause agent's benchmark-noise memory" -- .claude/agent-memory/core-pack-root-cause-analyst-agent
```
