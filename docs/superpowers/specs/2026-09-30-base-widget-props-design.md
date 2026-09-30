# Base widget props design

- **Date:** 2026-09-30
- **Status:** Sections 1–3 approved during brainstorming; written spec awaiting owner review.
- **Location:** `lib/src/components/common/base/`, new `test/src/components/common/base/`

## 1. Goal

Make `StratumStatelessWidget` and `StratumStatefulWidget` the base classes that `stratum-create-flutter-widget` and `stratum-read-figma` generate components on. Every row of the read-figma property mapping that names a "base field" must land on a field of both base classes, and both base classes must expose the same fields, defaults, and `resolve*` helpers.

Success criteria:

- `dart analyze lib/src/components/common/base/ test/src/components/common/base/` reports 0 issues.
- Both base classes declare the same 10 fields with the same defaults, and share one implementation of the `resolve*` helpers.
- Unit tests cover every `resolve*` fallback (section 7), are written before each implementation, and pass.

## 2. Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Sharing between the two base classes | A `mixin StratumWidgetProps` declares the contract as abstract getters plus concrete `resolve*` methods; both base classes mix it in and store the fields (approach A) | The analyzer rejects a base class that misses a field. The helpers exist once. Constructors stay flat, so a Figma property maps to one named argument. The mixin has no instance fields, so both constructors stay `const`. |
| Rejected: props value object (approach B) | `final StratumProps props` on both base classes | Call sites become `StratumButton(props: StratumProps(disabled: true))`, and the flat read-figma mapping table no longer applies. |
| Rejected: no base class (approach C) | Generator template plus `BuildContext` extensions | Consistency would live only in the skill template, with no compile check, and the `base:` key of the read-figma contract would lose its meaning. |
| Visual override | One `customStyle: WidgetStyle?` replaces `padding`, `margin`, `border`, `borderRadius`, `opacity`, `customWidth`, `customHeight`, `customMinWidth`, `customMaxWidth`, `customMinHeight`, `customMaxHeight`, and `customColor` | Those fields duplicate `WidgetStyle`. The read-figma spec already maps "override of the look" to `customStyle: WidgetStyle?`. |
| Fields kept | `size`, `color`, `themeMode`, `windowSize`, `state`, `feedbackState`, `disabled`, `loading`, `debug`, `customStyle` | Each one maps to a Figma axis in the read-figma mapping, or (`debug`) forwards to `ContainerLayout.debug`. |
| `disabled` and `loading` | `bool` with default `false` in both base classes | `StratumStatefulWidget` declared them as `bool?`, `StratumStatelessWidget` as `bool = false`; a nullable flag gives components a third state that nothing defines. |
| `resolveStyle(WidgetStyle defaults)` | Added; returns `defaults.merge(customStyle)` | States the precedence rule once: `customStyle` wins over the component defaults. Without it, every generated component writes the merge itself. |
| `resolveBreakpoint` | Renamed to `resolveWindowSize`, returns `WindowSize` | `Breakpoint` no longer exists; `WindowSize` replaced it. |
| `buildResponsive`, `buildTapClearFocus`, `buildTapRequestScopeFocus` | Removed | No caller exists. They are widget utilities, not props, and `context.clearFocus()` and `context.requestScopeFocus()` already exist in `context_extension.dart`. |
| `resolveBorderRadius` | Removed | `borderRadius` moves into `customStyle`; each component's default `WidgetStyle` reads the theme radius itself. |
| Missing `WindowSizeScope` | `resolveWindowSize` throws the existing `FlutterError` from `WindowSizeScope.of`; no `MediaQuery` fallback | A fallback would rebuild on every pixel of a resize and hide a missing scope in the app setup. |
| Imports | All three base files import only the libraries they use, not the `src.dart` barrel | Follows the rule set by the ContainerLayout design. The barrel loads in tests today (section 10), but narrow imports keep the base files loadable if it breaks again. |
| Test run | Test-first: each test in section 7 fails before its implementation exists | Owner ruling 2026-09-30. It replaces the earlier ruling (option A: land code gated by the analyzer, run the tests after the green build), which rested on the barrel failing to compile; a probe showed the barrel loads once the `BaseResponse` export is hidden. |

## 3. Current defects

| Location | Defect | Fix |
|---|---|---|
| `stateless_widget.dart:59–70` | 5 compile errors: `Breakpoint`, `context.windowSize`, `ResponsiveBuilder`, `ResponsiveBreakpoints`, and `PlatformChecker` no longer exist. | `resolveWindowSize` reads `context.deviceWindow.windowSize`; `buildResponsive` is removed. |
| `base/base.dart` | The barrel is empty at `HEAD` and in the working tree, so no library outside `base/` can reach either base class. | Export `widget_props.dart`, `stateless_widget.dart`, and `stateful_widget.dart`. |
| `stateful_widget.dart` | Missing `opacity`, `color`, `customColor`, and every `resolve*` helper; `disabled` and `loading` are nullable. | Both base classes mix in `StratumWidgetProps` and declare the same fields and defaults. |

## 4. Public API

New file `lib/src/components/common/base/widget_props.dart`:

```dart
/// The props every Stratum component takes, and how they resolve.
///
/// Call the `resolve*` methods inside `build` only: they register
/// dependencies on the nearest `StratumThemeApplication` and
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

Both base classes take the same constructor, with parameters in this order:

```dart
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
  // ...one `@override final` field per getter of StratumWidgetProps.
}
```

`StratumStatefulWidget` is identical except that it extends `StatefulWidget`. Its `State` calls the helpers through `widget`, for example `widget.resolveSize(context)`.

## 5. Data flow and dependencies

A generated component resolves its props in `build`, builds its default style from the theme, and applies `customStyle` last:

```dart
@override
Widget build(BuildContext context) {
  final theme = widget.resolveTheme(context);
  final size = widget.resolveSize(context);
  final style = widget.resolveStyle(_defaultStyle(theme, size, _state));
  return ContainerLayout(style: style, debug: widget.debug, child: ...);
}
```

- `resolveTheme` depends on `StratumThemeApplication`, so the widget rebuilds when the theme changes.
- `resolveWindowSize` depends on `WindowSizeScope` only when `windowSize` is null, because `??` returns before the lookup. A widget that receives `windowSize` does not rebuild when the window crosses a breakpoint. The implementation must keep the lookup on the right side of `??`.
- `resolveSize` reads the theme only when `size` is null.
- The `resolve*` methods are virtual, so a component may override one, for example to refuse a `padding` override in `resolveStyle`.

## 6. Edge cases

| Case | Behavior |
|---|---|
| No `StratumThemeApplication` above the widget | `resolveTheme` throws the existing `FlutterError` from `StratumThemeApplication.of`. |
| `windowSize` is null and no `WindowSizeScope` exists | `resolveWindowSize` throws the existing `FlutterError` from `WindowSizeScope.of`, which tells the caller how to wrap the app. |
| `windowSize` is set and no `WindowSizeScope` exists | `resolveWindowSize` returns `windowSize` without a lookup and does not throw. |
| `customStyle` is null | `resolveStyle` returns `defaults` unchanged. |
| `disabled: true` with `state: pressed`, or `disabled` with `loading` | The base classes do not validate combinations; each component defines which value wins. |

## 7. Testing

File: `test/src/components/common/base/widget_props_test.dart`, with narrow imports. It defines `_StatelessProbe extends StratumStatelessWidget` and `_StatefulProbe extends StratumStatefulWidget`, and `_FakeTheme extends Fake implements StratumThemeData` that sets only `defaultWidgetSize`. No full `StratumThemeData` fixture is needed.

1. **Default parity:** `_StatelessProbe()` and `_StatefulProbe()` both have `state == FullWidgetState.normal`, `disabled`, `loading`, and `debug` false, and every other field null. The analyzer cannot catch a default that differs between the two constructors; this test does.
2. **`resolveSize`:** a given `size` returns that size; a null `size` returns the fake theme's `defaultWidgetSize` under a `StratumThemeApplication`.
3. **`resolveWindowSize`:** a given `windowSize` returns without a `WindowSizeScope` in the tree and does not throw; a null `windowSize` returns the class that `WindowSizeScope` computes for the test view size.
4. **`resolveStyle`:** a null `customStyle` returns `defaults`; a non-null field of `customStyle` wins; a null field of `customStyle` keeps the default.
5. **`resolveTheme`:** `themeMode: ThemeMode.dark` returns the dark fake theme when the app theme mode is light; a null `themeMode` returns the app's theme.
6. **Stateful parity:** one `resolveSize` case through `_StatefulProbe` confirms that the mixin reaches `StratumStatefulWidget`.

## 8. Phases and prerequisites

1. **Base refactor, test-first.** Write each test in section 7, watch it fail, then write the code that passes it: `widget_props.dart`, both base classes, and the exports in `base.dart`. Fix the base files before exporting them, so the barrel gains no new errors. Gate: `flutter test test/src/components/common/base/` passes and `dart analyze lib/src/components/common/base/ test/src/components/common/base/` reports 0 issues.
2. **Doc sync.** In `docs/superpowers/specs/2026-09-30-stratum-read-figma-skill.md`, change the `platform` mapping row from `resolveBreakpoint()` to `resolveWindowSize()`, and change the `customStyle` row, which cites `customColor` and `customHeight` as the base class pattern, to cite `customStyle` alone.

## 9. Out of scope

- The 9 errors in `custom_scroll_view.dart`, `grid_view.dart`, and `list_view.dart` (owner's work in progress). `layout.dart` does not export these files and no library imports them, so they do not block the barrel. Layout primitives do not extend the base classes.
- Other green-build errors listed in the ContainerLayout design, section 11.
- Resolving `color: ColorEnum?` to a theme color; each component maps it.
- Validating combinations of `state`, `disabled`, and `loading`.
- Building any component on the base classes.

## 10. Evidence

Checked on 2026-09-30:

- `dart analyze lib/src/components/common/base/` reports the 5 errors in section 3; `dart analyze lib` reports errors only in the base files, the three scroll views, and `src.dart`. The base files are not reachable from the barrel, because `base.dart` is empty.
- `git grep StratumStatelessWidget HEAD -- lib` lists only the three scroll views outside `base/`; the working tree has no subclass.
- `git show HEAD:lib/src/components/common/base/base.dart` is empty.
- `flutter test test/stratum_ui_test.dart` failed to compile: `'BaseResponse' is exported from both 'package:dart_falmodel/networks/https/responses/base_response.dart' and 'package:http/src/base_response.dart'`. Adding `BaseResponse` to the `hide` list of the `extended_image` export in `lib/stratum_ui.dart` removed it. The analyzer then reported `ImageDecoderCallback` as an ambiguous export (from `dart:ui` through `flutter_falconx` and from Flutter's `image_provider.dart`); `hide ImageDecoderCallback` on the `flutter_falconx` export in `src.dart` removed it, and `src.dart` reports no further issue.
- A throwaway test that imports `src.dart` and `theme_application.dart` passes (`+1: All tests passed!`), so the barrel loads in tests.
- `WindowSizeScope.of` and `StratumThemeApplication.of` both throw `FlutterError` when their ancestor is missing.
