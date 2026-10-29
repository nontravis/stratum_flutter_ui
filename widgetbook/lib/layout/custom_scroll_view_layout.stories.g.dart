// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'custom_scroll_view_layout.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component =
    Component<CustomScrollViewLayout, StoryArgs<CustomScrollViewLayout>>;
typedef _Scenario = CustomScrollViewLayoutScenario;
typedef _Defaults = CustomScrollViewLayoutDefaults;
typedef _Story = CustomScrollViewLayoutStory;
typedef _Args = CustomScrollViewLayoutKnobsArgs;
final CustomScrollViewLayoutComponent =
    Component<CustomScrollViewLayout, StoryArgs<CustomScrollViewLayout>>(
      name: componentMeta.name ?? 'CustomScrollViewLayout',
      path: componentMeta.path ?? 'layout',
      docsBuilder: componentMeta.docsBuilder,
      docComment:
          r'''A [CustomScrollView] that scrolls inside a [WidgetStyle] box.

Takes either [slivers] or [children]; [children] go into one lazy
[SliverList]. The box (fill, border, radius, and shadow) stays in place
while the content scrolls. In children mode `style.padding` becomes a
[SliverPadding], so it scrolls with the content; with [slivers], wrap
them in a [SliverPadding] yourself, because grouping several slivers
changes how pinned headers behave. A [focusable] view, by default one
on web or on macOS, Windows, or Linux, is a Tab stop whose arrows, Page
Up, Page Down, Home, and End scroll it.''',
      stories: [
        $Playground..$generatedName = 'Playground',
        $RecipeFormRow..$generatedName = 'RecipeFormRow',
        $RecipeCard..$generatedName = 'RecipeCard',
        $RecipeListItem..$generatedName = 'RecipeListItem',
        $RecipeToolbar..$generatedName = 'RecipeToolbar',
        $RecipePageWithDrawer..$generatedName = 'RecipePageWithDrawer',
        $Responsive..$generatedName = 'Responsive',
        $Accessibility..$generatedName = 'Accessibility',
        $ExamplePinnedHeaderList..$generatedName = 'ExamplePinnedHeaderList',
      ],
    );
typedef CustomScrollViewLayoutScenario =
    Scenario<CustomScrollViewLayout, CustomScrollViewLayoutKnobsArgs>;
typedef CustomScrollViewLayoutDefaults =
    Defaults<CustomScrollViewLayout, CustomScrollViewLayoutKnobsArgs>;

class CustomScrollViewLayoutStory
    extends Story<CustomScrollViewLayout, CustomScrollViewLayoutKnobsArgs> {
  CustomScrollViewLayoutStory({
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

class CustomScrollViewLayoutKnobsArgs
    extends StoryArgs<CustomScrollViewLayout> {
  CustomScrollViewLayoutKnobsArgs({
    required Arg<Preset<WidgetStyle>> style,
    required Arg<Preset<List<Widget>?>> slivers,
    Arg<int>? children,
    required Arg<Preset<ScrollController>> controller,
    Arg<Axis>? scrollDirection,
    Arg<bool>? reverse,
    Arg<bool>? shrinkWrap,
    required Arg<Preset<ScrollPhysics>> physics,
    Arg<bool?>? showScrollbar,
    Arg<bool?>? focusable,
    required Arg<Preset<String>> semanticsLabel,
    required Arg<Preset<ScrollFocusStyle>> scrollFocusStyle,
  }) : this.styleArg = $initArg('style', style, null)!,
       this.sliversArg = $initArg('slivers', slivers, null)!,
       this.childrenArg = $initArg('children', children, IntArg(3))!,
       this.controllerArg = $initArg('controller', controller, null)!,
       this.scrollDirectionArg = $initArg(
         'scrollDirection',
         scrollDirection,
         EnumArg<Axis>(Axis.vertical, values: Axis.values),
       )!,
       this.reverseArg = $initArg('reverse', reverse, BoolArg(false))!,
       this.shrinkWrapArg = $initArg('shrinkWrap', shrinkWrap, BoolArg(false))!,
       this.physicsArg = $initArg('physics', physics, null)!,
       this.showScrollbarArg = $initArg(
         'showScrollbar',
         showScrollbar,
         NullableBoolArg(null),
       )!,
       this.focusableArg = $initArg(
         'focusable',
         focusable,
         NullableBoolArg(null),
       )!,
       this.semanticsLabelArg = $initArg(
         'semanticsLabel',
         semanticsLabel,
         null,
       )!,
       this.scrollFocusStyleArg = $initArg(
         'scrollFocusStyle',
         scrollFocusStyle,
         null,
       )!;

  CustomScrollViewLayoutKnobsArgs.fixed({
    required Preset<WidgetStyle> style,
    required Preset<List<Widget>?> slivers,
    int children = 3,
    required Preset<ScrollController> controller,
    Axis scrollDirection = Axis.vertical,
    bool reverse = false,
    bool shrinkWrap = false,
    required Preset<ScrollPhysics> physics,
    bool? showScrollbar = null,
    bool? focusable = null,
    required Preset<String> semanticsLabel,
    required Preset<ScrollFocusStyle> scrollFocusStyle,
  }) : this.styleArg = $initArg('style', Arg.fixed(style), null)!,
       this.sliversArg = $initArg('slivers', Arg.fixed(slivers), null)!,
       this.childrenArg = $initArg('children', Arg.fixed(children), null)!,
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
       this.shrinkWrapArg = $initArg(
         'shrinkWrap',
         Arg.fixed(shrinkWrap),
         null,
       )!,
       this.physicsArg = $initArg('physics', Arg.fixed(physics), null)!,
       this.showScrollbarArg = $initArg(
         'showScrollbar',
         showScrollbar == null ? null : Arg.fixed(showScrollbar),
         null,
       ),
       this.focusableArg = $initArg(
         'focusable',
         focusable == null ? null : Arg.fixed(focusable),
         null,
       ),
       this.semanticsLabelArg = $initArg(
         'semanticsLabel',
         Arg.fixed(semanticsLabel),
         null,
       )!,
       this.scrollFocusStyleArg = $initArg(
         'scrollFocusStyle',
         Arg.fixed(scrollFocusStyle),
         null,
       )!;

  final Arg<Preset<WidgetStyle>> styleArg;

  final Arg<Preset<List<Widget>?>> sliversArg;

  final Arg<int> childrenArg;

  final Arg<Preset<ScrollController>> controllerArg;

  final Arg<Axis> scrollDirectionArg;

  final Arg<bool> reverseArg;

  final Arg<bool> shrinkWrapArg;

  final Arg<Preset<ScrollPhysics>> physicsArg;

  final Arg<bool?>? showScrollbarArg;

  final Arg<bool?>? focusableArg;

  final Arg<Preset<String>> semanticsLabelArg;

  final Arg<Preset<ScrollFocusStyle>> scrollFocusStyleArg;

  Preset<WidgetStyle> get style => styleArg.value;

  Preset<List<Widget>?> get slivers => sliversArg.value;

  int get children => childrenArg.value;

  Preset<ScrollController> get controller => controllerArg.value;

  Axis get scrollDirection => scrollDirectionArg.value;

  bool get reverse => reverseArg.value;

  bool get shrinkWrap => shrinkWrapArg.value;

  Preset<ScrollPhysics> get physics => physicsArg.value;

  bool? get showScrollbar => showScrollbarArg?.value;

  bool? get focusable => focusableArg?.value;

  Preset<String> get semanticsLabel => semanticsLabelArg.value;

  Preset<ScrollFocusStyle> get scrollFocusStyle => scrollFocusStyleArg.value;

  @override
  List<Arg?> get list => [
    styleArg,
    sliversArg,
    childrenArg,
    controllerArg,
    scrollDirectionArg,
    reverseArg,
    shrinkWrapArg,
    physicsArg,
    showScrollbarArg,
    focusableArg,
    semanticsLabelArg,
    scrollFocusStyleArg,
  ];
}
