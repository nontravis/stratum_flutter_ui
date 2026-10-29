// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'indexed_stack_layout.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component =
    Component<IndexedStackLayout, StoryArgs<IndexedStackLayout>>;
typedef _Scenario = IndexedStackLayoutScenario;
typedef _Defaults = IndexedStackLayoutDefaults;
typedef _Story = IndexedStackLayoutStory;
typedef _Args = IndexedStackLayoutKnobsArgs;
final IndexedStackLayoutComponent =
    Component<IndexedStackLayout, StoryArgs<IndexedStackLayout>>(
      name: componentMeta.name ?? 'IndexedStackLayout',
      path: componentMeta.path ?? 'layout',
      docsBuilder: componentMeta.docsBuilder,
      docComment: r'''An [IndexedStack] on [BoxLayout]: shows the child at [index] and keeps
the others built, with style, interaction, semantics, and scrolling
from the base class.

As with [IndexedStack], only the shown child paints, takes hits, takes
focus, and appears in semantics. Hidden children's tickers stop through
[TickerMode], so their animations stop ticking and tick again when the
child shows; time still passes while they are hidden. A switch has no
animation; wrap the content in [AnimatedSwitcher] for a cross-fade.

When [index] changes while focus sits inside the outgoing child, focus
moves after the frame to the first node of the incoming child in Tab
order, else to the stack's own node, which is not a Tab stop, so the
next Tab moves on from the stack's place. Focus outside the stack, such
as on the tab bar that changed [index], stays where it is.

[alignment] and [clipBehavior] act on the stack; `style.alignment` and
`style.clipBehavior` act on the box.''',
      stories: [
        $Playground..$generatedName = 'Playground',
        $RecipeFormRow..$generatedName = 'RecipeFormRow',
        $RecipeCard..$generatedName = 'RecipeCard',
        $RecipeListItem..$generatedName = 'RecipeListItem',
        $RecipeToolbar..$generatedName = 'RecipeToolbar',
        $RecipePageWithDrawer..$generatedName = 'RecipePageWithDrawer',
        $Responsive..$generatedName = 'Responsive',
        $Accessibility..$generatedName = 'Accessibility',
        $ExampleSwitchStackedViews
          ..$generatedName = 'ExampleSwitchStackedViews',
      ],
    );
typedef IndexedStackLayoutScenario =
    Scenario<IndexedStackLayout, IndexedStackLayoutKnobsArgs>;
typedef IndexedStackLayoutDefaults =
    Defaults<IndexedStackLayout, IndexedStackLayoutKnobsArgs>;

class IndexedStackLayoutStory
    extends Story<IndexedStackLayout, IndexedStackLayoutKnobsArgs> {
  IndexedStackLayoutStory({
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

class IndexedStackLayoutKnobsArgs extends StoryArgs<IndexedStackLayout> {
  IndexedStackLayoutKnobsArgs({
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
    Arg<int?>? index,
    required Arg<Preset<AlignmentGeometry>> alignment,
    Arg<StackFit>? sizing,
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
       this.indexArg = $initArg('index', index, NullableIntArg(0))!,
       this.alignmentArg = $initArg('alignment', alignment, null)!,
       this.sizingArg = $initArg(
         'sizing',
         sizing,
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

  IndexedStackLayoutKnobsArgs.fixed({
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
    int? index = 0,
    required Preset<AlignmentGeometry> alignment,
    StackFit sizing = StackFit.loose,
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
       this.indexArg = $initArg(
         'index',
         index == null ? null : Arg.fixed(index),
         null,
       ),
       this.alignmentArg = $initArg('alignment', Arg.fixed(alignment), null)!,
       this.sizingArg = $initArg('sizing', Arg.fixed(sizing), null)!,
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

  final Arg<int?>? indexArg;

  final Arg<Preset<AlignmentGeometry>> alignmentArg;

  final Arg<StackFit> sizingArg;

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

  int? get index => indexArg?.value;

  Preset<AlignmentGeometry> get alignment => alignmentArg.value;

  StackFit get sizing => sizingArg.value;

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
    indexArg,
    alignmentArg,
    sizingArg,
    textDirectionArg,
    clipBehaviorArg,
    childrenArg,
  ];
}
