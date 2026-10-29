// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'widget_style.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<ContainerLayout, StoryArgs<ContainerLayout>>;
typedef _Scenario = ContainerLayoutScenario;
typedef _Defaults = ContainerLayoutDefaults;
typedef _Story = ContainerLayoutStory;
typedef _Args = WidgetStyleKnobsArgs;
final ContainerLayoutComponent =
    Component<ContainerLayout, StoryArgs<ContainerLayout>>(
      name: componentMeta.name ?? 'ContainerLayout',
      path: componentMeta.path ?? 'foundation',
      docsBuilder: componentMeta.docsBuilder,
      docComment: r'''A box that paints a [WidgetStyle] around [child], or around the content
[builder] builds from the box's [InteractionState].

Every visual value (spacing, size, fill, border, shadows, blur, opacity,
and animation) comes from `style`, which [AnimatedStyledBox] builds and
animates. The other parameters come from [BoxLayout] and cover what a
style cannot: per-instance layout, interaction, behavior, and
accessibility.''',
      stories: [$Playground..$generatedName = 'Playground'],
    );
typedef ContainerLayoutScenario =
    Scenario<ContainerLayout, WidgetStyleKnobsArgs>;
typedef ContainerLayoutDefaults =
    Defaults<ContainerLayout, WidgetStyleKnobsArgs>;

class ContainerLayoutStory
    extends Story<ContainerLayout, WidgetStyleKnobsArgs> {
  ContainerLayoutStory({
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

class WidgetStyleKnobsArgs extends StoryArgs<ContainerLayout> {
  WidgetStyleKnobsArgs({
    Arg<double>? opacity,
    Arg<double>? padding,
    Arg<double>? margin,
    Arg<double?>? width,
    Arg<double?>? height,
    Arg<double?>? minWidth,
    Arg<double?>? maxWidth,
    Arg<double?>? minHeight,
    Arg<double?>? maxHeight,
    required Arg<Preset<AlignmentGeometry>> alignment,
    Arg<double>? border,
    Arg<double>? borderRadius,
    Arg<Color?>? backgroundColor,
    required Arg<Preset<Gradient>> backgroundGradient,
    required Arg<Preset<DecorationImage>> backgroundImage,
    Arg<double>? backgroundBlur,
    Arg<Color?>? foregroundColor,
    required Arg<Preset<Gradient>> foregroundGradient,
    required Arg<Preset<DecorationImage>> foregroundImage,
    Arg<double>? foregroundBlur,
    Arg<Clip?>? clipBehavior,
    required Arg<Preset<List<BoxShadow>>> innerShadow,
    required Arg<Preset<List<BoxShadow>>> dropShadow,
    Arg<Duration>? animationStyle,
  }) : this.opacityArg = $initArg('opacity', opacity, DoubleArg(1))!,
       this.paddingArg = $initArg('padding', padding, DoubleArg(0))!,
       this.marginArg = $initArg('margin', margin, DoubleArg(0))!,
       this.widthArg = $initArg('width', width, NullableDoubleArg(null))!,
       this.heightArg = $initArg('height', height, NullableDoubleArg(null))!,
       this.minWidthArg = $initArg(
         'minWidth',
         minWidth,
         NullableDoubleArg(null),
       )!,
       this.maxWidthArg = $initArg(
         'maxWidth',
         maxWidth,
         NullableDoubleArg(null),
       )!,
       this.minHeightArg = $initArg(
         'minHeight',
         minHeight,
         NullableDoubleArg(null),
       )!,
       this.maxHeightArg = $initArg(
         'maxHeight',
         maxHeight,
         NullableDoubleArg(null),
       )!,
       this.alignmentArg = $initArg('alignment', alignment, null)!,
       this.borderArg = $initArg('border', border, DoubleArg(0))!,
       this.borderRadiusArg = $initArg(
         'borderRadius',
         borderRadius,
         DoubleArg(0),
       )!,
       this.backgroundColorArg = $initArg(
         'backgroundColor',
         backgroundColor,
         NullableColorArg(null),
       )!,
       this.backgroundGradientArg = $initArg(
         'backgroundGradient',
         backgroundGradient,
         null,
       )!,
       this.backgroundImageArg = $initArg(
         'backgroundImage',
         backgroundImage,
         null,
       )!,
       this.backgroundBlurArg = $initArg(
         'backgroundBlur',
         backgroundBlur,
         DoubleArg(0),
       )!,
       this.foregroundColorArg = $initArg(
         'foregroundColor',
         foregroundColor,
         NullableColorArg(null),
       )!,
       this.foregroundGradientArg = $initArg(
         'foregroundGradient',
         foregroundGradient,
         null,
       )!,
       this.foregroundImageArg = $initArg(
         'foregroundImage',
         foregroundImage,
         null,
       )!,
       this.foregroundBlurArg = $initArg(
         'foregroundBlur',
         foregroundBlur,
         DoubleArg(0),
       )!,
       this.clipBehaviorArg = $initArg(
         'clipBehavior',
         clipBehavior,
         NullableEnumArg<Clip>(null, values: Clip.values),
       )!,
       this.innerShadowArg = $initArg('innerShadow', innerShadow, null)!,
       this.dropShadowArg = $initArg('dropShadow', dropShadow, null)!,
       this.animationStyleArg = $initArg(
         'animationStyle',
         animationStyle,
         DurationArg(const Duration(milliseconds: 200)),
       )!;

  WidgetStyleKnobsArgs.fixed({
    double opacity = 1,
    double padding = 0,
    double margin = 0,
    double? width = null,
    double? height = null,
    double? minWidth = null,
    double? maxWidth = null,
    double? minHeight = null,
    double? maxHeight = null,
    required Preset<AlignmentGeometry> alignment,
    double border = 0,
    double borderRadius = 0,
    Color? backgroundColor = null,
    required Preset<Gradient> backgroundGradient,
    required Preset<DecorationImage> backgroundImage,
    double backgroundBlur = 0,
    Color? foregroundColor = null,
    required Preset<Gradient> foregroundGradient,
    required Preset<DecorationImage> foregroundImage,
    double foregroundBlur = 0,
    Clip? clipBehavior = null,
    required Preset<List<BoxShadow>> innerShadow,
    required Preset<List<BoxShadow>> dropShadow,
    Duration animationStyle = const Duration(milliseconds: 200),
  }) : this.opacityArg = $initArg('opacity', Arg.fixed(opacity), null)!,
       this.paddingArg = $initArg('padding', Arg.fixed(padding), null)!,
       this.marginArg = $initArg('margin', Arg.fixed(margin), null)!,
       this.widthArg = $initArg(
         'width',
         width == null ? null : Arg.fixed(width),
         null,
       ),
       this.heightArg = $initArg(
         'height',
         height == null ? null : Arg.fixed(height),
         null,
       ),
       this.minWidthArg = $initArg(
         'minWidth',
         minWidth == null ? null : Arg.fixed(minWidth),
         null,
       ),
       this.maxWidthArg = $initArg(
         'maxWidth',
         maxWidth == null ? null : Arg.fixed(maxWidth),
         null,
       ),
       this.minHeightArg = $initArg(
         'minHeight',
         minHeight == null ? null : Arg.fixed(minHeight),
         null,
       ),
       this.maxHeightArg = $initArg(
         'maxHeight',
         maxHeight == null ? null : Arg.fixed(maxHeight),
         null,
       ),
       this.alignmentArg = $initArg('alignment', Arg.fixed(alignment), null)!,
       this.borderArg = $initArg('border', Arg.fixed(border), null)!,
       this.borderRadiusArg = $initArg(
         'borderRadius',
         Arg.fixed(borderRadius),
         null,
       )!,
       this.backgroundColorArg = $initArg(
         'backgroundColor',
         backgroundColor == null ? null : Arg.fixed(backgroundColor),
         null,
       ),
       this.backgroundGradientArg = $initArg(
         'backgroundGradient',
         Arg.fixed(backgroundGradient),
         null,
       )!,
       this.backgroundImageArg = $initArg(
         'backgroundImage',
         Arg.fixed(backgroundImage),
         null,
       )!,
       this.backgroundBlurArg = $initArg(
         'backgroundBlur',
         Arg.fixed(backgroundBlur),
         null,
       )!,
       this.foregroundColorArg = $initArg(
         'foregroundColor',
         foregroundColor == null ? null : Arg.fixed(foregroundColor),
         null,
       ),
       this.foregroundGradientArg = $initArg(
         'foregroundGradient',
         Arg.fixed(foregroundGradient),
         null,
       )!,
       this.foregroundImageArg = $initArg(
         'foregroundImage',
         Arg.fixed(foregroundImage),
         null,
       )!,
       this.foregroundBlurArg = $initArg(
         'foregroundBlur',
         Arg.fixed(foregroundBlur),
         null,
       )!,
       this.clipBehaviorArg = $initArg(
         'clipBehavior',
         clipBehavior == null ? null : Arg.fixed(clipBehavior),
         null,
       ),
       this.innerShadowArg = $initArg(
         'innerShadow',
         Arg.fixed(innerShadow),
         null,
       )!,
       this.dropShadowArg = $initArg(
         'dropShadow',
         Arg.fixed(dropShadow),
         null,
       )!,
       this.animationStyleArg = $initArg(
         'animationStyle',
         Arg.fixed(animationStyle),
         null,
       )!;

  final Arg<double> opacityArg;

  final Arg<double> paddingArg;

  final Arg<double> marginArg;

  final Arg<double?>? widthArg;

  final Arg<double?>? heightArg;

  final Arg<double?>? minWidthArg;

  final Arg<double?>? maxWidthArg;

  final Arg<double?>? minHeightArg;

  final Arg<double?>? maxHeightArg;

  final Arg<Preset<AlignmentGeometry>> alignmentArg;

  final Arg<double> borderArg;

  final Arg<double> borderRadiusArg;

  final Arg<Color?>? backgroundColorArg;

  final Arg<Preset<Gradient>> backgroundGradientArg;

  final Arg<Preset<DecorationImage>> backgroundImageArg;

  final Arg<double> backgroundBlurArg;

  final Arg<Color?>? foregroundColorArg;

  final Arg<Preset<Gradient>> foregroundGradientArg;

  final Arg<Preset<DecorationImage>> foregroundImageArg;

  final Arg<double> foregroundBlurArg;

  final Arg<Clip?>? clipBehaviorArg;

  final Arg<Preset<List<BoxShadow>>> innerShadowArg;

  final Arg<Preset<List<BoxShadow>>> dropShadowArg;

  final Arg<Duration> animationStyleArg;

  double get opacity => opacityArg.value;

  double get padding => paddingArg.value;

  double get margin => marginArg.value;

  double? get width => widthArg?.value;

  double? get height => heightArg?.value;

  double? get minWidth => minWidthArg?.value;

  double? get maxWidth => maxWidthArg?.value;

  double? get minHeight => minHeightArg?.value;

  double? get maxHeight => maxHeightArg?.value;

  Preset<AlignmentGeometry> get alignment => alignmentArg.value;

  double get border => borderArg.value;

  double get borderRadius => borderRadiusArg.value;

  Color? get backgroundColor => backgroundColorArg?.value;

  Preset<Gradient> get backgroundGradient => backgroundGradientArg.value;

  Preset<DecorationImage> get backgroundImage => backgroundImageArg.value;

  double get backgroundBlur => backgroundBlurArg.value;

  Color? get foregroundColor => foregroundColorArg?.value;

  Preset<Gradient> get foregroundGradient => foregroundGradientArg.value;

  Preset<DecorationImage> get foregroundImage => foregroundImageArg.value;

  double get foregroundBlur => foregroundBlurArg.value;

  Clip? get clipBehavior => clipBehaviorArg?.value;

  Preset<List<BoxShadow>> get innerShadow => innerShadowArg.value;

  Preset<List<BoxShadow>> get dropShadow => dropShadowArg.value;

  Duration get animationStyle => animationStyleArg.value;

  @override
  List<Arg?> get list => [
    opacityArg,
    paddingArg,
    marginArg,
    widthArg,
    heightArg,
    minWidthArg,
    maxWidthArg,
    minHeightArg,
    maxHeightArg,
    alignmentArg,
    borderArg,
    borderRadiusArg,
    backgroundColorArg,
    backgroundGradientArg,
    backgroundImageArg,
    backgroundBlurArg,
    foregroundColorArg,
    foregroundGradientArg,
    foregroundImageArg,
    foregroundBlurArg,
    clipBehaviorArg,
    innerShadowArg,
    dropShadowArg,
    animationStyleArg,
  ];
}
