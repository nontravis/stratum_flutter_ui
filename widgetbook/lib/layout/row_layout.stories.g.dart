// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'row_layout.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<RowLayout, StoryArgs<RowLayout>>;
typedef _Scenario = RowLayoutScenario;
typedef _Defaults = RowLayoutDefaults;
typedef _Story = RowLayoutStory;
typedef _Args = FlexAxisKnobsArgs;
final RowLayoutComponent = Component<RowLayout, StoryArgs<RowLayout>>(
  name: componentMeta.name ?? 'RowLayout',
  path: componentMeta.path ?? 'layout',
  docsBuilder: componentMeta.docsBuilder,
  docComment: r'''A row on [FlexLayout]: style, interaction, semantics, and scrolling come
from [BoxLayout].

A width or max width in `style` forces [MainAxisSize.max], so the row
fills the width it is given. `gap` becomes [Flex.spacing], and `scroll`
scrolls horizontally unless its `direction` says otherwise.''',
  stories: [
    $Playground..$generatedName = 'Playground',
    $RecipeFormRow..$generatedName = 'RecipeFormRow',
    $RecipeCard..$generatedName = 'RecipeCard',
    $RecipeListItem..$generatedName = 'RecipeListItem',
    $RecipeToolbar..$generatedName = 'RecipeToolbar',
    $RecipePageWithDrawer..$generatedName = 'RecipePageWithDrawer',
    $Responsive..$generatedName = 'Responsive',
    $Accessibility..$generatedName = 'Accessibility',
    $ExamplePlainRow..$generatedName = 'ExamplePlainRow',
  ],
);
typedef RowLayoutScenario = Scenario<RowLayout, FlexAxisKnobsArgs>;
typedef RowLayoutDefaults = Defaults<RowLayout, FlexAxisKnobsArgs>;

class RowLayoutStory extends Story<RowLayout, FlexAxisKnobsArgs> {
  RowLayoutStory({
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

class FlexAxisKnobsArgs extends StoryArgs<RowLayout> {
  FlexAxisKnobsArgs({
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
    Arg<MainAxisAlignment>? mainAxisAlignment,
    Arg<MainAxisSize>? mainAxisSize,
    Arg<CrossAxisAlignment>? crossAxisAlignment,
    Arg<TextDirection?>? textDirection,
    Arg<VerticalDirection>? verticalDirection,
    Arg<TextBaseline?>? textBaseline,
    Arg<bool>? crossAxisIntrinsic,
    Arg<double?>? gap,
    required Arg<Preset<FocusGroup>> focusGroup,
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
       this.mainAxisAlignmentArg = $initArg(
         'mainAxisAlignment',
         mainAxisAlignment,
         EnumArg<MainAxisAlignment>(
           MainAxisAlignment.start,
           values: MainAxisAlignment.values,
         ),
       )!,
       this.mainAxisSizeArg = $initArg(
         'mainAxisSize',
         mainAxisSize,
         EnumArg<MainAxisSize>(MainAxisSize.max, values: MainAxisSize.values),
       )!,
       this.crossAxisAlignmentArg = $initArg(
         'crossAxisAlignment',
         crossAxisAlignment,
         EnumArg<CrossAxisAlignment>(
           CrossAxisAlignment.center,
           values: CrossAxisAlignment.values,
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
       this.textBaselineArg = $initArg(
         'textBaseline',
         textBaseline,
         NullableEnumArg<TextBaseline>(null, values: TextBaseline.values),
       )!,
       this.crossAxisIntrinsicArg = $initArg(
         'crossAxisIntrinsic',
         crossAxisIntrinsic,
         BoolArg(false),
       )!,
       this.gapArg = $initArg('gap', gap, NullableDoubleArg(null))!,
       this.focusGroupArg = $initArg('focusGroup', focusGroup, null)!,
       this.childrenArg = $initArg('children', children, IntArg(3))!;

  FlexAxisKnobsArgs.fixed({
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
    MainAxisAlignment mainAxisAlignment = MainAxisAlignment.start,
    MainAxisSize mainAxisSize = MainAxisSize.max,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
    TextDirection? textDirection = null,
    VerticalDirection verticalDirection = VerticalDirection.down,
    TextBaseline? textBaseline = null,
    bool crossAxisIntrinsic = false,
    double? gap = null,
    required Preset<FocusGroup> focusGroup,
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
       this.mainAxisAlignmentArg = $initArg(
         'mainAxisAlignment',
         Arg.fixed(mainAxisAlignment),
         null,
       )!,
       this.mainAxisSizeArg = $initArg(
         'mainAxisSize',
         Arg.fixed(mainAxisSize),
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
       this.textBaselineArg = $initArg(
         'textBaseline',
         textBaseline == null ? null : Arg.fixed(textBaseline),
         null,
       ),
       this.crossAxisIntrinsicArg = $initArg(
         'crossAxisIntrinsic',
         Arg.fixed(crossAxisIntrinsic),
         null,
       )!,
       this.gapArg = $initArg('gap', gap == null ? null : Arg.fixed(gap), null),
       this.focusGroupArg = $initArg(
         'focusGroup',
         Arg.fixed(focusGroup),
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

  final Arg<MainAxisAlignment> mainAxisAlignmentArg;

  final Arg<MainAxisSize> mainAxisSizeArg;

  final Arg<CrossAxisAlignment> crossAxisAlignmentArg;

  final Arg<TextDirection?>? textDirectionArg;

  final Arg<VerticalDirection> verticalDirectionArg;

  final Arg<TextBaseline?>? textBaselineArg;

  final Arg<bool> crossAxisIntrinsicArg;

  final Arg<double?>? gapArg;

  final Arg<Preset<FocusGroup>> focusGroupArg;

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

  MainAxisAlignment get mainAxisAlignment => mainAxisAlignmentArg.value;

  MainAxisSize get mainAxisSize => mainAxisSizeArg.value;

  CrossAxisAlignment get crossAxisAlignment => crossAxisAlignmentArg.value;

  TextDirection? get textDirection => textDirectionArg?.value;

  VerticalDirection get verticalDirection => verticalDirectionArg.value;

  TextBaseline? get textBaseline => textBaselineArg?.value;

  bool get crossAxisIntrinsic => crossAxisIntrinsicArg.value;

  double? get gap => gapArg?.value;

  Preset<FocusGroup> get focusGroup => focusGroupArg.value;

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
    mainAxisAlignmentArg,
    mainAxisSizeArg,
    crossAxisAlignmentArg,
    textDirectionArg,
    verticalDirectionArg,
    textBaselineArg,
    crossAxisIntrinsicArg,
    gapArg,
    focusGroupArg,
    childrenArg,
  ];
}
