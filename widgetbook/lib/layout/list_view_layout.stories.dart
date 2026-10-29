import 'package:flutter/rendering.dart' show ScrollCacheExtent;
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
  prototypeItem: EnumArg<SlotPreset>(
    SlotPreset.none,
    name: 'prototypeItem',
    values: SlotPreset.values,
  ),
  itemCount: slotCountKnob('itemCount', initial: 3),
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

/// The scroll controllers a layout page offers: the default null, then a
/// controller that starts the view at the second item.
final _controllers = <Preset<ScrollController>>[
  const Preset('None', _noController),
  Preset('Start at item 2', (_) => ScrollController(initialScrollOffset: 80)),
];

ScrollController? _noController(BuildContext context) => null;

/// The physics a scroll layout page offers: the default null, then two
/// named choices.
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

/// The item builders a scroll layout page offers: the default slot builder
/// that names each item by its index (fo11/us06/fr01).
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

/// The findChildIndexCallback choices: null, then one that reads a
/// key-to-index map the data keeps in sync.
final _findChildCallbacks = <Preset<ChildIndexGetter>>[
  const Preset('None', _noFindChild),
  const Preset('By key', _findChildByKey),
];

ChildIndexGetter? _noFindChild(BuildContext context) => null;
ChildIndexGetter? _findChildByKey(BuildContext context) =>
    (key) => null; // a real app reads its own key-to-index map here

/// The cache extents a scroll layout page offers.
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

/// The semantics labels a scroll layout page offers.
final _semanticsLabels = <Preset<String>>[
  const Preset('None', _noSemanticsLabel),
  Preset(
    'Title',
    (context) => SampleTexts.title.resolve(Localizations.localeOf(context)),
  ),
  Preset(
    'Message',
    (context) => SampleTexts.message.resolve(Localizations.localeOf(context)),
  ),
];

String? _noSemanticsLabel(BuildContext context) => null;

/// The focus ring styles a scroll layout page offers.
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

/// Knobs for a story that has no Playground: fixed, so the panel hides them.
ListViewLayoutKnobsArgs _fixedKnobs() => ListViewLayoutKnobsArgs.fixed(
  style: widgetStylePresets.first,
  controller: _controllers.first,
  physics: _physicsPresets.first,
  itemBuilder: _itemBuilders.first,
  findChildIndexCallback: _findChildCallbacks.first,
  scrollCacheExtent: _cacheExtents.first,
  semanticsLabel: _semanticsLabels.first,
  scrollFocusStyle: _focusStyles.first,
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
      _itemBuilders.first.build(context)!(context, index),
);

final $Playground = _BuilderStory(
  args: _knobs(),
  setup: (context, child, args) => SizedBox(
    height: _height,
    child: Story.defaultSetup(context, child, args),
  ),
  builder: (context, args) {
    final itemBuilder = args.itemBuilder.build(context);
    final gap =
        args.itemExtent == null &&
            args.prototypeItem == SlotPreset.none &&
            args.semanticChildCount == null
        ? args.gap
        : null;
    return ListViewLayout.builder(
      style: args.style.build(context),
      gap: gap,
      scrollDirection: args.scrollDirection,
      reverse: args.reverse,
      controller: args.controller.build(context),
      primary: args.primary,
      physics: args.physics.build(context),
      showScrollbar: args.showScrollbar,
      shrinkWrap: args.shrinkWrap,
      itemExtent: args.itemExtent,
      prototypeItem: slotFor(
        context,
        args.prototypeItem,
        name: 'prototypeItem',
      ),
      itemCount: args.itemCount,
      itemBuilder: itemBuilder ?? (_, _) => null,
      findChildIndexCallback: args.findChildIndexCallback.build(context),
      addAutomaticKeepAlives: args.addAutomaticKeepAlives,
      addRepaintBoundaries: args.addRepaintBoundaries,
      addSemanticIndexes: args.addSemanticIndexes,
      scrollCacheExtent: args.scrollCacheExtent.build(context),
      semanticChildCount: args.semanticChildCount,
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
