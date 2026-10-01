# Layout primitives design

- **Date:** 2026-10-01
- **Status:** Approved by the owner on 2026-10-01; revised the same day after the quality review (section 13); phase 3 done; section 9 amended to in-process ABBA comparison on 2026-10-01; phase 4 next.
- **Location:** `lib/src/components/common/layout/` (all files), new `lib/src/components/common/model/interaction.dart`, and changes in `lib/src/components/common/ink_well.dart`, `lib/src/components/common/style/animated_styled_box.dart`, `lib/src/themes/behavior/`, and `lib/src/themes/theme_application.dart`.

## 1. Goal

Turn the layout folder into a small family of primitives that share one build pipeline, hold 60 fps on 120 Hz displays (an 8.3 ms frame budget), and work by keyboard and screen reader on desktop and web as well as mobile. Today the folder holds 14 files: five box layouts, five gesture twins that forward about 19 interaction parameters each by hand, three scroll views that do not compile, and a barrel. The parameters have already drifted between twins, two scroll behaviors do nothing on the current Flutter SDK, and no layout offers a keyboard path beyond Enter and Space.

After this work the folder holds five box layouts on one base class, three scroll views on one shared scroll behavior resolver, and one interaction value object. Interaction, scrolling, semantics, and reduced motion each have one implementation.

Success criteria:

- Every test in section 8 for new or changed behavior is written before its implementation, fails first, and then passes. Cases marked "(pin)" guard behavior that exists today and pass from the start.
- `flutter test --no-pub test/src/components/common/ test/src/themes/` passes after each phase.
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
| Lazy animation controller | Decided by measurement in phase 3: if scene S2 has an average frame build time more than 10% above scene S2-plain (section 9), the `AnimatedStyledBox` rewrite in phase 3 also creates its controller only on the first animated change | S2-plain draws the same decoration without `AnimatedStyledBox`, so the gap measures the widget's own overhead. The threshold is fixed before measuring. |
| Scrolling | `scrollable: true` scrolls inside the box, as Figma overflow scrolling does: fill, border, radius, and shadow stay fixed; padding and children scroll | Owner ruling 2026-10-01. The current wrapper sits outside the box, so the background scrolls away with the content. |
| Scroll physics and behavior | One resolver: the widget's `physics` parameter applies on top of the theme's `physics` and `scrollBehavior`, read through a new `StratumThemeApplication.maybeOf`; without a theme, the inherited `ScrollConfiguration` | `StratumThemeApplication` is an `InheritedWidget`, so it cannot insert a `ScrollConfiguration` above its child. Without a theme the primitives fall back to Flutter defaults instead of throwing. |
| Semantics placement | Inside the margin for every layout, through `AnimatedStyledBox.boxBuilder` | The semantic rect then equals the visible box, which focus highlights and target-size checks measure. |
| Reduced motion | `AnimatedStyledBox` sets `AnimationBehavior.preserve` and applies one rule whenever `disableAnimations` or `reduceMotion` is set: geometry fields jump to their target and paint fields fade over the normal duration | Owner default accepted 2026-10-01. Without `preserve`, `AnimationController` cuts every fade to 5% of its duration on Android, web, and Linux, so the platforms would disagree. Outcome per platform in section 6. |
| Desktop keyboard | K1 context-menu key and Shift+F10; K2 focus-scoped `shortcuts`; K3 roving focus group; K4 focusable scroll views with Home and End | Owner chose all four on 2026-10-01; the owner targets desktop as well as mobile. |
| Text-entry guard | K3 and K4 keys, and K2 bindings without a control, meta, or alt modifier, are skipped while primary focus is inside an `EditableText` | Text-editing shortcuts sit at the app root (`WidgetsApp` wraps `DefaultTextEditingShortcuts`), so any binding between a text field and the root would take Home, End, arrows, and letters from it. |
| Shortcut shape | `Map<ShortcutActivator, VoidCallback>`, focus-scoped only | Owner chose the callback map. Components that need menu labels can wrap Flutter's `Shortcuts` and `Actions` themselves. |
| Scroll focus default | `focusable: null` resolves to `kIsWeb \|\| {macOS, windows, linux}.contains(defaultTargetPlatform)` | Firefox model: every scroller is a Tab stop. The Chrome model (focusable only when no child is) needs a descendant scan on every list change. |
| Spec shape | One spec with four phases, one plan per phase | Owner ruling 2026-10-01; the phases share every decision above. |
| Performance proof | Benchmark baseline on the current layouts before the refactor, judged on macOS in profile mode by in-process ABBA pairs against frozen copies of the baseline classes (section 9) | Owner rulings 2026-10-01. Separate `flutter drive` runs per side could not resolve a 5% change on the shared machine. |

## 3. Current defects

| ID | Defect | Where |
|---|---|---|
| D1 | `WrapLayout` with `scrollable` scrolls along `direction`, so a horizontal wrap gets unbounded width and never wraps. `GestureWrapLayout` scrolls along the cross axis. | `wrap_layout.dart:116`, `gesture_wrap_layout.dart:158` |
| D2 | `NoGlowScrollBehavior` and `StratumScrollBehavior` declare `buildViewportChrome`, which Flutter 3.47.3 no longer has. Without `@override` the method compiles and never runs. | `themes/behavior/` |
| D3 | Each scroll view adds `NotificationListener<OverscrollIndicatorNotification>` that returns true, so no ancestor receives that notification. | `list_view.dart:50`, `grid_view.dart:48`, `custom_scroll_view.dart:54` |
| D4 | The scroll views declare `super.padding` and `super.border` on `StatelessWidget`; these are all 8 errors that `flutter analyze lib` reports. | `custom_scroll_view.dart`, `grid_view.dart`, `list_view.dart` |
| D5 | `cacheExtent` is deprecated after v3.41.0-0.0.pre in favor of `scrollCacheExtent`. | `list_view.dart:68`, `grid_view.dart:65` |
| D6 | The scroll views hard-code their physics and behavior, so the theme's `scrollBehavior` and `physics` are never read. | `list_view.dart:57`, `grid_view.dart:56`, `custom_scroll_view.dart:13-14` |
| D7 | `ColumnLayout` and `RowLayout` always build `AnimatedStyledBox` (a controller, a ticker, and two `GlobalKey`s) even with no style. | `column_layout.dart:81`, `row_layout.dart:82` |
| D8 | The gesture column and row insert `Gap` widgets by hand: two list allocations per build and n−1 extra render objects. The plain twins use `Column.spacing`. | `gesture_column_layout.dart:175`, `gesture_row_layout.dart:181` |
| D9 | Scrollable column and row use `Clip.none`, so content paints outside the viewport. | `column_layout.dart:121` |
| D10 | `ContainerLayout` wraps `Semantics` outermost, so the semantic rect includes the margin and ignores the rotation; `GestureContainerLayout` places it inside the margin. | `container_layout.dart:86` |
| D11 | The scroll wrapper sits outside the box, so fill, border, and padding scroll with the content. | all `scrollable` layouts |
| D12 | Parameter drift: the four non-container gesture layouts lack `debug`; only the two container layouts have `transformAlignment`; `StackLayout` clips with `Clip.hardEdge` while `GestureStackLayout` uses `Clip.none`; only `ColumnLayout` stretches short content to the viewport; `GestureRowLayout.disableFocused` is never read. | gesture twins |
| D13 | `layout.dart` exports neither the four non-container gesture layouts nor the scroll views. | `layout.dart` |
| D14 | Reduced motion differs by platform: `AnimationController` cuts fades to 5% where the engine sets `disableAnimations` (Android, web, Linux), iOS `reduceMotion` is ignored, and macOS and Windows send no flag. | `animated_styled_box.dart` |
| D15 | Keyboard and assistive gaps: no key reaches `onSecondaryTap`; screen readers reach only tap and long press among the activation actions; no focus-scoped shortcut API; no roving group; a desktop list with no focusable item cannot scroll by keyboard; Home and End do nothing. | section 12 |
| D16 | A focused item in a lazy list can be disposed when it scrolls past the cache extent in two cases: in touch highlight mode, where `InkWell` builds no focus highlight, and on the K2 shortcut-only node, which is not an `InkWell`. In traditional highlight mode the focus highlight already keeps an `InkWell` alive. | `material/ink_well.dart:993`, `1142-1152` (SDK) |
| D17 | `ColumnLayout` with `scrollable` stretches short content through a `LayoutBuilder` minimum taken from `constraints.maxHeight`, which is infinite in an unbounded parent and fails the constraint assertions. | `column_layout.dart:127-137` |

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

  /// Whether `scrollable` stretches short content to fill the viewport.
  @protected
  bool get stretchesToViewport => true;
}
```

`build` runs the pipeline in section 5 and is the only implementation of it. Subclasses declare their own parameters plus `super.` parameters and override `buildContent`; `RowLayout` overrides `scrollDirection` to horizontal, and `WrapLayout` returns the axis that crosses `direction`.

### Box layouts

| Class | Own parameters |
|---|---|
| `ContainerLayout` | `child` |
| `ColumnLayout` | `mainAxisAlignment` (`start`), `mainAxisSize` (`max`), `crossAxisAlignment` (`center`), `textDirection`, `verticalDirection` (`down`), `textBaseline`, `crossAxisIntrinsic` (`false`), `gap`, `children`; phase 4: `focusGroup` |
| `RowLayout` | the same as `ColumnLayout` |
| `StackLayout` | `alignment` (`AlignmentDirectional.topStart`), `fit` (`StackFit.loose`), `textDirection`, `clipBehavior` (`Clip.hardEdge`), `children` |
| `WrapLayout` | `direction` (`horizontal`), `alignment` (`start`), `gap`, `runGap`, `runAlignment` (`start`), `crossAxisAlignment` (`start`), `textDirection`, `verticalDirection` (`down`), `clipBehavior` (`Clip.none`), `children`; phase 4: `focusGroup` |

Defaults follow Flutter's own widgets. `gap` and `runGap` follow Figma auto layout names; `WrapLayout` drops `spacing` and `runSpacing`, and a null `runGap` falls back to `gap`, as a null `runSpacing` does today. Column and row keep the current rule that a set `height` or `maxHeight` (width for row) forces `MainAxisSize.max`. `ContainerLayout` drops its public `boxBuilder`, which only `GestureContainerLayout` used.

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

`model/model.dart` exports `interaction.dart`. The fields map one to one onto `StratumInkWell`. `semantics` stays on `BoxLayout`, because non-interactive layouts use it too, and `BoxLayout` hands it to `StratumInkWell` when a tap surface is built. The class does not override `==`: callbacks compare by identity, and a `StatelessWidget` parent rebuilds its subtree either way. Phase 4 adds `shortcuts` and `secondaryTapSemanticsLabel`; both have defaults, so the change does not break callers.

A layout builds `StratumInkWell` when `interaction` is non-null and has at least one of: an activation callback (`onTap`, `onDoubleTap`, `onLongPress`, `onSecondaryTap`), `onHover`, `onHighlightChanged`, `onFocusChange`, or a non-empty `shortcuts` map. A non-null `interaction` with none of them keeps the box tier and adds no tap surface.

### `StratumFocusGroup` (phase 4)

```dart
@immutable
class StratumFocusGroup {
  const new({this.role, this.loop = false});

  final SemanticsRole? role;
  final bool loop;
}
```

`ColumnLayout`, `RowLayout`, and `WrapLayout` take `focusGroup:` from phase 4. Null builds nothing. Behavior is in section 6.

### Scroll views

| Class | Replaces | Parameters |
|---|---|---|
| `ListViewLayout.builder` | `AppListView.builder` | `style`, `gap`, `scrollDirection`, `reverse`, `controller`, `primary`, `physics`, `showScrollbar`, `shrinkWrap`, `itemExtent`, `prototypeItem`, `itemCount`, `itemBuilder`, `findChildIndexCallback`, `addAutomaticKeepAlives`, `addRepaintBoundaries`, `addSemanticIndexes`, `scrollCacheExtent`, `semanticChildCount`, `dragStartBehavior`, `keyboardDismissBehavior`, `restorationId`, `clipBehavior`; phase 4: `focusable`, `semanticsLabel` |
| `GridViewLayout.builder` | `AppGridView.builder` | `gridDelegate`, then the list parameters without `gap`, `itemExtent`, and `prototypeItem` |
| `CustomScrollViewLayout` | `AppCustomScrollView` | `style`, `slivers` or `children` (exactly one), `controller`, `scrollDirection`, `reverse`, `shrinkWrap`, `physics`, `showScrollbar`; phase 4: `focusable`, `semanticsLabel` |

- `physics: null` resolves as in section 2. `showScrollbar: null` uses the resolved behavior's default, which shows a scrollbar on desktop for vertical scroll views.
- `gap` builds `ListView.separated`. The constructor asserts that `itemCount` is non-null and that `itemExtent`, `prototypeItem`, and `semanticChildCount` are null when `gap` is set, because `separated` requires a count, supports no fixed extent, and derives the semantic count itself. `findChildIndexCallback` is then forwarded as `findItemIndexCallback`, which counts items without separators, as the caller's callback does.
- `AppCustomScrollView.width` and `border` move into `style`; its `scrollBehavior` parameter is removed in favor of the resolver.

### Theme and behavior

- `StratumThemeApplication.maybeOf(BuildContext context, {ThemeMode? themeMode})` returns `StratumThemeData?` and never throws: it reads the system brightness through `MediaQuery.maybePlatformBrightnessOf`, treating a missing `MediaQuery` as light. `of` calls `maybeOf` and throws the current `FlutterError` on null.
- `StratumScrollBehavior` overrides `buildOverscrollIndicator` to return `child`, with `@override` on every member, and stays `const`.
- `NoGlowScrollBehavior` and its export are deleted.

### Files

| File | Change |
|---|---|
| `layout/box_layout.dart` | new: `BoxLayout` (phase 3) |
| `layout/container_layout.dart`, `column_layout.dart`, `row_layout.dart`, `stack_layout.dart`, `wrap_layout.dart` | rewritten on `BoxLayout` (phase 3) |
| `layout/list_view_layout.dart`, `grid_view_layout.dart`, `custom_scroll_view_layout.dart` | renamed from `list_view.dart`, `grid_view.dart`, `custom_scroll_view.dart` and rewritten (phase 1) |
| `layout/scroll_frame.dart` | new, not exported: `resolveScrollBehavior` and `ScrollFrame` (phase 1); `ScrollFocus` (phase 4) |
| `layout/focus_group.dart` | new: `StratumFocusGroup` and its traversal policy (phase 4) |
| `layout/gesture_*_layout.dart` (5 files) | deleted (phase 3) |
| `layout/layout.dart` | exports every public layout class above |
| `common/model/interaction.dart`, `common/model/model.dart` | new `StratumInteraction` and its export (phase 3) |
| `common/ink_well.dart` | phase 4: K1, K2, shortcut-only focus, focus keep-alive |
| `style/animated_styled_box.dart` | phase 3: `scrollBuilder` hook, `AnimationBehavior.preserve`, reduced motion, and the lazy controller if section 9 calls for it |
| `themes/behavior/scroll_behavior.dart`, `behavior.dart`, `no_glow_scroll_behavior.dart` | fix, update export, delete (phase 1) |
| `themes/theme_application.dart` | `maybeOf` (phase 1) |

## 5. Widget tree and data flow

### Bare tier

```
_KeepAlive               keepAlive
WidgetPerformanceMonitor debug
RepaintBoundary          repaintBoundary
Semantics.fromProperties semantics
buildContent()
```

No `AnimatedStyledBox`, animation controller, or `GlobalKey` exists in this tier. A `State` exists only for `keepAlive` and `debug`, whose wrappers are stateful.

### Box tier (outer to inner)

```
_KeepAlive               keepAlive
WidgetPerformanceMonitor debug
RepaintBoundary          repaintBoundary
Transform.rotate         rotate
AnimatedStyledBox
  Opacity, Transform, Padding(margin)
  boxBuilder:  ScrollFocus                   phase 4, when scrollable and focusable
               StratumInkWell(semantics)     when the interaction needs a tap surface
               Semantics.fromProperties      otherwise, when semantics is set
  ConstrainedBox(size)
  DecoratedBox(foreground: border)           fixed
  DecoratedBox(background) / BackdropFilter  fixed
  clip                                       one clip, see section 6
  ImageFiltered(foregroundBlur)              blurs the viewport, not the whole content
  scrollBuilder: ScrollFrame(SingleChildScrollView)   new hook, when scrollable
  Padding(padding)                           scrolls with the content
  Align, AspectRatio
  buildContent()
```

`boxBuilder` keeps its `GlobalKey`, and the child keeps its own through `_childKey`. Adding the first callback to a non-null `interaction` or removing the last one changes the `boxBuilder` wrapper type, so the wrappers between the box key and the child (constraints and decorations) rebuild, while the child keeps its `State`. That is the guarantee of commit 7e86baf. The scroll subtree keeps its own `GlobalKey` the same way, so a `scrollable` layout's `ScrollableState` and its position survive a style, interaction, or semantics change; only a tier change resets it.

When `interaction` is non-null and the style has no `animationStyle`, the style animates over 100 ms with `easeInOutSine`, keeping the default that `GestureContainerLayout` has today.

### Scroll views after each phase

| After | `ListViewLayout`, `GridViewLayout`, `CustomScrollViewLayout` build |
|---|---|
| Phase 1 | `ContainerLayout(style: ScrollFrame.boxStyle(style))` when `style` is set, then `ScrollFrame`, then the Flutter scroll view with `style.padding` as its padding |
| Phase 3 | unchanged; `ContainerLayout` is now a `BoxLayout` in the box tier |
| Phase 4 | `ScrollFocus` around the box (or around `ScrollFrame` when `style` is null), then the phase 1 tree |

`ScrollFrame` is a `StatelessWidget` that wraps any scroll view, Flutter's or `SingleChildScrollView`, in a `ScrollConfiguration` carrying `resolveScrollBehavior(context, scrollbars: showScrollbar)`. `ScrollFrame.boxStyle` removes `padding` from the style and sets `clipBehavior: Clip.antiAlias` when the style has a `borderRadius` and no `clipBehavior` of its own.

## 6. Behavior

### Scrolling inside the box

- Scrollable box layouts pass `scrollBuilder: (content) => ScrollFrame(child: SingleChildScrollView(...))` along `scrollDirection`, with physics and behavior from the resolver.
- Content shorter than the viewport stretches to the viewport size minus the padding through `LayoutBuilder` and a minimum constraint, so `spaceBetween` and `end` alignments still work. `ColumnLayout` and `RowLayout` stretch only when their effective `mainAxisSize` is `MainAxisSize.max`; `StackLayout` and `WrapLayout` always stretch (owner ruling 2026-10-01). A layout whose `stretchesToViewport` is false skips the `LayoutBuilder` entirely, so it works under `IntrinsicWidth`, `IntrinsicHeight`, or a parent's `crossAxisIntrinsic`, where a stretching layout's `LayoutBuilder` is not supported. The stretch applies only when the viewport extent is finite. In a parent that is unbounded along the scroll axis, the layout sizes to its content, as `SingleChildScrollView` does, and never sets an infinite minimum (fixes D17).
- **One clip.** `AnimatedStyledBox._clip` owns the clip. It clips when a blur is set, when `style.clipBehavior` is set, or when a `scrollBuilder` is present and the style has a `borderRadius`; the last case uses `Clip.antiAlias`, which adds no save layer. Scroll views reach the same clip through `ScrollFrame.boxStyle`. No viewport is clipped twice: `SingleChildScrollView` and the Flutter scroll views keep their own `Clip.hardEdge` rectangle inside the rounded clip.
- `ImageFiltered` for `foregroundBlur` sits outside `scrollBuilder`, so it filters the viewport rather than the full scroll content.
- Scroll views apply the same model: `style.padding` becomes the list's sliver padding, which scrolls and builds lazily. `CustomScrollViewLayout` in children mode uses a `SliverPadding`; in slivers mode it asserts in `build` that `style.padding` is null, because wrapping several slivers in one group changes how pinned headers behave.
- `ScrollFrame`'s `ScrollConfiguration` also reaches Flutter scroll views inside the items, because `ListView.builder` and `GridView.builder` take no `scrollBehavior`. Layout scroll views inside resolve their own behavior, from the theme or, without a theme, from the configuration above the outermost `ScrollFrame` (carried down by a private inherited scope), so an outer `showScrollbar: false` does not remove an inner layout's scrollbar.

### Reduced motion

`AnimatedStyledBox` replaces its `ImplicitlyAnimatedWidget` base with its own `State`, so its controller can use `AnimationBehavior.preserve`. On every style change it reads `View.of(context).platformDispatcher.accessibilityFeatures` (`MediaQueryData` has no `reduceMotion` field). When `disableAnimations` or `reduceMotion` is set, the begin style takes the target's geometry fields (`width`, `height`, minimum and maximum sizes, `padding`, `margin`, `alignment`) before the tween starts, so geometry jumps while colors, gradients, images, borders, radius, shadows, blur, and opacity fade over the normal duration.

| Platform | Flag the engine sets | Result |
|---|---|---|
| Android | `disableAnimations` from "Remove animations" | geometry jumps, paint fades |
| iOS | `reduceMotion` from "Reduce Motion" | geometry jumps, paint fades |
| Web | both, from `prefers-reduced-motion` | geometry jumps, paint fades |
| Linux | `disableAnimations` from GNOME `enable-animations` | geometry jumps, paint fades |
| macOS, Windows | none | full animation; no platform signal reaches Flutter |

### Text-entry guard

A key binding from K3 or K4, and a K2 binding whose activator has no control, meta, or alt modifier, is skipped while primary focus is inside an `EditableText`. The key then reaches the text field's own shortcuts at the app root.

### K1: context-menu key

- When `onSecondaryTap` is set and the interaction is not disabled, `StratumInkWell` binds `LogicalKeyboardKey.contextMenu` and Shift+F10 to it while its node has focus, on every platform.
- It also adds a `CustomSemanticsAction` for the secondary tap, labeled `secondaryTapSemanticsLabel`, else `MaterialLocalizations.showMenuTooltip` when material localizations are present, else `'Show menu'`.
- `onDoubleTap` has no keyboard or screen-reader path. Dartdoc states that no function may be reachable only by double tap (WCAG 2.1.1); `shortcuts` provides the alternative.

### K2: shortcuts

- `shortcuts` builds a `CallbackShortcuts` above the tap surface's focus node, so a binding fires while that node or a descendant has focus. An empty map builds nothing.
- Bindings never fire while the interaction is disabled.
- With focus scoping and the text-entry guard, single-key bindings satisfy WCAG 2.1.4.
- **Shortcut-only focus.** An interaction with shortcuts but no activation callback still needs focus, but `InkWell` grants focus only when `enabled && canRequestFocus` and forces `canRequestFocus` to false on the node it receives otherwise. In that case `StratumInkWell` moves its focus node (the caller's `focusNode`, else its internal node) to an outer `Focus(canRequestFocus: interaction.canRequestFocus)` and gives `InkWell` no node. The focus ring and the keep-alive track that node. The node reports `focusable` and no button role, because no activation callback exists; any interaction with an activation callback keeps the button role.

### K3: roving focus group (phase 4)

- Tab enters the group once and lands on the item that last held focus, or on the first item.
- Arrows along the layout axis move to the next item **on screen** in the pressed direction: Left and Right in a row, Up and Down in a column. This one rule covers `TextDirection.rtl` and `VerticalDirection.up`. In a wrap, Left and Right move in reading order (reversed under RTL), and Up and Down move to the nearest item in the adjacent run by screen position.
- Arrows across the layout axis (Up and Down in a row, Left and Right in a column) are not handled by the group and keep Flutter's default.
- The group binds its own arrows, so the behavior is the same on web, where Flutter maps arrows to scrolling by default.
- Home and End move to the first and last item on screen. With `loop: true`, moving past either end wraps around.
- Tab and Shift+Tab always leave the group (WCAG 2.1.2).
- `role` sets `SemanticsRole` on the group node. Flutter's debug checks constrain the children: `tabBar` requires at least one child and every child with role `tab`; `menu` and `menuBar` require at least one child, and `menuItem` must sit under one of them; `radioGroup` allows at most one checked child; `list` has no check. Items take their role through their own `semantics:` (`SemanticsProperties(role: ...)`), which `StratumInkWell` honors in place of the button role. Flutter 3.47.3 has no `toolbar` role.
- The group covers built children only; lazy lists use Tab and K4.

### K4: keyboard scrolling (phase 4)

- **Where the node sits.** `ScrollFocus` owns the focus node, the keys, and the ring, and sits outside the clip so the 4 px `FocusSpread` ring, which paints outside the box, stays visible: around the box for scroll views, and through `boxBuilder` for scrollable box layouts. When the layout also has an interaction with a tap surface, `ScrollFocus` wraps `StratumInkWell` and creates no node of its own; its keys then act on events that bubble up from the tap surface's node.
- **Default.** `focusable: null` resolves through a function `defaultScrollFocusable({required bool isWeb, required TargetPlatform platform})`, which returns `isWeb || {macOS, windows, linux}.contains(platform)`; mobile web is therefore focusable. Scrollable box layouts use the default and take no `focusable` parameter.
- **Name.** A focusable scroll view takes `semanticsLabel`, which names the node a screen reader announces on focus.
- **Ring.** The ring shows while the node holds primary focus in traditional highlight mode (WCAG 2.4.7).
- **Keys while the viewport node itself holds focus.** Up and Down (Left and Right when horizontal) scroll 50 px, Page Up and Page Down scroll 0.8 of the viewport (the values of Flutter's `ScrollAction`), and Home and End jump to the first and last item; with `reverse: true`, Home still goes to the first item.
- **Keys while an item inside holds focus.** Arrows keep Flutter's default (directional focus; scrolling on web), and Page Up, Page Down, Home, and End still scroll the viewport, subject to the text-entry guard.
- **Jumps.** Home and End use `jumpTo`, so no motion plays. A lazy list only estimates `maxScrollExtent`, so End jumps again after each frame until the extent stops changing, at most three times.
- **Controller.** The node sits above the `Scrollable`, where `ScrollAction` cannot find it through `Scrollable.maybeOf`, so `ScrollFocus` scrolls through a controller. It uses the caller's `controller` when set. Otherwise, when the scroll view would attach to the `PrimaryScrollController` (`primary: true`, or `primary: null` on a platform and axis that inherits it), it uses `PrimaryScrollController.of` and passes no controller down. Otherwise, and only when `focusable` resolves to true, it creates an internal controller and passes it to the scroll view. A list on iOS or Android therefore keeps its automatic primary controller and status-bar tap to top.

### Focus keep-alive (phase 4)

`StratumInkWell` mixes in `AutomaticKeepAliveClientMixin` with `wantKeepAlive => focusNode.hasFocus` on the node it focuses (section 6, K2) and calls `updateKeepAlive` on focus changes, as `EditableText` does. This closes D16 in touch highlight mode and for shortcut-only nodes.

## 7. Edge cases

- Content remounts when the tier changes (toggling `scrollable` on an otherwise bare layout counts), when `rotate` switches between null and a value, when `repaintBoundary`, `debug`, or `keepAlive` changes, or, on a bare layout, when `semantics` switches between null and a value. Callers that toggle style or interaction pass a constant empty value instead of null.
- A `focusGroup` whose children contain no focusable node builds the group and does nothing on Tab. Under `role: SemanticsRole.menu`, `menuBar`, or `tabBar`, an empty group fails Flutter's debug role check, so a caller sets those roles only when items exist.
- `ListViewLayout.builder` with `gap` and a null `itemCount`, an `itemExtent`, a `prototypeItem`, or a `semanticChildCount` fails its assertion in debug mode.
- `CustomScrollViewLayout` with both or neither of `slivers` and `children` fails its constructor assertion; slivers mode with `style.padding` fails its build assertion.
- A scrollable layout in a parent that is unbounded along its scroll axis sizes to its content and does not stretch (section 6).
- A scrollable `ColumnLayout` or `RowLayout` with an effective `mainAxisSize` of `MainAxisSize.min` has `stretchesToViewport` false, so it builds with no `LayoutBuilder` and lays out under `IntrinsicWidth`, `IntrinsicHeight`, or a parent's `crossAxisIntrinsic`; the same layout at `MainAxisSize.max`, or a scrollable `StackLayout` or `WrapLayout`, still fails to build in that position.
- Without `StratumThemeApplication` above it, a scroll view uses `ScrollConfiguration` and Flutter defaults; `StratumInkWell` still requires the theme, as it does today.

## 8. Testing

Widget tests with `flutter_test`; no golden images. "(pin)" marks a case that guards existing behavior.

| Phase | File | Cases |
|---|---|---|
| 1 | `test/src/themes/behavior/scroll_behavior_test.dart` | No `StretchingOverscrollIndicator` or `GlowingOverscrollIndicator` under `StratumScrollBehavior`; a control case under `MaterialScrollBehavior` builds one |
| 1 | `test/src/themes/theme_application_test.dart` | `maybeOf` returns null without a theme; it picks the dark theme in dark mode, in system mode under a dark platform, and for an explicit `themeMode`; `of` still throws without a theme (pin). The missing-`MediaQuery` path is not testable, because every `View` provides a `MediaQuery`. |
| 1 | `layout/scroll_frame_test.dart` | Theme physics win over an outer `ScrollConfiguration`; without a theme the outer configuration applies; `showScrollbar: false` removes the macOS scrollbar and null keeps it; `boxStyle` moves padding out, adds `Clip.antiAlias` for a radius, and keeps an explicit `clipBehavior` |
| 1 | `layout/list_view_layout_test.dart` | Items build; no box without `style`; `style.padding` scrolls with the items while the box stays in place; a radius clips with `Clip.antiAlias`; the `physics` parameter applies on top of the theme; no overscroll indicator under the theme; without a theme an ancestor `NotificationListener<OverscrollIndicatorNotification>` receives the default indicator's notification (D3); `gap` in both axes; each `gap` assertion; `findChildIndexCallback` reaches `separated` as `findItemIndexCallback`; `scrollCacheExtent` forwarded; a nested list keeps its own scrollbar when the outer one hides its scrollbar |
| 1 | `layout/grid_view_layout_test.dart` | Items build; `style.padding` scrolls; `physics` parameter; no overscroll indicator under the theme |
| 1 | `layout/custom_scroll_view_layout_test.dart` | Children mode builds a `SliverList` and sets `semanticChildCount`; children-mode padding becomes a `SliverPadding`; slivers-mode padding fails the build assertion; both or neither of `slivers` and `children` fails; no box without `style`; `showScrollbar` |
| 3 | `layout/box_layout_test.dart` | With `keepAlive` and `debug` false, the bare tier builds no `AnimatedStyledBox` and no `StatefulElement`; each tier rule; the semantic rect equals the box and excludes the margin |
| 3 | `column_layout_test.dart`, `row_layout_test.dart`, `stack_layout_test.dart`, `wrap_layout_test.dart`, `container_layout_test.dart` | Existing cases ported, except `container_layout_test.dart` "hands boxBuilder to AnimatedStyledBox", which is dropped with the public `boxBuilder` (`animated_styled_box_test.dart` still covers the hook); Wrap scrolls along the cross axis; a null `runGap` falls back to `gap`; short content fills a bounded viewport for `spaceBetween`; an unbounded parent sizes to content without an assertion (D17); the decoration stays in place while the scroll offset changes; a rounded scrollable box builds exactly one clip; Column and Row use `spacing` |
| 3 | `interaction_test.dart` | The nine cases of `gesture_layout_test.dart` ported to `interaction:`; a child keeps its `State` when the first callback is added and when the last is removed; the 100 ms default animation |
| 3 | `animated_styled_box_test.dart` | The controller uses `AnimationBehavior.preserve`; with `FakeAccessibilityFeatures(reduceMotion: true)` and again with `disableAnimations: true`, geometry reaches its target in one frame while color is mid-fade |
| 4 | `ink_well_test.dart` | `sendKeyEvent(LogicalKeyboardKey.contextMenu)` and Shift+F10 call `onSecondaryTap`; neither fires while disabled; the custom semantics action uses `secondaryTapSemanticsLabel`, then `showMenuTooltip`, then `'Show menu'`; shortcuts fire only with focus and never while disabled; an empty map builds no `CallbackShortcuts`; an unmodified binding is skipped inside a `TextField`; a shortcut-only interaction takes focus on the caller's `focusNode` and has no button flag; in `FocusHighlightMode.touch`, a programmatically focused item and a shortcut-only item survive scrolling past the cache extent |
| 4 | `focus_group_test.dart` | Tab enters once; Tab returns to the item that last held focus; axis arrows move by screen direction in a row, a row under RTL, and a column under `VerticalDirection.up`; cross-axis arrows are not handled; wrap Up and Down move by screen position; Home and End; `loop`; Tab and Shift+Tab leave the group; group arrows are skipped inside a `TextField`; `role: SemanticsRole.tabBar` over items with role `tab` passes the debug check |
| 4 | `scroll_frame_test.dart` | `defaultScrollFocusable` for web, desktop, and mobile inputs; under `TargetPlatformVariant.desktop()` the viewport takes focus, carries `semanticsLabel`, and shows a ring that a rounded box does not clip; arrows, Page Down, Home, and End scroll; End reaches the true end of a lazy list; with a button item focused, Page Down still scrolls; Home and End inside a `TextField` item leave the list where it is; a list with `primary: null` on iOS uses `PrimaryScrollController` |
| 4 | `a11y_guidelines_test.dart` | `meetsGuideline(labeledTapTargetGuideline)` and `meetsGuideline(androidTapTargetGuideline)` on a tappable row; (pin) a tappable row with `minHeight: 48` and two lines of text grows at `TextScaler.linear(2)` without overflow |

The benchmark tools (section 9) have unit tests in `example/test/tool/`: `perf_freeze_test.dart` (a public name is renamed in every copied file, private names and imports stay, the header names the commit) and `perf_abba_test.dart` (pairing by run, group, scene, and pair; the rank k for 6, 12, 24, and 36 pairs and no interval below 6; each verdict, the budget override, and the overall order INVALID, FAIL, INCONCLUSIVE, PASS; the interval check; the cap). Run them with `flutter test --no-pub test/tool/` from `example/`.

Run with `flutter test --no-pub test/src/components/common/ test/src/themes/`. Layout test paths are under `test/src/components/common/`.

## 9. Benchmark

Phase 2 builds the harness that the container-layout spec (2026-09-30, section 10) describes, renamed from `container_layout_perf_test.dart` to `layout_perf_test.dart` because it covers the whole family. The baseline and the current code run in one profile app and are compared by interleaved pairs (ABBA). The owner measures under normal multitasking, and on the shared machine the S2-plain null control moved by about ±50% per run when each side ran as its own `flutter drive` process, so a 5% rule cannot be judged across processes. In one process, 12 ABBA pairs of the phase 3 S4 box against a verbatim copy of the old box resolved a median of −10.1%. The project memory entry holds both measurements.

### 9.1 Scenes

| Scene | Content | Decides |
|---|---|---|
| S1 | List of 1000 rows: a row of two columns with text, no style, scrolled down and back at a constant 4000 px/s | Bare-tier gain for column and row |
| S1-fast | S1 at 16000 px/s, so more than one row builds per frame at 144 Hz | Bare-tier gain when rows build on every frame |
| S2 | S1 with fill, radius, drop shadow, and inner shadow on each row; replaces the container-layout spec's 500-item scene | Decoration cost in a list |
| S2-box | S2's styled row around plain Flutter `Column`s, so the row's `AnimatedStyledBox` is the only one in each row | Cost of the row box alone |
| S2-plain | S2-box drawn with `Padding`, `ConstrainedBox`, `DecoratedBox(StyleDecoration)`, and `ClipRRect` directly, without `AnimatedStyledBox` and without the kit | Null control: both sides run the same code, so its confidence interval must contain 0. In phase 3 it also decided the lazy controller (section 2). |
| S3 | S2 with an interaction (`onTap`) and a 100 ms animated style | Cost of the tap surface |
| S4 | 50 boxes animating their style in a loop | Animation (from the container-layout spec) |
| S5 | 20 glass cards in one `BackdropGroup` scrolling over an image | Blur (from the container-layout spec) |

### 9.2 Files

| Path under `example/` | Role |
|---|---|
| `integration_test/layout_perf_test.dart` | Entry point: builds the run order for one scene group and traces each step |
| `integration_test/perf/perf_host.dart` | The fake theme and `perfHost` |
| `integration_test/perf/perf_scene.dart` | `PerfScene` (`key`, `build(kit)`, `drive`, optional `check`) and the run-order function |
| `integration_test/perf/perf_scenes.dart` | The scene catalog: one `PerfScene` per row of the 9.1 table; a new scene is one new entry |
| `integration_test/perf/perf_kit.dart` | `PerfKit` with `row`, `column`, and `container`. `CurrentKit` builds the current API; `BaselineKit` builds the frozen baseline classes. |
| `integration_test/widgets/` | Scene widgets: `AnimatingBoxes` (S4), `GlassCards` and its stripe painter (S5) |
| `integration_test/baseline/` | Frozen baseline classes written by `perf_freeze`; committed |
| `test_driver/perf_driver.dart` | Writes one summary and one timeline per report key and runs the coverage guard |
| `tool/perf_freeze.dart` | Freezes the baseline classes (9.3) |
| `tool/perf_abba.dart` | Runs the invocations, then pairs, judges, and reports (9.4, 9.5) |

Scenes reach layouts only through the kit, except S2-plain. Moving to a new API changes the two kits and leaves the scenes as they are.

### 9.3 Baseline freeze

- `dart run tool/perf_freeze.dart <commit> <path>...` reads each path with `git show <commit>:<path>`. It prefixes `Baseline` to every public top-level name that the copied files declare (class, mixin, enum, extension, typedef), applies each rename in all copied files, adds a header that names the commit and the source path, and replaces the content of `integration_test/baseline/`.
- A frozen file is verbatim except for that header and the renames. It keeps importing `package:stratum_ui/src/src.dart`, so types the phase leaves unchanged, such as `WidgetStyle`, `StyleDecoration`, and `StratumInkWell`, are shared by both sides.
- The copy set is every file the phase changes that a scene reaches. `flutter analyze` must report 0 errors in `integration_test/baseline/`. An error there means the copy set misses a file: a baseline class refers to a name that the phase removed.
- Phase 3 freezes six files of fd59ffa under `lib/src/components/common/`: `style/animated_styled_box.dart`, `layout/container_layout.dart`, `layout/column_layout.dart`, `layout/row_layout.dart`, `layout/gesture_row_layout.dart`, and `layout/gesture_container_layout.dart`. The old `GestureRowLayout` builds a `GestureContainerLayout`, which phase 3 removed. Each later phase freezes the commit it starts from and updates `BaselineKit`.

### 9.4 Run protocol

- Device: macOS desktop in profile mode decides the pass. A physical iOS or Android device adds data when the owner runs it. Profile mode is disabled on emulators and simulators.
- Trace: two seconds of constant-speed scrolling (S5 scrolls a fixed 2000 px; S4 animates continuously) with semantics off, recording only the `Dart`, `Embedder`, and `GC` timeline streams, under `--endless-trace-buffer`. The driver fails any trace whose summary covers less than the two-second window minus two frames. Semantics stay off through phase 4, so the metric measures layout work, not accessibility changes.
- Invocation: one `flutter drive --profile --endless-trace-buffer -d macos --driver=test_driver/perf_driver.dart --target=integration_test/layout_perf_test.dart --use-application-binary=build/perf-apps/g<group>.app`, with `PERF_RUN=<run>` and `PERF_GROUP=<group>` in the driver's environment. Before the first run of a call, `perf_abba` builds each group's profile app once (`flutter build macos --profile --dart-define=PERF_GROUP=<group>`), so every invocation of a group runs the same binary and none pays for a build (about 54 s instead of 100 s per invocation on 2026-10-01). One invocation holds at most 16 traces, because the binding sends every trace's timeline to the driver in one message after the last test (section 12).
- Groups: g1 is S2-plain, S1, S1-fast, and S2; g2 is S2-plain, S2-box, and S3; g3 is S2-plain, S4, and S5. Every group carries the null control, so each invocation measures its own noise. A run is one invocation per group.
- Order within an invocation: first a warm-up pass that builds and drives each scene of the group once per side without tracing, then one block per scene in the order baseline, current, current, baseline. Each block yields two pairs, one led by each side, so a linear drift cancels within the block.
- Each step pumps its scene, runs `check`, pumps 250 ms without tracing, and then traces `drive`. The report key is `<scene>.<side>.<pair>`, with side `base` or `cand`; the driver writes to `build/perf/abba/r<run>g<group>/`.
- Lost frames: when an invocation leaves its run invalid (9.5), `perf_abba` skips that run's remaining groups. Keep the test window visible: macOS slows a hidden window's frames.
- Load: `perf_abba` records the `uptime` load averages of each invocation in the report. It never waits for a quiet machine and never discards data for load (owner ruling 2026-10-01).

### 9.5 Analysis and verdict

- Metrics from `TimelineSummary`: `average_frame_build_time_millis`, `99th_percentile_frame_build_time_millis`, and `99th_percentile_frame_rasterizer_time_millis`.
- A pair is the `base` and `cand` traces with the same run, group, scene, and pair number. Its change in average build time is (cand / base − 1) × 100%.
- Interval check: a run (every group of one run number) with any trace whose frame interval differs by more than 10% from the run's median interval, or from the median interval of the whole comparison, is invalid; the report lists it and the analysis leaves it out. The second test catches a run whose windows all opened on another display. No other data is discarded.
- An expected scene with no valid pairs keeps its row, with 0 pairs and INCONCLUSIVE (S2-plain: null INVALID).
- Confidence interval: the distribution-free 95% interval for the median of the paired changes is [x(k), x(n−k+1)] of the sorted changes, where k is the largest rank with P(Bin(n, ½) ≤ k − 1) ≤ 0.025. Fewer than 6 pairs give no interval. 12 pairs give k = 3 (coverage 96.1%), 24 pairs k = 7 (97.7%), and 36 pairs k = 12 (97.1%).
- Null gate: the S2-plain interval must contain 0. Otherwise the comparison is INVALID and is run again. Half the width of the S2-plain interval is reported as the comparison's resolution.
- Average build, per scene except S2-plain, which only the null gate judges: PASS when the interval's upper bound is at most +5%; FAIL when its lower bound is above +5%; INCONCLUSIVE otherwise, including a scene with fewer than 6 pairs.
- Budget, per scene except S2-plain: the current side's median p99 build and median p99 raster stay below 8.3 ms, or, where the baseline median is already 8.3 ms or more, the median paired difference is at most 0. A scene that misses the budget FAILs, whatever its average-build result.
- Overall: INVALID when the null gate fails; otherwise FAIL when any scene fails; otherwise INCONCLUSIVE when any scene is inconclusive; otherwise PASS. `perf_abba` exits with 0 for PASS, 1 for FAIL or INVALID, and 2 for INCONCLUSIVE.
- Escalation: a comparison starts with 6 runs, which give 12 pairs per scene and 36 for S2-plain. On INCONCLUSIVE, add 6 runs once, to a cap of 24 pairs per scene; `perf_abba` refuses runs beyond the cap. A scene still inconclusive at the cap goes to the owner with its median and interval. The milestone or phase closes on the owner's ruling.
- Pass after phases 3 and 4: an overall PASS, or an owner ruling on the inconclusive scenes at the cap.
- Report: `perf_abba` prints one row per scene (pairs, base and current average build, median change, interval, p99 build, p99 raster, verdict) under a header with the run count, load range, frame interval, and resolution, and writes the same table to `build/perf/abba/report.md`. Measured numbers go to the project memory entry, not into this spec.

Commands, from `example/`:

```bash
dart run tool/perf_freeze.dart <baseline commit> <path>...
rm -rf build/perf/abba
dart run tool/perf_abba.dart run --runs 6
dart run tool/perf_abba.dart run --from 7 --runs 6   # escalation, once
dart run tool/perf_abba.dart report                  # judge stored runs again
```

## 10. Phases

| Phase | Work | Done when |
|---|---|---|
| 1. Scroll views | `StratumThemeApplication.maybeOf`, the `StratumScrollBehavior` fix, `resolveScrollBehavior` and `ScrollFrame`, the three scroll views (section 4 without phase 4 parameters, section 6 scroll-view items), deletion of `NoGlowScrollBehavior` | `flutter analyze lib` reports 0 errors and the phase 1 tests pass |
| 2. Benchmark baseline | Section 9 harness and scenes S1 to S5 on the current layouts | Baseline medians recorded in the project memory entry |
| 3. Layout family | `BoxLayout`, the five layouts, `StratumInteraction` without phase 4 fields, `scrollBuilder` with `ScrollFrame` and no keys, gesture twins deleted, the `AnimatedStyledBox` state rewrite with `preserve` and reduced motion, the S2 versus S2-plain decision | Phase 3 tests pass and the benchmark passes |
| 4. Keyboard and accessibility | K1 to K4 with the text-entry guard, `StratumFocusGroup`, `ScrollFocus`, shortcut-only focus, focus keep-alive, guideline tests | Phase 4 tests pass and the benchmark still passes |

Each phase gets its own implementation plan. Phase 1 met the done-when of the roadmap phase `stratum-green-build`, which the owner closed on 2026-10-01. Phase 2 absorbs the benchmark of the former `stratum-style-benchmark` phase, whose gesture-layout tests become phase 3's ported tests; its deferred `WidgetStyle` minors stay separate work in the roadmap phase `stratum-style-minors`, after phase 3.

## 11. Out of scope

- Renaming the `App*` theme-token classes in `lib/src/themes/styles/`.
- Two-dimensional grid navigation and roving focus inside lazy lists.
- App-wide shortcuts such as Cmd+K; they belong at the app root.
- Intent and action based shortcuts on primitives.
- A `toolbar` semantics role, which the SDK does not offer.
- A custom `RenderObject` for the box.
- `StratumThemeApplication.updateShouldNotify`, which compares only `lightTheme`.
- Space and Shift+Space paging in scroll views.
- Focus hidden under pinned sliver headers (WCAG 2.4.11): the caller supplies those slivers; verify it when a component adds pinned headers.

## 12. Evidence

Checked in the local Flutter SDK 3.47.3 and the repository on 2026-10-01. SDK paths are under `flutter-sdk/packages/flutter/lib/src/` unless they start with `engine/`.

- `flutter analyze --no-pub lib`: 8 errors, all in `custom_scroll_view.dart`, `grid_view.dart`, and `list_view.dart` (`super_formal_parameter_without_associated_named`, `undefined_identifier`), plus two `deprecated_member_use` infos for `cacheExtent`.
- `widgets/scroll_configuration.dart` declares `buildScrollbar` and `buildOverscrollIndicator` and no `buildViewportChrome`.
- `widgets/app.dart` `WidgetsApp.defaultShortcuts`, outside web: Enter, Space, and Numpad Enter map to `ActivateIntent`; arrows to `DirectionalFocusIntent`; Control+arrows (Meta+arrows on Apple platforms) and Page Up and Page Down to `ScrollIntent`; no Home, End, or context-menu key outside text editing. On web, `_defaultWebShortcuts` (`widgets/app.dart:1308-1339`, returned at `1391-1392`) maps the arrows to `ScrollIntent`. `widgets/app.dart:1818-1823` wraps `DefaultTextEditingShortcuts`, which binds Home and End (`widgets/default_text_editing_shortcuts.dart:348-353`).
- `widgets/scrollable_helpers.dart`: `ScrollAction.isEnabled` requires a `Scrollable` above the focused context or a `PrimaryScrollController` with clients; a line is 50 px and a page is 0.8 of the viewport (`445`). `widgets/primary_scroll_controller.dart` inherits automatically only on Android, iOS, and Fuchsia.
- `widgets/gesture_detector.dart:1715-1718`: the default semantics delegate exposes tap and long press among the activation actions, plus drag updates.
- `material/ink_well.dart:1333-1336`: focus requires `enabled && canRequestFocus` in traditional navigation; `993`: `wantKeepAlive` depends on highlights and splashes; `1142-1152`: a focused, enabled `InkWell` builds a focus highlight in traditional highlight mode.
- `widgets/editable_text.dart:2638`: `wantKeepAlive => widget.focusNode.hasFocus`.
- `animation/animation_controller.dart:651`: durations scale to 5% when `disableAnimations` is set, unless the behavior is `preserve`. `engine/src/flutter/lib/web_ui/lib/src/engine/platform_dispatcher.dart:1284-1297`: the web engine sets both `reduceMotion` and `disableAnimations` from `prefers-reduced-motion`. `engine/src/flutter/shell/platform/linux/fl_settings_handler.cc:48`: Linux sets `disableAnimations` from GNOME `enable-animations`. `widgets/media_query.dart:668-669`: `MediaQueryData` has no `reduceMotion` field.
- `widgets/media_query.dart:1807`: `MediaQuery.maybePlatformBrightnessOf`.
- `dart:ui` `SemanticsRole` has no `toolbar` value; `semantics/semantics.dart:2621`: `SemanticsProperties.role` exists; `semantics/semantics.dart:169-182`, `284-295`, `343-356`, `369-394`, `447-452`: the debug checks for `tabBar`, `menu`, `menuBar`, `menuItem`, `radioGroup`, and `listItem`.
- `material/material_localizations.dart:93`: `showMenuTooltip`.
- `widgets/scroll_view.dart`: `ListView.builder` and `GridView.builder` take `physics` and `scrollCacheExtent` but no `scrollBehavior`; `ListView.separated` requires `itemCount` (`1536`), deprecates `findChildIndexCallback` in favor of `findItemIndexCallback` (`1525-1534`), and has no `semanticChildCount`; `CustomScrollView` takes `scrollBehavior` and `semanticChildCount`.
- `flutter_test`: `labeledTapTargetGuideline`, `androidTapTargetGuideline`, `iOSTapTargetGuideline`, `FakeAccessibilityFeatures(reduceMotion:)`, and `TargetPlatformVariant.desktop()` exist.
- `lib/src/components/common/focus_spread.dart:31,40`: the ring uses `BorderSide.strokeAlignOutside`.
- No file in `lib/` or `example/lib/` outside `layout/` constructs a layout, so the API changes have no callers to migrate.
- Dart 3.13.3: a named constructor in the `new` form is written `new name(...)`; `new.name(...)` fails with `new_constructor_dot_name`.
- `flutter-sdk/packages/integration_test/lib/integration_test.dart:361-362`: `traceAction` stores the whole timeline under its report key. `flutter-sdk/packages/integration_test/lib/src/_callback_io.dart:36-45`: the binding answers the driver's `request_data` only after every test has ended, with all report data in one message. One stored two-second scene timeline from phase 3 is about 6 MB (pretty-printed).

External sources, checked 2026-10-01:

- Flutter build modes (https://docs.flutter.dev/testing/build-modes): "Profile mode is disabled on the emulator and simulator, because their behavior is not representative of real performance."
- Firefox has made scrolling areas keyboard tab stops since Firefox 4 (Adrian Roselli, "Keyboard-Only Scrolling Areas", https://adrianroselli.com/2022/06/keyboard-only-scrolling-areas.html). Chrome's version applies only when the scroller has no focusable child (blink-dev "Intent to Ship: Keyboard-focusable scroll containers", https://groups.google.com/a/chromium.org/g/blink-dev/c/jzMA5vUqNDs).
- WCAG 2.2 success criteria 2.1.1, 2.1.2, 2.1.4, 2.4.7, and 2.4.11, as cited in sections 6 and 11, were checked against the W3C text by the quality review.

## 13. Decisions log

- 2026-10-01: rename scope covers the layout family only; theme-token `App*` classes stay.
- 2026-10-01: benchmark baseline before the refactor.
- 2026-10-01: `scrollable` scrolls inside the box.
- 2026-10-01: option A, one base class and one interaction object; gesture twins removed.
- 2026-10-01: desktop keyboard K1 to K4 in scope.
- 2026-10-01: one spec with four phases.
- 2026-10-01: bundle named `interaction: StratumInteraction`.
- 2026-10-01: primitives use the Flutter name plus `Layout` without prefix; scroll views become `*ViewLayout`. This replaced the earlier ruling that renamed the family to `Stratum*`.
- 2026-10-01: design sections 1 to 5 approved in brainstorming; written spec approved.
- 2026-10-01: quality review returned the spec for fixes (4 blockers, 21 important, 13 minor). The owner accepted three defaults: reduced motion through `AnimationBehavior.preserve` with one rule on every platform; macOS profile mode decides the benchmark pass, with a no-worse-than-baseline fallback; the lazy-controller threshold compares S2 with S2-plain on average build time. The revision also adds the text-entry guard, `ScrollFocus` outside the clip, the controller rule that keeps the primary controller, the semantics role constraints, `semanticsLabel` on focusable scroll views, D17, and the narrowed D16, and moves pinned-header focus out of scope.
- 2026-10-01: section 9 compares in one process. Owner rulings: the baseline enters the profile app as frozen copies that `perf_freeze` writes and the repository commits; a scene is judged on a distribution-free 95% interval of the median paired change, with a three-way verdict and the S2-plain null gate; an inconclusive comparison gets one escalation to 24 pairs per scene, and then the owner rules; the declarative ABBA harness replaces the per-scene tests in `layout_perf_test.dart`, `tool/perf_pairs.dart`, and `tool/perf_median.dart`, with scene widgets in `integration_test/widgets/`.
