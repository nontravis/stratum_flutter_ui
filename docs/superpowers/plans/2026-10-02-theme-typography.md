# Theme Typography Implementation Plan

> **For agentic workers:** execute per the repository's execute rule; with none, run superpowers:subagent-driven-development in Dependency-table order. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give Stratum one typography system driven by `theme.yaml`: `StratumDimension` for fixed or percent lengths, `StratumTypography.fromYaml` for the `typography:` subtree, a pure and cached `TypographyResolver`, and the immutable `StratumTextStyle` that widgets turn into a `TextStyle` with `.build(context)`.

**Architecture:** Milestone M1 builds the data side. Task 1 adds the value type, Task 2 the enum and scope changes, and Task 3 the parser, which reads the layered yaml (fonts, family sets per locale tag, a window scale, and types with `extends`) into immutable models, collects every problem with its yaml path into one `StratumThemeFormatException`, and moves the default theme to the new shape with its asset folder declared. Milestone M2 builds the text side. Task 4 adds the immutable recipe; Task 5 the nine-step resolver with one `Expando` cache per theme, the `StratumThemeData.typography` field, and the Figma conformance test; Task 6 `build(context)`, which depends only on `Localizations`, `WindowSizeScope.maybeOf`, and `MediaQuery.maybeTextScalerOf`; and Task 7 the demo for the owner's manual Thai check.

**Tech Stack:** Flutter 3.47.3, Dart 3.13.3, `flutter_test`, `yaml` ^3.1.4, very_good_analysis 11 (library), `flutter_lints` (example).

**Spec:** `docs/superpowers/specs/2026-10-02-theme-typography-design.md`, all 15 sections; the tasks implement sections 4 to 12, section 13 stays out of scope, and the section 14 lookups change default-theme data only. Project memory: `profile/memory/project_stratum_ui_theme_system.md` in the NTD OS root, sections "Sub-project 1 rulings (typography)" and "Sub-project 1 spec written (05f978e)". PRD user stories in scope: none (`docs/prds/features/` holds no typography story).

**Anchor base:** master 7ddde99. Every `path:line` below cites that commit. The cited files are unchanged since the spec commit 05f978e: `git diff --stat 05f978e..7ddde99` lists only layout files, `focus_spread.dart`, and `scroll_frame_test.dart`.

**Preconditions:**
- `flutter test --no-pub` passes 596 tests on the anchor, and from `example/`, `flutter test --no-pub test/` passes 107 tests (verified in a clean worktree on 7ddde99).
- `flutter analyze --no-pub lib test example` reports 74 issues and no error on the anchor; one of them is the `unused_import` warning in `lib/src/themes/font_data.dart`, which Task 3 removes.
- The owner's work in progress is the set Global Constraints lists, and `git diff HEAD -- lib/src/components/common/style/style.dart pubspec.yaml` shows exactly two added lines, `export 'text_style_builder.dart';` and `  dotted_border: ^3.1.0`, staged or not.
- The owner has approved committing the staged rename `assets/themes/example.yaml -> assets/themes/default/theme.yaml` in Task 3 (pending owner approval; see Global Constraints).

This plan was verified in a scratch worktree on 7ddde99 that reproduced the owner's overlapping work in progress (the staged rename, the staged empty `text_style_builder.dart`, the staged export line in `style.dart`, the staged `dotted_border` line, and one more staged file): every task's code compiled, each RED step failed as stated, each GREEN step passed, and each commit step ran as written and left the owner's staged files staged. After Task 7 the library suite passed 756 tests, `flutter analyze --no-pub lib test example` reported 73 issues and no error (the anchor's 74 minus the `font_data.dart` warning), and the example suite passed 109 tests. The manual Thai check of spec section 11 was not run.

## Global Constraints

- Work in the main working tree on `master`. The owner's work in progress overlaps this plan in four paths, handled exactly this way:
  - `lib/src/components/common/style/text_style_builder.dart`: the owner staged an empty placeholder for this work. Task 4 writes the file whole and commits it.
  - `lib/src/components/common/style/style.dart`: the owner's diff is exactly `export 'text_style_builder.dart';`. Task 4 commits the file as it stands.
  - `pubspec.yaml`: the owner's `dotted_border` line stays out of every commit. Task 3 commits only the assets hunk, through a temporary index and the patch printed in Task 3 Step 5, then applies the same patch to the real index with `git apply --cached`. Never pass `pubspec.yaml` to `git add` or `git commit`: both take the owner's line too.
  - `assets/themes/default/theme.yaml`: the owner's staged rename from `assets/themes/example.yaml`. Task 3 commits both paths. Pending owner approval: confirm before Task 3 Step 7 that the rename may land in that commit.
- Every other piece of the owner's work in progress stays out of every commit: `lib/src/components/common/common.dart`, `lib/stratum_ui.dart`, `example/pubspec.lock`, `lib/src/components/common/utility/`, `lib/src/components/common/page/` (and `pages/` if it reappears), `lib/src/components/common/splash_screen.dart`, and the `swiftpm` folders under `example/macos/`. Never stage, unstage, stash, reset, check out, or format them.
- Commit with explicit paths only: `git add -- <new paths>`, then `git commit -F - -- <paths>` with the message in a heredoc. A commit with paths takes the working-tree content of those paths and leaves every other staged file staged. Write each path literally; zsh does not word-split a variable into several paths. Conventional Commits with a scope and a prose body; no `Co-Authored-By` line and no AI attribution.
- Constructors use the `new` form: `const new(` and `new(` for the unnamed constructor, `new(this.value);` in an enum (`const` there trips `unnecessary_const_in_enum_constructor`), `const new _(` for a private named constructor, `const factory fixed(double px) = FixedDimension;`, and `factory parse(Object? value)`. `unnecessary_type_name_in_constructor` flags the `ClassName(` form in `lib/` and `test/`. `example/` keeps the classic form, as `example/lib/focus_demo.dart` does.
- Lints: very_good_analysis 11 in `lib/` and `test/` (package imports, sorted directives, constructors first, single quotes, lines of at most 80 columns, `specify_nonobvious_property_types`, `use_null_aware_elements`); `flutter_lints` in `example/`. Library files and their tests import the barrel `package:stratum_ui/src/src.dart`; `test/src/components/common/fakes/fake_stratum_theme.dart` and `test/src/components/common/responsive/window_size_scope_test.dart` keep their narrow imports. An `example/` file that imports `package:stratum_ui/src/src.dart` starts with `// ignore_for_file: implementation_imports`.
- Every file this plan writes whole is `dart format` clean as written; paste code blocks unchanged. Never run `dart format` on `lib/src/themes/theme_data.dart`: it carries formatting drift from before this plan, and Task 5 edits four of its lines only.
- Run tests with `flutter test --no-pub <path>` and the analyzer with `flutter analyze --no-pub <paths>`, in the foreground. Run each RED step one file at a time: a compile error in one file fails every file in the same run. A command likely to take over a minute writes to a log under `build/` (git-ignored) and the step reads its tail.
- Spec values, verbatim. Section 3: `size = base + scaleByWindowSize`; `fontSize = size + adjustSize`; `lineBox = base + spaceHeight`; "`scaleByWindowSize` and `adjustSize` resolve against `base`; `spaceHeight` against `scale(base)`; `letterSpacing` against `scale(size)`, before `adjustSize`". Section 5: a dimension string matches `^-?\d+(\.\d+)?%$`; `th-TH` "is accepted and normalized to `th_TH`"; error lines such as `typography.types.table.extends: cycle table -> body -> table`. Section 7: the tag chain is "`<lang>_<country>` when a country exists, then `<lang>`, then `default`"; `lineBox = scaledBase + spaceHeight.resolve(of: scaledBase)`; `height = lineBox / textScaler.scale(fontSize)`; `letterSpacing.resolve(of: textScaler.scale(size))`; `leadingDistribution: TextLeadingDistribution.even`; "the resolver never multiplies by a precomputed ratio". Section 9: "The cache holds at most 512 entries and clears itself when full."
- Plan choices where the spec is silent (these are not owner rulings; the reviewer confirms or overrules them before Task 3):
  1. Every `FontType` needs a `types` entry (`typography.types.code: required`), reading section 5's "a `weight` and at least one size on every type" as every value of the enum, so the resolver never meets a missing type.
  2. A cycle reports at every type in it: the spec's `table` line arrives with `typography.types.body.extends: cycle body -> table -> body`.
  3. Inside each locale tag, the font lookup and the mono lookup walk `extends`, for the fallback list as well as for the primary font.
  4. `.mono` on `code` is ignored entirely: no mono lookup and no mono font in the fallback list.
  5. `fontFamilyFallback` is `null` when the list is empty.
  6. Warnings go through `debugPrint` under `kDebugMode`, as `Stratum theme: skipped unknown key <path>`, `Stratum theme: <type> has no size <size>; using <nearest>`, and `Stratum theme: no mono font for <type>; using <family>`; the last two print once per process.
  7. A locale tag is `default` or matches `^[a-z]{2,3}([-_][A-Z]{2})?$`; anything else is an error.
  8. With no font defined, font references are not checked (the `fonts` error covers them), and a family entry that names a type counts toward `families.default` coverage even when its font key is wrong, so one mistake gives one error.
  9. `FixedDimension` and `PercentDimension` extend the sealed `StratumDimension`, which has a `const new()`, as `StratumWebViewSource` in `lib/src/components/common/web_view/stratum_web_view_types.dart` does; the spec sketch writes `implements`, and the public API is the same.
- `.worktrees/` and `build/` are git-ignored; never stage them.

## Review Focus

- A `Text` that builds a `StratumTextStyle` with no `StratumThemeApplication` above it: a person expects a `FlutterError` that names `StratumThemeApplication`, not a null error deep in the resolver. Pinned in Task 6 ("without a StratumThemeApplication it throws a FlutterError").
- A platform or app locale with an empty country code, `Locale('th', '')`: a person expects Thai fonts through the `th` tag, not a lookup of a `th_` tag. Pinned in Task 5 ("an empty country code counts as no country").
- A custom size beyond the sizes a type defines, such as `.size(4)` or `.size(100)` on body: a person expects the metrics of the smallest or largest size, with a percent `spaceHeight` resolved on the custom size. Pinned in Task 5 ("a custom size beyond either end takes the end size").
- A family entry in the `{ font, mono }` form that leaves out `font`: a person expects one error at `...number.font`, not a crash or a silently missing font. Pinned in Task 3 ("reports a family entry with a mono but no font").
- A type that extends itself, `table: { extends: table }`: a person expects the cycle error `cycle table -> table` alone, not a hang or a second error about its fonts. Pinned in Task 3 ("reports a type that extends itself").

## File map

| File | Task | Responsibility |
|---|---|---|
| `lib/src/themes/typography/dimension.dart`, `test/src/themes/typography/dimension_test.dart` | 1 | `StratumDimension`, `FixedDimension`, `PercentDimension` |
| `lib/src/themes/themes.dart` | 1, 3, 5 | Exports of `dimension.dart` (1), `typography.dart` (3), `resolver.dart` (5) |
| `lib/src/themes/constant/font_type.dart`, `font_size.dart`, `test/src/themes/constant/font_type_test.dart`, `font_size_test.dart` | 2 | `FontType` without `numberMono`; `FontSize` without `custom`, with `value` |
| `lib/src/components/common/responsive/window_size_scope.dart`, its test | 2 | `WindowSizeScope.maybeOf` |
| `lib/src/themes/font_data.dart`, `test/src/themes/font_data_test.dart` | 3 | `StratumFontData` with `family`, `package`, `adjustSize`, `qualifiedFamily` |
| `lib/src/themes/typography/typography.dart`, `test/src/themes/typography/typography_test.dart` | 3 | Models, `StratumTypography.fromYaml`, `StratumThemeFormatException` |
| `assets/themes/default/theme.yaml` (renamed from `assets/themes/example.yaml`), `pubspec.yaml` (assets hunk only) | 3 | Default typography in the layered shape; the folder declared |
| `lib/src/components/common/style/text_style_builder.dart`, `style.dart`, `test/src/components/common/style/text_style_builder_test.dart` | 4, 6 | The recipe (4); `build(context)` (6) |
| `lib/src/themes/typography/resolver.dart`, `test/src/themes/typography/resolver_test.dart` | 5 | `TypographyResolver` and its cache |
| `lib/src/themes/theme_data.dart`, `test/src/themes/theme_data_test.dart` | 5 | `typography` replaces `fonts` |
| `test/src/components/common/fakes/fake_stratum_theme.dart` | 5 | `typography` and the ten text colors on the fake theme |
| `test/src/themes/typography/figma_conformance_test.dart` | 5 | Every Figma style of spec section 15 |
| `test/src/components/common/style/text_style_build_test.dart` | 6 | `build(context)` widget tests |
| `example/lib/typography_demo.dart`, `example/test/typography_demo_test.dart` | 7 | The manual-check page and its smoke test |

---

## Milestone M1: Value type, enums, and the yaml model

### Task 1 (M1-T1): StratumDimension

**Agent:** general-purpose
**Implements:** Q3, value syntax, value type name

**Files:**
- Create: `lib/src/themes/typography/dimension.dart`
- Create: `test/src/themes/typography/dimension_test.dart`
- Modify: `lib/src/themes/themes.dart` (whole file, nine lines)

**Interfaces:**
- Consumes: nothing new.
- Produces: `sealed class StratumDimension` with `const factory fixed(double px)`, `const factory percent(double ratio)`, `factory parse(Object? value)` (throws `FormatException('expected a number or "N%", got <value>')`, a string value in double quotes), and `double resolve({required double of})`; `final class FixedDimension` (`px`) and `final class PercentDimension` (`ratio`), each with `==`, `hashCode`, and `toString`.

- [ ] **Step 1: Write the failing test**

Create `test/src/themes/typography/dimension_test.dart` with:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

void main() {
  group('StratumDimension.parse', () {
    test('reads an int as fixed pixels', () {
      expect(StratumDimension.parse(2), const StratumDimension.fixed(2));
    });

    test('reads a double as fixed pixels', () {
      expect(StratumDimension.parse(0.5), const StratumDimension.fixed(0.5));
    });

    test('reads "50%" as a ratio of 0.5', () {
      expect(
        StratumDimension.parse('50%'),
        const StratumDimension.percent(0.5),
      );
    });

    test('reads "-12.5%" as a ratio of -0.125', () {
      expect(
        StratumDimension.parse('-12.5%'),
        const StratumDimension.percent(-0.125),
      );
    });

    test('rejects "8px" and quotes it in the message', () {
      expect(
        () => StratumDimension.parse('8px'),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'expected a number or "N%", got "8px"',
          ),
        ),
      );
    });

    test('rejects "abc"', () {
      expect(
        () => StratumDimension.parse('abc'),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects null', () {
      expect(
        () => StratumDimension.parse(null),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'expected a number or "N%", got null',
          ),
        ),
      );
    });
  });

  group('StratumDimension.resolve', () {
    test('a fixed value keeps its pixels whatever the base', () {
      expect(const StratumDimension.fixed(8).resolve(of: 32), 8);
    });

    test('a percent value is that share of the base', () {
      expect(const StratumDimension.percent(0.5).resolve(of: 32), 16);
      expect(const StratumDimension.percent(-0.01).resolve(of: 34), -0.34);
    });
  });

  group('StratumDimension equality', () {
    test('the same kind and number are equal with equal hash codes', () {
      expect(
        StratumDimension.parse('50%'),
        const StratumDimension.percent(0.5),
      );
      expect(
        StratumDimension.parse('50%').hashCode,
        const StratumDimension.percent(0.5).hashCode,
      );
    });

    test('a fixed and a percent value of the same number differ', () {
      expect(
        const StratumDimension.fixed(0.5),
        isNot(const StratumDimension.percent(0.5)),
      );
    });
  });
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `flutter test --no-pub test/src/themes/typography/dimension_test.dart`
Expected: FAIL to compile with `Error: Undefined name 'StratumDimension'.`

- [ ] **Step 3: Write the implementation**

Create `lib/src/themes/typography/dimension.dart` with:

```dart
import 'package:stratum_ui/src/src.dart';

/// A theme length: a fixed number of logical pixels, or a percent of a base
/// length that the caller supplies when it resolves the value.
///
/// In `theme.yaml` a bare number is fixed (`8`) and a string `"N%"` is a
/// percent (`"50%"`, `"-1.2%"`).
@immutable
sealed class StratumDimension {
  const new();

  /// A length of [px] logical pixels.
  const factory fixed(double px) = FixedDimension;

  /// A length of [ratio] times the base it resolves against; `0.5` is 50%.
  const factory percent(double ratio) = PercentDimension;

  /// Reads a `theme.yaml` value: a number gives [StratumDimension.fixed]; a
  /// string `"N%"` gives [StratumDimension.percent] of `N / 100`.
  ///
  /// Throws a [FormatException] for anything else.
  factory parse(Object? value) {
    if (value is num) return StratumDimension.fixed(value.toDouble());
    if (value is String && _percentPattern.hasMatch(value)) {
      final number = double.parse(value.substring(0, value.length - 1));
      return StratumDimension.percent(number / 100);
    }
    final shown = value is String ? '"$value"' : '$value';
    throw FormatException('expected a number or "N%", got $shown');
  }

  static final _percentPattern = RegExp(r'^-?\d+(\.\d+)?%$');

  /// The length in logical pixels; [of] is the base a percent value
  /// resolves against.
  double resolve({required double of});
}

/// A [StratumDimension] of [px] logical pixels.
final class FixedDimension extends StratumDimension {
  const new(this.px);

  /// The length in logical pixels.
  final double px;

  @override
  double resolve({required double of}) => px;

  @override
  bool operator ==(Object other) => other is FixedDimension && other.px == px;

  @override
  int get hashCode => Object.hash(FixedDimension, px);

  @override
  String toString() => 'StratumDimension.fixed($px)';
}

/// A [StratumDimension] of [ratio] times the base it resolves against.
final class PercentDimension extends StratumDimension {
  const new(this.ratio);

  /// The share of the base; `0.5` is 50%.
  final double ratio;

  @override
  double resolve({required double of}) => ratio * of;

  @override
  bool operator ==(Object other) =>
      other is PercentDimension && other.ratio == ratio;

  @override
  int get hashCode => Object.hash(PercentDimension, ratio);

  @override
  String toString() => 'StratumDimension.percent($ratio)';
}
```

Replace all of `lib/src/themes/themes.dart` with:

```dart
export 'behavior/behavior.dart';
export 'color/color.dart';
export 'constant/constant.dart';
export 'font_data.dart';
export 'styles/styles.dart';
export 'theme_application.dart';
export 'theme_color.dart';
export 'theme_data.dart';
export 'typography/dimension.dart';
```

- [ ] **Step 4: Run the test, the analyzer, and the formatter**

Run: `flutter test --no-pub test/src/themes/typography/dimension_test.dart`
Expected: PASS, `+11: All tests passed!`

Run: `flutter analyze --no-pub lib/src/themes/typography lib/src/themes/themes.dart test/src/themes/typography`
Expected: `No issues found!`

Run: `dart format --output=none --set-exit-if-changed lib/src/themes/typography/dimension.dart lib/src/themes/themes.dart test/src/themes/typography/dimension_test.dart`
Expected: `Formatted 3 files (0 changed)`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add -- lib/src/themes/typography/dimension.dart test/src/themes/typography/dimension_test.dart
git commit -F - -- lib/src/themes/typography/dimension.dart lib/src/themes/themes.dart test/src/themes/typography/dimension_test.dart <<'EOF'
feat(theme): add StratumDimension for fixed and percent theme lengths

A theme length is either a fixed number of logical pixels or a percent
of a base that the caller supplies when it resolves the value.
theme.yaml writes a bare number for the first and an "N%" string for
the second; parse rejects anything else with a FormatException that
quotes the value, so the typography parser can report it with its path.
EOF
```

### Task 2 (M1-T2): FontType, FontSize, and WindowSizeScope.maybeOf

**Agent:** general-purpose
**Implements:** T2, T5, T6, Q4

**Files:**
- Modify: `lib/src/themes/constant/font_type.dart:1` (whole file)
- Modify: `lib/src/themes/constant/font_size.dart:1` (whole file)
- Modify: `lib/src/components/common/responsive/window_size_scope.dart:15-27` (`of`, plus the new `maybeOf`)
- Create: `test/src/themes/constant/font_type_test.dart`, `test/src/themes/constant/font_size_test.dart`
- Modify: `test/src/components/common/responsive/window_size_scope_test.dart` (two tests at the end)

**Interfaces:**
- Consumes: nothing new.
- Produces: `enum FontType { header, paragraph, number, code, body, table }`; `enum FontSize { s10, s12, s14, s16, s18, s20, s24, s36, s48, s56 }` with `final double value`; `static WindowSize? WindowSizeScope.maybeOf(BuildContext context)`, which registers the same dependency as `of`.

- [ ] **Step 1: Write the failing tests**

Create `test/src/themes/constant/font_size_test.dart` with:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

void main() {
  test('every size has its value in logical pixels and no custom entry', () {
    expect(
      {for (final size in FontSize.values) size.name: size.value},
      {
        's10': 10,
        's12': 12,
        's14': 14,
        's16': 16,
        's18': 18,
        's20': 20,
        's24': 24,
        's36': 36,
        's48': 48,
        's56': 56,
      },
    );
  });
}
```

Create `test/src/themes/constant/font_type_test.dart` with:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

void main() {
  test('lists the six text roles; mono is a modifier, not a type', () {
    expect(
      [for (final type in FontType.values) type.name],
      ['header', 'paragraph', 'number', 'code', 'body', 'table'],
    );
  });
}
```

In `test/src/components/common/responsive/window_size_scope_test.dart`, replace:

```dart
    expect(dependentBuilds, 0);
  });
}
```

with:

```dart
    expect(dependentBuilds, 0);
  });

  testWidgets('maybeOf returns null without a WindowSizeScope ancestor', (
    tester,
  ) async {
    final seen = <WindowSize?>[];

    await tester.pumpWidget(
      Builder(
        builder: (context) {
          seen.add(WindowSizeScope.maybeOf(context));
          return const SizedBox();
        },
      ),
    );

    expect(seen, [null]);
  });

  testWidgets('maybeOf rebuilds its caller when a breakpoint is crossed', (
    tester,
  ) async {
    setWindowSize(tester, const Size(400, 800));
    addTearDown(tester.view.reset);
    final seen = <WindowSize?>[];

    await tester.pumpWidget(
      WindowSizeScope(
        child: Builder(
          builder: (context) {
            seen.add(WindowSizeScope.maybeOf(context));
            return const SizedBox();
          },
        ),
      ),
    );
    setWindowSize(tester, const Size(500, 800));
    await tester.pump();
    setWindowSize(tester, const Size(1300, 800));
    await tester.pump();

    expect(seen, [WindowSize.mobile, WindowSize.desktop]);
  });
}
```

- [ ] **Step 2: Run each test file to see it fail**

Run: `flutter test --no-pub test/src/themes/constant/font_size_test.dart`
Expected: FAIL to compile with `Error: The getter 'value' isn't defined for the type 'FontSize'.`

Run: `flutter test --no-pub test/src/themes/constant/font_type_test.dart`
Expected: FAIL; `Actual: ['header', 'paragraph', 'number', 'numberMono', 'code', 'body', 'table']`.

Run: `flutter test --no-pub test/src/components/common/responsive/window_size_scope_test.dart`
Expected: FAIL to compile with `Error: Member not found: 'WindowSizeScope.maybeOf'.`

- [ ] **Step 3: Write the implementation**

Replace all of `lib/src/themes/constant/font_type.dart` with:

```dart
/// The text roles of the theme's typography. Each one has its own weight,
/// sizes, and fonts in `theme.yaml`; mono is the `.mono` modifier of
/// `StratumTextStyle`, not a type.
enum FontType { header, paragraph, number, code, body, table }
```

Replace all of `lib/src/themes/constant/font_size.dart` with:

```dart
/// The named text sizes of the theme's typography.
enum FontSize {
  s10(10),
  s12(12),
  s14(14),
  s16(16),
  s18(18),
  s20(20),
  s24(24),
  s36(36),
  s48(48),
  s56(56);

  new(this.value);

  /// The size in logical pixels.
  final double value;
}
```

In `lib/src/components/common/responsive/window_size_scope.dart`, replace:

```dart
  static WindowSize of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_WindowSizeInherited>();
    if (scope == null) {
      throw FlutterError(
        'No WindowSizeScope found in context.\n'
        'Wrap the app with WindowSizeScope, e.g. '
        'MaterialApp(builder: (context, child) => '
        'WindowSizeScope(child: child!)).',
      );
    }
    return scope.windowSize;
  }

```

with:

```dart
  static WindowSize of(BuildContext context) {
    final windowSize = maybeOf(context);
    if (windowSize == null) {
      throw FlutterError(
        'No WindowSizeScope found in context.\n'
        'Wrap the app with WindowSizeScope, e.g. '
        'MaterialApp(builder: (context, child) => '
        'WindowSizeScope(child: child!)).',
      );
    }
    return windowSize;
  }

  /// The [WindowSize] of the nearest [WindowSizeScope], or null when none is
  /// above [context].
  ///
  /// Registers the same dependency as [of]: the caller rebuilds only when
  /// the window crosses a breakpoint.
  static WindowSize? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_WindowSizeInherited>()
      ?.windowSize;

```

- [ ] **Step 4: Run the tests, the analyzer, and the formatter**

Run: `flutter test --no-pub test/src/themes/constant/font_size_test.dart`
Expected: PASS, `+1: All tests passed!`

Run: `flutter test --no-pub test/src/themes/constant/font_type_test.dart`
Expected: PASS, `+1: All tests passed!`

Run: `flutter test --no-pub test/src/components/common/responsive/window_size_scope_test.dart`
Expected: PASS, `+6: All tests passed!`

Run: `flutter analyze --no-pub lib/src/themes/constant/font_type.dart lib/src/themes/constant/font_size.dart lib/src/components/common/responsive/window_size_scope.dart test/src/themes/constant test/src/components/common/responsive/window_size_scope_test.dart`
Expected: `No issues found!`

Run: `dart format --output=none --set-exit-if-changed lib/src/themes/constant/font_type.dart lib/src/themes/constant/font_size.dart lib/src/components/common/responsive/window_size_scope.dart test/src/themes/constant/font_size_test.dart test/src/themes/constant/font_type_test.dart test/src/components/common/responsive/window_size_scope_test.dart`
Expected: `Formatted 6 files (0 changed)`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add -- test/src/themes/constant/font_size_test.dart test/src/themes/constant/font_type_test.dart
git commit -F - -- lib/src/themes/constant/font_type.dart lib/src/themes/constant/font_size.dart lib/src/components/common/responsive/window_size_scope.dart test/src/themes/constant/font_size_test.dart test/src/themes/constant/font_type_test.dart test/src/components/common/responsive/window_size_scope_test.dart <<'EOF'
feat(theme): make mono a modifier, give FontSize its value, add maybeOf

FontType drops numberMono, so mono becomes a modifier that applies to
every type, and table stays the path to tabular figures. FontSize drops
custom and carries its size in logical pixels; a custom size stays a
double on the text style. WindowSizeScope.maybeOf returns null without a
scope and registers the same dependency as of, so text can skip the
window scale when no scope is above it.
EOF
```

### Task 3 (M1-T3): StratumTypography.fromYaml and the default theme typography

**Agent:** general-purpose
**Implements:** T3, T4, T7, Q6, parse scope, errors, default theme `spaceHeight`

**Files:**
- Modify: `lib/src/themes/font_data.dart` (whole file; drops the `unused_import` warning)
- Create: `lib/src/themes/typography/typography.dart`
- Modify: `lib/src/themes/themes.dart` (whole file)
- Create: `test/src/themes/font_data_test.dart`, `test/src/themes/typography/typography_test.dart`
- Modify: `assets/themes/default/theme.yaml`, lines 142 to 242 (the `typography:` subtree; the file is the owner's staged rename of `assets/themes/example.yaml`, whose lines `assets/themes/example.yaml:142-242` on the anchor hold the same subtree)
- Modify: `pubspec.yaml:73` (one line after it, through `build/typography-pubspec-assets.patch`)

**Interfaces:**
- Consumes: `StratumDimension` (Task 1); `FontType`, `FontSize` (Task 2); `WindowSize`; `loadYaml`, `YamlMap` from the barrel.
- Produces: `StratumFontData({required String family, String? package, StratumDimension adjustSize = const StratumDimension.fixed(0)})` with `String get qualifiedFamily`; `StratumFontRef({required String font, String? mono})`; `StratumFamilySet({required Map<FontType, StratumFontRef> types, String? mono})`; `StratumSizeMetrics({required StratumDimension spaceHeight, StratumDimension letterSpacing = const StratumDimension.fixed(0)})`; `StratumTypeStyle({required FontWeight weight, required Map<FontSize, StratumSizeMetrics> sizes, bool tabular = false, FontType? extendsType, Map<WindowSize, StratumDimension>? scaleByWindowSize})` (sizes after `extends`, smallest first); `StratumTypography({required Map<String, StratumFontData> fonts, required Map<String, StratumFamilySet> families, required Map<FontType, StratumTypeStyle> types, Map<WindowSize, StratumDimension> scaleByWindowSize = const {}})` with `factory fromYaml(YamlMap node)`; `StratumThemeFormatError(String path, String message)` printing `path: message`; `StratumThemeFormatException(List<StratumThemeFormatError> errors)`. Every model has `==` and `hashCode`.

- [ ] **Step 1: Write the failing tests**

Create `test/src/themes/font_data_test.dart` with:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

void main() {
  test('qualifiedFamily is the family for an app font', () {
    expect(const StratumFontData(family: 'Inter').qualifiedFamily, 'Inter');
  });

  test('qualifiedFamily prefixes the package of a package font', () {
    expect(
      const StratumFontData(
        family: 'Inter',
        package: 'stratum_ui',
      ).qualifiedFamily,
      'packages/stratum_ui/Inter',
    );
  });

  test('adjustSize defaults to a fixed 0', () {
    expect(
      const StratumFontData(family: 'Inter').adjustSize,
      const StratumDimension.fixed(0),
    );
  });

  test('fonts with the same fields are equal with equal hash codes', () {
    const a = StratumFontData(
      family: 'Font A',
      adjustSize: StratumDimension.fixed(2),
    );
    const b = StratumFontData(
      family: 'Font A',
      adjustSize: StratumDimension.fixed(2),
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(const StratumFontData(family: 'Font A')));
  });
}
```

Create `test/src/themes/typography/typography_test.dart` with:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

/// A valid style for each type; a test replaces or removes entries.
const _validTypes = <String, String?>{
  'header': '{ weight: 600, sizes: { s16: { spaceHeight: 8 } } }',
  'paragraph': '{ weight: 400, sizes: { s16: { spaceHeight: 10 } } }',
  'number': '{ weight: 600, sizes: { s16: { spaceHeight: 8 } } }',
  'code': '{ weight: 400, sizes: { s16: { spaceHeight: 8 } } }',
  'body': '{ weight: 400, sizes: { s16: { spaceHeight: 8 } } }',
  'table': '{ extends: body, tabular: true }',
};

const _validFamilies =
    '{ default: { header: inter, paragraph: inter, number: inter, '
    'code: inter, body: inter } }';

/// The `typography:` node of a small valid theme, with the sections a test
/// passes swapped in. A `null` entry in [types] removes that type.
YamlMap _typography({
  String fonts = '{ inter: { family: Inter } }',
  String families = _validFamilies,
  Map<String, String?> types = const {},
  String extra = '',
}) {
  final typeLines = [
    for (final MapEntry(:key, :value) in {..._validTypes, ...types}.entries)
      if (value != null) '    $key: $value',
  ].join('\n');
  final document = loadYaml('''
typography:
  fonts: $fonts
  families: $families
  types:
$typeLines
$extra''') as YamlMap;
  return document['typography'] as YamlMap;
}

/// The errors `fromYaml` reports for [node], as `path: message` lines.
List<String> _errors(YamlMap node) {
  try {
    StratumTypography.fromYaml(node);
  } on StratumThemeFormatException catch (exception) {
    return [for (final error in exception.errors) '$error'];
  }
  return const [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StratumTypography.fromYaml on the default theme', () {
    late StratumTypography typography;

    setUpAll(() async {
      final text = await rootBundle.loadString(
        'assets/themes/default/theme.yaml',
      );
      final document = loadYaml(text) as YamlMap;
      typography = StratumTypography.fromYaml(
        document['typography'] as YamlMap,
      );
    });

    test('reads the four fonts and the default family set', () {
      expect(typography.fonts, {
        'inter': const StratumFontData(family: 'Inter'),
        'geist': const StratumFontData(family: 'Geist'),
        'geist-mono': const StratumFontData(family: 'Geist Mono'),
        'roboto-mono': const StratumFontData(family: 'Roboto Mono'),
      });
      expect(typography.families.keys, ['default']);
      final defaults = typography.families['default']!;
      expect(defaults.mono, 'roboto-mono');
      expect(defaults.types, {
        FontType.header: const StratumFontRef(font: 'inter'),
        FontType.paragraph: const StratumFontRef(font: 'inter'),
        FontType.body: const StratumFontRef(font: 'inter'),
        FontType.number: const StratumFontRef(
          font: 'geist',
          mono: 'geist-mono',
        ),
        FontType.code: const StratumFontRef(font: 'roboto-mono'),
      });
    });

    test('reads the window scale', () {
      expect(typography.scaleByWindowSize, {
        WindowSize.watch: const StratumDimension.fixed(0),
        WindowSize.mobile: const StratumDimension.fixed(0),
        WindowSize.tablet: const StratumDimension.fixed(0.5),
        WindowSize.desktop: const StratumDimension.fixed(1),
        WindowSize.bigDesktop: const StratumDimension.fixed(2),
      });
    });

    test('reads the header weight and the Figma metrics of header s56', () {
      final header = typography.types[FontType.header]!;
      expect(header.weight, FontWeight.w600);
      expect(header.sizes.keys, [
        FontSize.s12,
        FontSize.s14,
        FontSize.s18,
        FontSize.s20,
        FontSize.s24,
        FontSize.s36,
        FontSize.s56,
      ]);
      expect(
        header.sizes[FontSize.s56],
        StratumSizeMetrics(
          spaceHeight: const StratumDimension.fixed(16),
          letterSpacing: StratumDimension.parse('-2.4%'),
        ),
      );
    });

    test('gives table the body weight and sizes with tabular figures', () {
      final body = typography.types[FontType.body]!;
      final table = typography.types[FontType.table]!;
      expect(table.weight, body.weight);
      expect(table.sizes, body.sizes);
      expect(table.tabular, isTrue);
      expect(table.extendsType, FontType.body);
      expect(body.tabular, isFalse);
    });
  });

  group('StratumTypography.fromYaml errors', () {
    test('reports several problems together, each with its yaml path', () {
      final node = _typography(
        families:
            '{ default: { header: inter, paragraph: inter, number: inter, '
            'body: inter }, th: { body: kanit } }',
        types: {
          'body':
              '{ extends: table, weight: 400, '
              'sizes: { s16: { spaceHeight: 8px } } }',
          'table': '{ extends: body, tabular: true }',
        },
      );

      expect(
        () => StratumTypography.fromYaml(node),
        throwsA(
          isA<StratumThemeFormatException>().having(
            (exception) => '$exception',
            'toString',
            contains('typography.families.th.body: unknown font key "kanit"'),
          ),
        ),
      );
      const spaceHeight =
          'typography.types.body.sizes.s16.spaceHeight: '
          'expected a number or "N%", got "8px"';
      expect(_errors(node), [
        'typography.families.th.body: unknown font key "kanit"',
        spaceHeight,
        'typography.types.body.extends: cycle body -> table -> body',
        'typography.types.table.extends: cycle table -> body -> table',
        'typography.families.default.code: no font for type "code"',
      ]);
    });

    final cases = <(String, YamlMap, String)>[
      (
        'no fonts',
        _typography(fonts: '{}'),
        'typography.fonts: expected at least one font',
      ),
      (
        'a font without a family',
        _typography(fonts: '{ inter: { package: stratum_ui } }'),
        'typography.fonts.inter.family: required',
      ),
      (
        'a font family that is not a string',
        _typography(fonts: '{ inter: { family: 12 } }'),
        'typography.fonts.inter.family: expected a string, got 12',
      ),
      (
        'an adjustSize that is not a dimension',
        _typography(fonts: '{ inter: { family: Inter, adjustSize: 2px } }'),
        'typography.fonts.inter.adjustSize: '
            'expected a number or "N%", got "2px"',
      ),
      (
        'no default family set',
        _typography(families: '{ th: { body: inter } }'),
        'typography.families.default: required',
      ),
      (
        'a malformed locale tag',
        _typography(
          families:
              '{ default: { header: inter, paragraph: inter, number: inter, '
              'code: inter, body: inter }, TH: { body: inter } }',
        ),
        'typography.families.TH: expected "default", a language such as '
            '"th", or a language and country such as "th_TH"',
      ),
      (
        'a mono reference to an unknown font',
        _typography(
          families:
              '{ default: { header: inter, paragraph: inter, '
              'number: { font: inter, mono: geist-mono }, code: inter, '
              'body: inter } }',
        ),
        'typography.families.default.number.mono: '
            'unknown font key "geist-mono"',
      ),
      (
        'a weight off the 100 grid',
        _typography(
          types: {
            'header': '{ weight: 650, sizes: { s16: { spaceHeight: 8 } } }',
          },
        ),
        'typography.types.header.weight: '
            'expected 100 to 900 in steps of 100, got 650',
      ),
      (
        'a type without a weight',
        _typography(
          types: {'header': '{ sizes: { s16: { spaceHeight: 8 } } }'},
        ),
        'typography.types.header.weight: required',
      ),
      (
        'a type without sizes',
        _typography(types: {'header': '{ weight: 600 }'}),
        'typography.types.header.sizes: expected at least one size',
      ),
      (
        'a size without a spaceHeight',
        _typography(
          types: {
            'header':
                '{ weight: 600, sizes: { s16: { spaceHeight: 8 }, '
                's14: { letterSpacing: 1 } } }',
          },
        ),
        'typography.types.header.sizes.s14.spaceHeight: required',
      ),
      (
        'a tabular flag that is not a bool',
        _typography(types: {'table': '{ extends: body, tabular: yes please }'}),
        'typography.types.table.tabular: '
            'expected true or false, got "yes please"',
      ),
      (
        'a family entry with a mono but no font',
        _typography(
          families:
              '{ default: { header: inter, paragraph: inter, '
              'number: { mono: inter }, code: inter, body: inter } }',
        ),
        'typography.families.default.number.font: required',
      ),
      (
        'a type that extends itself',
        _typography(types: {'table': '{ extends: table }'}),
        'typography.types.table.extends: cycle table -> table',
      ),
      (
        'an extends that names no type',
        _typography(types: {'table': '{ extends: tabel }'}),
        'typography.types.table.extends: unknown type "tabel"',
      ),
      (
        'a missing type',
        _typography(types: {'code': null}),
        'typography.types.code: required',
      ),
    ];
    for (final (name, node, error) in cases) {
      test('reports $name', () {
        expect(_errors(node), [error]);
      });
    }
  });

  group('StratumTypography.fromYaml extends', () {
    test('merges sizes down a chain and keeps the direct parent', () {
      final typography = StratumTypography.fromYaml(
        _typography(
          types: {
            'body':
                '{ extends: paragraph, sizes: { s14: { spaceHeight: 6 } } }',
            'table':
                '{ extends: body, tabular: true, '
                'sizes: { s14: { spaceHeight: 2 } } }',
          },
        ),
      );

      final table = typography.types[FontType.table]!;
      expect(table.extendsType, FontType.body);
      expect(table.weight, FontWeight.w400);
      expect(table.tabular, isTrue);
      expect(table.sizes, {
        FontSize.s14: const StratumSizeMetrics(
          spaceHeight: StratumDimension.fixed(2),
        ),
        FontSize.s16: const StratumSizeMetrics(
          spaceHeight: StratumDimension.fixed(10),
        ),
      });
    });

    test('lets the default family cover a type through its parent', () {
      expect(_errors(_typography()), isEmpty);
      expect(
        StratumTypography.fromYaml(_typography()).families['default']!.types
            .containsKey(FontType.table),
        isFalse,
      );
    });

    test('lets a type override the window scale of its parent', () {
      final typography = StratumTypography.fromYaml(
        _typography(
          types: {
            'body':
                '{ weight: 400, scaleByWindowSize: { desktop: "10%" }, '
                'sizes: { s16: { spaceHeight: 8 } } }',
          },
        ),
      );

      expect(typography.types[FontType.body]!.scaleByWindowSize, {
        WindowSize.desktop: const StratumDimension.percent(0.1),
      });
      expect(
        typography.types[FontType.table]!.scaleByWindowSize,
        typography.types[FontType.body]!.scaleByWindowSize,
      );
      expect(typography.types[FontType.header]!.scaleByWindowSize, isNull);
    });
  });

  group('StratumTypography.fromYaml tags and keys', () {
    test('normalizes th-TH to th_TH and keeps yaml order', () {
      final typography = StratumTypography.fromYaml(
        _typography(
          families:
              '{ th-TH: { body: inter }, default: { header: inter, '
              'paragraph: inter, number: inter, code: inter, body: inter }, '
              'th: { body: inter } }',
        ),
      );

      expect(typography.families.keys, ['th_TH', 'default', 'th']);
    });

    test('warns once per unknown key and skips it', () {
      final warnings = <String>[];
      final saved = debugPrint;
      debugPrint = (message, {wrapWidth}) => warnings.add(message!);
      addTearDown(() => debugPrint = saved);

      final typography = StratumTypography.fromYaml(
        _typography(
          fonts: '{ inter: { family: Inter, weight: 400 } }',
          types: {
            'header':
                '{ weight: 600, sizes: { s16: { spaceHeight: 8 }, '
                's15: { spaceHeight: 8 } } }',
          },
          extra: '  colors: {}',
        ),
      );

      expect(typography.types[FontType.header]!.sizes.keys, [FontSize.s16]);
      expect(warnings, [
        'Stratum theme: skipped unknown key typography.colors',
        'Stratum theme: skipped unknown key typography.fonts.inter.weight',
        'Stratum theme: skipped unknown key typography.types.header.sizes.s15',
      ]);
    });

    test('parsing the same yaml twice gives equal values', () {
      final a = StratumTypography.fromYaml(_typography());
      final b = StratumTypography.fromYaml(_typography());

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}
```

- [ ] **Step 2: Run each test file to see it fail**

Run: `flutter test --no-pub test/src/themes/font_data_test.dart`
Expected: FAIL to compile with `Error: No named parameter with the name 'family'.`

Run: `flutter test --no-pub test/src/themes/typography/typography_test.dart`
Expected: FAIL to compile with `Error: Undefined name 'StratumTypography'.`, among errors for `StratumFontRef`, `StratumSizeMetrics`, and `StratumThemeFormatException`.

- [ ] **Step 3: Write the implementation**

Replace all of `lib/src/themes/font_data.dart` with:

```dart
import 'package:stratum_ui/src/src.dart';

/// A physical font family plus its own size correction, as one entry of
/// `typography.fonts` in `theme.yaml`.
@immutable
class StratumFontData {
  const new({
    required this.family,
    this.package,
    this.adjustSize = const StratumDimension.fixed(0),
  });

  /// The family name the font is registered under.
  final String family;

  /// The package that bundles the font, or null for a font of the app.
  final String? package;

  /// Added to the font size so this font looks as large as the others; a
  /// percent resolves against the requested size.
  final StratumDimension adjustSize;

  /// `packages/<package>/<family>` when [package] is set, else [family].
  String get qualifiedFamily =>
      package == null ? family : 'packages/$package/$family';

  @override
  bool operator ==(Object other) =>
      other is StratumFontData &&
      other.family == family &&
      other.package == package &&
      other.adjustSize == adjustSize;

  @override
  int get hashCode => Object.hash(family, package, adjustSize);

  @override
  String toString() =>
      'StratumFontData(family: $family, package: $package, '
      'adjustSize: $adjustSize)';
}
```

Create `lib/src/themes/typography/typography.dart` with:

```dart
import 'package:stratum_ui/src/src.dart';

/// The fonts one type uses under one locale tag.
@immutable
class StratumFontRef {
  const new({required this.font, this.mono});

  /// Key into [StratumTypography.fonts].
  final String font;

  /// Key into [StratumTypography.fonts] that `.mono` swaps to, or null.
  final String? mono;

  @override
  bool operator ==(Object other) =>
      other is StratumFontRef && other.font == font && other.mono == mono;

  @override
  int get hashCode => Object.hash(font, mono);

  @override
  String toString() => 'StratumFontRef(font: $font, mono: $mono)';
}

/// The fonts of one `typography.families` entry, that is one locale tag.
@immutable
class StratumFamilySet {
  const new({required this.types, this.mono});

  /// The fonts of each type this tag names.
  final Map<FontType, StratumFontRef> types;

  /// Key of the theme-wide mono font of this tag, for `.mono` on a type
  /// without a mono font of its own, or null.
  final String? mono;

  @override
  bool operator ==(Object other) =>
      other is StratumFamilySet &&
      mapEquals(other.types, types) &&
      other.mono == mono;

  @override
  int get hashCode => Object.hash(_mapHash(types), mono);

  @override
  String toString() => 'StratumFamilySet(types: $types, mono: $mono)';
}

/// The line spacing and tracking of one type at one size.
@immutable
class StratumSizeMetrics {
  const new({
    required this.spaceHeight,
    this.letterSpacing = const StratumDimension.fixed(0),
  });

  /// Added to the size to give the line box; a percent resolves against
  /// the scaled size.
  final StratumDimension spaceHeight;

  /// The tracking; a percent resolves against the scaled size.
  final StratumDimension letterSpacing;

  @override
  bool operator ==(Object other) =>
      other is StratumSizeMetrics &&
      other.spaceHeight == spaceHeight &&
      other.letterSpacing == letterSpacing;

  @override
  int get hashCode => Object.hash(spaceHeight, letterSpacing);

  @override
  String toString() =>
      'StratumSizeMetrics(spaceHeight: $spaceHeight, '
      'letterSpacing: $letterSpacing)';
}

/// One entry of `typography.types`, with `extends` already merged in.
@immutable
class StratumTypeStyle {
  const new({
    required this.weight,
    required this.sizes,
    this.tabular = false,
    this.extendsType,
    this.scaleByWindowSize,
  });

  /// The weight when the text style sets none.
  final FontWeight weight;

  /// Whether the type draws tabular figures.
  final bool tabular;

  /// The type this one extends; the family lookup walks it.
  final FontType? extendsType;

  /// The window scale of this type, or null for the theme-wide one.
  final Map<WindowSize, StratumDimension>? scaleByWindowSize;

  /// The metrics of each size this type defines, smallest first.
  final Map<FontSize, StratumSizeMetrics> sizes;

  @override
  bool operator ==(Object other) =>
      other is StratumTypeStyle &&
      other.weight == weight &&
      other.tabular == tabular &&
      other.extendsType == extendsType &&
      mapEquals(other.scaleByWindowSize, scaleByWindowSize) &&
      mapEquals(other.sizes, sizes);

  @override
  int get hashCode => Object.hash(
    weight,
    tabular,
    extendsType,
    scaleByWindowSize == null ? null : _mapHash(scaleByWindowSize!),
    _mapHash(sizes),
  );

  @override
  String toString() =>
      'StratumTypeStyle(weight: $weight, tabular: $tabular, '
      'extendsType: $extendsType, scaleByWindowSize: $scaleByWindowSize, '
      'sizes: $sizes)';
}

/// The typography of a theme: the `typography:` subtree of `theme.yaml`.
@immutable
class StratumTypography {
  const new({
    required this.fonts,
    required this.families,
    required this.types,
    this.scaleByWindowSize = const {},
  });

  /// Parses the `typography:` node of `theme.yaml`.
  ///
  /// Collects every problem with its yaml path and throws one
  /// [StratumThemeFormatException] that lists them all. An unknown key
  /// prints one debug warning and is skipped.
  factory fromYaml(YamlMap node) => _TypographyParser().parse(node);

  /// Each font by its key.
  final Map<String, StratumFontData> fonts;

  /// Each family set by its locale tag (`default`, `th`, `th_TH`), in yaml
  /// order.
  final Map<String, StratumFamilySet> families;

  /// The size each window size adds; a missing window size adds 0.
  final Map<WindowSize, StratumDimension> scaleByWindowSize;

  /// The style of every type.
  final Map<FontType, StratumTypeStyle> types;

  @override
  bool operator ==(Object other) =>
      other is StratumTypography &&
      mapEquals(other.fonts, fonts) &&
      mapEquals(other.families, families) &&
      mapEquals(other.scaleByWindowSize, scaleByWindowSize) &&
      mapEquals(other.types, types);

  @override
  int get hashCode => Object.hash(
    _mapHash(fonts),
    _mapHash(families),
    _mapHash(scaleByWindowSize),
    _mapHash(types),
  );
}

/// One problem in `theme.yaml`, at [path].
@immutable
class StratumThemeFormatError {
  const new(this.path, this.message);

  /// The yaml path, for example `typography.types.body.sizes.s16`.
  final String path;

  /// What is wrong at [path].
  final String message;

  @override
  bool operator ==(Object other) =>
      other is StratumThemeFormatError &&
      other.path == path &&
      other.message == message;

  @override
  int get hashCode => Object.hash(path, message);

  @override
  String toString() => '$path: $message';
}

/// Thrown when `theme.yaml` has one or more problems; [errors] lists them
/// all.
class StratumThemeFormatException implements Exception {
  const new(this.errors);

  /// Every problem found, in the order the parser met them.
  final List<StratumThemeFormatError> errors;

  @override
  String toString() => [
    'StratumThemeFormatException: ${errors.length} problem(s) in theme.yaml',
    for (final error in errors) '  $error',
  ].join('\n');
}

int _mapHash(Map<Object?, Object?> map) => Object.hashAllUnordered(
  map.entries.map((entry) => Object.hash(entry.key, entry.value)),
);

/// One `typography.types` entry before `extends` is merged.
class _RawType {
  const new({
    required this.node,
    required this.sizes,
    this.weight,
    this.tabular,
    this.extendsType,
    this.scale,
  });

  final YamlMap node;
  final FontWeight? weight;
  final bool? tabular;
  final FontType? extendsType;
  final Map<WindowSize, StratumDimension>? scale;
  final Map<FontSize, StratumSizeMetrics> sizes;
}

class _TypographyParser {
  final _errors = <StratumThemeFormatError>[];
  final _extends = <FontType, FontType>{};

  /// Types whose `extends` names an unknown type.
  final _brokenExtends = <FontType>{};

  /// Types whose `extends` chain runs into a cycle.
  final _cycles = <FontType>{};

  static final _tagPattern = RegExp(r'^([a-z]{2,3})(?:[-_]([A-Z]{2}))?$');

  StratumTypography parse(YamlMap node) {
    const path = 'typography';
    _warnUnknown(node, path, const {
      'fonts',
      'families',
      'scaleByWindowSize',
      'types',
    });
    final fontsNode = _map(node['fonts'], '$path.fonts');
    final fontKeys = {...?fontsNode?.keys.map((key) => '$key')};
    final fonts = _fonts(fontsNode, '$path.fonts');
    final familiesNode = _map(node['families'], '$path.families');
    final families = _families(familiesNode, '$path.families', fontKeys);
    final scale = _scale(node['scaleByWindowSize'], '$path.scaleByWindowSize');
    final types = _types(_map(node['types'], '$path.types'), '$path.types');
    if (familiesNode != null) {
      _checkDefaultFamily(familiesNode, '$path.families.default');
    }
    if (_errors.isNotEmpty) {
      throw StratumThemeFormatException(List.unmodifiable(_errors));
    }
    return StratumTypography(
      fonts: fonts,
      families: families,
      scaleByWindowSize: scale ?? const {},
      types: types,
    );
  }

  Map<String, StratumFontData> _fonts(YamlMap? node, String path) {
    if (node == null) return const {};
    if (node.isEmpty) _error(path, 'expected at least one font');
    final fonts = <String, StratumFontData>{};
    for (final MapEntry(:key, :value) in node.entries) {
      final fontPath = '$path.$key';
      final font = _map(value, fontPath);
      if (font == null) continue;
      _warnUnknown(font, fontPath, const {'family', 'package', 'adjustSize'});
      final family = _string(font['family'], '$fontPath.family');
      final package = _string(
        font['package'],
        '$fontPath.package',
        required: false,
      );
      final adjustSize = _dimension(font['adjustSize'], '$fontPath.adjustSize');
      if (family == null) continue;
      fonts['$key'] = StratumFontData(
        family: family,
        package: package,
        adjustSize: adjustSize ?? const StratumDimension.fixed(0),
      );
    }
    return fonts;
  }

  Map<String, StratumFamilySet> _families(
    YamlMap? node,
    String path,
    Set<String> fontKeys,
  ) {
    if (node == null) return const {};
    final families = <String, StratumFamilySet>{};
    for (final MapEntry(:key, :value) in node.entries) {
      final tagPath = '$path.$key';
      final tag = _tag('$key', tagPath);
      final entry = _map(value, tagPath);
      if (tag == null || entry == null) continue;
      final types = <FontType, StratumFontRef>{};
      String? mono;
      for (final MapEntry(key: name, value: ref) in entry.entries) {
        final refPath = '$tagPath.$name';
        if (name == 'mono') {
          mono = _fontKey(ref, refPath, fontKeys);
          continue;
        }
        final type = FontType.values.asNameMap()['$name'];
        if (type == null) {
          _warn(refPath);
          continue;
        }
        final fontRef = _fontRef(ref, refPath, fontKeys);
        if (fontRef != null) types[type] = fontRef;
      }
      families[tag] = StratumFamilySet(types: types, mono: mono);
    }
    return families;
  }

  String? _tag(String key, String path) {
    if (key == 'default') return key;
    final match = _tagPattern.firstMatch(key);
    if (match == null) {
      _error(
        path,
        'expected "default", a language such as "th", or a language and '
        'country such as "th_TH"',
      );
      return null;
    }
    final country = match[2];
    return country == null ? match[1] : '${match[1]}_$country';
  }

  StratumFontRef? _fontRef(Object? value, String path, Set<String> keys) {
    if (value is! YamlMap) {
      final font = _fontKey(value, path, keys);
      return font == null ? null : StratumFontRef(font: font);
    }
    _warnUnknown(value, path, const {'font', 'mono'});
    final font = _fontKey(value['font'], '$path.font', keys);
    final mono = value['mono'] == null
        ? null
        : _fontKey(value['mono'], '$path.mono', keys);
    return font == null ? null : StratumFontRef(font: font, mono: mono);
  }

  String? _fontKey(Object? value, String path, Set<String> keys) {
    final key = _string(value, path);
    if (key == null) return null;
    if (keys.isEmpty || keys.contains(key)) return key;
    _error(path, 'unknown font key "$key"');
    return null;
  }

  Map<WindowSize, StratumDimension>? _scale(Object? value, String path) {
    final node = _map(value, path, required: false);
    if (node == null) return null;
    final scale = <WindowSize, StratumDimension>{};
    for (final MapEntry(:key, :value) in node.entries) {
      final sizePath = '$path.$key';
      final windowSize = WindowSize.values.asNameMap()['$key'];
      if (windowSize == null) {
        _warn(sizePath);
        continue;
      }
      final dimension = _dimension(value, sizePath, required: true);
      if (dimension != null) scale[windowSize] = dimension;
    }
    return scale;
  }

  Map<FontType, StratumTypeStyle> _types(YamlMap? node, String path) {
    if (node == null) return const {};
    final raw = <FontType, _RawType>{};
    for (final MapEntry(:key, :value) in node.entries) {
      final typePath = '$path.$key';
      final type = FontType.values.asNameMap()['$key'];
      if (type == null) {
        _warn(typePath);
        continue;
      }
      final typeNode = _map(value, typePath);
      if (typeNode != null) raw[type] = _rawType(type, typeNode, typePath);
    }
    final types = <FontType, StratumTypeStyle>{};
    for (final type in FontType.values) {
      final typePath = '$path.${type.name}';
      if (!raw.containsKey(type)) {
        _error(typePath, 'required');
        continue;
      }
      final chain = _chain(type, raw, typePath);
      if (chain == null) continue;
      final style = _merge(chain.map((link) => raw[link]!).toList(), typePath);
      if (style != null) types[type] = style;
    }
    return types;
  }

  _RawType _rawType(FontType type, YamlMap node, String path) {
    _warnUnknown(node, path, const {
      'weight',
      'sizes',
      'scaleByWindowSize',
      'extends',
      'tabular',
    });
    final extendsType = _extendsType(node['extends'], '$path.extends');
    if (extendsType != null) _extends[type] = extendsType;
    if (extendsType == null && node['extends'] != null) {
      _brokenExtends.add(type);
    }
    return _RawType(
      node: node,
      weight: _weight(node['weight'], '$path.weight'),
      tabular: _bool(node['tabular'], '$path.tabular'),
      extendsType: extendsType,
      scale: _scale(node['scaleByWindowSize'], '$path.scaleByWindowSize'),
      sizes: _sizes(node['sizes'], '$path.sizes'),
    );
  }

  /// [type] and its `extends` ancestors, nearest first; null when the chain
  /// has a cycle or reaches a type that is undefined or extends an unknown
  /// type.
  List<FontType>? _chain(
    FontType type,
    Map<FontType, _RawType> raw,
    String path,
  ) {
    if (_brokenExtends.contains(type)) return null;
    final chain = [type];
    for (var parent = raw[type]!.extendsType; parent != null;) {
      if (chain.contains(parent)) {
        final names = [...chain, parent].map((link) => link.name);
        _error('$path.extends', 'cycle ${names.join(' -> ')}');
        _cycles.add(type);
        return null;
      }
      final parentRaw = raw[parent];
      if (parentRaw == null || _brokenExtends.contains(parent)) return null;
      chain.add(parent);
      parent = parentRaw.extendsType;
    }
    return chain;
  }

  /// Merges a chain, nearest first, so a child keeps its own values.
  StratumTypeStyle? _merge(List<_RawType> chain, String path) {
    FontWeight? weight;
    bool? tabular;
    Map<WindowSize, StratumDimension>? scale;
    final sizes = <FontSize, StratumSizeMetrics>{};
    for (final link in chain.reversed) {
      weight = link.weight ?? weight;
      tabular = link.tabular ?? tabular;
      scale = link.scale ?? scale;
      sizes.addAll(link.sizes);
    }
    if (weight == null && chain.every((link) => link.node['weight'] == null)) {
      _error('$path.weight', 'required');
    }
    if (sizes.isEmpty) _error('$path.sizes', 'expected at least one size');
    if (weight == null || sizes.isEmpty) return null;
    return StratumTypeStyle(
      weight: weight,
      tabular: tabular ?? false,
      extendsType: chain.first.extendsType,
      scaleByWindowSize: scale,
      sizes: {for (final size in FontSize.values) size: ?sizes[size]},
    );
  }

  Map<FontSize, StratumSizeMetrics> _sizes(Object? value, String path) {
    final node = _map(value, path, required: false);
    if (node == null) return const {};
    final sizes = <FontSize, StratumSizeMetrics>{};
    for (final MapEntry(:key, :value) in node.entries) {
      final sizePath = '$path.$key';
      final size = FontSize.values.asNameMap()['$key'];
      if (size == null) {
        _warn(sizePath);
        continue;
      }
      final metrics = _map(value, sizePath);
      if (metrics == null) continue;
      _warnUnknown(metrics, sizePath, const {'spaceHeight', 'letterSpacing'});
      final spaceHeight = _dimension(
        metrics['spaceHeight'],
        '$sizePath.spaceHeight',
        required: true,
      );
      final letterSpacing = _dimension(
        metrics['letterSpacing'],
        '$sizePath.letterSpacing',
      );
      if (spaceHeight == null) continue;
      sizes[size] = StratumSizeMetrics(
        spaceHeight: spaceHeight,
        letterSpacing: letterSpacing ?? const StratumDimension.fixed(0),
      );
    }
    return sizes;
  }

  FontType? _extendsType(Object? value, String path) {
    final name = _string(value, path, required: false);
    if (name == null) return null;
    final type = FontType.values.asNameMap()[name];
    if (type == null) _error(path, 'unknown type "$name"');
    return type;
  }

  FontWeight? _weight(Object? value, String path) {
    if (value == null) return null;
    if (value is int && value >= 100 && value <= 900 && value % 100 == 0) {
      return FontWeight.values[value ~/ 100 - 1];
    }
    _error(path, 'expected 100 to 900 in steps of 100, got ${_show(value)}');
    return null;
  }

  /// Reports each type that the `default` family set names neither
  /// directly nor through the type's `extends` chain.
  ///
  /// Reads the names from yaml, so a bad font reference, which has its own
  /// error, still counts as naming the type.
  void _checkDefaultFamily(YamlMap families, String path) {
    final defaults = families['default'];
    if (defaults == null) {
      _error(path, 'required');
      return;
    }
    if (defaults is! YamlMap) return;
    final named = defaults.keys.map((key) => '$key').toSet();
    for (final type in FontType.values) {
      final lineage = _lineage(type).toList();
      if (lineage.any(_brokenExtends.contains)) continue;
      if (lineage.any(_cycles.contains)) continue;
      if (lineage.any((link) => named.contains(link.name))) continue;
      _error('$path.${type.name}', 'no font for type "${type.name}"');
    }
  }

  /// [type], then each type it extends, until the chain ends or repeats.
  Iterable<FontType> _lineage(FontType type) sync* {
    final seen = <FontType>{};
    for (FontType? link = type; link != null && seen.add(link);) {
      yield link;
      link = _extends[link];
    }
  }

  YamlMap? _map(Object? value, String path, {bool required = true}) {
    if (value is YamlMap) return value;
    if (value == null) {
      if (required) _error(path, 'required');
      return null;
    }
    _error(path, 'expected a map, got ${_show(value)}');
    return null;
  }

  String? _string(Object? value, String path, {bool required = true}) {
    if (value is String) return value;
    if (value == null) {
      if (required) _error(path, 'required');
      return null;
    }
    _error(path, 'expected a string, got ${_show(value)}');
    return null;
  }

  bool? _bool(Object? value, String path) {
    if (value == null || value is bool) return value as bool?;
    _error(path, 'expected true or false, got ${_show(value)}');
    return null;
  }

  StratumDimension? _dimension(
    Object? value,
    String path, {
    bool required = false,
  }) {
    if (value == null) {
      if (required) _error(path, 'required');
      return null;
    }
    try {
      return StratumDimension.parse(value);
    } on FormatException catch (error) {
      _error(path, error.message);
      return null;
    }
  }

  void _warnUnknown(YamlMap node, String path, Set<String> known) {
    for (final key in node.keys) {
      if (!known.contains('$key')) _warn('$path.$key');
    }
  }

  void _warn(String path) {
    if (kDebugMode) debugPrint('Stratum theme: skipped unknown key $path');
  }

  void _error(String path, String message) =>
      _errors.add(StratumThemeFormatError(path, message));

  static String _show(Object? value) => value is String ? '"$value"' : '$value';
}
```

Replace all of `lib/src/themes/themes.dart` with:

```dart
export 'behavior/behavior.dart';
export 'color/color.dart';
export 'constant/constant.dart';
export 'font_data.dart';
export 'styles/styles.dart';
export 'theme_application.dart';
export 'theme_color.dart';
export 'theme_data.dart';
export 'typography/dimension.dart';
export 'typography/typography.dart';
```

- [ ] **Step 4: Run the tests to see only the default theme fail**

Run: `flutter test --no-pub test/src/themes/font_data_test.dart`
Expected: PASS, `+4: All tests passed!`

Run: `flutter test --no-pub test/src/themes/typography/typography_test.dart`
Expected: FAIL in `StratumTypography.fromYaml on the default theme (setUpAll)` with `Unable to load asset: "assets/themes/default/theme.yaml".`; every other test passes (`+23 -1`). Flutter does not bundle subfolders of `assets/`, and the file still has the old shape.

- [ ] **Step 5: Replace the default typography and declare the folder**

In `assets/themes/default/theme.yaml`, replace lines 142 to 242, from `typography:` down to the last `      s10:` above the blank line and the `# ─── PALETTE` comment, with the spec section 5 subtree:

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

Create `build/typography-pubspec-assets.patch` with:

```diff
diff --git a/pubspec.yaml b/pubspec.yaml
--- a/pubspec.yaml
+++ b/pubspec.yaml
@@ -71,3 +71,4 @@ flutter:
   assets:
     - assets/
     - assets/fonts/
+    - assets/themes/default/
```

Check that it applies to both the index and the working tree, then apply it to the working tree only:

```bash
git apply --cached --check build/typography-pubspec-assets.patch
git apply --check build/typography-pubspec-assets.patch
git apply build/typography-pubspec-assets.patch
```

Expected: no output from any of the three. `pubspec.yaml` now ends with `    - assets/themes/default/`, and the owner's `dotted_border` line is still there.

- [ ] **Step 6: Run the tests, the analyzer, and the formatter**

Run: `flutter test --no-pub test/src/themes/typography/typography_test.dart`
Expected: PASS, `+27: All tests passed!`

Run: `flutter analyze --no-pub lib/src/themes/font_data.dart lib/src/themes/themes.dart lib/src/themes/typography test/src/themes/font_data_test.dart test/src/themes/typography`
Expected: `No issues found!`

Run: `dart format --output=none --set-exit-if-changed lib/src/themes/font_data.dart lib/src/themes/themes.dart lib/src/themes/typography test/src/themes/font_data_test.dart test/src/themes/typography`
Expected: `(0 changed)`, exit 0.

- [ ] **Step 7: Commit through a temporary index**

Confirm the owner's approval for the rename first (Global Constraints). The commit must hold the assets hunk of `pubspec.yaml` without the owner's `dotted_border` line, which `git commit -- pubspec.yaml` would take from the working tree. A temporary index built from `HEAD` holds exactly this task's changes; afterwards the real index gets the same content for these paths, so `git status` shows only the owner's own changes.

```bash
index="$(git rev-parse --git-path index).typography"
GIT_INDEX_FILE="$index" git read-tree HEAD
GIT_INDEX_FILE="$index" git add -- lib/src/themes/font_data.dart lib/src/themes/themes.dart lib/src/themes/typography/typography.dart test/src/themes/font_data_test.dart test/src/themes/typography/typography_test.dart assets/themes/default/theme.yaml
GIT_INDEX_FILE="$index" git rm --cached --quiet -- assets/themes/example.yaml
GIT_INDEX_FILE="$index" git apply --cached build/typography-pubspec-assets.patch
GIT_INDEX_FILE="$index" git commit -F - <<'EOF'
feat(theme): parse the typography subtree of theme.yaml

StratumTypography.fromYaml reads the layered typography shape: fonts
with their own adjustSize, families per locale tag, a theme-wide window
scale, and types with weight, sizes, extends, and tabular. It walks the
whole subtree, collects every problem with its yaml path, and throws
one StratumThemeFormatException; an unknown key prints a debug warning
and is skipped. StratumFontData becomes a family, an optional package,
and an additive adjustSize.

The default theme moves to assets/themes/default/theme.yaml with the
Figma typography in the new shape, and pubspec.yaml declares that
folder, because Flutter does not bundle subfolders of assets/.
EOF
rm -- "$index"
git add -- lib/src/themes/font_data.dart lib/src/themes/themes.dart lib/src/themes/typography/typography.dart test/src/themes/font_data_test.dart test/src/themes/typography/typography_test.dart assets/themes/default/theme.yaml
git apply --cached build/typography-pubspec-assets.patch
```

Run: `git show --stat HEAD`
Expected: seven paths: the rename `assets/themes/{example.yaml => default/theme.yaml}`, `lib/src/themes/font_data.dart`, `lib/src/themes/themes.dart`, `lib/src/themes/typography/typography.dart`, `pubspec.yaml` (`1 +`), and the two test files.

Run: `git diff HEAD -- pubspec.yaml`
Expected: exactly the owner's `+  dotted_border: ^3.1.0`, staged or not as before.

### M1 Dependency table

| task  | depends-on   | agent           |
|-------|--------------|-----------------|
| M1-T1 | —            | general-purpose |
| M1-T2 | —            | general-purpose |
| M1-T3 | M1-T1, M1-T2 | general-purpose |

M1-T1 and M1-T2 touch no common file. M1-T3 rewrites `themes.dart`, which M1-T1 created the export in, and its parser reads `FontType`, `FontSize`, and `StratumDimension`.

---

## Milestone M2: Recipe, resolver, and build

### Task 4 (M2-T4): The immutable StratumTextStyle recipe

**Agent:** general-purpose
**Implements:** T1, Q8, builder name

**Files:**
- Modify: `lib/src/components/common/style/text_style_builder.dart` (whole file; the owner's staged empty placeholder)
- Commit as it stands: `lib/src/components/common/style/style.dart` (the owner's export line)
- Create: `test/src/components/common/style/text_style_builder_test.dart`

**Interfaces:**
- Consumes: `FontType`, `FontSize` (Task 2); `FontColor`; `WindowSize`.
- Produces: `class StratumTextStyle` with the private `const new _(...)`; static `header`, `paragraph`, `number`, `code`, `body`, `table`, and `type(FontType type)`; getters `s10` to `s56`, `light`, `regular`, `medium`, `semiBold`, `bold`, `mono`, `italic`, `underline`, `lineThrough`, the ten `color*` getters, `darkTheme`, `lightTheme`; methods `size(double)`, `weight(FontWeight)`, `decoration(TextDecoration)`, `shadows(List<Shadow>)`, `fontColor(FontColor)`, `color(Color)`, `themeMode(ThemeMode)`, `locale(Locale)`, `windowSize(WindowSize)`, `textScaler(TextScaler)`. Public read-only fields for the resolver: `FontType fontType`, `FontSize fontSize` (default `s16`), `double? customSize` (replaces `fontSize` when set), `FontWeight? fontWeight`, `bool isMono`, `FontStyle? fontStyle`, `TextDecoration? textDecoration`, `List<Shadow>? textShadows`, `FontColor colorRole` (default `primary`), `Color? customColor`, `ThemeMode? themeModeOverride`, `Locale? localeOverride`, `WindowSize? windowSizeOverride`, `TextScaler? textScalerOverride`. The field names differ from the builder methods because a Dart class cannot hold a field and a method of one name.

- [ ] **Step 1: Write the failing test**

Create `test/src/components/common/style/text_style_builder_test.dart` with:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

void main() {
  group('StratumTextStyle entry points', () {
    test('each type starts at s16, its yaml weight, and primary color', () {
      final body = StratumTextStyle.body;

      expect(body.fontType, FontType.body);
      expect(body.fontSize, FontSize.s16);
      expect(body.customSize, isNull);
      expect(body.fontWeight, isNull);
      expect(body.isMono, isFalse);
      expect(body.colorRole, FontColor.primary);
      expect(body.customColor, isNull);
    });

    test('the static getters and type() give the same recipe', () {
      expect(
        {
          FontType.header: StratumTextStyle.header,
          FontType.paragraph: StratumTextStyle.paragraph,
          FontType.number: StratumTextStyle.number,
          FontType.code: StratumTextStyle.code,
          FontType.body: StratumTextStyle.body,
          FontType.table: StratumTextStyle.table,
        },
        {for (final type in FontType.values) type: StratumTextStyle.type(type)},
      );
    });
  });

  group('StratumTextStyle getters', () {
    final body = StratumTextStyle.body;

    test('size getters pick each FontSize', () {
      expect(
        [
          body.s10,
          body.s12,
          body.s14,
          body.s16,
          body.s18,
          body.s20,
          body.s24,
          body.s36,
          body.s48,
          body.s56,
        ].map((style) => style.fontSize),
        FontSize.values,
      );
    });

    test('weight getters pick w300 to w700', () {
      expect(
        [
          body.light,
          body.regular,
          body.medium,
          body.semiBold,
          body.bold,
        ].map((style) => style.fontWeight),
        [
          FontWeight.w300,
          FontWeight.w400,
          FontWeight.w500,
          FontWeight.w600,
          FontWeight.w700,
        ],
      );
      expect(body.weight(FontWeight.w800).fontWeight, FontWeight.w800);
    });

    test('color getters pick each FontColor', () {
      expect(
        [
          body.colorBrandPrimary,
          body.colorBrandSecondary,
          body.colorBrandTertiary,
          body.colorPrimary,
          body.colorPrimaryInverse,
          body.colorPrimaryOnColor,
          body.colorSecondary,
          body.colorSecondaryInverse,
          body.colorTertiary,
          body.colorTertiaryInverse,
        ].map((style) => style.colorRole),
        FontColor.values,
      );
      expect(
        body.fontColor(FontColor.secondary).colorRole,
        FontColor.secondary,
      );
    });

    test('style getters set mono, italic, and the decoration', () {
      expect(body.mono.isMono, isTrue);
      expect(body.italic.fontStyle, FontStyle.italic);
      expect(body.underline.textDecoration, TextDecoration.underline);
      expect(body.lineThrough.textDecoration, TextDecoration.lineThrough);
    });

    test('theme-mode shortcuts set the override', () {
      expect(body.darkTheme.themeModeOverride, ThemeMode.dark);
      expect(body.lightTheme.themeModeOverride, ThemeMode.light);
    });

    test('the last size or color call wins', () {
      final sized = body.size(13).s12;
      expect(sized.fontSize, FontSize.s12);
      expect(sized.customSize, isNull);
      expect(body.s12.size(13).customSize, 13);

      final colored = body.color(const Color(0xFF123456)).colorTertiary;
      expect(colored.customColor, isNull);
      expect(colored.colorRole, FontColor.tertiary);
    });
  });

  group('StratumTextStyle immutability', () {
    test('a stored style is not changed by a later getter', () {
      final caption = StratumTextStyle.body.s12.colorTertiary;
      final medium = caption.medium;

      expect(medium.fontWeight, FontWeight.w500);
      expect(caption.fontWeight, isNull);
      expect(caption, StratumTextStyle.body.s12.colorTertiary);
    });

    test('every getter returns a new instance', () {
      final caption = StratumTextStyle.body.s12;

      expect(identical(caption.s12, caption), isFalse);
      expect(caption.s12, caption);
    });
  });

  group('StratumTextStyle equality', () {
    final base = StratumTextStyle.body;
    final variants = <String, StratumTextStyle Function()>{
      'type': () => StratumTextStyle.header,
      'size': () => base.s12,
      'custom size': () => base.size(13),
      'weight': () => base.bold,
      'mono': () => base.mono,
      'italic': () => base.italic,
      'decoration': () => base.underline,
      'shadows': () => base.shadows([const Shadow(blurRadius: 2)]),
      'font color': () => base.colorBrandPrimary,
      'color': () => base.color(const Color(0xFF123456)),
      'theme mode': () => base.darkTheme,
      'locale': () => base.locale(const Locale('th')),
      'window size': () => base.windowSize(WindowSize.desktop),
      'text scaler': () => base.textScaler(const TextScaler.linear(2)),
    };

    for (final MapEntry(key: name, value: make) in variants.entries) {
      test('$name takes part in == and hashCode', () {
        expect(make(), isNot(base));
        expect(make(), make());
        expect(make().hashCode, make().hashCode);
      });
    }

    test('shadows compare by list content', () {
      final a = base.shadows([const Shadow(blurRadius: 2)]);
      final b = base.shadows([const Shadow(blurRadius: 2)]);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(base.shadows([const Shadow(blurRadius: 3)])));
    });
  });
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `flutter test --no-pub test/src/components/common/style/text_style_builder_test.dart`
Expected: FAIL to compile with `Error: Undefined name 'StratumTextStyle'.`

- [ ] **Step 3: Write the implementation**

Replace all of `lib/src/components/common/style/text_style_builder.dart` with:

```dart
import 'package:stratum_ui/src/src.dart';

/// An immutable text recipe: a type, a size, a weight, a color, and
/// optional overrides of the screen environment.
///
/// Every getter and method returns a new instance, so a stored recipe is
/// safe to reuse:
///
/// ```dart
/// final caption = StratumTextStyle.body.s12.colorTertiary;
/// Text('a', style: caption.medium.build(context)); // medium
/// Text('b', style: caption.build(context)); // regular; caption unchanged
/// ```
@immutable
class StratumTextStyle {
  const new _({
    required this.fontType,
    this.fontSize = FontSize.s16,
    this.customSize,
    this.fontWeight,
    this.isMono = false,
    this.fontStyle,
    this.textDecoration,
    this.textShadows,
    this.colorRole = FontColor.primary,
    this.customColor,
    this.themeModeOverride,
    this.localeOverride,
    this.windowSizeOverride,
    this.textScalerOverride,
  });

  // Type

  static StratumTextStyle get header =>
      const StratumTextStyle._(fontType: FontType.header);

  static StratumTextStyle get paragraph =>
      const StratumTextStyle._(fontType: FontType.paragraph);

  static StratumTextStyle get number =>
      const StratumTextStyle._(fontType: FontType.number);

  static StratumTextStyle get code =>
      const StratumTextStyle._(fontType: FontType.code);

  static StratumTextStyle get body =>
      const StratumTextStyle._(fontType: FontType.body);

  static StratumTextStyle get table =>
      const StratumTextStyle._(fontType: FontType.table);

  static StratumTextStyle type(FontType type) =>
      StratumTextStyle._(fontType: type);

  // Fields

  /// The type whose fonts, weight, and metrics apply.
  final FontType fontType;

  /// The named size; [customSize], when set, replaces it.
  final FontSize fontSize;

  /// A size in logical pixels that takes the metrics of the nearest named
  /// size, or null.
  final double? customSize;

  /// The weight, or null for the weight of the type in `theme.yaml`.
  final FontWeight? fontWeight;

  /// Whether the mono font of the type replaces its font.
  final bool isMono;

  final FontStyle? fontStyle;

  final TextDecoration? textDecoration;

  final List<Shadow>? textShadows;

  /// The theme text color used when [customColor] is null.
  final FontColor colorRole;

  final Color? customColor;

  /// The theme mode to read the theme for, or null for the app's mode.
  final ThemeMode? themeModeOverride;

  /// The locale that picks the fonts, or null for the context's locale.
  final Locale? localeOverride;

  /// The window size that picks the window scale, or null for the
  /// `WindowSizeScope` above the context.
  final WindowSize? windowSizeOverride;

  /// The text scaler, or null for the `MediaQuery` above the context.
  final TextScaler? textScalerOverride;

  // Size

  StratumTextStyle get s10 => _copy(fontSize: FontSize.s10);

  StratumTextStyle get s12 => _copy(fontSize: FontSize.s12);

  StratumTextStyle get s14 => _copy(fontSize: FontSize.s14);

  StratumTextStyle get s16 => _copy(fontSize: FontSize.s16);

  StratumTextStyle get s18 => _copy(fontSize: FontSize.s18);

  StratumTextStyle get s20 => _copy(fontSize: FontSize.s20);

  StratumTextStyle get s24 => _copy(fontSize: FontSize.s24);

  StratumTextStyle get s36 => _copy(fontSize: FontSize.s36);

  StratumTextStyle get s48 => _copy(fontSize: FontSize.s48);

  StratumTextStyle get s56 => _copy(fontSize: FontSize.s56);

  /// A size of [size] logical pixels with the metrics of the nearest named
  /// size.
  StratumTextStyle size(double size) =>
      _copy(fontSize: FontSize.s16, customSize: size);

  // Weight

  StratumTextStyle get light => weight(FontWeight.w300);

  StratumTextStyle get regular => weight(FontWeight.w400);

  StratumTextStyle get medium => weight(FontWeight.w500);

  StratumTextStyle get semiBold => weight(FontWeight.w600);

  StratumTextStyle get bold => weight(FontWeight.w700);

  StratumTextStyle weight(FontWeight weight) => _copy(fontWeight: weight);

  // Variant and style

  /// Swaps to the mono font of the type, keeping the type's metrics.
  StratumTextStyle get mono => _copy(isMono: true);

  StratumTextStyle get italic => _copy(fontStyle: FontStyle.italic);

  StratumTextStyle get underline => decoration(TextDecoration.underline);

  StratumTextStyle get lineThrough => decoration(TextDecoration.lineThrough);

  StratumTextStyle decoration(TextDecoration decoration) =>
      _copy(textDecoration: decoration);

  StratumTextStyle shadows(List<Shadow> shadows) =>
      _copy(textShadows: List.unmodifiable(shadows));

  // Color

  StratumTextStyle get colorPrimary => fontColor(FontColor.primary);

  StratumTextStyle get colorPrimaryInverse =>
      fontColor(FontColor.primaryInverse);

  StratumTextStyle get colorPrimaryOnColor =>
      fontColor(FontColor.primaryOnColor);

  StratumTextStyle get colorSecondary => fontColor(FontColor.secondary);

  StratumTextStyle get colorSecondaryInverse =>
      fontColor(FontColor.secondaryInverse);

  StratumTextStyle get colorTertiary => fontColor(FontColor.tertiary);

  StratumTextStyle get colorTertiaryInverse =>
      fontColor(FontColor.tertiaryInverse);

  StratumTextStyle get colorBrandPrimary => fontColor(FontColor.brandPrimary);

  StratumTextStyle get colorBrandSecondary =>
      fontColor(FontColor.brandSecondary);

  StratumTextStyle get colorBrandTertiary => fontColor(FontColor.brandTertiary);

  StratumTextStyle fontColor(FontColor color) => _copy(colorRole: color);

  StratumTextStyle color(Color color) => _copy(customColor: color);

  // Environment overrides

  StratumTextStyle themeMode(ThemeMode mode) => _copy(themeModeOverride: mode);

  StratumTextStyle get darkTheme => themeMode(ThemeMode.dark);

  StratumTextStyle get lightTheme => themeMode(ThemeMode.light);

  StratumTextStyle locale(Locale locale) => _copy(localeOverride: locale);

  StratumTextStyle windowSize(WindowSize windowSize) =>
      _copy(windowSizeOverride: windowSize);

  StratumTextStyle textScaler(TextScaler textScaler) =>
      _copy(textScalerOverride: textScaler);

  // Equality

  @override
  bool operator ==(Object other) =>
      other is StratumTextStyle &&
      other.fontType == fontType &&
      other.fontSize == fontSize &&
      other.customSize == customSize &&
      other.fontWeight == fontWeight &&
      other.isMono == isMono &&
      other.fontStyle == fontStyle &&
      other.textDecoration == textDecoration &&
      listEquals(other.textShadows, textShadows) &&
      other.colorRole == colorRole &&
      other.customColor == customColor &&
      other.themeModeOverride == themeModeOverride &&
      other.localeOverride == localeOverride &&
      other.windowSizeOverride == windowSizeOverride &&
      other.textScalerOverride == textScalerOverride;

  @override
  int get hashCode => Object.hash(
    fontType,
    fontSize,
    customSize,
    fontWeight,
    isMono,
    fontStyle,
    textDecoration,
    Object.hashAll(textShadows ?? const <Shadow>[]),
    colorRole,
    customColor,
    themeModeOverride,
    localeOverride,
    windowSizeOverride,
    textScalerOverride,
  );

  // Helpers

  /// A copy with the given fields. Setting [fontSize] also sets
  /// [customSize], and setting [colorRole] also sets [customColor], so the
  /// last size or color call wins.
  StratumTextStyle _copy({
    FontSize? fontSize,
    double? customSize,
    FontWeight? fontWeight,
    bool? isMono,
    FontStyle? fontStyle,
    TextDecoration? textDecoration,
    List<Shadow>? textShadows,
    FontColor? colorRole,
    Color? customColor,
    ThemeMode? themeModeOverride,
    Locale? localeOverride,
    WindowSize? windowSizeOverride,
    TextScaler? textScalerOverride,
  }) => StratumTextStyle._(
    fontType: fontType,
    fontSize: fontSize ?? this.fontSize,
    customSize: fontSize == null ? this.customSize : customSize,
    fontWeight: fontWeight ?? this.fontWeight,
    isMono: isMono ?? this.isMono,
    fontStyle: fontStyle ?? this.fontStyle,
    textDecoration: textDecoration ?? this.textDecoration,
    textShadows: textShadows ?? this.textShadows,
    colorRole: colorRole ?? this.colorRole,
    customColor: colorRole == null
        ? customColor ?? this.customColor
        : customColor,
    themeModeOverride: themeModeOverride ?? this.themeModeOverride,
    localeOverride: localeOverride ?? this.localeOverride,
    windowSizeOverride: windowSizeOverride ?? this.windowSizeOverride,
    textScalerOverride: textScalerOverride ?? this.textScalerOverride,
  );
}
```

Check that `lib/src/components/common/style/style.dart` already reads (the owner's line is the third):

```dart
export 'animated_styled_box.dart';
export 'style_decoration.dart';
export 'text_style_builder.dart';
```

- [ ] **Step 4: Run the test, the analyzer, and the formatter**

Run: `flutter test --no-pub test/src/components/common/style/text_style_builder_test.dart`
Expected: PASS, `+25: All tests passed!`

Run: `flutter analyze --no-pub lib/src/components/common/style test/src/components/common/style`
Expected: `No issues found!`

Run: `dart format --output=none --set-exit-if-changed lib/src/components/common/style/text_style_builder.dart lib/src/components/common/style/style.dart test/src/components/common/style/text_style_builder_test.dart`
Expected: `Formatted 3 files (0 changed)`, exit 0. Name the files: `style_decoration.dart` in the same folder has formatting drift from before this plan.

- [ ] **Step 5: Commit**

```bash
git add -- test/src/components/common/style/text_style_builder_test.dart
git commit -F - -- lib/src/components/common/style/text_style_builder.dart lib/src/components/common/style/style.dart test/src/components/common/style/text_style_builder_test.dart <<'EOF'
feat(style): add the immutable StratumTextStyle recipe

StratumTextStyle names a type, a size, a weight, a style, a color, and
optional environment overrides. Every getter returns a new instance, so
a stored recipe stays safe to reuse, and == and hashCode cover every
field, with shadows compared by content, so a later task can cache the
resolved TextStyle by recipe. The style barrel now exports it.
EOF
```

### Task 5 (M2-T5): TypographyResolver, its cache, StratumThemeData.typography, and Figma conformance

**Agent:** general-purpose
**Implements:** T8, Q1, Q2, Q3, Q4, Q5, Q7, leading distribution, default theme `spaceHeight`, section 9 cache, section 10 edge cases

**Files:**
- Create: `lib/src/themes/typography/resolver.dart`
- Modify: `lib/src/themes/themes.dart` (whole file)
- Modify: `lib/src/themes/theme_data.dart:16, 37, 106, 128`
- Modify: `test/src/components/common/fakes/fake_stratum_theme.dart` (whole file)
- Create: `test/src/themes/typography/resolver_test.dart`, `test/src/themes/theme_data_test.dart`, `test/src/themes/typography/figma_conformance_test.dart`

**Interfaces:**
- Consumes: everything Task 3 produces; `StratumTextStyle` and its fields (Task 4); `BaseThemeColor` text colors; `StratumThemeData`.
- Produces: `abstract final class TypographyResolver` with `static const maxCacheEntries = 512` and `static TextStyle resolve(StratumTextStyle recipe, {required StratumThemeData theme, required Locale locale, required WindowSize? windowSize, required TextScaler textScaler})`; `StratumThemeData.typography` (`required` in the constructor, a field, and a `copyWith` parameter) in place of `fonts`; in the test fake, `FakeStratumTheme({..., StratumTypography typography = const StratumTypography(fonts: {}, families: {}, types: {})})` and `const fakeTextColors = <FontColor, Color>{...}`, the text color the fake gives each `FontColor`.

- [ ] **Step 1: Write the failing tests**

Replace all of `test/src/components/common/fakes/fake_stratum_theme.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/themes/behavior/scroll_behavior.dart';
import 'package:stratum_ui/src/themes/color/transparent.dart';
import 'package:stratum_ui/src/themes/constant/font_color.dart';
import 'package:stratum_ui/src/themes/theme_application.dart';
import 'package:stratum_ui/src/themes/theme_color.dart';
import 'package:stratum_ui/src/themes/theme_data.dart';
import 'package:stratum_ui/src/themes/typography/typography.dart';

/// Hover overlay color of [fakeTheme].
const fakeHover = Color(0x11000000);

/// Press overlay color of [fakeTheme].
const fakeActive = Color(0x22000000);

/// The text color a [FakeStratumTheme] gives each [FontColor].
const fakeTextColors = <FontColor, Color>{
  FontColor.brandPrimary: Color(0xFF0000A1),
  FontColor.brandSecondary: Color(0xFF0000A2),
  FontColor.brandTertiary: Color(0xFF0000A3),
  FontColor.primary: Color(0xFF000001),
  FontColor.primaryInverse: Color(0xFF000002),
  FontColor.primaryOnColor: Color(0xFF000003),
  FontColor.secondary: Color(0xFF000004),
  FontColor.secondaryInverse: Color(0xFF000005),
  FontColor.tertiary: Color(0xFF000006),
  FontColor.tertiaryInverse: Color(0xFF000007),
};

class _FakeTransparent extends Fake implements TransparentColors {
  @override
  Color get t0 => const Color(0x00000000);
}

class _FakeColors extends Fake implements BaseThemeColor {
  new(this.overlayHover, this.overlayActive);

  @override
  final Color overlayHover;

  @override
  final Color overlayActive;

  @override
  Color get borderBrand => const Color(0xFF0000FF);

  @override
  TransparentColors get transparent => _FakeTransparent();

  @override
  Color get brandPrimaryText => fakeTextColors[FontColor.brandPrimary]!;

  @override
  Color get brandSecondaryText => fakeTextColors[FontColor.brandSecondary]!;

  @override
  Color get brandTertiaryText => fakeTextColors[FontColor.brandTertiary]!;

  @override
  Color get textPrimary => fakeTextColors[FontColor.primary]!;

  @override
  Color get textPrimaryInverse => fakeTextColors[FontColor.primaryInverse]!;

  @override
  Color get textPrimaryOnColor => fakeTextColors[FontColor.primaryOnColor]!;

  @override
  Color get textSecondary => fakeTextColors[FontColor.secondary]!;

  @override
  Color get textSecondaryInverse => fakeTextColors[FontColor.secondaryInverse]!;

  @override
  Color get textTertiary => fakeTextColors[FontColor.tertiary]!;

  @override
  Color get textTertiaryInverse => fakeTextColors[FontColor.tertiaryInverse]!;
}

/// A theme that answers only what the interaction widgets, the scroll
/// views, and the text styles read.
class FakeStratumTheme extends Fake implements StratumThemeData {
  new({
    Color hover = fakeHover,
    Color active = fakeActive,
    this.scrollBehavior = const StratumScrollBehavior(),
    this.physics = const ClampingScrollPhysics(),
    this.typography = const StratumTypography(
      fonts: {},
      families: {},
      types: {},
    ),
  }) : color = _FakeColors(hover, active);

  @override
  final BaseThemeColor color;

  @override
  final StratumTypography typography;

  @override
  final ScrollBehavior scrollBehavior;

  @override
  final ScrollPhysics physics;
}

/// The default theme of [themedHost].
final fakeTheme = FakeStratumTheme();

/// Places [child] in a [Center] under a [StratumThemeApplication] and a
/// [Directionality].
Widget themedHost(
  Widget child, {
  StratumThemeData? theme,
  TextDirection textDirection = TextDirection.ltr,
}) {
  return StratumThemeApplication(
    themeMode: ThemeMode.light,
    lightTheme: theme ?? fakeTheme,
    darkTheme: null,
    child: Directionality(
      textDirection: textDirection,
      child: Center(child: child),
    ),
  );
}
```

Create `test/src/themes/typography/resolver_test.dart` with:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import '../../components/common/fakes/fake_stratum_theme.dart';

/// The section 7 setup of the spec, plus a Thai header font, a mono font
/// for th_TH, and a table type with its own window scale.
String _yaml({
  String bodyS16 = '{ spaceHeight: "50%", letterSpacing: "-1%" }',
}) =>
    '''
typography:
  fonts:
    inter: { family: Inter }
    font-a: { family: Font A, adjustSize: 2 }
    inter-th: { family: Inter TH, package: thai_fonts }
    geist: { family: Geist }
    geist-mono: { family: Geist Mono }
    roboto-mono: { family: Roboto Mono }
    font-b-mono: { family: Font B Mono, adjustSize: "10%" }
  families:
    default:
      header: inter
      paragraph: inter
      body: inter
      number: { font: geist, mono: geist-mono }
      code: roboto-mono
      mono: roboto-mono
    th:
      body: font-a
    th_TH:
      header: inter-th
      mono: font-b-mono
  scaleByWindowSize: { tablet: "50%", desktop: 1 }
  types:
    header: { weight: 600, sizes: { s24: { spaceHeight: 10 } } }
    paragraph: { weight: 400, sizes: { s16: { spaceHeight: 10 } } }
    number: { weight: 600, sizes: { s16: { spaceHeight: 8 } } }
    code: { weight: 400, sizes: { s16: { spaceHeight: 8 } } }
    body:
      weight: 400
      sizes:
        s12: { spaceHeight: 4 }
        s16: $bodyS16
        s20: { spaceHeight: 8 }
    table: { extends: body, tabular: true, scaleByWindowSize: { desktop: 3 } }
''';

StratumThemeData _theme([String? yaml]) {
  final document = loadYaml(yaml ?? _yaml()) as YamlMap;
  return FakeStratumTheme(
    typography: StratumTypography.fromYaml(document['typography'] as YamlMap),
  );
}

const _en = Locale('en', 'US');
const _thTH = Locale('th', 'TH');

/// Doubles sizes up to 16 and adds the rest unscaled, like the nonlinear
/// font scaling of Android 14.
class _NonlinearScaler extends TextScaler {
  const new();

  @override
  double scale(double fontSize) =>
      fontSize <= 16 ? fontSize * 2 : 32 + (fontSize - 16);

  @override
  double get textScaleFactor => 2;
}

void main() {
  late StratumThemeData theme;

  setUp(() => theme = _theme());

  TextStyle resolve(
    StratumTextStyle recipe, {
    Locale locale = _en,
    WindowSize? windowSize = WindowSize.mobile,
    TextScaler textScaler = TextScaler.noScaling,
  }) => TypographyResolver.resolve(
    recipe,
    theme: theme,
    locale: locale,
    windowSize: windowSize,
    textScaler: textScaler,
  );

  group('TypographyResolver, the spec section 7 example', () {
    final recipe = StratumTextStyle.body.s16.medium;

    test('at a text scale of 2.0', () {
      final style = resolve(
        recipe,
        locale: _thTH,
        windowSize: WindowSize.desktop,
        textScaler: const TextScaler.linear(2),
      );

      expect(style.fontFamily, 'Font A');
      expect(style.fontFamilyFallback, ['Inter']);
      expect(style.fontSize, 19);
      expect(style.height, closeTo(48 / 38, 1e-9));
      expect(style.letterSpacing, closeTo(-0.34, 1e-9));
      expect(style.fontWeight, FontWeight.w500);
      expect(style.leadingDistribution, TextLeadingDistribution.even);
    });

    test('at a text scale of 1.0, tracking based before adjustSize', () {
      final style = resolve(
        recipe,
        locale: _thTH,
        windowSize: WindowSize.desktop,
      );

      expect(style.fontSize, 19);
      expect(style.height, closeTo(24 / 19, 1e-9));
      expect(style.letterSpacing, closeTo(-0.17, 1e-9));
    });

    test('a fixed spaceHeight keeps its pixels at a text scale of 2.0', () {
      theme = _theme(_yaml(bodyS16: '{ spaceHeight: 8 }'));

      final style = resolve(
        recipe,
        locale: _thTH,
        windowSize: WindowSize.desktop,
        textScaler: const TextScaler.linear(2),
      );

      expect(style.height, closeTo((32 + 8) / 38, 1e-9));
    });

    test('a nonlinear scaler scales each value on its own', () {
      final style = resolve(
        recipe,
        locale: _thTH,
        windowSize: WindowSize.desktop,
        textScaler: const _NonlinearScaler(),
      );

      expect(style.fontSize, 19);
      expect(style.height, closeTo(48 / 35, 1e-9));
      expect(style.letterSpacing, closeTo(-0.33, 1e-9));
    });
  });

  group('TypographyResolver line box', () {
    test('a percent spaceHeight keeps the height at any scale', () {
      final s16 = StratumTextStyle.body.s16;

      expect(resolve(s16).height, 1.5);
      expect(resolve(s16, textScaler: const TextScaler.linear(2)).height, 1.5);
    });

    test('a fixed spaceHeight tightens the height as text grows', () {
      final s20 = StratumTextStyle.body.s20;

      expect(resolve(s20).height, closeTo(28 / 20, 1e-9));
      expect(
        resolve(s20, textScaler: const TextScaler.linear(2)).height,
        closeTo(48 / 40, 1e-9),
      );
    });

    test('the window scale grows the font but not the line box', () {
      final style = resolve(
        StratumTextStyle.body.s20,
        windowSize: WindowSize.desktop,
      );

      expect(style.fontSize, 21);
      expect(style.height! * style.fontSize!, closeTo(28, 1e-9));
    });
  });

  group('TypographyResolver sizes', () {
    test('a missing size takes the nearest one, the smaller on a tie', () {
      final s14 = resolve(StratumTextStyle.body.s14);
      final s18 = resolve(StratumTextStyle.body.s18);
      final s24 = resolve(StratumTextStyle.body.s24);

      expect(s14.fontSize, 14);
      expect(s14.height, closeTo((14 + 4) / 14, 1e-9));
      expect(s18.height, closeTo((18 + 9) / 18, 1e-9));
      expect(s24.height, closeTo((24 + 8) / 24, 1e-9));
    });

    test('a missing size warns once per type and size', () {
      final warnings = <String>[];
      final saved = debugPrint;
      debugPrint = (message, {wrapWidth}) => warnings.add(message!);
      addTearDown(() => debugPrint = saved);

      resolve(StratumTextStyle.code.s36);
      resolve(
        StratumTextStyle.code.s36,
        textScaler: const TextScaler.linear(2),
      );

      expect(warnings, ['Stratum theme: code has no size s36; using s16']);
    });

    test('a custom size beyond either end takes the end size', () {
      final small = resolve(StratumTextStyle.body.size(4));
      final large = resolve(StratumTextStyle.body.size(100));

      expect(small.height, closeTo((4 + 4) / 4, 1e-9));
      expect(large.fontSize, 100);
      expect(large.height, closeTo((100 + 8) / 100, 1e-9));
    });

    test('a custom size takes the nearest metrics without a warning', () {
      final warnings = <String>[];
      final saved = debugPrint;
      debugPrint = (message, {wrapWidth}) => warnings.add(message!);
      addTearDown(() => debugPrint = saved);

      final style = resolve(StratumTextStyle.body.size(13));

      expect(style.fontSize, 13);
      expect(style.height, closeTo((13 + 4) / 13, 1e-9));
      expect(warnings, isEmpty);
    });
  });

  group('TypographyResolver window scale', () {
    test('a null window size adds nothing', () {
      expect(resolve(StratumTextStyle.body, windowSize: null).fontSize, 16);
    });

    test('a percent window scale resolves against the requested size', () {
      expect(
        resolve(StratumTextStyle.body, windowSize: WindowSize.tablet).fontSize,
        24,
      );
    });

    test("a type's own window scale wins over the theme-wide one", () {
      expect(
        resolve(
          StratumTextStyle.table,
          windowSize: WindowSize.desktop,
        ).fontSize,
        19,
      );
      expect(
        resolve(StratumTextStyle.table, windowSize: WindowSize.tablet).fontSize,
        24,
      );
    });
  });

  group('TypographyResolver fonts', () {
    test('the locale tags run from th_TH to th to default', () {
      expect(
        resolve(StratumTextStyle.header.s24, locale: _thTH).fontFamily,
        'packages/thai_fonts/Inter TH',
      );
      expect(
        resolve(
          StratumTextStyle.header.s24,
          locale: const Locale('th'),
        ).fontFamily,
        'Inter',
      );
      expect(
        resolve(StratumTextStyle.body, locale: const Locale('th')).fontFamily,
        'Font A',
      );
      expect(resolve(StratumTextStyle.body).fontFamily, 'Inter');
    });

    test('an empty country code counts as no country', () {
      expect(
        resolve(
          StratumTextStyle.body,
          locale: const Locale('th', ''),
        ).fontFamily,
        'Font A',
      );
    });

    test('the lookup walks extends inside each tag', () {
      expect(
        resolve(StratumTextStyle.table, locale: _thTH).fontFamily,
        'Font A',
      );
    });

    test('mono takes the type mono, then the tag mono, then warns', () {
      expect(resolve(StratumTextStyle.number.mono).fontFamily, 'Geist Mono');
      expect(
        resolve(StratumTextStyle.number.mono, locale: _thTH).fontFamily,
        'Geist Mono',
      );
      expect(resolve(StratumTextStyle.body.mono).fontFamily, 'Roboto Mono');
      expect(
        resolve(StratumTextStyle.body.mono, locale: _thTH).fontFamily,
        'Font B Mono',
      );
    });

    test("mono applies the mono font's own adjustSize", () {
      final style = resolve(StratumTextStyle.body.mono, locale: _thTH);

      expect(style.fontSize, closeTo(16 + 1.6, 1e-9));
      expect(style.height, closeTo(24 / 17.6, 1e-9));
    });

    test('mono on code changes nothing; on table it keeps tabular figures', () {
      expect(
        resolve(StratumTextStyle.code.mono),
        resolve(StratumTextStyle.code),
      );

      final table = resolve(StratumTextStyle.table.mono);
      expect(table.fontFamily, 'Roboto Mono');
      expect(table.fontFeatures, [const FontFeature.tabularFigures()]);
    });

    test('mono without any mono font keeps the primary and warns', () {
      theme = _theme('''
typography:
  fonts: { inter: { family: Inter } }
  families:
    default: { header: inter, paragraph: inter, number: inter, code: inter, body: inter }
  types:
    header: { weight: 600, sizes: { s16: { spaceHeight: 8 } } }
    paragraph: { weight: 400, sizes: { s16: { spaceHeight: 8 } } }
    number: { weight: 600, sizes: { s16: { spaceHeight: 8 } } }
    code: { weight: 400, sizes: { s16: { spaceHeight: 8 } } }
    body: { weight: 400, sizes: { s16: { spaceHeight: 8 } } }
    table: { extends: body, tabular: true }
''');
      final warnings = <String>[];
      final saved = debugPrint;
      debugPrint = (message, {wrapWidth}) => warnings.add(message!);
      addTearDown(() => debugPrint = saved);

      expect(resolve(StratumTextStyle.body.mono).fontFamily, 'Inter');
      expect(warnings, ['Stratum theme: no mono font for body; using Inter']);
    });

    test('the fallback lists the same type from every other tag', () {
      expect(resolve(StratumTextStyle.body).fontFamilyFallback, ['Font A']);
      expect(resolve(StratumTextStyle.header.s24).fontFamilyFallback, [
        'packages/thai_fonts/Inter TH',
      ]);
      expect(resolve(StratumTextStyle.body.mono).fontFamilyFallback, [
        'Inter',
        'Font A',
        'Font B Mono',
      ]);
      expect(resolve(StratumTextStyle.code).fontFamilyFallback, isNull);
    });
  });

  group('TypographyResolver weight, features, color, and style', () {
    test('the weight defaults to the type and yields to the recipe', () {
      expect(resolve(StratumTextStyle.body).fontWeight, FontWeight.w400);
      expect(resolve(StratumTextStyle.header.s24).fontWeight, FontWeight.w600);
      expect(resolve(StratumTextStyle.body.bold).fontWeight, FontWeight.w700);
    });

    test('a tabular type draws tabular figures', () {
      expect(resolve(StratumTextStyle.table).fontFeatures, [
        const FontFeature.tabularFigures(),
      ]);
      expect(resolve(StratumTextStyle.body).fontFeatures, isNull);
    });

    test('each FontColor maps to its theme text color', () {
      for (final role in FontColor.values) {
        expect(
          resolve(StratumTextStyle.body.fontColor(role)).color,
          fakeTextColors[role],
          reason: '$role',
        );
      }
    });

    test('a custom color wins over the FontColor', () {
      expect(
        resolve(StratumTextStyle.body.color(const Color(0xFF123456))).color,
        const Color(0xFF123456),
      );
    });

    test('italic, decoration, and shadows pass through', () {
      final style = resolve(
        StratumTextStyle.body.italic.underline.shadows(const [
          Shadow(blurRadius: 2),
        ]),
      );

      expect(style.fontStyle, FontStyle.italic);
      expect(style.decoration, TextDecoration.underline);
      expect(style.shadows, const [Shadow(blurRadius: 2)]);
    });
  });

  group('TypographyResolver cache', () {
    test('a hit returns the identical instance', () {
      final recipe = StratumTextStyle.body.s20;

      expect(identical(resolve(recipe), resolve(recipe)), isTrue);
    });

    test('a different window size gives a different instance', () {
      final recipe = StratumTextStyle.body.s20;

      expect(
        identical(
          resolve(recipe),
          resolve(recipe, windowSize: WindowSize.desktop),
        ),
        isFalse,
      );
    });

    test('each theme keeps its own cache', () {
      final recipe = StratumTextStyle.body.s20;
      final first = resolve(recipe);
      theme = _theme();

      expect(identical(resolve(recipe), first), isFalse);
      expect(resolve(recipe), first);
    });

    test('the 513th entry clears the cache', () {
      final first = resolve(StratumTextStyle.body.size(1000));
      for (var i = 1; i < TypographyResolver.maxCacheEntries; i++) {
        resolve(StratumTextStyle.body.size(1000.0 + i));
      }
      expect(
        identical(resolve(StratumTextStyle.body.size(1000)), first),
        isTrue,
      );

      resolve(StratumTextStyle.body.size(2000));

      expect(
        identical(resolve(StratumTextStyle.body.size(1000)), first),
        isFalse,
      );
    });
  });
}
```

Create `test/src/themes/theme_data_test.dart` with:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import '../components/common/fakes/fake_stratum_theme.dart';

StratumThemeData _theme(StratumTypography typography) => StratumThemeData(
  defaultWidgetSize: WidgetSize.medium,
  themeMode: ThemeMode.light,
  color: fakeTheme.color,
  borderRadius: const AppRadius(),
  border: const AppBorder(),
  shadow: const AppShadow(),
  size: const AppSize(),
  filter: const AppFilter(),
  systemOverlayStyle: SystemUiOverlayStyle.dark,
  systemOverlayInverseStyle: SystemUiOverlayStyle.light,
  space: const AppSpace(),
  splashFactory: InkRipple.splashFactory,
  typography: typography,
);

void main() {
  const inter = StratumTypography(
    fonts: {'inter': StratumFontData(family: 'Inter')},
    families: {},
    types: {},
  );
  const geist = StratumTypography(
    fonts: {'geist': StratumFontData(family: 'Geist')},
    families: {},
    types: {},
  );

  test('copyWith keeps the typography unless it is given', () {
    final theme = _theme(inter);

    expect(theme.typography, inter);
    expect(theme.copyWith().typography, inter);
    expect(theme.copyWith(typography: geist).typography, geist);
  });
}
```

Create `test/src/themes/typography/figma_conformance_test.dart` with:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import '../../components/common/fakes/fake_stratum_theme.dart';

/// Figma line heights by size (file wjRe9eL7863nMRfFats8jZ, node
/// 56740:3360, read 2026-10-02).
const _header = {56: 72, 36: 48, 24: 34, 20: 28, 18: 24, 14: 20, 12: 20};
const _paragraph = {20: 32, 18: 30, 16: 26, 14: 24};
const _body = {18: 28, 16: 24, 14: 24, 12: 16, 10: 16};
const _table = {18: 28, 16: 24, 14: 24, 12: 16};
const _number = {36: 48, 24: 32, 18: 24, 16: 24, 14: 24, 12: 16};
const _code = {18: 24, 16: 24, 14: 24, 12: 16};

StratumTextStyle _at(StratumTextStyle style, int size) => switch (size) {
  10 => style.s10,
  12 => style.s12,
  14 => style.s14,
  16 => style.s16,
  18 => style.s18,
  20 => style.s20,
  24 => style.s24,
  36 => style.s36,
  48 => style.s48,
  56 => style.s56,
  _ => throw ArgumentError.value(size, 'size'),
};

/// A Figma text style: its name, the recipe for it, its size and line
/// height, and its family and weight.
typedef _FigmaStyle = ({
  String name,
  StratumTextStyle recipe,
  int size,
  int lineHeight,
  String family,
  FontWeight weight,
});

/// The Figma styles of [type] at each size of [lineHeights], once per
/// weight name in [weights].
List<_FigmaStyle> _styles(
  String type,
  Map<int, int> lineHeights,
  String family,
  Map<String, (StratumTextStyle, FontWeight)> weights,
) => [
  for (final MapEntry(key: size, value: lineHeight) in lineHeights.entries)
    for (final MapEntry(key: weightName, value: (recipe, weight))
        in weights.entries)
      (
        name: '$type/$size $weightName',
        recipe: _at(recipe, size),
        size: size,
        lineHeight: lineHeight,
        family: family,
        weight: weight,
      ),
];

final _figma = <_FigmaStyle>[
  ..._styles('header', _header, 'Inter', {
    'semibold': (StratumTextStyle.header, FontWeight.w600),
  }),
  ..._styles('paragraph', _paragraph, 'Inter', {
    'regular': (StratumTextStyle.paragraph, FontWeight.w400),
    'semibold': (StratumTextStyle.paragraph.semiBold, FontWeight.w600),
  }),
  ..._styles('body', _body, 'Inter', {
    'regular': (StratumTextStyle.body, FontWeight.w400),
    'medium': (StratumTextStyle.body.medium, FontWeight.w500),
    'semibold': (StratumTextStyle.body.semiBold, FontWeight.w600),
  }),
  ..._styles('table', _table, 'Inter', {
    'regular': (StratumTextStyle.table, FontWeight.w400),
  }),
  ..._styles('number', _number, 'Geist', {
    'semibold': (StratumTextStyle.number, FontWeight.w600),
  }),
  ..._styles(
    'number',
    {10: 16},
    'Geist Mono',
    {'mono': (StratumTextStyle.number.mono, FontWeight.w600)},
  ),
  ..._styles('code', _code, 'Roboto Mono', {
    'regular': (StratumTextStyle.code, FontWeight.w400),
  }),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StratumThemeData theme;

  setUpAll(() async {
    final text = await rootBundle.loadString(
      'assets/themes/default/theme.yaml',
    );
    final document = loadYaml(text) as YamlMap;
    theme = FakeStratumTheme(
      typography: StratumTypography.fromYaml(document['typography'] as YamlMap),
    );
  });

  TextStyle resolve(StratumTextStyle recipe) => TypographyResolver.resolve(
    recipe,
    theme: theme,
    locale: const Locale('en'),
    windowSize: WindowSize.mobile,
    textScaler: TextScaler.noScaling,
  );

  test('covers the 45 Figma text styles', () {
    expect(_figma, hasLength(45));
  });

  for (final style in _figma) {
    test('${style.name} matches Figma at scale 1 on mobile', () {
      final resolved = resolve(style.recipe);

      expect(resolved.fontSize, style.size);
      expect(
        resolved.height! * resolved.fontSize!,
        closeTo(style.lineHeight, 1e-9),
      );
      expect(resolved.fontFamily, style.family);
      expect(resolved.fontWeight, style.weight);
    });
  }

  test('table draws tabular figures on the body font', () {
    expect(resolve(StratumTextStyle.table.s14).fontFeatures, [
      const FontFeature.tabularFigures(),
    ]);
  });

  test('a laid-out line of each type is as tall as Figma says', () {
    final samples = {
      'header/24': (StratumTextStyle.header.s24, 34.0),
      'paragraph/16': (StratumTextStyle.paragraph.s16, 26.0),
      'body/12': (StratumTextStyle.body.s12, 16.0),
      'table/18': (StratumTextStyle.table.s18, 28.0),
      'number/36': (StratumTextStyle.number.s36, 48.0),
      'code/14': (StratumTextStyle.code.s14, 24.0),
    };
    for (final MapEntry(key: name, value: (recipe, lineHeight))
        in samples.entries) {
      final painter = TextPainter(
        text: TextSpan(text: 'Ag ปู่', style: resolve(recipe)),
        textDirection: TextDirection.ltr,
      )..layout();
      addTearDown(painter.dispose);

      expect(
        painter.computeLineMetrics().single.height,
        closeTo(lineHeight, 0.01),
        reason: name,
      );
    }
  });
}
```

- [ ] **Step 2: Run each test file to see it fail**

Run: `flutter test --no-pub test/src/themes/typography/resolver_test.dart`
Expected: FAIL to compile with `Error: Undefined name 'TypographyResolver'.`

Run: `flutter test --no-pub test/src/themes/theme_data_test.dart`
Expected: FAIL to compile with `Error: No named parameter with the name 'typography'.`

Run: `flutter test --no-pub test/src/themes/typography/figma_conformance_test.dart`
Expected: FAIL to compile with `Error: Undefined name 'TypographyResolver'.`

- [ ] **Step 3: Write the implementation**

Create `lib/src/themes/typography/resolver.dart` with:

```dart
import 'package:stratum_ui/src/src.dart';

typedef _CacheKey = (StratumTextStyle, Locale, WindowSize?, TextScaler);

/// Turns a [StratumTextStyle] plus the screen environment into a
/// [TextStyle]. Reads no `BuildContext`.
///
/// Keeps one cache per [StratumThemeData] instance, so a theme swap drops
/// the old cache with the old theme.
abstract final class TypographyResolver {
  /// The most entries one theme's cache holds before it clears itself.
  static const maxCacheEntries = 512;

  static final _caches = Expando<Map<_CacheKey, TextStyle>>(
    'TypographyResolver cache',
  );
  static final _warned = <String>{};

  /// The [TextStyle] for [recipe] under [theme], [locale], [windowSize],
  /// and [textScaler]; the same instance while the cache holds it.
  ///
  /// A null [windowSize] adds no window scale.
  static TextStyle resolve(
    StratumTextStyle recipe, {
    required StratumThemeData theme,
    required Locale locale,
    required WindowSize? windowSize,
    required TextScaler textScaler,
  }) {
    final cache = _caches[theme] ??= {};
    final key = (recipe, locale, windowSize, textScaler);
    if (cache[key] case final style?) return style;
    if (cache.length >= maxCacheEntries) cache.clear();
    return cache[key] = _resolve(recipe, theme, locale, windowSize, textScaler);
  }

  static TextStyle _resolve(
    StratumTextStyle recipe,
    StratumThemeData theme,
    Locale locale,
    WindowSize? windowSize,
    TextScaler textScaler,
  ) {
    final typography = theme.typography;
    final type = recipe.fontType;
    final style = typography.types[type]!;
    final base = recipe.customSize ?? recipe.fontSize.value;
    final metrics = _metrics(style, recipe);
    final mono = recipe.isMono && type != FontType.code;
    final tags = _tags(locale, typography);
    final primaryKey = mono
        ? _monoKey(typography, type, tags)
        : _fontKey(typography, type, tags);
    final font = typography.fonts[primaryKey]!;

    final scaleDimension = windowSize == null
        ? null
        : style.scaleByWindowSize?[windowSize] ??
              typography.scaleByWindowSize[windowSize];
    final size = base + (scaleDimension?.resolve(of: base) ?? 0);
    final fontSize = size + font.adjustSize.resolve(of: base);
    final scaledBase = textScaler.scale(base);
    final lineBox = scaledBase + metrics.spaceHeight.resolve(of: scaledBase);
    final fallback = _fallback(typography, type, mono, primaryKey);

    return TextStyle(
      color: recipe.customColor ?? _color(theme.color, recipe.colorRole),
      fontSize: fontSize,
      fontWeight: recipe.fontWeight ?? style.weight,
      fontStyle: recipe.fontStyle,
      letterSpacing: metrics.letterSpacing.resolve(of: textScaler.scale(size)),
      height: lineBox / textScaler.scale(fontSize),
      leadingDistribution: TextLeadingDistribution.even,
      fontFamily: font.qualifiedFamily,
      fontFamilyFallback: fallback.isEmpty ? null : fallback,
      fontFeatures: style.tabular ? const [FontFeature.tabularFigures()] : null,
      decoration: recipe.textDecoration,
      shadows: recipe.textShadows,
    );
  }

  /// The metrics of the requested size, else of the nearest defined size.
  static StratumSizeMetrics _metrics(
    StratumTypeStyle style,
    StratumTextStyle recipe,
  ) {
    final custom = recipe.customSize;
    if (custom != null) return style.sizes[_nearest(style, custom)]!;
    if (style.sizes[recipe.fontSize] case final metrics?) return metrics;
    final nearest = _nearest(style, recipe.fontSize.value);
    _warnOnce(
      '${recipe.fontType.name} has no size ${recipe.fontSize.name}; '
      'using ${nearest.name}',
    );
    return style.sizes[nearest]!;
  }

  /// The defined size closest to [target], the smaller one on a tie.
  static FontSize _nearest(StratumTypeStyle style, double target) {
    return style.sizes.keys.reduce((best, size) {
      final distance = (size.value - target).abs();
      final bestDistance = (best.value - target).abs();
      return distance < bestDistance ||
              (distance == bestDistance && size.value < best.value)
          ? size
          : best;
    });
  }

  /// The family sets for [locale], most specific first: `<lang>_<country>`,
  /// `<lang>`, then `default`.
  static List<StratumFamilySet> _tags(
    Locale locale,
    StratumTypography typography,
  ) {
    final language = locale.languageCode;
    final country = locale.countryCode;
    return [
      if (country != null && country.isNotEmpty) '${language}_$country',
      language,
      'default',
    ].map((tag) => typography.families[tag]).nonNulls.toList();
  }

  /// [type], then each type it extends.
  static Iterable<FontType> _lineage(
    StratumTypography typography,
    FontType type,
  ) sync* {
    final seen = <FontType>{};
    for (FontType? link = type; link != null && seen.add(link);) {
      yield link;
      link = typography.types[link]?.extendsType;
    }
  }

  /// The font of [type] in [family], walking `extends`, or null.
  static StratumFontRef? _ref(
    StratumTypography typography,
    StratumFamilySet family,
    FontType type,
  ) {
    for (final link in _lineage(typography, type)) {
      if (family.types[link] case final ref?) return ref;
    }
    return null;
  }

  /// The mono font of [type] in [family]: the type's own mono, else the
  /// tag's theme-wide mono, or null.
  static String? _monoOf(
    StratumTypography typography,
    StratumFamilySet family,
    FontType type,
  ) {
    for (final link in _lineage(typography, type)) {
      if (family.types[link]?.mono case final mono?) return mono;
    }
    return family.mono;
  }

  static String _fontKey(
    StratumTypography typography,
    FontType type,
    List<StratumFamilySet> tags,
  ) {
    for (final family in tags) {
      if (_ref(typography, family, type) case final ref?) return ref.font;
    }
    throw StateError('No font for type "${type.name}".');
  }

  /// The type's mono along every tag, then each tag's theme-wide mono,
  /// then the non-mono font with a warning.
  static String _monoKey(
    StratumTypography typography,
    FontType type,
    List<StratumFamilySet> tags,
  ) {
    for (final family in tags) {
      for (final link in _lineage(typography, type)) {
        if (family.types[link]?.mono case final mono?) return mono;
      }
    }
    for (final family in tags) {
      if (family.mono case final mono?) return mono;
    }
    final key = _fontKey(typography, type, tags);
    _warnOnce(
      'no mono font for ${type.name}; '
      'using ${typography.fonts[key]!.family}',
    );
    return key;
  }

  /// The qualified families of [type] in every tag, `default` first, then
  /// yaml order; the mono font before the font when [mono] is set; without
  /// duplicates or [primaryKey].
  static List<String> _fallback(
    StratumTypography typography,
    FontType type,
    bool mono,
    String primaryKey,
  ) {
    final families = [
      ?typography.families['default'],
      for (final MapEntry(:key, :value) in typography.families.entries)
        if (key != 'default') value,
    ];
    final keys = <String>{
      for (final family in families) ...[
        if (mono) ?_monoOf(typography, family, type),
        ?_ref(typography, family, type)?.font,
      ],
    }..remove(primaryKey);
    return [for (final key in keys) typography.fonts[key]!.qualifiedFamily];
  }

  static Color _color(BaseThemeColor colors, FontColor role) => switch (role) {
    FontColor.brandPrimary => colors.brandPrimaryText,
    FontColor.brandSecondary => colors.brandSecondaryText,
    FontColor.brandTertiary => colors.brandTertiaryText,
    FontColor.primary => colors.textPrimary,
    FontColor.primaryInverse => colors.textPrimaryInverse,
    FontColor.primaryOnColor => colors.textPrimaryOnColor,
    FontColor.secondary => colors.textSecondary,
    FontColor.secondaryInverse => colors.textSecondaryInverse,
    FontColor.tertiary => colors.textTertiary,
    FontColor.tertiaryInverse => colors.textTertiaryInverse,
  };

  static void _warnOnce(String message) {
    if (kDebugMode && _warned.add(message)) {
      debugPrint('Stratum theme: $message');
    }
  }
}
```

Replace all of `lib/src/themes/themes.dart` with:

```dart
export 'behavior/behavior.dart';
export 'color/color.dart';
export 'constant/constant.dart';
export 'font_data.dart';
export 'styles/styles.dart';
export 'theme_application.dart';
export 'theme_color.dart';
export 'theme_data.dart';
export 'typography/dimension.dart';
export 'typography/resolver.dart';
export 'typography/typography.dart';
```

In `lib/src/themes/theme_data.dart`, replace:

```dart
    required this.fonts,
```

with:

```dart
    required this.typography,
```

In `lib/src/themes/theme_data.dart`, replace:

```dart
  final List<StratumFontData> fonts;
```

with:

```dart
  final StratumTypography typography;
```

In `lib/src/themes/theme_data.dart`, replace:

```dart
    List<StratumFontData>? fonts,
```

with:

```dart
    StratumTypography? typography,
```

In `lib/src/themes/theme_data.dart`, replace:

```dart
      fonts: fonts ?? this.fonts,
```

with:

```dart
      typography: typography ?? this.typography,
```

- [ ] **Step 4: Run the tests, the analyzer, and the formatter**

Run: `flutter test --no-pub test/src/themes/typography/resolver_test.dart`
Expected: PASS, `+31: All tests passed!`

Run: `flutter test --no-pub test/src/themes/theme_data_test.dart`
Expected: PASS, `+1: All tests passed!`

Run: `flutter test --no-pub test/src/themes/typography/figma_conformance_test.dart`
Expected: PASS, `+48: All tests passed!` (45 Figma styles, the count, tabular figures, and the `TextPainter` line heights).

Run: `flutter test --no-pub test/src/components/common/`
Expected: PASS, `+585: All tests passed!` on the verified tree; the suites that use the fake theme still pass.

Run: `flutter analyze --no-pub lib/src/themes/typography lib/src/themes/theme_data.dart lib/src/themes/themes.dart test/src/themes/typography test/src/themes/theme_data_test.dart test/src/components/common/fakes`
Expected: one issue, the `unnecessary_type_name_in_constructor` info at `lib/src/themes/theme_data.dart:140:9` that the anchor already reports.

Run: `dart format --output=none --set-exit-if-changed lib/src/themes/typography lib/src/themes/themes.dart test/src/themes/typography test/src/themes/theme_data_test.dart test/src/components/common/fakes/fake_stratum_theme.dart`
Expected: `(0 changed)`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add -- lib/src/themes/typography/resolver.dart test/src/themes/typography/resolver_test.dart test/src/themes/theme_data_test.dart test/src/themes/typography/figma_conformance_test.dart
git commit -F - -- lib/src/themes/typography/resolver.dart lib/src/themes/themes.dart lib/src/themes/theme_data.dart test/src/themes/typography/resolver_test.dart test/src/themes/theme_data_test.dart test/src/themes/typography/figma_conformance_test.dart test/src/components/common/fakes/fake_stratum_theme.dart <<'EOF'
feat(theme): resolve text recipes into cached TextStyles

TypographyResolver.resolve is a pure function from a StratumTextStyle,
a theme, a locale, a window size, and a text scaler to a TextStyle. It
follows the nine steps of the typography spec: nearest size with one
warning, the locale tag chain, the mono chain, a fallback list of the
same type from every tag, the window scale on the size but not the line
box, adjustSize on the font size only, and textScaler.scale per value,
so a nonlinear scaler stays exact. Each theme instance keeps its own
cache of at most 512 entries in an Expando.

StratumThemeData replaces its unused fonts list with typography in the
constructor, the field, and copyWith. The Figma conformance test checks
all 45 Figma text styles against the default theme at text scale 1 on
mobile.
EOF
```

### Task 6 (M2-T6): StratumTextStyle.build(context)

**Agent:** general-purpose
**Implements:** Q2, Q5, Q8, section 9 rebuild scope, section 10 edge cases

**Files:**
- Modify: `lib/src/components/common/style/text_style_builder.dart` (class doc; `build` before `// Equality`)
- Create: `test/src/components/common/style/text_style_build_test.dart`

**Interfaces:**
- Consumes: `TypographyResolver.resolve` (Task 5); `StratumThemeApplication.of`; `WindowSizeScope.maybeOf` (Task 2); `FakeStratumTheme(typography:)` and `themedHost` from the test fake.
- Produces: `TextStyle StratumTextStyle.build(BuildContext context)`.

- [ ] **Step 1: Write the failing test**

Create `test/src/components/common/style/text_style_build_test.dart` with:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import '../fakes/fake_stratum_theme.dart';

/// A theme whose body is [body] by default and Font A in Thai, with a
/// window scale of 1 on tablet and 2 on desktop.
StratumThemeData _theme({String body = 'inter'}) {
  final document = loadYaml('''
typography:
  fonts:
    inter: { family: Inter }
    geist: { family: Geist }
    font-a: { family: Font A }
  families:
    default:
      header: inter
      paragraph: inter
      number: inter
      code: inter
      body: $body
    th: { body: font-a }
  scaleByWindowSize: { tablet: 1, desktop: 2 }
  types:
    header: { weight: 600, sizes: { s16: { spaceHeight: 8 } } }
    paragraph: { weight: 400, sizes: { s16: { spaceHeight: 8 } } }
    number: { weight: 600, sizes: { s16: { spaceHeight: 8 } } }
    code: { weight: 400, sizes: { s16: { spaceHeight: 8 } } }
    body: { weight: 400, sizes: { s16: { spaceHeight: 8 } } }
    table: { extends: body, tabular: true }
''') as YamlMap;
  return FakeStratumTheme(
    typography: StratumTypography.fromYaml(document['typography'] as YamlMap),
  );
}

/// A widget that builds [recipe] on every build and records the result.
Widget _probe(List<TextStyle> styles, [StratumTextStyle? recipe]) {
  return Builder(
    builder: (context) {
      styles.add((recipe ?? StratumTextStyle.body).build(context));
      return const SizedBox();
    },
  );
}

void main() {
  final theme = _theme();

  void setWindowSize(WidgetTester tester, Size size) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
  }

  Widget localized(Locale locale, Widget child) => Localizations(
    locale: locale,
    delegates: const [DefaultWidgetsLocalizations.delegate],
    child: child,
  );

  testWidgets('a Localizations locale change switches the family', (
    tester,
  ) async {
    final styles = <TextStyle>[];
    final probe = _probe(styles);

    await tester.pumpWidget(
      themedHost(localized(const Locale('en'), probe), theme: theme),
    );
    await tester.pumpWidget(
      themedHost(localized(const Locale('th'), probe), theme: theme),
    );

    expect(styles.map((style) => style.fontFamily), ['Inter', 'Font A']);
  });

  testWidgets('without Localizations the platform locale picks the family', (
    tester,
  ) async {
    tester.platformDispatcher.localeTestValue = const Locale('th');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    final styles = <TextStyle>[];

    await tester.pumpWidget(themedHost(_probe(styles), theme: theme));

    expect(styles.single.fontFamily, 'Font A');
  });

  testWidgets('a resize inside one breakpoint builds no text', (tester) async {
    setWindowSize(tester, const Size(400, 800));
    addTearDown(tester.view.reset);
    final styles = <TextStyle>[];

    await tester.pumpWidget(
      themedHost(WindowSizeScope(child: _probe(styles)), theme: theme),
    );
    for (var width = 401.0; width < 600; width += 7) {
      setWindowSize(tester, Size(width, 800));
      await tester.pump();
    }

    expect(styles, hasLength(1));
  });

  testWidgets('crossing a breakpoint rebuilds with the new font size', (
    tester,
  ) async {
    setWindowSize(tester, const Size(400, 800));
    addTearDown(tester.view.reset);
    final styles = <TextStyle>[];

    await tester.pumpWidget(
      themedHost(WindowSizeScope(child: _probe(styles)), theme: theme),
    );
    setWindowSize(tester, const Size(800, 1000));
    await tester.pump();

    expect(styles.map((style) => style.fontSize), [16, 17]);
  });

  testWidgets('a text scale change rebuilds with a new height', (tester) async {
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final styles = <TextStyle>[];

    await tester.pumpWidget(themedHost(_probe(styles), theme: theme));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    await tester.pump();

    expect(styles.map((style) => style.height), [24 / 16, 40 / 32]);
  });

  testWidgets('no WindowSizeScope adds no window scale and does not throw', (
    tester,
  ) async {
    setWindowSize(tester, const Size(1300, 800));
    addTearDown(tester.view.reset);
    final styles = <TextStyle>[];

    await tester.pumpWidget(themedHost(_probe(styles), theme: theme));

    expect(tester.takeException(), isNull);
    expect(styles.single.fontSize, 16);
  });

  testWidgets('without a StratumThemeApplication it throws a FlutterError', (
    tester,
  ) async {
    await tester.pumpWidget(_probe(<TextStyle>[]));

    expect(
      tester.takeException(),
      isA<FlutterError>().having(
        (error) => error.message,
        'message',
        contains('StratumThemeApplication'),
      ),
    );
  });

  testWidgets('the themeMode override reads the theme of that mode', (
    tester,
  ) async {
    final styles = <TextStyle>[];

    await tester.pumpWidget(
      StratumThemeApplication(
        themeMode: ThemeMode.light,
        lightTheme: theme,
        darkTheme: _theme(body: 'geist'),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            children: [
              _probe(styles),
              _probe(styles, StratumTextStyle.body.darkTheme),
            ],
          ),
        ),
      ),
    );

    expect(styles.map((style) => style.fontFamily), ['Inter', 'Geist']);
  });

  testWidgets('the locale, windowSize, and textScaler overrides apply', (
    tester,
  ) async {
    final styles = <TextStyle>[];

    await tester.pumpWidget(
      themedHost(
        localized(
          const Locale('en'),
          Column(
            children: [
              _probe(styles, StratumTextStyle.body.locale(const Locale('th'))),
              _probe(
                styles,
                StratumTextStyle.body.windowSize(WindowSize.desktop),
              ),
              _probe(
                styles,
                StratumTextStyle.body.textScaler(const TextScaler.linear(2)),
              ),
            ],
          ),
        ),
        theme: theme,
      ),
    );

    expect(styles[0].fontFamily, 'Font A');
    expect(styles[1].fontSize, 18);
    expect(styles[2].height, 40 / 32);
  });
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `flutter test --no-pub test/src/components/common/style/text_style_build_test.dart`
Expected: FAIL to compile with `Error: The method 'build' isn't defined for the type 'StratumTextStyle'.`

- [ ] **Step 3: Write the implementation**

In `lib/src/components/common/style/text_style_builder.dart`, replace:

```dart
/// ```
@immutable
```

with:

```dart
/// ```
///
/// [build] computes the line height and letter spacing for the text scaler
/// of the nearest [MediaQuery]. A [Text] that sets its own `textScaler`
/// must pass the same scaler through [textScaler].
@immutable
```

In `lib/src/components/common/style/text_style_builder.dart`, replace:

```dart
  // Equality
```

with:

```dart
  // Build

  /// The [TextStyle] for this recipe under the environment of [context].
  ///
  /// Reads the theme from [StratumThemeApplication] for
  /// [themeModeOverride]; the locale from [localeOverride], else
  /// [Localizations], else the platform; the window size from
  /// [windowSizeOverride], else [WindowSizeScope], where none adds no
  /// window scale; and the text scaler from [textScalerOverride], else
  /// [MediaQuery], else no scaling. The calling widget rebuilds only when
  /// one of these changes, so a resize inside one breakpoint rebuilds no
  /// text.
  TextStyle build(BuildContext context) => TypographyResolver.resolve(
    this,
    theme: StratumThemeApplication.of(context, themeMode: themeModeOverride),
    locale:
        localeOverride ??
        Localizations.maybeLocaleOf(context) ??
        View.of(context).platformDispatcher.locale,
    windowSize: windowSizeOverride ?? WindowSizeScope.maybeOf(context),
    textScaler:
        textScalerOverride ??
        MediaQuery.maybeTextScalerOf(context) ??
        TextScaler.noScaling,
  );

  // Equality
```

- [ ] **Step 4: Run the tests, the analyzer, and the formatter**

Run: `flutter test --no-pub test/src/components/common/style/text_style_build_test.dart`
Expected: PASS, `+9: All tests passed!`

Run: `flutter test --no-pub test/src/components/common/style/text_style_builder_test.dart`
Expected: PASS, `+25: All tests passed!`

Run: `flutter analyze --no-pub lib/src/components/common/style/text_style_builder.dart test/src/components/common/style/text_style_build_test.dart`
Expected: `No issues found!`

Run: `dart format --output=none --set-exit-if-changed lib/src/components/common/style/text_style_builder.dart test/src/components/common/style/text_style_build_test.dart`
Expected: `Formatted 2 files (0 changed)`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add -- test/src/components/common/style/text_style_build_test.dart
git commit -F - -- lib/src/components/common/style/text_style_builder.dart test/src/components/common/style/text_style_build_test.dart <<'EOF'
feat(style): build a StratumTextStyle from its BuildContext

build(context) reads the theme for the recipe's theme mode, the locale
from Localizations or the platform, the window size from
WindowSizeScope.maybeOf, and the text scaler from
MediaQuery.maybeTextScalerOf, each replaced by its override, and hands
them to TypographyResolver. Text therefore rebuilds on a locale change,
a breakpoint crossing, or a text scale change, and not on a resize
inside one breakpoint. The class documents that a Text with its own
textScaler must pass the same scaler to the recipe.
EOF
```

### Task 7 (M2-T7): The typography demo and the final verification

**Agent:** general-purpose
**Implements:** section 11 manual check (the page), section 12 verification

**Files:**
- Create: `example/lib/typography_demo.dart`
- Create: `example/test/typography_demo_test.dart`

**Interfaces:**
- Consumes: `StratumTextStyle` with `build` (Task 6); `StratumTypography.fromYaml` (Task 3); the package asset `packages/stratum_ui/assets/themes/default/theme.yaml` (Task 3).
- Produces: `Future<StratumThemeData> loadDemoTheme()` and `TypographyDemoApp({Key? key, required StratumThemeData theme})` in `package:stratum_ui_example/typography_demo.dart`; each sample `Text` carries `ValueKey('<type> <size>')`, for example `ValueKey('header s56')`.

- [ ] **Step 1: Write the failing test**

Create `example/test/typography_demo_test.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui_example/typography_demo.dart';

void main() {
  testWidgets('loads the default theme and lists its types and sizes', (
    tester,
  ) async {
    final theme = await tester.runAsync(loadDemoTheme);

    await tester.pumpWidget(TypographyDemoApp(theme: theme!));

    expect(find.text('header s56'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('table s10'), 300);
    expect(find.text('table s10'), findsOneWidget);
  });

  testWidgets('switches the window size and the text scale', (tester) async {
    final theme = await tester.runAsync(loadDemoTheme);
    await tester.pumpWidget(TypographyDemoApp(theme: theme!));
    TextStyle sample() =>
        tester.widget<Text>(find.byKey(const ValueKey('header s56'))).style!;

    await tester.tap(find.text('mobile'));
    await tester.pumpAndSettle();
    expect(sample().fontSize, 56);
    expect(sample().height, closeTo(72 / 56, 1e-9));

    await tester.tap(find.text('200%'));
    await tester.pumpAndSettle();
    expect(sample().height, closeTo((112 + 16) / 112, 1e-9));

    await tester.tap(find.text('bigDesktop'));
    await tester.pumpAndSettle();
    expect(sample().fontSize, 58);
  });
}
```

- [ ] **Step 2: Run it to see it fail**

From `example/`, run: `flutter test --no-pub test/typography_demo_test.dart`
Expected: FAIL to compile with `Error: Error when reading 'lib/typography_demo.dart': No such file or directory`.

- [ ] **Step 3: Write the demo**

Create `example/lib/typography_demo.dart` with:

```dart
// A page for checking typography by hand on Chrome and macOS, above all
// Thai stacked marks at text scales of 100%, 150%, and 200%:
//
//   flutter run -d chrome -t lib/typography_demo.dart
//   flutter run -d macos -t lib/typography_demo.dart
//
// ignore_for_file: implementation_imports
import 'package:stratum_ui/src/src.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(TypographyDemoApp(theme: await loadDemoTheme()));
}

/// The default theme's typography, read from the stratum_ui package assets.
Future<StratumThemeData> loadDemoTheme() async {
  final text = await rootBundle.loadString(
    'packages/stratum_ui/assets/themes/default/theme.yaml',
  );
  final document = loadYaml(text) as YamlMap;
  return _DemoTheme(
    StratumTypography.fromYaml(document['typography'] as YamlMap),
  );
}

/// The smallest theme the text styles read: the typography and the primary
/// text color. Any other member throws, as the test theme does.
class _DemoTheme implements StratumThemeData {
  _DemoTheme(this.typography);

  @override
  final StratumTypography typography;

  @override
  final BaseThemeColor color = _DemoColors();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DemoColors implements BaseThemeColor {
  @override
  final Color textPrimary = const Color(0xFF111827);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _sample = 'ปู่ นี้ ฟุ้ง ญี่ปุ่น · Ag 1,250.00';

const _scales = {'100%': 1.0, '150%': 1.5, '200%': 2.0};

StratumTextStyle _at(StratumTextStyle style, FontSize size) => switch (size) {
  FontSize.s10 => style.s10,
  FontSize.s12 => style.s12,
  FontSize.s14 => style.s14,
  FontSize.s16 => style.s16,
  FontSize.s18 => style.s18,
  FontSize.s20 => style.s20,
  FontSize.s24 => style.s24,
  FontSize.s36 => style.s36,
  FontSize.s48 => style.s48,
  FontSize.s56 => style.s56,
};

class TypographyDemoApp extends StatelessWidget {
  const TypographyDemoApp({super.key, required this.theme});

  final StratumThemeData theme;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stratum typography demo',
      builder: (context, child) => StratumThemeApplication(
        themeMode: ThemeMode.light,
        lightTheme: theme,
        darkTheme: null,
        child: WindowSizeScope(child: child!),
      ),
      home: const _TypographyDemoPage(),
    );
  }
}

class _TypographyDemoPage extends StatefulWidget {
  const _TypographyDemoPage();

  @override
  State<_TypographyDemoPage> createState() => _TypographyDemoPageState();
}

class _TypographyDemoPageState extends State<_TypographyDemoPage> {
  /// The window size the samples use; null follows the real window.
  WindowSize? _windowSize;
  var _scale = 1.0;

  Widget _chip(
    String label, {
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }

  Widget _controls() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text('Window size'),
        _chip(
          'auto (${WindowSizeScope.of(context).name})',
          selected: _windowSize == null,
          onSelected: () => setState(() => _windowSize = null),
        ),
        for (final windowSize in WindowSize.values)
          _chip(
            windowSize.name,
            selected: _windowSize == windowSize,
            onSelected: () => setState(() => _windowSize = windowSize),
          ),
        const SizedBox(width: 16),
        const Text('Text scale'),
        for (final MapEntry(key: label, value: scale) in _scales.entries)
          _chip(
            label,
            selected: _scale == scale,
            onSelected: () => setState(() => _scale = scale),
          ),
      ],
    );
  }

  Widget _sampleRow(BuildContext context, FontType type, FontSize size) {
    var recipe = _at(StratumTextStyle.type(type), size);
    final windowSize = _windowSize;
    if (windowSize != null) recipe = recipe.windowSize(windowSize);
    final label = '${type.name} ${size.name}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label)),
          Expanded(
            child: ColoredBox(
              color: const Color(0xFFE8EEF9),
              child: Text(
                _sample,
                key: ValueKey(label),
                style: recipe.build(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final typography = StratumThemeApplication.of(context).typography;
    return Scaffold(
      appBar: AppBar(title: const Text('Typography demo')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(padding: const EdgeInsets.all(16), child: _controls()),
          Expanded(
            child: MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(_scale)),
              child: Builder(
                builder: (context) => ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final type in FontType.values) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 8),
                        child: Text(
                          type.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      for (final size
                          in typography.types[type]!.sizes.keys
                              .toList()
                              .reversed)
                        _sampleRow(context, type, size),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test, the analyzer, and the formatter**

From `example/`, run: `flutter test --no-pub test/typography_demo_test.dart`
Expected: PASS, `+2: All tests passed!`

Run: `flutter analyze --no-pub example/lib/typography_demo.dart example/test/typography_demo_test.dart`
Expected: `No issues found!`

Run: `dart format --output=none --set-exit-if-changed example/lib/typography_demo.dart example/test/typography_demo_test.dart`
Expected: `Formatted 2 files (0 changed)`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add -- example/lib/typography_demo.dart example/test/typography_demo_test.dart
git commit -F - -- example/lib/typography_demo.dart example/test/typography_demo_test.dart <<'EOF'
feat(example): add a typography demo for the manual Thai check

The page loads the default theme from the stratum_ui package assets and
renders every type at every size it defines with Thai stacked marks on
a tinted line box, so clipped or colliding marks show. Chips switch the
window size (or follow the real window) and the text scale between
100%, 150%, and 200%. A smoke test loads the theme and checks that both
switches reach the resolved style.
EOF
```

- [ ] **Step 6: Run the whole verification**

Run: `flutter test --no-pub > build/typography-suite.log 2>&1; tail -1 build/typography-suite.log`
Expected: `+756: All tests passed!`

Run: `flutter analyze --no-pub lib test example > build/typography-analyze.log 2>&1; tail -1 build/typography-analyze.log`
Expected: `73 issues found.`, none of them an error and none in a file this plan touched except `lib/src/themes/theme_data.dart:140:9`.

From `example/`, run: `flutter test --no-pub test/ > build/typography-example.log 2>&1; tail -1 build/typography-example.log`
Expected: `+109: All tests passed!`

Run: `git status --short`
Expected: only the owner's work in progress, as Global Constraints lists it, and `pubspec.yaml` with the `dotted_border` line alone.

- [ ] **Step 7: Hand the manual check to the owner**

The owner runs `flutter run -d macos -t lib/typography_demo.dart` and `flutter run -d chrome -t lib/typography_demo.dart` from `example/`, and checks the Thai stacked marks of every row at 100%, 150%, and 200% on every window size, `bigDesktop` above all (spec section 10). Record the findings in `profile/memory/project_stratum_ui_theme_system.md` in the NTD OS root.

### M2 Dependency table

| task  | depends-on | agent           |
|-------|------------|-----------------|
| M2-T4 | —          | general-purpose |
| M2-T5 | M2-T4      | general-purpose |
| M2-T6 | M2-T5      | general-purpose |
| M2-T7 | M2-T6      | general-purpose |

M2 waits on all of M1. M2-T6 edits the file M2-T4 writes, and both read the fake theme that M2-T5 extends.

## Coverage

| requirement | task(s) | note |
|-------------|---------|------|
| T1 empty `text_style_builder.dart` | M2-T4, M2-T6 | |
| T2 `FontType` without `numberMono` | M1-T2 | |
| T3 `StratumFontData` rewrite | M1-T3 | |
| T4 default `typography:` subtree | M1-T3 | |
| T5 `FontSize` without `custom` | M1-T2 | |
| T6 `WindowSizeScope.maybeOf` | M1-T2 | |
| T7 `assets/themes/default/` declared | M1-T3 | the typography test loads the file through the asset bundle |
| T8 `StratumThemeData.typography` | M2-T5 | |
| Q1 line box | M2-T5 | |
| Q2 system text scale | M2-T5, M2-T6 | |
| Q3 percent bases | M1-T1, M2-T5 | |
| Q4 `.mono` and `table` | M1-T2, M2-T5 | |
| Q5 locale and fallback (A1) | M2-T5, M2-T6 | |
| Q6 layered yaml shape | M1-T3 | |
| Q7 missing size | M2-T5 | |
| Q8 immutable builder | M2-T4, M2-T6 | |
| Value syntax | M1-T1, M1-T3 | |
| Value type name `StratumDimension` | M1-T1 | |
| Builder name `StratumTextStyle` | M2-T4 | |
| Default theme `spaceHeight` in px | M1-T3, M2-T5 | conformance test |
| Leading distribution `even` | M2-T5 | |
| Parse scope `typography:` only | M1-T3 | |
| Errors collected with paths | M1-T3 | |
| Section 9 cache and rebuild scope | M2-T5, M2-T6 | |
| Section 10 edge cases | M1-T3, M2-T5, M2-T6, M2-T7 | a family that is not bundled falls to Flutter's platform font; nothing to build |
| Section 11 tests | M1-T1 to M2-T7 | golden tests deferred by the spec |
| Section 11 manual Thai check | M2-T7 | the owner runs it (Step 7) |
| Section 12 verification | M2-T7 | |
| Test-first | every task | |
