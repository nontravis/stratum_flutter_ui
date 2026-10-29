import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:stratum_ui/stratum_ui.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

import '../kit/docs/catalog_docs.dart';
import '../kit/docs/stratum_docs.dart';
import '../kit/preset.dart';
import '../kit/story_set.dart';
import '../kit/style_presets.dart';
import '../shell/catalog_section.dart';
import 'grid_view_layout_knobs.dart';
import 'layout_page.dart';
import 'recipes.dart';

part 'grid_view_layout.stories.g.dart';

const _docs = CatalogDocs(
  figma: null,
  usage: '''
GridViewLayout.builder(
  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
  itemCount: photos.length,
  itemBuilder: (context, index) => PhotoTile(photos[index]),
)''',
  dos: [
    'Use it for a photo grid or a card grid; it builds only the cells near '
        'the viewport.',
    'Pick the gridDelegate by the use: a fixed column count for tiles, a '
        'max extent so the count follows the width.',
    recipeWindowDo,
  ],
  donts: [
    'Build a grid from a raw GridView; the layout carries the style, the '
        'scroll behavior, and the keyboard scrolling.',
    'Set primary beside an explicit controller or semanticChildCount above '
        'itemCount; the builders assert on each, so the Playground drops or '
        'clamps the losing knob.',
    'Give the grid an unbounded cross axis; it needs a bounded width for a '
        'vertical scroll and a bounded height for a horizontal one.',
  ],
  accessibility: [
    'A focusable grid, by default on web and desktop, is a Tab stop whose '
        'arrows, Page Up, Page Down, Home, and End scroll it.',
    'The semanticsLabel knob names the grid for a screen reader.',
  ],
);

const meta = Meta(GridViewLayout.builder, argsType: GridViewLayoutKnobs.new);

final componentMeta = ComponentMeta(
  name: 'GridViewLayout',
  path: CatalogSection.layout.label,
  docsBuilder: stratumDocs(
    _docs,
    args: [for (final arg in $Playground.args.list) ?arg],
  ),
);

/// The grid delegates a grid page offers: two columns first, then wider
/// and adaptive choices.
final _gridDelegates = <RequiredPreset<SliverGridDelegate>>[
  const RequiredPreset('2 columns', _twoColumns),
  const RequiredPreset('4 columns', _fourColumns),
  const RequiredPreset('Max 120 px', _max120),
];

SliverGridDelegate _twoColumns(BuildContext context) =>
    const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2);
SliverGridDelegate _fourColumns(BuildContext context) =>
    const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4);
SliverGridDelegate _max120(BuildContext context) =>
    const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 120);

/// A fresh set of knobs: one per constructor param, in constructor order.
GridViewLayoutKnobsArgs _knobs() => GridViewLayoutKnobsArgs(
  style: styleKnob(),
  gridDelegate: requiredPresetKnob('gridDelegate', _gridDelegates),
  controller: presetKnob('controller', scrollControllerPresets),
  physics: presetKnob('physics', scrollPhysicsPresets),
  itemCount: slotCountKnob('itemCount', initial: 3),
  itemBuilder: presetKnob('itemBuilder', slotItemBuilders),
  findChildIndexCallback: presetKnob(
    'findChildIndexCallback',
    findChildIndexPresets,
  ),
  scrollCacheExtent: presetKnob('scrollCacheExtent', scrollCacheExtentPresets),
  semanticsLabel: presetKnob('semanticsLabel', scrollSemanticsLabelPresets),
  scrollFocusStyle: presetKnob('scrollFocusStyle', scrollFocusStylePresets),
);

/// Knobs for a story that has no Playground: fixed, so the panel hides them.
GridViewLayoutKnobsArgs _fixedKnobs() => GridViewLayoutKnobsArgs.fixed(
  style: widgetStylePresets.first,
  gridDelegate: _gridDelegates.first,
  controller: scrollControllerPresets.first,
  physics: scrollPhysicsPresets.first,
  itemBuilder: slotItemBuilders.first,
  findChildIndexCallback: findChildIndexPresets.first,
  scrollCacheExtent: scrollCacheExtentPresets.first,
  semanticsLabel: scrollSemanticsLabelPresets.first,
  scrollFocusStyle: scrollFocusStylePresets.first,
);

/// The height the scroll stories give the view, since a vertical scroll
/// needs a bounded height.
const _height = 320.0;

/// The page widget Widgetbook's builder must return; the frame stories show
/// their own layout through `setup`, which drops this child.
GridViewLayout _frameChild(
  BuildContext context,
  GridViewLayoutKnobsArgs args,
) => GridViewLayout.builder(
  gridDelegate: _gridDelegates.first.valueOf(context),
  itemCount: 6,
  itemBuilder: (context, index) =>
      slotItemBuilders.first.valueOf(context)(context, index),
);

/// A two-column grid of six slots in a bounded height, the layout every
/// frame story shows.
Widget _sample(BuildContext context) =>
    SizedBox(height: _height, child: _frameChild(context, _fixedKnobs()));

final $Playground = _BuilderStory(
  args: _knobs(),
  setup: (context, child, args) => LayoutStoryScope(
    child: SizedBox(
      height: _height,
      child: Story.defaultSetup(context, child, args),
    ),
  ),
  builder: (context, args) {
    final controller = args.controller.build(context);
    return GridViewLayout.builder(
      style: args.style.build(context),
      gridDelegate: args.gridDelegate.valueOf(context),
      scrollDirection: args.scrollDirection,
      reverse: args.reverse,
      controller: controller,
      primary: ScrollKnobGuards.primary(
        primary: args.primary,
        controller: controller,
      ),
      physics: args.physics.build(context),
      showScrollbar: args.showScrollbar,
      shrinkWrap: args.shrinkWrap,
      itemCount: args.itemCount,
      itemBuilder: args.itemBuilder.build(context) ?? (_, _) => null,
      findChildIndexCallback: args.findChildIndexCallback.build(context),
      addAutomaticKeepAlives: args.addAutomaticKeepAlives,
      addRepaintBoundaries: args.addRepaintBoundaries,
      addSemanticIndexes: args.addSemanticIndexes,
      scrollCacheExtent: args.scrollCacheExtent.build(context),
      semanticChildCount: ScrollKnobGuards.semanticChildCount(
        count: args.semanticChildCount,
        itemCount: args.itemCount,
      ),
      dragStartBehavior: args.dragStartBehavior,
      keyboardDismissBehavior: args.keyboardDismissBehavior,
      restorationId: args.restorationId,
      clipBehavior: args.clipBehavior,
      focusable: args.focusable,
      semanticsLabel: args.semanticsLabel.build(context),
      scrollFocusStyle: args.scrollFocusStyle.build(context),
    );
  },
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

final $ExamplePhotoGrid = _BuilderStory(
  name: StoryNames.example('photo grid'),
  args: _fixedKnobs(),
  builder: _frameChild,
  setup: (context, _, _) => SizedBox(
    height: 320,
    child: GridViewLayout.builder(
      style: stylePreset('Card').build(context),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 140,
      ),
      itemCount: 12,
      itemBuilder: (context, index) =>
          StratumSlot(name: 'photo ${index + 1}', height: 96),
    ),
  ),
);
