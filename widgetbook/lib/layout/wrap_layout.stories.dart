import 'package:stratum_ui/stratum_ui.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

import '../kit/callback_report.dart';
import '../kit/docs/catalog_docs.dart';
import '../kit/docs/stratum_docs.dart';
import '../kit/preset.dart';
import '../kit/story_set.dart';
import '../kit/style_presets.dart';
import '../shell/catalog_section.dart';
import 'wrap_layout_knobs.dart';
import 'layout_page.dart';
import 'layout_slots.dart';
import 'recipes.dart';

part 'wrap_layout.stories.g.dart';

const _docs = CatalogDocs(
  figma: null,
  usage: '''
WrapLayout(
  gap: 8,
  maxRuns: 2,
  overflowBuilder: (context, hidden) => Text('+\$hidden'),
  children: [for (final tag in tags) Chip(label: Text(tag))],
)''',

  dos: [
    'Use it for tags and chips that flow onto new runs.',
    'Set maxRuns or maxChildren with an overflowBuilder to cut the wrap and '
        'count the hidden items.',
    recipeWindowDo,
  ],
  donts: [
    'Combine a limit or overflowBuilder with scroll; the constructor '
        'asserts it, so the Playground drops the limits while a scroll is '
        'picked.',
    'Build a wrap from a raw Wrap; the layout carries the style, '
        'semantics, and focus group.',
  ],
  accessibility: [
    'A hidden item never takes focus or reaches a screen reader.',
    'The overflowBuilder item states the exact number of hidden items.',
  ],
);

const meta = Meta(WrapLayout.new, argsType: WrapLayoutKnobs.new);

final componentMeta = ComponentMeta(
  name: 'WrapLayout',
  path: CatalogSection.layout.label,
  docsBuilder: stratumDocs(
    _docs,
    args: [for (final arg in $Playground.args.list) ?arg],
  ),
);

/// A fresh set of knobs: one per constructor param, in constructor order.
WrapLayoutKnobsArgs _knobs() => WrapLayoutKnobsArgs(
  style: styleKnob(),
  transform: transformKnob(),
  transformAlignment: transformAlignmentKnob(),
  semantics: semanticsKnob(),
  interaction: interactionKnob(),
  scroll: scrollKnob(),
  focusGroup: focusGroupKnob(),
  overflowBuilder: presetKnob('overflowBuilder', _overflowBuilders),
  children: slotCountKnob('children', initial: 3),
);

final _overflowBuilders =
    <Preset<Widget Function(BuildContext context, int hiddenCount)>>[
      const Preset.none(),
      Preset(
        'Count slot',
        (_) =>
            (context, hiddenCount) => StratumSlot(name: '+$hiddenCount'),
      ),
    ];

/// Knobs for a story that has no Playground: fixed, so the panel hides them.
WrapLayoutKnobsArgs _fixedKnobs() => WrapLayoutKnobsArgs.fixed(
  style: widgetStylePresets.first,
  transform: transformPresets.first,
  transformAlignment: alignmentPresets().first,
  semantics: semanticsPresets.first,
  interaction: interactionPresets.first,
  scroll: scrollPresets.first,
  focusGroup: focusGroupPresets.first,
  overflowBuilder: _overflowBuilders.first,
);

/// Three named slots in a wrap, the layout every frame story shows.
WrapLayout _sample(BuildContext context) =>
    WrapLayout(gap: context.theme.space.sm, children: slotChildren(3));

/// The page widget Widgetbook's builder must return; the frame stories show
/// their own layout through `setup`, which drops this child.
WrapLayout _frameChild(BuildContext context, WrapLayoutKnobsArgs args) =>
    _sample(context);

/// [value] raised to [minimum], since the constructor asserts a limit below
/// it; null stays null.
int? _atLeast(int? value, int minimum) =>
    value == null || value >= minimum ? value : minimum;

final $Playground = _Story(
  args: _knobs(),
  setup: reportingSetup,
  builder: (context, args) {
    final scroll = args.scroll.build(context);
    final cuts = scroll == null;
    return WrapLayout(
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
      scroll: scroll,
      direction: args.direction,
      alignment: args.alignment,
      gap: args.gap,
      runGap: args.runGap,
      runAlignment: args.runAlignment,
      crossAxisAlignment: args.crossAxisAlignment,
      textDirection: args.textDirection,
      verticalDirection: args.verticalDirection,
      clipBehavior: args.clipBehavior,
      focusGroup: args.focusGroup.build(context),
      maxRuns: cuts ? _atLeast(args.maxRuns, 1) : null,
      maxChildren: cuts ? _atLeast(args.maxChildren, 0) : null,
      overflowBuilder: cuts ? args.overflowBuilder.build(context) : null,
      children: slotChildren(args.children),
    );
  },
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

final $ExampleTagsCutToTwoRuns = _Story(
  name: StoryNames.example('tags cut to two runs'),
  args: _fixedKnobs(),
  builder: _frameChild,
  setup: (context, _, _) => SizedBox(
    width: 320,
    child: WrapLayout(
      gap: context.theme.space.sm,
      maxRuns: 2,
      overflowBuilder: (context, hiddenCount) =>
          StratumSlot(name: '+$hiddenCount'),
      children: [for (var i = 1; i <= 12; i++) StratumSlot(name: 'tag $i')],
    ),
  ),
);
