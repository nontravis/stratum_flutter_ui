# Base Widget Props Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild `StratumStatelessWidget` and `StratumStatefulWidget` on one `StratumWidgetProps` mixin, so both base classes declare the same 10 props with the same defaults and share one implementation of the `resolve*` helpers.

**Architecture:** `mixin StratumWidgetProps` declares the props as abstract getters and implements `resolveTheme`, `resolveSize`, `resolveWindowSize`, and `resolveStyle`. Each base class mixes it in and stores the props as `@override final` fields behind a flat `const new(...)` constructor. The visual fields of the old base classes collapse into one `customStyle: WidgetStyle?`. All three files use narrow imports, and `base.dart` exports them once both base classes compile.

**Tech Stack:** Flutter 3.47.3, Dart ^3.13.3, flutter_test, very_good_analysis 11.

**Spec:** `docs/superpowers/specs/2026-09-30-base-widget-props-design.md` (sections 2, 4, 5, 6, 7, and 8)

## Global Constraints

- Work in the main working tree, not a git worktree; the tree holds owner work in progress that this plan must not disturb.
- `widget_props.dart`, `stateless_widget.dart`, `stateful_widget.dart`, and the test file import only the libraries they use, never `package:stratum_ui/src/src.dart`.
- Lints come from very_good_analysis 11: package imports only, sorted directives, constructors before fields, lines at most 80 characters.
- Constructors use the `const new(` form, as the rest of the package does.
- Both base constructors take their parameters in this order: `key`, `size`, `color`, `themeMode`, `windowSize`, `state` (default `FullWidgetState.normal`), `feedbackState`, `disabled` (default `false`), `loading` (default `false`), `debug` (default `false`), `customStyle`.
- `resolveWindowSize` keeps the `WindowSizeScope` lookup on the right side of `??`, so a given `windowSize` registers no dependency.
- Run tests with `flutter test --no-pub test/src/components/common/base/widget_props_test.dart`.
- The barrel loads in tests only because of two uncommitted export fixes: `BaseResponse` in the `extended_image` hide list of `lib/stratum_ui.dart`, and `hide ImageDecoderCallback` on the `flutter_falconx` export in `lib/src/src.dart`. Leave both in place.
- Commit with explicit paths: `git add -- <paths>` then `git commit -m "<message>" -- <paths>`. Never commit `lib/stratum_ui.dart`, `lib/src/src.dart`, `lib/src/components/common/common.dart`, or `docs/superpowers/specs/2026-09-30-stratum-read-figma-skill.md` (untracked); they hold owner work in progress.
- Both base files are replaced whole. Their commits absorb the owner's uncommitted edits in those two files (the `const new(` form, `windowSize`, and the `custom*` size fields), which the new content supersedes.
- Conventional Commits with a scope; no `Co-Authored-By` line and no AI attribution.

## Review Focus

- A component with a null `windowSize` and no `WindowSizeScope` in the tree must fail with the scope's `FlutterError` ("No WindowSizeScope found"), not a null error. Pinned in Task 1.
- A component with no `StratumThemeApplication` ancestor must fail with that class's `FlutterError` when it resolves the theme. Pinned in Task 1.
- A component given `size` must resolve it without a theme in the tree, because `??` returns before the theme lookup. Pinned in Task 1.
- `customStyle: WidgetStyle(dropShadow: [])` must clear the component's default shadows; an empty list is the documented way to clear a list field. Pinned in Task 1.
- `themeMode: ThemeMode.system` (Figma `AUTO`) must follow the platform brightness. Pinned in Task 1.

Known gap outside this plan: `StratumThemeApplication.updateShouldNotify` compares only `lightTheme`, so switching the app `themeMode` or `darkTheme` alone does not rebuild dependents. Spec section 5 says a component rebuilds when the theme changes; that holds only for a `lightTheme` change. `theme_application.dart` is outside the spec scope, so this plan does not change it.

---

### Task 1: StratumWidgetProps and StratumStatelessWidget

**Files:**
- Create: `lib/src/components/common/base/widget_props.dart`
- Modify: `lib/src/components/common/base/stateless_widget.dart` (whole file)
- Create: `test/src/components/common/base/widget_props_test.dart`

**Interfaces:**
- Consumes: `StratumThemeApplication.of(BuildContext, {ThemeMode? themeMode})` (`lib/src/themes/theme_application.dart`), `StratumThemeData.defaultWidgetSize` (`lib/src/themes/theme_data.dart`), `context.deviceWindow.windowSize` (`lib/src/components/common/responsive/device_window.dart`), `WidgetStyle.merge(WidgetStyle?)` (`lib/src/components/common/model/widget_style.dart`).
- Produces:
  - `mixin StratumWidgetProps` with getters `WidgetSize? size`, `ColorEnum? color`, `ThemeMode? themeMode`, `WindowSize? windowSize`, `FullWidgetState state`, `FeedbackState? feedbackState`, `bool disabled`, `bool loading`, `bool debug`, `WidgetStyle? customStyle`, and methods `StratumThemeData resolveTheme(BuildContext context)`, `WidgetSize resolveSize(BuildContext context)`, `WindowSize resolveWindowSize(BuildContext context)`, `WidgetStyle resolveStyle(WidgetStyle defaults)`.
  - `abstract class StratumStatelessWidget extends StatelessWidget with StratumWidgetProps`, constructor as in Global Constraints.
  - In the test file: `_props(StratumWidgetProps)`, `_readInBuild`, `_themed`, `_FakeTheme`, `_light`, `_dark`, and `_StatelessProbe`, which Task 2 reuses.

- [ ] **Step 1: Write the failing tests**

Create `test/src/components/common/base/widget_props_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_falmodel/flutter_falmodel.dart' show FullWidgetState;
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/base/stateless_widget.dart';
import 'package:stratum_ui/src/components/common/base/widget_props.dart';
import 'package:stratum_ui/src/components/common/model/widget_style.dart';
import 'package:stratum_ui/src/components/common/responsive/window_size_scope.dart';
import 'package:stratum_ui/src/themes/constant/widget_size.dart';
import 'package:stratum_ui/src/themes/constant/window_size.dart';
import 'package:stratum_ui/src/themes/theme_application.dart';
import 'package:stratum_ui/src/themes/theme_data.dart';

class _StatelessProbe extends StratumStatelessWidget {
  const new({
    super.size,
    super.themeMode,
    super.windowSize,
    super.customStyle,
  });

  @override
  Widget build(BuildContext context) => const SizedBox();
}

class _FakeTheme extends Fake implements StratumThemeData {
  new(this.defaultWidgetSize);

  @override
  final WidgetSize defaultWidgetSize;
}

final _light = _FakeTheme(WidgetSize.small);
final _dark = _FakeTheme(WidgetSize.large);

/// Every prop of [props], in constructor order.
List<Object?> _props(StratumWidgetProps props) => [
  props.size,
  props.color,
  props.themeMode,
  props.windowSize,
  props.state,
  props.feedbackState,
  props.disabled,
  props.loading,
  props.debug,
  props.customStyle,
];

Widget _themed(Widget child, {ThemeMode themeMode = ThemeMode.light}) =>
    StratumThemeApplication(
      themeMode: themeMode,
      lightTheme: _light,
      darkTheme: _dark,
      child: child,
    );

/// Pumps a reader, wrapped by [wrap] when given, and returns what [read]
/// returned during its build.
Future<T> _readInBuild<T>(
  WidgetTester tester,
  T Function(BuildContext context) read, {
  Widget Function(Widget child)? wrap,
}) async {
  late T result;
  final reader = Builder(
    builder: (context) {
      result = read(context);
      return const SizedBox();
    },
  );
  await tester.pumpWidget(wrap == null ? reader : wrap(reader));
  return result;
}

void main() {
  test('StratumStatelessWidget defaults to a normal state with no overrides', () {
    expect(_props(const _StatelessProbe()), [
      null,
      null,
      null,
      null,
      FullWidgetState.normal,
      null,
      false,
      false,
      false,
      null,
    ]);
  });

  group('resolveSize', () {
    testWidgets('returns the given size without a theme in the tree', (
      tester,
    ) async {
      final size = await _readInBuild(
        tester,
        const _StatelessProbe(size: WidgetSize.huge).resolveSize,
      );

      expect(size, WidgetSize.huge);
    });

    testWidgets('falls back to the theme defaultWidgetSize', (tester) async {
      final size = await _readInBuild(
        tester,
        const _StatelessProbe().resolveSize,
        wrap: _themed,
      );

      expect(size, WidgetSize.small);
    });
  });

  group('resolveWindowSize', () {
    testWidgets('returns the given window size without a WindowSizeScope', (
      tester,
    ) async {
      final windowSize = await _readInBuild(
        tester,
        const _StatelessProbe(windowSize: WindowSize.desktop)
            .resolveWindowSize,
      );

      expect(windowSize, WindowSize.desktop);
    });

    testWidgets('reads the nearest WindowSizeScope when windowSize is null', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(900, 800);
      addTearDown(tester.view.reset);

      final windowSize = await _readInBuild(
        tester,
        const _StatelessProbe().resolveWindowSize,
        wrap: (child) => WindowSizeScope(child: child),
      );

      expect(windowSize, WindowSize.tablet);
    });

    testWidgets('throws a FlutterError when null and no scope exists', (
      tester,
    ) async {
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            const _StatelessProbe().resolveWindowSize(context);
            return const SizedBox();
          },
        ),
      );

      expect(
        tester.takeException(),
        isA<FlutterError>().having(
          (error) => error.message,
          'message',
          contains('No WindowSizeScope found'),
        ),
      );
    });
  });

  group('resolveStyle', () {
    const defaults = WidgetStyle(
      padding: EdgeInsets.all(8),
      opacity: 0.5,
      dropShadow: [BoxShadow(blurRadius: 4)],
    );

    test('returns the defaults when customStyle is null', () {
      expect(const _StatelessProbe().resolveStyle(defaults), same(defaults));
    });

    test('applies each non-null customStyle field over the defaults', () {
      final style = const _StatelessProbe(
        customStyle: WidgetStyle(opacity: 1),
      ).resolveStyle(defaults);

      expect(style.opacity, 1);
      expect(style.padding, const EdgeInsets.all(8));
      expect(style.dropShadow, defaults.dropShadow);
    });

    test('clears default shadows when customStyle passes an empty list', () {
      final style = const _StatelessProbe(
        customStyle: WidgetStyle(dropShadow: []),
      ).resolveStyle(defaults);

      expect(style.dropShadow, isEmpty);
    });
  });

  group('resolveTheme', () {
    testWidgets('returns the app theme when themeMode is null', (
      tester,
    ) async {
      final theme = await _readInBuild(
        tester,
        const _StatelessProbe().resolveTheme,
        wrap: _themed,
      );

      expect(theme, same(_light));
    });

    testWidgets('themeMode overrides the app theme mode', (tester) async {
      final theme = await _readInBuild(
        tester,
        const _StatelessProbe(themeMode: ThemeMode.dark).resolveTheme,
        wrap: _themed,
      );

      expect(theme, same(_dark));
    });

    testWidgets('ThemeMode.system follows the platform brightness', (
      tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      final theme = await _readInBuild(
        tester,
        const _StatelessProbe(themeMode: ThemeMode.system).resolveTheme,
        wrap: _themed,
      );

      expect(theme, same(_dark));
    });

    testWidgets('throws a FlutterError without a StratumThemeApplication', (
      tester,
    ) async {
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            const _StatelessProbe().resolveTheme(context);
            return const SizedBox();
          },
        ),
      );

      expect(
        tester.takeException(),
        isA<FlutterError>().having(
          (error) => error.message,
          'message',
          contains('StratumThemeApplication.of() called'),
        ),
      );
    });
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test --no-pub test/src/components/common/base/widget_props_test.dart`
Expected: FAIL at compilation, with an error that `lib/src/components/common/base/widget_props.dart` cannot be read and errors from the current `stateless_widget.dart` (for example `Type 'Breakpoint' not found` or `No named parameter with the name 'customStyle'`).

- [ ] **Step 3: Write `StratumWidgetProps`**

Create `lib/src/components/common/base/widget_props.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_falmodel/flutter_falmodel.dart' show FullWidgetState;
import 'package:stratum_ui/src/components/common/model/widget_style.dart';
import 'package:stratum_ui/src/components/common/responsive/device_window.dart';
import 'package:stratum_ui/src/themes/constant/color.dart';
import 'package:stratum_ui/src/themes/constant/feedback_state.dart';
import 'package:stratum_ui/src/themes/constant/widget_size.dart';
import 'package:stratum_ui/src/themes/constant/window_size.dart';
import 'package:stratum_ui/src/themes/theme_application.dart';
import 'package:stratum_ui/src/themes/theme_data.dart';

/// The props every Stratum component takes, and how they resolve.
///
/// Call the `resolve*` methods inside `build` only: they register
/// dependencies on the nearest [StratumThemeApplication] and
/// `WindowSizeScope`.
mixin StratumWidgetProps {
  /// Null resolves to the theme's `defaultWidgetSize`.
  WidgetSize? get size;

  /// Feedback colors go to [feedbackState] instead.
  ColorEnum? get color;

  /// Null uses the app's theme mode.
  ThemeMode? get themeMode;

  /// Null resolves from the nearest `WindowSizeScope`.
  WindowSize? get windowSize;

  /// Forces a visual state for previews and golden tests. When it is
  /// `normal`, the widget derives hovered, pressed, and focused at runtime.
  FullWidgetState get state;

  FeedbackState? get feedbackState;

  bool get disabled;

  bool get loading;

  /// Forwarded to `ContainerLayout.debug`.
  bool get debug;

  /// Merged over the component's default style; see [resolveStyle].
  WidgetStyle? get customStyle;

  StratumThemeData resolveTheme(BuildContext context) =>
      StratumThemeApplication.of(context, themeMode: themeMode);

  WidgetSize resolveSize(BuildContext context) =>
      size ?? resolveTheme(context).defaultWidgetSize;

  WindowSize resolveWindowSize(BuildContext context) =>
      windowSize ?? context.deviceWindow.windowSize;

  /// Returns [defaults] with every non-null field of [customStyle] applied.
  WidgetStyle resolveStyle(WidgetStyle defaults) =>
      defaults.merge(customStyle);
}
```

- [ ] **Step 4: Rewrite `StratumStatelessWidget`**

Replace the whole content of `lib/src/components/common/base/stateless_widget.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_falmodel/flutter_falmodel.dart' show FullWidgetState;
import 'package:stratum_ui/src/components/common/base/widget_props.dart';
import 'package:stratum_ui/src/components/common/model/widget_style.dart';
import 'package:stratum_ui/src/themes/constant/color.dart';
import 'package:stratum_ui/src/themes/constant/feedback_state.dart';
import 'package:stratum_ui/src/themes/constant/widget_size.dart';
import 'package:stratum_ui/src/themes/constant/window_size.dart';

/// Base class for a Stratum component without state.
///
/// Holds the props of [StratumWidgetProps]; `build` reads them through the
/// `resolve*` methods.
abstract class StratumStatelessWidget extends StatelessWidget
    with StratumWidgetProps {
  const new({
    super.key,
    this.size,
    this.color,
    this.themeMode,
    this.windowSize,
    this.state = FullWidgetState.normal,
    this.feedbackState,
    this.disabled = false,
    this.loading = false,
    this.debug = false,
    this.customStyle,
  });

  @override
  final WidgetSize? size;
  @override
  final ColorEnum? color;
  @override
  final ThemeMode? themeMode;
  @override
  final WindowSize? windowSize;
  @override
  final FullWidgetState state;
  @override
  final FeedbackState? feedbackState;
  @override
  final bool disabled;
  @override
  final bool loading;
  @override
  final bool debug;
  @override
  final WidgetStyle? customStyle;
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test --no-pub test/src/components/common/base/widget_props_test.dart`
Expected: PASS, `+13: All tests passed!`

- [ ] **Step 6: Analyze the base folder and the test**

Run: `dart analyze lib/src/components/common/base/ test/src/components/common/base/`
Expected: `No issues found!` If a lint fires (for example a line over 80 characters), fix it in place and rerun Steps 5 and 6.

- [ ] **Step 7: Commit**

```bash
git add -- lib/src/components/common/base/widget_props.dart lib/src/components/common/base/stateless_widget.dart test/src/components/common/base/widget_props_test.dart
git commit -m "refactor(base): build StratumStatelessWidget on StratumWidgetProps" -- lib/src/components/common/base/widget_props.dart lib/src/components/common/base/stateless_widget.dart test/src/components/common/base/widget_props_test.dart
```

---

### Task 2: StratumStatefulWidget, base exports, and read-figma spec sync

**Files:**
- Modify: `lib/src/components/common/base/stateful_widget.dart` (whole file)
- Modify: `lib/src/components/common/base/base.dart` (empty today)
- Modify: `test/src/components/common/base/widget_props_test.dart` (add one import, one probe, and one group)
- Modify, do not commit: `docs/superpowers/specs/2026-09-30-stratum-read-figma-skill.md:65`, `:77`

**Interfaces:**
- Consumes: `mixin StratumWidgetProps` and its four `resolve*` methods (Task 1); `_props`, `_readInBuild`, `_themed`, and `_StatelessProbe` in the test file (Task 1).
- Produces: `abstract class StratumStatefulWidget extends StatefulWidget with StratumWidgetProps`, with the same constructor as `StratumStatelessWidget`; `base.dart` exports `stateful_widget.dart`, `stateless_widget.dart`, and `widget_props.dart`.

- [ ] **Step 1: Write the failing tests**

In `test/src/components/common/base/widget_props_test.dart`, add this import between the `flutter_test` import and the `stateless_widget.dart` import:

```dart
import 'package:stratum_ui/src/components/common/base/stateful_widget.dart';
```

Add this probe below `_StatelessProbe`:

```dart
class _StatefulProbe extends StratumStatefulWidget {
  const new({super.size});

  @override
  State<_StatefulProbe> createState() => _StatefulProbeState();
}

class _StatefulProbeState extends State<_StatefulProbe> {
  @override
  Widget build(BuildContext context) => const SizedBox();
}
```

Add this group at the end of `main()`:

```dart
  group('StratumStatefulWidget', () {
    test('has the same defaults as StratumStatelessWidget', () {
      expect(
        _props(const _StatefulProbe()),
        _props(const _StatelessProbe()),
      );
    });

    testWidgets('resolveSize returns the given size', (tester) async {
      final size = await _readInBuild(
        tester,
        const _StatefulProbe(size: WidgetSize.huge).resolveSize,
      );

      expect(size, WidgetSize.huge);
    });

    testWidgets('resolveSize falls back to the theme defaultWidgetSize', (
      tester,
    ) async {
      final size = await _readInBuild(
        tester,
        const _StatefulProbe().resolveSize,
        wrap: _themed,
      );

      expect(size, WidgetSize.small);
    });
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test --no-pub test/src/components/common/base/widget_props_test.dart`
Expected: FAIL at compilation: `_StatefulProbe` cannot be passed as a `StratumWidgetProps`, and `resolveSize` is not defined for `_StatefulProbe`.

- [ ] **Step 3: Rewrite `StratumStatefulWidget`**

Replace the whole content of `lib/src/components/common/base/stateful_widget.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_falmodel/flutter_falmodel.dart' show FullWidgetState;
import 'package:stratum_ui/src/components/common/base/widget_props.dart';
import 'package:stratum_ui/src/components/common/model/widget_style.dart';
import 'package:stratum_ui/src/themes/constant/color.dart';
import 'package:stratum_ui/src/themes/constant/feedback_state.dart';
import 'package:stratum_ui/src/themes/constant/widget_size.dart';
import 'package:stratum_ui/src/themes/constant/window_size.dart';

/// Base class for a Stratum component with state, such as the hovered,
/// pressed, and focused states it derives at runtime.
///
/// Holds the props of [StratumWidgetProps]; the `State` reads them through
/// `widget`, for example `widget.resolveSize(context)`.
abstract class StratumStatefulWidget extends StatefulWidget
    with StratumWidgetProps {
  const new({
    super.key,
    this.size,
    this.color,
    this.themeMode,
    this.windowSize,
    this.state = FullWidgetState.normal,
    this.feedbackState,
    this.disabled = false,
    this.loading = false,
    this.debug = false,
    this.customStyle,
  });

  @override
  final WidgetSize? size;
  @override
  final ColorEnum? color;
  @override
  final ThemeMode? themeMode;
  @override
  final WindowSize? windowSize;
  @override
  final FullWidgetState state;
  @override
  final FeedbackState? feedbackState;
  @override
  final bool disabled;
  @override
  final bool loading;
  @override
  final bool debug;
  @override
  final WidgetStyle? customStyle;
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test --no-pub test/src/components/common/base/widget_props_test.dart`
Expected: PASS, `+16: All tests passed!`

- [ ] **Step 5: Export the base classes**

Replace the empty content of `lib/src/components/common/base/base.dart`:

```dart
export 'stateful_widget.dart';
export 'stateless_widget.dart';
export 'widget_props.dart';
```

- [ ] **Step 6: Verify the barrel gains no errors**

Run: `dart analyze lib/src/components/common/base/ test/src/components/common/base/`
Expected: `No issues found!`

Run: `dart analyze lib 2>&1 | grep -E "^\s+error"`
Expected: exactly 9 lines, all in `custom_scroll_view.dart`, `grid_view.dart`, or `list_view.dart` (owner work in progress). Any error in `src.dart`, `stratum_ui.dart`, or a base file means an export clash; stop and report it.

Run: `flutter test --no-pub test/src/components/common/base/widget_props_test.dart`
Expected: PASS, `+16: All tests passed!` (the theme files load the barrel, which now includes the base classes).

- [ ] **Step 7: Commit**

```bash
git add -- lib/src/components/common/base/stateful_widget.dart lib/src/components/common/base/base.dart test/src/components/common/base/widget_props_test.dart
git commit -m "refactor(base): build StratumStatefulWidget on StratumWidgetProps and export the base" -- lib/src/components/common/base/stateful_widget.dart lib/src/components/common/base/base.dart test/src/components/common/base/widget_props_test.dart
```

- [ ] **Step 8: Sync the read-figma spec (no commit)**

In `docs/superpowers/specs/2026-09-30-stratum-read-figma-skill.md`, replace line 65:

```markdown
| `platform` with `MOBILE`, `TABLET`, `DESKTOP`   | `windowSize` (base field); null resolves from the screen width through `resolveBreakpoint()`          |
```

with:

```markdown
| `platform` with `MOBILE`, `TABLET`, `DESKTOP`   | `windowSize` (base field); null resolves from the nearest `WindowSizeScope` through `resolveWindowSize()` |
```

and replace line 77:

```markdown
| override of the look                           | `customStyle: WidgetStyle?`, following the base class `custom*` pattern (`customColor`, `customHeight`) |
```

with:

```markdown
| override of the look                           | `customStyle: WidgetStyle?` (base field), merged over the component defaults by `resolveStyle()`      |
```

Run: `grep -n "resolveBreakpoint\|customColor\|customHeight" docs/superpowers/specs/2026-09-30-stratum-read-figma-skill.md`
Expected: no output.

Do not commit this file: it is untracked owner work in progress. Report the edit in the task summary.
