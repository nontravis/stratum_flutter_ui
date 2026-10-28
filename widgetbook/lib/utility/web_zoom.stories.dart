import 'package:stratum_ui/stratum_ui.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

import '../kit/docs/catalog_docs.dart';
import '../kit/docs/stratum_docs.dart';
import '../kit/slot_preset.dart';
import '../kit/story_set.dart';
import '../shell/catalog_section.dart';
import 'web_zoom_knobs.dart';

part 'web_zoom.stories.g.dart';

const _docs = CatalogDocs(
  figma: null,
  usage: '''
StratumWebZoom(
  maxScale: 3,
  child: Image.asset('assets/map.png'),
)''',
  dos: [
    'Wrap the whole page of a web app that people should pinch to zoom.',
    'Set maxScale to at least minScale; the constructor asserts it.',
  ],
  donts: [
    'Expect zoom on Android, iOS, macOS, Windows, or Linux; the widget '
        'builds the child alone there.',
    'Nest it in another zoom or pan area.',
  ],
  accessibility: [
    'It adds no semantics; the child keeps its own.',
    'Zoom eases at once under reduced motion.',
  ],
);

const meta = Meta(StratumWebZoom.new, argsType: WebZoomKnobs.new);

final componentMeta = ComponentMeta(
  name: 'Web zoom',
  path: CatalogSection.utility.label,
  docsBuilder: stratumDocs(
    _docs,
    args: [for (final arg in $Playground.args.list) ?arg],
  ),
);

/// The slot every story but the example puts inside the zoom.
const _slotName = 'content';

/// The page widget Widgetbook's builder must return; the frame stories show
/// their own layout through `setup`, which drops this child.
StratumWebZoom _frameChild(BuildContext context, WebZoomKnobsArgs args) =>
    const StratumWebZoom(child: StratumSlot(name: _slotName));

final $Playground = _Story(
  args: WebZoomKnobsArgs(),
  builder: (context, args) => StratumWebZoom(
    minScale: args.minScale,
    maxScale: args.maxScale,
    child:
        slotFor(context, args.child, name: _slotName) ??
        const SizedBox.shrink(),
  ),
);

final $Variants = _Story(
  args: WebZoomKnobsArgs(),
  builder: _frameChild,
  setup: (_, _, _) => const StratumWebZoom(child: StratumSlot(name: _slotName)),
);

final $Responsive = _Story(
  args: WebZoomKnobsArgs(),
  builder: _frameChild,
  setup: (_, _, _) => responsiveFrames(
    (context) => const StratumWebZoom(child: StratumSlot(name: _slotName)),
  ),
);

final $Accessibility = _Story(
  args: WebZoomKnobsArgs(),
  builder: _frameChild,
  setup: (_, _, _) => accessibilityFrames(
    build: (context) =>
        const StratumWebZoom(child: StratumSlot(name: _slotName)),
  ),
);

final $ExampleZoomableMap = _Story(
  name: StoryNames.example('zoomable map'),
  args: WebZoomKnobsArgs(),
  builder: (context, args) => const StratumWebZoom(
    maxScale: 3,
    child: StratumSlot(name: 'Map', width: 320, height: 240),
  ),
);
