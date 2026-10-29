import 'package:stratum_ui/stratum_ui.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

import '../kit/sample_text.dart';

import '../kit/docs/catalog_docs.dart';
import '../kit/docs/stratum_docs.dart';
import '../kit/preset.dart';
import '../kit/story_set.dart';
import '../kit/style_presets.dart';
import '../shell/catalog_section.dart';
import 'split_layout_knobs.dart';
import 'layout_page.dart';
import 'layout_slots.dart';
import 'recipes.dart';

part 'split_layout.stories.g.dart';

const _docs = CatalogDocs(
  figma: null,
  usage: '''
SplitLayout(
  panes: [
    SplitPane(child: ListPane(), size: 240),
    SplitPane(child: DetailPane()),
  ],
)''',
  dos: [
    'Use it to split a page body, such as a list beside its detail.',
    'Give the split a bounded extent along its axis.',
    'Keep the fractions in a SplitLayoutController when the app restores '
        'them.',
    recipeWindowDo,
  ],
  donts: [
    'Pass a pane both a size and a flex; the pane asserts it.',
    'Expect the divider to paint; it paints nothing unless dividerBuilder '
        'paints it, though its hit area always spans the platform target '
        'size.',
  ],
  accessibility: [
    'The divider is a Tab stop; the arrow keys step it, Shift makes the step '
        'larger, and Home and End go to the limits.',
    'A screen reader reads the divider as a slider valued by the start '
        'pane\'s share, with increase and decrease actions.',
  ],
);

const meta = Meta(SplitLayout.new, argsType: SplitLayoutKnobs.new);

final componentMeta = ComponentMeta(
  name: 'SplitLayout',
  path: CatalogSection.layout.label,
  docsBuilder: stratumDocs(
    _docs,
    args: [for (final arg in $Playground.args.list) ?arg],
  ),
);

/// The height the split stories give the split, since a vertical split
/// needs a bounded height.
const _height = 320.0;

/// A fresh set of knobs: one per constructor param, in constructor order.
SplitLayoutKnobsArgs _knobs() => SplitLayoutKnobsArgs(
  panes: slotCountKnob('panes', initial: 2, min: 2, max: 4),
  controller: presetKnob('controller', _controllers),
  dividerLabel: presetKnob('dividerLabel', _dividerLabels),
  dividerBuilder: presetKnob('dividerBuilder', _dividerBuilders),
  customStyle: presetKnob('customStyle', _customStyles),
  setting: presetKnob('setting', _settings),
);

final _controllers = <Preset<SplitLayoutController>>[
  const Preset.none(),
  Preset('Start pane 30%', (_) => SplitLayoutController()),
];

/// The share the `Start pane 30%` preset gives the first pane.
const _startShare = 0.3;

/// [controller] holding [_startShare] for the first of [panes] panes and an
/// even share of the rest for each other, so the preset keeps its meaning at
/// every pane count; a split discards a list whose length differs from its
/// panes'.
SplitLayoutController? _fitToPanes(
  SplitLayoutController? controller,
  int panes,
) {
  if (controller == null) return null;
  final rest = (1 - _startShare) / (panes - 1);
  return controller
    ..fractions = [_startShare, for (var i = 1; i < panes; i++) rest];
}

final _dividerLabels = <Preset<String>>[
  const Preset.none(),
  Preset('Label', (context) => SampleTexts.label.of(context)),
  Preset('Title', (context) => SampleTexts.title.of(context)),
];

final _dividerBuilders = <Preset<SplitDividerBuilder>>[
  const Preset.none(),
  Preset(
    'Outlined hit area',
    (_) =>
        (context, state) =>
            ContainerLayout(style: stylePreset('Outlined').build(context)),
  ),
];

final _customStyles = <Preset<SplitLayoutStyle>>[
  const Preset.none(),
  Preset(
    'Heavy focus ring',
    (context) => SplitLayoutStyle(
      focus: StratumFocusBorderStyle(
        width: WidgetStatePropertyAll(context.theme.focus.outsideWidth),
        color: WidgetStatePropertyAll(context.theme.color.border.color.gray),
      ),
    ),
  ),
];

/// The `None` choice only: a setting key needs a `StratumWidgetSettings`
/// above the split, which this Playground does not place (the PageLayout
/// Playground does).
final _settings = <Preset<WidgetSettingKey>>[const Preset.none()];

/// Knobs for a story that has no Playground: fixed, so the panel hides them.
SplitLayoutKnobsArgs _fixedKnobs() => SplitLayoutKnobsArgs.fixed(
  controller: _controllers.first,
  dividerLabel: _dividerLabels.first,
  dividerBuilder: _dividerBuilders.first,
  customStyle: _customStyles.first,
  setting: _settings.first,
);

/// [count] panes, each holding one named slot.
List<SplitPane> _panes(int count) => [
  for (final child in slotChildren(count)) SplitPane(child: child),
];

/// The page widget Widgetbook's builder must return; the frame stories show
/// their own layout through `setup`, which drops this child.
SplitLayout _frameChild(BuildContext context, SplitLayoutKnobsArgs args) =>
    SplitLayout(panes: _panes(2));

/// A two pane split on a bounded height, the layout every frame story shows.
Widget _sample(BuildContext context) =>
    SizedBox(height: _height, child: _frameChild(context, _fixedKnobs()));

final $Playground = _Story(
  args: _knobs(),
  setup: (context, child, args) => SizedBox(
    height: _height,
    child: Story.defaultSetup(context, child, args),
  ),
  builder: (context, args) => SplitLayout(
    panes: _panes(args.panes),
    axis: args.axis,
    resizable: args.resizable,
    controller: _fitToPanes(args.controller.build(context), args.panes),
    dividerLabel: args.dividerLabel.build(context),
    dividerBuilder: args.dividerBuilder.build(context),
    customStyle: args.customStyle.build(context),
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
  setup: (_, _, _) => accessibilityFrames(build: _sample),
);

final $ExampleListBesideDetail = _Story(
  name: StoryNames.example('list beside detail'),
  args: _fixedKnobs(),
  builder: _frameChild,
  setup: (_, _, _) => const SizedBox(
    height: _height,
    child: SplitLayout(
      panes: [
        SplitPane(size: 160, min: 120, child: StratumSlot(name: 'list')),
        SplitPane(child: StratumSlot(name: 'detail')),
      ],
    ),
  ),
);
