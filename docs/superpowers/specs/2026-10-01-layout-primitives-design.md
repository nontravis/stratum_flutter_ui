# Layout primitives design

- **Date:** 2026-10-01
- **Status:** Approved in brainstorming on 2026-10-01; written spec awaiting owner review.
- **Location:** `lib/src/components/common/layout/` (all files), new `lib/src/components/common/interaction.dart`, and changes in `lib/src/components/common/ink_well.dart`, `lib/src/components/common/style/animated_styled_box.dart`, `lib/src/themes/behavior/`, and `lib/src/themes/theme_application.dart`.

## 1. Goal

Turn the layout folder into a small family of primitives that share one build pipeline, hold 60 fps on 120 Hz displays (an 8.3 ms frame budget), and work by keyboard and screen reader on desktop as well as mobile. Today the folder holds 14 files: five box layouts, five gesture twins that forward about 19 interaction parameters each by hand, three scroll views that do not compile, and a barrel. The parameters have already drifted between twins, two scroll behaviors do nothing on the current Flutter SDK, and no layout offers a keyboard path beyond Enter and Space.

After this work the folder holds five box layouts on one base class, three scroll views on one shared scroll frame, and one interaction value object. Interaction, scrolling, semantics, and reduced motion each have one implementation.

Success criteria:

- Every test in section 8 is written before its implementation, fails first, and then passes.
- `flutter test test/src/components/common/` passes after each phase.
- `flutter analyze lib` reports 0 errors after phase 1.
- No file under `lib/` declares a `Gesture*Layout` class, an `App*View` class, `NoGlowScrollBehavior`, or a `buildViewportChrome` method.
- The benchmark in section 9 meets its pass criteria after phases 3 and 4.

## 2. Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Naming | A primitive takes the Flutter widget name plus `Layout`, with no prefix: `ContainerLayout`, `ColumnLayout`, `RowLayout`, `StackLayout`, `WrapLayout`, `ListViewLayout`, `GridViewLayout`, `CustomScrollViewLayout`; base `BoxLayout`. Value classes and components keep the `Stratum` prefix: `StratumInteraction`, `StratumFocusGroup`, `StratumInkWell`. | Owner ruling 2026-10-01. The five box layouts keep their current names, so only the scroll views and the removed gesture twins change for callers. `App*` theme-token classes in `lib/src/themes/styles/` stay out of scope. |
| Family structure | Five layouts extend one abstract `BoxLayout`; interaction parameters live in one `StratumInteraction` object passed as `interaction:`; the five `Gesture*Layout` classes are removed | Owner chose option A over flat parameters (about 30 per constructor) and over keeping gesture twins (ten classes, and a caller that swaps types remounts the subtree). Callers of primitives are mostly components, so the extra object at the call site costs little. |
| Bundle name | `interaction: StratumInteraction` | The bundle carries pointer, focus, keyboard, semantics, and cursor settings. In Flutter "gesture" means pointer input only (`GestureDetector`), so `gesture:` would mislabel shortcuts and focus. |
| Build tiers | `bare` when `style`, `ratio`, `rotate`, `transform`, and `interaction` are null and `scrollable` is false; `box` otherwise. The tier depends on whether a parameter is null, never on its content. | Matches what `StackLayout` and `WrapLayout` already do (`_hasContainerFeatures`) and removes the animation controller from plain column and row structure. Switching a parameter between null and a value remounts the children; dartdoc tells callers to pass `const WidgetStyle()` or `const StratumInteraction()` up front when a value can appear later. |
| Lazy animation controller | Decided by measurement: if benchmark scene S2 builds more than 10% slower than S1 (section 9), phase 3 rewrites `AnimatedStyledBox` to create its controller on the first animated change | The threshold is fixed before measuring, so the numbers decide. |
| Scrolling | `scrollable: true` scrolls inside the box, as Figma overflow scrolling does: fill, border, radius, and shadow stay fixed; padding and children scroll | Owner ruling 2026-10-01. The current wrapper sits outside the box, so the background scrolls away with the content. |
| Scroll physics and behavior | One resolver: the widget's `physics` parameter, then the theme's `physics` and `scrollBehavior` through a new `StratumThemeApplication.maybeOf`, then the inherited `ScrollConfiguration` | `StratumThemeApplication` is an `InheritedWidget`, so it cannot insert a `ScrollConfiguration` above its child. Without a theme the primitives fall back to Flutter defaults instead of throwing. |
| Semantics placement | Inside the margin for every layout, through `AnimatedStyledBox.boxBuilder` | The semantic rect then equals the visible box, which focus highlights and target-size checks measure. |
| Reduced motion | Android `disableAnimations` stays with `AnimationController`, which already scales durations to 5%. On iOS Reduce Motion, geometry fields jump to their target and paint fields still fade. | Apple's guidance replaces motion with fades rather than removing all transitions. |
| Desktop keyboard | K1 context-menu key and Shift+F10; K2 focus-scoped `shortcuts`; K3 roving focus group; K4 focusable scroll views with Home and End | Owner chose all four on 2026-10-01; the owner targets desktop as well as mobile. |
| Shortcut shape | `Map<ShortcutActivator, VoidCallback>`, focus-scoped only | Owner chose the callback map. Components that need menu labels can wrap Flutter's `Shortcuts` and `Actions` themselves. |
| Scroll focus default | `focusable: null` means true on macOS, Windows, Linux, and web, false on iOS and Android | Firefox model: every scroller is a Tab stop. The Chrome model (focusable only when no child is) needs a descendant scan on every list change. |
| Spec shape | One spec with four phases, one plan per phase | Owner ruling 2026-10-01; the phases share every decision above. |
| Performance proof | Benchmark baseline on the current layouts before the refactor | Owner ruling 2026-10-01. |

## 3. Current defects

| ID | Defect | Where |
|---|---|---|
| D1 | `WrapLayout` with `scrollable` scrolls along `direction`, so a horizontal wrap gets unbounded width and never wraps. `GestureWrapLayout` scrolls along the cross axis. | `wrap_layout.dart:116`, `gesture_wrap_layout.dart:158` |
| D2 | `NoGlowScrollBehavior` and `StratumScrollBehavior` declare `buildViewportChrome`, which Flutter 3.47.3 no longer has. Without `@override` the method compiles and never runs. | `themes/behavior/` |
| D3 | Each scroll view adds `NotificationListener<OverscrollIndicatorNotification>` that returns true, so no ancestor receives the notification. | `list_view.dart:50`, `grid_view.dart:48`, `custom_scroll_view.dart:54` |
| D4 | The scroll views declare `super.padding` and `super.border` on `StatelessWidget`; these are all 8 errors that `flutter analyze lib` reports. | `custom_scroll_view.dart`, `grid_view.dart`, `list_view.dart` |
| D5 | `cacheExtent` is deprecated after v3.41.0-0.0.pre in favor of `scrollCacheExtent`. | `list_view.dart:68`, `grid_view.dart:65` |
| D6 | `ListView` and `GridView` hard-code `ClampingScrollPhysics`; the theme's `scrollBehavior` and `physics` are never read. | `theme_data.dart:17-18` |
| D7 | `ColumnLayout` and `RowLayout` always build `AnimatedStyledBox` (a controller, a ticker, and two `GlobalKey`s) even with no style. | `column_layout.dart:81`, `row_layout.dart:82` |
| D8 | The gesture column and row insert `Gap` widgets by hand: two list allocations per build and n−1 extra render objects. The plain twins use `Column.spacing`. | `gesture_column_layout.dart:175`, `gesture_row_layout.dart:181` |
| D9 | Scrollable column and row use `Clip.none`, so content paints outside the viewport. | `column_layout.dart:121` |
| D10 | `ContainerLayout` wraps `Semantics` outermost, so the semantic rect includes the margin and rotation; `GestureContainerLayout` places it inside the margin. | `container_layout.dart:86` |
| D11 | The scroll wrapper sits outside the box, so fill, border, and padding scroll with the content. | all `scrollable` layouts |
| D12 | Parameter drift: gesture twins lack `debug` and `transformAlignment`; `StackLayout` clips with `Clip.hardEdge` while `GestureStackLayout` uses `Clip.none`; only `ColumnLayout` stretches short content to the viewport; `GestureRowLayout.disableFocused` is never read. | gesture twins |
| D13 | `layout.dart` exports neither the four non-container gesture layouts nor the scroll views. | `layout.dart` |
| D14 | iOS Reduce Motion (`AccessibilityFeatures.reduceMotion`) is not honored. | `animated_styled_box.dart` |
| D15 | Keyboard and assistive gaps: no key reaches `onSecondaryTap`; screen readers reach only tap and long press; no focus-scoped shortcut API; no roving group; a desktop list with no focusable item cannot scroll by keyboard; Home and End do nothing. | section 12 |
| D16 | A focused `InkWell` item in a lazy list stays alive only while highlights or splashes exist, so focus can be lost when it scrolls past the cache extent. | `ink_well.dart:993` (SDK) |

## 4. Public API

### `BoxLayout`

```dart
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

  @nonVirtual
  @override
  Widget build(BuildContext context);

  /// The layout's own content: a Column, Row, Stack, Wrap, or child.
  @protected
  Widget buildContent(BuildContext context);

  /// The axis that `scrollable` scrolls along.
  @protected
  Axis get scrollDirection => Axis.vertical;
}
```

`build` runs the pipeline in section 5 and is the only implementation of it. Subclasses declare their own parameters plus `super.` parameters and override `buildContent`; `RowLayout` overrides `scrollDirection` to horizontal, and `WrapLayout` returns the axis that crosses `direction`.

### Box layouts

| Class | Own parameters |
|---|---|
| `ContainerLayout` | `child` |
| `ColumnLayout` | `mainAxisAlignment` (`start`), `mainAxisSize` (`max`), `crossAxisAlignment` (`center`), `textDirection`, `verticalDirection` (`down`), `textBaseline`, `crossAxisIntrinsic` (`false`), `gap`, `focusGroup`, `children` |
| `RowLayout` | the same as `ColumnLayout` |
| `StackLayout` | `alignment` (`AlignmentDirectional.topStart`), `fit` (`StackFit.loose`), `textDirection`, `clipBehavior` (`Clip.hardEdge`), `children` |
| `WrapLayout` | `direction` (`horizontal`), `alignment` (`start`), `gap`, `runGap`, `runAlignment` (`start`), `crossAxisAlignment` (`start`), `textDirection`, `verticalDirection` (`down`), `clipBehavior` (`Clip.none`), `focusGroup`, `children` |

Defaults follow Flutter's own widgets. `gap` and `runGap` follow Figma auto layout names; `WrapLayout` drops `spacing` and `runSpacing`. Column and row keep the current rule that a set `height` or `maxHeight` (width for row) forces `MainAxisSize.max`. `ContainerLayout` drops its public `boxBuilder`, which only `GestureContainerLayout` used.

### `StratumInteraction`

```dart
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
    // Phase 4:
    this.shortcuts = const {},
    this.secondaryTapSemanticsLabel,
  });
}
```

The fields map one to one onto `StratumInkWell`. `semantics` stays on `BoxLayout`, because non-interactive layouts use it too, and `BoxLayout` hands it to `StratumInkWell` when an interaction is present. The class does not override `==`: callbacks compare by identity, and a `StatelessWidget` parent rebuilds its subtree either way. Phase 4 adds `shortcuts` and `secondaryTapSemanticsLabel`; both have defaults, so the change does not break callers.

A layout builds `StratumInkWell` when `interaction` is non-null and has at least one of: an activation callback, `onHover`, `onHighlightChanged`, `onFocusChange`, or a non-empty `shortcuts` map. A non-null `interaction` with none of them keeps the box tier and adds no tap surface.

### `StratumFocusGroup`

```dart
@immutable
class StratumFocusGroup {
  const new({this.role, this.loop = false});

  final SemanticsRole? role;
  final bool loop;
}
```

`ColumnLayout`, `RowLayout`, and `WrapLayout` take `focusGroup:`. Null builds nothing. Behavior is in section 6.

### Scroll views

| Class | Replaces | Parameters |
|---|---|---|
| `ListViewLayout.builder` | `AppListView.builder` | `style`, `gap`, `scrollDirection`, `reverse`, `controller`, `primary`, `physics`, `showScrollbar`, `focusable`, `shrinkWrap`, `itemExtent`, `prototypeItem`, `itemCount`, `itemBuilder`, `findChildIndexCallback`, `addAutomaticKeepAlives`, `addRepaintBoundaries`, `addSemanticIndexes`, `scrollCacheExtent`, `semanticChildCount`, `dragStartBehavior`, `keyboardDismissBehavior`, `restorationId`, `clipBehavior` |
| `GridViewLayout.builder` | `AppGridView.builder` | `gridDelegate`, then the list parameters without `gap`, `itemExtent`, and `prototypeItem` |
| `CustomScrollViewLayout` | `AppCustomScrollView` | `style`, `slivers` or `children` (exactly one), `controller`, `scrollDirection`, `reverse`, `shrinkWrap`, `physics`, `showScrollbar`, `focusable` |

`physics: null` resolves as in section 2. `showScrollbar: null` uses the resolved behavior's default, which shows a scrollbar on desktop. `gap` builds `ListView.separated` and asserts that `itemExtent` and `prototypeItem` are null. `AppCustomScrollView.width` and `border` move into `style`; its `scrollBehavior` parameter is removed in favor of the resolver.

### Theme and behavior

- `StratumThemeApplication.maybeOf(BuildContext context, {ThemeMode? themeMode})` returns `StratumThemeData?` and never throws.
- `StratumScrollBehavior` overrides `buildOverscrollIndicator` to return `child`, with `@override` on every member, and stays `const`.
- `NoGlowScrollBehavior` and its export are deleted.

### Files

| File | Change |
|---|---|
| `layout/box_layout.dart` | new: `BoxLayout` |
| `layout/container_layout.dart`, `column_layout.dart`, `row_layout.dart`, `stack_layout.dart`, `wrap_layout.dart` | rewritten on `BoxLayout` |
| `layout/list_view_layout.dart`, `grid_view_layout.dart`, `custom_scroll_view_layout.dart` | renamed from `list_view.dart`, `grid_view.dart`, `custom_scroll_view.dart` and rewritten |
| `layout/scroll_frame.dart` | new, `@internal`, not exported: the scroll resolver and `ScrollFrame` |
| `layout/focus_group.dart` | new: `StratumFocusGroup` and its traversal policy (phase 4) |
| `layout/gesture_*_layout.dart` (5 files) | deleted |
| `layout/layout.dart` | exports every public class above |
| `common/interaction.dart` | new: `StratumInteraction` |
| `common/ink_well.dart` | phase 4: K1, K2, shortcut-only focus, focus keep-alive |
| `style/animated_styled_box.dart` | `scrollBuilder` hook, reduced motion, and the lazy controller if section 9 calls for it |
| `themes/behavior/scroll_behavior.dart`, `behavior.dart`, `no_glow_scroll_behavior.dart` | fix, update export, delete |
| `themes/theme_application.dart` | `maybeOf` |

## 5. Widget tree and data flow

### Bare tier

```
_KeepAlive               keepAlive
WidgetPerformanceMonitor debug
RepaintBoundary          repaintBoundary
Semantics.fromProperties semantics
buildContent()
```

No `State`, controller, or `GlobalKey` exists in this tier.

### Box tier (outer to inner)

```
_KeepAlive               keepAlive
WidgetPerformanceMonitor debug
RepaintBoundary          repaintBoundary
Transform.rotate         rotate
AnimatedStyledBox
  Opacity, Transform, Padding(margin)
  boxBuilder:  StratumInkWell(semantics)     when the interaction needs a tap surface
               Semantics.fromProperties      otherwise, when semantics is set
  ConstrainedBox(size)
  DecoratedBox(foreground: border)           fixed
  DecoratedBox(background) / BackdropFilter  fixed
  clip
  scrollBuilder: ScrollFrame                 new hook, when scrollable
  Padding(padding)                           scrolls with the content
  Align, AspectRatio
  buildContent()
```

`boxBuilder` keeps its `GlobalKey`, so adding or removing a callback inside a non-null `interaction` does not remount the box (the guarantee from commit 7e86baf). The new `scrollBuilder` hook wraps the padded content after `Padding` and before the decorations, so the box stays fixed and the content scrolls inside it.

When `interaction` is non-null and the style has no `animationStyle`, the style animates over 100 ms with `easeInOutSine`, keeping the default that `GestureContainerLayout` has today.

## 6. Behavior

### Scrolling inside the box

- `ScrollFrame` builds a `SingleChildScrollView` along `scrollDirection`, with physics and behavior from the resolver.
- Content shorter than the viewport stretches to the viewport size minus the padding, through `LayoutBuilder` and a minimum constraint, so `spaceBetween` and `end` alignments still work. Every layout gets this, not only `ColumnLayout`.
- A box with `borderRadius` clips the viewport to the rounded shape with `Clip.antiAlias`, which adds no save layer. Without a radius the viewport keeps its own `Clip.hardEdge`.
- Scroll views apply the same model: `style.padding` becomes the list's sliver padding, which scrolls and builds lazily. `CustomScrollViewLayout` in children mode uses a `SliverPadding`; in slivers mode it asserts that `style.padding` is null, because wrapping several slivers in one group changes how pinned headers behave.

### Reduced motion

- On every style change, `AnimatedStyledBox` reads `accessibilityFeatures.reduceMotion`. When it is true, the begin style takes the target's geometry fields (`width`, `height`, minimum and maximum sizes, `padding`, `margin`, `alignment`) before the tween starts, so geometry jumps while colors, gradients, images, borders, radius, shadows, blur, and opacity fade over the normal duration.
- `disableAnimations` needs no change: `AnimationController` already shortens every animation to 5% of its duration.

### K1: context-menu key

- When `onSecondaryTap` is set and the interaction is not disabled, `StratumInkWell` binds `LogicalKeyboardKey.contextMenu` and Shift+F10 to it while its node has focus, on every platform.
- It also adds a `CustomSemanticsAction` for the secondary tap, labeled `secondaryTapSemanticsLabel`, else `MaterialLocalizations.showMenuTooltip` when material localizations are present, else `'Show menu'`.
- `onDoubleTap` has no keyboard or screen-reader path. Dartdoc states that no function may be reachable only by double tap (WCAG 2.1.1); `shortcuts` provides the alternative.

### K2: shortcuts

- `shortcuts` builds a `CallbackShortcuts` above the tap surface's focus node, so a binding fires while that node or a descendant has focus. An empty map builds nothing.
- Bindings never fire while the interaction is disabled.
- A binding whose activator has no control, meta, or alt modifier is skipped while primary focus is inside an `EditableText`, so a single-key shortcut does not take typed characters from a text field. With focus scoping, this satisfies WCAG 2.1.4.
- An interaction with shortcuts but no activation callback still receives focus: `InkWell` grants focus only when `enabled && canRequestFocus`, so `StratumInkWell` adds its own focusable node in that case. That node shows the focus ring and reports `focusable` but no button role, because Enter does nothing.

### K3: roving focus group

- Tab enters the group once and lands on the item that last held focus, or on the first item.
- Arrow keys move along the layout axis: Left and Right in a row (swapped under `TextDirection.rtl`), Up and Down in a column. In a wrap, Left and Right move in child order and Up and Down move by screen position.
- Home and End move to the first and last item. With `loop: true`, moving past either end wraps around.
- Tab and Shift+Tab always leave the group (WCAG 2.1.2).
- `role` sets `SemanticsRole` on the group node. Flutter 3.47.3 offers `list`, `menu`, `menuBar`, `radioGroup`, and `tabBar`, among others, and has no `toolbar` role.
- The group covers built children only; lazy lists use Tab and K4.

### K4: keyboard scrolling

- `ScrollFrame` owns a focus node when `focusable` resolves to true, and shows a `FocusSpread` ring around the viewport while it holds primary focus in traditional highlight mode (WCAG 2.4.7). Scrollable box layouts use the platform default and take no `focusable` parameter.
- While the viewport itself holds primary focus: Up and Down (Left and Right when horizontal) scroll one line, Page Up and Page Down scroll one page, and Home and End jump to the start and end. While an item inside holds focus, arrows keep moving focus, and Page Up, Page Down, Home, and End still scroll the viewport.
- Home and End use `jumpTo`, so no motion plays. A lazy list only estimates `maxScrollExtent`, so End jumps again after each frame until the extent stops changing, at most three times.
- The focus node sits above the `Scrollable`, where `ScrollAction` cannot find it through `Scrollable.maybeOf`. `ScrollFrame` therefore scrolls through `controller ?? internal controller`, and through `PrimaryScrollController.of` when `primary` is true, because Flutter forbids `primary` together with a controller.

### Focus keep-alive

`StratumInkWell` mixes in `AutomaticKeepAliveClientMixin` with `wantKeepAlive => focusNode.hasFocus` and calls `updateKeepAlive` on focus changes, as `EditableText` does. A focused item in a lazy list then survives scrolling past the cache extent.

## 7. Edge cases

- A tier change (a parameter going between null and a value) remounts `buildContent()`. Callers that toggle style or interaction pass a constant empty value instead of null.
- A `focusGroup` whose children contain no focusable node builds the group and does nothing on Tab.
- A `ListViewLayout` with `gap` and `itemExtent` fails its assertion in debug mode.
- `CustomScrollViewLayout` with both or neither of `slivers` and `children` fails its assertion.
- A scrollable layout inside an unbounded parent along its scroll axis throws the same error as a `SingleChildScrollView` in that position.
- Without `StratumThemeApplication` above it, a scroll view uses `ScrollConfiguration`; `StratumInkWell` still requires the theme, as it does today.

## 8. Testing

Widget tests with `flutter_test`; no golden images.

| Phase | File | Cases |
|---|---|---|
| 1 | `list_view_layout_test.dart`, `grid_view_layout_test.dart`, `custom_scroll_view_layout_test.dart`, `scroll_behavior_test.dart` | No `StretchingOverscrollIndicator` or `GlowingOverscrollIndicator` under `StratumScrollBehavior`; physics resolve from parameter, then theme, then `ScrollConfiguration`; `style.padding` scrolls while the decoration stays in place; an ancestor `NotificationListener` receives scroll notifications; children mode sets `semanticChildCount`; `maybeOf` returns null without a theme |
| 3 | `box_layout_test.dart` | Bare tier builds no `AnimatedStyledBox` or `StatefulElement`; each tier rule; semantic rect equals the box and excludes the margin |
| 3 | `column_layout_test.dart`, `row_layout_test.dart`, `stack_layout_test.dart`, `wrap_layout_test.dart`, `container_layout_test.dart` | Existing cases ported; Wrap scrolls along the cross axis; short content fills the viewport for `spaceBetween`; the decoration stays in place while the scroll offset changes; the viewport clips to the radius; Column and Row use `spacing` |
| 3 | `interaction_test.dart` | The nine cases of `gesture_layout_test.dart` ported to `interaction:`; a child keeps its `State` when a callback comes or goes; the 100 ms default animation |
| 3 | `animated_styled_box_test.dart` | With `FakeAccessibilityFeatures(reduceMotion: true)`, geometry reaches its target in one frame while color is mid-fade |
| 4 | `ink_well_test.dart` | `sendKeyEvent(LogicalKeyboardKey.contextMenu)` and Shift+F10 call `onSecondaryTap`; the custom semantics action exists; shortcuts fire only with focus; an unmodified binding is skipped inside a `TextField`; a shortcut-only interaction takes focus and has no button flag; a focused item survives scrolling past the cache extent |
| 4 | `focus_group_test.dart` | Tab enters once; arrows move; RTL swaps Left and Right; Home and End; `loop`; Tab and Shift+Tab leave the group; the group carries `role` |
| 4 | `scroll_frame_test.dart` | Under `TargetPlatformVariant.desktop()` the viewport takes focus and shows the ring; arrows, Page Down, Home, and End scroll; End reaches the true end of a lazy list; mobile platforms are not focusable by default; a focused item is not hidden under a pinned sliver header (WCAG 2.4.11) |
| 4 | `a11y_guidelines_test.dart` | `meetsGuideline(labeledTapTargetGuideline)` and `meetsGuideline(androidTapTargetGuideline)` on a tappable row; a row with fixed `minHeight` reflows without overflow at `TextScaler.linear(2)` |

Run with `flutter test --no-pub test/src/components/common/`.

## 9. Benchmark

Phase 2 builds the harness that the container-layout spec (2026-09-30, section 10) describes and that does not exist yet: `example/integration_test/layout_perf_test.dart` runs each scene inside `binding.traceAction` and reports a `TimelineSummary` through `example/test_driver/perf_driver.dart`, run with `flutter drive --profile`.

| Scene | Content | Decides |
|---|---|---|
| S1 | List of 1000 rows: a row of two columns with text, no style, flung for five seconds | Bare-tier gain for column and row |
| S2 | S1 with a static style (fill and radius) on each row | The 10% lazy-controller threshold, compared with S1 |
| S3 | S2 with an interaction (`onTap`) and a 100 ms animated style | Cost of the tap surface |
| S4 | 50 boxes animating their style in a loop | Animation (from the container-layout spec) |
| S5 | 20 glass cards in one `BackdropGroup` scrolling over an image | Blur (from the container-layout spec) |

- Each scene has one builder function, so moving from the old API (`GestureRowLayout`) to the new one (`RowLayout(interaction:)`) changes only that function.
- Device: macOS desktop in profile mode; a physical iOS or Android device when the owner runs it. Profile mode does not run on simulators or emulators.
- Each scene runs three times; the median counts. Measured numbers go to the project memory entry, not into this spec.
- Pass after phases 3 and 4: p99 frame build time and p99 raster time below 8.3 ms in every scene, and average build time no more than 5% above the baseline in every scene.

## 10. Phases

| Phase | Work | Done when |
|---|---|---|
| 1. Scroll views | Section 4 scroll views and theme items, section 6 scrolling for scroll views without K4 | `flutter analyze lib` reports 0 errors and the phase 1 tests pass |
| 2. Benchmark baseline | Section 9 harness and five scenes on the current layouts | Baseline medians recorded in the project memory entry |
| 3. Layout family | `BoxLayout`, the five layouts, `StratumInteraction` without phase 4 fields, `scrollBuilder` and `ScrollFrame` without keys, gesture twins deleted, reduced motion, the 10% decision | Phase 3 tests pass and the benchmark passes |
| 4. Keyboard and accessibility | K1 to K4, shortcut-only focus, focus keep-alive, guideline tests | Phase 4 tests pass and the benchmark still passes |

Each phase gets its own implementation plan. Phase 1 meets the done-when of the roadmap phase `stratum-green-build`. Phase 2 absorbs the benchmark part of `stratum-style-benchmark`, whose gesture-layout tests become phase 3's ported tests; that phase's deferred `WidgetStyle` minors stay separate work.

## 11. Out of scope

- Renaming the `App*` theme-token classes in `lib/src/themes/styles/`.
- Two-dimensional grid navigation and roving focus inside lazy lists.
- App-wide shortcuts such as Cmd+K; they belong at the app root.
- Intent and action based shortcuts on primitives.
- A `toolbar` semantics role, which the SDK does not offer.
- A custom `RenderObject` for the box.
- `StratumThemeApplication.updateShouldNotify`, which compares only `lightTheme`.
- Space and Shift+Space paging in scroll views.

## 12. Evidence

Checked in the local Flutter SDK 3.47.3 and the repository on 2026-10-01:

- `flutter analyze --no-pub lib`: 8 errors, all in `custom_scroll_view.dart`, `grid_view.dart`, and `list_view.dart` (`super_formal_parameter_without_associated_named`, `undefined_identifier`), plus two `deprecated_member_use` infos for `cacheExtent`.
- `widgets/scroll_configuration.dart` declares `buildScrollbar` and `buildOverscrollIndicator` and no `buildViewportChrome`.
- `widgets/app.dart` `WidgetsApp.defaultShortcuts`: Enter, Space, and Numpad Enter map to `ActivateIntent`; arrows to `DirectionalFocusIntent`; Control+arrows (Meta+arrows on Apple platforms) and Page Up and Page Down to `ScrollIntent`; no Home, End, or context-menu key outside text editing.
- `widgets/scrollable_helpers.dart` `ScrollAction.isEnabled` requires a `Scrollable` above the focused context or a `PrimaryScrollController` with clients; `widgets/primary_scroll_controller.dart` inherits automatically only on Android, iOS, and Fuchsia.
- `widgets/gesture_detector.dart:1715-1716`: the default semantics delegate exposes only tap and long press.
- `material/ink_well.dart:1333-1336`: focus requires `enabled && canRequestFocus` in traditional navigation; `ink_well.dart:993`: `wantKeepAlive` depends on highlights and splashes only.
- `widgets/editable_text.dart:2638`: `wantKeepAlive => widget.focusNode.hasFocus`.
- `animation/animation_controller.dart:651`: durations scale to 5% when `disableAnimations` is set; `dart:ui` `AccessibilityFeatures.reduceMotion` is "Only supported on iOS".
- `dart:ui` `SemanticsRole` has no `toolbar` value; `semantics/semantics.dart:2621`: `SemanticsProperties.role` exists.
- `material/material_localizations.dart:93`: `showMenuTooltip`.
- `flutter_test`: `labeledTapTargetGuideline`, `androidTapTargetGuideline`, `iOSTapTargetGuideline`, `FakeAccessibilityFeatures(reduceMotion:)`, and `TargetPlatformVariant.desktop()` exist.
- `ListView.builder` takes `physics` and `scrollCacheExtent` but no `scrollBehavior`, so scroll views apply the resolved behavior through a `ScrollConfiguration`.
- No file in `lib/` or `example/lib/` outside `layout/` constructs a layout, so the API changes have no callers to migrate.

## 13. Decisions log

- 2026-10-01: rename scope covers the layout family only; theme-token `App*` classes stay.
- 2026-10-01: benchmark baseline before the refactor.
- 2026-10-01: `scrollable` scrolls inside the box.
- 2026-10-01: option A, one base class and one interaction object; gesture twins removed.
- 2026-10-01: desktop keyboard K1 to K4 in scope.
- 2026-10-01: one spec with four phases.
- 2026-10-01: bundle named `interaction: StratumInteraction`.
- 2026-10-01: primitives use the Flutter name plus `Layout` without prefix; scroll views become `*ViewLayout`. This replaced the earlier ruling that renamed the family to `Stratum*`.
- 2026-10-01: design sections 1 to 5 approved in brainstorming.
