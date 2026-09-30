# StratumInkWell design

- **Date:** 2026-10-01
- **Status:** Implemented on master on 2026-10-01; planning amendments in section 12.
- **Location:** new `lib/src/components/common/stratum_ink_well.dart`; changes in `lib/src/components/common/style/animated_styled_box.dart`, `lib/src/components/common/layout/container_layout.dart`, and the five `gesture_*_layout.dart` files.

## 1. Goal

Add `StratumInkWell`, the one tap surface of the design system. It keeps what Flutter's `InkWell` does well (gesture recognition, keyboard activation, focus, hover, the semantic tap action) and closes the gaps that `InkWell` and the current `GestureContainerLayout` leave open: no button role, no disabled flag for screen readers, ink hidden under an opaque background, a disposed caller `FocusNode`, stale theme colors, and one global keyboard handler per instance. `GestureContainerLayout` then delegates all interaction to `StratumInkWell`, and the five gesture layouts share one callback naming convention.

Success criteria:

- Every test in section 8 is written before its implementation, fails first, and then passes.
- `flutter test test/src/components/common/` passes.
- `flutter analyze lib` reports no error outside the 8 errors that exist today in `custom_scroll_view.dart`, `grid_view.dart`, and `list_view.dart` (owner work in progress).
- No file under `lib/src/components/common/layout/` still declares `onSecondaryPress`, `onPress`, a `FocusNode` listener, or a `HardwareKeyboard` handler.

## 2. Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Pressed feedback | Flat overlay: `overlayHover` on hover, `overlayActive` on press, painted over the child. Material ripple is off (`NoSplash.splashFactory`, transparent overlay colors). | Figma states `HOVERED` and `PRESSED` are flat fills. A foreground overlay also removes the ink-under-background defect (section 3, D4). |
| Callback naming | Layered, as Flutter does it. Primitives (`StratumInkWell`, gesture layouts) use `onTap`, `onDoubleTap`, `onLongPress`, `onSecondaryTap`. Components (`StratumButton` and later ones) use `onPressed` and `onLongPress`. | Matches `InkWell`/`GestureDetector` and `ElevatedButton`, so developers reuse Flutter habits. The component rule is already fixed by the read-figma spec. Rejected: `onPressed` everywhere (`onDoublePressed` and `onSecondaryPressed` exist nowhere in Flutter); `onTap` everywhere (contradicts the approved read-figma contract). |
| Scope | `StratumInkWell` plus the move of `GestureContainerLayout` onto it | Interaction logic then lives in one place, and defects D5 to D7 are fixed where they live. The other four gesture layouts already delegate to `GestureContainerLayout`, so they only take the renames. |
| Tap requests focus | Only when `focusType == FocusType.focused` | The default (`focusedVisible`) no longer steals focus from a focused `TextField`, which closed the soft keyboard on mobile. Callers that want click-to-select keep it through `focused`. |
| Semantics role | Reuse `semantics: SemanticsProperties?`. `null` gives `button: true` when an activation callback exists. A non-null value hands the role to the caller. `container` and `enabled` are always set by an outer wrapper. | No new parameter. A parent `Semantics` cannot remove a child's button flag, so checkbox, radio, link, and tab components need this way out. |
| Theme access | One class reads `context.theme` directly | The barrel compiles in tests today (`container_layout_test.dart` passes through it), so a theme-free core class buys nothing. Rejected: a separate core class that receives resolved colors. |
| Overlay and ring placement | `AnimatedStyledBox` gains `boxBuilder`, applied after the size constraints and before margin, transform, and opacity. `GestureContainerLayout` passes `StratumInkWell` through it. | The overlay, focus ring, and hit area then match the box: they exclude the margin, rotate and transform with the box, and fade with its opacity. One `AnimatedStyledBox` per layout keeps the frame cost unchanged. Rejected: a second `AnimatedStyledBox` for the outer layer (two animation controllers per layout); documenting the limitation (a visible defect that components would hit). |
| Base class | Plain `StatefulWidget` with a plain `State` | Layout primitives do not extend `StratumStatefulWidget` (base-widget-props spec, section 5). `FalconState` adds nothing that `StratumInkWell` uses. |
| Imports | `stratum_ink_well.dart` imports only the libraries it uses | Follows the rule set by the ContainerLayout design. `context_extension.dart` still reaches the barrel, so this documents dependencies without isolating the file. |
| Test run | Test-first | Owner ruling 2026-09-30 in the base-widget-props spec. |

## 3. Current defects

| ID | Location | Defect | Fix |
|---|---|---|---|
| D1 | `InkWell` (`ink_well.dart:1401`) | The node has a tap action but no button role, so VoiceOver does not say "Button" and TalkBack names no role. | Outer `Semantics(button: true)` when an activation callback exists and `semantics` is null. |
| D2 | `InkWell` | A disabled `InkWell` only drops its action; screen readers cannot say "dimmed". | Outer `Semantics(enabled: !disabled)` when an activation callback exists. |
| D3 | `InkWell` | No `container: true`, so the node can merge into an ancestor or sibling. | Outer `Semantics(container: true)`. |
| D4 | `gesture_container_layout.dart:255` | `Material` paints ink before its child (`material.dart:621–634`), and `AnimatedStyledBox` paints the background inside that child, so an opaque background hides hover and press ink. | Ink off; the overlay is a foreground `DecoratedBox` above the child. |
| D5 | `gesture_container_layout.dart:118, 167, 350` | `dispose()` disposes a caller-owned `focusNode`; switching from the internal node to a caller node leaks the internal one. | Track ownership; dispose only the node the widget created. |
| D6 | `gesture_container_layout.dart:128` | Theme colors are cached once behind `_cacheInitialized`, so a light and dark switch keeps the old overlay colors. | Read `context.theme.color` on every build. |
| D7 | `gesture_container_layout.dart:120` | Each instance adds a `HardwareKeyboard` handler and a `Listener` to guess the input method. | Use `FocusManager.instance.highlightMode` and `addHighlightModeListener`, which `InkWell` itself uses (`ink_well.dart:1148`). |
| D8 | `gesture_container_layout.dart:22`, `gesture_wrap_layout.dart:28` | Callback names mix `onTap`, `onSecondaryPress`, and `onPress`. | Rename per section 2. |
| D9 | `gesture_wrap_layout.dart:48`, `gesture_stack_layout.dart:40` | `_hasGestures` starts with `!disabled`, so a disabled wrap or stack skips the gesture wrapper and loses its disabled semantics and cursor. | Decide the wrapper from the callbacks only; `disabled` is handled inside `StratumInkWell`. |
| D10 | `ink_well.dart:1315–1320` | `InkWell` reports hover only when an activation callback exists, so a layout with `onHover` alone never calls it. | `StratumInkWell` feeds `onHover` from its own `MouseRegion` and does not pass it to `InkWell`. |

## 4. Public API

### `StratumInkWell`

```dart
class StratumInkWell extends StatefulWidget {
  const StratumInkWell({
    super.key,
    required this.child,
    // Gestures
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.onSecondaryTap,
    this.onHover,
    this.onHighlightChanged,
    // State
    this.disabled = false,
    this.statesController,
    // Look
    this.borderRadius,
    this.disabledPressAnimation = false,
    this.mouseCursor,
    // Focus
    this.focusNode,
    this.focusType = FocusType.focusedVisible,
    this.showFocusOnPrimary = true,
    this.canRequestFocus = true,
    this.autofocus = false,
    this.onFocusChange,
    // Semantics and feedback
    this.semantics,
    this.excludeFromSemantics = false,
    this.enableFeedback = true,
  });

  final Widget child;
  final GestureTapCallback? onTap;
  final GestureTapCallback? onDoubleTap;
  final GestureLongPressCallback? onLongPress;
  final GestureTapCallback? onSecondaryTap;
  final ValueChanged<bool>? onHover;
  final ValueChanged<bool>? onHighlightChanged;
  final bool disabled;
  final WidgetStatesController? statesController;
  final BorderRadiusGeometry? borderRadius;
  final bool disabledPressAnimation;
  final MouseCursor? mouseCursor;
  final FocusNode? focusNode;
  final FocusType focusType;
  final bool showFocusOnPrimary;
  final bool canRequestFocus;
  final bool autofocus;
  final ValueChanged<bool>? onFocusChange;
  final SemanticsProperties? semantics;
  final bool excludeFromSemantics;
  final bool enableFeedback;
}
```

`statesController` doubles as a preview input: a caller that sets `{WidgetState.hovered}` sees the hover overlay without a pointer, for golden tests and Figma parity. `StratumInkWell` is exported from `common.dart`.

### `AnimatedStyledBox` and `ContainerLayout`

Both gain one optional parameter:

```dart
/// Wraps the styled box after its size constraints and before its margin,
/// transform, and opacity. Receives the style of the current animation frame.
final Widget Function(WidgetStyle style, Widget box)? boxBuilder;
```

`ContainerLayout` forwards `boxBuilder` to `AnimatedStyledBox` unchanged. With `boxBuilder == null`, both widgets build the same tree as today.

### Gesture layouts

- `GestureContainerLayout` becomes a `StatelessWidget`. It keeps its public parameters, renames `onSecondaryPress` to `onSecondaryTap`, and passes a `boxBuilder` that returns `StratumInkWell` with `borderRadius: style.borderRadius` and every interaction parameter forwarded.
- `GestureColumnLayout`, `GestureRowLayout`, `GestureStackLayout`, and `GestureWrapLayout` rename `onSecondaryPress` to `onSecondaryTap`. `GestureWrapLayout` also renames `onPress` to `onTap`.
- No caller exists outside `lib/src/components/common/layout/`, so the renames ship without deprecated aliases.
- A gesture layout builds the interaction wrapper when any of `onTap`, `onDoubleTap`, `onLongPress`, `onSecondaryTap`, `onHover`, `onHighlightChanged`, or `onFocusChange` is non-null, whatever the value of `disabled` (D9).
- `semantics` goes to `StratumInkWell` when the wrapper is built, and to `ContainerLayout.semantics` otherwise.

## 5. Widget tree and data flow

`StratumInkWell` builds, from the outside in:

```
Semantics(container: true, enabled: …, button: …)   skipped when excludeFromSemantics
 └ Semantics.fromProperties(semantics)               only when semantics != null
   └ FocusSpread(focus: ring, borderRadius)          only when focusType is focused or focusedVisible
     └ MouseRegion(onEnter, onExit)                  only when onHover != null; null handlers while disabled (D10)
       └ Material(type: MaterialType.transparency)   satisfies InkWell's Material ancestor check
         └ InkWell(splashFactory: NoSplash.splashFactory, overlayColor: transparent,
                   statesController, focusNode, callbacks …)
           └ overlay: ListenableBuilder → TweenAnimationBuilder<Color?> → DecoratedBox(position: foreground)
             └ child
```

Inside `GestureContainerLayout`, the order becomes:

```
ContainerLayout rotate (Transform.rotate)
 └ AnimatedStyledBox: opacity → transform → margin
   └ boxBuilder → StratumInkWell (tree above)
     └ size constraints → decoration, clip, blur → padding → alignment → ratio → child
```

Data flow:

- `InkWell` writes `hovered`, `pressed`, `focused`, and `disabled` into the states controller. The overlay listens to it through a `ListenableBuilder` below `InkWell`. `InkWell` updates the controller inside its own `didUpdateWidget`, and a listener above `InkWell` would then call `setState` during the build of a descendant, which Flutter rejects.
- `FocusManager.instance.highlightMode` and the focus node decide the ring. `StratumInkWell` listens to both.
- Colors come from `context.theme.color` in `build`. The ring color is the `FocusSpread` default (`borderBrand` at 30 % alpha).

## 6. Behavior

### Overlay

| State, in priority order | Overlay color |
|---|---|
| `disabled` or `disabledPressAnimation` | none |
| `WidgetState.pressed` | `theme.color.overlayActive` |
| `WidgetState.hovered` | `theme.color.overlayHover` |
| any other state, including `focused` | none (focus shows the ring) |

The overlay animates to its target color over 100 ms with `Curves.easeInOutSine` and takes the shape of `borderRadius`.

### Focus

- **Ownership.** With `focusNode == null`, the state creates a node on first use and keeps it until `dispose`, the pattern `TextField` uses. A caller node is never disposed. A change of the parameter moves the listener from the old node to the new one; the internal node is not disposed mid-update, because `InkWell`'s `Focus` still holds it until its own update runs. The internal states controller follows the same pattern.
- **Focusable.** `canRequestFocus` passed to `InkWell` is `!disabled && focusType != FocusType.none && canRequestFocus`.
- **Ring.** `none` and `invisible` never show it. `focusedVisible` shows it while focused and `highlightMode == FocusHighlightMode.traditional`. `focused` shows it while focused. "Focused" means `hasPrimaryFocus` when `showFocusOnPrimary` is true, else `hasFocus`.
- **Tap.** With `focusType == FocusType.focused`, a tap requests focus before it calls `onTap`. Other values leave focus where it is.
- `onFocusChange` receives every focus change of the node.

### Semantics

- `hasActivation` is true when `onTap`, `onDoubleTap`, `onLongPress`, or `onSecondaryTap` is non-null. It ignores `disabled`.
- With `excludeFromSemantics`, `StratumInkWell` adds no container node or role and `InkWell` drops its actions. A caller `semantics` still applies, because `excludeFromSemantics` plus a custom label and actions is the usual way to replace gesture semantics.
- Otherwise the outer node is `Semantics(container: true, enabled: hasActivation ? !disabled : null, button: semantics == null && hasActivation)`. `InkWell`'s own `Semantics(onTap:)` is not a container, so its action merges into this node.
- A disabled widget with a callback reads as a dimmed button with no action.

### Disabled

- Every callback passed to `InkWell` is `null`, and the `MouseRegion` for `onHover` keeps its place with null handlers, so toggling `disabled` never changes the widget structure.
- No overlay, no ring, and no focus. When the node holds focus as `disabled` turns true, Flutter moves focus away because the node can no longer request it.
- The cursor is `mouseCursor ?? (disabled ? SystemMouseCursors.forbidden : null)`; `null` keeps `InkWell`'s default, as today.

## 7. Edge cases

| Case | Handling |
|---|---|
| Style wrappers above `boxBuilder` appear or disappear (for example `opacity` drops below 1) | `AnimatedStyledBox` wraps the `boxBuilder` result in a `KeyedSubtree` with its own `GlobalKey`, the same way it keeps the child today (`animated_styled_box.dart:60`). Without it, `StratumInkWell` would lose its focus node and states mid-hover. |
| `boxBuilder` with a null `style` | Applied anyway; `AnimatedStyledBox` already falls back to `const WidgetStyle()`. |
| Caller swaps `statesController` | The overlay's `ListenableBuilder` and `InkWell` both move to the new controller. The internal controller, if one was created, lives until `dispose`. |
| A quick tap shorter than 100 ms | The overlay may not reach full `overlayActive` before it fades. Accepted. |
| `onHover` with no activation callback | Called through `MouseRegion` (D10). No overlay appears, because `InkWell` sets `hovered` only when an activation callback exists. |
| `disabled` turns true while hovered or pressed | The overlay fades out on the next build; `InkWell` clears its own highlights. |

## 8. Testing

Theme setup follows `widget_props_test.dart`: `StratumThemeApplication(lightTheme, darkTheme)` around the widget under test.

`test/src/components/common/stratum_ink_well_test.dart`:

| Group | Tests |
|---|---|
| Overlay | A `{hovered}` preset paints `overlayHover`. `pressed` wins over `hovered`. `disabled` and `disabledPressAnimation` paint nothing. A new `lightTheme` changes the color (D6); the test swaps `lightTheme` because `StratumThemeApplication.updateShouldNotify` compares only `lightTheme`. The duration is 100 ms and the default curve is `easeInOutSine`. The overlay `DecoratedBox` is a foreground decoration between `InkWell` and the child (D4). |
| Focus | Unmounting leaves a caller `focusNode` usable (D5). The node swaps from internal to caller and back without error. `focusedVisible` shows the ring only in traditional highlight mode. `focused` takes focus on tap. `focusedVisible` keeps focus on another focused node after a tap. `none` cannot take focus. `invisible` takes focus with no ring. `disabled` cannot take focus. |
| Semantics | `onTap` gives a container node with button, enabled, and a tap action (D1–D3). `disabled` gives button and `enabled: false` with no action (D2). `onHover` alone gives no button flag. A `semantics` value with `checked` gives no button flag and keeps the enabled flag. `excludeFromSemantics` gives no flags and no action. |
| Gestures | Tap, double tap, long press, and secondary tap call the matching callback. `disabled` calls none. Enter calls `onTap`. `onHover` alone is called on pointer enter and exit (D10). |

`test/src/components/common/style/animated_styled_box_test.dart` (additions):

- The `boxBuilder` result sits below the margin `Padding` and above the size `ConstrainedBox`.
- The `boxBuilder` result keeps its `State` when `opacity` changes from 1 to 0.5.
- With `boxBuilder == null`, every existing test still passes.

Gesture layout tests:

- `GestureContainerLayout` with `margin: EdgeInsets.all(8)` paints an overlay the size of the box, without the margin.
- With `rotate`, `StratumInkWell` is a descendant of the `Transform`.
- A disabled `GestureWrapLayout` or `GestureStackLayout` with `onTap` reads as a dimmed button (D9).
- `onSecondaryTap` reaches the callback through each gesture layout.

## 9. Verification

1. `flutter test test/src/components/common/` passes.
2. `flutter analyze lib` shows the same 8 errors in the three owner files and no other error.
3. `grep -rE "onSecondaryPress|onPress\b|keyboard\.addHandler" lib/src/components/common/layout/` returns nothing.

## 10. Out of scope

- The frame-time benchmark (roadmap phase `stratum-style-benchmark`).
- The three owner files with errors: `custom_scroll_view.dart`, `grid_view.dart`, `list_view.dart`.
- `test/stratum_ui_test.dart`, which fails to load on a template `Calculator` reference.
- Renaming `disabledPressAnimation`.
- Components that use `StratumInkWell`, such as `StratumButton`.
- `ContainerLayout` rotate appearing or disappearing above `AnimatedStyledBox`, which already rebuilds the box.

## 11. Evidence

- Flutter 3.47.3 SDK: `material/ink_well.dart:1401` (semantics wrapper), `:1148` (`highlightMode`), `:1292` (`isWidgetEnabled`), `:1315–1320` (hover only when enabled); `material/material.dart:621–634` (ink painted before the child); `widgets/feedback.dart` (`enableFeedback` effects).
- `lib/src/components/common/style/animated_styled_box.dart:60` (child `GlobalKey`), `:133` (size), `:137` (margin), `:141` (transform), `:149` (opacity).
- `lib/src/components/common/layout/container_layout.dart:64–69` (rotate outside `AnimatedStyledBox`).
- `lib/src/extensions/context_extension.dart:1` (theme access reaches the barrel).
- `lib/src/themes/theme_data.dart:45` (`toThemeData()` has no caller, so Material theme colors are not a usable fallback).
- `docs/superpowers/specs/2026-09-30-stratum-read-figma-skill.md:76` (components use `onPressed`).
- `docs/superpowers/specs/2026-09-30-base-widget-props-design.md:34, 169` (barrel loads in tests; the three erroring files block nothing).
- `test/src/components/common/layout/container_layout_test.dart`: 10 tests pass through the barrel on 2026-10-01.

## 12. Decisions log

- 2026-10-01: flat overlay; layered callback naming; scope includes `GestureContainerLayout`; tap focus tied to `focusType`; `semantics` parameter carries the role; one class reads the theme; `boxBuilder` placement.
- 2026-10-01, added while writing the spec: `GlobalKey` around the `boxBuilder` result; `MouseRegion` for `onHover` (D10); `boxBuilder` receives the animated style so the overlay radius follows a radius animation.
- 2026-10-01, owner approval: overlay timing stays 100 ms with `easeInOutSine`; the unused theme token `animation.normal` is not adopted.
- 2026-10-01, planning amendments: internal focus node and states controller live until `dispose`; the overlay listens through a `ListenableBuilder` below `InkWell`; the `onHover` `MouseRegion` stays in place while disabled; the theme-change test swaps `lightTheme`.
- 2026-10-01, final review: a caller `semantics` applies even with `excludeFromSemantics` (fixes a regression against the old `GestureContainerLayout`).
