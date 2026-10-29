import 'package:stratum_ui/stratum_ui.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

import '../kit/docs/catalog_docs.dart';
import '../kit/docs/stratum_docs.dart';
import '../kit/preset.dart';
import '../kit/sample_text.dart';
import '../kit/story_set.dart';
import '../shell/catalog_section.dart';
import 'custom_scroll_view_layout_knobs.dart';
import 'layout_page.dart';
import 'layout_slots.dart';
import 'recipes.dart';

part 'custom_scroll_view_layout.stories.g.dart';

const _docs = CatalogDocs(
  figma: null,
  usage: '''
CustomScrollViewLayout(
  slivers: [
    SliverPersistentHeader(delegate: HeaderDelegate()),
    SliverList.builder(itemBuilder: (context, i) => ItemTile(items[i])),
  ],
)''',
  dos: [
    'Use it when one scroll needs more than a list: a pinned header over a '
        'list, several lists under one scrollbar.',
    'Wrap the slivers in a SliverPadding yourself when you pass slivers; '
        'grouping slivers changes how pinned headers behave.',
    recipeWindowDo,
  ],
  donts: [
    'Pass both slivers and children; the constructor asserts it, so the '
        'Playground passes the slivers while their preset is set and the '
        'children count otherwise.',
    'Give slivers a style with padding; the layout asserts it, so the '
        'Playground drops the style while a padded one is picked beside '
        'slivers.',
    'Build one long Column of everything; it lays out the whole content at '
        'once, where slivers build only what is near the viewport.',
  ],
  accessibility: [
    'A focusable view, by default on web and desktop, is a Tab stop whose '
        'arrows, Page Up, Page Down, Home, and End scroll it.',
    'The semanticsLabel knob names the view for a screen reader.',
  ],
);

const meta = Meta(
  CustomScrollViewLayout.new,
  argsType: CustomScrollViewLayoutKnobs.new,
);

final componentMeta = ComponentMeta(
  name: 'CustomScrollViewLayout',
  path: CatalogSection.layout.label,
  docsBuilder: stratumDocs(
    _docs,
    args: [for (final arg in $Playground.args.list) ?arg],
  ),
);

/// The slivers a slivers preset builds: `SliverToBoxAdapter`s of named
/// slots (fo11/us06/fr01); `None` keeps the children mode.
final _sliversBuilders = <Preset<List<Widget>?>>[
  const Preset('None', _noSlivers),
  const Preset('Header and slots', _slotSlivers),
];

List<Widget>? _noSlivers(BuildContext context) => null;

List<Widget>? _slotSlivers(BuildContext context) => const [
  SliverToBoxAdapter(child: StratumSlot(name: 'header')),
  SliverToBoxAdapter(child: StratumSlot(name: 'body')),
  SliverToBoxAdapter(child: StratumSlot(name: 'footer')),
];

final _controllers = <Preset<ScrollController>>[
  const Preset('None', _noController),
  Preset('Start at item 2', (_) => ScrollController(initialScrollOffset: 80)),
];

ScrollController? _noController(BuildContext context) => null;

/// A fresh set of knobs: one per constructor param, in constructor order.
CustomScrollViewLayoutKnobsArgs _knobs() => CustomScrollViewLayoutKnobsArgs(
  style: styleKnob(),
  slivers: presetKnob('slivers', _sliversBuilders),
  children: slotCountKnob('children', initial: 3),
  controller: presetKnob('controller', _controllers),
  physics: presetKnob('physics', scrollPhysicsPresets),
  semanticsLabel: presetKnob('semanticsLabel', scrollSemanticsLabelPresets),
  scrollFocusStyle: presetKnob('scrollFocusStyle', scrollFocusStylePresets),
);

/// Knobs for a story that has no Playground: fixed, so the panel hides them.
CustomScrollViewLayoutKnobsArgs _fixedKnobs() =>
    CustomScrollViewLayoutKnobsArgs.fixed(
      style: widgetStylePresets.first,
      slivers: _sliversBuilders.first,
      controller: _controllers.first,
      physics: scrollPhysicsPresets.first,
      semanticsLabel: scrollSemanticsLabelPresets.first,
      scrollFocusStyle: scrollFocusStylePresets.first,
    );

/// The height the scroll stories give the view, since a vertical scroll
/// needs a bounded height.
const _height = 320.0;

/// The height of each slot child, tall enough that six overflow the view.
const _childHeight = 48.0;

/// The page widget Widgetbook's builder must return; the frame stories show
/// their own layout through `setup`, which drops this child.
CustomScrollViewLayout _frameChild(
  BuildContext context,
  CustomScrollViewLayoutKnobsArgs args,
) => CustomScrollViewLayout(children: slotChildren(6, height: _childHeight));

/// A list of six slots in a bounded height, the layout every frame story
/// shows.
Widget _sample(BuildContext context) =>
    SizedBox(height: _height, child: _frameChild(context, _fixedKnobs()));

final $Playground = _Story(
  args: _knobs(),
  setup: (context, child, args) => SizedBox(
    height: _height,
    child: Story.defaultSetup(context, child, args),
  ),
  builder: (context, args) {
    final slivers = args.slivers.build(context);
    return CustomScrollViewLayout(
      style: ScrollKnobGuards.style(
        style: args.style.build(context),
        slivers: slivers,
      ),
      slivers: slivers,
      controller: args.controller.build(context),
      scrollDirection: args.scrollDirection,
      reverse: args.reverse,
      shrinkWrap: args.shrinkWrap,
      physics: args.physics.build(context),
      showScrollbar: args.showScrollbar,
      focusable: args.focusable,
      semanticsLabel: args.semanticsLabel.build(context),
      scrollFocusStyle: args.scrollFocusStyle.build(context),
      children: slivers == null
          ? slotChildren(args.children, height: _childHeight)
          : null,
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

final $ExamplePinnedHeaderList = _Story(
  name: StoryNames.example('pinned header list'),
  args: _fixedKnobs(),
  builder: _frameChild,
  setup: (context, _, _) => SizedBox(
    height: _height,
    child: CustomScrollViewLayout(
      slivers: [
        SliverToBoxAdapter(
          child: StratumSlot(
            name: SampleTexts.title.resolve(Localizations.localeOf(context)),
            height: 48,
          ),
        ),
        SliverList.builder(
          itemCount: 12,
          itemBuilder: (context, index) =>
              StratumSlot(name: 'row ${index + 1}', height: 36),
        ),
      ],
    ),
  ),
);
