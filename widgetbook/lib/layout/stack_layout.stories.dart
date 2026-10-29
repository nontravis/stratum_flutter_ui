import 'package:stratum_ui/stratum_ui.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

import '../kit/callback_report.dart';
import '../kit/docs/catalog_docs.dart';
import '../kit/docs/stratum_docs.dart';
import '../kit/preset.dart';
import '../kit/story_set.dart';
import '../kit/style_presets.dart';
import '../shell/catalog_section.dart';
import 'stack_layout_knobs.dart';
import 'layout_page.dart';
import 'layout_slots.dart';
import 'recipes.dart';

part 'stack_layout.stories.g.dart';

const _docs = CatalogDocs(
  figma: null,
  usage: '''
StackLayout(
  alignment: AlignmentDirectional.bottomEnd,
  children: [
    Image.asset('assets/photo.png'),
    Text('Caption'),
  ],
)''',
  dos: [
    'Use it to overlap children: a badge on an avatar, text on an image.',
    'Set alignment to place the children that have no Positioned.',
    recipeWindowDo,
  ],
  donts: [
    'Build a stack from a raw Stack; the layout carries the style, '
        'semantics, and scroll.',
    'Expect style.alignment to move the children; it places the whole '
        'stack inside the box.',
  ],
  accessibility: [
    'Children keep their own semantics, in paint order.',
    'The semantics knob adds a label to the whole stack.',
  ],
);

const meta = Meta(StackLayout.new, argsType: StackLayoutKnobs.new);

final componentMeta = ComponentMeta(
  name: 'StackLayout',
  path: CatalogSection.layout.label,
  docsBuilder: stratumDocs(
    _docs,
    args: [for (final arg in $Playground.args.list) ?arg],
  ),
);

/// A fresh set of knobs: one per constructor param, in constructor order.
StackLayoutKnobsArgs _knobs() => StackLayoutKnobsArgs(
  style: styleKnob(),
  transform: transformKnob(),
  transformAlignment: transformAlignmentKnob(),
  semantics: semanticsKnob(),
  interaction: interactionKnob(),
  scroll: scrollKnob(),
  alignment: stackAlignmentKnob(),
  children: slotCountKnob('children', initial: 3),
);

/// Knobs for a story that has no Playground: fixed, so the panel hides them.
StackLayoutKnobsArgs _fixedKnobs() => StackLayoutKnobsArgs.fixed(
  style: widgetStylePresets.first,
  transform: transformPresets.first,
  transformAlignment: alignmentPresets().first,
  semantics: semanticsPresets.first,
  interaction: interactionPresets.first,
  scroll: scrollPresets.first,
  alignment: alignmentPresets(initial: AlignmentDirectional.topStart).first,
);

/// Three named slots in a stack, the layout every frame story shows.
StackLayout _sample(BuildContext context) =>
    StackLayout(children: slotChildren(3));

/// The page widget Widgetbook's builder must return; the frame stories show
/// their own layout through `setup`, which drops this child.
StackLayout _frameChild(BuildContext context, StackLayoutKnobsArgs args) =>
    _sample(context);

final $Playground = _Story(
  args: _knobs(),
  setup: reportingSetup,
  builder: (context, args) => StackLayout(
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
    alignment: args.alignment.build(context) ?? AlignmentDirectional.topStart,
    fit: args.fit,
    textDirection: args.textDirection,
    clipBehavior: args.clipBehavior,
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

final $ExampleBadgeOverAvatar = _Story(
  name: StoryNames.example('badge over avatar'),
  args: _fixedKnobs(),
  builder: (context, args) => const StackLayout(
    children: [
      StratumSlot(name: 'avatar', width: 64, height: 64),
      PositionedDirectional(top: 0, end: 0, child: StratumSlot(name: 'badge')),
    ],
  ),
);
