// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'list_view_layout.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<ListViewLayout, StoryArgs<ListViewLayout>>;
typedef _BuilderScenario = ListViewLayoutBuilderScenario;
typedef _BuilderDefaults = ListViewLayoutBuilderDefaults;
typedef _BuilderStory = ListViewLayoutBuilderStory;
typedef _BuilderArgs = ListViewLayoutKnobsArgs;
final ListViewLayoutComponent =
    Component<ListViewLayout, StoryArgs<ListViewLayout>>(
      name: componentMeta.name ?? 'ListViewLayout',
      path: componentMeta.path ?? 'layout',
      docsBuilder: componentMeta.docsBuilder,
      docComment: r'''A lazy list that scrolls inside a [WidgetStyle] box.

The box (fill, border, radius, and shadow) stays in place while the
items scroll. `style.padding` becomes the list padding, so it scrolls
with the items. Scroll behavior and physics come from
[resolveScrollBehavior]; [physics] applies on top of them. A [focusable]
list, by default one on web or on macOS, Windows, or Linux, is a Tab
stop whose arrows, Page Up, Page Down, Home, and End scroll it.''',
      stories: [
        $Playground..$generatedName = 'Playground',
        $RecipeFormRow..$generatedName = 'RecipeFormRow',
        $RecipeCard..$generatedName = 'RecipeCard',
        $RecipeListItem..$generatedName = 'RecipeListItem',
        $RecipeToolbar..$generatedName = 'RecipeToolbar',
        $RecipePageWithDrawer..$generatedName = 'RecipePageWithDrawer',
        $Responsive..$generatedName = 'Responsive',
        $Accessibility..$generatedName = 'Accessibility',
        $ExampleStyledList..$generatedName = 'ExampleStyledList',
      ],
    );
typedef ListViewLayoutBuilderScenario =
    Scenario<ListViewLayout, ListViewLayoutKnobsArgs>;
typedef ListViewLayoutBuilderDefaults =
    Defaults<ListViewLayout, ListViewLayoutKnobsArgs>;

class ListViewLayoutBuilderStory
    extends Story<ListViewLayout, ListViewLayoutKnobsArgs> {
  ListViewLayoutBuilderStory({
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

class ListViewLayoutKnobsArgs extends StoryArgs<ListViewLayout> {
  ListViewLayoutKnobsArgs({
    required Arg<Preset<WidgetStyle>> style,
    Arg<double?>? gap,
    Arg<Axis>? scrollDirection,
    Arg<bool>? reverse,
    required Arg<Preset<ScrollController>> controller,
    Arg<bool?>? primary,
    required Arg<Preset<ScrollPhysics>> physics,
    Arg<bool?>? showScrollbar,
    Arg<bool>? shrinkWrap,
    Arg<double?>? itemExtent,
    Arg<SlotPreset>? prototypeItem,
    Arg<int>? itemCount,
    required Arg<Preset<Widget? Function(BuildContext, int)>> itemBuilder,
    required Arg<Preset<int? Function(Key)>> findChildIndexCallback,
    Arg<bool>? addAutomaticKeepAlives,
    Arg<bool>? addRepaintBoundaries,
    Arg<bool>? addSemanticIndexes,
    required Arg<Preset<ScrollCacheExtent>> scrollCacheExtent,
    Arg<int?>? semanticChildCount,
    Arg<DragStartBehavior>? dragStartBehavior,
    Arg<ScrollViewKeyboardDismissBehavior?>? keyboardDismissBehavior,
    Arg<String?>? restorationId,
    Arg<Clip>? clipBehavior,
    Arg<bool?>? focusable,
    required Arg<Preset<String>> semanticsLabel,
    required Arg<Preset<ScrollFocusStyle>> scrollFocusStyle,
  }) : this.styleArg = $initArg('style', style, null)!,
       this.gapArg = $initArg('gap', gap, NullableDoubleArg(null))!,
       this.scrollDirectionArg = $initArg(
         'scrollDirection',
         scrollDirection,
         EnumArg<Axis>(Axis.vertical, values: Axis.values),
       )!,
       this.reverseArg = $initArg('reverse', reverse, BoolArg(false))!,
       this.controllerArg = $initArg('controller', controller, null)!,
       this.primaryArg = $initArg('primary', primary, NullableBoolArg(null))!,
       this.physicsArg = $initArg('physics', physics, null)!,
       this.showScrollbarArg = $initArg(
         'showScrollbar',
         showScrollbar,
         NullableBoolArg(null),
       )!,
       this.shrinkWrapArg = $initArg('shrinkWrap', shrinkWrap, BoolArg(false))!,
       this.itemExtentArg = $initArg(
         'itemExtent',
         itemExtent,
         NullableDoubleArg(null),
       )!,
       this.prototypeItemArg = $initArg(
         'prototypeItem',
         prototypeItem,
         EnumArg<SlotPreset>(SlotPreset.none, values: SlotPreset.values),
       )!,
       this.itemCountArg = $initArg('itemCount', itemCount, IntArg(0))!,
       this.itemBuilderArg = $initArg('itemBuilder', itemBuilder, null)!,
       this.findChildIndexCallbackArg = $initArg(
         'findChildIndexCallback',
         findChildIndexCallback,
         null,
       )!,
       this.addAutomaticKeepAlivesArg = $initArg(
         'addAutomaticKeepAlives',
         addAutomaticKeepAlives,
         BoolArg(true),
       )!,
       this.addRepaintBoundariesArg = $initArg(
         'addRepaintBoundaries',
         addRepaintBoundaries,
         BoolArg(true),
       )!,
       this.addSemanticIndexesArg = $initArg(
         'addSemanticIndexes',
         addSemanticIndexes,
         BoolArg(true),
       )!,
       this.scrollCacheExtentArg = $initArg(
         'scrollCacheExtent',
         scrollCacheExtent,
         null,
       )!,
       this.semanticChildCountArg = $initArg(
         'semanticChildCount',
         semanticChildCount,
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
       this.keyboardDismissBehaviorArg = $initArg(
         'keyboardDismissBehavior',
         keyboardDismissBehavior,
         NullableEnumArg<ScrollViewKeyboardDismissBehavior>(
           null,
           values: ScrollViewKeyboardDismissBehavior.values,
         ),
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

  ListViewLayoutKnobsArgs.fixed({
    required Preset<WidgetStyle> style,
    double? gap = null,
    Axis scrollDirection = Axis.vertical,
    bool reverse = false,
    required Preset<ScrollController> controller,
    bool? primary = null,
    required Preset<ScrollPhysics> physics,
    bool? showScrollbar = null,
    bool shrinkWrap = false,
    double? itemExtent = null,
    SlotPreset prototypeItem = SlotPreset.none,
    int itemCount = 0,
    required Preset<Widget? Function(BuildContext, int)> itemBuilder,
    required Preset<int? Function(Key)> findChildIndexCallback,
    bool addAutomaticKeepAlives = true,
    bool addRepaintBoundaries = true,
    bool addSemanticIndexes = true,
    required Preset<ScrollCacheExtent> scrollCacheExtent,
    int? semanticChildCount = null,
    DragStartBehavior dragStartBehavior = DragStartBehavior.start,
    ScrollViewKeyboardDismissBehavior? keyboardDismissBehavior = null,
    String? restorationId = null,
    Clip clipBehavior = Clip.hardEdge,
    bool? focusable = null,
    required Preset<String> semanticsLabel,
    required Preset<ScrollFocusStyle> scrollFocusStyle,
  }) : this.styleArg = $initArg('style', Arg.fixed(style), null)!,
       this.gapArg = $initArg('gap', gap == null ? null : Arg.fixed(gap), null),
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
       this.primaryArg = $initArg(
         'primary',
         primary == null ? null : Arg.fixed(primary),
         null,
       ),
       this.physicsArg = $initArg('physics', Arg.fixed(physics), null)!,
       this.showScrollbarArg = $initArg(
         'showScrollbar',
         showScrollbar == null ? null : Arg.fixed(showScrollbar),
         null,
       ),
       this.shrinkWrapArg = $initArg(
         'shrinkWrap',
         Arg.fixed(shrinkWrap),
         null,
       )!,
       this.itemExtentArg = $initArg(
         'itemExtent',
         itemExtent == null ? null : Arg.fixed(itemExtent),
         null,
       ),
       this.prototypeItemArg = $initArg(
         'prototypeItem',
         Arg.fixed(prototypeItem),
         null,
       )!,
       this.itemCountArg = $initArg('itemCount', Arg.fixed(itemCount), null)!,
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
       this.addAutomaticKeepAlivesArg = $initArg(
         'addAutomaticKeepAlives',
         Arg.fixed(addAutomaticKeepAlives),
         null,
       )!,
       this.addRepaintBoundariesArg = $initArg(
         'addRepaintBoundaries',
         Arg.fixed(addRepaintBoundaries),
         null,
       )!,
       this.addSemanticIndexesArg = $initArg(
         'addSemanticIndexes',
         Arg.fixed(addSemanticIndexes),
         null,
       )!,
       this.scrollCacheExtentArg = $initArg(
         'scrollCacheExtent',
         Arg.fixed(scrollCacheExtent),
         null,
       )!,
       this.semanticChildCountArg = $initArg(
         'semanticChildCount',
         semanticChildCount == null ? null : Arg.fixed(semanticChildCount),
         null,
       ),
       this.dragStartBehaviorArg = $initArg(
         'dragStartBehavior',
         Arg.fixed(dragStartBehavior),
         null,
       )!,
       this.keyboardDismissBehaviorArg = $initArg(
         'keyboardDismissBehavior',
         keyboardDismissBehavior == null
             ? null
             : Arg.fixed(keyboardDismissBehavior),
         null,
       ),
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

  final Arg<double?>? gapArg;

  final Arg<Axis> scrollDirectionArg;

  final Arg<bool> reverseArg;

  final Arg<Preset<ScrollController>> controllerArg;

  final Arg<bool?>? primaryArg;

  final Arg<Preset<ScrollPhysics>> physicsArg;

  final Arg<bool?>? showScrollbarArg;

  final Arg<bool> shrinkWrapArg;

  final Arg<double?>? itemExtentArg;

  final Arg<SlotPreset> prototypeItemArg;

  final Arg<int> itemCountArg;

  final Arg<Preset<Widget? Function(BuildContext, int)>> itemBuilderArg;

  final Arg<Preset<int? Function(Key)>> findChildIndexCallbackArg;

  final Arg<bool> addAutomaticKeepAlivesArg;

  final Arg<bool> addRepaintBoundariesArg;

  final Arg<bool> addSemanticIndexesArg;

  final Arg<Preset<ScrollCacheExtent>> scrollCacheExtentArg;

  final Arg<int?>? semanticChildCountArg;

  final Arg<DragStartBehavior> dragStartBehaviorArg;

  final Arg<ScrollViewKeyboardDismissBehavior?>? keyboardDismissBehaviorArg;

  final Arg<String?>? restorationIdArg;

  final Arg<Clip> clipBehaviorArg;

  final Arg<bool?>? focusableArg;

  final Arg<Preset<String>> semanticsLabelArg;

  final Arg<Preset<ScrollFocusStyle>> scrollFocusStyleArg;

  Preset<WidgetStyle> get style => styleArg.value;

  double? get gap => gapArg?.value;

  Axis get scrollDirection => scrollDirectionArg.value;

  bool get reverse => reverseArg.value;

  Preset<ScrollController> get controller => controllerArg.value;

  bool? get primary => primaryArg?.value;

  Preset<ScrollPhysics> get physics => physicsArg.value;

  bool? get showScrollbar => showScrollbarArg?.value;

  bool get shrinkWrap => shrinkWrapArg.value;

  double? get itemExtent => itemExtentArg?.value;

  SlotPreset get prototypeItem => prototypeItemArg.value;

  int get itemCount => itemCountArg.value;

  Preset<Widget? Function(BuildContext, int)> get itemBuilder =>
      itemBuilderArg.value;

  Preset<int? Function(Key)> get findChildIndexCallback =>
      findChildIndexCallbackArg.value;

  bool get addAutomaticKeepAlives => addAutomaticKeepAlivesArg.value;

  bool get addRepaintBoundaries => addRepaintBoundariesArg.value;

  bool get addSemanticIndexes => addSemanticIndexesArg.value;

  Preset<ScrollCacheExtent> get scrollCacheExtent => scrollCacheExtentArg.value;

  int? get semanticChildCount => semanticChildCountArg?.value;

  DragStartBehavior get dragStartBehavior => dragStartBehaviorArg.value;

  ScrollViewKeyboardDismissBehavior? get keyboardDismissBehavior =>
      keyboardDismissBehaviorArg?.value;

  String? get restorationId => restorationIdArg?.value;

  Clip get clipBehavior => clipBehaviorArg.value;

  bool? get focusable => focusableArg?.value;

  Preset<String> get semanticsLabel => semanticsLabelArg.value;

  Preset<ScrollFocusStyle> get scrollFocusStyle => scrollFocusStyleArg.value;

  @override
  List<Arg?> get list => [
    styleArg,
    gapArg,
    scrollDirectionArg,
    reverseArg,
    controllerArg,
    primaryArg,
    physicsArg,
    showScrollbarArg,
    shrinkWrapArg,
    itemExtentArg,
    prototypeItemArg,
    itemCountArg,
    itemBuilderArg,
    findChildIndexCallbackArg,
    addAutomaticKeepAlivesArg,
    addRepaintBoundariesArg,
    addSemanticIndexesArg,
    scrollCacheExtentArg,
    semanticChildCountArg,
    dragStartBehaviorArg,
    keyboardDismissBehaviorArg,
    restorationIdArg,
    clipBehaviorArg,
    focusableArg,
    semanticsLabelArg,
    scrollFocusStyleArg,
  ];
}
