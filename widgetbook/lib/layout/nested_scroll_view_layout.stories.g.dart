// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'nested_scroll_view_layout.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component =
    Component<NestedScrollViewLayout, StoryArgs<NestedScrollViewLayout>>;
typedef _Scenario = NestedScrollViewLayoutScenario;
typedef _Defaults = NestedScrollViewLayoutDefaults;
typedef _Story = NestedScrollViewLayoutStory;
typedef _Args = NestedScrollViewLayoutKnobsArgs;
final NestedScrollViewLayoutComponent =
    Component<NestedScrollViewLayout, StoryArgs<NestedScrollViewLayout>>(
      name: componentMeta.name ?? 'NestedScrollViewLayout',
      path: componentMeta.path ?? 'layout',
      docsBuilder: componentMeta.docsBuilder,
      docComment:
          r'''A [NestedScrollView] inside a [WidgetStyle] box: a header that
collapses as the body scrolls.

The box (fill, border, radius, and shadow) stays in place, and
`style.padding` insets the viewport, so it does not scroll. Scroll
behavior and physics come from [resolveScrollBehavior]; [physics]
applies on top of them.

The layout is not a Tab stop. The scroll views in [body] are, and their
keys scroll the header and the body as one range: an arrow or a page
first collapses or expands the header and then scrolls the body, Home
expands the header and returns the body to its start, and End scrolls
the body to its end. [body] should be a vertical layout scroll view,
such as `ListViewLayout`, whose `controller` is null and whose
`primary` is null or true, so it attaches to the inner controller; a
scroll view with its own controller scrolls on its own, as in Flutter.

The scroll views of a `TabBarView` body share the inner controller.
Build them with `showScrollbar: false`: a desktop scrollbar asserts
while a tab swipe attaches two of them to the controller it watches.''',
      stories: [
        $Playground..$generatedName = 'Playground',
        $RecipeFormRow..$generatedName = 'RecipeFormRow',
        $RecipeCard..$generatedName = 'RecipeCard',
        $RecipeListItem..$generatedName = 'RecipeListItem',
        $RecipeToolbar..$generatedName = 'RecipeToolbar',
        $RecipePageWithDrawer..$generatedName = 'RecipePageWithDrawer',
        $Responsive..$generatedName = 'Responsive',
        $Accessibility..$generatedName = 'Accessibility',
        $ExampleCollapsingHeader..$generatedName = 'ExampleCollapsingHeader',
      ],
    );
typedef NestedScrollViewLayoutScenario =
    Scenario<NestedScrollViewLayout, NestedScrollViewLayoutKnobsArgs>;
typedef NestedScrollViewLayoutDefaults =
    Defaults<NestedScrollViewLayout, NestedScrollViewLayoutKnobsArgs>;

class NestedScrollViewLayoutStory
    extends Story<NestedScrollViewLayout, NestedScrollViewLayoutKnobsArgs> {
  NestedScrollViewLayoutStory({
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

class NestedScrollViewLayoutKnobsArgs
    extends StoryArgs<NestedScrollViewLayout> {
  NestedScrollViewLayoutKnobsArgs({
    required Arg<Preset<WidgetStyle>> style,
    required Arg<Preset<ScrollController>> controller,
    Arg<Axis>? scrollDirection,
    Arg<bool>? reverse,
    required Arg<Preset<ScrollPhysics>> physics,
    Arg<bool?>? showScrollbar,
    required Arg<RequiredPreset<List<Widget> Function(BuildContext, bool)>>
    headerSliverBuilder,
    Arg<SlotPreset>? body,
    Arg<DragStartBehavior>? dragStartBehavior,
    Arg<bool>? floatHeaderSlivers,
    Arg<Clip>? clipBehavior,
    Arg<HitTestBehavior>? hitTestBehavior,
    Arg<String?>? restorationId,
  }) : this.styleArg = $initArg('style', style, null)!,
       this.controllerArg = $initArg('controller', controller, null)!,
       this.scrollDirectionArg = $initArg(
         'scrollDirection',
         scrollDirection,
         EnumArg<Axis>(Axis.vertical, values: Axis.values),
       )!,
       this.reverseArg = $initArg('reverse', reverse, BoolArg(false))!,
       this.physicsArg = $initArg('physics', physics, null)!,
       this.showScrollbarArg = $initArg(
         'showScrollbar',
         showScrollbar,
         NullableBoolArg(null),
       )!,
       this.headerSliverBuilderArg = $initArg(
         'headerSliverBuilder',
         headerSliverBuilder,
         null,
       )!,
       this.bodyArg = $initArg(
         'body',
         body,
         EnumArg<SlotPreset>(SlotPreset.slot, values: SlotPreset.values),
       )!,
       this.dragStartBehaviorArg = $initArg(
         'dragStartBehavior',
         dragStartBehavior,
         EnumArg<DragStartBehavior>(
           DragStartBehavior.start,
           values: DragStartBehavior.values,
         ),
       )!,
       this.floatHeaderSliversArg = $initArg(
         'floatHeaderSlivers',
         floatHeaderSlivers,
         BoolArg(false),
       )!,
       this.clipBehaviorArg = $initArg(
         'clipBehavior',
         clipBehavior,
         EnumArg<Clip>(Clip.hardEdge, values: Clip.values),
       )!,
       this.hitTestBehaviorArg = $initArg(
         'hitTestBehavior',
         hitTestBehavior,
         EnumArg<HitTestBehavior>(
           HitTestBehavior.opaque,
           values: HitTestBehavior.values,
         ),
       )!,
       this.restorationIdArg = $initArg(
         'restorationId',
         restorationId,
         NullableStringArg(null),
       )!;

  NestedScrollViewLayoutKnobsArgs.fixed({
    required Preset<WidgetStyle> style,
    required Preset<ScrollController> controller,
    Axis scrollDirection = Axis.vertical,
    bool reverse = false,
    required Preset<ScrollPhysics> physics,
    bool? showScrollbar = null,
    required RequiredPreset<List<Widget> Function(BuildContext, bool)>
    headerSliverBuilder,
    SlotPreset body = SlotPreset.slot,
    DragStartBehavior dragStartBehavior = DragStartBehavior.start,
    bool floatHeaderSlivers = false,
    Clip clipBehavior = Clip.hardEdge,
    HitTestBehavior hitTestBehavior = HitTestBehavior.opaque,
    String? restorationId = null,
  }) : this.styleArg = $initArg('style', Arg.fixed(style), null)!,
       this.controllerArg = $initArg(
         'controller',
         Arg.fixed(controller),
         null,
       )!,
       this.scrollDirectionArg = $initArg(
         'scrollDirection',
         Arg.fixed(scrollDirection),
         null,
       )!,
       this.reverseArg = $initArg('reverse', Arg.fixed(reverse), null)!,
       this.physicsArg = $initArg('physics', Arg.fixed(physics), null)!,
       this.showScrollbarArg = $initArg(
         'showScrollbar',
         showScrollbar == null ? null : Arg.fixed(showScrollbar),
         null,
       ),
       this.headerSliverBuilderArg = $initArg(
         'headerSliverBuilder',
         Arg.fixed(headerSliverBuilder),
         null,
       )!,
       this.bodyArg = $initArg('body', Arg.fixed(body), null)!,
       this.dragStartBehaviorArg = $initArg(
         'dragStartBehavior',
         Arg.fixed(dragStartBehavior),
         null,
       )!,
       this.floatHeaderSliversArg = $initArg(
         'floatHeaderSlivers',
         Arg.fixed(floatHeaderSlivers),
         null,
       )!,
       this.clipBehaviorArg = $initArg(
         'clipBehavior',
         Arg.fixed(clipBehavior),
         null,
       )!,
       this.hitTestBehaviorArg = $initArg(
         'hitTestBehavior',
         Arg.fixed(hitTestBehavior),
         null,
       )!,
       this.restorationIdArg = $initArg(
         'restorationId',
         restorationId == null ? null : Arg.fixed(restorationId),
         null,
       );

  final Arg<Preset<WidgetStyle>> styleArg;

  final Arg<Preset<ScrollController>> controllerArg;

  final Arg<Axis> scrollDirectionArg;

  final Arg<bool> reverseArg;

  final Arg<Preset<ScrollPhysics>> physicsArg;

  final Arg<bool?>? showScrollbarArg;

  final Arg<RequiredPreset<List<Widget> Function(BuildContext, bool)>>
  headerSliverBuilderArg;

  final Arg<SlotPreset> bodyArg;

  final Arg<DragStartBehavior> dragStartBehaviorArg;

  final Arg<bool> floatHeaderSliversArg;

  final Arg<Clip> clipBehaviorArg;

  final Arg<HitTestBehavior> hitTestBehaviorArg;

  final Arg<String?>? restorationIdArg;

  Preset<WidgetStyle> get style => styleArg.value;

  Preset<ScrollController> get controller => controllerArg.value;

  Axis get scrollDirection => scrollDirectionArg.value;

  bool get reverse => reverseArg.value;

  Preset<ScrollPhysics> get physics => physicsArg.value;

  bool? get showScrollbar => showScrollbarArg?.value;

  RequiredPreset<List<Widget> Function(BuildContext, bool)>
  get headerSliverBuilder => headerSliverBuilderArg.value;

  SlotPreset get body => bodyArg.value;

  DragStartBehavior get dragStartBehavior => dragStartBehaviorArg.value;

  bool get floatHeaderSlivers => floatHeaderSliversArg.value;

  Clip get clipBehavior => clipBehaviorArg.value;

  HitTestBehavior get hitTestBehavior => hitTestBehaviorArg.value;

  String? get restorationId => restorationIdArg?.value;

  @override
  List<Arg?> get list => [
    styleArg,
    controllerArg,
    scrollDirectionArg,
    reverseArg,
    physicsArg,
    showScrollbarArg,
    headerSliverBuilderArg,
    bodyArg,
    dragStartBehaviorArg,
    floatHeaderSliversArg,
    clipBehaviorArg,
    hitTestBehaviorArg,
    restorationIdArg,
  ];
}
