import 'package:stratum_ui/stratum_ui.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

import '../kit/callback_report.dart';
import '../kit/docs/catalog_docs.dart';
import '../kit/docs/stratum_docs.dart';
import '../kit/preset.dart';
import '../kit/slot_preset.dart';
import '../kit/story_set.dart';
import '../kit/style_presets.dart';
import '../shell/catalog_section.dart';
import 'container_layout_knobs.dart';
import 'layout_page.dart';
import 'recipes.dart';

part 'container_layout.stories.g.dart';

const _docs = CatalogDocs(
  figma: null,
  usage: '''
ContainerLayout(
  style: WidgetStyle(padding: EdgeInsets.all(16)),
  child: Text('Content'),
)''',
  dos: [
    'Use it for every box: fill, border, padding, size, and shadow all come '
        'from one WidgetStyle.',
    'Pass builder when the content follows hover, press, focus, or '
        'disabled.',
    recipeWindowDo,
  ],
  donts: [
    'Pass both child and builder; the constructor asserts it, so the '
        'Playground drops the child while a builder is picked.',
    'Combine fit with scroll; the constructor asserts it, so the Playground '
        'drops the fit while a scroll is picked.',
  ],
  accessibility: [
    'The semantics knob describes the visible box, inside its margin.',
    'A tappable box is one button for a screen reader.',
  ],
);

const meta = Meta(ContainerLayout.new, argsType: ContainerLayoutKnobs.new);

final componentMeta = ComponentMeta(
  name: 'ContainerLayout',
  path: CatalogSection.layout.label,
  docsBuilder: stratumDocs(
    _docs,
    args: [for (final arg in $Playground.args.list) ?arg],
  ),
);

/// The slot every story but the example puts inside the container.
const _slotName = 'content';

/// A fresh set of knobs: one per constructor param, in constructor order.
ContainerLayoutKnobsArgs _knobs() => ContainerLayoutKnobsArgs(
  style: styleKnob(),
  transform: transformKnob(),
  transformAlignment: transformAlignmentKnob(),
  semantics: semanticsKnob(),
  interaction: interactionKnob(),
  scroll: scrollKnob(),
  builder: presetKnob('builder', _builders),
);

final _builders =
    <Preset<Widget Function(BuildContext context, InteractionState state)>>[
      const Preset.none(),
      Preset(
        'Slot builder',
        (_) =>
            (context, state) => const StratumSlot(name: 'builder content'),
      ),
    ];

/// Knobs for a story that has no Playground: fixed, so the panel hides them.
ContainerLayoutKnobsArgs _fixedKnobs() => ContainerLayoutKnobsArgs.fixed(
  style: widgetStylePresets.first,
  transform: transformPresets.first,
  transformAlignment: alignmentPresets().first,
  semantics: semanticsPresets.first,
  interaction: interactionPresets.first,
  scroll: scrollPresets.first,
  builder: _builders.first,
);

/// The container every frame story shows: the Card style around one slot.
ContainerLayout _sample(BuildContext context) => ContainerLayout(
  style: stylePreset('Card').build(context),
  child: const StratumSlot(name: _slotName),
);

/// The page widget Widgetbook's builder must return; the frame stories show
/// their own layout through `setup`, which drops this child.
ContainerLayout _frameChild(
  BuildContext context,
  ContainerLayoutKnobsArgs args,
) => _sample(context);

final $Playground = _Story(
  args: _knobs(),
  setup: reportingSetup,
  builder: (context, args) {
    final scroll = args.scroll.build(context);
    final builder = args.builder.build(context);
    return ContainerLayout(
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
      fit: scroll == null ? args.fit : null,
      builder: builder,
      child: builder == null
          ? slotFor(context, args.child, name: _slotName)
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

final $ExampleFittedMedia = _Story(
  name: StoryNames.example('fitted media'),
  args: _fixedKnobs(),
  builder: _frameChild,
  setup: (context, _, _) => SizedBox(
    width: 180,
    height: 80,
    child: ContainerLayout(
      style: stylePreset('Padded').build(context),
      fit: BoxFit.cover,
      child: const StratumSlot(name: 'media', width: 120, height: 120),
    ),
  ),
);
