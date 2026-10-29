// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'container_layout.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<ContainerLayout, StoryArgs<ContainerLayout>>;
typedef _Scenario = ContainerLayoutScenario;
typedef _Defaults = ContainerLayoutDefaults;
typedef _Story = ContainerLayoutStory;
typedef _Args = ContainerLayoutKnobsArgs;
final ContainerLayoutComponent =
    Component<ContainerLayout, StoryArgs<ContainerLayout>>(
      name: componentMeta.name ?? 'ContainerLayout',
      path: componentMeta.path ?? 'layout',
      docsBuilder: componentMeta.docsBuilder,
      docComment: r'''A box that paints a [WidgetStyle] around [child], or around the content
[builder] builds from the box's [InteractionState].

Every visual value (spacing, size, fill, border, shadows, blur, opacity,
and animation) comes from `style`, which [AnimatedStyledBox] builds and
animates. The other parameters come from [BoxLayout] and cover what a
style cannot: per-instance layout, interaction, behavior, and
accessibility.''',
      stories: [
        $Playground..$generatedName = 'Playground',
        $RecipeFormRow..$generatedName = 'RecipeFormRow',
        $RecipeCard..$generatedName = 'RecipeCard',
        $RecipeListItem..$generatedName = 'RecipeListItem',
        $RecipeToolbar..$generatedName = 'RecipeToolbar',
        $RecipePageWithDrawer..$generatedName = 'RecipePageWithDrawer',
        $Responsive..$generatedName = 'Responsive',
        $Accessibility..$generatedName = 'Accessibility',
        $ExampleFittedMedia..$generatedName = 'ExampleFittedMedia',
      ],
    );
typedef ContainerLayoutScenario =
    Scenario<ContainerLayout, ContainerLayoutKnobsArgs>;
typedef ContainerLayoutDefaults =
    Defaults<ContainerLayout, ContainerLayoutKnobsArgs>;

class ContainerLayoutStory
    extends Story<ContainerLayout, ContainerLayoutKnobsArgs> {
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

class ContainerLayoutKnobsArgs extends StoryArgs<ContainerLayout> {
  ContainerLayoutKnobsArgs({
    required Arg<Preset<WidgetStyle>> style,
    Arg<double?>? ratio,
    Arg<double?>? rotate,
    required Arg<Preset<Matrix4>> transform,
    required Arg<Preset<AlignmentGeometry>> transformAlignment,
    Arg<bool>? keepAlive,
    Arg<bool>? repaintBoundary,
    required Arg<Preset<SemanticsProperties>> semantics,
    Arg<bool>? onEndAnimate,
    required Arg<Preset<Interaction>> interaction,
    required Arg<Preset<Scroll>> scroll,
    Arg<BoxFit?>? fit,
    Arg<SlotPreset>? child,
    required Arg<Preset<Widget Function(BuildContext, InteractionState)>>
    builder,
  }) : this.styleArg = $initArg('style', style, null)!,
       this.ratioArg = $initArg('ratio', ratio, NullableDoubleArg(null))!,
       this.rotateArg = $initArg('rotate', rotate, NullableDoubleArg(null))!,
       this.transformArg = $initArg('transform', transform, null)!,
       this.transformAlignmentArg = $initArg(
         'transformAlignment',
         transformAlignment,
         null,
       )!,
       this.keepAliveArg = $initArg('keepAlive', keepAlive, BoolArg(false))!,
       this.repaintBoundaryArg = $initArg(
         'repaintBoundary',
         repaintBoundary,
         BoolArg(false),
       )!,
       this.semanticsArg = $initArg('semantics', semantics, null)!,
       this.onEndAnimateArg = $initArg(
         'onEndAnimate',
         onEndAnimate,
         BoolArg(true),
       )!,
       this.interactionArg = $initArg('interaction', interaction, null)!,
       this.scrollArg = $initArg('scroll', scroll, null)!,
       this.fitArg = $initArg(
         'fit',
         fit,
         NullableEnumArg<BoxFit>(null, values: BoxFit.values),
       )!,
       this.childArg = $initArg(
         'child',
         child,
         EnumArg<SlotPreset>(SlotPreset.slot, values: SlotPreset.values),
       )!,
       this.builderArg = $initArg('builder', builder, null)!;

  ContainerLayoutKnobsArgs.fixed({
    required Preset<WidgetStyle> style,
    double? ratio = null,
    double? rotate = null,
    required Preset<Matrix4> transform,
    required Preset<AlignmentGeometry> transformAlignment,
    bool keepAlive = false,
    bool repaintBoundary = false,
    required Preset<SemanticsProperties> semantics,
    bool onEndAnimate = true,
    required Preset<Interaction> interaction,
    required Preset<Scroll> scroll,
    BoxFit? fit = null,
    SlotPreset child = SlotPreset.slot,
    required Preset<Widget Function(BuildContext, InteractionState)> builder,
  }) : this.styleArg = $initArg('style', Arg.fixed(style), null)!,
       this.ratioArg = $initArg(
         'ratio',
         ratio == null ? null : Arg.fixed(ratio),
         null,
       ),
       this.rotateArg = $initArg(
         'rotate',
         rotate == null ? null : Arg.fixed(rotate),
         null,
       ),
       this.transformArg = $initArg('transform', Arg.fixed(transform), null)!,
       this.transformAlignmentArg = $initArg(
         'transformAlignment',
         Arg.fixed(transformAlignment),
         null,
       )!,
       this.keepAliveArg = $initArg('keepAlive', Arg.fixed(keepAlive), null)!,
       this.repaintBoundaryArg = $initArg(
         'repaintBoundary',
         Arg.fixed(repaintBoundary),
         null,
       )!,
       this.semanticsArg = $initArg('semantics', Arg.fixed(semantics), null)!,
       this.onEndAnimateArg = $initArg(
         'onEndAnimate',
         Arg.fixed(onEndAnimate),
         null,
       )!,
       this.interactionArg = $initArg(
         'interaction',
         Arg.fixed(interaction),
         null,
       )!,
       this.scrollArg = $initArg('scroll', Arg.fixed(scroll), null)!,
       this.fitArg = $initArg('fit', fit == null ? null : Arg.fixed(fit), null),
       this.childArg = $initArg('child', Arg.fixed(child), null)!,
       this.builderArg = $initArg('builder', Arg.fixed(builder), null)!;

  final Arg<Preset<WidgetStyle>> styleArg;

  final Arg<double?>? ratioArg;

  final Arg<double?>? rotateArg;

  final Arg<Preset<Matrix4>> transformArg;

  final Arg<Preset<AlignmentGeometry>> transformAlignmentArg;

  final Arg<bool> keepAliveArg;

  final Arg<bool> repaintBoundaryArg;

  final Arg<Preset<SemanticsProperties>> semanticsArg;

  final Arg<bool> onEndAnimateArg;

  final Arg<Preset<Interaction>> interactionArg;

  final Arg<Preset<Scroll>> scrollArg;

  final Arg<BoxFit?>? fitArg;

  final Arg<SlotPreset> childArg;

  final Arg<Preset<Widget Function(BuildContext, InteractionState)>> builderArg;

  Preset<WidgetStyle> get style => styleArg.value;

  double? get ratio => ratioArg?.value;

  double? get rotate => rotateArg?.value;

  Preset<Matrix4> get transform => transformArg.value;

  Preset<AlignmentGeometry> get transformAlignment =>
      transformAlignmentArg.value;

  bool get keepAlive => keepAliveArg.value;

  bool get repaintBoundary => repaintBoundaryArg.value;

  Preset<SemanticsProperties> get semantics => semanticsArg.value;

  bool get onEndAnimate => onEndAnimateArg.value;

  Preset<Interaction> get interaction => interactionArg.value;

  Preset<Scroll> get scroll => scrollArg.value;

  BoxFit? get fit => fitArg?.value;

  SlotPreset get child => childArg.value;

  Preset<Widget Function(BuildContext, InteractionState)> get builder =>
      builderArg.value;

  @override
  List<Arg?> get list => [
    styleArg,
    ratioArg,
    rotateArg,
    transformArg,
    transformAlignmentArg,
    keepAliveArg,
    repaintBoundaryArg,
    semanticsArg,
    onEndAnimateArg,
    interactionArg,
    scrollArg,
    fitArg,
    childArg,
    builderArg,
  ];
}
