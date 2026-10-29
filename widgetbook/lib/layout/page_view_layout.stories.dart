import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:stratum_ui/stratum_ui.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

import '../kit/callback_report.dart';
import '../kit/docs/catalog_docs.dart';
import '../kit/docs/stratum_docs.dart';
import '../kit/preset.dart';
import '../kit/sample_text.dart';
import '../kit/story_set.dart';
import '../kit/style_presets.dart';
import '../shell/catalog_section.dart';
import 'layout_page.dart';
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
  const Preset.none(),
  Preset('Start at page 2', (_) => PageController(initialPage: 1)),
];

/// A fresh set of knobs: one per constructor param, in constructor order.
PageViewLayoutKnobsArgs _knobs() => PageViewLayoutKnobsArgs(
  style: styleKnob(),
  controller: presetKnob('controller', _controllers),
  physics: presetKnob('physics', scrollPhysicsPresets),
  itemBuilder: presetKnob('itemBuilder', slotItemBuilders),
  findChildIndexCallback: presetKnob(
    'findChildIndexCallback',
    findChildIndexPresets,
  ),
  itemCount: slotCountKnob('itemCount', initial: 3),
  scrollCacheExtent: presetKnob('scrollCacheExtent', scrollCacheExtentPresets),
  semanticsLabel: presetKnob('semanticsLabel', scrollSemanticsLabelPresets),
  scrollFocusStyle: presetKnob('scrollFocusStyle', scrollFocusStylePresets),
);

/// Knobs for a story that has no Playground: fixed, so the panel hides them.
PageViewLayoutKnobsArgs _fixedKnobs() => PageViewLayoutKnobsArgs.fixed(
  style: widgetStylePresets.first,
  controller: _controllers.first,
  physics: scrollPhysicsPresets.first,
  itemBuilder: slotItemBuilders.first,
  findChildIndexCallback: findChildIndexPresets.first,
  scrollCacheExtent: scrollCacheExtentPresets.first,
  semanticsLabel: scrollSemanticsLabelPresets.first,
  scrollFocusStyle: scrollFocusStylePresets.first,
);

/// The page widget Widgetbook's builder must return; the frame stories show
/// their own layout through `setup`, which drops this child.
PageViewLayout _frameChild(
  BuildContext context,
  PageViewLayoutKnobsArgs args,
) => PageViewLayout.builder(
  itemCount: 3,
  itemBuilder: (context, index) =>
      slotItemBuilders.first.build(context)!(context, index),
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
      itemBuilder: (context, index) =>
          StratumSlot(name: SampleTexts.title.of(context), height: 120),
    ),
  ),
);
