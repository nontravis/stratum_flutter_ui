// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'wrap_layout.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<WrapLayout, StoryArgs<WrapLayout>>;
typedef _Scenario = WrapLayoutScenario;
typedef _Defaults = WrapLayoutDefaults;
typedef _Story = WrapLayoutStory;
typedef _Args = WrapLayoutKnobsArgs;
final WrapLayoutComponent = Component<WrapLayout, StoryArgs<WrapLayout>>(
  name: componentMeta.name ?? 'WrapLayout',
  path: componentMeta.path ?? 'layout',
  docsBuilder: componentMeta.docsBuilder,
  docComment:
      r'''A [Wrap] on [BoxLayout]: style, interaction, semantics, and scrolling
come from the base class.

`scroll` scrolls across [direction], so a horizontal wrap keeps its
width, wraps into runs, and scrolls vertically.

[maxRuns], [maxChildren], and [overflowBuilder] cut the wrap and count
what they hide (US-14). With all three null the wrap builds Flutter's
[Wrap], unchanged; otherwise it lays out by [Wrap]'s run rules and cuts
its children. A limit or [overflowBuilder] cannot go with `scroll`.''',
  stories: [
    $Playground..$generatedName = 'Playground',
    $RecipeFormRow..$generatedName = 'RecipeFormRow',
    $RecipeCard..$generatedName = 'RecipeCard',
    $RecipeListItem..$generatedName = 'RecipeListItem',
    $RecipeToolbar..$generatedName = 'RecipeToolbar',
    $RecipePageWithDrawer..$generatedName = 'RecipePageWithDrawer',
    $Responsive..$generatedName = 'Responsive',
    $Accessibility..$generatedName = 'Accessibility',
    $ExampleTagsCutToTwoRuns..$generatedName = 'ExampleTagsCutToTwoRuns',
  ],
);
typedef WrapLayoutScenario = Scenario<WrapLayout, WrapLayoutKnobsArgs>;
typedef WrapLayoutDefaults = Defaults<WrapLayout, WrapLayoutKnobsArgs>;

class WrapLayoutStory extends Story<WrapLayout, WrapLayoutKnobsArgs> {
  WrapLayoutStory({
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

class WrapLayoutKnobsArgs extends StoryArgs<WrapLayout> {
  WrapLayoutKnobsArgs({
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
    Arg<Axis>? direction,
    Arg<WrapAlignment>? alignment,
    Arg<double?>? gap,
    Arg<double?>? runGap,
    Arg<WrapAlignment>? runAlignment,
    Arg<WrapCrossAlignment>? crossAxisAlignment,
    Arg<TextDirection?>? textDirection,
    Arg<VerticalDirection>? verticalDirection,
    Arg<Clip>? clipBehavior,
    required Arg<Preset<FocusGroup>> focusGroup,
    Arg<int?>? maxRuns,
    Arg<int?>? maxChildren,
    required Arg<Preset<Widget Function(BuildContext, int)>> overflowBuilder,
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
       this.directionArg = $initArg(
         'direction',
         direction,
         EnumArg<Axis>(Axis.horizontal, values: Axis.values),
       )!,
       this.alignmentArg = $initArg(
         'alignment',
         alignment,
         EnumArg<WrapAlignment>(
           WrapAlignment.start,
           values: WrapAlignment.values,
         ),
       )!,
       this.gapArg = $initArg('gap', gap, NullableDoubleArg(null))!,
       this.runGapArg = $initArg('runGap', runGap, NullableDoubleArg(null))!,
       this.runAlignmentArg = $initArg(
         'runAlignment',
         runAlignment,
         EnumArg<WrapAlignment>(
           WrapAlignment.start,
           values: WrapAlignment.values,
         ),
       )!,
       this.crossAxisAlignmentArg = $initArg(
         'crossAxisAlignment',
         crossAxisAlignment,
         EnumArg<WrapCrossAlignment>(
           WrapCrossAlignment.start,
           values: WrapCrossAlignment.values,
         ),
       )!,
       this.textDirectionArg = $initArg(
         'textDirection',
         textDirection,
         NullableEnumArg<TextDirection>(null, values: TextDirection.values),
       )!,
       this.verticalDirectionArg = $initArg(
         'verticalDirection',
         verticalDirection,
         EnumArg<VerticalDirection>(
           VerticalDirection.down,
           values: VerticalDirection.values,
         ),
       )!,
       this.clipBehaviorArg = $initArg(
         'clipBehavior',
         clipBehavior,
         EnumArg<Clip>(Clip.none, values: Clip.values),
       )!,
       this.focusGroupArg = $initArg('focusGroup', focusGroup, null)!,
       this.maxRunsArg = $initArg('maxRuns', maxRuns, NullableIntArg(null))!,
       this.maxChildrenArg = $initArg(
         'maxChildren',
         maxChildren,
         NullableIntArg(null),
       )!,
       this.overflowBuilderArg = $initArg(
         'overflowBuilder',
         overflowBuilder,
         null,
       )!,
       this.childrenArg = $initArg('children', children, IntArg(3))!;

  WrapLayoutKnobsArgs.fixed({
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
    Axis direction = Axis.horizontal,
    WrapAlignment alignment = WrapAlignment.start,
    double? gap = null,
    double? runGap = null,
    WrapAlignment runAlignment = WrapAlignment.start,
    WrapCrossAlignment crossAxisAlignment = WrapCrossAlignment.start,
    TextDirection? textDirection = null,
    VerticalDirection verticalDirection = VerticalDirection.down,
    Clip clipBehavior = Clip.none,
    required Preset<FocusGroup> focusGroup,
    int? maxRuns = null,
    int? maxChildren = null,
    required Preset<Widget Function(BuildContext, int)> overflowBuilder,
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
       this.directionArg = $initArg('direction', Arg.fixed(direction), null)!,
       this.alignmentArg = $initArg('alignment', Arg.fixed(alignment), null)!,
       this.gapArg = $initArg('gap', gap == null ? null : Arg.fixed(gap), null),
       this.runGapArg = $initArg(
         'runGap',
         runGap == null ? null : Arg.fixed(runGap),
         null,
       ),
       this.runAlignmentArg = $initArg(
         'runAlignment',
         Arg.fixed(runAlignment),
         null,
       )!,
       this.crossAxisAlignmentArg = $initArg(
         'crossAxisAlignment',
         Arg.fixed(crossAxisAlignment),
         null,
       )!,
       this.textDirectionArg = $initArg(
         'textDirection',
         textDirection == null ? null : Arg.fixed(textDirection),
         null,
       ),
       this.verticalDirectionArg = $initArg(
         'verticalDirection',
         Arg.fixed(verticalDirection),
         null,
       )!,
       this.clipBehaviorArg = $initArg(
         'clipBehavior',
         Arg.fixed(clipBehavior),
         null,
       )!,
       this.focusGroupArg = $initArg(
         'focusGroup',
         Arg.fixed(focusGroup),
         null,
       )!,
       this.maxRunsArg = $initArg(
         'maxRuns',
         maxRuns == null ? null : Arg.fixed(maxRuns),
         null,
       ),
       this.maxChildrenArg = $initArg(
         'maxChildren',
         maxChildren == null ? null : Arg.fixed(maxChildren),
         null,
       ),
       this.overflowBuilderArg = $initArg(
         'overflowBuilder',
         Arg.fixed(overflowBuilder),
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

  final Arg<Axis> directionArg;

  final Arg<WrapAlignment> alignmentArg;

  final Arg<double?>? gapArg;

  final Arg<double?>? runGapArg;

  final Arg<WrapAlignment> runAlignmentArg;

  final Arg<WrapCrossAlignment> crossAxisAlignmentArg;

  final Arg<TextDirection?>? textDirectionArg;

  final Arg<VerticalDirection> verticalDirectionArg;

  final Arg<Clip> clipBehaviorArg;

  final Arg<Preset<FocusGroup>> focusGroupArg;

  final Arg<int?>? maxRunsArg;

  final Arg<int?>? maxChildrenArg;

  final Arg<Preset<Widget Function(BuildContext, int)>> overflowBuilderArg;

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

  Axis get direction => directionArg.value;

  WrapAlignment get alignment => alignmentArg.value;

  double? get gap => gapArg?.value;

  double? get runGap => runGapArg?.value;

  WrapAlignment get runAlignment => runAlignmentArg.value;

  WrapCrossAlignment get crossAxisAlignment => crossAxisAlignmentArg.value;

  TextDirection? get textDirection => textDirectionArg?.value;

  VerticalDirection get verticalDirection => verticalDirectionArg.value;

  Clip get clipBehavior => clipBehaviorArg.value;

  Preset<FocusGroup> get focusGroup => focusGroupArg.value;

  int? get maxRuns => maxRunsArg?.value;

  int? get maxChildren => maxChildrenArg?.value;

  Preset<Widget Function(BuildContext, int)> get overflowBuilder =>
      overflowBuilderArg.value;

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
    directionArg,
    alignmentArg,
    gapArg,
    runGapArg,
    runAlignmentArg,
    crossAxisAlignmentArg,
    textDirectionArg,
    verticalDirectionArg,
    clipBehaviorArg,
    focusGroupArg,
    maxRunsArg,
    maxChildrenArg,
    overflowBuilderArg,
    childrenArg,
  ];
}
