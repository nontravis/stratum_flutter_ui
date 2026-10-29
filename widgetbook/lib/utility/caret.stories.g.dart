// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'caret.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<StratumCaret, StoryArgs<StratumCaret>>;
typedef _Scenario = StratumCaretScenario;
typedef _Defaults = StratumCaretDefaults;
typedef _Story = StratumCaretStory;
typedef _Args = CaretKnobsArgs;
final StratumCaretComponent = Component<StratumCaret, StoryArgs<StratumCaret>>(
  name: componentMeta.name ?? 'StratumCaret',
  path: componentMeta.path ?? 'utility',
  docsBuilder: componentMeta.docsBuilder,
  docComment:
      r'''Indicates that an element is **expandable** or that a **menu/dropdown
will appear** on interaction. The style variants control visual weight
to match the density of the surrounding UI.

Points [StratumCaretDirection.start] and [StratumCaretDirection.end] by
the ambient text direction, turns the short way when [direction]
changes, shows the new direction at once under reduced motion, and
stays out of the semantics tree: the owning component announces
expanded or collapsed.

## Use when

- A control toggles open a dropdown, select menu, or disclosure
- An interactive element needs a directional affordance to signal
  hidden content

## Don't use when

- Navigation between pages or sections — use a dedicated arrow or
  chevron icon instead
- Pagination or sequential movement — use directional arrows
- The element is purely decorative with no expand/collapse behavior

## Related

- Use a chevron or arrow icon instead when indicating **navigation
  direction** rather than expand/collapse

The base `color` picks the theme's `icon.color.<name>` token through
[resolveColor], else `icon.default.primary`. The caret takes no
`state`, `feedbackState`, `loading`, or `windowSize`, since none of
them changes its look and no caret code reads a window size (FO-08
US-01 FR-01 E03; R10(1)); its own `customStyle` styles the square box,
never the glyph.''',
  stories: [
    $Playground..$generatedName = 'Playground',
    $Variants..$generatedName = 'Variants',
    $Responsive..$generatedName = 'Responsive',
    $Accessibility..$generatedName = 'Accessibility',
    $ExampleDropdownTrigger..$generatedName = 'ExampleDropdownTrigger',
  ],
);
typedef StratumCaretScenario = Scenario<StratumCaret, CaretKnobsArgs>;
typedef StratumCaretDefaults = Defaults<StratumCaret, CaretKnobsArgs>;

class StratumCaretStory extends Story<StratumCaret, CaretKnobsArgs> {
  StratumCaretStory({
    super.name,
    super.designLink,
    super.setup,
    super.modes,
    required super.args,
    required super.builder,
    super.scenarios,
    super.excludeFromTests,
  });
}

class CaretKnobsArgs extends StoryArgs<StratumCaret> {
  CaretKnobsArgs({
    Arg<StratumCaretGlyph>? style,
    Arg<StratumCaretDirection>? direction,
    Arg<WidgetSize?>? size,
    Arg<double?>? customSize,
    Arg<ColorEnum?>? color,
    Arg<Color?>? customColor,
    Arg<ThemeMode?>? themeMode,
    Arg<bool>? disabled,
    required Arg<Preset<StratumCaretStyle>> customStyle,
  }) : this.styleArg = $initArg(
         'style',
         style,
         EnumArg<StratumCaretGlyph>(
           StratumCaretGlyph.regular,
           values: StratumCaretGlyph.values,
         ),
       )!,
       this.directionArg = $initArg(
         'direction',
         direction,
         EnumArg<StratumCaretDirection>(
           StratumCaretDirection.down,
           values: StratumCaretDirection.values,
         ),
       )!,
       this.sizeArg = $initArg(
         'size',
         size,
         NullableEnumArg<WidgetSize>(null, values: WidgetSize.values),
       )!,
       this.customSizeArg = $initArg(
         'customSize',
         customSize,
         NullableDoubleArg(null),
       )!,
       this.colorArg = $initArg(
         'color',
         color,
         NullableEnumArg<ColorEnum>(null, values: ColorEnum.values),
       )!,
       this.customColorArg = $initArg(
         'customColor',
         customColor,
         NullableColorArg(null),
       )!,
       this.themeModeArg = $initArg(
         'themeMode',
         themeMode,
         NullableEnumArg<ThemeMode>(null, values: ThemeMode.values),
       )!,
       this.disabledArg = $initArg('disabled', disabled, BoolArg(false))!,
       this.customStyleArg = $initArg('customStyle', customStyle, null)!;

  CaretKnobsArgs.fixed({
    StratumCaretGlyph style = StratumCaretGlyph.regular,
    StratumCaretDirection direction = StratumCaretDirection.down,
    WidgetSize? size = null,
    double? customSize = null,
    ColorEnum? color = null,
    Color? customColor = null,
    ThemeMode? themeMode = null,
    bool disabled = false,
    required Preset<StratumCaretStyle> customStyle,
  }) : this.styleArg = $initArg('style', Arg.fixed(style), null)!,
       this.directionArg = $initArg('direction', Arg.fixed(direction), null)!,
       this.sizeArg = $initArg(
         'size',
         size == null ? null : Arg.fixed(size),
         null,
       ),
       this.customSizeArg = $initArg(
         'customSize',
         customSize == null ? null : Arg.fixed(customSize),
         null,
       ),
       this.colorArg = $initArg(
         'color',
         color == null ? null : Arg.fixed(color),
         null,
       ),
       this.customColorArg = $initArg(
         'customColor',
         customColor == null ? null : Arg.fixed(customColor),
         null,
       ),
       this.themeModeArg = $initArg(
         'themeMode',
         themeMode == null ? null : Arg.fixed(themeMode),
         null,
       ),
       this.disabledArg = $initArg('disabled', Arg.fixed(disabled), null)!,
       this.customStyleArg = $initArg(
         'customStyle',
         Arg.fixed(customStyle),
         null,
       )!;

  final Arg<StratumCaretGlyph> styleArg;

  final Arg<StratumCaretDirection> directionArg;

  final Arg<WidgetSize?>? sizeArg;

  final Arg<double?>? customSizeArg;

  final Arg<ColorEnum?>? colorArg;

  final Arg<Color?>? customColorArg;

  final Arg<ThemeMode?>? themeModeArg;

  final Arg<bool> disabledArg;

  final Arg<Preset<StratumCaretStyle>> customStyleArg;

  StratumCaretGlyph get style => styleArg.value;

  StratumCaretDirection get direction => directionArg.value;

  WidgetSize? get size => sizeArg?.value;

  double? get customSize => customSizeArg?.value;

  ColorEnum? get color => colorArg?.value;

  Color? get customColor => customColorArg?.value;

  ThemeMode? get themeMode => themeModeArg?.value;

  bool get disabled => disabledArg.value;

  Preset<StratumCaretStyle> get customStyle => customStyleArg.value;

  @override
  List<Arg?> get list => [
    styleArg,
    directionArg,
    sizeArg,
    customSizeArg,
    colorArg,
    customColorArg,
    themeModeArg,
    disabledArg,
    customStyleArg,
  ];
}
