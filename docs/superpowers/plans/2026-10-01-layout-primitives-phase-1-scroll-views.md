# Layout Primitives Phase 1: Scroll Views Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the three non-compiling `App*` scroll views with `ListViewLayout`, `GridViewLayout`, and `CustomScrollViewLayout`, built on one scroll behavior resolver, so that `flutter analyze lib` reports 0 errors.

**Architecture:** `StratumThemeApplication` gains a non-throwing `maybeOf`. A new internal file `layout/scroll_frame.dart` holds `resolveScrollBehavior` (theme behavior and physics, else the inherited `ScrollConfiguration`) and `ScrollFrame`, a `StatelessWidget` that wraps a scroll view in a `ScrollConfiguration` carrying that behavior. Each scroll view builds `ContainerLayout(style: ScrollFrame.boxStyle(style))` when a style is set, then `ScrollFrame`, then the Flutter scroll view with `style.padding` as its sliver padding. `StratumScrollBehavior` finally removes the overscroll indicator by overriding `buildOverscrollIndicator`.

**Tech Stack:** Flutter 3.47.3, Dart ^3.13.3, flutter_test, very_good_analysis 11, freezed (`WidgetStyle.copyWith`).

**Spec:** `docs/superpowers/specs/2026-10-01-layout-primitives-design.md` (sections 2, 4 "Scroll views" and "Theme and behavior", 5 "Scroll views after each phase", 6 "Scrolling inside the box" for scroll views, 7, 8 phase 1 rows, 10 phase 1)

## Global Constraints

- Work in the main working tree. The owner has staged and unstaged work in progress (for example a staged `assets/themes/` rename and `.claude/skills/` edits); never stage or commit it.
- Commit with explicit paths only: `git add -- <paths>` then `git commit -m "<message>" -- <paths>`. Conventional Commits with a scope; no `Co-Authored-By` line and no AI attribution.
- Constructors use the `new` form: `const new(` for the unnamed constructor and `const new builder(` for a named one. `new.builder(` fails with `new_constructor_dot_name`.
- Layout files and their tests import the barrel `package:stratum_ui/src/src.dart`. `scroll_frame.dart` is not exported by any barrel; files that use it import `package:stratum_ui/src/components/common/layout/scroll_frame.dart` directly.
- Lints come from very_good_analysis 11: package imports only, sorted directives, constructors before fields, single quotes, lines at most 80 characters in `lib/`.
- Do not touch the gesture layouts, `column_layout.dart`, `row_layout.dart`, `stack_layout.dart`, `wrap_layout.dart`, `container_layout.dart`, or `animated_styled_box.dart`; they change in phase 3.
- Phase 4 parameters (`focusable`, `semanticsLabel`) are not added in this phase.
- Run tests with `flutter test --no-pub <path>`. Run the analyzer with `flutter analyze --no-pub <path>`.
- The barrel compiles in tests only while every exported file compiles. Each scroll view is added to `layout/layout.dart` in the same task that makes it compile, never earlier.

## Review Focus

- A Flutter or layout scroll view nested inside an item of a list whose `showScrollbar` is false: a person expects the inner layout list to keep its own scrollbar. Pinned in Task 4 ("keeps the scrollbar of a nested list").
- An app with no `StratumThemeApplication`: a person expects the scroll views to build with Flutter defaults instead of throwing. Pinned in Task 1 (`maybeOf` returns null) and Task 4 (the no-theme notification case).
- `gap` on an unbounded list (`itemCount: null`): a person expects a clear assertion instead of a cast error inside `ListView.separated`. Pinned in Task 4.
- A horizontal list with `gap`: a person expects horizontal space, not a vertical separator. Pinned in Task 4.
- A rounded box with an explicit `clipBehavior: Clip.none`: a person expects the explicit choice to win over the automatic rounded clip. Pinned in Task 3.

---

### Task 1: `StratumThemeApplication.maybeOf`

**Files:**
- Modify: `lib/src/themes/theme_application.dart:16-38` (the `of` method)
- Create: `test/src/themes/theme_application_test.dart`

**Interfaces:**
- Consumes: `FakeStratumTheme` from `test/src/components/common/fakes/fake_stratum_theme.dart` (constructor `FakeStratumTheme()`).
- Produces: `static StratumThemeData? StratumThemeApplication.maybeOf(BuildContext context, {ThemeMode? themeMode})`; `of` keeps its signature and error.

- [ ] **Step 1: Write the failing test**

Create `test/src/themes/theme_application_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import '../components/common/fakes/fake_stratum_theme.dart';

final _light = FakeStratumTheme();
final _dark = FakeStratumTheme();

Widget _themed(ThemeMode mode, WidgetBuilder builder) {
  return StratumThemeApplication(
    themeMode: mode,
    lightTheme: _light,
    darkTheme: _dark,
    child: Builder(builder: builder),
  );
}

void main() {
  group('StratumThemeApplication.maybeOf', () {
    testWidgets('returns null without a theme', (tester) async {
      StratumThemeData? found = _light;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            found = StratumThemeApplication.maybeOf(context);
            return const SizedBox();
          },
        ),
      );
      expect(found, isNull);
    });

    testWidgets('returns the light theme in light mode', (tester) async {
      StratumThemeData? found;
      await tester.pumpWidget(
        _themed(ThemeMode.light, (context) {
          found = StratumThemeApplication.maybeOf(context);
          return const SizedBox();
        }),
      );
      expect(found, same(_light));
    });

    testWidgets('returns the dark theme in dark mode', (tester) async {
      StratumThemeData? found;
      await tester.pumpWidget(
        _themed(ThemeMode.dark, (context) {
          found = StratumThemeApplication.maybeOf(context);
          return const SizedBox();
        }),
      );
      expect(found, same(_dark));
    });

    testWidgets('follows the platform brightness in system mode',
        (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue =
          Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      StratumThemeData? found;
      await tester.pumpWidget(
        _themed(ThemeMode.system, (context) {
          found = StratumThemeApplication.maybeOf(context);
          return const SizedBox();
        }),
      );
      expect(found, same(_dark));
    });

    testWidgets('lets an explicit themeMode win', (tester) async {
      StratumThemeData? found;
      await tester.pumpWidget(
        _themed(ThemeMode.light, (context) {
          found = StratumThemeApplication.maybeOf(
            context,
            themeMode: ThemeMode.dark,
          );
          return const SizedBox();
        }),
      );
      expect(found, same(_dark));
    });
  });

  group('StratumThemeApplication.of', () {
    testWidgets('(pin) throws a FlutterError without a theme',
        (tester) async {
      Object? error;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            try {
              StratumThemeApplication.of(context);
            } on FlutterError catch (caught) {
              error = caught;
            }
            return const SizedBox();
          },
        ),
      );
      expect(error, isA<FlutterError>());
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --no-pub test/src/themes/theme_application_test.dart`
Expected: FAIL to compile with "The method 'maybeOf' isn't defined for the type 'StratumThemeApplication'".

- [ ] **Step 3: Write minimal implementation**

In `lib/src/themes/theme_application.dart`, replace the whole `of` method (lines 16-38) with:

```dart
  static StratumThemeData of(BuildContext context, {ThemeMode? themeMode}) {
    final theme = maybeOf(context, themeMode: themeMode);
    if (theme == null) {
      throw FlutterError(
        'StratumThemeApplication.of() called with a context that does not contain a '
        'StratumThemeApplication.',
      );
    }
    return theme;
  }

  /// The theme for [context], or null when no [StratumThemeApplication] is
  /// above it.
  ///
  /// In [ThemeMode.system], a missing [MediaQuery] counts as light, so this
  /// never throws.
  static StratumThemeData? maybeOf(
    BuildContext context, {
    ThemeMode? themeMode,
  }) {
    final application = context
        .dependOnInheritedWidgetOfExactType<StratumThemeApplication>();
    if (application == null) return null;
    final isDark = switch (themeMode ?? application.themeMode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system =>
        MediaQuery.maybePlatformBrightnessOf(context) == Brightness.dark,
    };
    return isDark
        ? application.darkTheme ?? application.lightTheme
        : application.lightTheme;
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test --no-pub test/src/themes/theme_application_test.dart test/src/components/common/base/`
Expected: PASS (the base tests resolve the theme through `of`).

- [ ] **Step 5: Commit**

```bash
git add -- lib/src/themes/theme_application.dart test/src/themes/theme_application_test.dart
git commit -m "feat(themes): add StratumThemeApplication.maybeOf" -- lib/src/themes/theme_application.dart test/src/themes/theme_application_test.dart
```

---

### Task 2: `StratumScrollBehavior` removes the overscroll indicator

**Files:**
- Modify: `lib/src/themes/behavior/scroll_behavior.dart` (whole file)
- Create: `test/src/themes/behavior/scroll_behavior_test.dart`

**Interfaces:**
- Produces: `const StratumScrollBehavior()` whose `buildOverscrollIndicator` returns its child; scrollbars and physics stay `MaterialScrollBehavior`'s.

- [ ] **Step 1: Write the failing test**

Create `test/src/themes/behavior/scroll_behavior_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

Widget _list(ScrollBehavior behavior) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: ScrollConfiguration(
      behavior: behavior,
      child: ListView(children: const [SizedBox(height: 2000)]),
    ),
  );
}

final _indicator = find.byWidgetPredicate(
  (widget) =>
      widget is StretchingOverscrollIndicator ||
      widget is GlowingOverscrollIndicator,
);

void main() {
  group('StratumScrollBehavior', () {
    testWidgets('builds no overscroll indicator', (tester) async {
      await tester.pumpWidget(_list(const StratumScrollBehavior()));

      expect(_indicator, findsNothing);
    });

    testWidgets('control: MaterialScrollBehavior builds one', (tester) async {
      await tester.pumpWidget(_list(const MaterialScrollBehavior()));

      expect(_indicator, findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --no-pub test/src/themes/behavior/scroll_behavior_test.dart`
Expected: FAIL in "builds no overscroll indicator" with "Expected: no matching candidates / Actual: _WidgetPredicateWidgetFinder ... Found 1 widget", because `buildViewportChrome` overrides nothing.

- [ ] **Step 3: Write minimal implementation**

Replace `lib/src/themes/behavior/scroll_behavior.dart` with:

```dart
import 'package:stratum_ui/src/src.dart';

/// The design system's scroll behavior: Material scrollbars and physics,
/// with no overscroll glow or stretch on any platform.
class StratumScrollBehavior extends MaterialScrollBehavior {
  const new();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test --no-pub test/src/themes/behavior/scroll_behavior_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add -- lib/src/themes/behavior/scroll_behavior.dart test/src/themes/behavior/scroll_behavior_test.dart
git commit -m "fix(themes): remove the overscroll indicator in StratumScrollBehavior" -- lib/src/themes/behavior/scroll_behavior.dart test/src/themes/behavior/scroll_behavior_test.dart
```

---

### Task 3: `resolveScrollBehavior` and `ScrollFrame`

**Files:**
- Create: `lib/src/components/common/layout/scroll_frame.dart`
- Modify: `test/src/components/common/fakes/fake_stratum_theme.dart` (`FakeStratumTheme` gains `scrollBehavior` and `physics`)
- Create: `test/src/components/common/layout/scroll_frame_test.dart`

**Interfaces:**
- Consumes: `StratumThemeApplication.maybeOf` (Task 1); `StratumScrollBehavior` (Task 2); `WidgetStyle.copyWith` (freezed; passing `null` clears a field).
- Produces:
  - `ScrollBehavior resolveScrollBehavior(BuildContext context, {bool? scrollbars})`
  - `class ScrollFrame extends StatelessWidget` with `const new({Key? key, bool? showScrollbar, required Widget child})`
  - `static WidgetStyle ScrollFrame.boxStyle(WidgetStyle style)`
  - `FakeStratumTheme({Color hover, Color active, ScrollBehavior scrollBehavior = const StratumScrollBehavior(), ScrollPhysics physics = const ClampingScrollPhysics()})`

- [ ] **Step 1: Extend the fake theme**

In `test/src/components/common/fakes/fake_stratum_theme.dart`, add this import as the first `package:stratum_ui` import:

```dart
import 'package:stratum_ui/src/themes/behavior/scroll_behavior.dart';
```

and replace the `FakeStratumTheme` class with:

```dart
/// A theme that answers only what the interaction widgets and the scroll
/// views read.
class FakeStratumTheme extends Fake implements StratumThemeData {
  new({
    Color hover = fakeHover,
    Color active = fakeActive,
    this.scrollBehavior = const StratumScrollBehavior(),
    this.physics = const ClampingScrollPhysics(),
  }) : color = _FakeColors(hover, active);

  @override
  final BaseThemeColor color;

  @override
  final ScrollBehavior scrollBehavior;

  @override
  final ScrollPhysics physics;
}
```

- [ ] **Step 2: Write the failing test**

Create `test/src/components/common/layout/scroll_frame_test.dart`:

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
  for (ScrollPhysics? physics = state.position.physics;
      physics != null;
      physics = physics.parent) {
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

Widget _bouncingOutside(Widget child) {
  return ScrollConfiguration(behavior: const _BouncingBehavior(), child: child);
}

void main() {
  group('ScrollFrame', () {
    testWidgets('lets theme physics win over an outer ScrollConfiguration',
        (tester) async {
      await tester.pumpWidget(themedHost(_bouncingOutside(_framed())));

      final chain = _physicsChain(tester);
      expect(chain, contains(ClampingScrollPhysics));
      expect(chain, isNot(contains(BouncingScrollPhysics)));
    });

    testWidgets('uses the outer ScrollConfiguration without a theme',
        (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(child: _bouncingOutside(_framed())),
        ),
      );

      expect(_physicsChain(tester), contains(BouncingScrollPhysics));
    });

    testWidgets(
      'removes the scrollbar when showScrollbar is false',
      (tester) async {
        await tester.pumpWidget(themedHost(_framed(showScrollbar: false)));

        expect(find.byType(Scrollbar), findsNothing);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

    testWidgets(
      'keeps the desktop scrollbar when showScrollbar is null',
      (tester) async {
        await tester.pumpWidget(themedHost(_framed()));

        expect(find.byType(Scrollbar), findsOneWidget);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );
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
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test --no-pub test/src/components/common/layout/scroll_frame_test.dart`
Expected: FAIL to compile with "Target of URI doesn't exist: 'package:stratum_ui/src/components/common/layout/scroll_frame.dart'".

- [ ] **Step 4: Write minimal implementation**

Create `lib/src/components/common/layout/scroll_frame.dart`:

```dart
import 'package:stratum_ui/src/src.dart';

/// The scroll behavior for a layout scroll view at [context].
///
/// Starts from the theme's `scrollBehavior` with the theme's `physics` when
/// a [StratumThemeApplication] is above [context], else from the inherited
/// [ScrollConfiguration]. A null [scrollbars] keeps the behavior's own
/// choice, which shows a scrollbar on desktop. A scroll view's own
/// `physics` parameter applies on top of the result.
ScrollBehavior resolveScrollBehavior(
  BuildContext context, {
  bool? scrollbars,
}) {
  final theme = StratumThemeApplication.maybeOf(context);
  final behavior = theme?.scrollBehavior ?? ScrollConfiguration.of(context);
  return behavior.copyWith(physics: theme?.physics, scrollbars: scrollbars);
}

/// Applies [resolveScrollBehavior] to the scroll view in [child].
///
/// The behavior also reaches Flutter scroll views inside the items. Layout
/// scroll views among them resolve their own behavior from the theme.
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
    return ScrollConfiguration(
      behavior: resolveScrollBehavior(context, scrollbars: showScrollbar),
      child: child,
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test --no-pub test/src/components/common/layout/scroll_frame_test.dart test/src/components/common/ink_well_test.dart`
Expected: PASS (7 scroll frame tests; the ink well tests still pass with the extended fake).

- [ ] **Step 6: Commit**

```bash
git add -- lib/src/components/common/layout/scroll_frame.dart test/src/components/common/layout/scroll_frame_test.dart test/src/components/common/fakes/fake_stratum_theme.dart
git commit -m "feat(layout): add the scroll behavior resolver and ScrollFrame" -- lib/src/components/common/layout/scroll_frame.dart test/src/components/common/layout/scroll_frame_test.dart test/src/components/common/fakes/fake_stratum_theme.dart
```

---

### Task 4: `ListViewLayout`

**Files:**
- Rename: `lib/src/components/common/layout/list_view.dart` → `lib/src/components/common/layout/list_view_layout.dart` (then replace the whole file)
- Modify: `lib/src/components/common/layout/layout.dart` (add the export)
- Create: `test/src/components/common/layout/list_view_layout_test.dart`

**Interfaces:**
- Consumes: `ScrollFrame`, `ScrollFrame.boxStyle` (Task 3); `ContainerLayout({WidgetStyle? style, Widget? child})`; `themedHost(Widget child, {StratumThemeData? theme})` and `FakeStratumTheme({ScrollPhysics physics})` from the fakes.
- Produces: `ListViewLayout.builder({Key? key, WidgetStyle? style, double? gap, Axis scrollDirection = Axis.vertical, bool reverse = false, ScrollController? controller, bool? primary, ScrollPhysics? physics, bool? showScrollbar, bool shrinkWrap = false, double? itemExtent, Widget? prototypeItem, required int? itemCount, required NullableIndexedWidgetBuilder itemBuilder, ChildIndexGetter? findChildIndexCallback, bool addAutomaticKeepAlives = true, bool addRepaintBoundaries = true, bool addSemanticIndexes = true, ScrollCacheExtent? scrollCacheExtent, int? semanticChildCount, DragStartBehavior dragStartBehavior = DragStartBehavior.start, ScrollViewKeyboardDismissBehavior? keyboardDismissBehavior, String? restorationId, Clip clipBehavior = Clip.hardEdge})`

- [ ] **Step 1: Write the failing test**

Create `test/src/components/common/layout/list_view_layout_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import '../fakes/fake_stratum_theme.dart';

Widget _item(BuildContext context, int index) {
  return SizedBox(key: ValueKey(index), width: 40, height: 40);
}

Widget _sized(Widget child) {
  return SizedBox(width: 200, height: 300, child: child);
}

List<Type> _physicsChain(WidgetTester tester) {
  final state = tester.state<ScrollableState>(find.byType(Scrollable).first);
  final chain = <Type>[];
  for (ScrollPhysics? physics = state.position.physics;
      physics != null;
      physics = physics.parent) {
    chain.add(physics.runtimeType);
  }
  return chain;
}

final _indicator = find.byWidgetPredicate(
  (widget) =>
      widget is StretchingOverscrollIndicator ||
      widget is GlowingOverscrollIndicator,
);

void main() {
  group('ListViewLayout', () {
    testWidgets('builds its items', (tester) async {
      await tester.pumpWidget(
        themedHost(
          _sized(ListViewLayout.builder(itemCount: 3, itemBuilder: _item)),
        ),
      );

      expect(find.byKey(const ValueKey(2)), findsOneWidget);
    });

    testWidgets('builds no box without a style', (tester) async {
      await tester.pumpWidget(
        themedHost(
          _sized(ListViewLayout.builder(itemCount: 3, itemBuilder: _item)),
        ),
      );

      expect(find.byType(AnimatedStyledBox), findsNothing);
    });

    testWidgets('scrolls style padding with the items and keeps the box',
        (tester) async {
      await tester.pumpWidget(
        themedHost(
          _sized(
            ListViewLayout.builder(
              style: const WidgetStyle(
                padding: EdgeInsets.all(16),
                backgroundColor: Color(0xFFFFFFFF),
              ),
              itemCount: 50,
              itemBuilder: _item,
            ),
          ),
        ),
      );

      final list = tester.widget<ListView>(find.byType(ListView));
      expect(list.padding, const EdgeInsets.all(16));
      final box = tester.widget<AnimatedStyledBox>(
        find.byType(AnimatedStyledBox),
      );
      expect(box.style?.padding, isNull);
      final boxTop = tester.getTopLeft(find.byType(AnimatedStyledBox));
      final itemTop = tester.getTopLeft(find.byKey(const ValueKey(0)));
      expect(itemTop.dy - boxTop.dy, 16);

      await tester.drag(find.byType(ListView), const Offset(0, -100));
      await tester.pump();

      expect(tester.getTopLeft(find.byType(AnimatedStyledBox)), boxTop);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey(0))).dy,
        lessThan(itemTop.dy),
      );
    });

    testWidgets('clips a rounded box with antiAlias', (tester) async {
      await tester.pumpWidget(
        themedHost(
          _sized(
            ListViewLayout.builder(
              style: const WidgetStyle(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              itemCount: 3,
              itemBuilder: _item,
            ),
          ),
        ),
      );

      final box = tester.widget<AnimatedStyledBox>(
        find.byType(AnimatedStyledBox),
      );
      expect(box.style?.clipBehavior, Clip.antiAlias);
      expect(
        find.descendant(
          of: find.byType(AnimatedStyledBox),
          matching: find.byType(ClipRRect),
        ),
        findsOneWidget,
      );
    });

    testWidgets('applies the physics parameter on top of the theme',
        (tester) async {
      await tester.pumpWidget(
        themedHost(
          _sized(
            ListViewLayout.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 3,
              itemBuilder: _item,
            ),
          ),
        ),
      );

      final chain = _physicsChain(tester);
      expect(chain.first, NeverScrollableScrollPhysics);
      expect(chain, contains(ClampingScrollPhysics));
    });

    testWidgets('reads the theme physics', (tester) async {
      await tester.pumpWidget(
        themedHost(
          _sized(ListViewLayout.builder(itemCount: 3, itemBuilder: _item)),
          theme: FakeStratumTheme(physics: const BouncingScrollPhysics()),
        ),
      );

      expect(_physicsChain(tester), contains(BouncingScrollPhysics));
    });

    testWidgets('builds no overscroll indicator under the theme',
        (tester) async {
      await tester.pumpWidget(
        themedHost(
          _sized(ListViewLayout.builder(itemCount: 50, itemBuilder: _item)),
        ),
      );

      expect(_indicator, findsNothing);
    });

    testWidgets('lets an ancestor hear the overscroll indicator', (
      tester,
    ) async {
      var heard = 0;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: NotificationListener<OverscrollIndicatorNotification>(
            onNotification: (notification) {
              heard++;
              return false;
            },
            child: ListViewLayout.builder(itemCount: 50, itemBuilder: _item),
          ),
        ),
      );

      await tester.drag(find.byType(ListView), const Offset(0, 200));
      await tester.pump();

      expect(heard, greaterThan(0));
    });

    testWidgets('puts a vertical gap between items', (tester) async {
      await tester.pumpWidget(
        themedHost(
          _sized(
            ListViewLayout.builder(gap: 8, itemCount: 3, itemBuilder: _item),
          ),
        ),
      );

      final first = tester.getBottomLeft(find.byKey(const ValueKey(0)));
      final second = tester.getTopLeft(find.byKey(const ValueKey(1)));
      expect(second.dy - first.dy, 8);
    });

    testWidgets('puts a horizontal gap between items', (tester) async {
      await tester.pumpWidget(
        themedHost(
          _sized(
            ListViewLayout.builder(
              scrollDirection: Axis.horizontal,
              gap: 8,
              itemCount: 3,
              itemBuilder: _item,
            ),
          ),
        ),
      );

      final first = tester.getTopRight(find.byKey(const ValueKey(0)));
      final second = tester.getTopLeft(find.byKey(const ValueKey(1)));
      expect(second.dx - first.dx, 8);
    });

    test('asserts that gap has an itemCount', () {
      expect(
        () => ListViewLayout.builder(
          gap: 8,
          itemCount: null,
          itemBuilder: _item,
        ),
        throwsAssertionError,
      );
    });

    test('asserts that gap takes no itemExtent', () {
      expect(
        () => ListViewLayout.builder(
          gap: 8,
          itemExtent: 40,
          itemCount: 3,
          itemBuilder: _item,
        ),
        throwsAssertionError,
      );
    });

    test('asserts that gap takes no prototypeItem', () {
      expect(
        () => ListViewLayout.builder(
          gap: 8,
          prototypeItem: const SizedBox(height: 40),
          itemCount: 3,
          itemBuilder: _item,
        ),
        throwsAssertionError,
      );
    });

    test('asserts that gap takes no semanticChildCount', () {
      expect(
        () => ListViewLayout.builder(
          gap: 8,
          semanticChildCount: 3,
          itemCount: 3,
          itemBuilder: _item,
        ),
        throwsAssertionError,
      );
    });

    testWidgets('hands findChildIndexCallback to separated as item indices',
        (tester) async {
      int? finder(Key key) => key == const ValueKey('x') ? 1 : null;
      await tester.pumpWidget(
        themedHost(
          _sized(
            ListViewLayout.builder(
              gap: 8,
              itemCount: 3,
              itemBuilder: _item,
              findChildIndexCallback: finder,
            ),
          ),
        ),
      );

      final list = tester.widget<ListView>(find.byType(ListView));
      final delegate = list.childrenDelegate as SliverChildBuilderDelegate;
      expect(delegate.findChildIndexCallback!(const ValueKey('x')), 2);
    });

    testWidgets('forwards scrollCacheExtent', (tester) async {
      const extent = ScrollCacheExtent.pixels(120);
      await tester.pumpWidget(
        themedHost(
          _sized(
            ListViewLayout.builder(
              scrollCacheExtent: extent,
              itemCount: 3,
              itemBuilder: _item,
            ),
          ),
        ),
      );

      final list = tester.widget<ListView>(find.byType(ListView));
      expect(list.scrollCacheExtent, extent);
    });

    testWidgets(
      'keeps the scrollbar of a nested list',
      (tester) async {
        await tester.pumpWidget(
          themedHost(
            _sized(
              ListViewLayout.builder(
                showScrollbar: false,
                itemCount: 1,
                itemBuilder: (context, index) => SizedBox(
                  height: 200,
                  child: ListViewLayout.builder(
                    itemCount: 50,
                    itemBuilder: _item,
                  ),
                ),
              ),
            ),
          ),
        );

        expect(find.byType(Scrollbar), findsOneWidget);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --no-pub test/src/components/common/layout/list_view_layout_test.dart`
Expected: FAIL to compile with "Undefined name 'ListViewLayout'" (or "The method 'ListViewLayout.builder' isn't defined").

- [ ] **Step 3: Rename the file**

Run: `git mv lib/src/components/common/layout/list_view.dart lib/src/components/common/layout/list_view_layout.dart`

- [ ] **Step 4: Write minimal implementation**

Replace `lib/src/components/common/layout/list_view_layout.dart` with:

```dart
import 'package:stratum_ui/src/components/common/layout/scroll_frame.dart';
import 'package:stratum_ui/src/src.dart';

/// A lazy list that scrolls inside a [WidgetStyle] box.
///
/// The box (fill, border, radius, and shadow) stays in place while the
/// items scroll. `style.padding` becomes the list padding, so it scrolls
/// with the items. Scroll behavior and physics come from
/// [resolveScrollBehavior]; [physics] applies on top of them.
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

  @override
  Widget build(BuildContext context) {
    final style = this.style;
    Widget list = ScrollFrame(
      showScrollbar: showScrollbar,
      child: _buildList(style?.padding),
    );
    if (style != null) {
      list = ContainerLayout(style: ScrollFrame.boxStyle(style), child: list);
    }
    return list;
  }

  Widget _buildList(EdgeInsetsGeometry? padding) {
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

- [ ] **Step 5: Export it**

In `lib/src/components/common/layout/layout.dart`, add the line `export 'list_view_layout.dart';` between `export 'gesture_container_layout.dart';` and `export 'row_layout.dart';`.

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test --no-pub test/src/components/common/layout/list_view_layout_test.dart`
Expected: PASS (17 tests).

Run: `flutter analyze --no-pub lib/src/components/common/layout/list_view_layout.dart lib/src/components/common/layout/scroll_frame.dart`
Expected: no errors or warnings.

- [ ] **Step 7: Commit**

```bash
git add -- lib/src/components/common/layout/list_view.dart lib/src/components/common/layout/list_view_layout.dart lib/src/components/common/layout/layout.dart test/src/components/common/layout/list_view_layout_test.dart
git commit -m "feat(layout): replace AppListView with ListViewLayout" -- lib/src/components/common/layout/list_view.dart lib/src/components/common/layout/list_view_layout.dart lib/src/components/common/layout/layout.dart test/src/components/common/layout/list_view_layout_test.dart
```

---

### Task 5: `GridViewLayout`

**Files:**
- Rename: `lib/src/components/common/layout/grid_view.dart` → `lib/src/components/common/layout/grid_view_layout.dart` (then replace the whole file)
- Modify: `lib/src/components/common/layout/layout.dart` (add the export)
- Create: `test/src/components/common/layout/grid_view_layout_test.dart`

**Interfaces:**
- Consumes: `ScrollFrame`, `ScrollFrame.boxStyle` (Task 3); `ContainerLayout`; `themedHost`.
- Produces: `GridViewLayout.builder({Key? key, WidgetStyle? style, required SliverGridDelegate gridDelegate, Axis scrollDirection = Axis.vertical, bool reverse = false, ScrollController? controller, bool? primary, ScrollPhysics? physics, bool? showScrollbar, bool shrinkWrap = false, required int? itemCount, required NullableIndexedWidgetBuilder itemBuilder, ChildIndexGetter? findChildIndexCallback, bool addAutomaticKeepAlives = true, bool addRepaintBoundaries = true, bool addSemanticIndexes = true, ScrollCacheExtent? scrollCacheExtent, int? semanticChildCount, DragStartBehavior dragStartBehavior = DragStartBehavior.start, ScrollViewKeyboardDismissBehavior? keyboardDismissBehavior, String? restorationId, Clip clipBehavior = Clip.hardEdge})`

- [ ] **Step 1: Write the failing test**

Create `test/src/components/common/layout/grid_view_layout_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import '../fakes/fake_stratum_theme.dart';

const _delegate = SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 2,
);

Widget _item(BuildContext context, int index) {
  return SizedBox(key: ValueKey(index));
}

Widget _sized(Widget child) {
  return SizedBox(width: 200, height: 300, child: child);
}

List<Type> _physicsChain(WidgetTester tester) {
  final state = tester.state<ScrollableState>(find.byType(Scrollable).first);
  final chain = <Type>[];
  for (ScrollPhysics? physics = state.position.physics;
      physics != null;
      physics = physics.parent) {
    chain.add(physics.runtimeType);
  }
  return chain;
}

void main() {
  group('GridViewLayout', () {
    testWidgets('builds its items', (tester) async {
      await tester.pumpWidget(
        themedHost(
          _sized(
            GridViewLayout.builder(
              gridDelegate: _delegate,
              itemCount: 4,
              itemBuilder: _item,
            ),
          ),
        ),
      );

      expect(find.byKey(const ValueKey(3)), findsOneWidget);
      expect(find.byType(AnimatedStyledBox), findsNothing);
    });

    testWidgets('moves style padding into the grid', (tester) async {
      await tester.pumpWidget(
        themedHost(
          _sized(
            GridViewLayout.builder(
              style: const WidgetStyle(padding: EdgeInsets.all(16)),
              gridDelegate: _delegate,
              itemCount: 4,
              itemBuilder: _item,
            ),
          ),
        ),
      );

      final grid = tester.widget<GridView>(find.byType(GridView));
      expect(grid.padding, const EdgeInsets.all(16));
      final box = tester.widget<AnimatedStyledBox>(
        find.byType(AnimatedStyledBox),
      );
      expect(box.style?.padding, isNull);
    });

    testWidgets('applies the physics parameter on top of the theme',
        (tester) async {
      await tester.pumpWidget(
        themedHost(
          _sized(
            GridViewLayout.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: _delegate,
              itemCount: 4,
              itemBuilder: _item,
            ),
          ),
        ),
      );

      final chain = _physicsChain(tester);
      expect(chain.first, NeverScrollableScrollPhysics);
      expect(chain, contains(ClampingScrollPhysics));
    });

    testWidgets('builds no overscroll indicator under the theme',
        (tester) async {
      await tester.pumpWidget(
        themedHost(
          _sized(
            GridViewLayout.builder(
              gridDelegate: _delegate,
              itemCount: 40,
              itemBuilder: _item,
            ),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is StretchingOverscrollIndicator ||
              widget is GlowingOverscrollIndicator,
        ),
        findsNothing,
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --no-pub test/src/components/common/layout/grid_view_layout_test.dart`
Expected: FAIL to compile with "Undefined name 'GridViewLayout'".

- [ ] **Step 3: Rename the file**

Run: `git mv lib/src/components/common/layout/grid_view.dart lib/src/components/common/layout/grid_view_layout.dart`

- [ ] **Step 4: Write minimal implementation**

Replace `lib/src/components/common/layout/grid_view_layout.dart` with:

```dart
import 'package:stratum_ui/src/components/common/layout/scroll_frame.dart';
import 'package:stratum_ui/src/src.dart';

/// A lazy grid that scrolls inside a [WidgetStyle] box.
///
/// The box (fill, border, radius, and shadow) stays in place while the
/// items scroll. `style.padding` becomes the grid padding, so it scrolls
/// with the items. Scroll behavior and physics come from
/// [resolveScrollBehavior]; [physics] applies on top of them.
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

  @override
  Widget build(BuildContext context) {
    final style = this.style;
    Widget grid = ScrollFrame(
      showScrollbar: showScrollbar,
      child: GridView.builder(
        gridDelegate: gridDelegate,
        scrollDirection: scrollDirection,
        reverse: reverse,
        controller: controller,
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
    );
    if (style != null) {
      grid = ContainerLayout(style: ScrollFrame.boxStyle(style), child: grid);
    }
    return grid;
  }
}
```

- [ ] **Step 5: Export it**

In `lib/src/components/common/layout/layout.dart`, add `export 'grid_view_layout.dart';` between `export 'gesture_container_layout.dart';` and `export 'list_view_layout.dart';`.

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test --no-pub test/src/components/common/layout/grid_view_layout_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 7: Commit**

```bash
git add -- lib/src/components/common/layout/grid_view.dart lib/src/components/common/layout/grid_view_layout.dart lib/src/components/common/layout/layout.dart test/src/components/common/layout/grid_view_layout_test.dart
git commit -m "feat(layout): replace AppGridView with GridViewLayout" -- lib/src/components/common/layout/grid_view.dart lib/src/components/common/layout/grid_view_layout.dart lib/src/components/common/layout/layout.dart test/src/components/common/layout/grid_view_layout_test.dart
```

---

### Task 6: `CustomScrollViewLayout` and the end of `NoGlowScrollBehavior`

**Files:**
- Rename: `lib/src/components/common/layout/custom_scroll_view.dart` → `lib/src/components/common/layout/custom_scroll_view_layout.dart` (then replace the whole file)
- Modify: `lib/src/components/common/layout/layout.dart` (add the export)
- Delete: `lib/src/themes/behavior/no_glow_scroll_behavior.dart`
- Modify: `lib/src/themes/behavior/behavior.dart` (drop its export)
- Create: `test/src/components/common/layout/custom_scroll_view_layout_test.dart`

**Interfaces:**
- Consumes: `ScrollFrame`, `ScrollFrame.boxStyle` (Task 3); `ContainerLayout`; `themedHost`.
- Produces: `CustomScrollViewLayout({Key? key, WidgetStyle? style, List<Widget>? slivers, List<Widget>? children, ScrollController? controller, Axis scrollDirection = Axis.vertical, bool reverse = false, bool shrinkWrap = false, ScrollPhysics? physics, bool? showScrollbar})`

- [ ] **Step 1: Write the failing test**

Create `test/src/components/common/layout/custom_scroll_view_layout_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import '../fakes/fake_stratum_theme.dart';

const _children = [
  SizedBox(key: ValueKey(0), height: 40),
  SizedBox(key: ValueKey(1), height: 40),
  SizedBox(key: ValueKey(2), height: 40),
];

Widget _sized(Widget child) {
  return SizedBox(width: 200, height: 300, child: child);
}

void main() {
  group('CustomScrollViewLayout', () {
    testWidgets('builds children in one SliverList and counts them',
        (tester) async {
      await tester.pumpWidget(
        themedHost(_sized(const CustomScrollViewLayout(children: _children))),
      );

      expect(find.byType(SliverList), findsOneWidget);
      expect(find.byKey(const ValueKey(2)), findsOneWidget);
      final view = tester.widget<CustomScrollView>(
        find.byType(CustomScrollView),
      );
      expect(view.semanticChildCount, 3);
      expect(find.byType(AnimatedStyledBox), findsNothing);
    });

    testWidgets('turns style padding into a SliverPadding', (tester) async {
      await tester.pumpWidget(
        themedHost(
          _sized(
            const CustomScrollViewLayout(
              style: WidgetStyle(padding: EdgeInsets.all(16)),
              children: _children,
            ),
          ),
        ),
      );

      final padding = tester.widget<SliverPadding>(find.byType(SliverPadding));
      expect(padding.padding, const EdgeInsets.all(16));
      final box = tester.widget<AnimatedStyledBox>(
        find.byType(AnimatedStyledBox),
      );
      expect(box.style?.padding, isNull);
    });

    testWidgets('passes slivers through', (tester) async {
      await tester.pumpWidget(
        themedHost(
          _sized(
            const CustomScrollViewLayout(
              slivers: [SliverToBoxAdapter(child: SizedBox(height: 40))],
            ),
          ),
        ),
      );

      expect(find.byType(SliverToBoxAdapter), findsOneWidget);
      final view = tester.widget<CustomScrollView>(
        find.byType(CustomScrollView),
      );
      expect(view.semanticChildCount, isNull);
    });

    testWidgets('asserts that slivers take no style padding', (tester) async {
      await tester.pumpWidget(
        themedHost(
          _sized(
            const CustomScrollViewLayout(
              style: WidgetStyle(padding: EdgeInsets.all(16)),
              slivers: [SliverToBoxAdapter(child: SizedBox(height: 40))],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isAssertionError);
    });

    test('asserts exactly one of slivers and children', () {
      expect(() => CustomScrollViewLayout(), throwsAssertionError);
      expect(
        () => CustomScrollViewLayout(
          slivers: const [],
          children: const [],
        ),
        throwsAssertionError,
      );
    });

    testWidgets(
      'hides the scrollbar when showScrollbar is false',
      (tester) async {
        await tester.pumpWidget(
          themedHost(
            _sized(
              const CustomScrollViewLayout(
                showScrollbar: false,
                children: _children,
              ),
            ),
          ),
        );

        expect(find.byType(Scrollbar), findsNothing);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

    testWidgets(
      'keeps the desktop scrollbar by default',
      (tester) async {
        await tester.pumpWidget(
          themedHost(_sized(const CustomScrollViewLayout(children: _children))),
        );

        expect(find.byType(Scrollbar), findsOneWidget);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --no-pub test/src/components/common/layout/custom_scroll_view_layout_test.dart`
Expected: FAIL to compile with "Undefined name 'CustomScrollViewLayout'".

- [ ] **Step 3: Rename the file**

Run: `git mv lib/src/components/common/layout/custom_scroll_view.dart lib/src/components/common/layout/custom_scroll_view_layout.dart`

- [ ] **Step 4: Write minimal implementation**

Replace `lib/src/components/common/layout/custom_scroll_view_layout.dart` with:

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
/// changes how pinned headers behave.
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
      child: CustomScrollView(
        controller: controller,
        scrollDirection: scrollDirection,
        reverse: reverse,
        shrinkWrap: shrinkWrap,
        physics: physics,
        semanticChildCount: slivers == null ? children!.length : null,
        slivers: slivers ?? [_buildChildrenSliver(style?.padding)],
      ),
    );
    if (style != null) {
      view = ContainerLayout(style: ScrollFrame.boxStyle(style), child: view);
    }
    return view;
  }

  Widget _buildChildrenSliver(EdgeInsetsGeometry? padding) {
    final sliver = SliverList.list(children: children!);
    if (padding == null) return sliver;
    return SliverPadding(padding: padding, sliver: sliver);
  }
}
```

- [ ] **Step 5: Export it and delete `NoGlowScrollBehavior`**

In `lib/src/components/common/layout/layout.dart`, add `export 'custom_scroll_view_layout.dart';` between `export 'container_layout.dart';` and `export 'gesture_container_layout.dart';`.

Run: `git rm lib/src/themes/behavior/no_glow_scroll_behavior.dart`

Replace `lib/src/themes/behavior/behavior.dart` with:

```dart
export 'scroll_behavior.dart';
```

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test --no-pub test/src/components/common/layout/custom_scroll_view_layout_test.dart`
Expected: PASS (7 tests).

- [ ] **Step 7: Commit**

```bash
git add -- lib/src/components/common/layout/custom_scroll_view.dart lib/src/components/common/layout/custom_scroll_view_layout.dart lib/src/components/common/layout/layout.dart lib/src/themes/behavior/no_glow_scroll_behavior.dart lib/src/themes/behavior/behavior.dart test/src/components/common/layout/custom_scroll_view_layout_test.dart
git commit -m "feat(layout): replace AppCustomScrollView with CustomScrollViewLayout" -m "Delete NoGlowScrollBehavior, which duplicated StratumScrollBehavior and overrode a method Flutter no longer has." -- lib/src/components/common/layout/custom_scroll_view.dart lib/src/components/common/layout/custom_scroll_view_layout.dart lib/src/components/common/layout/layout.dart lib/src/themes/behavior/no_glow_scroll_behavior.dart lib/src/themes/behavior/behavior.dart test/src/components/common/layout/custom_scroll_view_layout_test.dart
```

---

### Task 7: Phase 1 verification

**Files:**
- No source changes. If a check fails, fix it in the task that owns the file and amend nothing; make a new `fix(layout):` commit with explicit paths.

**Interfaces:**
- Consumes: everything above.
- Produces: the evidence for the phase 1 done-when (spec section 10).

- [ ] **Step 1: Analyzer**

Run: `flutter analyze --no-pub lib 2>&1 | grep -cE "^\s+error "`
Expected: `0`.

- [ ] **Step 2: No removed names remain**

Run: `grep -rnE "class App(ListView|GridView|CustomScrollView)|NoGlowScrollBehavior|buildViewportChrome" lib`
Expected: no output.

- [ ] **Step 3: Test suites**

Run: `flutter test --no-pub test/src/components/common/ test/src/themes/`
Expected: every test passes.

- [ ] **Step 4: Report**

Report the analyzer count, the test totals, and the commit range of Tasks 1 to 6. The main session then updates the roadmap (milestone `p1-scroll-views` and phase `stratum-green-build`) after asking the owner.
