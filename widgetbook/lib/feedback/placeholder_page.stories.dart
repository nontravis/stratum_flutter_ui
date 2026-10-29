import 'package:stratum_ui/stratum_ui.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

import '../kit/docs/catalog_docs.dart';
import '../kit/docs/stratum_docs.dart';
import '../kit/preset.dart';
import '../kit/sample_text.dart';
import '../kit/slot_preset.dart';
import '../kit/story_set.dart';
import '../shell/catalog_section.dart';
import 'placeholder_page_knobs.dart';

part 'placeholder_page.stories.g.dart';

const _docs = CatalogDocs(
  figma: null,
  usage: '''
StratumPlaceholderPage(
  title: 'Coming soon',
  message: 'This screen arrives in the next release.',
  icon: Icon(Icons.construction_outlined),
)''',
  dos: [
    'Put it where a screen is not built yet, in place of the whole screen.',
    'Give the icon its own color when the theme default does not fit.',
  ],
  donts: [
    'Use it as an empty or error state; those are the app\'s own pages.',
    'Add a back action of your own; the page has none by design.',
  ],
  accessibility: [
    'The title reads to a screen reader, in the toolbar language when it '
        'keeps its default.',
    'The icon is skipped by a screen reader; the title carries the meaning.',
    'The page scrolls and its text wraps at 200% text scale.',
  ],
);

const meta = Meta(
  StratumPlaceholderPage.new,
  argsType: PlaceholderPageKnobs.new,
);

final componentMeta = ComponentMeta(
  name: 'Placeholder page',
  path: CatalogSection.feedback.label,
  docsBuilder: stratumDocs(
    _docs,
    args: [for (final arg in $Playground.args.list) ?arg],
  ),
);

/// The slot name of the `icon` param.
const _iconSlot = 'icon';

final _titles = <Preset<String>>[
  const Preset.none(),
  Preset('Title', (context) => SampleTexts.title.of(context)),
];

final _messages = <Preset<String>>[
  const Preset.none(),
  Preset('Message', (context) => SampleTexts.message.of(context)),
];

/// A fresh set of knobs: one per constructor param, in constructor order.
PlaceholderPageKnobsArgs _knobs() => PlaceholderPageKnobsArgs(
  title: presetKnob('title', _titles),
  message: presetKnob('message', _messages),
  icon: EnumArg<SlotPreset>(
    SlotPreset.icon,
    name: 'icon',
    values: SlotPreset.values,
  ),
);

/// Knobs for a story that has no Playground: fixed, so the panel hides them.
PlaceholderPageKnobsArgs _fixedKnobs() => PlaceholderPageKnobsArgs.fixed(
  title: _titles.first,
  message: _messages.first,
  icon: SlotPreset.icon,
);

/// The page widget Widgetbook's builder must return; the frame stories show
/// their own layout through `setup`, which drops this child.
StratumPlaceholderPage _frameChild(
  BuildContext context,
  PlaceholderPageKnobsArgs args,
) => const StratumPlaceholderPage();

/// One [StratumPlaceholderPage] with [title], [message], and [icon] each on
/// or off as the three flags say.
Widget _variantOf(
  BuildContext context, {
  bool title = true,
  bool message = true,
  bool icon = true,
}) => StratumPlaceholderPage(
  title: title ? _titles.last.build(context) : null,
  message: message ? _messages.last.build(context) : null,
  icon: icon ? slotFor(context, SlotPreset.icon, name: _iconSlot) : null,
);

/// [page] in a box of fixed height: the page fills the height its parent
/// gives it.
Widget _boxed(Widget page) => fixedBox(height: 360, child: page);

/// Every with-and-without of `title`, `message`, and `icon`, each labelled
/// by the params it keeps.
Widget _variantsGrid() => Builder(
  builder: (context) => ColumnLayout(
    scroll: const Scroll(),
    crossAxisAlignment: CrossAxisAlignment.start,
    gap: 16,
    children: [
      for (final (title, message, icon) in [
        (true, true, true),
        (false, true, true),
        (true, false, true),
        (true, true, false),
        (false, false, true),
        (false, true, false),
        (true, false, false),
      ])
        ColumnLayout(
          crossAxisAlignment: CrossAxisAlignment.start,
          gap: 4,
          children: [
            Text(
              [
                if (title) 'title',
                if (message) 'message',
                if (icon) 'icon',
              ].join(' + '),
            ),
            _boxed(
              _variantOf(context, title: title, message: message, icon: icon),
            ),
          ],
        ),
    ],
  ),
);

final $Playground = _Story(
  args: _knobs(),
  builder: (context, args) => StratumPlaceholderPage(
    title: args.title.build(context),
    message: args.message.build(context),
    icon: slotFor(context, args.icon, name: _iconSlot),
  ),
);

final $Variants = _Story(
  args: _fixedKnobs(),
  builder: _frameChild,
  setup: (_, _, _) => _variantsGrid(),
);

final $Responsive = _Story(
  args: _fixedKnobs(),
  builder: _frameChild,
  setup: (_, _, _) => responsiveFrames((context) => _variantOf(context)),
);

final $Accessibility = _Story(
  args: _fixedKnobs(),
  builder: _frameChild,
  setup: (_, _, _) =>
      accessibilityFrames(build: (context) => _boxed(_variantOf(context))),
);

final $ExampleNotBuiltScreen = _Story(
  name: StoryNames.example('not-built screen'),
  args: _fixedKnobs(),
  builder: (context, args) => StratumPlaceholderPage(
    title: SampleTexts.title.of(context),
    message: SampleTexts.message.of(context),
  ),
);
