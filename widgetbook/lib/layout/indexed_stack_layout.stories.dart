import 'package:stratum_ui/stratum_ui.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

import '../kit/callback_report.dart';
import '../kit/docs/catalog_docs.dart';
import '../kit/docs/stratum_docs.dart';
import '../kit/preset.dart';
import '../kit/story_set.dart';
import '../shell/catalog_section.dart';
import 'indexed_stack_layout_knobs.dart';
import 'layout_page.dart';
import 'layout_slots.dart';
import 'recipes.dart';

part 'indexed_stack_layout.stories.g.dart';

const _docs = CatalogDocs(
  figma: null,
  usage: '''
IndexedStackLayout(
  index: 1,
  children: [
    HomeView(),
    SearchView(),
  ],
)''',
  dos: [
    'Use it to switch between views that must keep their state while hidden.',
    'Wrap the content in an AnimatedSwitcher when the switch needs a '
        'cross-fade; the layout switches at once.',
    recipeWindowDo,
  ],
  donts: [
    'Pass an index at or past the child count; the Playground keeps the '
        'index inside the count.',
    'Expect a hidden view to take focus or appear to a screen reader; only '
        'the shown child does.',
  ],
  accessibility: [
    'When the index changes while focus sits in the old view, focus moves to '
        'the first item of the new view.',
    'Focus outside the stack, such as on the tab bar, stays where it is.',
  ],
);

const meta = Meta(
  IndexedStackLayout.new,
  argsType: IndexedStackLayoutKnobs.new,
);

final componentMeta = ComponentMeta(
  name: 'IndexedStackLayout',
  path: CatalogSection.layout.label,
  docsBuilder: stratumDocs(
    _docs,
    args: [for (final arg in $Playground.args.list) ?arg],
  ),
);

/// A fresh set of knobs: one per constructor param, in constructor order.
IndexedStackLayoutKnobsArgs _knobs() => IndexedStackLayoutKnobsArgs(
  style: styleKnob(),
  transform: transformKnob(),
  transformAlignment: transformAlignmentKnob(),
  semantics: semanticsKnob(),
  interaction: interactionKnob(),
  scroll: scrollKnob(),
  index: NullableIntArg(
    0,
    name: 'index',
    style: const SliderIntArgStyle(min: 0, max: 7, divisions: 7),
  ),
  alignment: stackAlignmentKnob(),
  children: slotCountKnob('children', initial: 3),
);

/// Knobs for a story that has no Playground: fixed, so the panel hides them.
IndexedStackLayoutKnobsArgs _fixedKnobs() => IndexedStackLayoutKnobsArgs.fixed(
  style: widgetStylePresets.first,
  transform: transformPresets.first,
  transformAlignment: alignmentPresets().first,
  semantics: semanticsPresets.first,
  interaction: interactionPresets.first,
  scroll: scrollPresets.first,
  alignment: alignmentPresets(initial: AlignmentDirectional.topStart).first,
);

/// Three named slots in a stack, the layout every frame story shows.
IndexedStackLayout _sample(BuildContext context) =>
    IndexedStackLayout(children: slotChildren(3));

/// The page widget Widgetbook's builder must return; the frame stories show
/// their own layout through `setup`, which drops this child.
IndexedStackLayout _frameChild(
  BuildContext context,
  IndexedStackLayoutKnobsArgs args,
) => _sample(context);

/// [index] kept inside the [count] children, since the stack asserts an index
/// past its last child; null shows none.
int? _shownIndex(int? index, int count) {
  if (index == null) return null;
  return index >= count ? count - 1 : index;
}

final $Playground = _Story(
  args: _knobs(),
  setup: reportingSetup,
  builder: (context, args) => IndexedStackLayout(
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
    index: _shownIndex(args.index, args.children),
    alignment: args.alignment.build(context) ?? AlignmentDirectional.topStart,
    sizing: args.sizing,
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

final $ExampleSwitchStackedViews = _Story(
  name: StoryNames.example('switch stacked views'),
  args: _fixedKnobs(),
  builder: (context, args) => const IndexedStackLayout(
    index: 1,
    children: [
      StratumSlot(name: 'home view'),
      StratumSlot(name: 'search view'),
      StratumSlot(name: 'profile view'),
    ],
  ),
);
