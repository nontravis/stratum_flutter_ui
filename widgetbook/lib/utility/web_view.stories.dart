import 'package:stratum_ui/stratum_ui.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

import '../kit/callback_report.dart';
import '../kit/docs/catalog_docs.dart';
import '../kit/docs/stratum_docs.dart';
import '../kit/preset.dart';
import '../kit/sample_text.dart';
import '../kit/story_set.dart';
import '../shell/catalog_section.dart';
import 'web_view_knobs.dart';

part 'web_view.stories.g.dart';

const _docs = CatalogDocs(
  figma: null,
  usage: '''
StratumWebView(
  source: StratumWebViewSource.url(Uri.parse('https://flutter.dev')),
  allowedOrigins: {Uri.parse('https://flutter.dev')},
  onError: (error) => debugPrint(error.description),
)''',
  dos: [
    'List every origin that may send messages in allowedOrigins; the bridge '
        'stays off while it is empty.',
    'Offer an open-in-new-tab fallback on the web: many sites refuse to be '
        'framed.',
  ],
  donts: [
    'Load a page you do not trust with JavaScript on.',
    'Draw Flutter widgets over the view on Linux; they cannot draw above it.',
  ],
  accessibility: [
    'The page inside carries its own semantics; the view adds none.',
    'Give the view a visible label near it so a screen reader user knows '
        'what it holds.',
  ],
);

const meta = Meta(StratumWebView.new, argsType: WebViewKnobs.new);

final componentMeta = ComponentMeta(
  name: 'Web view',
  path: CatalogSection.utility.label,
  docsBuilder: stratumDocs(
    _docs,
    args: [for (final arg in $Playground.args.list) ?arg],
  ),
);

final _sources = <Preset<StratumWebViewSource>>[
  const Preset('HTML sample', _htmlSample),
  Preset(
    'flutter.dev',
    (context) => StratumWebViewSource.url(Uri.parse('https://flutter.dev')),
  ),
];

StratumWebViewSource _htmlSample(BuildContext context) =>
    const StratumWebViewSource.html('<p>สวัสดี Hello</p>');

final _controllers = <Preset<StratumWebViewController>>[
  const Preset('None', _noController),
  const Preset('Story controller', _StoryController.of),
];

StratumWebViewController? _noController(BuildContext context) => null;

final _origins = <Preset<Set<Uri>>>[
  const Preset('Default', _defaultOrigins),
  Preset('flutter.dev', (context) => {Uri.parse('https://flutter.dev')}),
];

Set<Uri> _defaultOrigins(BuildContext context) => const <Uri>{};

final _decisions = <Preset<StratumNavigationDecision Function(Uri url)>>[
  const Preset('None', _noDecider),
  Preset('Prevent all', (context) => _preventAll),
];

StratumNavigationDecision Function(Uri url)? _noDecider(BuildContext context) =>
    null;

StratumNavigationDecision _preventAll(Uri url) =>
    StratumNavigationDecision.prevent;

/// The value of [preset], for a preset knob that always has one.
T _valueOf<T extends Object>(Preset<T> preset, BuildContext context) =>
    preset.build(context) ??
    (throw StateError('Preset "${preset.name}" has no value'));

/// A fresh set of knobs: one per constructor param, in constructor order.
WebViewKnobsArgs _knobs() => WebViewKnobsArgs(
  source: PresetArg(_sources.first, name: 'source', values: _sources),
  controller: PresetArg(
    _controllers.first,
    name: 'controller',
    values: _controllers,
  ),
  allowedOrigins: PresetArg(
    _origins.first,
    name: 'allowedOrigins',
    values: _origins,
  ),
  onNavigationRequest: PresetArg(
    _decisions.first,
    name: 'onNavigationRequest',
    values: _decisions,
  ),
);

/// The page widget Widgetbook's builder must return; the frame stories show
/// their own layout through `setup`, which drops this child.
StratumWebView _frameChild(BuildContext context, WebViewKnobsArgs args) =>
    StratumWebView(source: _valueOf(_sources.first, context));

/// [source] in a fixed box, since a web view needs a bounded size.
Widget _boxedView(StratumWebViewSource source) => ContainerLayout(
  style: const WidgetStyle(width: 320, height: 240),
  child: StratumWebView(source: source),
);

final $Playground = _Story(
  args: _knobs(),
  setup: (context, child, args) =>
      _StoryControllerScope(child: reportingSetup(context, child, args)),
  builder: (context, args) => StratumWebView(
    source: _valueOf(args.source, context),
    controller: args.controller.build(context),
    allowedOrigins: _valueOf(args.allowedOrigins, context),
    javaScriptEnabled: args.javaScriptEnabled,
    onMessage: args.onMessage
        ? reportValue<StratumWebViewMessage>(context, 'onMessage')
        : null,
    onNavigationRequest: args.onNavigationRequest.build(context),
    onPageStarted: args.onPageStarted
        ? reportValue<Uri?>(context, 'onPageStarted')
        : null,
    onPageFinished: args.onPageFinished
        ? reportValue<Uri?>(context, 'onPageFinished')
        : null,
    onError: args.onError
        ? reportValue<StratumWebViewError>(context, 'onError')
        : null,
  ),
);

final $Variants = _Story(
  args: _knobs(),
  builder: _frameChild,
  setup: (_, _, _) => ColumnLayout(
    scroll: const Scroll(),
    crossAxisAlignment: CrossAxisAlignment.start,
    gap: 16,
    children: [
      for (final preset in _sources)
        ColumnLayout(
          crossAxisAlignment: CrossAxisAlignment.start,
          gap: 4,
          children: [
            Text(preset.name),
            Builder(
              builder: (context) => _boxedView(_valueOf(preset, context)),
            ),
          ],
        ),
    ],
  ),
);

final $Responsive = _Story(
  args: _knobs(),
  builder: _frameChild,
  setup: (_, _, _) => responsiveFrames(
    (context) => _boxedView(_valueOf(_sources.first, context)),
  ),
);

final $Accessibility = _Story(
  args: _knobs(),
  builder: _frameChild,
  setup: (_, _, _) => accessibilityFrames(
    build: (context) => _boxedView(_valueOf(_sources.first, context)),
  ),
);

final $ExampleHelpPage = _Story(
  name: StoryNames.example('embedded help page'),
  args: _knobs(),
  builder: _frameChild,
  setup: (_, _, _) => Builder(
    builder: (context) {
      final message = SampleTexts.message.resolve(
        Localizations.localeOf(context),
      );
      return _boxedView(StratumWebViewSource.html('<p>$message</p>'));
    },
  ),
);

/// Holds the one [StratumWebViewController] the `Story controller` preset
/// hands out and disposes it with the story.
///
/// Sits outside Widgetbook's `KeyedSubtree`, so a knob change keeps the
/// controller while the view below it is rebuilt.
class _StoryControllerScope extends StatefulWidget {
  const _StoryControllerScope({required this.child});

  final Widget child;

  @override
  State<_StoryControllerScope> createState() => _StoryControllerScopeState();
}

class _StoryControllerScopeState extends State<_StoryControllerScope> {
  StratumWebViewController? _controller;

  /// The controller, created on first use so the story pays for a platform
  /// view only when the preset asks for one.
  StratumWebViewController get controller =>
      _controller ??= StratumWebViewController();

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Reads the controller of the nearest [_StoryControllerScope].
abstract final class _StoryController {
  static StratumWebViewController of(BuildContext context) {
    final state = context.findAncestorStateOfType<_StoryControllerScopeState>();
    if (state == null) {
      throw StateError('Story controller needs the Playground setup');
    }
    return state.controller;
  }
}
