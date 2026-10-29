import 'package:stratum_ui/stratum_ui.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

import '../kit/callback_report.dart';
import '../kit/docs/catalog_docs.dart';
import '../kit/docs/stratum_docs.dart';
import '../kit/preset.dart';
import '../kit/slot_preset.dart';
import '../kit/story_set.dart';
import '../kit/style_presets.dart';
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
  safeArea: requiredPresetKnob('safeArea', _safeAreas),
  loadingBuilder: presetKnob('loadingBuilder', _loadingBuilders),
  controller: presetKnob('controller', _controllers),
  leftSide: requiredPresetKnob('leftSide', _sides),
  rightSide: requiredPresetKnob('rightSide', _sides),
  leftDividerBuilder: presetKnob('leftDividerBuilder', _leftDividers),
  rightDividerBuilder: presetKnob('rightDividerBuilder', _rightDividers),
  customStyle: presetKnob('customStyle', _customStyles),
  systemStyle: presetKnob('systemStyle', _systemStyles),
  setting: presetKnob('setting', widgetSettingPresets),
);

final _safeAreas = <RequiredPreset<PageSafeArea>>[
  const RequiredPreset('Default', _defaultSafeArea),
  const RequiredPreset('None', _noSafeArea),
];

PageSafeArea _defaultSafeArea(BuildContext context) => const PageSafeArea();
PageSafeArea _noSafeArea(BuildContext context) =>
    const PageSafeArea(top: false, bottom: false, left: false, right: false);

final _loadingBuilders = <Preset<WidgetBuilder>>[
  const Preset.none(),
  Preset(
    'Slot',
    (_) =>
        (context) => const StratumSlot(name: 'loading'),
  ),
];

final _controllers = <Preset<PageLayoutController>>[
  const Preset.none(),
  Preset(
    'Story controller',
    (context) => LayoutStoryScope.held(context, PageLayoutController.new),
  ),
];

final _sides = <RequiredPreset<PageSide>>[
  const RequiredPreset('Default', _defaultSide),
  const RequiredPreset('Wide', _wideSide),
];

PageSide _defaultSide(BuildContext context) => const PageSide();
PageSide _wideSide(BuildContext context) =>
    const PageSide(minWidth: 320, maxWidth: 400);

final _leftDividers = <Preset<SplitDividerBuilder>>[
  const Preset.none(),
  Preset(
    'Slot',
    (_) =>
        (context, state) => const StratumSlot(name: 'left divider'),
  ),
];

final _rightDividers = <Preset<SplitDividerBuilder>>[
  const Preset.none(),
  Preset(
    'Slot',
    (_) =>
        (context, state) => const StratumSlot(name: 'right divider'),
  ),
];

final _customStyles = <Preset<PageLayoutStyle>>[
  const Preset.none(),
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

final _systemStyles = <Preset<SystemStyle>>[
  const Preset.none(),
  const Preset('Light icons', _lightIcons),
  const Preset('Dark icons', _darkIcons),
];

SystemStyle? _lightIcons(BuildContext context) =>
    const SystemStyle(statusBarIcons: SystemBarIcons.light);
SystemStyle? _darkIcons(BuildContext context) =>
    const SystemStyle(statusBarIcons: SystemBarIcons.dark);

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
  setting: widgetSettingPresets.first,
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
  setup: (context, child, args) => LayoutStoryScope(
    withSettings: true,
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
