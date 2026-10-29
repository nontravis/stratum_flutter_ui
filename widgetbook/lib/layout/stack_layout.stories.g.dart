// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'stack_layout.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<StackLayout, StoryArgs<StackLayout>>;
typedef _Scenario = StackLayoutScenario;
typedef _Defaults = StackLayoutDefaults;
typedef _Story = StackLayoutStory;
typedef _Args = StackLayoutKnobsArgs;
final StackLayoutComponent = Component<StackLayout, StoryArgs<StackLayout>>(
  name: componentMeta.name ?? 'StackLayout',
  path: componentMeta.path ?? 'layout',
  docsBuilder: componentMeta.docsBuilder,
  docComment:
      r'''A [Stack] on [BoxLayout]: style, interaction, semantics, and scrolling
come from the base class.

[clipBehavior] clips the stack's own children; the box clips through
`style.clipBehavior`. `scroll` scrolls vertically unless its `direction`
says otherwise.''',
  stories: [
    $Playground..$generatedName = 'Playground',
    $RecipeFormRow..$generatedName = 'RecipeFormRow',
    $RecipeCard..$generatedName = 'RecipeCard',
    $RecipeListItem..$generatedName = 'RecipeListItem',
    $RecipeToolbar..$generatedName = 'RecipeToolbar',
    $RecipePageWithDrawer..$generatedName = 'RecipePageWithDrawer',
    $Responsive..$generatedName = 'Responsive',
    $Accessibility..$generatedName = 'Accessibility',
    $ExampleBadgeOverAvatar..$generatedName = 'ExampleBadgeOverAvatar',
  ],
);
typedef StackLayoutScenario = Scenario<StackLayout, StackLayoutKnobsArgs>;
typedef StackLayoutDefaults = Defaults<StackLayout, StackLayoutKnobsArgs>;

class StackLayoutStory extends Story<StackLayout, StackLayoutKnobsArgs> {
  StackLayoutStory({
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

class StackLayoutKnobsArgs extends StoryArgs<StackLayout> {
  StackLayoutKnobsArgs({
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
    required Arg<Preset<AlignmentGeometry>> alignment,
    Arg<StackFit>? fit,
    Arg<TextDirection?>? textDirection,
    Arg<Clip>? clipBehavior,
    Arg<int>? children,
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
       this.alignmentArg = $initArg('alignment', alignment, null)!,
       this.fitArg = $initArg(
         'fit',
         fit,
         EnumArg<StackFit>(StackFit.loose, values: StackFit.values),
       )!,
       this.textDirectionArg = $initArg(
         'textDirection',
         textDirection,
         NullableEnumArg<TextDirection>(null, values: TextDirection.values),
       )!,
       this.clipBehaviorArg = $initArg(
         'clipBehavior',
         clipBehavior,
         EnumArg<Clip>(Clip.hardEdge, values: Clip.values),
       )!,
       this.childrenArg = $initArg('children', children, IntArg(3))!;

  StackLayoutKnobsArgs.fixed({
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
    required Preset<AlignmentGeometry> alignment,
    StackFit fit = StackFit.loose,
    TextDirection? textDirection = null,
    Clip clipBehavior = Clip.hardEdge,
    int children = 3,
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
       this.alignmentArg = $initArg('alignment', Arg.fixed(alignment), null)!,
       this.fitArg = $initArg('fit', Arg.fixed(fit), null)!,
       this.textDirectionArg = $initArg(
         'textDirection',
         textDirection == null ? null : Arg.fixed(textDirection),
         null,
       ),
       this.clipBehaviorArg = $initArg(
         'clipBehavior',
         Arg.fixed(clipBehavior),
         null,
       )!,
       this.childrenArg = $initArg('children', Arg.fixed(children), null)!;

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

  final Arg<Preset<AlignmentGeometry>> alignmentArg;

  final Arg<StackFit> fitArg;

  final Arg<TextDirection?>? textDirectionArg;

  final Arg<Clip> clipBehaviorArg;

  final Arg<int> childrenArg;

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

  Preset<AlignmentGeometry> get alignment => alignmentArg.value;

  StackFit get fit => fitArg.value;

  TextDirection? get textDirection => textDirectionArg?.value;

  Clip get clipBehavior => clipBehaviorArg.value;

  int get children => childrenArg.value;

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
    alignmentArg,
    fitArg,
    textDirectionArg,
    clipBehaviorArg,
    childrenArg,
  ];
}
