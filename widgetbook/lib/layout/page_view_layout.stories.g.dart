// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'page_view_layout.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<PageViewLayout, StoryArgs<PageViewLayout>>;
typedef _BuilderScenario = PageViewLayoutBuilderScenario;
typedef _BuilderDefaults = PageViewLayoutBuilderDefaults;
typedef _BuilderStory = PageViewLayoutBuilderStory;
typedef _BuilderArgs = PageViewLayoutKnobsArgs;
final PageViewLayoutComponent =
    Component<PageViewLayout, StoryArgs<PageViewLayout>>(
      name: componentMeta.name ?? 'PageViewLayout',
      path: componentMeta.path ?? 'layout',
      docsBuilder: componentMeta.docsBuilder,
      docComment: r'''A [PageView] inside a [WidgetStyle] box.

The box (fill, border, radius, and shadow) stays in place while the
pages slide, and `style.padding` insets the viewport, so it does not
slide with them. Scroll behavior and physics come from
[resolveScrollBehavior]; [physics] applies on top of them.

A [focusable] page view, by default one on web or on macOS, Windows, or
Linux, is a Tab stop. While it holds focus, the arrows along
[scrollDirection] go to the page on that side of the screen, Page Up and
Page Down to the previous and next page, and Home and End to the first
and last page; End needs a page count. A key page change slides over
300 ms, or jumps when the app or the platform asks for less motion.
While a node inside a page holds focus, Page Up, Page Down, Home, and End
still change the page and move focus to the new page's first node. Tab
finishes one page before the next; with [allowImplicitScrolling] it
reaches the neighbor pages, and the view then shows the page it entered
whole.

Previous and next buttons are the job of the components built on this
layout: a mouse without a trackpad cannot swipe a page view on desktop.
Pass a [PageController] with a `viewportFraction` below 1 to show the
neighbor pages.''',
      stories: [
        $Playground..$generatedName = 'Playground',
        $RecipeFormRow..$generatedName = 'RecipeFormRow',
        $RecipeCard..$generatedName = 'RecipeCard',
        $RecipeListItem..$generatedName = 'RecipeListItem',
        $RecipeToolbar..$generatedName = 'RecipeToolbar',
        $RecipePageWithDrawer..$generatedName = 'RecipePageWithDrawer',
        $Responsive..$generatedName = 'Responsive',
        $Accessibility..$generatedName = 'Accessibility',
        $ExamplePagedSections..$generatedName = 'ExamplePagedSections',
      ],
    );
typedef PageViewLayoutBuilderScenario =
    Scenario<PageViewLayout, PageViewLayoutKnobsArgs>;
typedef PageViewLayoutBuilderDefaults =
    Defaults<PageViewLayout, PageViewLayoutKnobsArgs>;

class PageViewLayoutBuilderStory
    extends Story<PageViewLayout, PageViewLayoutKnobsArgs> {
  PageViewLayoutBuilderStory({
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

class PageViewLayoutKnobsArgs extends StoryArgs<PageViewLayout> {
  PageViewLayoutKnobsArgs({
    required Arg<Preset<WidgetStyle>> style,
    Arg<Axis>? scrollDirection,
    Arg<bool>? reverse,
    required Arg<Preset<PageController>> controller,
    required Arg<Preset<ScrollPhysics>> physics,
    Arg<bool>? pageSnapping,
    Arg<bool>? onPageChanged,
    required Arg<Preset<Widget? Function(BuildContext, int)>> itemBuilder,
    required Arg<Preset<int? Function(Key)>> findChildIndexCallback,
    Arg<int?>? itemCount,
    Arg<DragStartBehavior>? dragStartBehavior,
    Arg<bool>? allowImplicitScrolling,
    required Arg<Preset<ScrollCacheExtent>> scrollCacheExtent,
    Arg<String?>? restorationId,
    Arg<Clip>? clipBehavior,
    Arg<HitTestBehavior>? hitTestBehavior,
    Arg<bool>? padEnds,
    Arg<bool?>? showScrollbar,
    Arg<bool?>? focusable,
    required Arg<Preset<String>> semanticsLabel,
    required Arg<Preset<ScrollFocusStyle>> scrollFocusStyle,
  }) : this.styleArg = $initArg('style', style, null)!,
       this.scrollDirectionArg = $initArg(
         'scrollDirection',
         scrollDirection,
         EnumArg<Axis>(Axis.horizontal, values: Axis.values),
       )!,
       this.reverseArg = $initArg('reverse', reverse, BoolArg(false))!,
       this.controllerArg = $initArg('controller', controller, null)!,
       this.physicsArg = $initArg('physics', physics, null)!,
       this.pageSnappingArg = $initArg(
         'pageSnapping',
         pageSnapping,
         BoolArg(true),
       )!,
       this.onPageChangedArg = $initArg(
         'onPageChanged',
         onPageChanged,
         BoolArg(true),
       )!,
       this.itemBuilderArg = $initArg('itemBuilder', itemBuilder, null)!,
       this.findChildIndexCallbackArg = $initArg(
         'findChildIndexCallback',
         findChildIndexCallback,
         null,
       )!,
       this.itemCountArg = $initArg(
         'itemCount',
         itemCount,
         NullableIntArg(null),
       )!,
       this.dragStartBehaviorArg = $initArg(
         'dragStartBehavior',
         dragStartBehavior,
         EnumArg<DragStartBehavior>(
           DragStartBehavior.start,
           values: DragStartBehavior.values,
         ),
       )!,
       this.allowImplicitScrollingArg = $initArg(
         'allowImplicitScrolling',
         allowImplicitScrolling,
         BoolArg(false),
       )!,
       this.scrollCacheExtentArg = $initArg(
         'scrollCacheExtent',
         scrollCacheExtent,
         null,
       )!,
       this.restorationIdArg = $initArg(
         'restorationId',
         restorationId,
         NullableStringArg(null),
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
       this.padEndsArg = $initArg('padEnds', padEnds, BoolArg(true))!,
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

  PageViewLayoutKnobsArgs.fixed({
    required Preset<WidgetStyle> style,
    Axis scrollDirection = Axis.horizontal,
    bool reverse = false,
    required Preset<PageController> controller,
    required Preset<ScrollPhysics> physics,
    bool pageSnapping = true,
    bool onPageChanged = true,
    required Preset<Widget? Function(BuildContext, int)> itemBuilder,
    required Preset<int? Function(Key)> findChildIndexCallback,
    int? itemCount = null,
    DragStartBehavior dragStartBehavior = DragStartBehavior.start,
    bool allowImplicitScrolling = false,
    required Preset<ScrollCacheExtent> scrollCacheExtent,
    String? restorationId = null,
    Clip clipBehavior = Clip.hardEdge,
    HitTestBehavior hitTestBehavior = HitTestBehavior.opaque,
    bool padEnds = true,
    bool? showScrollbar = null,
    bool? focusable = null,
    required Preset<String> semanticsLabel,
    required Preset<ScrollFocusStyle> scrollFocusStyle,
  }) : this.styleArg = $initArg('style', Arg.fixed(style), null)!,
       this.scrollDirectionArg = $initArg(
         'scrollDirection',
         Arg.fixed(scrollDirection),
         null,
       )!,
       this.reverseArg = $initArg('reverse', Arg.fixed(reverse), null)!,
       this.controllerArg = $initArg(
         'controller',
         Arg.fixed(controller),
         null,
       )!,
       this.physicsArg = $initArg('physics', Arg.fixed(physics), null)!,
       this.pageSnappingArg = $initArg(
         'pageSnapping',
         Arg.fixed(pageSnapping),
         null,
       )!,
       this.onPageChangedArg = $initArg(
         'onPageChanged',
         Arg.fixed(onPageChanged),
         null,
       )!,
       this.itemBuilderArg = $initArg(
         'itemBuilder',
         Arg.fixed(itemBuilder),
         null,
       )!,
       this.findChildIndexCallbackArg = $initArg(
         'findChildIndexCallback',
         Arg.fixed(findChildIndexCallback),
         null,
       )!,
       this.itemCountArg = $initArg(
         'itemCount',
         itemCount == null ? null : Arg.fixed(itemCount),
         null,
       ),
       this.dragStartBehaviorArg = $initArg(
         'dragStartBehavior',
         Arg.fixed(dragStartBehavior),
         null,
       )!,
       this.allowImplicitScrollingArg = $initArg(
         'allowImplicitScrolling',
         Arg.fixed(allowImplicitScrolling),
         null,
       )!,
       this.scrollCacheExtentArg = $initArg(
         'scrollCacheExtent',
         Arg.fixed(scrollCacheExtent),
         null,
       )!,
       this.restorationIdArg = $initArg(
         'restorationId',
         restorationId == null ? null : Arg.fixed(restorationId),
         null,
       ),
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
       this.padEndsArg = $initArg('padEnds', Arg.fixed(padEnds), null)!,
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

  final Arg<Axis> scrollDirectionArg;

  final Arg<bool> reverseArg;

  final Arg<Preset<PageController>> controllerArg;

  final Arg<Preset<ScrollPhysics>> physicsArg;

  final Arg<bool> pageSnappingArg;

  final Arg<bool> onPageChangedArg;

  final Arg<Preset<Widget? Function(BuildContext, int)>> itemBuilderArg;

  final Arg<Preset<int? Function(Key)>> findChildIndexCallbackArg;

  final Arg<int?>? itemCountArg;

  final Arg<DragStartBehavior> dragStartBehaviorArg;

  final Arg<bool> allowImplicitScrollingArg;

  final Arg<Preset<ScrollCacheExtent>> scrollCacheExtentArg;

  final Arg<String?>? restorationIdArg;

  final Arg<Clip> clipBehaviorArg;

  final Arg<HitTestBehavior> hitTestBehaviorArg;

  final Arg<bool> padEndsArg;

  final Arg<bool?>? showScrollbarArg;

  final Arg<bool?>? focusableArg;

  final Arg<Preset<String>> semanticsLabelArg;

  final Arg<Preset<ScrollFocusStyle>> scrollFocusStyleArg;

  Preset<WidgetStyle> get style => styleArg.value;

  Axis get scrollDirection => scrollDirectionArg.value;

  bool get reverse => reverseArg.value;

  Preset<PageController> get controller => controllerArg.value;

  Preset<ScrollPhysics> get physics => physicsArg.value;

  bool get pageSnapping => pageSnappingArg.value;

  bool get onPageChanged => onPageChangedArg.value;

  Preset<Widget? Function(BuildContext, int)> get itemBuilder =>
      itemBuilderArg.value;

  Preset<int? Function(Key)> get findChildIndexCallback =>
      findChildIndexCallbackArg.value;

  int? get itemCount => itemCountArg?.value;

  DragStartBehavior get dragStartBehavior => dragStartBehaviorArg.value;

  bool get allowImplicitScrolling => allowImplicitScrollingArg.value;

  Preset<ScrollCacheExtent> get scrollCacheExtent => scrollCacheExtentArg.value;

  String? get restorationId => restorationIdArg?.value;

  Clip get clipBehavior => clipBehaviorArg.value;

  HitTestBehavior get hitTestBehavior => hitTestBehaviorArg.value;

  bool get padEnds => padEndsArg.value;

  bool? get showScrollbar => showScrollbarArg?.value;

  bool? get focusable => focusableArg?.value;

  Preset<String> get semanticsLabel => semanticsLabelArg.value;

  Preset<ScrollFocusStyle> get scrollFocusStyle => scrollFocusStyleArg.value;

  @override
  List<Arg?> get list => [
    styleArg,
    scrollDirectionArg,
    reverseArg,
    controllerArg,
    physicsArg,
    pageSnappingArg,
    onPageChangedArg,
    itemBuilderArg,
    findChildIndexCallbackArg,
    itemCountArg,
    dragStartBehaviorArg,
    allowImplicitScrollingArg,
    scrollCacheExtentArg,
    restorationIdArg,
    clipBehaviorArg,
    hitTestBehaviorArg,
    padEndsArg,
    showScrollbarArg,
    focusableArg,
    semanticsLabelArg,
    scrollFocusStyleArg,
  ];
}
