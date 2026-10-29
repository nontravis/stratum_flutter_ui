import 'dart:async';

import 'package:stratum_ui/stratum_ui.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

import '../kit/callback_report.dart';
import '../kit/docs/catalog_docs.dart';
import '../kit/docs/stratum_docs.dart';
import '../kit/preset.dart';
import '../kit/slot_preset.dart';
import '../kit/story_set.dart';
import '../shell/catalog_section.dart';
import 'layout_page.dart';
import 'page_layout_knobs.dart';
import 'recipes.dart';

part 'page_layout.stories.g.dart';

const _docs = CatalogDocs(
  figma: null,
  usage: '''
PageLayout(
  header: AppHeader(),
  left: Navigation(),
  body: Content(),
  footer: ActionBar(),
)''',
  dos: [
    'Use it for a whole screen: every slot is optional, and a null slot '
        'takes no space.',
    'Give it bounded constraints, such as a screen or a SizedBox.',
    'Pass a PageLayoutController to open and close the drawers from code.',
    recipeWindowDo,
  ],
  donts: [
    'Nest a Scaffold in a slot; each slot already hosts any widget on a '
        'transparent Material.',
    'Expect the left or right slot inline below drawerCut; they are '
        'drawers there and take no space until opened.',
  ],
  accessibility: [
    'An open drawer keeps focus inside it, reads as its own named screen, '
        'and hides the page behind it from a screen reader.',
    'The divider beside an inline pane is a Tab stop; the arrow keys step '
        'its width.',
    'The loading layer blocks the page and announces that it is busy.',
  ],
);

const meta = Meta(PageLayout.new, argsType: PageLayoutKnobs.new);

final componentMeta = ComponentMeta(
  name: 'PageLayout',
  path: CatalogSection.layout.label,
  docsBuilder: stratumDocs(
    _docs,
    args: [for (final arg in $Playground.args.list) ?arg],
  ),
);

/// The height the page stories give the page, since a page needs bounded
/// constraints.
const _height = 480.0;

/// A fresh set of knobs: one per constructor param, in constructor order.
PageLayoutKnobsArgs _knobs() => PageLayoutKnobsArgs(
  safeArea: PresetArg(_safeAreas.first, name: 'safeArea', values: _safeAreas),
  loadingBuilder: PresetArg(
    _loadingBuilders.first,
    name: 'loadingBuilder',
    values: _loadingBuilders,
  ),
  controller: PresetArg(
    _controllers.first,
    name: 'controller',
    values: _controllers,
  ),
  leftSide: PresetArg(_sides.first, name: 'leftSide', values: _sides),
  rightSide: PresetArg(_sides.first, name: 'rightSide', values: _sides),
  leftDividerBuilder: PresetArg(
    _leftDividers.first,
    name: 'leftDividerBuilder',
    values: _leftDividers,
  ),
  rightDividerBuilder: PresetArg(
    _rightDividers.first,
    name: 'rightDividerBuilder',
    values: _rightDividers,
  ),
  customStyle: PresetArg(
    _customStyles.first,
    name: 'customStyle',
    values: _customStyles,
  ),
  systemStyle: PresetArg(
    _systemStyles.first,
    name: 'systemStyle',
    values: _systemStyles,
  ),
  setting: PresetArg(_settings.first, name: 'setting', values: _settings),
);

final _safeAreas = <Preset<PageSafeArea>>[
  const Preset('Default', _defaultSafeArea),
  const Preset('None', _noSafeArea),
];

PageSafeArea? _defaultSafeArea(BuildContext context) => const PageSafeArea();
PageSafeArea? _noSafeArea(BuildContext context) =>
    const PageSafeArea(top: false, bottom: false, left: false, right: false);

final _loadingBuilders = <Preset<WidgetBuilder>>[
  const Preset('None', _noWidgetBuilder),
  Preset(
    'Slot',
    (_) =>
        (context) => const StratumSlot(name: 'loading'),
  ),
];

WidgetBuilder? _noWidgetBuilder(BuildContext context) => null;

final _controllers = <Preset<PageLayoutController>>[
  const Preset('None', _noController),
  const Preset('Story controller', _StoryScope.controllerOf),
];

PageLayoutController? _noController(BuildContext context) => null;

final _sides = <Preset<PageSide>>[
  const Preset('Default', _defaultSide),
  const Preset('Wide', _wideSide),
];

PageSide? _defaultSide(BuildContext context) => const PageSide();
PageSide? _wideSide(BuildContext context) =>
    const PageSide(minWidth: 320, maxWidth: 400);

final _leftDividers = <Preset<SplitDividerBuilder>>[
  const Preset('None', _noDividerBuilder),
  Preset(
    'Slot',
    (_) =>
        (context, state) => const StratumSlot(name: 'left divider'),
  ),
];

final _rightDividers = <Preset<SplitDividerBuilder>>[
  const Preset('None', _noDividerBuilder),
  Preset(
    'Slot',
    (_) =>
        (context, state) => const StratumSlot(name: 'right divider'),
  ),
];

SplitDividerBuilder? _noDividerBuilder(BuildContext context) => null;

final _customStyles = <Preset<PageLayoutStyle>>[
  const Preset('None', _noStyle),
  Preset('Framed areas', (context) {
    final card = stylePreset('Card').build(context);
    return PageLayoutStyle(
      header: card,
      top: card,
      tab: card,
      left: card,
      body: card,
      right: card,
      bottom: card,
      footer: card,
      snack: card,
    );
  }),
];

PageLayoutStyle? _noStyle(BuildContext context) => null;

final _systemStyles = <Preset<SystemStyle>>[
  const Preset('None', _noSystemStyle),
  const Preset('Light icons', _lightIcons),
  const Preset('Dark icons', _darkIcons),
];

SystemStyle? _noSystemStyle(BuildContext context) => null;
SystemStyle? _lightIcons(BuildContext context) =>
    const SystemStyle(statusBarIcons: SystemBarIcons.light);
SystemStyle? _darkIcons(BuildContext context) =>
    const SystemStyle(statusBarIcons: SystemBarIcons.dark);

/// The setting keys this page offers; a keyed one needs the
/// `StratumWidgetSettings` the Playground setup places above the page.
final _settings = <Preset<WidgetSettingKey>>[
  const Preset('None', _noSetting),
  const Preset('Global', _globalSetting),
  const Preset('Catalog id', _catalogSetting),
];

WidgetSettingKey? _noSetting(BuildContext context) => null;
WidgetSettingKey? _globalSetting(BuildContext context) =>
    const WidgetSettingKey.global();
WidgetSettingKey? _catalogSetting(BuildContext context) =>
    const WidgetSettingKey.id('catalog');

/// Knobs for a story that has no Playground: fixed, so the panel hides them.
PageLayoutKnobsArgs _fixedKnobs() => PageLayoutKnobsArgs.fixed(
  safeArea: _safeAreas.first,
  loadingBuilder: _loadingBuilders.first,
  controller: _controllers.first,
  leftSide: _sides.first,
  rightSide: _sides.first,
  leftDividerBuilder: _leftDividers.first,
  rightDividerBuilder: _rightDividers.first,
  customStyle: _customStyles.first,
  systemStyle: _systemStyles.first,
  setting: _settings.first,
);

/// The page widget Widgetbook's builder must return; the frame stories show
/// their own layout through `setup`, which drops this child.
PageLayout _frameChild(BuildContext context, PageLayoutKnobsArgs args) =>
    _samplePage;

/// A page of a header, a start drawer, a body, and a footer.
const _samplePage = PageLayout(
  header: StratumSlot(name: 'header'),
  left: StratumSlot(name: 'left'),
  body: StratumSlot(name: 'body'),
  footer: StratumSlot(name: 'footer'),
);

/// The sample page on a bounded height, the layout every frame story shows.
Widget _sample(BuildContext context) =>
    const SizedBox(height: _height, child: _samplePage);

/// The sample page with its blocking loading layer on; the layer shows a
/// slot, since a spinner never lets a test settle.
Widget _loadingSample(BuildContext context) => const SizedBox(
  height: _height,
  child: PageLayout(
    header: StratumSlot(name: 'header'),
    left: StratumSlot(name: 'left'),
    body: StratumSlot(name: 'body'),
    footer: StratumSlot(name: 'footer'),
    loading: true,
    loadingBuilder: _loadingSlot,
  ),
);

Widget _loadingSlot(BuildContext context) =>
    const StratumSlot(name: 'loading layer');

final $Playground = _Story(
  args: _knobs(),
  setup: (context, child, args) => _StoryScope(
    child: SizedBox(
      height: _height,
      child: reportingSetup(context, child, args),
    ),
  ),
  builder: (context, args) => PageLayout(
    header: slotFor(context, args.header, name: 'header'),
    left: slotFor(context, args.left, name: 'left'),
    top: slotFor(context, args.top, name: 'top'),
    tab: slotFor(context, args.tab, name: 'tab'),
    body: slotFor(context, args.body, name: 'body'),
    bottom: slotFor(context, args.bottom, name: 'bottom'),
    right: slotFor(context, args.right, name: 'right'),
    footer: slotFor(context, args.footer, name: 'footer'),
    snack: slotFor(context, args.snack, name: 'snack'),
    safeArea: args.safeArea.valueOf(context),
    resizeToAvoidKeyboard: args.resizeToAvoidKeyboard,
    loading: args.loading,
    loadingBuilder: args.loadingBuilder.build(context),
    controller: args.controller.build(context),
    leftSide: args.leftSide.valueOf(context),
    rightSide: args.rightSide.valueOf(context),
    drawerCut: args.drawerCut,
    rightAsOverlay: args.rightAsOverlay,
    minCenterWidth: args.minCenterWidth,
    leftDividerBuilder: args.leftDividerBuilder.build(context),
    rightDividerBuilder: args.rightDividerBuilder.build(context),
    edgeSwipe: args.edgeSwipe,
    onDrawerChanged: args.onDrawerChanged
        ? reportValue<PageDrawerSide?>(context, 'onDrawerChanged')
        : null,
    customStyle: args.customStyle.build(context),
    systemStyle: args.systemStyle.build(context),
    setting: args.setting.build(context),
  ),
);

final $RecipeFormRow = _Story(
  name: StoryNames.recipes[0],
  args: _fixedKnobs(),
  builder: _frameChild,
  setup: (_, _, _) => recipeFrame(const FormRowRecipe()),
);

final $RecipeCard = _Story(
  name: StoryNames.recipes[1],
  args: _fixedKnobs(),
  builder: _frameChild,
  setup: (_, _, _) => recipeFrame(const CardRecipe()),
);

final $RecipeListItem = _Story(
  name: StoryNames.recipes[2],
  args: _fixedKnobs(),
  builder: _frameChild,
  setup: (_, _, _) => recipeFrame(const ListItemRecipe()),
);

final $RecipeToolbar = _Story(
  name: StoryNames.recipes[3],
  args: _fixedKnobs(),
  builder: _frameChild,
  setup: (_, _, _) => recipeFrame(const ToolbarRecipe()),
);

final $RecipePageWithDrawer = _Story(
  name: StoryNames.recipes[4],
  args: _fixedKnobs(),
  builder: _frameChild,
  setup: (_, _, _) => recipeFrame(const PageWithDrawerRecipe()),
);

final $Responsive = _Story(
  args: _fixedKnobs(),
  builder: _frameChild,
  setup: (_, _, _) => responsiveFrames(_sample),
);

final $Accessibility = _Story(
  args: _fixedKnobs(),
  builder: _frameChild,
  setup: (_, _, _) =>
      accessibilityFrames(build: _sample, states: {'Loading': _loadingSample}),
);

final $ExampleScreenWithABottomBar = _Story(
  name: StoryNames.example('screen with a bottom bar'),
  args: _fixedKnobs(),
  builder: _frameChild,
  setup: (_, _, _) => const SizedBox(
    height: _height,
    child: PageLayout(
      header: StratumSlot(name: 'header'),
      body: StratumSlot(name: 'body'),
      bottom: StratumSlot(name: 'bottom bar'),
    ),
  ),
);

/// Holds the page controller the `Story controller` preset hands out and the
/// settings controller of the `StratumWidgetSettings` above the page, and
/// disposes both with the story.
///
/// Sits outside Widgetbook's `KeyedSubtree`, so a knob change keeps them
/// while the page below is rebuilt.
class _StoryScope extends StatefulWidget {
  const _StoryScope({required this.child});

  final Widget child;

  /// The page controller of the nearest scope above [context].
  static PageLayoutController controllerOf(BuildContext context) =>
      _of(context).controller;

  /// The nearest scope above [context].
  static _StoryScopeState _of(BuildContext context) {
    final state = context.findAncestorStateOfType<_StoryScopeState>();
    if (state == null) {
      throw StateError('The story controllers need the Playground setup');
    }
    return state;
  }

  @override
  State<_StoryScope> createState() => _StoryScopeState();
}

class _StoryScopeState extends State<_StoryScope> {
  PageLayoutController? _controller;
  late final StratumWidgetSettingsController _settings;
  bool _settingsLoaded = false;

  /// The page controller, created on first use.
  PageLayoutController get controller => _controller ??= PageLayoutController();

  @override
  void initState() {
    super.initState();
    _settings = StratumWidgetSettingsController(
      store: StratumMemorySettingStore(),
    );
    unawaited(_loadSettings());
  }

  /// Reads the in-memory store once; a page that binds a setting asserts
  /// the controller is loaded, so the story builds only after this ends.
  Future<void> _loadSettings() async {
    await _settings.load();
    if (mounted) setState(() => _settingsLoaded = true);
  }

  @override
  void dispose() {
    _controller?.dispose();
    _settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _settingsLoaded
      ? StratumWidgetSettings(controller: _settings, child: widget.child)
      : const SizedBox.shrink();
}
