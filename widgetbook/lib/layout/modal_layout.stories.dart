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
import 'layout_page.dart';
import 'modal_layout_knobs.dart';
import 'recipes.dart';

part 'modal_layout.stories.g.dart';

const _docs = CatalogDocs(
  figma: null,
  usage: '''
showModalLayout(
  context: context,
  builder: (context) => ModalLayout(
    top: Text('Title'),
    body: Text('Message'),
  ),
)''',
  dos: [
    'Show it through showModalLayout in an app; the Playground draws it in '
        'place so the toolbar window size reaches it.',
    'Leave type null so the window picks: a bottom sheet below the tablet '
        'window size, a modal at tablet and above.',
    'Pass scrollBody false for a body that scrolls itself, such as a list.',
    recipeWindowDo,
  ],
  donts: [
    'Expect a close button in place with onClose null; with no route there '
        'is nothing to close.',
    'Expect size to change a bottom sheet; it takes the window width.',
  ],
  accessibility: [
    'Tab visits the top, tab, and body slots, then the handle and the close '
        'button.',
    'The close button reads as a button labeled by the built-in close '
        'label.',
    'Large text scrolls the body inside the sheet rather than clipping it.',
  ],
);

const meta = Meta(ModalLayout.new, argsType: ModalLayoutKnobs.new);

final componentMeta = ComponentMeta(
  name: 'ModalLayout',
  path: CatalogSection.layout.label,
  docsBuilder: stratumDocs(
    _docs,
    args: [for (final arg in $Playground.args.list) ?arg],
  ),
);

/// The height the modal stories give the layout, since an inline modal
/// takes the height its parent gives it.
const _height = 480.0;

/// A fresh set of knobs: one per constructor param, in constructor order.
ModalLayoutKnobsArgs _knobs() => ModalLayoutKnobsArgs(
  borderRadius: presetKnob('borderRadius', _borderRadii),
  customStyle: presetKnob('customStyle', _customStyles),
);

final _borderRadii = <Preset<BorderRadiusGeometry>>[
  const Preset.none(),
  Preset(
    'radius.lg',
    (context) => BorderRadius.circular(context.theme.radius.lg),
  ),
];

final _customStyles = <Preset<ModalLayoutStyle>>[
  const Preset.none(),
  Preset('Card', (context) {
    final card = stylePreset('Card').build(context);
    return ModalLayoutStyle(top: card, tab: card, body: card);
  }),
];

/// Knobs for a story that has no Playground: fixed, so the panel hides them.
ModalLayoutKnobsArgs _fixedKnobs() => ModalLayoutKnobsArgs.fixed(
  borderRadius: _borderRadii.first,
  customStyle: _customStyles.first,
);

/// The modal layout every frame story shows: a top, a tab, and a body slot.
const _sampleModal = ModalLayout(
  top: StratumSlot(name: 'top'),
  tab: StratumSlot(name: 'tab'),
  body: StratumSlot(name: 'body'),
);

/// [modal] on a bounded height, left aligned so it takes its own width.
Widget _frame(Widget modal) => Align(
  alignment: AlignmentDirectional.topStart,
  child: SizedBox(height: _height, child: modal),
);

/// The page widget Widgetbook's builder must return; the frame stories show
/// their own layout through `setup`, which drops this child.
ModalLayout _frameChild(BuildContext context, ModalLayoutKnobsArgs args) =>
    _sampleModal;

/// The sample modal in its frame, the layout every frame story shows.
Widget _sample(BuildContext context) => _frame(_sampleModal);

final $Playground = _Story(
  args: _knobs(),
  setup: (context, child, args) => Align(
    alignment: AlignmentDirectional.topStart,
    child: SizedBox(
      height: _height,
      child: reportingSetup(context, child, args),
    ),
  ),
  builder: (context, args) => ModalLayout(
    top: slotFor(context, args.top, name: 'top'),
    tab: slotFor(context, args.tab, name: 'tab'),
    body: slotFor(context, args.body, name: 'body') ?? const SizedBox.shrink(),
    type: args.type,
    size: args.size,
    showClose: args.showClose,
    onClose: args.onClose ? reportCallback(context, 'onClose') : null,
    borderRadius: args.borderRadius.build(context),
    safeArea: args.safeArea,
    fullHeight: args.fullHeight,
    scrollBody: args.scrollBody,
    customStyle: args.customStyle.build(context),
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

final $ExampleConfirmation = _Story(
  name: StoryNames.example('confirmation'),
  args: _fixedKnobs(),
  builder: _frameChild,
  setup: (_, _, _) => _frame(
    const ModalLayout(
      top: StratumSlot(name: 'title'),
      body: StratumSlot(name: 'message'),
      showClose: false,
    ),
  ),
);
