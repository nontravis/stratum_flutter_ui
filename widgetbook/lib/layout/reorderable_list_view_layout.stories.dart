import 'package:flutter/rendering.dart'
    show ItemExtentBuilder, ScrollCacheExtent, SliverLayoutDimensions;
import 'package:stratum_ui/stratum_ui.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

import '../kit/callback_report.dart';
import '../kit/docs/catalog_docs.dart';
import '../kit/docs/stratum_docs.dart';
import '../kit/preset.dart';
import '../kit/sample_text.dart';
import '../kit/slot_preset.dart';
import '../kit/story_set.dart';
import '../shell/catalog_section.dart';
import 'layout_page.dart';
import 'layout_slots.dart';
import 'recipes.dart';
import 'reorderable_list_view_layout_knobs.dart';

part 'reorderable_list_view_layout.stories.g.dart';

const _docs = CatalogDocs(
  figma: null,
  usage: '''
ReorderableListViewLayout.builder(
  itemCount: settings.length,
  itemBuilder: (context, index) => SettingTile(
    key: ValueKey(settings[index].id),
    setting: settings[index],
  ),
  onReorderItem: (oldIndex, newIndex) =>
      ref.read(settingsProvider).reorder(oldIndex, newIndex),
)''',
  dos: [
    'Give every item a key that follows the data, not the index, so a moved '
        'item keeps its State and focus.',
    'Pick longPressDrag false to drag from anywhere at once; keep it true '
        'when an item holds tappable content.',
    'Reorder the data in onReorderItem exactly as it reports the indices.',
    recipeWindowDo,
  ],
  donts: [
    'Reorder the data with no moveItem call and no findChildIndexCallback; '
        'a live sync needs the callback so focus follows the item.',
    'Hand one ReorderableItemsController to two lists at once; hand it over '
        'only after the first list drops it.',
  ],
  accessibility: [
    'While the list holds focus, Alt and an arrow key move the focused '
        'item; the keys do nothing inside a text field.',
    'A screen reader reads the move actions; the announcement knobs '
        'replace what it hears after a move.',
  ],
);

const meta = Meta(
  ReorderableListViewLayout.builder,
  argsType: ReorderableListViewLayoutKnobs.new,
);

final componentMeta = ComponentMeta(
  name: 'ReorderableListViewLayout',
  path: CatalogSection.layout.label,
  docsBuilder: stratumDocs(
    _docs,
    args: [for (final arg in $Playground.args.list) ?arg],
  ),
);

final _controllers = <Preset<ScrollController>>[
  const Preset('None', _noController),
];

ScrollController? _noController(BuildContext context) => null;

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

/// The item builders this page offers: the default slot builder that names
/// and keys each item by its index (fo11/us06/fr01).
final _itemBuilders = <Preset<Widget Function(BuildContext, int)>>[
  Preset(
    'Slot builder',
    (_) =>
        (context, index) => StratumSlot(
          key: ValueKey('item ${index + 1}'),
          name: 'item ${index + 1}',
        ),
  ),
];

final _itemExtentBuilders = <Preset<ItemExtentBuilder?>>[
  const Preset('None', _noItemExtentBuilder),
  const Preset('Fixed 64 px', _fixed64),
];

ItemExtentBuilder? _noItemExtentBuilder(BuildContext context) => null;
ItemExtentBuilder? _fixed64(BuildContext context) =>
    (_, _) => 64;

final _dragStyles = <Preset<WidgetStyle>>[
  const Preset('None', _noDragStyle),
  Preset('Card', (context) => stylePreset('Card').build(context)),
];

WidgetStyle? _noDragStyle(BuildContext context) => null;

final _itemsControllers = <Preset<ReorderableItemsController>>[
  const Preset('None', _noItemsController),
];

ReorderableItemsController? _noItemsController(BuildContext context) => null;

final _itemTransitionBuilders =
    <Preset<Widget Function(BuildContext, Animation<double>, Widget)?>>[
      const Preset('None', _noTransitionBuilder),
    ];

Widget Function(BuildContext, Animation<double>, Widget)? _noTransitionBuilder(
  BuildContext context,
) => null;

final _cacheExtents = <Preset<ScrollCacheExtent>>[
  const Preset('None', _noCacheExtent),
  const Preset('200 px', _cache200),
];

ScrollCacheExtent? _noCacheExtent(BuildContext context) => null;
ScrollCacheExtent? _cache200(BuildContext context) =>
    const ScrollCacheExtent.pixels(200);

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

final _findChildCallbacks = <Preset<ChildIndexGetter>>[
  const Preset('None', _noFindChild),
];

ChildIndexGetter? _noFindChild(BuildContext context) => null;

/// The move announcements this page offers: null, then one in the toolbar
/// language.
final _moveAnnouncements = <Preset<String Function(int position, int count)>>[
  const Preset('None', _noMoveAnnouncement),
  Preset(
    'Position of count',
    (context) =>
        (position, count) =>
            '$position / $count (${Localizations.localeOf(context).languageCode})',
  ),
];

String Function(int position, int count)? _noMoveAnnouncement(
  BuildContext context,
) => null;

final _atStartAnnouncements = <Preset<String>>[
  const Preset('None', _noAtStart),
  Preset(
    'Close',
    (context) => SampleTexts.close.resolve(Localizations.localeOf(context)),
  ),
];

String? _noAtStart(BuildContext context) => null;

final _atEndAnnouncements = <Preset<String>>[
  const Preset('None', _noAtEnd),
  Preset(
    'Close',
    (context) => SampleTexts.close.resolve(Localizations.localeOf(context)),
  ),
];

String? _noAtEnd(BuildContext context) => null;

/// A fresh set of knobs: one per constructor param, in constructor order.
ReorderableListViewLayoutKnobsArgs _knobs() =>
    ReorderableListViewLayoutKnobsArgs(
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
      itemExtentBuilder: PresetArg(
        _itemExtentBuilders.first,
        name: 'itemExtentBuilder',
        values: _itemExtentBuilders,
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
      dragStyle: PresetArg(
        _dragStyles.first,
        name: 'dragStyle',
        values: _dragStyles,
      ),
      itemsController: PresetArg(
        _itemsControllers.first,
        name: 'itemsController',
        values: _itemsControllers,
      ),
      itemTransitionBuilder: PresetArg(
        _itemTransitionBuilders.first,
        name: 'itemTransitionBuilder',
        values: _itemTransitionBuilders,
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
      findChildIndexCallback: PresetArg(
        _findChildCallbacks.first,
        name: 'findChildIndexCallback',
        values: _findChildCallbacks,
      ),
      moveAnnouncement: PresetArg(
        _moveAnnouncements.first,
        name: 'moveAnnouncement',
        values: _moveAnnouncements,
      ),
      atStartAnnouncement: PresetArg(
        _atStartAnnouncements.first,
        name: 'atStartAnnouncement',
        values: _atStartAnnouncements,
      ),
      atEndAnnouncement: PresetArg(
        _atEndAnnouncements.first,
        name: 'atEndAnnouncement',
        values: _atEndAnnouncements,
      ),
    );

/// Knobs for a story that has no Playground: fixed, so the panel hides them.
ReorderableListViewLayoutKnobsArgs _fixedKnobs() =>
    ReorderableListViewLayoutKnobsArgs.fixed(
      style: widgetStylePresets.first,
      controller: _controllers.first,
      physics: _physicsPresets.first,
      itemBuilder: _itemBuilders.first,
      itemExtentBuilder: _itemExtentBuilders.first,
      dragStyle: _dragStyles.first,
      itemsController: _itemsControllers.first,
      itemTransitionBuilder: _itemTransitionBuilders.first,
      scrollCacheExtent: _cacheExtents.first,
      semanticsLabel: _semanticsLabels.first,
      scrollFocusStyle: _focusStyles.first,
      findChildIndexCallback: _findChildCallbacks.first,
      moveAnnouncement: _moveAnnouncements.first,
      atStartAnnouncement: _atStartAnnouncements.first,
      atEndAnnouncement: _atEndAnnouncements.first,
    );

/// The page widget Widgetbook's builder must return; the frame stories show
/// their own layout through `setup`, which drops this child.
ReorderableListViewLayout _frameChild(
  BuildContext context,
  ReorderableListViewLayoutKnobsArgs args,
) => _list(context, count: 3);

/// The height the scroll stories give the list, since a vertical scroll
/// needs a bounded height.
const _height = 320.0;

/// A reorderable list of [count] keyed slots in a bounded height, the
/// layout every frame story shows.
Widget _sample(BuildContext context) =>
    SizedBox(height: _height, child: _frameChild(context, _fixedKnobs()));

/// A reorderable list of [count] keyed slots.
ReorderableListViewLayout _list(BuildContext context, {required int count}) =>
    ReorderableListViewLayout.builder(
      itemCount: count,
      itemBuilder: _itemBuilders.first.build(context)!,
      onReorderItem: (_, _) {},
    );

final $Playground = _BuilderStory(
  args: _knobs(),
  setup: (context, child, args) =>
      SizedBox(height: _height, child: reportingSetup(context, child, args)),
  builder: (context, args) => ReorderableListViewLayout.builder(
    style: args.style.build(context),
    scrollDirection: args.scrollDirection,
    reverse: args.reverse,
    controller: args.controller.build(context),
    primary: args.primary,
    physics: args.physics.build(context),
    showScrollbar: args.showScrollbar,
    shrinkWrap: args.shrinkWrap,
    itemExtent: args.itemExtent,
    itemExtentBuilder: args.itemExtentBuilder.build(context),
    prototypeItem: slotFor(context, args.prototypeItem, name: 'prototypeItem'),
    itemCount: args.itemCount,
    itemBuilder: args.itemBuilder.build(context)!,
    onReorderItem: args.onReorderItem
        ? (_, _) => CallbackReport.report(context, 'onReorderItem')
        : (_, _) {},
    onReorderStart: args.onReorderStart
        ? (_) => CallbackReport.report(context, 'onReorderStart')
        : null,
    onReorderEnd: args.onReorderEnd
        ? (_) => CallbackReport.report(context, 'onReorderEnd')
        : null,
    dragStyle: args.dragStyle.build(context),
    longPressDrag: args.longPressDrag,
    itemsController: args.itemsController.build(context),
    itemTransitionBuilder: args.itemTransitionBuilder.build(context),
    scrollCacheExtent: args.scrollCacheExtent.build(context),
    dragStartBehavior: args.dragStartBehavior,
    keyboardDismissBehavior: args.keyboardDismissBehavior,
    restorationId: args.restorationId,
    clipBehavior: args.clipBehavior,
    autoScrollerVelocityScalar: args.autoScrollerVelocityScalar,
    focusable: args.focusable,
    semanticsLabel: args.semanticsLabel.build(context),
    scrollFocusStyle: args.scrollFocusStyle.build(context),
    findChildIndexCallback: args.findChildIndexCallback.build(context),
    moveAnnouncement: args.moveAnnouncement.build(context),
    atStartAnnouncement: args.atStartAnnouncement.build(context),
    atEndAnnouncement: args.atEndAnnouncement.build(context),
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

final $ExampleReorderableSettings = _BuilderStory(
  name: StoryNames.example('reorderable settings'),
  args: _fixedKnobs(),
  builder: _frameChild,
  setup: (context, _, _) =>
      SizedBox(height: 240, child: _list(context, count: 6)),
);
