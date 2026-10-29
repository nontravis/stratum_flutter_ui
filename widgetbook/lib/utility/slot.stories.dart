import 'package:stratum_ui/stratum_ui.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

import '../kit/docs/catalog_docs.dart';
import '../kit/docs/stratum_docs.dart';
import '../kit/preset.dart';
import '../kit/story_set.dart';
import '../shell/catalog_section.dart';
import 'slot_knobs.dart';

part 'slot.stories.g.dart';

final _docs = CatalogDocs(
  figma: Uri.parse(
    'https://www.figma.com/design/wjRe9eL7863nMRfFats8jZ/'
    'Design-System-4-by-Nonthawit?node-id=40000310-9233',
  ),
  usage: '''
StratumSlot(
  name: 'Avatar',
  width: 64,
  height: 64,
)''',
  dos: [
    'Name the slot after the content that belongs in it.',
    'Give it the width and height the real content will take.',
  ],
  donts: [
    'Ship a slot to end users; swap it for real content first.',
    'Use it as a loading or empty state.',
  ],
  accessibility: [
    'The placeholder text reads as "❖ <name>" to a screen reader.',
    'The slot has no action, so it takes no focus.',
  ],
);

const meta = Meta(StratumSlot.new, argsType: SlotKnobs.new);

final componentMeta = ComponentMeta(
  name: 'Slot',
  path: CatalogSection.utility.label,
  docsBuilder: stratumDocs(
    _docs,
    args: [for (final arg in $Playground.args.list) ?arg],
  ),
);

/// A fresh set of knobs: one per constructor param, in constructor order.
SlotKnobsArgs _knobs() =>
    SlotKnobsArgs(padding: presetKnob('padding', _paddings));

final _paddings = <Preset<EdgeInsets>>[
  const Preset.none(),
  Preset(
    'space.md all sides',
    (context) => EdgeInsets.all(context.theme.space.md),
  ),
];

/// Knobs for a story that has no Playground: fixed, so the panel hides them.
SlotKnobsArgs _fixedKnobs() => SlotKnobsArgs.fixed(padding: _paddings.first);

/// The page widget Widgetbook's builder must return; the frame stories show
/// their own layout through `setup`, which drops this child.
StratumSlot _frameChild(BuildContext context, SlotKnobsArgs args) =>
    const StratumSlot();

final $Playground = _Story(
  args: _knobs(),
  builder: (context, args) => StratumSlot(
    height: args.height,
    width: args.width,
    padding: args.padding.build(context),
    name: args.name,
  ),
);

final $Variants = _Story(
  args: _fixedKnobs(),
  builder: _frameChild,
  setup: (_, _, _) => const StratumSlot(),
);

final $Responsive = _Story(
  args: _fixedKnobs(),
  builder: _frameChild,
  setup: (_, _, _) => responsiveFrames((context) => const StratumSlot()),
);

final $Accessibility = _Story(
  args: _fixedKnobs(),
  builder: _frameChild,
  setup: (_, _, _) =>
      accessibilityFrames(build: (context) => const StratumSlot()),
);

final $ExampleAvatarPlaceholder = _Story(
  name: StoryNames.example('avatar placeholder'),
  args: _fixedKnobs(),
  builder: (context, args) =>
      const StratumSlot(name: 'Avatar', width: 64, height: 64),
);
