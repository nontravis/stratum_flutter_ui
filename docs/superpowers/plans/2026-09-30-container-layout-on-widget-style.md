# ContainerLayout on WidgetStyle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild `ContainerLayout` on `AnimatedStyledBox` so every visual value comes from one `WidgetStyle`, then move its ten callers from 24 to 26 flat style parameters each to a single `style` parameter.

**Architecture:** `ContainerLayout` keeps only per-instance parameters (ratio, rotate, transform, keep-alive, repaint boundary, debug, semantics, `onEndAnimate`) and hands `style` to `AnimatedStyledBox`, which the phase 1 plan built and tested. Callers stop declaring style fields and forward `style`. `ContainerLayout`, `WidgetPerformanceMonitor`, and the four plain layouts (column, row, stack, wrap) move to narrow imports so their widget tests load; the gesture layouts and `AppCustomScrollView` stay on the `src.dart` barrel and are verified with `flutter analyze` until the green build lands.

**Tech Stack:** Flutter 3.47.3, Dart ^3.13.3, flutter_test.

**Spec:** `docs/superpowers/specs/2026-09-30-container-layout-widget-style-design.md` (sections 3, 4, 5, 8, 9, and 11 phases 2 and 3)

## Global Constraints

- Work in the main working tree, not a git worktree; the tree holds owner work in progress that this plan must not disturb.
- `container_layout.dart`, `widget_performance_monitor.dart`, `column_layout.dart`, `row_layout.dart`, `stack_layout.dart`, and `wrap_layout.dart` import only `package:flutter/...`, `dart:math`, and `package:stratum_ui/src/components/...` files, never `package:stratum_ui/src/src.dart`. The gesture layouts and `custom_scroll_view.dart` keep the barrel import.
- Lints come from very_good_analysis 11: package imports only, lines at most 80 characters.
- Keep each modified file's existing constructor declaration style; the rewritten `ContainerLayout` keeps its `const new(` form.
- Run tests with `flutter test --no-pub <file>` on the listed files only; a bare `flutter test` fails on pre-existing barrel errors.
- Verify barrel-bound files with `flutter analyze --no-pub <paths>`.
- Commit with explicit paths: `git add -- <paths>` then `git commit -m "<message>" -- <paths>`. Never commit `pubspec.yaml`, `lib/src/src.dart`, the base widgets, theme files, `focus_spread.dart`, `common.dart`, or `animated_styled_box.dart`; they hold owner work in progress.
- Conventional Commits with a scope; no `Co-Authored-By` line and no AI attribution.
- A null curve in a style animation falls back to `Curves.easeInOutSine` (owner ruling 2026-09-30, already in `AnimatedStyledBox`).
- Callers keep their own layout parameters. Stack and Wrap keep `alignment` and `clipBehavior` because those configure the `Stack` or `Wrap`; the box's own clip and alignment come from `style`.

## Review Focus

- A `ContainerLayout` whose `rotate` changes from 0 to 90 must keep its child's `State`; only a switch between null and a value may rebuild it. Pinned in Task 1.
- `keepAlive: true` inside a `ListView` must keep a scrolled-away item's `State`, and outside a list must not throw. Pinned in Task 1.
- A scrollable `ColumnLayout` whose style sets a height must lay out without an error. Pinned in Task 2.
- A `StackLayout` given only `semantics` must still apply the semantics (the old widget dropped them). Pinned in Task 3.
- `onEndAnimate` passed to a layout widget must fire once when its style animation ends. Pinned in Tasks 1 and 2.

Deferred verification: `GestureContainerLayout`, the gesture layouts, and `AppCustomScrollView` import the barrel, so their widget tests (hover animation default, `InkWell` radius, focus ring radius) wait for the green-build plan.

---

### Task 1: ContainerLayout on AnimatedStyledBox

**Files:**
- Modify: `lib/src/components/common/layout/container_layout.dart` (whole file)
- Modify: `lib/src/components/common/widget_performance_monitor.dart:1`
- Create: `test/src/components/common/layout/container_layout_test.dart`

**Interfaces:**
- Consumes: `AnimatedStyledBox({Key? key, WidgetStyle? style, double? ratio, Matrix4? transform, AlignmentGeometry? transformAlignment, VoidCallback? onEnd, Widget? child})`; `WidgetStyle`.
- Produces: `const ContainerLayout({Key? key, WidgetStyle? style, double? ratio, double? rotate, Matrix4? transform, AlignmentGeometry? transformAlignment, bool keepAlive = false, bool repaintBoundary = false, bool debug = false, SemanticsProperties? semantics, VoidCallback? onEndAnimate, Widget? child})`.

- [ ] **Step 1: Record the analyzer baseline**

Run: `flutter analyze --no-pub lib > /tmp/analyze_plan2_before.txt 2>&1; grep -c '^ *error' /tmp/analyze_plan2_before.txt; grep '^ *error' /tmp/analyze_plan2_before.txt | grep -c custom_scroll_view`
Expected: two numbers; write both down. They were `84` and `7` when this plan was written.

- [ ] **Step 2: Write the failing tests**

Create `test/src/components/common/layout/container_layout_test.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/layout/container_layout.dart';
import 'package:stratum_ui/src/components/common/widget_performance_monitor.dart';
import 'package:stratum_ui/src/components/common/model/widget_style.dart';
import 'package:stratum_ui/src/components/common/style/animated_styled_box.dart';

const _style = WidgetStyle(
  backgroundColor: Color(0xFFFFFFFF),
  padding: EdgeInsets.all(8),
);

Widget _host(Widget child) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Center(child: child),
  );
}

Finder _inside(Type type) {
  return find.descendant(
    of: find.byType(ContainerLayout),
    matching: find.byType(type),
  );
}

void main() {
  group('ContainerLayout', () {
    testWidgets('hands style and layout values to AnimatedStyledBox',
        (tester) async {
      final transform = Matrix4.translationValues(4, 0, 0);
      await tester.pumpWidget(
        _host(
          ContainerLayout(
            style: _style,
            ratio: 2,
            transform: transform,
            child: const SizedBox(width: 40, height: 20),
          ),
        ),
      );

      final box = tester.widget<AnimatedStyledBox>(
        find.byType(AnimatedStyledBox),
      );
      expect(box.style, _style);
      expect(box.ratio, 2);
      expect(box.transform, transform);
    });

    testWidgets('adds no outer wrappers by default', (tester) async {
      await tester.pumpWidget(_host(const ContainerLayout(style: _style)));

      for (final type in const [
        Semantics,
        RepaintBoundary,
        WidgetPerformanceMonitor,
        Transform,
      ]) {
        expect(_inside(type), findsNothing, reason: '$type');
      }
    });

    testWidgets('rotate turns degrees into an exact quarter turn',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const ContainerLayout(
            rotate: 90,
            child: SizedBox(width: 40, height: 20),
          ),
        ),
      );

      final transform = tester.widget<Transform>(_inside(Transform)).transform;
      expect(transform.entry(1, 0), 1.0);
    });

    testWidgets('changing rotate from 0 keeps the child State', (tester) async {
      await tester.pumpWidget(
        _host(const ContainerLayout(rotate: 0, child: _Probe())),
      );
      final before = tester.state(find.byType(_Probe));

      await tester.pumpWidget(
        _host(const ContainerLayout(rotate: 90, child: _Probe())),
      );

      expect(identical(tester.state(find.byType(_Probe)), before), isTrue);
    });

    testWidgets('keepAlive outside a lazy list does not throw',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const ContainerLayout(
            keepAlive: true,
            child: SizedBox(width: 40, height: 20),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('keepAlive keeps a scrolled-away item alive in a ListView',
        (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ListView(
            children: const [
              ContainerLayout(keepAlive: true, child: _Probe()),
              SizedBox(height: 2000),
            ],
          ),
        ),
      );
      final before = tester.state(find.byType(_Probe));

      await tester.drag(find.byType(ListView), const Offset(0, -1500));
      await tester.pump();

      final probe = find.byType(_Probe, skipOffstage: false);
      expect(probe, findsOneWidget);
      expect(identical(tester.state(probe), before), isTrue);
    });

    testWidgets('onEndAnimate fires once after a style animation',
        (tester) async {
      var ends = 0;
      Widget build(Color color) {
        return _host(
          ContainerLayout(
            style: WidgetStyle(
              backgroundColor: color,
              animationStyle: const AnimationStyle(
                duration: Duration(milliseconds: 100),
              ),
            ),
            onEndAnimate: () => ends++,
          ),
        );
      }

      await tester.pumpWidget(build(const Color(0xFFFF0000)));
      await tester.pumpWidget(build(const Color(0xFF0000FF)));
      await tester.pumpAndSettle();

      expect(ends, 1);
    });

    testWidgets('semantics, repaintBoundary, and debug add their wrappers',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const ContainerLayout(
            semantics: SemanticsProperties(label: 'card'),
            repaintBoundary: true,
            debug: true,
            child: SizedBox(width: 40, height: 20),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.label == 'card',
        ),
        findsOneWidget,
      );
      expect(_inside(RepaintBoundary), findsOneWidget);
      expect(_inside(WidgetPerformanceMonitor), findsOneWidget);
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

- [ ] **Step 3: Run the tests to verify they fail**

Run: `flutter test --no-pub test/src/components/common/layout/container_layout_test.dart`
Expected: FAIL to load with compile errors that come from the `src.dart` barrel `container_layout.dart` imports today (for example `'BaseResponse' is exported from both`).

- [ ] **Step 4: Move `widget_performance_monitor.dart` off the barrel**

Replace line 1 (`import 'package:stratum_ui/src/src.dart';`) with:

```dart
import 'package:flutter/material.dart';
```

- [ ] **Step 5: Rewrite `container_layout.dart`**

Replace the whole file with:

```dart
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:stratum_ui/src/components/common/widget_performance_monitor.dart';
import 'package:stratum_ui/src/components/common/model/widget_style.dart';
import 'package:stratum_ui/src/components/common/style/animated_styled_box.dart';

/// A box that paints a [WidgetStyle] around [child].
///
/// Every visual value (spacing, size, fill, border, shadows, blur, opacity,
/// and animation) comes from [style], which [AnimatedStyledBox] builds and
/// animates. The other parameters cover what a style cannot: per-instance
/// layout, behavior, and accessibility.
class ContainerLayout extends StatelessWidget {
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
    this.child,
  });

  final WidgetStyle? style;

  /// Width divided by height for the child.
  final double? ratio;

  /// Clockwise rotation in degrees.
  ///
  /// Switching between null and a value adds or removes a wrapper and
  /// rebuilds the subtree; pass 0 when the rotation may change later.
  final double? rotate;
  final Matrix4? transform;
  final AlignmentGeometry? transformAlignment;

  /// Keeps this box alive when a lazy list scrolls it away.
  final bool keepAlive;
  final bool repaintBoundary;
  final bool debug;
  final SemanticsProperties? semantics;

  /// Called when a style animation completes.
  final VoidCallback? onEndAnimate;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    Widget content = AnimatedStyledBox(
      style: style,
      ratio: ratio,
      transform: transform,
      transformAlignment: transformAlignment,
      onEnd: onEndAnimate,
      child: child,
    );
    final degrees = rotate;
    if (degrees != null) {
      content = Transform.rotate(
        angle: degrees * math.pi / 180,
        child: content,
      );
    }
    if (repaintBoundary) {
      content = RepaintBoundary(child: content);
    }
    if (debug) {
      content = WidgetPerformanceMonitor(child: content);
    }
    if (keepAlive) {
      content = _KeepAlive(child: content);
    }
    final properties = semantics;
    if (properties != null) {
      content = Semantics.fromProperties(
        properties: properties,
        child: content,
      );
    }
    return content;
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

- [ ] **Step 6: Run the tests to verify they pass**

Run: `flutter test --no-pub test/src/components/common/layout/container_layout_test.dart`
Expected: PASS, `+8: All tests passed!`

- [ ] **Step 7: Analyze the two files and the test**

Run: `flutter analyze --no-pub lib/src/components/common/layout/container_layout.dart lib/src/components/common/widget_performance_monitor.dart test/src/components/common/layout/container_layout_test.dart`
Expected: no `error` or `warning` lines. A pre-existing `info • Unnecessary type name in a constructor` in `widget_performance_monitor.dart` is acceptable.

- [ ] **Step 8: Commit**

```bash
git add -- lib/src/components/common/layout/container_layout.dart \
  lib/src/components/common/widget_performance_monitor.dart \
  test/src/components/common/layout/container_layout_test.dart
git commit -m "feat(layout): build ContainerLayout on WidgetStyle and AnimatedStyledBox" -- \
  lib/src/components/common/layout/container_layout.dart \
  lib/src/components/common/widget_performance_monitor.dart \
  test/src/components/common/layout/container_layout_test.dart
```

---

### Task 2: ColumnLayout and RowLayout

**Files:**
- Modify: `lib/src/components/common/layout/column_layout.dart`
- Modify: `lib/src/components/common/layout/row_layout.dart`
- Create: `test/src/components/common/layout/column_layout_test.dart`
- Create: `test/src/components/common/layout/row_layout_test.dart`

**Interfaces:**
- Consumes: `ContainerLayout` (Task 1).
- Produces: `ColumnLayout({..., WidgetStyle? style, ...})` and `RowLayout({..., WidgetStyle? style, ...})`; every other existing parameter keeps its name and default.

The style set removed from both constructors and field lists (25 names): `width`, `height`, `minWidth`, `maxWidth`, `minHeight`, `maxHeight`, `decoration`, `padding`, `margin`, `border`, `borderRadius`, `backgroundColor`, `backgroundGradient`, `backgroundImage`, `foregroundColor`, `foregroundGradient`, `foregroundImage`, `opacity`, `clipBehavior`, `innerShadow`, `dropShadow`, `backgroundBlur`, `animate`, `animateDuration`, `animateCurve`.

- [ ] **Step 1: Write the failing tests**

Create `test/src/components/common/layout/column_layout_test.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/layout/column_layout.dart';
import 'package:stratum_ui/src/components/common/layout/container_layout.dart';
import 'package:stratum_ui/src/components/common/model/widget_style.dart';

Widget _host(Widget child) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Center(child: child),
  );
}

void main() {
  group('ColumnLayout', () {
    testWidgets('passes its style to ContainerLayout', (tester) async {
      const style = WidgetStyle(padding: EdgeInsets.all(8));
      await tester.pumpWidget(
        _host(
          const ColumnLayout(style: style, children: [SizedBox(height: 20)]),
        ),
      );

      final box = tester.widget<ContainerLayout>(find.byType(ContainerLayout));
      expect(box.style, style);
    });

    testWidgets('a height in the style makes the column fill it',
        (tester) async {
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

    testWidgets('crossAxisIntrinsic applies only without a style width',
        (tester) async {
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

    testWidgets('a scrollable column with a style height lays out',
        (tester) async {
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
}
```

Create `test/src/components/common/layout/row_layout_test.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/layout/container_layout.dart';
import 'package:stratum_ui/src/components/common/layout/row_layout.dart';
import 'package:stratum_ui/src/components/common/model/widget_style.dart';

Widget _host(Widget child) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Center(child: child),
  );
}

void main() {
  group('RowLayout', () {
    testWidgets('passes its style to ContainerLayout', (tester) async {
      const style = WidgetStyle(padding: EdgeInsets.all(8));
      await tester.pumpWidget(
        _host(const RowLayout(style: style, children: [SizedBox(width: 20)])),
      );

      final box = tester.widget<ContainerLayout>(find.byType(ContainerLayout));
      expect(box.style, style);
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

    testWidgets('crossAxisIntrinsic applies only without a style height',
        (tester) async {
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
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test --no-pub test/src/components/common/layout/column_layout_test.dart test/src/components/common/layout/row_layout_test.dart`
Expected: FAIL to load with compile errors from the `src.dart` barrel that both layouts import today.

- [ ] **Step 3: Migrate `column_layout.dart`**

1. Replace line 1 (`import 'package:stratum_ui/src/src.dart';`) with:

```dart
import 'package:flutter/widgets.dart';
import 'package:stratum_ui/src/components/common/layout/container_layout.dart';
import 'package:stratum_ui/src/components/common/model/widget_style.dart';
```

2. In the constructor, delete the parameter line of every name in the style set (25 lines), and insert `this.style,` directly after `super.key,`.
3. Replace the constructor's closing initializer, which starts `}) : _effectiveMainAxisSize = height != null || maxHeight != null` and ends `_needsIntrinsicWidth = crossAxisIntrinsic && width == null;`, with `});`.
4. Delete the field declaration of every name in the style set, the `// If you use width,height will override min and max width, height.` comment, the `// Pre-computed values` comment, and the two fields `final MainAxisSize _effectiveMainAxisSize;` and `final bool _needsIntrinsicWidth;`. Insert, directly above the `///===== Semantics ======///` header:

```dart
  ///========== Style ==========///
  final WidgetStyle? style;

  MainAxisSize get _effectiveMainAxisSize =>
      style?.height != null || style?.maxHeight != null
          ? MainAxisSize.max
          : mainAxisSize;

  bool get _needsIntrinsicWidth => crossAxisIntrinsic && style?.width == null;
```

5. Replace the whole `ContainerLayout(...)` call in `build` (from `Widget result = ContainerLayout(` through its closing `);`) with:

```dart
    Widget result = ContainerLayout(
      style: style,
      ratio: ratio,
      rotate: rotate,
      keepAlive: keepAlive,
      repaintBoundary: repaintBoundary,
      debug: debug,
      transform: transform,
      onEndAnimate: onEndAnimate,
      semantics: semantics,
      child: columnContent,
    );
```

- [ ] **Step 4: Migrate `row_layout.dart`**

1. Replace line 1 (`import 'package:stratum_ui/src/src.dart';`) with:

```dart
import 'package:flutter/widgets.dart';
import 'package:stratum_ui/src/components/common/layout/container_layout.dart';
import 'package:stratum_ui/src/components/common/model/widget_style.dart';
```

2. In the constructor, delete the parameter line of every name in the style set (25 lines), and insert `this.style,` directly after `super.key,`.
3. Replace the constructor's closing initializer, which starts `}) : _effectiveMainAxisSize = width != null || maxWidth != null` and ends `_needsIntrinsicHeight = crossAxisIntrinsic && height == null;`, with `});`.
4. Delete the field declaration of every name in the style set, the `// If you use width,height will override min and max width, height.` comment if present, the `// Pre-computed values` comment, and the two fields `final MainAxisSize _effectiveMainAxisSize;` and `final bool _needsIntrinsicHeight;`. Insert, directly above the `///===== Semantics ======///` header:

```dart
  ///========== Style ==========///
  final WidgetStyle? style;

  MainAxisSize get _effectiveMainAxisSize =>
      style?.width != null || style?.maxWidth != null
          ? MainAxisSize.max
          : mainAxisSize;

  bool get _needsIntrinsicHeight =>
      crossAxisIntrinsic && style?.height == null;
```

5. Replace the whole `ContainerLayout(...)` call in `build` (from `Widget result = ContainerLayout(` through its closing `);`) with:

```dart
    Widget result = ContainerLayout(
      style: style,
      ratio: ratio,
      rotate: rotate,
      keepAlive: keepAlive,
      repaintBoundary: repaintBoundary,
      debug: debug,
      transform: transform,
      onEndAnimate: onEndAnimate,
      semantics: semantics,
      child: rowContent,
    );
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test --no-pub test/src/components/common/layout/column_layout_test.dart test/src/components/common/layout/row_layout_test.dart`
Expected: PASS, `+8: All tests passed!`

- [ ] **Step 6: Analyze**

Run: `flutter analyze --no-pub lib/src/components/common/layout/column_layout.dart lib/src/components/common/layout/row_layout.dart test/src/components/common/layout`
Expected: no `error` or `warning` lines. Pre-existing `info • Unnecessary type name in a constructor` lines are acceptable.

- [ ] **Step 7: Commit**

```bash
git add -- lib/src/components/common/layout/column_layout.dart \
  lib/src/components/common/layout/row_layout.dart \
  test/src/components/common/layout/column_layout_test.dart \
  test/src/components/common/layout/row_layout_test.dart
git commit -m "refactor(layout): pass WidgetStyle through ColumnLayout and RowLayout" -- \
  lib/src/components/common/layout/column_layout.dart \
  lib/src/components/common/layout/row_layout.dart \
  test/src/components/common/layout/column_layout_test.dart \
  test/src/components/common/layout/row_layout_test.dart
```

---

### Task 3: StackLayout and WrapLayout

**Files:**
- Modify: `lib/src/components/common/layout/stack_layout.dart`
- Modify: `lib/src/components/common/layout/wrap_layout.dart`
- Create: `test/src/components/common/layout/stack_layout_test.dart`
- Create: `test/src/components/common/layout/wrap_layout_test.dart`

**Interfaces:**
- Consumes: `ContainerLayout` (Task 1).
- Produces: `StackLayout({..., WidgetStyle? style, ...})` and `WrapLayout({..., WidgetStyle? style, ...})`. `alignment` and `clipBehavior` stay and keep configuring the `Stack` or `Wrap`.

The style set removed from both constructors and field lists (24 names): `width`, `height`, `minWidth`, `maxWidth`, `minHeight`, `maxHeight`, `decoration`, `padding`, `margin`, `border`, `borderRadius`, `backgroundColor`, `backgroundGradient`, `backgroundImage`, `foregroundColor`, `foregroundGradient`, `foregroundImage`, `opacity`, `innerShadow`, `dropShadow`, `backgroundBlur`, `animate`, `animateDuration`, `animateCurve`.

- [ ] **Step 1: Write the failing tests**

Create `test/src/components/common/layout/stack_layout_test.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/layout/container_layout.dart';
import 'package:stratum_ui/src/components/common/layout/stack_layout.dart';
import 'package:stratum_ui/src/components/common/model/widget_style.dart';

const _style = WidgetStyle(backgroundColor: Color(0xFFFFFFFF));

Widget _host(Widget child) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Center(child: child),
  );
}

void main() {
  group('StackLayout', () {
    testWidgets('builds no ContainerLayout without container values',
        (tester) async {
      await tester.pumpWidget(
        _host(const StackLayout(children: [SizedBox(width: 20, height: 20)])),
      );

      expect(find.byType(ContainerLayout), findsNothing);
    });

    testWidgets('wraps the stack in ContainerLayout when a style is set',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const StackLayout(
            style: _style,
            children: [SizedBox(width: 20, height: 20)],
          ),
        ),
      );

      final box = tester.widget<ContainerLayout>(find.byType(ContainerLayout));
      expect(box.style, _style);
    });

    testWidgets('semantics alone still wraps the stack', (tester) async {
      await tester.pumpWidget(
        _host(
          const StackLayout(
            semantics: SemanticsProperties(label: 'stack'),
            children: [SizedBox(width: 20, height: 20)],
          ),
        ),
      );

      expect(find.byType(ContainerLayout), findsOneWidget);
    });

    testWidgets('keeps clipBehavior and alignment on the Stack',
        (tester) async {
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
      final box = tester.widget<ContainerLayout>(find.byType(ContainerLayout));
      expect(box.style?.clipBehavior, isNull);
    });
  });
}
```

Create `test/src/components/common/layout/wrap_layout_test.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/layout/container_layout.dart';
import 'package:stratum_ui/src/components/common/layout/wrap_layout.dart';
import 'package:stratum_ui/src/components/common/model/widget_style.dart';

const _style = WidgetStyle(backgroundColor: Color(0xFFFFFFFF));

Widget _host(Widget child) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Center(child: child),
  );
}

void main() {
  group('WrapLayout', () {
    testWidgets('builds no ContainerLayout without container values',
        (tester) async {
      await tester.pumpWidget(
        _host(const WrapLayout(children: [SizedBox(width: 20, height: 20)])),
      );

      expect(find.byType(ContainerLayout), findsNothing);
    });

    testWidgets('wraps the wrap in ContainerLayout when a style is set',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const WrapLayout(
            style: _style,
            children: [SizedBox(width: 20, height: 20)],
          ),
        ),
      );

      final box = tester.widget<ContainerLayout>(find.byType(ContainerLayout));
      expect(box.style, _style);
    });

    testWidgets('keeps clipBehavior and alignment on the Wrap',
        (tester) async {
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
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test --no-pub test/src/components/common/layout/stack_layout_test.dart test/src/components/common/layout/wrap_layout_test.dart`
Expected: FAIL to load with compile errors from the `src.dart` barrel.

- [ ] **Step 3: Migrate `stack_layout.dart`**

1. Replace line 1 (`import 'package:stratum_ui/src/src.dart';`) with:

```dart
import 'package:flutter/widgets.dart';
import 'package:stratum_ui/src/components/common/layout/container_layout.dart';
import 'package:stratum_ui/src/components/common/model/widget_style.dart';
```

2. In the constructor, delete the parameter line of every name in the 24-name style set, and insert `this.style,` directly after `super.key,`. Keep `this.alignment = AlignmentDirectional.topStart,` and `this.clipBehavior = Clip.hardEdge,`.
3. Replace the whole initializer that starts `}) : _hasContainerFeatures = ratio != null ||` and ends `animate != null;` with:

```dart
  }) : _hasContainerFeatures = style != null ||
           ratio != null ||
           rotate != null ||
           transform != null ||
           keepAlive ||
           repaintBoundary ||
           debug ||
           semantics != null;
```

4. Delete the field declaration of every name in the 24-name style set and the `// If you use width,height will override min and max width, height.` comment. Insert, directly above the `///===== Child Widget ======///` header:

```dart
  ///========== Style ==========///
  final WidgetStyle? style;

```

5. Replace the whole `ContainerLayout(...)` call inside `if (_hasContainerFeatures) {` (from `stackWidget = ContainerLayout(` through its closing `);`) with:

```dart
      stackWidget = ContainerLayout(
        style: style,
        ratio: ratio,
        rotate: rotate,
        keepAlive: keepAlive,
        repaintBoundary: repaintBoundary,
        debug: debug,
        transform: transform,
        onEndAnimate: onEndAnimate,
        semantics: semantics,
        child: stackWidget,
      );
```

- [ ] **Step 4: Migrate `wrap_layout.dart`**

1. Replace line 1 (`import 'package:stratum_ui/src/src.dart';`) with:

```dart
import 'package:flutter/widgets.dart';
import 'package:stratum_ui/src/components/common/layout/container_layout.dart';
import 'package:stratum_ui/src/components/common/model/widget_style.dart';
```

2. In the constructor, delete the parameter line of every name in the 24-name style set, and insert `this.style,` directly after `super.key,`. Keep `this.alignment = WrapAlignment.start,` and `this.clipBehavior = Clip.none,`.
3. In the initializer, keep the `_effectiveSpacing` and `_effectiveRunSpacing` lines, and replace the `_hasContainerFeatures = ratio != null ||` expression through its closing `animate != null;` with:

```dart
       _hasContainerFeatures = style != null ||
           ratio != null ||
           rotate != null ||
           transform != null ||
           keepAlive ||
           repaintBoundary ||
           debug ||
           semantics != null;
```

4. Delete the field declaration of every name in the 24-name style set and the `// If you use width,height will override min and max width, height.` comment if present. Insert, directly above the `///===== Child Widget ======///` header:

```dart
  ///========== Style ==========///
  final WidgetStyle? style;

```

5. Replace the whole `ContainerLayout(...)` call inside `if (_hasContainerFeatures) {` (from `wrapWidget = ContainerLayout(` through its closing `);`) with:

```dart
      wrapWidget = ContainerLayout(
        style: style,
        ratio: ratio,
        rotate: rotate,
        keepAlive: keepAlive,
        repaintBoundary: repaintBoundary,
        debug: debug,
        transform: transform,
        onEndAnimate: onEndAnimate,
        semantics: semantics,
        child: wrapWidget,
      );
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test --no-pub test/src/components/common/layout/stack_layout_test.dart test/src/components/common/layout/wrap_layout_test.dart`
Expected: PASS, `+7: All tests passed!`

- [ ] **Step 6: Analyze**

Run: `flutter analyze --no-pub lib/src/components/common/layout/stack_layout.dart lib/src/components/common/layout/wrap_layout.dart test/src/components/common/layout`
Expected: no `error` or `warning` lines.

- [ ] **Step 7: Commit**

```bash
git add -- lib/src/components/common/layout/stack_layout.dart \
  lib/src/components/common/layout/wrap_layout.dart \
  test/src/components/common/layout/stack_layout_test.dart \
  test/src/components/common/layout/wrap_layout_test.dart
git commit -m "refactor(layout): pass WidgetStyle through StackLayout and WrapLayout" -- \
  lib/src/components/common/layout/stack_layout.dart \
  lib/src/components/common/layout/wrap_layout.dart \
  test/src/components/common/layout/stack_layout_test.dart \
  test/src/components/common/layout/wrap_layout_test.dart
```

---

### Task 4: GestureContainerLayout and the layout barrel

**Files:**
- Modify: `lib/src/components/common/layout/gesture_container_layout.dart`
- Modify: `lib/src/components/common/layout/layout.dart`

**Interfaces:**
- Consumes: `ContainerLayout` (Task 1); `WidgetStyle.copyWith` (freezed).
- Produces: `GestureContainerLayout({..., WidgetStyle? style, ...})`; every gesture and focus parameter keeps its name and default. `GestureContainerLayout` is exported from `layout.dart`.

The style set removed from the constructor and field list (26 names): `width`, `height`, `minWidth`, `maxWidth`, `minHeight`, `maxHeight`, `alignment`, `decoration`, `padding`, `margin`, `border`, `borderRadius`, `backgroundColor`, `backgroundGradient`, `backgroundImage`, `foregroundColor`, `foregroundGradient`, `foregroundImage`, `opacity`, `clipBehavior`, `innerShadow`, `dropShadow`, `backgroundBlur`, `animate`, `animateDuration`, `animateCurve`.

This file imports the barrel, so the check is the analyzer.

- [ ] **Step 1: Confirm the starting state**

Run: `flutter analyze --no-pub lib/src/components/common/layout/gesture_container_layout.dart`
Expected: no `error` lines (the file compiles since `FalconState` and `FocusSpread` exist).

- [ ] **Step 2: Migrate the constructor and fields**

1. In the constructor, delete the parameter line of every name in the 26-name style set, and insert `this.style,` directly after `super.key,`. Note that `this.animate = true,` goes with them.
2. Delete the field declaration of every name in the 26-name style set and the `// If you use width,height will override min and max width, height.` comment. Insert, directly above the `///===== InkWell ======///` header:

```dart
  ///========== Style ==========///
  /// Style changes animate over 100 ms unless the style sets its own
  /// `animationStyle`, keeping the old `animate: true` default.
  final WidgetStyle? style;

```

- [ ] **Step 3: Migrate the state**

1. In `_GestureContainerLayoutState`, add these members directly above `@override Widget buildStates(`:

```dart
  static const _defaultAnimation = AnimationStyle(
    duration: Duration(milliseconds: 100),
  );

  WidgetStyle? get _effectiveStyle {
    final style = widget.style;
    if (style == null || style.animationStyle != null) return style;
    return style.copyWith(animationStyle: _defaultAnimation);
  }

```

2. Replace the whole `ContainerLayout(...)` call in `buildStates` (from `Widget content = ContainerLayout(` through its closing `);`) with:

```dart
    Widget content = ContainerLayout(
      style: _effectiveStyle,
      ratio: widget.ratio,
      rotate: widget.rotate,
      keepAlive: widget.keepAlive,
      repaintBoundary: widget.repaintBoundary,
      debug: widget.debug,
      transform: widget.transform,
      transformAlignment: widget.transformAlignment,
      onEndAnimate: widget.onEndAnimate,
      child: widget.child,
    );
```

3. In the `FocusSpread(` call, replace `borderRadius: widget.decoration?.borderRadius ?? widget.borderRadius,` with:

```dart
        borderRadius: widget.style?.borderRadius,
```

4. In the `InkWell(` call inside `_buildGestureWrapper`, replace `borderRadius: widget.borderRadius,` with:

```dart
        borderRadius: widget.style?.borderRadius?.resolve(
          Directionality.of(context),
        ),
```

- [ ] **Step 4: Export it from the layout barrel**

In `lib/src/components/common/layout/layout.dart`, insert this line directly after `export 'container_layout.dart';`:

```dart
export 'gesture_container_layout.dart';
```

- [ ] **Step 5: Analyze**

Run: `flutter analyze --no-pub lib/src/components/common/layout/gesture_container_layout.dart lib/src/components/common/layout/layout.dart`
Expected: no `error` or `warning` lines. The pre-existing `info` lines (`unnecessary_ignore`, `unnecessary_type_name_in_constructor`) are acceptable. The four gesture layouts still pass the old parameters and now report errors; Task 5 migrates them.

- [ ] **Step 6: Commit**

```bash
git add -- lib/src/components/common/layout/gesture_container_layout.dart \
  lib/src/components/common/layout/layout.dart
git commit -m "refactor(layout): pass WidgetStyle through GestureContainerLayout" -- \
  lib/src/components/common/layout/gesture_container_layout.dart \
  lib/src/components/common/layout/layout.dart
```

---

### Task 5: The four gesture layouts

**Files:**
- Modify: `lib/src/components/common/layout/gesture_column_layout.dart`
- Modify: `lib/src/components/common/layout/gesture_row_layout.dart`
- Modify: `lib/src/components/common/layout/gesture_stack_layout.dart`
- Modify: `lib/src/components/common/layout/gesture_wrap_layout.dart`

**Interfaces:**
- Consumes: `ContainerLayout` (Task 1), `GestureContainerLayout({..., WidgetStyle? style, ...})` (Task 4).
- Produces: each gesture layout gains `WidgetStyle? style`; every gesture, focus, and layout parameter keeps its name and default.

These files import the barrel, so the check is the analyzer. Column and row remove the 25-name set from Task 2; stack and wrap remove the 24-name set from Task 3 and keep `alignment` and `clipBehavior` for the `Stack` or `Wrap`.

- [ ] **Step 1: Record the starting errors**

Run: `flutter analyze --no-pub lib/src/components/common/layout/gesture_column_layout.dart lib/src/components/common/layout/gesture_row_layout.dart lib/src/components/common/layout/gesture_stack_layout.dart lib/src/components/common/layout/gesture_wrap_layout.dart 2>&1 | grep -c '^ *error'`
Expected: a positive number (old parameters passed to the migrated `GestureContainerLayout` and `ContainerLayout`).

- [ ] **Step 2: Migrate `gesture_column_layout.dart`**

1. In the constructor, delete the parameter line of every name in the 25-name set, and insert `this.style,` directly after `super.key,`.
2. Replace the closing initializer that starts `}) : _effectiveMainAxisSize = height != null || maxHeight != null` and ends `_needsIntrinsicWidth = crossAxisIntrinsic && width == null;` with `});`.
3. Delete the field declaration of every name in the 25-name set, the `// Pre-computed values` comment, and the fields `final MainAxisSize _effectiveMainAxisSize;` and `final bool _needsIntrinsicWidth;`. Insert, directly above the `///===== InkWell ======///` header:

```dart
  ///========== Style ==========///
  final WidgetStyle? style;

  MainAxisSize get _effectiveMainAxisSize =>
      style?.height != null || style?.maxHeight != null
          ? MainAxisSize.max
          : mainAxisSize;

  bool get _needsIntrinsicWidth => crossAxisIntrinsic && style?.width == null;

```

4. Replace the whole `GestureContainerLayout(...)` call in `build` with:

```dart
    Widget result = GestureContainerLayout(
      style: style,
      ratio: ratio,
      rotate: rotate,
      keepAlive: keepAlive,
      repaintBoundary: repaintBoundary,
      transform: transform,
      focusType: focusType,
      disabled: disabled,
      disabledPressAnimation: disabledPressAnimation,
      onTap: onTap,
      onSecondaryPress: onSecondaryPress,
      onDoubleTap: onDoubleTap,
      onLongPress: onLongPress,
      onHighlightChanged: onHighlightChanged,
      onHover: onHover,
      mouseCursor: mouseCursor,
      enableFeedback: enableFeedback,
      excludeFromSemantics: excludeFromSemantics,
      focusNode: focusNode,
      canRequestFocus: canRequestFocus,
      onFocusChange: onFocusChange,
      showFocusOnPrimary: showFocusOnPrimary,
      autofocus: autofocus,
      statesController: statesController,
      onEndAnimate: onEndAnimate,
      semantics: semantics,
      child: columnContent,
    );
```


- [ ] **Step 3: Migrate `gesture_row_layout.dart`**

1. In the constructor, delete the parameter line of every name in the 25-name set, and insert `this.style,` directly after `super.key,`.
2. Replace the closing initializer that starts `}) : _effectiveMainAxisSize = width != null || maxWidth != null` and ends `_needsIntrinsicHeight = crossAxisIntrinsic && height == null;` with `});`.
3. Delete the field declaration of every name in the 25-name set, the `// Pre-computed values` comment, and the fields `final MainAxisSize _effectiveMainAxisSize;` and `final bool _needsIntrinsicHeight;`. Insert, directly above the `///===== InkWell ======///` header:

```dart
  ///========== Style ==========///
  final WidgetStyle? style;

  MainAxisSize get _effectiveMainAxisSize =>
      style?.width != null || style?.maxWidth != null
          ? MainAxisSize.max
          : mainAxisSize;

  bool get _needsIntrinsicHeight =>
      crossAxisIntrinsic && style?.height == null;

```

4. Replace the whole `GestureContainerLayout(...)` call in `build` with:

```dart
    Widget result = GestureContainerLayout(
      style: style,
      ratio: ratio,
      rotate: rotate,
      keepAlive: keepAlive,
      repaintBoundary: repaintBoundary,
      transform: transform,
      focusType: focusType,
      disabledPressAnimation: disabledPressAnimation,
      disabled: disabled,
      onTap: onTap,
      onSecondaryPress: onSecondaryPress,
      onDoubleTap: onDoubleTap,
      onLongPress: onLongPress,
      onHighlightChanged: onHighlightChanged,
      onHover: onHover,
      mouseCursor: mouseCursor,
      enableFeedback: enableFeedback,
      excludeFromSemantics: excludeFromSemantics,
      focusNode: focusNode,
      canRequestFocus: canRequestFocus,
      onFocusChange: onFocusChange,
      autofocus: autofocus,
      showFocusOnPrimary: showFocusOnPrimary,
      statesController: statesController,
      onEndAnimate: onEndAnimate,
      semantics: semantics,
      child: rowContent,
    );
```


- [ ] **Step 4: Migrate `gesture_stack_layout.dart`**

1. In the constructor, delete the parameter line of every name in the 24-name set, and insert `this.style,` directly after `super.key,`. Keep `alignment` and `clipBehavior`.
2. Delete the field declaration of every name in the 24-name set. Insert, directly above the `///===== Child Widget ======///` header:

```dart
  ///========== Style ==========///
  final WidgetStyle? style;

```

3. Replace the `GestureContainerLayout(...)` call (inside `if (_hasGestures)`) with:

```dart
GestureContainerLayout(
        style: style,
        ratio: ratio,
        rotate: rotate,
        keepAlive: keepAlive,
        repaintBoundary: repaintBoundary,
        transform: transform,
        focusType: focusType,
        disabled: disabled,
        disabledPressAnimation: disabledPressAnimation,
        onTap: onTap,
        onSecondaryPress: onSecondaryPress,
        onDoubleTap: onDoubleTap,
        onLongPress: onLongPress,
        onHighlightChanged: onHighlightChanged,
        onHover: onHover,
        mouseCursor: mouseCursor,
        enableFeedback: enableFeedback,
        excludeFromSemantics: excludeFromSemantics,
        focusNode: focusNode,
        canRequestFocus: canRequestFocus,
        onFocusChange: onFocusChange,
        autofocus: autofocus,
        showFocusOnPrimary: showFocusOnPrimary,
        statesController: statesController,
        onEndAnimate: onEndAnimate,
        semantics: semantics,
        child: stackWidget,
      )
```

4. Replace the `ContainerLayout(...)` call in the `else` branch with:

```dart
ContainerLayout(
        style: style,
        ratio: ratio,
        rotate: rotate,
        keepAlive: keepAlive,
        repaintBoundary: repaintBoundary,
        transform: transform,
        onEndAnimate: onEndAnimate,
        semantics: semantics,
        child: stackWidget,
      )
```

Keep each call's original left-hand side and trailing `;`.

- [ ] **Step 5: Migrate `gesture_wrap_layout.dart`**

1. In the constructor, delete the parameter line of every name in the 24-name set, and insert `this.style,` directly after `super.key,`. Keep `alignment` and `clipBehavior`.
2. Delete the field declaration of every name in the 24-name set. Insert, directly above the `///===== Child Widget ======///` header:

```dart
  ///========== Style ==========///
  final WidgetStyle? style;

```

3. Replace the `GestureContainerLayout(...)` call (inside `if (_hasGestures)`) with:

```dart
GestureContainerLayout(
        style: style,
        ratio: ratio,
        rotate: rotate,
        keepAlive: keepAlive,
        repaintBoundary: repaintBoundary,
        transform: transform,
        focusType: focusType,
        disabled: disabled,
        disabledPressAnimation: disabledPressAnimation,
        onTap: onPress,
        onSecondaryPress: onSecondaryPress,
        onDoubleTap: onDoubleTap,
        onLongPress: onLongPress,
        onHighlightChanged: onHighlightChanged,
        onHover: onHover,
        mouseCursor: mouseCursor,
        enableFeedback: enableFeedback,
        excludeFromSemantics: excludeFromSemantics,
        focusNode: focusNode,
        canRequestFocus: canRequestFocus,
        onFocusChange: onFocusChange,
        autofocus: autofocus,
        showFocusOnPrimary: showFocusOnPrimary,
        statesController: statesController,
        onEndAnimate: onEndAnimate,
        semantics: semantics,
        child: wrapWidget,
      )
```

4. Replace the `ContainerLayout(...)` call in the `else` branch with:

```dart
ContainerLayout(
        style: style,
        ratio: ratio,
        rotate: rotate,
        keepAlive: keepAlive,
        repaintBoundary: repaintBoundary,
        transform: transform,
        onEndAnimate: onEndAnimate,
        semantics: semantics,
        child: wrapWidget,
      )
```

Keep each call's original left-hand side and trailing `;`.

- [ ] **Step 6: Analyze**

Run: `flutter analyze --no-pub lib/src/components/common/layout/gesture_column_layout.dart lib/src/components/common/layout/gesture_row_layout.dart lib/src/components/common/layout/gesture_stack_layout.dart lib/src/components/common/layout/gesture_wrap_layout.dart 2>&1 | grep -E '^ *(error|warning)'`
Expected: no output.

- [ ] **Step 7: Commit**

```bash
git add -- lib/src/components/common/layout/gesture_column_layout.dart \
  lib/src/components/common/layout/gesture_row_layout.dart \
  lib/src/components/common/layout/gesture_stack_layout.dart \
  lib/src/components/common/layout/gesture_wrap_layout.dart
git commit -m "refactor(layout): pass WidgetStyle through the gesture layouts" -- \
  lib/src/components/common/layout/gesture_column_layout.dart \
  lib/src/components/common/layout/gesture_row_layout.dart \
  lib/src/components/common/layout/gesture_stack_layout.dart \
  lib/src/components/common/layout/gesture_wrap_layout.dart
```

---

### Task 6: AppCustomScrollView and the phase check

**Files:**
- Modify: `lib/src/components/common/layout/custom_scroll_view.dart` (the `ContainerLayout(` call in `build`)

**Interfaces:**
- Consumes: `ContainerLayout` (Task 1).
- Produces: no API change; `AppCustomScrollView` keeps its own `width` and inherited `border`.

- [ ] **Step 1: Migrate the call**

Replace

```dart
      return ContainerLayout(
        width: width,
        border: border,
        child: scrollView,
      );
```

with

```dart
      return ContainerLayout(
        style: WidgetStyle(width: width, border: border),
        child: scrollView,
      );
```

- [ ] **Step 2: Verify no new error in the file**

Run: `flutter analyze --no-pub lib/src/components/common/layout/custom_scroll_view.dart 2>&1 | grep -c '^ *error'`
Expected: the custom_scroll_view count from Task 1 Step 1 (`7` when this plan was written). Those errors come from the base widget and `NoGlowScrollBehavior`, and the green build owns them.

- [ ] **Step 3: Verify the package error count**

Run: `flutter analyze --no-pub lib > /tmp/analyze_plan2_after.txt 2>&1; grep -c '^ *error' /tmp/analyze_plan2_after.txt; grep '^ *error' /tmp/analyze_plan2_after.txt | grep -E 'layout/(container|column|row|stack|wrap|gesture_[a-z_]+)_layout\.dart|widget_performance_monitor'`
Expected: the first number is the Task 1 Step 1 count minus 4 (the four gesture layouts no longer report `GestureContainerLayout` as undefined); the grep prints nothing.

- [ ] **Step 4: Run every test this plan and the phase 1 plan own**

Run: `flutter test --no-pub test/src/components/common/model test/src/components/common/style test/src/components/common/layout`
Expected: PASS. The count is 49 from phase 1, plus 8 (container), 8 (column and row), and 7 (stack and wrap): `+72: All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add -- lib/src/components/common/layout/custom_scroll_view.dart
git commit -m "refactor(layout): pass WidgetStyle from AppCustomScrollView" -- \
  lib/src/components/common/layout/custom_scroll_view.dart
```
