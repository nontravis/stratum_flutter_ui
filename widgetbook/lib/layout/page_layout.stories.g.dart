// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'page_layout.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<PageLayout, StoryArgs<PageLayout>>;
typedef _Scenario = PageLayoutScenario;
typedef _Defaults = PageLayoutDefaults;
typedef _Story = PageLayoutStory;
typedef _Args = PageLayoutKnobsArgs;
final PageLayoutComponent = Component<PageLayout, StoryArgs<PageLayout>>(
  name: componentMeta.name ?? 'PageLayout',
  path: componentMeta.path ?? 'layout',
  docsBuilder: componentMeta.docsBuilder,
  docComment:
      r'''A page's slots in the geometry of the Figma page layout (US-18 FR-01):
[header] across the full width on top; below it [left], full height
between [header] and [footer], beside a main column of [top] over the
center column ([tab] over [body] over [bottom]) and [right], which starts
under [top]; [footer] across the full width at the end; and [snack]
floating at the bottom center over every slot, taking no layout space.

A null slot builds nothing and takes no space. [left] is the start side
and [right] the end side, so both mirror under [TextDirection.rtl].
Slots take plain widgets: the app picks what rebuilds by placing its own
state listener inside one slot or around the whole page (US-18 FR-02).
Each slot sits under its own repaint boundary and a transparent
[Material], so a slot hosts any SDK widget with no `Scaffold`.

Every slot that touches a screen edge fills under that edge's system
inset while its content pads by it, as [safeArea] allows; [body] instead
hands its top and bottom insets to its children, so a body list scrolls
under the home indicator with its last item able to scroll clear.
Children read the media insets with the page's share removed, so a
nested page pads nothing twice (US-18 FR-04). While the keyboard is open
and [resizeToAvoidKeyboard] holds, the page above [footer] ends at the
keyboard's top, so [bottom] rides above it, and [footer] stays docked at
the bottom edge under the keyboard (US-18 FR-05).

Below [drawerCut], [WindowSize.tablet] by default, [left] and [right]
are drawers that take no space: [PageLayoutController.openLeft] and
[PageLayoutController.openRight] open them, a swipe from their screen
edge opens them while [edgeSwipe] holds, and a tap on the scrim, a drag
toward their edge, Esc, or back closes them, back before the route pops.
[leftSide] and [rightSide] set each drawer's type, width bounds, page
scale, and label, and [onDrawerChanged] hears each open and close. An
open drawer keeps focus inside it, reads as its own named screen, and
hides the page behind from screen readers (US-19 FR-02 to FR-05).

At and above the cut both sides sit inline beside the center column, as
two nested [SplitLayout]s, with a divider the EndUser drags or moves by
the arrow, Home, and End keys, within the side's width bounds. A divider
paints only what [leftDividerBuilder] or [rightDividerBuilder] paints,
while it always takes the drag, the keys, and focus, and reads as a
slider. Each pane opens at the controller's chosen width, else at its
Figma width, and the controller hears each settled resize as the new
width (US-19 FR-06). With [rightAsOverlay], [right] opens there instead
as a front drawer over a scrim, with a close button (US-19 FR-01). A
drawer open as the window crosses into inline panes closes.

While [loading] holds, a layer over the whole page refuses every tap and
keyboard focus, reads as a live region with the built-in loading label,
and shows [loadingBuilder]'s widget, else a plain spinner; focus returns
to where it sat once [loading] turns false. The layer fades in and out
over the theme's `fast` level with no other movement (US-18 FR-06).

Each part's style layers the theme defaults, then the app-wide
[PageLayoutStyle] the application registers for [PageLayout], then
[customStyle] (FO-08 US-06 FR-01). Tab visits [header], [left] and its
divider, [top], [tab], [body], [bottom], the divider of [right] and
[right], [footer], then [snack] (NFR-U02).

The page needs bounded constraints, as a route's page has.

A solid slot fill or page fill declares itself to the system bar
resolver, so the automatic bar icons pick against what the page paints
under each bar; a gradient or image fill declares nothing, and the app
wraps its own `SystemBarFill` or sets explicit icons (US-18 FR-07).
[systemStyle] sets this page's bar style as an inner scope over the
app-wide one.''',
  stories: [
    $Playground..$generatedName = 'Playground',
    $RecipeFormRow..$generatedName = 'RecipeFormRow',
    $RecipeCard..$generatedName = 'RecipeCard',
    $RecipeListItem..$generatedName = 'RecipeListItem',
    $RecipeToolbar..$generatedName = 'RecipeToolbar',
    $RecipePageWithDrawer..$generatedName = 'RecipePageWithDrawer',
    $Responsive..$generatedName = 'Responsive',
    $Accessibility..$generatedName = 'Accessibility',
    $ExampleScreenWithABottomBar
      ..$generatedName = 'ExampleScreenWithABottomBar',
  ],
);
typedef PageLayoutScenario = Scenario<PageLayout, PageLayoutKnobsArgs>;
typedef PageLayoutDefaults = Defaults<PageLayout, PageLayoutKnobsArgs>;

class PageLayoutStory extends Story<PageLayout, PageLayoutKnobsArgs> {
  PageLayoutStory({
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

class PageLayoutKnobsArgs extends StoryArgs<PageLayout> {
  PageLayoutKnobsArgs({
    Arg<SlotPreset>? header,
    Arg<SlotPreset>? left,
    Arg<SlotPreset>? top,
    Arg<SlotPreset>? tab,
    Arg<SlotPreset>? body,
    Arg<SlotPreset>? bottom,
    Arg<SlotPreset>? right,
    Arg<SlotPreset>? footer,
    Arg<SlotPreset>? snack,
    required Arg<RequiredPreset<PageSafeArea>> safeArea,
    Arg<bool>? resizeToAvoidKeyboard,
    Arg<bool>? loading,
    required Arg<Preset<Widget Function(BuildContext)>> loadingBuilder,
    required Arg<Preset<PageLayoutController>> controller,
    required Arg<RequiredPreset<PageSide>> leftSide,
    required Arg<RequiredPreset<PageSide>> rightSide,
    Arg<WindowSize>? drawerCut,
    Arg<bool>? rightAsOverlay,
    Arg<double>? minCenterWidth,
    required Arg<Preset<Widget Function(BuildContext, SplitDividerState)>>
    leftDividerBuilder,
    required Arg<Preset<Widget Function(BuildContext, SplitDividerState)>>
    rightDividerBuilder,
    Arg<bool>? edgeSwipe,
    Arg<bool>? onDrawerChanged,
    required Arg<Preset<PageLayoutStyle>> customStyle,
    required Arg<Preset<SystemStyle>> systemStyle,
    required Arg<Preset<WidgetSettingKey>> setting,
  }) : this.headerArg = $initArg(
         'header',
         header,
         EnumArg<SlotPreset>(SlotPreset.slot, values: SlotPreset.values),
       )!,
       this.leftArg = $initArg(
         'left',
         left,
         EnumArg<SlotPreset>(SlotPreset.slot, values: SlotPreset.values),
       )!,
       this.topArg = $initArg(
         'top',
         top,
         EnumArg<SlotPreset>(SlotPreset.slot, values: SlotPreset.values),
       )!,
       this.tabArg = $initArg(
         'tab',
         tab,
         EnumArg<SlotPreset>(SlotPreset.slot, values: SlotPreset.values),
       )!,
       this.bodyArg = $initArg(
         'body',
         body,
         EnumArg<SlotPreset>(SlotPreset.slot, values: SlotPreset.values),
       )!,
       this.bottomArg = $initArg(
         'bottom',
         bottom,
         EnumArg<SlotPreset>(SlotPreset.slot, values: SlotPreset.values),
       )!,
       this.rightArg = $initArg(
         'right',
         right,
         EnumArg<SlotPreset>(SlotPreset.slot, values: SlotPreset.values),
       )!,
       this.footerArg = $initArg(
         'footer',
         footer,
         EnumArg<SlotPreset>(SlotPreset.slot, values: SlotPreset.values),
       )!,
       this.snackArg = $initArg(
         'snack',
         snack,
         EnumArg<SlotPreset>(SlotPreset.slot, values: SlotPreset.values),
       )!,
       this.safeAreaArg = $initArg('safeArea', safeArea, null)!,
       this.resizeToAvoidKeyboardArg = $initArg(
         'resizeToAvoidKeyboard',
         resizeToAvoidKeyboard,
         BoolArg(true),
       )!,
       this.loadingArg = $initArg('loading', loading, BoolArg(false))!,
       this.loadingBuilderArg = $initArg(
         'loadingBuilder',
         loadingBuilder,
         null,
       )!,
       this.controllerArg = $initArg('controller', controller, null)!,
       this.leftSideArg = $initArg('leftSide', leftSide, null)!,
       this.rightSideArg = $initArg('rightSide', rightSide, null)!,
       this.drawerCutArg = $initArg(
         'drawerCut',
         drawerCut,
         EnumArg<WindowSize>(WindowSize.tablet, values: WindowSize.values),
       )!,
       this.rightAsOverlayArg = $initArg(
         'rightAsOverlay',
         rightAsOverlay,
         BoolArg(false),
       )!,
       this.minCenterWidthArg = $initArg(
         'minCenterWidth',
         minCenterWidth,
         DoubleArg(320),
       )!,
       this.leftDividerBuilderArg = $initArg(
         'leftDividerBuilder',
         leftDividerBuilder,
         null,
       )!,
       this.rightDividerBuilderArg = $initArg(
         'rightDividerBuilder',
         rightDividerBuilder,
         null,
       )!,
       this.edgeSwipeArg = $initArg('edgeSwipe', edgeSwipe, BoolArg(true))!,
       this.onDrawerChangedArg = $initArg(
         'onDrawerChanged',
         onDrawerChanged,
         BoolArg(true),
       )!,
       this.customStyleArg = $initArg('customStyle', customStyle, null)!,
       this.systemStyleArg = $initArg('systemStyle', systemStyle, null)!,
       this.settingArg = $initArg('setting', setting, null)!;

  PageLayoutKnobsArgs.fixed({
    SlotPreset header = SlotPreset.slot,
    SlotPreset left = SlotPreset.slot,
    SlotPreset top = SlotPreset.slot,
    SlotPreset tab = SlotPreset.slot,
    SlotPreset body = SlotPreset.slot,
    SlotPreset bottom = SlotPreset.slot,
    SlotPreset right = SlotPreset.slot,
    SlotPreset footer = SlotPreset.slot,
    SlotPreset snack = SlotPreset.slot,
    required RequiredPreset<PageSafeArea> safeArea,
    bool resizeToAvoidKeyboard = true,
    bool loading = false,
    required Preset<Widget Function(BuildContext)> loadingBuilder,
    required Preset<PageLayoutController> controller,
    required RequiredPreset<PageSide> leftSide,
    required RequiredPreset<PageSide> rightSide,
    WindowSize drawerCut = WindowSize.tablet,
    bool rightAsOverlay = false,
    double minCenterWidth = 320,
    required Preset<Widget Function(BuildContext, SplitDividerState)>
    leftDividerBuilder,
    required Preset<Widget Function(BuildContext, SplitDividerState)>
    rightDividerBuilder,
    bool edgeSwipe = true,
    bool onDrawerChanged = true,
    required Preset<PageLayoutStyle> customStyle,
    required Preset<SystemStyle> systemStyle,
    required Preset<WidgetSettingKey> setting,
  }) : this.headerArg = $initArg('header', Arg.fixed(header), null)!,
       this.leftArg = $initArg('left', Arg.fixed(left), null)!,
       this.topArg = $initArg('top', Arg.fixed(top), null)!,
       this.tabArg = $initArg('tab', Arg.fixed(tab), null)!,
       this.bodyArg = $initArg('body', Arg.fixed(body), null)!,
       this.bottomArg = $initArg('bottom', Arg.fixed(bottom), null)!,
       this.rightArg = $initArg('right', Arg.fixed(right), null)!,
       this.footerArg = $initArg('footer', Arg.fixed(footer), null)!,
       this.snackArg = $initArg('snack', Arg.fixed(snack), null)!,
       this.safeAreaArg = $initArg('safeArea', Arg.fixed(safeArea), null)!,
       this.resizeToAvoidKeyboardArg = $initArg(
         'resizeToAvoidKeyboard',
         Arg.fixed(resizeToAvoidKeyboard),
         null,
       )!,
       this.loadingArg = $initArg('loading', Arg.fixed(loading), null)!,
       this.loadingBuilderArg = $initArg(
         'loadingBuilder',
         Arg.fixed(loadingBuilder),
         null,
       )!,
       this.controllerArg = $initArg(
         'controller',
         Arg.fixed(controller),
         null,
       )!,
       this.leftSideArg = $initArg('leftSide', Arg.fixed(leftSide), null)!,
       this.rightSideArg = $initArg('rightSide', Arg.fixed(rightSide), null)!,
       this.drawerCutArg = $initArg('drawerCut', Arg.fixed(drawerCut), null)!,
       this.rightAsOverlayArg = $initArg(
         'rightAsOverlay',
         Arg.fixed(rightAsOverlay),
         null,
       )!,
       this.minCenterWidthArg = $initArg(
         'minCenterWidth',
         Arg.fixed(minCenterWidth),
         null,
       )!,
       this.leftDividerBuilderArg = $initArg(
         'leftDividerBuilder',
         Arg.fixed(leftDividerBuilder),
         null,
       )!,
       this.rightDividerBuilderArg = $initArg(
         'rightDividerBuilder',
         Arg.fixed(rightDividerBuilder),
         null,
       )!,
       this.edgeSwipeArg = $initArg('edgeSwipe', Arg.fixed(edgeSwipe), null)!,
       this.onDrawerChangedArg = $initArg(
         'onDrawerChanged',
         Arg.fixed(onDrawerChanged),
         null,
       )!,
       this.customStyleArg = $initArg(
         'customStyle',
         Arg.fixed(customStyle),
         null,
       )!,
       this.systemStyleArg = $initArg(
         'systemStyle',
         Arg.fixed(systemStyle),
         null,
       )!,
       this.settingArg = $initArg('setting', Arg.fixed(setting), null)!;

  final Arg<SlotPreset> headerArg;

  final Arg<SlotPreset> leftArg;

  final Arg<SlotPreset> topArg;

  final Arg<SlotPreset> tabArg;

  final Arg<SlotPreset> bodyArg;

  final Arg<SlotPreset> bottomArg;

  final Arg<SlotPreset> rightArg;

  final Arg<SlotPreset> footerArg;

  final Arg<SlotPreset> snackArg;

  final Arg<RequiredPreset<PageSafeArea>> safeAreaArg;

  final Arg<bool> resizeToAvoidKeyboardArg;

  final Arg<bool> loadingArg;

  final Arg<Preset<Widget Function(BuildContext)>> loadingBuilderArg;

  final Arg<Preset<PageLayoutController>> controllerArg;

  final Arg<RequiredPreset<PageSide>> leftSideArg;

  final Arg<RequiredPreset<PageSide>> rightSideArg;

  final Arg<WindowSize> drawerCutArg;

  final Arg<bool> rightAsOverlayArg;

  final Arg<double> minCenterWidthArg;

  final Arg<Preset<Widget Function(BuildContext, SplitDividerState)>>
  leftDividerBuilderArg;

  final Arg<Preset<Widget Function(BuildContext, SplitDividerState)>>
  rightDividerBuilderArg;

  final Arg<bool> edgeSwipeArg;

  final Arg<bool> onDrawerChangedArg;

  final Arg<Preset<PageLayoutStyle>> customStyleArg;

  final Arg<Preset<SystemStyle>> systemStyleArg;

  final Arg<Preset<WidgetSettingKey>> settingArg;

  SlotPreset get header => headerArg.value;

  SlotPreset get left => leftArg.value;

  SlotPreset get top => topArg.value;

  SlotPreset get tab => tabArg.value;

  SlotPreset get body => bodyArg.value;

  SlotPreset get bottom => bottomArg.value;

  SlotPreset get right => rightArg.value;

  SlotPreset get footer => footerArg.value;

  SlotPreset get snack => snackArg.value;

  RequiredPreset<PageSafeArea> get safeArea => safeAreaArg.value;

  bool get resizeToAvoidKeyboard => resizeToAvoidKeyboardArg.value;

  bool get loading => loadingArg.value;

  Preset<Widget Function(BuildContext)> get loadingBuilder =>
      loadingBuilderArg.value;

  Preset<PageLayoutController> get controller => controllerArg.value;

  RequiredPreset<PageSide> get leftSide => leftSideArg.value;

  RequiredPreset<PageSide> get rightSide => rightSideArg.value;

  WindowSize get drawerCut => drawerCutArg.value;

  bool get rightAsOverlay => rightAsOverlayArg.value;

  double get minCenterWidth => minCenterWidthArg.value;

  Preset<Widget Function(BuildContext, SplitDividerState)>
  get leftDividerBuilder => leftDividerBuilderArg.value;

  Preset<Widget Function(BuildContext, SplitDividerState)>
  get rightDividerBuilder => rightDividerBuilderArg.value;

  bool get edgeSwipe => edgeSwipeArg.value;

  bool get onDrawerChanged => onDrawerChangedArg.value;

  Preset<PageLayoutStyle> get customStyle => customStyleArg.value;

  Preset<SystemStyle> get systemStyle => systemStyleArg.value;

  Preset<WidgetSettingKey> get setting => settingArg.value;

  @override
  List<Arg?> get list => [
    headerArg,
    leftArg,
    topArg,
    tabArg,
    bodyArg,
    bottomArg,
    rightArg,
    footerArg,
    snackArg,
    safeAreaArg,
    resizeToAvoidKeyboardArg,
    loadingArg,
    loadingBuilderArg,
    controllerArg,
    leftSideArg,
    rightSideArg,
    drawerCutArg,
    rightAsOverlayArg,
    minCenterWidthArg,
    leftDividerBuilderArg,
    rightDividerBuilderArg,
    edgeSwipeArg,
    onDrawerChangedArg,
    customStyleArg,
    systemStyleArg,
    settingArg,
  ];
}
