# Theme typography design

- **Date:** 2026-10-02
- **Status:** Design approved in chat on 2026-10-02; awaiting spec review. Three data lookups remain open (section 14); none blocks the code.
- **Location:** new `lib/src/themes/typography/` (`dimension.dart`, `typography.dart`, `resolver.dart`); rewritten `lib/src/themes/font_data.dart` and `lib/src/components/common/style/text_style_builder.dart`; changes in `lib/src/themes/theme_data.dart`, `lib/src/themes/constant/font_type.dart`, `lib/src/themes/constant/font_size.dart`, `lib/src/components/common/responsive/window_size_scope.dart`, `assets/themes/default/theme.yaml`, and `pubspec.yaml`.

## 1. Goal

Give Stratum one typography system driven by `theme.yaml`: a value type that holds a fixed or percent number, a typography model parsed from the `typography:` subtree, a pure resolver that turns a text recipe plus the screen environment into a Flutter `TextStyle`, and the immutable builder `StratumTextStyle` that widgets call, in the style of mangmee's `AppTextStyleBuilder`.

Success criteria:

- Every test in section 11 is written before its implementation, fails first, and then passes.
- `flutter test` passes, including the 572 tests that pass on master today.
- `flutter analyze` reports no new issue in `lib`, `test`, or `example`.
- For every Figma text style in section 15, the resolver at text scale 1, window size `mobile`, and `adjustSize` 0 returns `fontSize == size` and `height × fontSize == lineHeight`.
- The owner checks Thai stacked marks on `example/lib/typography_demo.dart` at text scale 100%, 150%, and 200% on every window size.

## 2. Context

The theme brainstorm of 2026-10-02 split the theme system into five sub-projects, each with its own spec, plan, and implementation (owner ruling, Option A):

| # | Sub-project | Depends on |
|---|---|---|
| 1 | Typography, `StratumDimension`, `StratumTextStyle` (this spec) | none |
| 2 | theme.yaml schema v1: whole-file parser, validation, token aliases, merge over `default` | 1 |
| 3 | `StratumThemeData` defaults and app extensions (palettes, asset slots such as splash, loading, mascot), widget resolve API | 2 |
| 4 | Theme registry and runtime: bundled discovery under `assets/themes/<id>/`, app override of `default`, preload, runtime switch, font loading, persistence | 3 |
| 5 | Remote `<id>.zip` install: checksum or signature, safe extraction, versioning | 4 |

This spec parses only the `typography:` subtree. Sub-project 2 lifts the parser and its error type into a whole-file framework.

## 3. Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Q1 line box | `size = base + scaleByWindowSize`; `fontSize = size + adjustSize`; `lineBox = base + spaceHeight`. The line box excludes both the window scale and `adjustSize`. | Line spacing stays equal to Figma on every window size. Rejected: `lineBox = size + spaceHeight`, which grew the line box with the window. |
| Q2 system text scale | The builder reads `MediaQuery.textScalerOf` and computes the line box itself. A fixed `spaceHeight` keeps its px at any scale; a percent `spaceHeight` resolves against the scaled base. | The theme author picks the behavior per value: `8` keeps an 8 px gap, `"50%"` grows with the text. Rejected: always proportional (Flutter's default), which gave the author no fixed option. |
| Q3 percent bases | `size` takes fixed values only. `scaleByWindowSize` and `adjustSize` resolve against `base`; `spaceHeight` against `scale(base)`; `letterSpacing` against `scale(size)`, before `adjustSize`. | `adjustSize` only corrects how large a font looks, so tracking follows the size the designer saw in Figma. A percent `size` would need a root size (CSS `rem`) that nothing uses yet. |
| Value syntax | A bare number is fixed; a string `"N%"` is percent. | Matches the existing theme.yaml (`letterSpace: 1.0%`). Dart `yaml` parses `50%` and `-12.5%` as strings without quotes (verified, section 15). |
| Value type name | `StratumDimension`, with `.fixed` and `.percent` | The W3C Design Tokens format calls a number with a unit a `dimension`. The prefix matches `StratumThemeData`. Sub-projects 2 and 3 reuse it for space, radius, and layout widths. Rejected: `DesignValue` (colors and shadows are design values too; no prefix), `StratumLength` (CSS term, unfamiliar outside the web). |
| Q4 `.mono` | `.mono` swaps to a mono family and keeps the type's metrics; the mono font's own `adjustSize` applies. `table` is body metrics plus `FontFeature.tabularFigures()` on the body font. `numberMono` leaves `FontType`; callers write `number.mono`. | Figma's `number/10-mono` swaps to Geist Mono, while `body/*-table-regular` keeps Inter with body metrics. Rejected: `.mono` as tabular figures only (cannot express Geist Mono); separate `.mono` and `.tabular` modifiers (larger API, `.mono.tabular` is redundant). |
| Q5 locale and mixed scripts | A1: the locale picks the primary family; `fontFamilyFallback` lists the bundled fonts of the same type from other locale entries, so fallback glyphs take the primary font's size. | Without a fallback list, missing glyphs use the platform font, which differs per platform and can show tofu on Linux and offline web. Deferred: A2, splitting text into script runs so each fallback font uses its own `StratumFontData`; a later `scripts:` field adds it without breaking yaml. |
| Q6 yaml shape | Layered: `fonts`, `families`, `scaleByWindowSize`, `types` (section 5) | Changing a font's `adjustSize`, adding a locale, or adding a size each touches one place. Rejected: a flat block per type, size, and locale (about 80 blocks, the font repeated in each); Figma style names (weight inside the name clashes with builder weight getters). |
| Q7 size missing for a type | Every `FontSize` getter exists on every type. A size the yaml lacks for that type uses the nearest defined size and prints a debug warning once. | The theme decides which sizes exist, and a remote theme with a gap cannot crash a screen. Rejected: one builder class per type (locks sizes in code); throwing. |
| Q8 builder mutability | Immutable: each getter returns a copy. | A stored builder stays safe to reuse, and a stable `==` and `hashCode` make the resolved `TextStyle` cacheable. The allocation cost is negligible next to the `TextStyle` built anyway. Rejected: mangmee's mutable cascade, where `base.bold` also turns every other user of `base` bold. |
| Builder name | `StratumTextStyle` | Short at every call site; `.build(context)` shows it is a recipe. Rejected: `StratumTextStyleBuilder` (long). |
| Default theme `spaceHeight` | Figma px values (fixed) | Readable side by side with Figma. Accepted cost: near 200% text scale the lines run tight (body s14 gives height 1.36), so Thai marks need the manual check in section 11. Rejected: percent values such as `"71.43%"`. |
| Leading distribution | `TextLeadingDistribution.even` | Figma splits the extra line space evenly above and below. Flutter's default `proportional` splits it by the font's ascent and descent, so text would sit off its Figma position. |
| Parse scope | `StratumTypography.fromYaml` parses the `typography:` node only. | Testable end to end now; sub-project 2 generalizes it. |
| Errors | Collect every error with its yaml path, then throw one `StratumThemeFormatException`. Unknown keys print a debug warning and are skipped. | An author fixes a theme in one pass, and sub-project 5 needs the full report for remote themes. Skipping unknown keys lets a theme written for a newer schema open on an older app. |
| Test run | Test-first | Owner rule for this repository. |

## 4. Current defects fixed here

| ID | Location | Defect | Fix |
|---|---|---|---|
| T1 | `lib/src/components/common/style/text_style_builder.dart` | Staged with 0 lines. | `StratumTextStyle` (section 8). |
| T2 | `lib/src/themes/constant/font_type.dart:1` | `numberMono` is a type, so `.mono` cannot apply to every type; there is no `table` path to tabular figures. | `enum FontType { header, paragraph, number, code, body, table }`; mono becomes the `.mono` modifier. |
| T3 | `lib/src/themes/font_data.dart:3` | `StratumFontData` has no locale or type, and its multiplier fields (`fontSizeScaleAdjustment`, `letterSpaceScaleAdjustment`) do not match the agreed additive `adjustSize`. | Rewrite (section 6). Locale and type move to `families`. |
| T4 | `assets/themes/default/theme.yaml:146` onward | Every type, size, and locale repeats `fontFamily`, `letterSpace`, and `adjustSize`. | Replace the `typography:` subtree with the layered shape (section 5). |
| T5 | `lib/src/themes/constant/font_size.dart:1` | `FontSize.custom` stands for a value the enum cannot hold. | Drop `custom`; add `double get value`; the builder keeps a custom size as a `double`. |
| T6 | `lib/src/components/common/responsive/window_size_scope.dart:15` | Only `of` exists and it throws without a scope. | Add `static WindowSize? maybeOf(BuildContext context)`, which registers the same dependency. |
| T7 | `pubspec.yaml:73` | Flutter does not include subfolders, so `assets/themes/default/theme.yaml` is not bundled. | Declare `assets/themes/default/`. |
| T8 | `lib/src/themes/theme_data.dart:16, 37, 106, 128` | `fonts: List<StratumFontData>` holds no metrics, locales, or types. | Replace with `typography: StratumTypography` in the constructor, field, and `copyWith`. |

`StratumFontData` is used only in `theme_data.dart`. Test and example themes are `Fake`s or `noSuchMethod` stand-ins (`test/src/components/common/fakes/fake_stratum_theme.dart:38`, `example/lib/focus_demo.dart`), so the new field breaks no existing call site.

## 5. YAML schema

### Shape and default content

The default theme's `typography:` subtree after this change. Values come from the Figma file `wjRe9eL7863nMRfFats8jZ` (section 15). `letterSpacing` is written as percent pending lookup L1; there is no `th` entry pending lookup L2.

```yaml
typography:
  fonts:                         # font key: physical family plus its own tuning
    inter:       { family: Inter }
    geist:       { family: Geist }
    geist-mono:  { family: Geist Mono }
    roboto-mono: { family: Roboto Mono }

  families:                      # per locale tag: type to font key
    default:
      header: inter
      paragraph: inter
      body: inter
      number: { font: geist, mono: geist-mono }
      code: roboto-mono
      mono: roboto-mono          # theme-wide mono for types without their own

  scaleByWindowSize: { watch: 0, mobile: 0, tablet: 0.5, desktop: 1, bigDesktop: 2 }

  types:
    header:
      weight: 600
      sizes:
        s56: { spaceHeight: 16, letterSpacing: "-2.4%" }
        s36: { spaceHeight: 12, letterSpacing: "-2%" }
        s24: { spaceHeight: 10, letterSpacing: "-1.4%" }
        s20: { spaceHeight: 8,  letterSpacing: "-1.2%" }
        s18: { spaceHeight: 6,  letterSpacing: "-1%" }
        s14: { spaceHeight: 6,  letterSpacing: "0.6%" }
        s12: { spaceHeight: 8,  letterSpacing: "1.8%" }
    paragraph:
      weight: 400
      sizes:
        s20: { spaceHeight: 12, letterSpacing: "-1%" }
        s18: { spaceHeight: 12, letterSpacing: "-1%" }
        s16: { spaceHeight: 10, letterSpacing: "0%" }
        s14: { spaceHeight: 10, letterSpacing: "0.2%" }
    body:
      weight: 400
      sizes:
        s18: { spaceHeight: 10, letterSpacing: "-1%" }
        s16: { spaceHeight: 8,  letterSpacing: "-1%" }
        s14: { spaceHeight: 10, letterSpacing: "-0.6%" }
        s12: { spaceHeight: 4,  letterSpacing: "0.5%" }
        s10: { spaceHeight: 6,  letterSpacing: "0.8%" }
    number:
      weight: 600
      sizes:
        s36: { spaceHeight: 12 }
        s24: { spaceHeight: 8 }
        s18: { spaceHeight: 6 }
        s16: { spaceHeight: 8 }
        s14: { spaceHeight: 10 }
        s12: { spaceHeight: 4 }
        s10: { spaceHeight: 6 }
    code:
      weight: 400
      sizes:
        s18: { spaceHeight: 6 }
        s16: { spaceHeight: 8 }
        s14: { spaceHeight: 10 }
        s12: { spaceHeight: 4 }
    table:
      extends: body
      tabular: true
```

An app theme that adds Thai would add one block, for example:

```yaml
  fonts:
    font-a: { family: Font A, adjustSize: 2 }
  families:
    th: { header: font-a, paragraph: font-a, body: font-a }
```

### Parse rules

| Node | Rule |
|---|---|
| Dimension value | `int` or `double` gives `StratumDimension.fixed`; a `String` matching `^-?\d+(\.\d+)?%$` gives `StratumDimension.percent(n / 100)`; anything else is an error. |
| `fonts.<key>` | `family` (string, required), `package` (string, optional), `adjustSize` (dimension, default `0`). |
| `families.<tag>` | `<tag>` is `default`, a language (`th`), or language and country (`th_TH`); `th-TH` is accepted and normalized to `th_TH`. Each type maps to a font key or to `{ font, mono }`. The key `mono` names the theme-wide mono font for that tag. |
| `scaleByWindowSize` | Keys are `WindowSize` names; values are dimensions; missing keys mean `0`. |
| `types.<type>` | `<type>` is a `FontType` name. `weight` is an int from 100 to 900 in steps of 100. `sizes` maps `FontSize` names to `{ spaceHeight, letterSpacing }`. Optional: `scaleByWindowSize` (per-type override, same shape as the global one), `extends` (another type name), `tabular` (bool, default `false`). |
| `extends` | Resolved at parse time. The child inherits `weight`, `tabular`, `scaleByWindowSize`, and every size it does not define, and the family lookup also walks the chain (section 7, step 2). Chains of any length are allowed; cycles are errors. |

Required: at least one entry in `fonts`; a `families.default` entry that resolves a font for every type, directly or through `extends`; a `weight` and at least one size on every type after `extends`; a `spaceHeight` on every size. Optional with default `0`: `adjustSize`, `letterSpacing`, `scaleByWindowSize`, `package`, `mono`.

### Errors

`StratumTypography.fromYaml` walks the whole subtree, collects every problem, and throws one `StratumThemeFormatException` that lists them all. Each entry names its yaml path:

```
typography.types.body.sizes.s16.spaceHeight: expected a number or "N%", got "8px"
typography.families.th.body: unknown font key "kanit"
typography.types.table.extends: cycle table -> body -> table
typography.families.default.code: no font for type "code"
```

An unknown key prints one debug warning with its path and is skipped.

## 6. Data model

```dart
// lib/src/themes/typography/dimension.dart
sealed class StratumDimension {
  const factory StratumDimension.fixed(double px) = FixedDimension;
  const factory StratumDimension.percent(double ratio) = PercentDimension;

  /// A number gives fixed; "N%" gives percent; anything else throws
  /// [FormatException].
  factory StratumDimension.parse(Object? value);

  /// Pixels; [of] is the base a percent value resolves against.
  double resolve({required double of});
}

final class FixedDimension implements StratumDimension { final double px; }
final class PercentDimension implements StratumDimension { final double ratio; }

// lib/src/themes/font_data.dart
class StratumFontData {
  const StratumFontData({
    required this.family,
    this.package,
    this.adjustSize = const StratumDimension.fixed(0),
  });

  final String family;
  final String? package;
  final StratumDimension adjustSize;

  /// `packages/<package>/<family>` when [package] is set.
  String get qualifiedFamily;
}

// lib/src/themes/typography/typography.dart
class StratumFontRef {
  final String font;   // key into StratumTypography.fonts
  final String? mono;  // key into StratumTypography.fonts
}

class StratumFamilySet {
  final Map<FontType, StratumFontRef> types;
  final String? mono;  // theme-wide mono font key for this tag
}

class StratumSizeMetrics {
  final StratumDimension spaceHeight;
  final StratumDimension letterSpacing;
}

class StratumTypeStyle {
  final FontWeight weight;
  final bool tabular;
  final FontType? extendsType;                          // kept for the family lookup
  final Map<WindowSize, StratumDimension>? scaleByWindowSize;
  final Map<FontSize, StratumSizeMetrics> sizes;        // after extends
}

class StratumTypography {
  final Map<String, StratumFontData> fonts;
  final Map<String, StratumFamilySet> families;         // yaml order kept
  final Map<WindowSize, StratumDimension> scaleByWindowSize;
  final Map<FontType, StratumTypeStyle> types;

  /// Parses the `typography:` node; throws [StratumThemeFormatException].
  factory StratumTypography.fromYaml(YamlMap node);
}

class StratumThemeFormatException implements Exception {
  final List<StratumThemeFormatError> errors;  // each has `path` and `message`
}
```

All model classes are immutable and implement `==` and `hashCode`.

Enum changes: `enum FontType { header, paragraph, number, code, body, table }` and `enum FontSize { s10, s12, s14, s16, s18, s20, s24, s36, s48, s56 }` with `double get value`.

`StratumThemeData` replaces `final List<StratumFontData> fonts` with `final StratumTypography typography` in its constructor, field, and `copyWith`.

## 7. Resolution

`TypographyResolver.resolve(recipe, theme:, locale:, windowSize:, textScaler:)` in `lib/src/themes/typography/resolver.dart` is a pure function: it reads no `BuildContext`.

Worked example: `StratumTextStyle.body.s16.medium`, locale `th_TH`, window `desktop`, a linear text scale of 2.0, with `fonts.font-a: { family: Font A, adjustSize: 2 }`, `families.th.body: font-a`, `families.default.body: inter`, `scaleByWindowSize.desktop: 1`, and `types.body.sizes.s16: { spaceHeight: "50%", letterSpacing: "-1%" }`.

| Step | Rule | Example |
|---|---|---|
| 1. Size metrics | `types[type].sizes[size]`. A missing size takes the nearest defined size by `|value − target|`, the smaller one on a tie, with one debug warning per type and size. A custom size (`size(double)`) takes the nearest metrics without a warning. `base` is the requested size value. | `base` 16, `spaceHeight` 50%, `letterSpacing` −1% |
| 2. Primary font | Build the tag chain from the locale: `<lang>_<country>` when a country exists, then `<lang>`, then `default`. For each tag in order, look up the type, then each `extends` ancestor; the first hit wins. With `.mono` on a type other than `code`: first the type's `mono` along the same chain, then each tag's theme-wide `mono`, then the non-mono primary with a debug warning. | `th_TH` has no entry; `th.body` gives `font-a`, Font A |
| 3. Fallback list | For each tag (`default` first, then yaml order), the tag's mono font for the type when `.mono` is set, then the tag's primary font for the type; drop duplicates and the primary. Families are passed as `qualifiedFamily`, and `TextStyle.package` stays null. | `[Inter]` |
| 4. Window scale | `types[type].scaleByWindowSize[ws]`, else `typography.scaleByWindowSize[ws]`, else `0`; percent resolves against `base`. A null window size gives `0`. | +1, so `size` = 17 |
| 5. Font size | `fontSize = size + font.adjustSize.resolve(of: base)` | 17 + 2 = 19 |
| 6. Line box | `scaledBase = textScaler.scale(base)`; `lineBox = scaledBase + spaceHeight.resolve(of: scaledBase)` | 32 + 16 = 48 |
| 7. Height | `height = lineBox / textScaler.scale(fontSize)` | 48 / 38 = 1.263 |
| 8. Letter spacing | `letterSpacing.resolve(of: textScaler.scale(size))`. Flutter does not scale `letterSpacing`, so the resolver passes the scaled value. | −1% × 34 = −0.34 |
| 9. The rest | `fontWeight` = the recipe's weight, else the type's; `fontFeatures` = `[FontFeature.tabularFigures()]` when the type is `tabular`; `color` = the recipe's custom color, else the theme color for its `FontColor` (default `primary`); `fontStyle`, `decoration`, and `shadows` from the recipe; `leadingDistribution: TextLeadingDistribution.even`. | `FontWeight.w500` |

Result for the example:

```dart
TextStyle(
  fontFamily: 'Font A',
  fontFamilyFallback: ['Inter'],
  fontSize: 19,          // Flutter renders 38 at a scale of 2.0
  height: 1.263,         // 1.263 × 38 = a 48 px line
  letterSpacing: -0.34,  // already scaled
  fontWeight: FontWeight.w500,
  leadingDistribution: TextLeadingDistribution.even,
)
```

At a scale of 1.0 the same recipe gives `fontSize` 19, a line box of 16 + 8 = 24, and `height` 24 / 19 = 1.263, unchanged because `spaceHeight` is a percent. A fixed `spaceHeight: 8` at a scale of 2.0 gives (32 + 8) / 38 = 1.053.

Steps 6 to 8 call `textScaler.scale` on each value separately. A nonlinear scaler (Android 14 and later) does not scale 19 by the same ratio as 16, so the resolver never multiplies by a precomputed ratio.

`FontColor` maps to theme colors as mangmee does: `brandPrimary`, `brandSecondary`, and `brandTertiary` to `brandPrimaryText`, `brandSecondaryText`, and `brandTertiaryText`; `primary`, `primaryOnColor`, `primaryInverse`, `secondary`, `secondaryInverse`, `tertiary`, and `tertiaryInverse` to the `text*` field of the same name.

## 8. Builder API

```dart
// lib/src/components/common/style/text_style_builder.dart
@immutable
class StratumTextStyle {
  // Type (static entry points)
  static StratumTextStyle get header;
  static StratumTextStyle get paragraph;
  static StratumTextStyle get number;
  static StratumTextStyle get code;
  static StratumTextStyle get body;
  static StratumTextStyle get table;
  static StratumTextStyle type(FontType type);

  // Size (default s16)
  StratumTextStyle get s10; // s12, s14, s16, s18, s20, s24, s36, s48, s56
  StratumTextStyle size(double size);

  // Weight (default: the type's yaml weight)
  StratumTextStyle get light;     // w300
  StratumTextStyle get regular;   // w400
  StratumTextStyle get medium;    // w500
  StratumTextStyle get semiBold;  // w600
  StratumTextStyle get bold;      // w700
  StratumTextStyle weight(FontWeight weight);

  // Variant and style
  StratumTextStyle get mono;
  StratumTextStyle get italic;
  StratumTextStyle get underline;
  StratumTextStyle get lineThrough;
  StratumTextStyle decoration(TextDecoration decoration);
  StratumTextStyle shadows(List<Shadow> shadows);

  // Color (default FontColor.primary)
  StratumTextStyle get colorPrimary; // colorPrimaryInverse, colorPrimaryOnColor,
  // colorSecondary, colorSecondaryInverse, colorTertiary, colorTertiaryInverse,
  // colorBrandPrimary, colorBrandSecondary, colorBrandTertiary
  StratumTextStyle fontColor(FontColor color);
  StratumTextStyle color(Color color);

  // Environment overrides (default: read from context)
  StratumTextStyle themeMode(ThemeMode mode);
  StratumTextStyle get darkTheme;
  StratumTextStyle get lightTheme;
  StratumTextStyle locale(Locale locale);
  StratumTextStyle windowSize(WindowSize windowSize);
  StratumTextStyle textScaler(TextScaler textScaler);

  TextStyle build(BuildContext context);
}
```

Every getter and method returns a new instance. `==` and `hashCode` cover every field; `shadows` compares by list content.

The theme-mode shortcuts are `darkTheme` and `lightTheme`, as in mangmee, because `light` is the w300 weight.

`build(context)` reads, in order: the theme from `StratumThemeApplication.of(context, themeMode: recipe.themeMode)`; the locale from the override, else `Localizations.maybeLocaleOf(context)`, else `View.of(context).platformDispatcher.locale`; the window size from the override, else `WindowSizeScope.maybeOf(context)` (null gives no window scale); the text scaler from the override, else `MediaQuery.maybeTextScalerOf(context)`, else `TextScaler.noScaling`. It then calls `TypographyResolver.resolve`.

Usage:

```dart
Text('ราคา', style: StratumTextStyle.header.s24.build(context));

Text('฿1,250.00',
    style: StratumTextStyle.number.s36.mono.colorBrandPrimary.build(context));

final caption = StratumTextStyle.body.s12.colorTertiary;
Text('a', style: caption.medium.build(context)); // medium
Text('b', style: caption.build(context));        // regular; caption is unchanged
```

Intentional differences from mangmee: no `header1` to `header5` presets (Figma has no H1 to H5 names); `body` replaces `FontType.ui`; `header` takes its weight from yaml (600) instead of forcing bold; no `thin` (Figma has none and many fonts lack w200); immutable instead of a mutable cascade.

`.mono` on `code` changes nothing. `.mono` on `table` swaps to the mono font and keeps tabular figures.

## 9. Caching and rebuilds

- **Cache:** `TypographyResolver` keeps one cache per `StratumThemeData` instance in a static `Expando`, keyed by the recipe, the locale, the window size, and the text scaler. A hit returns the same `TextStyle` instance. A theme swap drops the old cache with the old theme. The cache holds at most 512 entries and clears itself when full. A `TextScaler` without `==` only misses the cache; the output stays correct.
- **Rebuild scope:** `WindowSizeScope` notifies only when the window crosses a breakpoint, so resizing inside one breakpoint rebuilds no text. The builder reads `MediaQuery.maybeTextScalerOf`, which depends on the text scale aspect only, so keyboard insets and other `MediaQuery` changes do not rebuild text.

## 10. Edge cases

| Case | Behavior |
|---|---|
| A `Text` sets its own `textScaler` | `height` and `letterSpacing` assume the `MediaQuery` scaler; pass the same scaler through `.textScaler(...)`. Documented on the class. |
| No `WindowSizeScope` above | No window scale; no throw. |
| No `Localizations` above | The platform locale. |
| The type has no font in any tag | Cannot happen after a successful parse (section 5 requires `families.default` to cover every type). |
| `.mono` with no mono font anywhere | The non-mono primary font plus one debug warning. |
| A requested family is not bundled | Flutter falls back to the platform font. Bundling is sub-project 4. |
| `bigDesktop` with fixed `spaceHeight` | The gap shrinks by the window scale (Q1); `height` can drop near the glyph height. Covered by the manual Thai check. |
| Fallback glyphs | Use the primary font's size and tracking (Q5, A1). |

## 11. Testing

Test-first. Unit tests use no widgets; widget tests count builds.

| Unit | Tests |
|---|---|
| `StratumDimension` | Parses `2`, `0.5`, `"50%"`, `"-12.5%"`; rejects `"8px"`, `"abc"`, `null`; `resolve(of:)` for both kinds. |
| `StratumTypography.fromYaml` | The default theme file parses. Each error kind in section 5 is reported with its path, and several errors arrive together. `extends` merges sizes and walks the family lookup. Unknown keys warn. `th-TH` normalizes to `th_TH`. |
| `TypographyResolver` | The section 7 example at scales 1.0 and 2.0; fixed against percent `spaceHeight`; nearest size and its tie rule; the tag chain; the mono chain; the fallback list; `tabularFigures`; default weight; `letterSpacing` based before `adjustSize`; a fake nonlinear `TextScaler`; a cache hit returns the identical instance; a different window size gives a different instance; the 513th entry clears the cache. |
| Figma conformance | For each Figma style in section 15: scale 1, `mobile`, `adjustSize` 0 gives `fontSize == size` and `height × fontSize == lineHeight`. `TextPainter.computeLineMetrics()` confirms the line height for one style per type. |
| `StratumTextStyle` | A stored builder is not mutated by a later getter; `==` and `hashCode`. |
| `build(context)` widget tests | A `Localizations` locale change switches the family. A resize inside one breakpoint causes no rebuild (build counter). Crossing a breakpoint rebuilds with a new `fontSize`. A `MediaQuery.textScaler` change gives a new `height`. No `WindowSizeScope` gives no window scale and no throw. `.themeMode()`, `.locale()`, and `.windowSize()` overrides apply. |
| `WindowSizeScope.maybeOf` | Returns null without a scope and registers a dependency with one. |

Manual check: `example/lib/typography_demo.dart` renders every type and size with Thai stacked marks ("ปู่ นี้ ฟุ้ง ญี่ปุ่น") and switches window size and text scale (100%, 150%, 200%). The owner runs it on macOS and Chrome. It loads `packages/stratum_ui/assets/themes/default/theme.yaml`.

Golden tests are deferred: their output depends on the platform and installed fonts, and fonts are not bundled until sub-project 4.

## 12. Verification

- `flutter test` passes (the 572 existing tests plus the new ones).
- `flutter analyze` reports no new issue in `lib`, `test`, and `example`.
- `dart format` leaves the touched files unchanged.
- The owner's manual Thai check on `typography_demo.dart` passes, or its findings are recorded.

## 13. Out of scope

| Item | Goes to |
|---|---|
| Whole-file theme.yaml parser, token aliases, merge over `default` | Sub-project 2 |
| Unquoted `#FFFFFF` colors in `theme.yaml` parse as YAML comments, so every color is null today | Sub-project 2 |
| App-extensible palettes and colors beyond `FontColor`; Material `ThemeData.textTheme` mapping; `copyWith` missing `physics` (`theme_data.dart:109`) | Sub-project 3 |
| Font file bundling and runtime `FontLoader`; per-theme family namespacing | Sub-project 4 |
| `StratumThemeApplication.updateShouldNotify` compares only `lightTheme` (`theme_application.dart:68`) | Sub-project 4 |
| Script-run splitting (A2) | Later, through a `scripts:` field |
| Golden tests | After sub-project 4 bundles fonts |

## 14. Pre-implementation lookups

These fill default-theme data only; the code and tests do not wait for them.

| ID | Question | Current assumption | Affects |
|---|---|---|---|
| L1 | Are Figma `letterSpacing` values percent or px? Raw values: header/56 −2.4, header/12 1.8, body/16 −1, body/14 −0.6. | Percent. The values track the Inter Dynamic Metrics curve in percent (16 px about −1.1%, 56 px about −2.2%); the curve constants were recalled from memory and not checked against Inter's documentation. | `letterSpacing` values in `assets/themes/default/theme.yaml`; px would make them bare numbers. |
| L2 | Which Thai font does the default theme ship? Figma's Thai sample frames (node `3480:6700`) use the Inter styles, which have no Thai glyphs. | None: no `th` entry, so Thai uses the platform font. | `families.th` and `fonts` in the default theme. |
| L3 | What does the Figma frame "Font calculate" (node `3530:17609`, "Formula = font-size x 1.375") compute? | Unknown. | Possibly Thai `adjustSize` or `spaceHeight` values. |

## 15. Evidence

- **Figma text styles** (file `wjRe9eL7863nMRfFats8jZ`, node `56740:3360`, read 2026-10-02 with `get_variable_defs`), as size / lineHeight / weight / letterSpacing:
  - header (Inter): 56/72/600/−2.4, 36/48/600/−2, 24/34/600/−1.4, 20/28/600/−1.2, 18/24/600/−1, 14/20/600/0.6, 12/20/600/1.8
  - paragraph (Inter): 20/32/−1, 18/30/−1, 16/26/0, 14/24/0.2, each in regular 400 and semi bold 600
  - body (Inter): 18/28/−1, 16/24/−1, 14/24/−0.6, 12/16/0.5, 10/16/0.8, each in regular, medium, and semi bold
  - table (Inter, body metrics): `body*/NN-table-regular` for 18, 16, 14, 12
  - number (Geist, 600): 36/48, 24/32, 18/24, 16/24, 14/24, 12/16, all letterSpacing 0; `number/10-mono` is Geist Mono 10/16
  - code (Roboto Mono, 400): 18/24, 16/24, 14/24, 12/16, all letterSpacing 0
- **Dart `yaml` parsing** (probe run with the project's `yaml` package on 2026-10-02): `a: #FFFFFF` gives `null`; `"#FFFFFF"`, `1.0%`, `50%`, `-12.5%`, and `-1%` give `String`; `2` gives `int`; `0.5` gives `double`.
- **Flutter text scaling** (`packages/flutter/lib/src/painting/text_style.dart`, `getTextStyle`, lines 1346 to 1366 in the local SDK): only `fontSize` passes through `textScaler.scale`; `letterSpacing` and `height` pass unchanged.
- **Existing code**: `WindowSizeScope` notifies only on a breakpoint change (`window_size_scope.dart`, `updateShouldNotify`); `StratumFontData` is referenced only by `theme_data.dart`.
