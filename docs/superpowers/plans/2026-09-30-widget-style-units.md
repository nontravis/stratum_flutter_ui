# WidgetStyle Units Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the style units that `ContainerLayout` will stand on: the size and alignment fields plus `lerp` on `WidgetStyle`, `ImageBlurFilter.lerp`, the `StyleDecoration` painter, and the `AnimatedStyledBox` widget.

**Architecture:** `WidgetStyle` stays a freezed classic class; it gains seven fields and a hand-written `lerp`. `StyleDecoration` is a `Decoration` whose painter forwards drop shadows, fill, and image to Flutter's `BoxDecoration` painter and adds inset shadows on top. `AnimatedStyledBox` is an `ImplicitlyAnimatedWidget` that tweens a whole `WidgetStyle` and builds the primitive widget tree from spec section 4. Every file in this plan imports only the libraries it uses, so its tests run while the rest of the package does not compile.

**Tech Stack:** Flutter 3.47.3, Dart ^3.13.3, freezed 4.0.2, freezed_annotation 3.1.0, build_runner 2.16.1, flutter_test (`paints` matcher).

**Spec:** `docs/superpowers/specs/2026-09-30-container-layout-widget-style-design.md`

This plan covers spec section 11, phase 1 only. Phases 3 to 6 (baseline benchmark, `ContainerLayout` refactor, caller migration, benchmark after) get their own plan once the separate green-build phase leaves `flutter analyze lib` with 0 errors.

## Global Constraints

- Work in the main working tree, not a git worktree: this plan builds on uncommitted `WidgetStyle` work that a worktree from `HEAD` would not contain.
- Files under `lib/src/components/common/model/` and `lib/src/components/common/style/` never import `package:stratum_ui/src/src.dart`; they import `package:flutter/...`, `package:freezed_annotation/...`, `dart:ui`, and sibling files through `package:stratum_ui/src/components/...` URIs.
- Lints come from very_good_analysis 11: package imports only (`always_use_package_imports`), lines at most 80 characters, `public_member_api_docs` is off.
- Declare unnamed constructors with the `new(` / `const new(` syntax the surrounding code uses; freezed `factory` constructors keep the type name.
- Run tests with `flutter test --no-pub <file>` on the listed files only. A bare `flutter test` fails, because the package has 193 pre-existing compile errors.
- After changing a `@freezed` class, run `dart run build_runner build` from the repository root; output lands in `generated/` (see `build.yaml`).
- Commit with explicit paths: `git add -- <paths>` then `git commit -m "<message>" -- <paths>`. The index holds owner-staged work in progress; never commit `lib/src/src.dart`, `pubspec.yaml`, theme files, or any path a task does not list.
- Commit messages follow Conventional Commits with a scope, as in `feat(web_view): ...`. Add no `Co-Authored-By` line and no AI attribution.
- Frame budget target: 8.3 ms per frame (120 Hz), measured later by the benchmark phase.

## Review Focus

- A hover style that adds a foreground tint (`foregroundColor` from null to a color) must keep the child's `State`; a text field inside a hovered card must not lose focus. Pinned in Task 7.
- A curve that overshoots (`Curves.elasticOut`, `Curves.easeOutBack`) pushes `t` outside 0 to 1; opacity, padding, margin, sizes, and blur sigmas must stay legal instead of tripping `Opacity` or `Padding` assertions. Pinned in Tasks 2 and 3.
- An inset shadow with `blurRadius: 0` (a crisp inner line) must paint without a mask filter and without an error. Pinned in Task 5.
- A background blur on a box with no `borderRadius` must still be clipped (to a rectangle); an unclipped `BackdropFilter` blurs the whole screen. Pinned in Task 6.
- Setting `style` to null while an animation runs must settle on the empty style in the same frame, with no error and no leftover background. Pinned in Task 6.

---

### Task 1: Isolate the model files and add size and alignment fields

**Files:**
- Modify: `lib/src/components/common/model/widget_style.dart` (whole file)
- Modify: `lib/src/components/common/model/image_blur_filter.dart:1`
- Modify: `test/src/components/common/model/widget_style_test.dart:48-75`
- Regenerate: `lib/src/components/common/model/generated/widget_style.freezed.dart`, `lib/src/components/common/model/generated/image_blur_filter.freezed.dart`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `WidgetStyle` fields `double? width`, `double? height`, `double? minWidth`, `double? maxWidth`, `double? minHeight`, `double? maxHeight`, `AlignmentGeometry? alignment`, all merged by `WidgetStyle merge(WidgetStyle? other)`.

- [ ] **Step 1: Replace the barrel import in `image_blur_filter.dart`**

Replace line 1 (`import 'package:stratum_ui/src/src.dart';`) with:

```dart
import 'dart:ui' show ImageFilter, TileMode;

import 'package:freezed_annotation/freezed_annotation.dart';
```

- [ ] **Step 2: Replace the barrel import in `widget_style.dart`**

Replace line 1 (`import 'package:stratum_ui/src/src.dart';`) with:

```dart
import 'package:flutter/widgets.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stratum_ui/src/components/common/model/image_blur_filter.dart';
```

- [ ] **Step 3: Run the existing tests to prove they now load in the repository**

Run: `flutter test --no-pub test/src/components/common/model/widget_style_test.dart`
Expected: PASS, 5 tests (`+5: All tests passed!`). Before Step 2 this file failed to load with `'BaseResponse' is exported from both ...`.

- [ ] **Step 4: Extend the "keeps every field" test with the new fields**

In `test/src/components/common/model/widget_style_test.dart`, inside the `const full = WidgetStyle(` literal, insert these lines directly after `margin: EdgeInsets.all(4),`:

```dart
        width: 120,
        height: 48,
        minWidth: 40,
        maxWidth: 320,
        minHeight: 24,
        maxHeight: 96,
        alignment: Alignment.center,
```

- [ ] **Step 5: Run the test to verify it fails**

Run: `flutter test --no-pub test/src/components/common/model/widget_style_test.dart`
Expected: FAIL to compile with `No named parameter with the name 'width'.`

- [ ] **Step 6: Write the new `widget_style.dart`**

Replace the whole file with:

```dart
import 'package:flutter/widgets.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stratum_ui/src/components/common/model/image_blur_filter.dart';

part 'generated/widget_style.freezed.dart';

@freezed
class WidgetStyle with _$WidgetStyle {
  const new({
    this.opacity,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.minWidth,
    this.maxWidth,
    this.minHeight,
    this.maxHeight,
    this.alignment,
    this.border,
    this.borderRadius,
    this.backgroundColor,
    this.backgroundGradient,
    this.backgroundImage,
    this.backgroundBlur,
    this.foregroundColor,
    this.foregroundGradient,
    this.foregroundImage,
    this.foregroundBlur,
    this.clipBehavior,
    this.innerShadow,
    this.dropShadow,
    this.animationStyle,
  });
  final double? opacity;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  /// Tight width. Min and max constraints win when they conflict, as in
  /// `Container`.
  final double? width;

  /// Tight height. Min and max constraints win when they conflict, as in
  /// `Container`.
  final double? height;
  final double? minWidth;
  final double? maxWidth;
  final double? minHeight;
  final double? maxHeight;

  /// Aligns the child inside the padded box.
  final AlignmentGeometry? alignment;
  final Border? border;
  final BorderRadiusGeometry? borderRadius;
  final Color? backgroundColor;

  final Gradient? backgroundGradient;
  final DecorationImage? backgroundImage;

  final ImageBlurFilter? backgroundBlur;

  /// Painted over the child, e.g. a hover or pressed tint.
  ///
  /// Unlike `ButtonStyle.foregroundColor`, this is not the text or icon color.
  final Color? foregroundColor;
  final Gradient? foregroundGradient;
  final DecorationImage? foregroundImage;

  /// Blurs the child itself, while [backgroundBlur] blurs what is behind it.
  final ImageBlurFilter? foregroundBlur;

  final List<BoxShadow>? innerShadow;
  final List<BoxShadow>? dropShadow;

  final Clip? clipBehavior;

  final AnimationStyle? animationStyle;

  /// Returns a copy where every non-null field of [other] replaces this one.
  ///
  /// A null field in [other] keeps this value, so null cannot clear a field.
  /// Pass an empty value instead: `[]` for shadows, `EdgeInsets.zero` for
  /// spacing, `AnimationStyle.noAnimation` for [animationStyle]. Lists are
  /// replaced whole, never concatenated.
  WidgetStyle merge(WidgetStyle? other) {
    if (other == null) return this;
    return WidgetStyle(
      opacity: other.opacity ?? opacity,
      padding: other.padding ?? padding,
      margin: other.margin ?? margin,
      width: other.width ?? width,
      height: other.height ?? height,
      minWidth: other.minWidth ?? minWidth,
      maxWidth: other.maxWidth ?? maxWidth,
      minHeight: other.minHeight ?? minHeight,
      maxHeight: other.maxHeight ?? maxHeight,
      alignment: other.alignment ?? alignment,
      border: other.border ?? border,
      borderRadius: other.borderRadius ?? borderRadius,
      backgroundColor: other.backgroundColor ?? backgroundColor,
      backgroundGradient: other.backgroundGradient ?? backgroundGradient,
      backgroundImage: other.backgroundImage ?? backgroundImage,
      backgroundBlur: other.backgroundBlur ?? backgroundBlur,
      foregroundColor: other.foregroundColor ?? foregroundColor,
      foregroundGradient: other.foregroundGradient ?? foregroundGradient,
      foregroundImage: other.foregroundImage ?? foregroundImage,
      foregroundBlur: other.foregroundBlur ?? foregroundBlur,
      clipBehavior: other.clipBehavior ?? clipBehavior,
      innerShadow: other.innerShadow ?? innerShadow,
      dropShadow: other.dropShadow ?? dropShadow,
      animationStyle: other.animationStyle ?? animationStyle,
    );
  }
}
```

- [ ] **Step 7: Regenerate freezed output**

Run: `dart run build_runner build`
Expected: `wrote 2 outputs` (or `wrote 1 output`), ending with `Built with build_runner`.

- [ ] **Step 8: Run the tests to verify they pass**

Run: `flutter test --no-pub test/src/components/common/model/widget_style_test.dart`
Expected: PASS, `+5: All tests passed!`

- [ ] **Step 9: Analyze the touched files**

Run: `flutter analyze --no-pub lib/src/components/common/model test/src/components/common/model`
Expected: no `error` or `warning` lines. Two pre-existing `info • Unnecessary type name in a constructor` lines in `image_blur_filter.dart` are acceptable.

- [ ] **Step 10: Commit**

This commit also records the earlier uncommitted model work this plan builds on (`build.yaml`, the move of `ImageBlurFilter` out of `filter.dart`, the model barrel).

```bash
git add -- build.yaml \
  lib/src/components/common/model/model.dart \
  lib/src/components/common/model/widget_style.dart \
  lib/src/components/common/model/image_blur_filter.dart \
  lib/src/components/common/model/generated/widget_style.freezed.dart \
  lib/src/components/common/model/generated/image_blur_filter.freezed.dart \
  lib/src/themes/styles/filter.dart \
  lib/src/themes/styles/generated/filter.freezed.dart \
  test/src/components/common/model/widget_style_test.dart
git commit -m "feat(widget_style): add size and alignment fields to WidgetStyle" -- \
  build.yaml \
  lib/src/components/common/model/model.dart \
  lib/src/components/common/model/widget_style.dart \
  lib/src/components/common/model/image_blur_filter.dart \
  lib/src/components/common/model/generated/widget_style.freezed.dart \
  lib/src/components/common/model/generated/image_blur_filter.freezed.dart \
  lib/src/themes/styles/filter.dart \
  lib/src/themes/styles/generated/filter.freezed.dart \
  test/src/components/common/model/widget_style_test.dart
```

---

### Task 2: `ImageBlurFilter.lerp`

**Files:**
- Modify: `lib/src/components/common/model/image_blur_filter.dart`
- Create: `test/src/components/common/model/image_blur_filter_test.dart`

**Interfaces:**
- Consumes: `ImageBlurFilter({double sigmaX = 0.0, double sigmaY = 0.0, TileMode? tileMode})` and its `ImageFilter get blur`.
- Produces: `static ImageBlurFilter? lerp(ImageBlurFilter? a, ImageBlurFilter? b, double t)`.

- [ ] **Step 1: Write the failing tests**

Create `test/src/components/common/model/image_blur_filter_test.dart`:

```dart
import 'dart:ui' show TileMode;

import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/model/image_blur_filter.dart';

void main() {
  group('ImageBlurFilter.lerp', () {
    test('returns null when both sides are null', () {
      expect(ImageBlurFilter.lerp(null, null, 0.5), isNull);
    });

    test('interpolates both sigmas', () {
      final result = ImageBlurFilter.lerp(
        const ImageBlurFilter(sigmaX: 4, sigmaY: 8),
        const ImageBlurFilter(sigmaX: 8, sigmaY: 16),
        0.5,
      );

      expect(result, const ImageBlurFilter(sigmaX: 6, sigmaY: 12));
    });

    test('treats a null side as sigma 0', () {
      final result = ImageBlurFilter.lerp(
        null,
        const ImageBlurFilter(sigmaX: 10, sigmaY: 10),
        0.25,
      );

      expect(result, const ImageBlurFilter(sigmaX: 2.5, sigmaY: 2.5));
    });

    test('switches tileMode at t = 0.5', () {
      const a = ImageBlurFilter(tileMode: TileMode.clamp);
      const b = ImageBlurFilter(tileMode: TileMode.mirror);

      expect(ImageBlurFilter.lerp(a, b, 0.4)!.tileMode, TileMode.clamp);
      expect(ImageBlurFilter.lerp(a, b, 0.6)!.tileMode, TileMode.mirror);
    });

    test('never returns a negative sigma when the curve overshoots', () {
      final result = ImageBlurFilter.lerp(
        const ImageBlurFilter(sigmaX: 4, sigmaY: 4),
        const ImageBlurFilter(),
        1.5,
      );

      expect(result!.sigmaX, 0);
      expect(result.sigmaY, 0);
    });
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test --no-pub test/src/components/common/model/image_blur_filter_test.dart`
Expected: FAIL to compile with `Member not found: 'ImageBlurFilter.lerp'.`

- [ ] **Step 3: Implement `lerp`**

In `image_blur_filter.dart`, change the `dart:ui` import to:

```dart
import 'dart:ui' show ImageFilter, TileMode, lerpDouble;
```

Then add this method inside `ImageBlurFilter`, directly after the `ImageFilter get blur => ...;` getter:

```dart
  /// Interpolates the sigmas; a null side counts as sigma 0.
  ///
  /// [tileMode] switches at `t = 0.5`. Sigmas never go below 0, so a curve
  /// that overshoots cannot produce an invalid blur.
  static ImageBlurFilter? lerp(
    ImageBlurFilter? a,
    ImageBlurFilter? b,
    double t,
  ) {
    if (identical(a, b)) return a;
    double sigma(double? from, double? to) {
      final value = lerpDouble(from ?? 0, to ?? 0, t)!;
      return value < 0 ? 0 : value;
    }

    return ImageBlurFilter(
      sigmaX: sigma(a?.sigmaX, b?.sigmaX),
      sigmaY: sigma(a?.sigmaY, b?.sigmaY),
      tileMode: t < 0.5 ? a?.tileMode : b?.tileMode,
    );
  }
```

`identical(null, null)` is true, so two null sides return null.

- [ ] **Step 4: Regenerate and run the tests to verify they pass**

Run: `dart run build_runner build`
Then: `flutter test --no-pub test/src/components/common/model/image_blur_filter_test.dart`
Expected: PASS, `+5: All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add -- lib/src/components/common/model/image_blur_filter.dart \
  lib/src/components/common/model/generated/image_blur_filter.freezed.dart \
  test/src/components/common/model/image_blur_filter_test.dart
git commit -m "feat(widget_style): interpolate ImageBlurFilter sigmas" -- \
  lib/src/components/common/model/image_blur_filter.dart \
  lib/src/components/common/model/generated/image_blur_filter.freezed.dart \
  test/src/components/common/model/image_blur_filter_test.dart
```

---

### Task 3: `WidgetStyle.lerp`

**Files:**
- Modify: `lib/src/components/common/model/widget_style.dart`
- Modify: `test/src/components/common/model/widget_style_test.dart`

**Interfaces:**
- Consumes: `ImageBlurFilter.lerp` (Task 2); the seven fields from Task 1.
- Produces: `static WidgetStyle? lerp(WidgetStyle? a, WidgetStyle? b, double t)`. Returns `a` when `t == 0` and `b` when `t == 1`; a null style counts as `const WidgetStyle()`.

- [ ] **Step 1: Write the failing tests**

In `test/src/components/common/model/widget_style_test.dart`, add this group at the end of `main()`, after the closing `});` of `group('merge', ...)`:

```dart
  group('lerp', () {
    const a = WidgetStyle(
      opacity: 1,
      padding: EdgeInsets.all(8),
      width: 100,
      backgroundColor: Color(0xFF000000),
      clipBehavior: Clip.none,
      animationStyle: AnimationStyle(duration: Duration(milliseconds: 100)),
    );
    const b = WidgetStyle(
      opacity: 0.5,
      padding: EdgeInsets.all(16),
      width: 200,
      backgroundColor: Color(0xFFFFFFFF),
      clipBehavior: Clip.antiAlias,
      animationStyle: AnimationStyle(duration: Duration(milliseconds: 300)),
    );

    test('returns a at t = 0 and b at t = 1', () {
      expect(identical(WidgetStyle.lerp(a, b, 0), a), isTrue);
      expect(identical(WidgetStyle.lerp(a, b, 1), b), isTrue);
    });

    test('interpolates opacity, spacing, sizes, and colors', () {
      final mid = WidgetStyle.lerp(a, b, 0.5)!;

      expect(mid.opacity, 0.75);
      expect(mid.padding, const EdgeInsets.all(12));
      expect(mid.width, 150);
      expect(
        mid.backgroundColor,
        Color.lerp(a.backgroundColor, b.backgroundColor, 0.5),
      );
    });

    test('switches clipBehavior at t = 0.5 and takes animationStyle from b',
        () {
      expect(WidgetStyle.lerp(a, b, 0.4)!.clipBehavior, Clip.none);
      expect(WidgetStyle.lerp(a, b, 0.6)!.clipBehavior, Clip.antiAlias);
      expect(WidgetStyle.lerp(a, b, 0.1)!.animationStyle, b.animationStyle);
    });

    test('switches a size at t = 0.5 when one side is null', () {
      const unsized = WidgetStyle();
      const sized = WidgetStyle(height: 48);

      expect(WidgetStyle.lerp(unsized, sized, 0.4)!.height, isNull);
      expect(WidgetStyle.lerp(unsized, sized, 0.6)!.height, 48);
    });

    test('treats a null style as an empty style', () {
      const target = WidgetStyle(
        backgroundColor: Color(0xFFFFFFFF),
        opacity: 0.5,
      );
      final mid = WidgetStyle.lerp(null, target, 0.5)!;

      expect(
        mid.backgroundColor,
        Color.lerp(null, const Color(0xFFFFFFFF), 0.5),
      );
      expect(mid.opacity, 0.75);
    });

    test('keeps values legal when the curve overshoots', () {
      final over = WidgetStyle.lerp(b, a, 2.5)!;

      expect(over.opacity, 1);
      expect(over.padding!.isNonNegative, isTrue);
      expect(over.width, 0);
    });
  });
```

The overshoot numbers: from `b` to `a` at `t = 2.5`, raw opacity is `0.5 * -1.5 + 1 * 2.5 = 1.75`, raw padding is `16 * -1.5 + 8 * 2.5 = -4`, raw width is `200 * -1.5 + 100 * 2.5 = -50`.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test --no-pub test/src/components/common/model/widget_style_test.dart`
Expected: FAIL to compile with `Member not found: 'WidgetStyle.lerp'.`

- [ ] **Step 3: Implement `lerp`**

In `widget_style.dart`, add `import 'dart:ui' show lerpDouble;` as the first import, followed by a blank line, so the import block reads:

```dart
import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stratum_ui/src/components/common/model/image_blur_filter.dart';
```

Then add these members inside `WidgetStyle`, directly after the `merge` method:

```dart
  /// Interpolates between two styles, for implicit animation.
  ///
  /// Returns [a] at `t == 0` and [b] at `t == 1`. A null style counts as
  /// `const WidgetStyle()`. A size switches at `t = 0.5` when one side is
  /// null, because null means unconstrained. [clipBehavior] switches at
  /// `t = 0.5`, and [animationStyle] always comes from [b]. Opacity,
  /// spacing, sizes, and blur are clamped to legal values, so a curve that
  /// overshoots cannot throw.
  static WidgetStyle? lerp(WidgetStyle? a, WidgetStyle? b, double t) {
    if (identical(a, b)) return a;
    if (t == 0) return a;
    if (t == 1) return b;
    final from = a ?? const WidgetStyle();
    final to = b ?? const WidgetStyle();
    return WidgetStyle(
      opacity: _lerpOpacity(from.opacity, to.opacity, t),
      padding: _lerpSpacing(from.padding, to.padding, t),
      margin: _lerpSpacing(from.margin, to.margin, t),
      width: _lerpSize(from.width, to.width, t),
      height: _lerpSize(from.height, to.height, t),
      minWidth: _lerpSize(from.minWidth, to.minWidth, t),
      maxWidth: _lerpSize(from.maxWidth, to.maxWidth, t),
      minHeight: _lerpSize(from.minHeight, to.minHeight, t),
      maxHeight: _lerpSize(from.maxHeight, to.maxHeight, t),
      alignment: AlignmentGeometry.lerp(from.alignment, to.alignment, t),
      border: Border.lerp(from.border, to.border, t),
      borderRadius: BorderRadiusGeometry.lerp(
        from.borderRadius,
        to.borderRadius,
        t,
      ),
      backgroundColor: Color.lerp(
        from.backgroundColor,
        to.backgroundColor,
        t,
      ),
      backgroundGradient: Gradient.lerp(
        from.backgroundGradient,
        to.backgroundGradient,
        t,
      ),
      backgroundImage: DecorationImage.lerp(
        from.backgroundImage,
        to.backgroundImage,
        t,
      ),
      backgroundBlur: ImageBlurFilter.lerp(
        from.backgroundBlur,
        to.backgroundBlur,
        t,
      ),
      foregroundColor: Color.lerp(
        from.foregroundColor,
        to.foregroundColor,
        t,
      ),
      foregroundGradient: Gradient.lerp(
        from.foregroundGradient,
        to.foregroundGradient,
        t,
      ),
      foregroundImage: DecorationImage.lerp(
        from.foregroundImage,
        to.foregroundImage,
        t,
      ),
      foregroundBlur: ImageBlurFilter.lerp(
        from.foregroundBlur,
        to.foregroundBlur,
        t,
      ),
      clipBehavior: t < 0.5 ? from.clipBehavior : to.clipBehavior,
      innerShadow: BoxShadow.lerpList(from.innerShadow, to.innerShadow, t),
      dropShadow: BoxShadow.lerpList(from.dropShadow, to.dropShadow, t),
      animationStyle: to.animationStyle,
    );
  }

  static double? _lerpOpacity(double? a, double? b, double t) {
    if (a == null && b == null) return null;
    final value = lerpDouble(a ?? 1, b ?? 1, t)!;
    if (value < 0) return 0;
    if (value > 1) return 1;
    return value;
  }

  static EdgeInsetsGeometry? _lerpSpacing(
    EdgeInsetsGeometry? a,
    EdgeInsetsGeometry? b,
    double t,
  ) {
    final value = EdgeInsetsGeometry.lerp(a, b, t);
    if (value == null || value.isNonNegative) return value;
    return value.clamp(EdgeInsets.zero, EdgeInsetsGeometry.infinity);
  }

  static double? _lerpSize(double? a, double? b, double t) {
    if (a == null || b == null) return t < 0.5 ? a : b;
    final value = lerpDouble(a, b, t)!;
    return value < 0 ? 0 : value;
  }
```

- [ ] **Step 4: Regenerate and run the tests to verify they pass**

Run: `dart run build_runner build`
Then: `flutter test --no-pub test/src/components/common/model/widget_style_test.dart`
Expected: PASS, `+11: All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add -- lib/src/components/common/model/widget_style.dart \
  lib/src/components/common/model/generated/widget_style.freezed.dart \
  test/src/components/common/model/widget_style_test.dart
git commit -m "feat(widget_style): interpolate WidgetStyle with clamped values" -- \
  lib/src/components/common/model/widget_style.dart \
  lib/src/components/common/model/generated/widget_style.freezed.dart \
  test/src/components/common/model/widget_style_test.dart
```

---

### Task 4: `StyleDecoration` value semantics and delegated painting

**Files:**
- Create: `lib/src/components/common/style/style_decoration.dart`
- Create: `test/src/components/common/style/style_decoration_test.dart`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `StyleDecoration({Color? color, Gradient? gradient, DecorationImage? image, BorderRadiusGeometry? borderRadius, List<BoxShadow>? dropShadow, List<BoxShadow>? innerShadow})` with `bool get isOpaque`, value `==` and `hashCode`, rounded `hitTest`, and `isComplex`.

- [ ] **Step 1: Write the failing tests**

Create `test/src/components/common/style/style_decoration_test.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/style/style_decoration.dart';

const _radius = BorderRadius.all(Radius.circular(16));
const _shadowColor = Color(0x40000000);
const _shadow = [BoxShadow(blurRadius: 4, color: _shadowColor)];

Widget _box(StyleDecoration decoration) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: DecoratedBox(
        decoration: decoration,
        child: const SizedBox(width: 100, height: 60),
      ),
    ),
  );
}

void main() {
  group('StyleDecoration value semantics', () {
    test('equal fields give equal decorations and hash codes', () {
      const a = StyleDecoration(
        color: Color(0xFF112233),
        dropShadow: _shadow,
      );
      final b = StyleDecoration(
        color: const Color(0xFF112233),
        dropShadow: [..._shadow],
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('hitTest is false in a rounded corner', () {
      const decoration = StyleDecoration(borderRadius: _radius);
      const size = Size(100, 60);

      expect(decoration.hitTest(size, const Offset(1, 1)), isFalse);
      expect(decoration.hitTest(size, const Offset(50, 30)), isTrue);
    });

    test('isComplex is true only with shadows', () {
      expect(
        const StyleDecoration(color: Color(0xFF000000)).isComplex,
        isFalse,
      );
      expect(const StyleDecoration(dropShadow: _shadow).isComplex, isTrue);
      expect(const StyleDecoration(innerShadow: _shadow).isComplex, isTrue);
    });

    test('isOpaque needs a fill with no transparency', () {
      const opaqueGradient = LinearGradient(
        colors: [Color(0xFF000000), Color(0xFFFFFFFF)],
      );
      const fadingGradient = LinearGradient(
        colors: [Color(0xFF000000), Color(0x00FFFFFF)],
      );

      expect(const StyleDecoration().isOpaque, isFalse);
      expect(
        const StyleDecoration(color: Color(0xFF000000)).isOpaque,
        isTrue,
      );
      expect(
        const StyleDecoration(color: Color(0x80000000)).isOpaque,
        isFalse,
      );
      expect(
        const StyleDecoration(gradient: opaqueGradient).isOpaque,
        isTrue,
      );
      expect(
        const StyleDecoration(gradient: fadingGradient).isOpaque,
        isFalse,
      );
      expect(
        const StyleDecoration(
          image: DecorationImage(image: AssetImage('a.png')),
        ).isOpaque,
        isFalse,
      );
    });
  });

  group('StyleDecoration painting', () {
    testWidgets('paints the shadow, then the fill, with no clip when opaque',
        (tester) async {
      await tester.pumpWidget(
        _box(
          const StyleDecoration(
            color: Color(0xFFFFFFFF),
            borderRadius: _radius,
            dropShadow: _shadow,
          ),
        ),
      );

      final box = find.byType(DecoratedBox);
      expect(
        box,
        paints
          ..rrect(color: _shadowColor, hasMaskFilter: true)
          ..rrect(color: const Color(0xFFFFFFFF)),
      );
      expect(box, paintsExactlyCountTimes(#clipPath, 0));
    });
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test --no-pub test/src/components/common/style/style_decoration_test.dart`
Expected: FAIL to compile with `Error when reading 'lib/src/components/common/style/style_decoration.dart': No such file or directory`.

- [ ] **Step 3: Implement `StyleDecoration`**

Create `lib/src/components/common/style/style_decoration.dart`:

```dart
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/widgets.dart';

/// A [BoxDecoration] that also paints inset shadows.
///
/// Drop shadows are painted outside the box shape when the fill is
/// translucent, so a glass card does not look dimmed by its own shadow.
/// The border is not part of this decoration; paint it with a foreground
/// [BoxDecoration].
@immutable
class StyleDecoration extends Decoration {
  const new({
    this.color,
    this.gradient,
    this.image,
    this.borderRadius,
    this.dropShadow,
    this.innerShadow,
  });

  final Color? color;
  final Gradient? gradient;
  final DecorationImage? image;
  final BorderRadiusGeometry? borderRadius;
  final List<BoxShadow>? dropShadow;
  final List<BoxShadow>? innerShadow;

  /// Whether the fill hides everything behind the box.
  ///
  /// True when [color] is set with alpha 1.0 and no [gradient] is set, or
  /// when every [gradient] color has alpha 1.0 and [color], if set, has
  /// alpha 1.0. An [image] does not change the result.
  bool get isOpaque {
    final fill = color;
    if (fill != null && fill.a < 1) return false;
    final colors = gradient?.colors;
    if (colors != null) return colors.every((c) => c.a >= 1);
    return fill != null;
  }

  @override
  bool get isComplex =>
      (dropShadow?.isNotEmpty ?? false) || (innerShadow?.isNotEmpty ?? false);

  @override
  bool hitTest(Size size, Offset position, {TextDirection? textDirection}) {
    final radius = borderRadius;
    if (radius == null) return true;
    return radius
        .resolve(textDirection)
        .toRRect(Offset.zero & size)
        .contains(position);
  }

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _StylePainter(this, onChanged);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StyleDecoration &&
          other.color == color &&
          other.gradient == gradient &&
          other.image == image &&
          other.borderRadius == borderRadius &&
          listEquals(other.dropShadow, dropShadow) &&
          listEquals(other.innerShadow, innerShadow);

  @override
  int get hashCode => Object.hash(
        color,
        gradient,
        image,
        borderRadius,
        _hashList(dropShadow),
        _hashList(innerShadow),
      );

  static int? _hashList(List<BoxShadow>? shadows) =>
      shadows == null ? null : Object.hashAll(shadows);
}

class _StylePainter extends BoxPainter {
  new(this._decoration, VoidCallback? onChanged) : super(onChanged);

  final StyleDecoration _decoration;
  BoxPainter? _shadowPainter;
  BoxPainter? _fillPainter;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    _paintDropShadows(canvas, offset, configuration);
    _fillPainter ??= BoxDecoration(
      color: _decoration.color,
      gradient: _decoration.gradient,
      image: _decoration.image,
      borderRadius: _decoration.borderRadius,
    ).createBoxPainter(onChanged);
    _fillPainter!.paint(canvas, offset, configuration);
  }

  void _paintDropShadows(
    Canvas canvas,
    Offset offset,
    ImageConfiguration configuration,
  ) {
    final shadows = _decoration.dropShadow;
    if (shadows == null || shadows.isEmpty) return;
    _shadowPainter ??= BoxDecoration(
      borderRadius: _decoration.borderRadius,
      boxShadow: shadows,
    ).createBoxPainter(onChanged);
    _shadowPainter!.paint(canvas, offset, configuration);
  }

  @override
  void dispose() {
    _shadowPainter?.dispose();
    _fillPainter?.dispose();
    super.dispose();
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test --no-pub test/src/components/common/style/style_decoration_test.dart`
Expected: PASS, `+5: All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add -- lib/src/components/common/style/style_decoration.dart \
  test/src/components/common/style/style_decoration_test.dart
git commit -m "feat(style): add StyleDecoration over the BoxDecoration painter" -- \
  lib/src/components/common/style/style_decoration.dart \
  test/src/components/common/style/style_decoration_test.dart
```

---

### Task 5: Outside-only drop shadows and inset shadows

**Files:**
- Modify: `lib/src/components/common/style/style_decoration.dart` (`_StylePainter`)
- Modify: `test/src/components/common/style/style_decoration_test.dart`

**Interfaces:**
- Consumes: `StyleDecoration.isOpaque`, `dropShadow`, `innerShadow`, `borderRadius` (Task 4).
- Produces: no new public names. Paint order becomes: drop shadows (clipped to the outside when translucent), fill and image, then inset shadows.

- [ ] **Step 1: Write the failing tests**

In `style_decoration_test.dart`, add these tests inside `group('StyleDecoration painting', ...)`, after the existing test:

```dart
    testWidgets('clips the shadow to the outside when the fill is translucent',
        (tester) async {
      await tester.pumpWidget(
        _box(
          const StyleDecoration(
            color: Color(0x80FFFFFF),
            borderRadius: _radius,
            dropShadow: _shadow,
          ),
        ),
      );

      expect(
        find.byType(DecoratedBox),
        paints
          ..save()
          ..clipPath()
          ..rrect(color: _shadowColor, hasMaskFilter: true)
          ..restore()
          ..rrect(color: const Color(0x80FFFFFF)),
      );
    });

    testWidgets('paints inset shadows inside the box, above the fill',
        (tester) async {
      await tester.pumpWidget(
        _box(
          const StyleDecoration(
            color: Color(0xFFFFFFFF),
            borderRadius: _radius,
            innerShadow: _shadow,
          ),
        ),
      );

      expect(
        find.byType(DecoratedBox),
        paints
          ..rrect(color: const Color(0xFFFFFFFF))
          ..save()
          ..clipRRect()
          ..path(color: _shadowColor, hasMaskFilter: true)
          ..restore(),
      );
    });

    testWidgets('paints a zero-blur inset shadow without a mask filter',
        (tester) async {
      await tester.pumpWidget(
        _box(
          const StyleDecoration(
            color: Color(0xFFFFFFFF),
            innerShadow: [
              BoxShadow(color: _shadowColor, offset: Offset(0, 2)),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(
        find.byType(DecoratedBox),
        paints
          ..clipRRect()
          ..path(color: _shadowColor, hasMaskFilter: false),
      );
    });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test --no-pub test/src/components/common/style/style_decoration_test.dart`
Expected: FAIL on the three new tests, each reporting that the painter did not call `save`/`clipPath` or `clipRRect`/`drawPath`.

- [ ] **Step 3: Implement the painting**

In `style_decoration.dart`, replace the whole `_StylePainter` class with:

```dart
class _StylePainter extends BoxPainter {
  new(this._decoration, VoidCallback? onChanged) : super(onChanged);

  final StyleDecoration _decoration;
  BoxPainter? _shadowPainter;
  BoxPainter? _fillPainter;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final rect = offset & configuration.size!;
    final rrect = (_decoration.borderRadius ?? BorderRadius.zero)
        .resolve(configuration.textDirection)
        .toRRect(rect);
    _paintDropShadows(canvas, offset, configuration, rect, rrect);
    _fillPainter ??= BoxDecoration(
      color: _decoration.color,
      gradient: _decoration.gradient,
      image: _decoration.image,
      borderRadius: _decoration.borderRadius,
    ).createBoxPainter(onChanged);
    _fillPainter!.paint(canvas, offset, configuration);
    _paintInnerShadows(canvas, rect, rrect);
  }

  void _paintDropShadows(
    Canvas canvas,
    Offset offset,
    ImageConfiguration configuration,
    Rect rect,
    RRect rrect,
  ) {
    final shadows = _decoration.dropShadow;
    if (shadows == null || shadows.isEmpty) return;
    _shadowPainter ??= BoxDecoration(
      borderRadius: _decoration.borderRadius,
      boxShadow: shadows,
    ).createBoxPainter(onChanged);
    if (_decoration.isOpaque) {
      _shadowPainter!.paint(canvas, offset, configuration);
      return;
    }
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(rect.inflate(_reach(shadows)))
      ..addRRect(rrect);
    canvas
      ..save()
      ..clipPath(outside);
    _shadowPainter!.paint(canvas, offset, configuration);
    canvas.restore();
  }

  void _paintInnerShadows(Canvas canvas, Rect rect, RRect rrect) {
    final shadows = _decoration.innerShadow;
    if (shadows == null || shadows.isEmpty) return;
    for (final shadow in shadows) {
      final hole = rrect.shift(shadow.offset).deflate(shadow.spreadRadius);
      final ring = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(rect.inflate(_reach([shadow])))
        ..addRRect(hole);
      final paint = Paint()..color = shadow.color;
      if (shadow.blurSigma > 0) {
        paint.maskFilter = MaskFilter.blur(BlurStyle.normal, shadow.blurSigma);
      }
      canvas
        ..save()
        ..clipRRect(rrect)
        ..drawPath(ring, paint)
        ..restore();
    }
  }

  /// How far any of [shadows] can reach past the box edge.
  static double _reach(List<BoxShadow> shadows) {
    var reach = 0.0;
    for (final shadow in shadows) {
      final extent = shadow.blurSigma * 3 +
          shadow.spreadRadius.abs() +
          shadow.offset.distance;
      if (extent > reach) reach = extent;
    }
    return reach;
  }

  @override
  void dispose() {
    _shadowPainter?.dispose();
    _fillPainter?.dispose();
    super.dispose();
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test --no-pub test/src/components/common/style/style_decoration_test.dart`
Expected: PASS, `+8: All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add -- lib/src/components/common/style/style_decoration.dart \
  test/src/components/common/style/style_decoration_test.dart
git commit -m "feat(style): paint inset shadows and keep drop shadows outside glass" -- \
  lib/src/components/common/style/style_decoration.dart \
  test/src/components/common/style/style_decoration_test.dart
```

---

### Task 6: `AnimatedStyledBox` structure and animation

**Files:**
- Create: `lib/src/components/common/style/animated_styled_box.dart`
- Create: `test/src/components/common/style/animated_styled_box_test.dart`

**Interfaces:**
- Consumes: `WidgetStyle` and `WidgetStyle.lerp` (Tasks 1 and 3), `ImageBlurFilter.blur`, `StyleDecoration` (Tasks 4 and 5).
- Produces: `AnimatedStyledBox({Key? key, WidgetStyle? style, double? ratio, Matrix4? transform, AlignmentGeometry? transformAlignment, VoidCallback? onEnd, Widget? child})`. Phase 4 (`ContainerLayout`) wraps it.

- [ ] **Step 1: Write the failing tests**

Create `test/src/components/common/style/animated_styled_box_test.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/model/image_blur_filter.dart';
import 'package:stratum_ui/src/components/common/model/widget_style.dart';
import 'package:stratum_ui/src/components/common/style/animated_styled_box.dart';
import 'package:stratum_ui/src/components/common/style/style_decoration.dart';

const _radius = BorderRadius.all(Radius.circular(8));
const _blur = ImageBlurFilter(sigmaX: 10, sigmaY: 10);
const _slow = AnimationStyle(duration: Duration(milliseconds: 100));
const _red = Color(0xFFFF0000);
const _blue = Color(0xFF0000FF);

Widget _host(
  WidgetStyle? style, {
  Widget? child = const SizedBox(width: 40, height: 20),
  double? ratio,
}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: AnimatedStyledBox(style: style, ratio: ratio, child: child),
    ),
  );
}

Finder _decorated({bool Function(StyleDecoration decoration)? where}) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is DecoratedBox &&
        widget.decoration is StyleDecoration &&
        (where?.call(widget.decoration as StyleDecoration) ?? true),
  );
}

Color? _fillColor(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(_decorated());
  return (box.decoration as StyleDecoration).color;
}

void main() {
  group('AnimatedStyledBox structure', () {
    testWidgets('a fill, radius, and padding add no effect layers',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const WidgetStyle(
            backgroundColor: Color(0xFFFFFFFF),
            borderRadius: _radius,
            padding: EdgeInsets.all(8),
          ),
        ),
      );

      expect(find.byType(DecoratedBox), findsOneWidget);
      expect(find.byType(Padding), findsOneWidget);
      for (final type in const [
        Opacity,
        ClipRRect,
        ClipRect,
        BackdropFilter,
        ImageFiltered,
        ConstrainedBox,
        Align,
        Transform,
      ]) {
        expect(find.byType(type), findsNothing, reason: '$type');
      }
    });

    testWidgets('a null style passes the child through', (tester) async {
      await tester.pumpWidget(_host(null));

      expect(find.byType(DecoratedBox), findsNothing);
      expect(find.byType(Padding), findsNothing);
      expect(
        tester.getSize(find.byType(AnimatedStyledBox)),
        const Size(40, 20),
      );
    });

    testWidgets('a style with only layout fields builds no background',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const WidgetStyle(padding: EdgeInsets.all(4), borderRadius: _radius),
        ),
      );

      expect(find.byType(DecoratedBox), findsNothing);
    });

    testWidgets('opacity below 1 adds Opacity, and 1 does not',
        (tester) async {
      await tester.pumpWidget(_host(const WidgetStyle(opacity: 1)));
      expect(find.byType(Opacity), findsNothing);

      await tester.pumpWidget(_host(const WidgetStyle(opacity: 0.5)));
      expect(find.byType(Opacity), findsOneWidget);
    });

    testWidgets(
        'backgroundBlur clips above the filter and keeps the shadow outside',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const WidgetStyle(
            borderRadius: _radius,
            backgroundColor: Color(0x80FFFFFF),
            dropShadow: [BoxShadow(blurRadius: 8)],
            backgroundBlur: _blur,
          ),
        ),
      );

      final clip = find.byType(ClipRRect);
      final filter = find.byType(BackdropFilter);
      final shadow = _decorated(where: (d) => d.dropShadow != null);
      final fill = _decorated(
        where: (d) => d.color == const Color(0x80FFFFFF),
      );
      expect(find.ancestor(of: filter, matching: clip), findsOneWidget);
      expect(find.ancestor(of: clip, matching: shadow), findsOneWidget);
      expect(find.ancestor(of: fill, matching: filter), findsOneWidget);
    });

    testWidgets('backgroundBlur without a radius clips with ClipRect',
        (tester) async {
      await tester.pumpWidget(_host(const WidgetStyle(backgroundBlur: _blur)));

      expect(find.byType(ClipRRect), findsNothing);
      final clip = tester.widget<ClipRect>(find.byType(ClipRect));
      expect(clip.clipBehavior, Clip.hardEdge);
    });

    testWidgets('clipBehavior without blur clips inside the background',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const WidgetStyle(
            backgroundColor: Color(0xFFFFFFFF),
            dropShadow: [BoxShadow(blurRadius: 8)],
            borderRadius: _radius,
            clipBehavior: Clip.antiAlias,
          ),
        ),
      );

      expect(
        find.ancestor(of: find.byType(ClipRRect), matching: _decorated()),
        findsOneWidget,
      );
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('foregroundBlur needs a child', (tester) async {
      const style = WidgetStyle(foregroundBlur: _blur);

      await tester.pumpWidget(_host(style, child: null));
      expect(find.byType(ImageFiltered), findsNothing);

      await tester.pumpWidget(_host(style));
      expect(find.byType(ImageFiltered), findsOneWidget);
    });

    testWidgets('foreground fields paint over the background', (tester) async {
      await tester.pumpWidget(
        _host(
          const WidgetStyle(
            backgroundColor: Color(0xFFFFFFFF),
            foregroundColor: Color(0x1F000000),
          ),
        ),
      );

      final foreground = find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.position == DecorationPosition.foreground,
      );
      expect(
        find.ancestor(of: _decorated(), matching: foreground),
        findsOneWidget,
      );
    });

    testWidgets('min and max constraints win over width', (tester) async {
      await tester.pumpWidget(
        _host(
          const WidgetStyle(
            backgroundColor: Color(0xFFFFFFFF),
            width: 300,
            maxWidth: 100,
            height: 50,
          ),
        ),
      );

      expect(tester.getSize(_decorated()), const Size(100, 50));
    });

    testWidgets('a null child becomes an empty box sized by padding',
        (tester) async {
      await tester.pumpWidget(
        _host(const WidgetStyle(padding: EdgeInsets.all(4)), child: null),
      );

      expect(tester.getSize(find.byType(Padding)), const Size(8, 8));
    });

    testWidgets('ratio wraps the child in AspectRatio', (tester) async {
      await tester.pumpWidget(_host(null, ratio: 2));

      expect(find.byType(AspectRatio), findsOneWidget);
    });
  });

  group('AnimatedStyledBox animation', () {
    testWidgets('a null animationStyle applies the new style at once',
        (tester) async {
      await tester.pumpWidget(_host(const WidgetStyle(backgroundColor: _red)));
      await tester.pumpWidget(
        _host(const WidgetStyle(backgroundColor: _blue)),
      );

      expect(_fillColor(tester), _blue);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('a set duration interpolates half-way', (tester) async {
      await tester.pumpWidget(
        _host(const WidgetStyle(backgroundColor: _red, animationStyle: _slow)),
      );
      await tester.pumpWidget(
        _host(
          const WidgetStyle(backgroundColor: _blue, animationStyle: _slow),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(_fillColor(tester), Color.lerp(_red, _blue, 0.5));
    });

    testWidgets('an equal style does not restart the animation',
        (tester) async {
      await tester.pumpWidget(
        _host(const WidgetStyle(backgroundColor: _red, animationStyle: _slow)),
      );
      await tester.pumpWidget(
        // A new instance with equal fields, as a build method would create.
        // ignore: prefer_const_constructors
        _host(WidgetStyle(backgroundColor: _red, animationStyle: _slow)),
      );

      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('onEnd fires once when an animation completes',
        (tester) async {
      var ends = 0;
      Widget build(Color color) {
        return Directionality(
          textDirection: TextDirection.ltr,
          child: AnimatedStyledBox(
            style: WidgetStyle(backgroundColor: color, animationStyle: _slow),
            onEnd: () => ends++,
          ),
        );
      }

      await tester.pumpWidget(build(_red));
      await tester.pumpWidget(build(_blue));
      await tester.pumpAndSettle();

      expect(ends, 1);
    });

    testWidgets('a null target interrupts an animation without error',
        (tester) async {
      await tester.pumpWidget(
        _host(const WidgetStyle(backgroundColor: _red, animationStyle: _slow)),
      );
      await tester.pumpWidget(
        _host(
          const WidgetStyle(backgroundColor: _blue, animationStyle: _slow),
        ),
      );
      await tester.pump(const Duration(milliseconds: 30));
      await tester.pumpWidget(_host(null));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(_decorated(), findsNothing);
    });
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test --no-pub test/src/components/common/style/animated_styled_box_test.dart`
Expected: FAIL to compile with `Error when reading 'lib/src/components/common/style/animated_styled_box.dart': No such file or directory`.

- [ ] **Step 3: Implement `AnimatedStyledBox`**

Create `lib/src/components/common/style/animated_styled_box.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:stratum_ui/src/components/common/model/widget_style.dart';
import 'package:stratum_ui/src/components/common/style/style_decoration.dart';

/// Paints a [WidgetStyle] around [child] and animates between styles.
///
/// Duration and curve come from the target style's
/// [WidgetStyle.animationStyle]; a null value applies the new style in the
/// same frame. `AnimationStyle.reverseDuration` and `reverseCurve` are not
/// used, because [ImplicitlyAnimatedWidget] has no reverse settings.
class AnimatedStyledBox extends ImplicitlyAnimatedWidget {
  new({
    super.key,
    this.style,
    this.ratio,
    this.transform,
    this.transformAlignment,
    super.onEnd,
    this.child,
  }) : super(
         duration: style?.animationStyle?.duration ?? Duration.zero,
         curve: style?.animationStyle?.curve ?? Curves.linear,
       );

  final WidgetStyle? style;
  final double? ratio;
  final Matrix4? transform;
  final AlignmentGeometry? transformAlignment;
  final Widget? child;

  @override
  AnimatedWidgetBaseState<AnimatedStyledBox> createState() =>
      _AnimatedStyledBoxState();
}

class _AnimatedStyledBoxState
    extends AnimatedWidgetBaseState<AnimatedStyledBox> {
  _WidgetStyleTween? _style;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _style = visitor(
      _style,
      widget.style ?? const WidgetStyle(),
      (dynamic value) => _WidgetStyleTween(begin: value as WidgetStyle),
    ) as _WidgetStyleTween?;
  }

  @override
  Widget build(BuildContext context) => _buildBox(_style!.evaluate(animation));

  Widget _buildBox(WidgetStyle style) {
    final child = widget.child;
    final blur = style.backgroundBlur;
    var current = child ?? const SizedBox.shrink();

    final ratio = widget.ratio;
    if (ratio != null) {
      current = AspectRatio(aspectRatio: ratio, child: current);
    }
    final alignment = style.alignment;
    if (alignment != null) {
      current = Align(alignment: alignment, child: current);
    }
    final padding = style.padding;
    if (padding != null) {
      current = Padding(padding: padding, child: current);
    }
    final foregroundBlur = style.foregroundBlur;
    if (foregroundBlur != null && child != null) {
      current = ImageFiltered(imageFilter: foregroundBlur.blur, child: current);
    }
    if (blur != null) {
      current = DecoratedBox(
        decoration: StyleDecoration(
          color: style.backgroundColor,
          gradient: style.backgroundGradient,
          image: style.backgroundImage,
          borderRadius: style.borderRadius,
          innerShadow: style.innerShadow,
        ),
        child: current,
      );
      current = BackdropFilter.grouped(filter: blur.blur, child: current);
    }
    current = _clip(style, hasBlur: blur != null, child: current);
    if (blur != null) {
      if (style.dropShadow != null) {
        current = DecoratedBox(
          decoration: StyleDecoration(
            borderRadius: style.borderRadius,
            dropShadow: style.dropShadow,
          ),
          child: current,
        );
      }
    } else if (_hasBackground(style)) {
      current = DecoratedBox(
        decoration: StyleDecoration(
          color: style.backgroundColor,
          gradient: style.backgroundGradient,
          image: style.backgroundImage,
          borderRadius: style.borderRadius,
          dropShadow: style.dropShadow,
          innerShadow: style.innerShadow,
        ),
        child: current,
      );
    }
    if (_hasForeground(style)) {
      current = DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          color: style.foregroundColor,
          gradient: style.foregroundGradient,
          image: style.foregroundImage,
          border: style.border,
          borderRadius: style.borderRadius,
        ),
        child: current,
      );
    }
    final constraints = _constraints(style);
    if (constraints != null) {
      current = ConstrainedBox(constraints: constraints, child: current);
    }
    final margin = style.margin;
    if (margin != null) {
      current = Padding(padding: margin, child: current);
    }
    final transform = widget.transform;
    if (transform != null) {
      current = Transform(
        transform: transform,
        alignment: widget.transformAlignment,
        child: current,
      );
    }
    final opacity = style.opacity;
    if (opacity != null && opacity < 1) {
      current = Opacity(opacity: opacity, child: current);
    }
    return current;
  }

  static bool _hasBackground(WidgetStyle style) =>
      style.backgroundColor != null ||
      style.backgroundGradient != null ||
      style.backgroundImage != null ||
      style.dropShadow != null ||
      style.innerShadow != null;

  static bool _hasForeground(WidgetStyle style) =>
      style.foregroundColor != null ||
      style.foregroundGradient != null ||
      style.foregroundImage != null ||
      style.border != null;

  /// Clips when a blur is set or [WidgetStyle.clipBehavior] asks for it.
  ///
  /// A blur is always clipped, because an unclipped `BackdropFilter` blurs
  /// everything up to the nearest ancestor clip.
  static Widget _clip(
    WidgetStyle style, {
    required bool hasBlur,
    required Widget child,
  }) {
    final requested = style.clipBehavior ?? Clip.none;
    if (!hasBlur && requested == Clip.none) return child;
    final radius = style.borderRadius;
    final behavior = requested != Clip.none
        ? requested
        : (radius == null ? Clip.hardEdge : Clip.antiAlias);
    if (radius == null) {
      return ClipRect(clipBehavior: behavior, child: child);
    }
    return ClipRRect(
      borderRadius: radius,
      clipBehavior: behavior,
      child: child,
    );
  }

  /// Same rules as `Container`: min and max win over width and height.
  static BoxConstraints? _constraints(WidgetStyle style) {
    final hasRange = style.minWidth != null ||
        style.maxWidth != null ||
        style.minHeight != null ||
        style.maxHeight != null;
    var constraints = hasRange
        ? BoxConstraints(
            minWidth: style.minWidth ?? 0,
            maxWidth: style.maxWidth ?? double.infinity,
            minHeight: style.minHeight ?? 0,
            maxHeight: style.maxHeight ?? double.infinity,
          )
        : null;
    if (style.width != null || style.height != null) {
      constraints = constraints?.tighten(
            width: style.width,
            height: style.height,
          ) ??
          BoxConstraints.tightFor(width: style.width, height: style.height);
    }
    return constraints;
  }
}

class _WidgetStyleTween extends Tween<WidgetStyle> {
  new({super.begin});

  @override
  WidgetStyle lerp(double t) => WidgetStyle.lerp(begin, end, t)!;
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test --no-pub test/src/components/common/style/animated_styled_box_test.dart`
Expected: PASS, `+17: All tests passed!`

- [ ] **Step 5: Analyze the new files**

Run: `flutter analyze --no-pub lib/src/components/common/style test/src/components/common/style`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add -- lib/src/components/common/style/animated_styled_box.dart \
  test/src/components/common/style/animated_styled_box_test.dart
git commit -m "feat(style): add AnimatedStyledBox built from WidgetStyle" -- \
  lib/src/components/common/style/animated_styled_box.dart \
  test/src/components/common/style/animated_styled_box_test.dart
```

---

### Task 7: Keep the child's State when wrappers change

**Files:**
- Modify: `lib/src/components/common/style/animated_styled_box.dart` (`_AnimatedStyledBoxState`)
- Modify: `test/src/components/common/style/animated_styled_box_test.dart`

**Interfaces:**
- Consumes: `AnimatedStyledBox` (Task 6).
- Produces: no new public names. The child subtree sits under a `KeyedSubtree` whose `GlobalKey` the state owns.

- [ ] **Step 1: Write the failing test**

In `animated_styled_box_test.dart`, add this test inside `group('AnimatedStyledBox animation', ...)`, after the last test:

```dart
    testWidgets('the child keeps its State when wrappers come and go',
        (tester) async {
      await tester.pumpWidget(_host(const WidgetStyle(), child: const _Probe()));
      final before = tester.state(find.byType(_Probe));

      for (final style in const [
        WidgetStyle(foregroundColor: Color(0x1F000000)),
        WidgetStyle(opacity: 0.5),
        WidgetStyle(margin: EdgeInsets.all(4), backgroundBlur: _blur),
        WidgetStyle(animationStyle: AnimationStyle.noAnimation),
        WidgetStyle(),
      ]) {
        await tester.pumpWidget(_host(style, child: const _Probe()));
        expect(
          identical(tester.state(find.byType(_Probe)), before),
          isTrue,
          reason: '$style',
        );
      }
    });
```

Then add this class at the end of the file, after `main()`:

```dart
class _Probe extends StatefulWidget {
  const _Probe();

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  Widget build(BuildContext context) => const SizedBox(width: 40, height: 20);
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test --no-pub test/src/components/common/style/animated_styled_box_test.dart`
Expected: FAIL on `the child keeps its State when wrappers come and go` with `Expected: true  Actual: <false>` and a reason naming the `foregroundColor` style.

- [ ] **Step 3: Key the child subtree**

In `_AnimatedStyledBoxState`, add this field directly above `_WidgetStyleTween? _style;`:

```dart
  final GlobalKey _childKey = GlobalKey(debugLabel: 'AnimatedStyledBox.child');
```

In `_buildBox`, replace the line

```dart
    var current = child ?? const SizedBox.shrink();
```

with

```dart
    // Wrappers above the child come and go with the style. The GlobalKey
    // makes Flutter move the child's element instead of rebuilding it, so
    // the child keeps its State.
    Widget current = KeyedSubtree(
      key: _childKey,
      child: child ?? const SizedBox.shrink(),
    );
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test --no-pub test/src/components/common/style/animated_styled_box_test.dart`
Expected: PASS, `+18: All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add -- lib/src/components/common/style/animated_styled_box.dart \
  test/src/components/common/style/animated_styled_box_test.dart
git commit -m "fix(style): keep the child State when style wrappers change" -- \
  lib/src/components/common/style/animated_styled_box.dart \
  test/src/components/common/style/animated_styled_box_test.dart
```

---

### Task 8: Export the style units and verify the phase

**Files:**
- Create: `lib/src/components/common/style/style.dart`
- Modify: `lib/src/components/common/common.dart`

**Interfaces:**
- Consumes: `StyleDecoration`, `AnimatedStyledBox` (Tasks 4 to 7).
- Produces: both names exported through `package:stratum_ui/stratum_ui.dart`, ready for the `ContainerLayout` plan.

- [ ] **Step 1: Record the pre-existing error count**

Run: `flutter analyze --no-pub lib > /tmp/analyze_before.txt 2>&1; grep -c '^ *error' /tmp/analyze_before.txt`
Expected: a number; write it down. It was `193` when this plan was written; owner work in progress may change it.

- [ ] **Step 2: Create the barrel**

Create `lib/src/components/common/style/style.dart`:

```dart
export 'animated_styled_box.dart';
export 'style_decoration.dart';
```

- [ ] **Step 3: Export it from the common barrel**

In `lib/src/components/common/common.dart`, add this line directly after `export 'space_directional.dart';`:

```dart
export 'style/style.dart';
```

- [ ] **Step 4: Verify no new errors and no name clash**

Run: `flutter analyze --no-pub lib > /tmp/analyze_after.txt 2>&1; grep -c '^ *error' /tmp/analyze_after.txt; grep -E 'components/common/(style|model)/|ambiguous_export.*(StyleDecoration|AnimatedStyledBox)' /tmp/analyze_after.txt`
Expected: the same number as Step 1, then only the two known `info • Unnecessary type name in a constructor` lines from `model/image_blur_filter.dart`.

- [ ] **Step 5: Run every test from this plan together**

Run: `flutter test --no-pub test/src/components/common/model test/src/components/common/style`
Expected: PASS, `+42: All tests passed!` (11 `widget_style`, 5 `image_blur_filter`, 8 `style_decoration`, 18 `animated_styled_box`).

- [ ] **Step 6: Commit**

```bash
git add -- lib/src/components/common/style/style.dart \
  lib/src/components/common/common.dart
git commit -m "feat(style): export the style units from the common barrel" -- \
  lib/src/components/common/style/style.dart \
  lib/src/components/common/common.dart
```

`lib/src/components/common/common.dart` has no owner changes in the working tree today; if `git diff -- lib/src/components/common/common.dart` shows lines other than the new export before this commit, stop and ask the owner.
