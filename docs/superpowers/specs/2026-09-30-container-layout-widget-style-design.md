# ContainerLayout on WidgetStyle design

- **Date:** 2026-09-30
- **Status:** Sections 1–4 approved during brainstorming; written spec awaiting owner review.
- **Location:** `lib/src/components/common/layout/container_layout.dart`, `lib/src/components/common/model/`, new `lib/src/components/common/style/`

## 1. Goal

Refactor `ContainerLayout` so that every visual property comes from one `WidgetStyle` value, and so that the widget holds 60 fps on 120 Hz displays (an 8.3 ms frame budget) in three scenarios with equal weight:

1. Long scrolling lists and grids of styled items.
2. Interaction animation (hover, pressed, focus style changes).
3. Frosted-glass cards that blur what is behind them.

`WidgetStyle` becomes the single style model that every stratum_ui widget uses. `ContainerLayout` is the first consumer and the one every layout widget builds on.

## 2. Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Rendering approach | Custom `StyleDecoration` on `DecoratedBox`, primitive widgets, own implicit animation (approach B) | Frame rate matches a plain `Container` + `BoxDecoration` (approach A); B adds a correct inner shadow on any fill and animates every style field, blur included. A custom `RenderObject` (approach C) stays a follow-up, taken only if the benchmark shows B misses the budget. |
| Style surface on `ContainerLayout` | One `WidgetStyle? style` parameter replaces 26 flat parameters (19 style, 6 size, `alignment`) | One override channel, one `merge`, one animation target. No compatibility shim: the library is unpublished and no code outside `layout/` constructs these widgets. |
| Sizing and alignment | Move `width`, `height`, `minWidth`, `maxWidth`, `minHeight`, `maxHeight` (as `double?`) and `alignment` into `WidgetStyle` | Theme and state need to set them, as `ButtonStyle` does in Flutter. Six doubles merge field by field, so `WidgetStyle(height: 48)` keeps a theme width. |
| What stays on the widget | `ratio`, `rotate`, `transform`, `transformAlignment`, `keepAlive`, `repaintBoundary`, `debug`, `semantics`, `onEndAnimate`, `child` | Per-instance layout, behavior, accessibility, and callbacks. A callback inside `WidgetStyle` would break value equality and force a repaint on every build. |
| Drop shadow under a translucent fill | Paint the drop shadow outside the box shape only when the fill is not opaque | Matches the Figma default of not showing a shadow behind transparent areas (owner to confirm in Figma). Keeps glass cards clear. Opaque fills skip the extra clip. |
| Animation widget | Always build `AnimatedStyledBox`; a null `animationStyle` means `Duration.zero` | Switching between an animated and a static widget type would remount the subtree and drop child state. A zero-duration controller never starts a ticker. |
| Test isolation while the build is red | New and changed model/style files import only the libraries they use, not the `src.dart` barrel | The package has 193 pre-existing compile errors in 14 files, so any test that imports the barrel fails to load. Narrow imports let TDD start now for the new units. |

## 3. Bugs fixed in the current `ContainerLayout`

| Line | Defect | Fix |
|---|---|---|
| `:105` | `BackdropFilter` has no clip, so it blurs everything up to the nearest ancestor clip, often the whole screen, every frame. | Clip the blur to the box shape. |
| `:204–218` | The drop-shadow wrapper paints `theme.color.bg` behind the box. A glass card with a shadow turns opaque, and the widget depends on the theme. | Remove the wrapper; shadows live in the decoration and paint outside the shape when the fill is translucent. |
| `:273` | Inner shadow is emulated by stacking solid and background-colored shadows. It only works on an opaque solid fill and costs extra blur passes. | Real inset shadow in `StyleDecoration`. |
| `:159` | Toggling `animate` swaps `Container` and `AnimatedContainer`, which remounts the subtree. | One widget type in every case. |
| `:132` | `KeepAlive` is a `ParentDataWidget`; outside a sliver list it throws "Incorrect use of ParentDataWidget". | A private stateful wrapper with `AutomaticKeepAliveClientMixin`. |
| `:117` | Rotation uses `3.14159`. | Use `pi`. |
| `:45` comment | Claims `width`/`height` override min and max. `Container` actually calls `constraints.tighten(width, height)`, so min and max win. | Keep the runtime behavior; correct the doc comment on `WidgetStyle`. |

## 4. Architecture

### Files

```
lib/src/components/common/
  model/
    widget_style.dart            # + 7 fields, + static lerp; narrow imports
    image_blur_filter.dart       # + static lerp; narrow imports
  style/                         # new
    style.dart                   # barrel, exported from common.dart
    style_decoration.dart        # StyleDecoration + _StylePainter; narrow imports
    animated_styled_box.dart     # AnimatedStyledBox + _WidgetStyleTween; narrow imports
  layout/
    container_layout.dart        # outer wrappers + AnimatedStyledBox; private keep-alive wrapper
```

### Widget tree

Outermost first. `?` marks a node that is present only when its input is set. The order inside `AnimatedStyledBox` follows `Container.build()` so that layout and paint match the old widget.

```
Semantics?                          semantics
└ _KeepAlive?                       keepAlive
  └ WidgetPerformanceMonitor?       debug
    └ RepaintBoundary?              repaintBoundary
      └ Transform.rotate?           rotate
        └ AnimatedStyledBox         style (animated), ratio, transform, onEnd, child
          └ Opacity?                style.opacity < 1.0
            └ Transform?            transform
              └ Padding?            style.margin
                └ ConstrainedBox?   style.width / height / min* / max*
                  └ DecoratedBox?   foreground: BoxDecoration(foregroundColor/Gradient/Image, border, borderRadius)
                    └ DecoratedBox? background: StyleDecoration (fill, shadows, or blur set)
                      └ ClipRRect | ClipRect?        backgroundBlur, or clipBehavior not none
                        └ BackdropFilter.grouped?    backgroundBlur
                          └ DecoratedBox?            blur only: fill + innerShadow
                            └ ImageFiltered?         foregroundBlur, and child not null
                              └ Padding?             style.padding
                                └ Align?             style.alignment
                                  └ AspectRatio?     ratio
                                    └ KeyedSubtree   GlobalKey owned by AnimatedStyledBox
                                      └ child ?? SizedBox.shrink()
```

Every `?` node comes and goes with the style, so a hover style that adds a foreground tint changes the tree above the child. The `GlobalKey` on the `KeyedSubtree` makes Flutter move the child's element instead of rebuilding it, so the child keeps its `State` (focus, scroll offset, running animations). The cost is one `GlobalKey` per mounted box.

Without `backgroundBlur`, the background `StyleDecoration` holds drop shadows, fill, and inner shadows, and the clip (when `clipBehavior` asks for one) clips only the child. With `backgroundBlur`, the outer `StyleDecoration` holds only the drop shadows, which stay outside the clip; the fill and inner shadows move to the inner `DecoratedBox` so they paint on top of the blurred backdrop.

A box with a fill, rounded corners, and padding builds two render objects under `AnimatedStyledBox`: `RenderDecoratedBox` and `RenderPadding`.

## 5. Public API

### `WidgetStyle` additions

```dart
final double? width;
final double? height;
final double? minWidth;
final double? maxWidth;
final double? minHeight;
final double? maxHeight;
final AlignmentGeometry? alignment;

static WidgetStyle? lerp(WidgetStyle? a, WidgetStyle? b, double t);
```

`merge` and the existing "keeps every field" test cover the seven new fields. Doc comment on the size fields: min and max constraints win over `width` and `height`.

### `ImageBlurFilter` addition

```dart
static ImageBlurFilter? lerp(ImageBlurFilter? a, ImageBlurFilter? b, double t);
```

A null side counts as sigma 0. `tileMode` switches at `t = 0.5`.

### `ContainerLayout`

```dart
const ContainerLayout({
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
```

Removed: `decoration`, `padding`, `margin`, `border`, `borderRadius`, `backgroundColor`, `backgroundGradient`, `backgroundImage`, `foregroundColor`, `foregroundGradient`, `foregroundImage`, `opacity`, `clipBehavior`, `innerShadow`, `dropShadow`, `backgroundBlur`, `animate`, `animateDuration`, `animateCurve`, `width`, `height`, `minWidth`, `maxWidth`, `minHeight`, `maxHeight`, `alignment`.

### `AnimatedStyledBox`

```dart
class AnimatedStyledBox extends ImplicitlyAnimatedWidget {
  AnimatedStyledBox({
    super.key,
    this.style,                 // WidgetStyle?
    this.ratio,
    this.transform,
    this.transformAlignment,
    super.onEnd,
    this.child,
  }) : super(
         duration: style?.animationStyle?.duration ?? Duration.zero,
         curve: style?.animationStyle?.curve ?? Curves.easeInOutSine,
       );
}
```

The constructor is not `const`, because it reads `style.animationStyle` in the initializer list. Its state extends `AnimatedWidgetBaseState` with one `_WidgetStyleTween` whose `lerp` calls `WidgetStyle.lerp`. A null curve falls back to `Curves.easeInOutSine`, because the owner found a linear change too stiff (ruling 2026-09-30). `reverseDuration` and `reverseCurve` of `AnimationStyle` are not used, because `ImplicitlyAnimatedWidget` has no reverse settings; the doc comment says so.

## 6. Painting: `StyleDecoration`

```dart
class StyleDecoration extends Decoration {
  const StyleDecoration({
    this.color,
    this.gradient,
    this.image,
    this.borderRadius,
    this.dropShadow,
    this.innerShadow,
  });
}
```

`StyleDecoration` takes separate fields, not a `WidgetStyle`, because the blur path needs two instances with different subsets.

| Member | Behavior |
|---|---|
| `createBoxPainter` | Returns `_StylePainter`, which wraps a `BoxDecoration(color, gradient, image, borderRadius, boxShadow: dropShadow)` painter and forwards `onChanged` so async images repaint. |
| `==` / `hashCode` | Every field, lists compared by value. Required: `RenderDecoratedBox` skips repaint only when the new decoration is `==` to the old one. |
| `hitTest` | Same as `BoxDecoration`: inside the rounded rectangle when `borderRadius` is set, otherwise the whole rectangle. |
| `isComplex` | `true` when `dropShadow` or `innerShadow` is non-empty. |
| `padding` | `EdgeInsets.zero`. The border is painted by the foreground decoration, as in the current widget. |
| `lerpFrom` / `lerpTo` | Not overridden. Animation interpolates `WidgetStyle`, not decorations. |

### Paint order in `_StylePainter.paint`

1. **Drop shadows.** When the fill is opaque, forward to the `BoxDecoration` painter as is. When the fill is translucent, `save`, clip to the area outside the box shape (an even-odd path of a large rectangle and the rounded rectangle), paint the shadows through a shadow-only `BoxDecoration` painter, and `restore`.
2. **Fill and image.** Forward to the `BoxDecoration` painter without shadows.
3. **Inner shadows.** For each shadow: `save`; `clipRRect` to the box; build an even-odd path from a rectangle inflated by `blurRadius * 2 + |offset| + spreadRadius` and the box rounded rectangle shifted by `offset` and deflated by `spreadRadius`; draw it with `Paint()..color = shadow.color..maskFilter = MaskFilter.blur(BlurStyle.normal, shadow.blurSigma)`; `restore`.

The fill counts as opaque when `color` is set with alpha 1.0 and no gradient is set, or when a gradient is set whose colors all have alpha 1.0 and `color`, if set, has alpha 1.0. Every other case, including no fill, is translucent. An image does not change the result.

`dispose` disposes every wrapped `BoxDecoration` painter, which releases the image stream listener.

## 7. Animation: `WidgetStyle.lerp` rules

`lerp(a, b, t)` returns `a` when `identical(a, b)` and `null` when both are null. A null side of the whole style counts as `const WidgetStyle()`. Per field:

| Field | Interpolation | When one side is null |
|---|---|---|
| `backgroundColor`, `foregroundColor` | `Color.lerp` | Fades from or to transparent |
| `backgroundGradient`, `foregroundGradient` | `Gradient.lerp` | Scales from or to nothing |
| `backgroundImage`, `foregroundImage` | `DecorationImage.lerp` | Cross-fades |
| `border` | `Border.lerp` | Scales from or to nothing |
| `dropShadow`, `innerShadow` | `BoxShadow.lerpList` | Scales from or to nothing |
| `padding`, `margin` | `EdgeInsetsGeometry.lerp` | From or to zero |
| `borderRadius` | `BorderRadiusGeometry.lerp` | From or to zero |
| `backgroundBlur`, `foregroundBlur` | `ImageBlurFilter.lerp` | From or to sigma 0 |
| `opacity` | `lerpDouble` | Null counts as 1.0 |
| `alignment` | `AlignmentGeometry.lerp` | Framework default |
| `width`, `height`, `minWidth`, `maxWidth`, `minHeight`, `maxHeight` | `lerpDouble` when both sides are set | Switches at `t = 0.5`; a null size means unconstrained and has no midpoint |
| `clipBehavior` | None | Switches at `t = 0.5` |
| `animationStyle` | None | Always `b` |

Results are clamped to legal values, because a curve such as `Curves.elasticOut` drives `t` outside 0 to 1: `opacity` stays within 0 to 1, `padding`, `margin`, sizes, blur sigmas, and shadow blur radii stay non-negative, and a size switches at `t = 0.5` when either side is not finite (`lerpDouble` asserts on infinity). Without the clamp, `Opacity` and `Padding` throw assertion errors mid-animation.

## 8. Edge cases

| Case | Behavior |
|---|---|
| `style` is null | `AnimatedStyledBox` still builds; only `ratio` and `transform` wrap the child. |
| `child` is null | `SizedBox.shrink()`, as today; size comes from the size fields and padding. |
| `width` conflicts with min or max | Min and max win (`Container` semantics). |
| `backgroundBlur` without `borderRadius` | `ClipRect` instead of `ClipRRect`. |
| Clip mode | `clipBehavior` when set, otherwise `Clip.antiAlias` for rounded corners and `Clip.hardEdge` for rectangles. `Clip.antiAliasWithSaveLayer` is never chosen automatically. |
| `backgroundBlur` set | The whole box content is clipped to the shape, whatever `clipBehavior` says. |
| `opacity` is 0 | Not painted, still hit-testable (same as `Opacity`). |
| `foregroundBlur` without a child | No `ImageFiltered`. |
| `keepAlive` outside a sliver list | No error; the mixin dispatches a notification nobody listens to. |
| Style rebuilt with an equal value | No animation restart, no repaint. |
| A style change adds or removes a wrapper | The child keeps its `State` through the `KeyedSubtree` `GlobalKey`. |
| Target `style` is null | The empty style applies in the same frame, because the target has no `animationStyle`. An animation in flight stops there without error. |
| Style has only layout fields | No background `DecoratedBox` is built. |
| Min and max cross mid-animation | The range is normalized before `width` and `height` tighten it, so no constraint assertion fires. |
| `StyleDecoration` inside a `Container` with `clipBehavior` | `getClipPath` returns the rounded rectangle, as `BoxDecoration` does. |
| Theme | `ContainerLayout` no longer reads the theme. |

## 9. Migration of callers

Replace the 23–24 flat style parameters in each constructor with `WidgetStyle? style` and pass it through to `ContainerLayout`:

- `column_layout.dart`, `row_layout.dart`, `stack_layout.dart`, `wrap_layout.dart`
- `gesture_column_layout.dart`, `gesture_row_layout.dart`, `gesture_stack_layout.dart`, `gesture_wrap_layout.dart`
- `gesture_container_layout.dart` (compiles since `FalconState` comes from `flutter_falconx` and the owner added `FocusSpread`)
- `custom_scroll_view.dart` (one parameter)

No code in `example/lib` or `test/` constructs these widgets today. Until the green build (section 11) lands, callers are verified with `flutter analyze` only: no new error in any migrated file, and the package error count does not grow. Their files import the `src.dart` barrel, so widget tests cannot load them yet.

## 10. Testing

### Structural tests

| Test file | Covers |
|---|---|
| `test/src/components/common/model/widget_style_test.dart` | Existing five `merge` cases extended to the new fields; `lerp` endpoints (`t = 0` gives `a`, `t = 1` gives `b`), size switch at 0.5, color fade from null, opacity null as 1.0 |
| `test/src/components/common/model/image_blur_filter_test.dart` | Sigma interpolation, null as sigma 0 |
| `test/src/components/common/style/style_decoration_test.dart` | `==` and `hashCode`; `hitTest` false in a rounded corner; `isComplex`; paint calls through the `paints` matcher from `flutter_test` (no golden images): inner shadow clips and draws a path, translucent fill clips the shadow to the outside, opaque fill adds no clip |
| `test/src/components/common/style/animated_styled_box_test.dart` | Null `animationStyle` applies in one frame; a set duration gives the interpolated value mid-way; child `State` survives an `animationStyle` toggle; an equal style leaves `hasRunningAnimations` false |
| `test/src/components/common/layout/container_layout_test.dart` | Basic style builds one background `DecoratedBox` and no `Opacity`, clip, `BackdropFilter`, or `ImageFiltered`; blur puts the clip above `BackdropFilter` and the shadow decoration outside the clip; `keepAlive` outside a sliver does not throw |

### Benchmark

- `example/integration_test/container_layout_perf_test.dart` runs each scene inside `binding.traceAction` and reports a `TimelineSummary` through `example/test_driver/perf_driver.dart`.
- Scenes: (1) a list of 500 items with fill, radius, drop shadow, and inner shadow, flung for five seconds; (2) 50 boxes animating their style in a loop; (3) 20 glass cards inside one `BackdropGroup` scrolling over an image.
- Run with `flutter drive --profile` on a physical iOS or Android device, or on macOS desktop. Profile mode does not run on simulators or emulators.
- Pass: p99 frame build time and p99 raster time below 8.3 ms on a physical device the owner chooses. No baseline run: the old `ContainerLayout` is replaced before the example app can build (owner ruling 2026-09-30).

## 11. Phases and prerequisites

1. **Style units (done).** `WidgetStyle` fields and `lerp`, `ImageBlurFilter.lerp`, `StyleDecoration`, `AnimatedStyledBox`, each test-first, with narrow imports.
2. **`ContainerLayout` refactor** with its structural tests; `container_layout.dart` and `widget_performance_monitor.dart` move to narrow imports so the tests load.
3. **Caller migration** (section 9), verified by `flutter analyze`.
4. **Green build (separate work, owner decisions).** Clear the pre-existing errors: `font_data.dart` (owner's rewrite), flutter_gen references with no assets behind them (`FontFamily`, `AssetGenImage`, `SvgGenImage`, `AppIcon`), renamed classes still referenced by the base widgets (`ThemeApplication`, `ResponsiveBreakpoints`, `Breakpoint`), `LocaleSettings` from the absent slang package, and the `BaseResponse` ambiguous export. Not designed in this spec.
5. **Benchmark**, against the 8.3 ms budget only.

Owner ruling 2026-09-30: phases 2 and 3 run before the green build, because the owner has other work in progress in the files the green build touches. The cost is the before/after frame-time comparison, which the baseline run would have given.

## 12. Out of scope

- Style per interaction state (a hover or pressed style map).
- Theme-level default `WidgetStyle` per component.
- Animating `transform`, `rotate`, or `ratio`.
- A custom `RenderObject` (approach C), unless the benchmark calls for it.
- Placing `BackdropGroup` in screens; that belongs to the screen that shows many glass cards.

## 13. Evidence

Checked in the local Flutter SDK 3.47.3 on 2026-09-30:

| Claim | Source |
|---|---|
| `RenderDecoratedBox` repaints only when the decoration is not `==` to the old one | `rendering/proxy_box.dart:2412` |
| `BoxDecoration.hitTest` respects `borderRadius` | `painting/box_decoration.dart:375` |
| `BoxDecoration.isComplex` is `boxShadow != null` | `painting/box_decoration.dart:252` |
| `BoxDecoration` painter disposes its image painter | `painting/box_decoration.dart:564` |
| `Container` tightens constraints with `width` and `height` | `widgets/container.dart:283` |
| A zero-duration `AnimationController` completes without a ticker | `animation/animation_controller.dart:672` |
| Implicit animations restart only when the target changes | `widgets/implicit_animations.dart:430` |
| `RenderPadding` skips relayout for an equal padding | `rendering/shifted_box.dart:159` |
| `BackdropFilter.grouped` falls back to an ungrouped filter without a `BackdropGroup` | `widgets/basic.dart:737` |
| A keep-alive notification without a listener is harmless | `widgets/automatic_keep_alive.dart:428` |
| `BoxShadow` exposes `blurSigma` | `dart:ui` `painting.dart:8719` |
