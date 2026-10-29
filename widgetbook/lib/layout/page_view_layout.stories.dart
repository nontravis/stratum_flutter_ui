import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:stratum_ui/stratum_ui.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

import '../kit/callback_report.dart';
import '../kit/docs/catalog_docs.dart';
import '../kit/docs/stratum_docs.dart';
import '../kit/preset.dart';
import '../kit/sample_text.dart';
import '../kit/story_set.dart';
import '../shell/catalog_section.dart';
import 'layout_page.dart';
import 'layout_slots.dart';
import 'page_view_layout_knobs.dart';
import 'recipes.dart';

part 'page_view_layout.stories.g.dart';

const _docs = CatalogDocs(
  figma: null,
  usage: '''
PageViewLayout.builder(
  itemCount: steps.length,
  itemBuilder: (context, index) => StepPage(steps[index]),
  onPageChanged: (index) => updateDots(index),
)''',
  dos: [
    'Use it for full-screen pages the EndUser swipes through: an onboarding '
        'flow, a photo carousel.',
    'Build previous and next buttons beside it: a mouse without a trackpad '
        'cannot swipe a page view on desktop.',
    'Pass a PageController with a viewportFraction below 1 to show the '
        'neighbor pages.',
    recipeWindowDo,
  ],
  donts: [
    'Build a carousel from a raw PageView; the layout carries the style, '
        'the scroll behavior, and the keyboard paging.',
    'Expect End to reach the last page without an itemCount; it needs a '
        'page count.',
  ],
  accessibility: [
    'A focusable page view, by default on web and desktop, is a Tab stop; '
        'its arrows page it, Page Up and Page Down go one page, Home and '
        'End go to the ends.',
    'With allowImplicitScrolling a screen reader reaches the neighbor '
        'pages, and the view shows the page it entered whole.',
  ],
);

const meta = Meta(PageViewLayout.builder, argsType: PageViewLayoutKnobs.new);

final componentMeta = ComponentMeta(
  name: 'PageViewLayout',
  path: CatalogSection.layout.label,
  docsBuilder: stratumDocs(
    _docs,
    args: [for (final arg in $Playground.args.list) ?arg],
  ),
);

/// The page controllers this page offers: the default null, then one that
/// starts on the second page.
final _controllers = <Preset<PageController>>[
  const Preset('None', _noController),
  Preset('Start at page 2', (_) => PageController(initialPage: 1)),
];

PageController? _noController(BuildContext context) => null;

final _physicsPresets = <Preset<ScrollPhysics>>[
  const Preset('None', _noPhysics),
  const Preset('Bouncing', _bouncingPhysics),
  const Preset('Never scroll', _neverPhysics),
];

ScrollPhysics? _noPhysics(BuildContext context) => null;
ScrollPhysics? _bouncingPhysics(BuildContext context) =>
    const BouncingScrollPhysics();
ScrollPhysics? _neverPhysics(BuildContext context) =>
    const NeverScrollableScrollPhysics();

/// The page builders this page offers: the default slot builder that names
/// each page by its index (fo11/us06/fr01).
final _itemBuilders = <Preset<Widget? Function(BuildContext, int)>>[
  Preset(
    'Slot builder',
    (_) =>
        (context, index) => StratumSlot(name: 'item ${index + 1}'),
  ),
  Preset(
    'Text builder',
    (context) =>
        (context, index) => Text(
          '${SampleTexts.title.resolve(Localizations.localeOf(context))} '
          '${index + 1}',
        ),
  ),
];

final _findChildCallbacks = <Preset<ChildIndexGetter>>[
  const Preset('None', _noFindChild),
];

ChildIndexGetter? _noFindChild(BuildContext context) => null;

final _cacheExtents = <Preset<ScrollCacheExtent>>[
  const Preset('None', _noCacheExtent),
  const Preset('200 px', _cache200),
  const Preset('2 viewports', _cacheTwoViewports),
];

ScrollCacheExtent? _noCacheExtent(BuildContext context) => null;
ScrollCacheExtent? _cache200(BuildContext context) =>
    const ScrollCacheExtent.pixels(200);
ScrollCacheExtent? _cacheTwoViewports(BuildContext context) =>
    const ScrollCacheExtent.viewport(2);

final _semanticsLabels = <Preset<String>>[
  const Preset('None', _noSemanticsLabel),
  Preset(
    'Title',
    (context) => SampleTexts.title.resolve(Localizations.localeOf(context)),
  ),
];

String? _noSemanticsLabel(BuildContext context) => null;

final _focusStyles = <Preset<ScrollFocusStyle>>[
  const Preset('None', _noFocusStyle),
  Preset(
    'Gray 4 ring',
    (context) => ScrollFocusStyle(
      focus: StratumFocusBorderStyle(
        width: const WidgetStatePropertyAll(4),
        color: WidgetStatePropertyAll(context.theme.color.border.color.gray),
      ),
    ),
  ),
];

ScrollFocusStyle? _noFocusStyle(BuildContext context) => null;

/// A fresh set of knobs: one per constructor param, in constructor order.
PageViewLayoutKnobsArgs _knobs() => PageViewLayoutKnobsArgs(
  style: styleKnob(),
  controller: PresetArg(
    _controllers.first,
    name: 'controller',
    values: _controllers,
  ),
  physics: PresetArg(
    _physicsPresets.first,
    name: 'physics',
    values: _physicsPresets,
  ),
  itemBuilder: PresetArg(
    _itemBuilders.first,
    name: 'itemBuilder',
    values: _itemBuilders,
  ),
  findChildIndexCallback: PresetArg(
    _findChildCallbacks.first,
    name: 'findChildIndexCallback',
    values: _findChildCallbacks,
  ),
  itemCount: slotCountKnob('itemCount', initial: 3),
  scrollCacheExtent: PresetArg(
    _cacheExtents.first,
    name: 'scrollCacheExtent',
    values: _cacheExtents,
  ),
  semanticsLabel: PresetArg(
    _semanticsLabels.first,
    name: 'semanticsLabel',
    values: _semanticsLabels,
  ),
  scrollFocusStyle: PresetArg(
    _focusStyles.first,
    name: 'scrollFocusStyle',
    values: _focusStyles,
  ),
);

/// Knobs for a story that has no Playground: fixed, so the panel hides them.
PageViewLayoutKnobsArgs _fixedKnobs() => PageViewLayoutKnobsArgs.fixed(
  style: widgetStylePresets.first,
  controller: _controllers.first,
  physics: _physicsPresets.first,
  itemBuilder: _itemBuilders.first,
  findChildIndexCallback: _findChildCallbacks.first,
  scrollCacheExtent: _cacheExtents.first,
  semanticsLabel: _semanticsLabels.first,
  scrollFocusStyle: _focusStyles.first,
);

/// The page widget Widgetbook's builder must return; the frame stories show
/// their own layout through `setup`, which drops this child.
PageViewLayout _frameChild(
  BuildContext context,
  PageViewLayoutKnobsArgs args,
) => PageViewLayout.builder(
  itemCount: 3,
  itemBuilder: (context, index) =>
      _itemBuilders.first.build(context)!(context, index),
);

/// A page view of three slot pages in a bounded height, the layout every
/// frame story shows.
Widget _sample(BuildContext context) =>
    SizedBox(height: 240, child: _frameChild(context, _fixedKnobs()));

final $Playground = _BuilderStory(
  args: _knobs(),
  setup: (context, child, args) =>
      SizedBox(height: 240, child: reportingSetup(context, child, args)),
  builder: (context, args) => PageViewLayout.builder(
    style: args.style.build(context),
    scrollDirection: args.scrollDirection,
    reverse: args.reverse,
    controller: args.controller.build(context),
    physics: args.physics.build(context),
    pageSnapping: args.pageSnapping,
    onPageChanged: args.onPageChanged
        ? reportValue<int>(context, 'onPageChanged')
        : null,
    itemBuilder: args.itemBuilder.build(context) ?? (_, _) => null,
    findChildIndexCallback: args.findChildIndexCallback.build(context),
    itemCount: args.itemCount,
    dragStartBehavior: args.dragStartBehavior,
    allowImplicitScrolling: args.allowImplicitScrolling,
    scrollCacheExtent: args.scrollCacheExtent.build(context),
    restorationId: args.restorationId,
    clipBehavior: args.clipBehavior,
    hitTestBehavior: args.hitTestBehavior,
    padEnds: args.padEnds,
    showScrollbar: args.showScrollbar,
    focusable: args.focusable,
    semanticsLabel: args.semanticsLabel.build(context),
    scrollFocusStyle: args.scrollFocusStyle.build(context),
  ),
);

final $RecipeFormRow = _BuilderStory(
  name: StoryNames.recipes[0],
  args: _fixedKnobs(),
  builder: _frameChild,
  setup: (_, _, _) => recipeFrame(const FormRowRecipe()),
);

final $RecipeCard = _BuilderStory(
  name: StoryNames.recipes[1],
  args: _fixedKnobs(),
  builder: _frameChild,
  setup: (_, _, _) => recipeFrame(const CardRecipe()),
);

final $RecipeListItem = _BuilderStory(
  name: StoryNames.recipes[2],
  args: _fixedKnobs(),
  builder: _frameChild,
  setup: (_, _, _) => recipeFrame(const ListItemRecipe()),
);

final $RecipeToolbar = _BuilderStory(
  name: StoryNames.recipes[3],
  args: _fixedKnobs(),
  builder: _frameChild,
  setup: (_, _, _) => recipeFrame(const ToolbarRecipe()),
);

final $RecipePageWithDrawer = _BuilderStory(
  name: StoryNames.recipes[4],
  args: _fixedKnobs(),
  builder: _frameChild,
  setup: (_, _, _) => recipeFrame(const PageWithDrawerRecipe()),
);

final $Responsive = _BuilderStory(
  args: _fixedKnobs(),
  builder: _frameChild,
  setup: (_, _, _) => responsiveFrames(_sample),
);

final $Accessibility = _BuilderStory(
  args: _fixedKnobs(),
  builder: _frameChild,
  setup: (_, _, _) => accessibilityFrames(build: _sample),
);

final $ExamplePagedSections = _BuilderStory(
  name: StoryNames.example('paged sections'),
  args: _fixedKnobs(),
  builder: _frameChild,
  setup: (context, _, _) => SizedBox(
    height: 200,
    child: PageViewLayout.builder(
      style: stylePreset('Card').build(context),
      itemCount: 4,
      itemBuilder: (context, index) => StratumSlot(
        name: SampleTexts.title.resolve(Localizations.localeOf(context)),
        height: 120,
      ),
    ),
  ),
);
