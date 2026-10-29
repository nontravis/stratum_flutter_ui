import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:stratum_ui/stratum_ui.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

import '../kit/docs/catalog_docs.dart';
import '../kit/docs/stratum_docs.dart';
import '../kit/preset.dart';
import '../kit/slot_preset.dart';
import '../kit/story_set.dart';
import '../kit/style_presets.dart';
import '../shell/catalog_section.dart';
import 'layout_page.dart';
import 'list_view_layout_knobs.dart';
import 'recipes.dart';

part 'list_view_layout.stories.g.dart';

const _docs = CatalogDocs(
  figma: null,
  usage: '''
ListViewLayout.builder(
  style: WidgetStyle(padding: EdgeInsets.all(16)),
  itemCount: items.length,
  itemBuilder: (context, index) => ItemTile(items[index]),
)''',
  dos: [
    'Use it for every long list: it builds only the items near the viewport.',
    'Set gap instead of a spacer widget between the items.',
    'Give every item a key when the data can reorder behind the list.',
    recipeWindowDo,
  ],
  donts: [
    'Set gap without an itemCount, or beside itemExtent, prototypeItem, or '
        'semanticChildCount; the constructor asserts it, so the Playground '
        'drops the gap while those are set.',
    'Set primary beside an explicit controller, prototypeItem beside '
        'itemExtent, or semanticChildCount above itemCount; the builders '
        'assert on each, so the Playground drops or clamps the losing knob.',
    'Put the list inside an unbounded height along its scroll direction; '
        'give the page or column a bounded height first.',
  ],
  accessibility: [
    'A focusable list, by default on web and desktop, is a Tab stop whose '
        'arrows, Page Up, Page Down, Home, and End scroll it.',
    'The semanticsLabel knob names the list for a screen reader.',
  ],
);

const meta = Meta(ListViewLayout.builder, argsType: ListViewLayoutKnobs.new);

final componentMeta = ComponentMeta(
  name: 'ListViewLayout',
  path: CatalogSection.layout.label,
  docsBuilder: stratumDocs(
    _docs,
    args: [for (final arg in $Playground.args.list) ?arg],
  ),
);

/// A fresh set of knobs: one per constructor param, in constructor order.
ListViewLayoutKnobsArgs _knobs() => ListViewLayoutKnobsArgs(
  style: styleKnob(),
  controller: presetKnob('controller', scrollControllerPresets),
  physics: presetKnob('physics', scrollPhysicsPresets),
  prototypeItem: EnumArg<SlotPreset>(
    SlotPreset.none,
    name: 'prototypeItem',
    values: SlotPreset.values,
  ),
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
ListViewLayoutKnobsArgs _fixedKnobs() => ListViewLayoutKnobsArgs.fixed(
  style: widgetStylePresets.first,
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

/// A lazy list of three slots in a bounded height, the layout every frame
/// story shows.
Widget _sample(BuildContext context) =>
    SizedBox(height: _height, child: _frameChild(context, _fixedKnobs()));

/// The page widget Widgetbook's builder must return; the frame stories show
/// their own layout through `setup`, which drops this child.
ListViewLayout _frameChild(
  BuildContext context,
  ListViewLayoutKnobsArgs args,
) => ListViewLayout.builder(
  itemCount: 3,
  itemBuilder: (context, index) =>
      slotItemBuilders.first.valueOf(context)(context, index),
);

final $Playground = _BuilderStory(
  args: _knobs(),
  setup: (context, child, args) => LayoutStoryScope(
    child: SizedBox(
      height: _height,
      child: Story.defaultSetup(context, child, args),
    ),
  ),
  builder: (context, args) {
    final itemBuilder = args.itemBuilder.build(context);
    final controller = args.controller.build(context);
    final picked = args.prototypeItem == SlotPreset.none
        ? null
        : args.prototypeItem;
    final prototype = ScrollKnobGuards.prototypeItem(
      prototypeItem: picked,
      itemExtent: args.itemExtent,
      itemExtentBuilder: null,
    );
    final gap = ScrollKnobGuards.gap(
      gap: args.gap,
      itemExtent: args.itemExtent,
      prototypeItem: prototype,
      semanticChildCount: args.semanticChildCount,
    );
    return ListViewLayout.builder(
      style: args.style.build(context),
      gap: gap,
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
      itemExtent: args.itemExtent,
      prototypeItem: slotFor(
        context,
        prototype ?? SlotPreset.none,
        name: 'prototypeItem',
      ),
      itemCount: args.itemCount,
      itemBuilder: itemBuilder ?? (_, _) => null,
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

final $ExampleStyledList = _BuilderStory(
  name: StoryNames.example('styled list'),
  args: _fixedKnobs(),
  builder: _frameChild,
  setup: (context, _, _) => SizedBox(
    height: 240,
    child: ListViewLayout.builder(
      style: stylePreset('Card').build(context),
      gap: context.theme.space.sm,
      itemCount: 12,
      itemBuilder: (context, index) =>
          StratumSlot(name: 'row ${index + 1}', height: 36),
    ),
  ),
);
