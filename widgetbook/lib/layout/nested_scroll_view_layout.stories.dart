import 'package:stratum_ui/stratum_ui.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

import '../kit/docs/catalog_docs.dart';
import '../kit/docs/stratum_docs.dart';
import '../kit/preset.dart';
import '../kit/sample_text.dart';
import '../kit/slot_preset.dart';
import '../kit/story_set.dart';
import '../shell/catalog_section.dart';
import 'layout_page.dart';
import 'layout_slots.dart';
import 'nested_scroll_view_layout_knobs.dart';
import 'recipes.dart';

part 'nested_scroll_view_layout.stories.g.dart';

const _docs = CatalogDocs(
  figma: null,
  usage: '''
NestedScrollViewLayout(
  headerSliverBuilder: (context, innerBoxIsScrolled) => [
    SliverAppBar(title: Text('Profile'), pinned: true),
  ],
  body: ListViewLayout.builder(
    itemCount: posts.length,
    itemBuilder: (context, index) => PostTile(posts[index]),
  ),
)''',
  dos: [
    'Use it for a header that collapses while the body scrolls: a profile '
        'over a feed, a toolbar over a list.',
    'Build the body on a vertical layout scroll view, such as '
        'ListViewLayout, whose controller is null and whose primary is null '
        'or true, so it attaches to the inner controller.',
    recipeWindowDo,
  ],
  donts: [
    'Hand the body scroll view its own controller; it then scrolls on its '
        'own and the header stays put.',
    'Show a desktop scrollbar inside a TabBarView body; build those views '
        'with showScrollbar false, since a swipe attaches two of them to the '
        'controller it watches.',
  ],
  accessibility: [
    'The layout is not a Tab stop; the scroll views in the body are, and '
        'their keys scroll the header and the body as one range.',
    'An arrow or a page first collapses or expands the header and then '
        'scrolls the body; Home expands the header and returns the body to '
        'its start.',
  ],
);

const meta = Meta(
  NestedScrollViewLayout.new,
  argsType: NestedScrollViewLayoutKnobs.new,
);

final componentMeta = ComponentMeta(
  name: 'NestedScrollViewLayout',
  path: CatalogSection.layout.label,
  docsBuilder: stratumDocs(
    _docs,
    args: [for (final arg in $Playground.args.list) ?arg],
  ),
);

/// The header sliver builders this page offers: the default one that builds
/// a `SliverToBoxAdapter` of a named slot (fo11/us06/fr01).
final _headerBuilders = <Preset<NestedScrollViewHeaderSliversBuilder>>[
  Preset(
    'Slot builder',
    (_) =>
        (context, innerBoxIsScrolled) => [
          const SliverToBoxAdapter(child: StratumSlot(name: 'header')),
        ],
  ),
  Preset(
    'Second slot',
    (_) =>
        (context, innerBoxIsScrolled) => [
          const SliverToBoxAdapter(child: StratumSlot(name: 'second header')),
        ],
  ),
];

final _controllers = <Preset<ScrollController>>[
  const Preset('None', _noController),
];

ScrollController? _noController(BuildContext context) => null;

/// A fresh set of knobs: one per constructor param, in constructor order.
NestedScrollViewLayoutKnobsArgs _knobs() => NestedScrollViewLayoutKnobsArgs(
  style: styleKnob(),
  controller: presetKnob('controller', _controllers),
  physics: presetKnob('physics', scrollPhysicsPresets),
  headerSliverBuilder: presetKnob('headerSliverBuilder', _headerBuilders),
  body: EnumArg<SlotPreset>(
    SlotPreset.slot,
    name: 'body',
    values: SlotPreset.values,
  ),
);

/// Knobs for a story that has no Playground: fixed, so the panel hides them.
NestedScrollViewLayoutKnobsArgs _fixedKnobs() =>
    NestedScrollViewLayoutKnobsArgs.fixed(
      style: widgetStylePresets.first,
      controller: _controllers.first,
      physics: scrollPhysicsPresets.first,
      headerSliverBuilder: _headerBuilders.first,
    );

/// A collapsing header slot over a list of item slots in a bounded height,
/// the layout every frame story shows.
Widget _sample(BuildContext context) =>
    SizedBox(height: 280, child: _frameChild(context, _fixedKnobs()));

/// The page widget Widgetbook's builder must return; the frame stories show
/// their own layout through `setup`, which drops this child.
NestedScrollViewLayout _frameChild(
  BuildContext context,
  NestedScrollViewLayoutKnobsArgs args,
) => NestedScrollViewLayout(
  headerSliverBuilder: _headerBuilders.first.build(context)!,
  body: _body(context),
);

/// The body the frame stories scroll: a list of three item slots.
Widget _body(BuildContext context) => ListViewLayout.builder(
  itemCount: 3,
  itemBuilder: (context, index) =>
      slotItemBuilders.first.build(context)!(context, index),
);

final $Playground = _Story(
  args: _knobs(),
  setup: (context, child, args) =>
      SizedBox(height: 280, child: Story.defaultSetup(context, child, args)),
  builder: (context, args) => NestedScrollViewLayout(
    style: args.style.build(context),
    controller: args.controller.build(context),
    scrollDirection: args.scrollDirection,
    reverse: args.reverse,
    physics: args.physics.build(context),
    showScrollbar: args.showScrollbar,
    headerSliverBuilder: args.headerSliverBuilder.build(context)!,
    body: slotFor(context, args.body, name: 'body') ?? const SizedBox.shrink(),
    dragStartBehavior: args.dragStartBehavior,
    floatHeaderSlivers: args.floatHeaderSlivers,
    clipBehavior: args.clipBehavior,
    hitTestBehavior: args.hitTestBehavior,
    restorationId: args.restorationId,
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

final $ExampleCollapsingHeader = _Story(
  name: StoryNames.example('collapsing header'),
  args: _fixedKnobs(),
  builder: _frameChild,
  setup: (context, _, _) => SizedBox(
    height: 280,
    child: NestedScrollViewLayout(
      style: stylePreset('Card').build(context),
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverToBoxAdapter(
          child: StratumSlot(
            name: SampleTexts.title.resolve(Localizations.localeOf(context)),
            height: 96,
          ),
        ),
      ],
      body: ListViewLayout.builder(
        itemCount: 12,
        itemBuilder: (context, index) =>
            StratumSlot(name: 'row ${index + 1}', height: 36),
      ),
    ),
  ),
);
