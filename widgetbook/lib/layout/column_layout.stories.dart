import 'package:stratum_ui/stratum_ui.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

import '../kit/callback_report.dart';
import '../kit/docs/catalog_docs.dart';
import '../kit/docs/stratum_docs.dart';
import '../kit/preset.dart';
import '../kit/story_set.dart';
import '../shell/catalog_section.dart';
import 'flex_axis_knobs.dart';
import 'layout_page.dart';
import 'layout_slots.dart';
import 'recipes.dart';

part 'column_layout.stories.g.dart';

const _docs = CatalogDocs(
  figma: null,
  usage: '''
ColumnLayout(
  gap: 8,
  children: [
    Text('Title'),
    Text('Body'),
  ],
)''',
  dos: [
    'Use it for every vertical stack; it takes the same style, interaction, '
        'and scroll as the other box layouts.',
    'Set gap for the space between children instead of a spacer widget.',
    recipeWindowDo,
  ],
  donts: [
    'Build a column from a raw Column; the layout carries the style, '
        'semantics, and focus group.',
    'Set a height in style and expect mainAxisSize.min; a height forces '
        'MainAxisSize.max.',
  ],
  accessibility: [
    'Its children keep their own semantics; the semantics knob adds a '
        'label to the whole column.',
    'A focus group makes the arrow keys move between its children.',
  ],
);

const meta = Meta(ColumnLayout.new, argsType: FlexAxisKnobs.new);

final componentMeta = ComponentMeta(
  name: 'ColumnLayout',
  path: CatalogSection.layout.label,
  docsBuilder: stratumDocs(
    _docs,
    args: [for (final arg in $Playground.args.list) ?arg],
  ),
);

/// A fresh set of knobs: one per constructor param, in constructor order.
FlexAxisKnobsArgs _knobs() => FlexAxisKnobsArgs(
  style: styleKnob(),
  transform: transformKnob(),
  transformAlignment: transformAlignmentKnob(),
  semantics: semanticsKnob(),
  interaction: interactionKnob(),
  scroll: scrollKnob(),
  focusGroup: focusGroupKnob(),
  children: slotCountKnob('children', initial: 3),
);

/// Knobs for a story that has no Playground: fixed, so the panel hides them.
FlexAxisKnobsArgs _fixedKnobs() => FlexAxisKnobsArgs.fixed(
  style: widgetStylePresets.first,
  transform: transformPresets.first,
  transformAlignment: alignmentPresets().first,
  semantics: semanticsPresets.first,
  interaction: interactionPresets.first,
  scroll: scrollPresets.first,
  focusGroup: focusGroupPresets.first,
);

/// Three named slots in a column, the layout every frame story shows.
ColumnLayout _sample(BuildContext context) =>
    ColumnLayout(gap: context.theme.space.sm, children: slotChildren(3));

/// The page widget Widgetbook's builder must return; the frame stories show
/// their own layout through `setup`, which drops this child.
ColumnLayout _frameChild(BuildContext context, FlexAxisKnobsArgs args) =>
    _sample(context);

final $Playground = _Story(
  args: _knobs(),
  setup: reportingSetup,
  builder: (context, args) => ColumnLayout(
    style: args.style.build(context),
    ratio: args.ratio,
    rotate: args.rotate,
    transform: args.transform.build(context),
    transformAlignment: args.transformAlignment.build(context),
    keepAlive: args.keepAlive,
    repaintBoundary: args.repaintBoundary,
    semantics: args.semantics.build(context),
    onEndAnimate: endAnimateCallback(context, enabled: args.onEndAnimate),
    interaction: args.interaction.build(context),
    scroll: args.scroll.build(context),
    mainAxisAlignment: args.mainAxisAlignment,
    mainAxisSize: args.mainAxisSize,
    crossAxisAlignment: args.crossAxisAlignment,
    textDirection: args.textDirection,
    verticalDirection: args.verticalDirection,
    textBaseline: baselineFor(args.crossAxisAlignment, args.textBaseline),
    crossAxisIntrinsic: args.crossAxisIntrinsic,
    gap: args.gap,
    focusGroup: args.focusGroup.build(context),
    children: slotChildren(args.children),
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

final $ExampleStyledColumn = _Story(
  name: StoryNames.example('styled column'),
  args: _fixedKnobs(),
  builder: (context, args) => ColumnLayout(
    style: stylePreset('Card').build(context),
    gap: context.theme.space.sm,
    children: const [
      StratumSlot(name: 'title'),
      StratumSlot(name: 'body'),
    ],
  ),
);
