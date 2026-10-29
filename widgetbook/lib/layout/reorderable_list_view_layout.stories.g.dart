// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'reorderable_list_view_layout.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component =
    Component<ReorderableListViewLayout, StoryArgs<ReorderableListViewLayout>>;
typedef _BuilderScenario = ReorderableListViewLayoutBuilderScenario;
typedef _BuilderDefaults = ReorderableListViewLayoutBuilderDefaults;
typedef _BuilderStory = ReorderableListViewLayoutBuilderStory;
typedef _BuilderArgs = ReorderableListViewLayoutKnobsArgs;
final ReorderableListViewLayoutComponent =
    Component<ReorderableListViewLayout, StoryArgs<ReorderableListViewLayout>>(
      name: componentMeta.name ?? 'ReorderableListViewLayout',
      path: componentMeta.path ?? 'layout',
      docsBuilder: componentMeta.docsBuilder,
      docComment: r'''A lazy list whose items the user reorders, inside a [WidgetStyle] box.

Built on the widgets-level [SliverReorderableList]. Every item that
[itemBuilder] returns carries a key. A long press anywhere on an item
starts a drag when [longPressDrag] is true, on every platform; a handle
that the item wraps in [ReorderableDragStartListener] starts one on
pointer down and wins over the long press. [dragStyle] styles the lifted
item.

While a node inside item `i` holds focus, Alt+Up and Alt+Down (Alt+Left
and Alt+Right in a horizontal list, by screen direction) call
[onReorderItem] with `i - 1` or `i + 1`, and Alt+Home and Alt+End move
it to the start and the end; a move past either end does nothing but is
still handled, so the key never reaches the browser. On macOS Alt is
the Option key. The keys do nothing while focus is inside a text
field. A moved item keeps its State and focus, after a key move, a
screen reader's move action, or a drop, and is revealed after the move.
A pointer path without dragging, such as "Move up" and "Move down" menu
entries, is the job of the components built on this layout.

The box, keyboard scrolling, and Tab stop work as on [ListViewLayout];
plain arrows still scroll the list or move focus.

With an [itemsController], an item the app inserts into its data grows
along the main axis and fades in, and an item it removes shrinks and
fades out, over the theme's `normal` level on its `standard` curve. A
removed item keeps the look it had and is drawn in the slot of its
neighbor while it leaves, so every index the list reports is an index
of the app's data. Under reduced motion or a fixed item extent the size
changes at once and only the fade plays, a removed item fading over the
item that takes its place; under a fixed extent a removed last item
leaves at once. A leaving item takes no tap, drag, reorder key, or
focus, and focus inside it moves to the next item, else the one before,
else the list's own Tab stop when the list is focusable, unless the app
moves focus itself in the same turn. A focused item the app removes and
inserts back with its key in the same turn keeps focus, and the list
shows it at its new slot. A reorder of the item a leaving item is drawn
beside ends that leaving item at once.
[itemTransitionBuilder] replaces the built-in transition.
[ReorderableItemsController.moveItem] closes a moved item's old
slot while the item grows into its new one, and the item keeps its
State and focus.

An insert or remove during a drag, through [itemsController] or not,
and a `moveItem` call during one, end the drag first: the dragged item
goes back to its slot, [onReorderEnd] reports the index the drag
started at, and [onReorderItem] does not fire. A drag that starts
between an `insertItem`, `removeItem`, or `moveItem` call, or a move
the list reported through [onReorderItem], and the next frame ends the
same way at once. A reorder key or a screen reader's move during a drag
ends it the same way before it moves; while a dropped item settles, it
completes the drop at once — one [onReorderItem], the item in its new
slot, no second [onReorderEnd] — then moves (R52).''',
      stories: [
        $Playground..$generatedName = 'Playground',
        $RecipeFormRow..$generatedName = 'RecipeFormRow',
        $RecipeCard..$generatedName = 'RecipeCard',
        $RecipeListItem..$generatedName = 'RecipeListItem',
        $RecipeToolbar..$generatedName = 'RecipeToolbar',
        $RecipePageWithDrawer..$generatedName = 'RecipePageWithDrawer',
        $Responsive..$generatedName = 'Responsive',
        $Accessibility..$generatedName = 'Accessibility',
        $ExampleReorderableSettings
          ..$generatedName = 'ExampleReorderableSettings',
      ],
    );
typedef ReorderableListViewLayoutBuilderScenario =
    Scenario<ReorderableListViewLayout, ReorderableListViewLayoutKnobsArgs>;
typedef ReorderableListViewLayoutBuilderDefaults =
    Defaults<ReorderableListViewLayout, ReorderableListViewLayoutKnobsArgs>;

class ReorderableListViewLayoutBuilderStory
    extends
        Story<ReorderableListViewLayout, ReorderableListViewLayoutKnobsArgs> {
  ReorderableListViewLayoutBuilderStory({
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

class ReorderableListViewLayoutKnobsArgs
    extends StoryArgs<ReorderableListViewLayout> {
  ReorderableListViewLayoutKnobsArgs({
    required Arg<Preset<WidgetStyle>> style,
    Arg<Axis>? scrollDirection,
    Arg<bool>? reverse,
    required Arg<Preset<ScrollController>> controller,
    Arg<bool?>? primary,
    required Arg<Preset<ScrollPhysics>> physics,
    Arg<bool?>? showScrollbar,
    Arg<bool>? shrinkWrap,
    Arg<double?>? itemExtent,
    required Arg<Preset<double? Function(int, SliverLayoutDimensions)?>>
    itemExtentBuilder,
    Arg<SlotPreset>? prototypeItem,
    Arg<int>? itemCount,
    required Arg<Preset<Widget Function(BuildContext, int)>> itemBuilder,
    Arg<bool>? onReorderItem,
    Arg<bool>? onReorderStart,
    Arg<bool>? onReorderEnd,
    required Arg<Preset<WidgetStyle>> dragStyle,
    Arg<bool>? longPressDrag,
    required Arg<Preset<ReorderableItemsController>> itemsController,
    required Arg<
      Preset<Widget Function(BuildContext, Animation<double>, Widget)?>
    >
    itemTransitionBuilder,
    required Arg<Preset<ScrollCacheExtent>> scrollCacheExtent,
    Arg<DragStartBehavior>? dragStartBehavior,
    Arg<ScrollViewKeyboardDismissBehavior?>? keyboardDismissBehavior,
    Arg<String?>? restorationId,
    Arg<Clip>? clipBehavior,
    Arg<double?>? autoScrollerVelocityScalar,
    Arg<bool?>? focusable,
    required Arg<Preset<String>> semanticsLabel,
    required Arg<Preset<ScrollFocusStyle>> scrollFocusStyle,
    required Arg<Preset<int? Function(Key)>> findChildIndexCallback,
    required Arg<Preset<String Function(int, int)>> moveAnnouncement,
    required Arg<Preset<String>> atStartAnnouncement,
    required Arg<Preset<String>> atEndAnnouncement,
  }) : this.styleArg = $initArg('style', style, null)!,
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
       this.itemExtentBuilderArg = $initArg(
         'itemExtentBuilder',
         itemExtentBuilder,
         null,
       )!,
       this.prototypeItemArg = $initArg(
         'prototypeItem',
         prototypeItem,
         EnumArg<SlotPreset>(SlotPreset.none, values: SlotPreset.values),
       )!,
       this.itemCountArg = $initArg('itemCount', itemCount, IntArg(0))!,
       this.itemBuilderArg = $initArg('itemBuilder', itemBuilder, null)!,
       this.onReorderItemArg = $initArg(
         'onReorderItem',
         onReorderItem,
         BoolArg(true),
       )!,
       this.onReorderStartArg = $initArg(
         'onReorderStart',
         onReorderStart,
         BoolArg(true),
       )!,
       this.onReorderEndArg = $initArg(
         'onReorderEnd',
         onReorderEnd,
         BoolArg(true),
       )!,
       this.dragStyleArg = $initArg('dragStyle', dragStyle, null)!,
       this.longPressDragArg = $initArg(
         'longPressDrag',
         longPressDrag,
         BoolArg(true),
       )!,
       this.itemsControllerArg = $initArg(
         'itemsController',
         itemsController,
         null,
       )!,
       this.itemTransitionBuilderArg = $initArg(
         'itemTransitionBuilder',
         itemTransitionBuilder,
         null,
       )!,
       this.scrollCacheExtentArg = $initArg(
         'scrollCacheExtent',
         scrollCacheExtent,
         null,
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
       this.autoScrollerVelocityScalarArg = $initArg(
         'autoScrollerVelocityScalar',
         autoScrollerVelocityScalar,
         NullableDoubleArg(null),
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
       )!,
       this.findChildIndexCallbackArg = $initArg(
         'findChildIndexCallback',
         findChildIndexCallback,
         null,
       )!,
       this.moveAnnouncementArg = $initArg(
         'moveAnnouncement',
         moveAnnouncement,
         null,
       )!,
       this.atStartAnnouncementArg = $initArg(
         'atStartAnnouncement',
         atStartAnnouncement,
         null,
       )!,
       this.atEndAnnouncementArg = $initArg(
         'atEndAnnouncement',
         atEndAnnouncement,
         null,
       )!;

  ReorderableListViewLayoutKnobsArgs.fixed({
    required Preset<WidgetStyle> style,
    Axis scrollDirection = Axis.vertical,
    bool reverse = false,
    required Preset<ScrollController> controller,
    bool? primary = null,
    required Preset<ScrollPhysics> physics,
    bool? showScrollbar = null,
    bool shrinkWrap = false,
    double? itemExtent = null,
    required Preset<double? Function(int, SliverLayoutDimensions)?>
    itemExtentBuilder,
    SlotPreset prototypeItem = SlotPreset.none,
    int itemCount = 0,
    required Preset<Widget Function(BuildContext, int)> itemBuilder,
    bool onReorderItem = true,
    bool onReorderStart = true,
    bool onReorderEnd = true,
    required Preset<WidgetStyle> dragStyle,
    bool longPressDrag = true,
    required Preset<ReorderableItemsController> itemsController,
    required Preset<Widget Function(BuildContext, Animation<double>, Widget)?>
    itemTransitionBuilder,
    required Preset<ScrollCacheExtent> scrollCacheExtent,
    DragStartBehavior dragStartBehavior = DragStartBehavior.start,
    ScrollViewKeyboardDismissBehavior? keyboardDismissBehavior = null,
    String? restorationId = null,
    Clip clipBehavior = Clip.hardEdge,
    double? autoScrollerVelocityScalar = null,
    bool? focusable = null,
    required Preset<String> semanticsLabel,
    required Preset<ScrollFocusStyle> scrollFocusStyle,
    required Preset<int? Function(Key)> findChildIndexCallback,
    required Preset<String Function(int, int)> moveAnnouncement,
    required Preset<String> atStartAnnouncement,
    required Preset<String> atEndAnnouncement,
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
       this.itemExtentBuilderArg = $initArg(
         'itemExtentBuilder',
         Arg.fixed(itemExtentBuilder),
         null,
       )!,
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
       this.onReorderItemArg = $initArg(
         'onReorderItem',
         Arg.fixed(onReorderItem),
         null,
       )!,
       this.onReorderStartArg = $initArg(
         'onReorderStart',
         Arg.fixed(onReorderStart),
         null,
       )!,
       this.onReorderEndArg = $initArg(
         'onReorderEnd',
         Arg.fixed(onReorderEnd),
         null,
       )!,
       this.dragStyleArg = $initArg('dragStyle', Arg.fixed(dragStyle), null)!,
       this.longPressDragArg = $initArg(
         'longPressDrag',
         Arg.fixed(longPressDrag),
         null,
       )!,
       this.itemsControllerArg = $initArg(
         'itemsController',
         Arg.fixed(itemsController),
         null,
       )!,
       this.itemTransitionBuilderArg = $initArg(
         'itemTransitionBuilder',
         Arg.fixed(itemTransitionBuilder),
         null,
       )!,
       this.scrollCacheExtentArg = $initArg(
         'scrollCacheExtent',
         Arg.fixed(scrollCacheExtent),
         null,
       )!,
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
       this.autoScrollerVelocityScalarArg = $initArg(
         'autoScrollerVelocityScalar',
         autoScrollerVelocityScalar == null
             ? null
             : Arg.fixed(autoScrollerVelocityScalar),
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
       )!,
       this.findChildIndexCallbackArg = $initArg(
         'findChildIndexCallback',
         Arg.fixed(findChildIndexCallback),
         null,
       )!,
       this.moveAnnouncementArg = $initArg(
         'moveAnnouncement',
         Arg.fixed(moveAnnouncement),
         null,
       )!,
       this.atStartAnnouncementArg = $initArg(
         'atStartAnnouncement',
         Arg.fixed(atStartAnnouncement),
         null,
       )!,
       this.atEndAnnouncementArg = $initArg(
         'atEndAnnouncement',
         Arg.fixed(atEndAnnouncement),
         null,
       )!;

  final Arg<Preset<WidgetStyle>> styleArg;

  final Arg<Axis> scrollDirectionArg;

  final Arg<bool> reverseArg;

  final Arg<Preset<ScrollController>> controllerArg;

  final Arg<bool?>? primaryArg;

  final Arg<Preset<ScrollPhysics>> physicsArg;

  final Arg<bool?>? showScrollbarArg;

  final Arg<bool> shrinkWrapArg;

  final Arg<double?>? itemExtentArg;

  final Arg<Preset<double? Function(int, SliverLayoutDimensions)?>>
  itemExtentBuilderArg;

  final Arg<SlotPreset> prototypeItemArg;

  final Arg<int> itemCountArg;

  final Arg<Preset<Widget Function(BuildContext, int)>> itemBuilderArg;

  final Arg<bool> onReorderItemArg;

  final Arg<bool> onReorderStartArg;

  final Arg<bool> onReorderEndArg;

  final Arg<Preset<WidgetStyle>> dragStyleArg;

  final Arg<bool> longPressDragArg;

  final Arg<Preset<ReorderableItemsController>> itemsControllerArg;

  final Arg<Preset<Widget Function(BuildContext, Animation<double>, Widget)?>>
  itemTransitionBuilderArg;

  final Arg<Preset<ScrollCacheExtent>> scrollCacheExtentArg;

  final Arg<DragStartBehavior> dragStartBehaviorArg;

  final Arg<ScrollViewKeyboardDismissBehavior?>? keyboardDismissBehaviorArg;

  final Arg<String?>? restorationIdArg;

  final Arg<Clip> clipBehaviorArg;

  final Arg<double?>? autoScrollerVelocityScalarArg;

  final Arg<bool?>? focusableArg;

  final Arg<Preset<String>> semanticsLabelArg;

  final Arg<Preset<ScrollFocusStyle>> scrollFocusStyleArg;

  final Arg<Preset<int? Function(Key)>> findChildIndexCallbackArg;

  final Arg<Preset<String Function(int, int)>> moveAnnouncementArg;

  final Arg<Preset<String>> atStartAnnouncementArg;

  final Arg<Preset<String>> atEndAnnouncementArg;

  Preset<WidgetStyle> get style => styleArg.value;

  Axis get scrollDirection => scrollDirectionArg.value;

  bool get reverse => reverseArg.value;

  Preset<ScrollController> get controller => controllerArg.value;

  bool? get primary => primaryArg?.value;

  Preset<ScrollPhysics> get physics => physicsArg.value;

  bool? get showScrollbar => showScrollbarArg?.value;

  bool get shrinkWrap => shrinkWrapArg.value;

  double? get itemExtent => itemExtentArg?.value;

  Preset<double? Function(int, SliverLayoutDimensions)?>
  get itemExtentBuilder => itemExtentBuilderArg.value;

  SlotPreset get prototypeItem => prototypeItemArg.value;

  int get itemCount => itemCountArg.value;

  Preset<Widget Function(BuildContext, int)> get itemBuilder =>
      itemBuilderArg.value;

  bool get onReorderItem => onReorderItemArg.value;

  bool get onReorderStart => onReorderStartArg.value;

  bool get onReorderEnd => onReorderEndArg.value;

  Preset<WidgetStyle> get dragStyle => dragStyleArg.value;

  bool get longPressDrag => longPressDragArg.value;

  Preset<ReorderableItemsController> get itemsController =>
      itemsControllerArg.value;

  Preset<Widget Function(BuildContext, Animation<double>, Widget)?>
  get itemTransitionBuilder => itemTransitionBuilderArg.value;

  Preset<ScrollCacheExtent> get scrollCacheExtent => scrollCacheExtentArg.value;

  DragStartBehavior get dragStartBehavior => dragStartBehaviorArg.value;

  ScrollViewKeyboardDismissBehavior? get keyboardDismissBehavior =>
      keyboardDismissBehaviorArg?.value;

  String? get restorationId => restorationIdArg?.value;

  Clip get clipBehavior => clipBehaviorArg.value;

  double? get autoScrollerVelocityScalar =>
      autoScrollerVelocityScalarArg?.value;

  bool? get focusable => focusableArg?.value;

  Preset<String> get semanticsLabel => semanticsLabelArg.value;

  Preset<ScrollFocusStyle> get scrollFocusStyle => scrollFocusStyleArg.value;

  Preset<int? Function(Key)> get findChildIndexCallback =>
      findChildIndexCallbackArg.value;

  Preset<String Function(int, int)> get moveAnnouncement =>
      moveAnnouncementArg.value;

  Preset<String> get atStartAnnouncement => atStartAnnouncementArg.value;

  Preset<String> get atEndAnnouncement => atEndAnnouncementArg.value;

  @override
  List<Arg?> get list => [
    styleArg,
    scrollDirectionArg,
    reverseArg,
    controllerArg,
    primaryArg,
    physicsArg,
    showScrollbarArg,
    shrinkWrapArg,
    itemExtentArg,
    itemExtentBuilderArg,
    prototypeItemArg,
    itemCountArg,
    itemBuilderArg,
    onReorderItemArg,
    onReorderStartArg,
    onReorderEndArg,
    dragStyleArg,
    longPressDragArg,
    itemsControllerArg,
    itemTransitionBuilderArg,
    scrollCacheExtentArg,
    dragStartBehaviorArg,
    keyboardDismissBehaviorArg,
    restorationIdArg,
    clipBehaviorArg,
    autoScrollerVelocityScalarArg,
    focusableArg,
    semanticsLabelArg,
    scrollFocusStyleArg,
    findChildIndexCallbackArg,
    moveAnnouncementArg,
    atStartAnnouncementArg,
    atEndAnnouncementArg,
  ];
}
