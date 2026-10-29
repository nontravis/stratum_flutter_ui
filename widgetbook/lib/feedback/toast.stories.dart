import 'package:stratum_ui/stratum_ui.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

import '../kit/callback_report.dart';
import '../kit/docs/catalog_docs.dart';
import '../kit/docs/stratum_docs.dart';
import '../kit/preset.dart';
import '../kit/sample_text.dart';
import '../kit/slot_preset.dart';
import '../kit/story_set.dart';
import '../layout/layout_slots.dart';
import '../shell/catalog_section.dart';
import 'toast_knobs.dart';

part 'toast.stories.g.dart';

/// The slot names the Playground's stand-ins carry.
const _appSlot = 'app';
const _lookSlot = 'app toast look';

/// The text of the trigger beside the app slot.
const _showToastText = SampleText(th: 'แสดงการแจ้งเตือน', en: 'Show toast');

final _docs = CatalogDocs(
  figma: Uri.parse(
    'https://www.figma.com/design/wjRe9eL7863nMRfFats8jZ/'
    'Design-System-4-by-Nonthawit?node-id=935-17178',
  ),
  usage: '''
MaterialApp(
  builder: (context, child) => StratumToastHost(child: child!),
  home: MyHomePage(),
)

// Anywhere below the host:
context.showToast(
  message: 'Saved',
  kind: FeedbackState.positive,
  action: StratumToastAction(label: 'Undo', onPressed: undoSave),
)''',
  dos: [
    'Mount one host in `MaterialApp.builder`, below the theme application, '
        'so every route shows its notices.',
    'Call `context.dismissAllToasts()` on logout so a notice from the ended '
        'session never reaches the next one.',
    'Give a notice an action when the user may need more than 4 seconds to '
        'act on it.',
  ],
  donts: [
    'Mount a second root host; toastification keeps one wrapper per process.',
    'Put a secret or personal data in `message`; the host shows and '
        'announces it as is.',
    'Use a notice as the only place a result shows; it closes by itself.',
  ],
  accessibility: [
    'The host announces each notice with its kind name and message.',
    'A notice with an action stays open while a screen reader runs; one '
        'without closes after 4 seconds.',
    'Hover, touch, and focus inside a notice pause its close timer.',
    'The focus shortcut moves focus into the newest notice; Esc closes it.',
    'Every kind differs by icon as well as color.',
  ],
);

/// A look the app supplies, stood in as a slot (US-03 FR-03).
Widget _slotLook(BuildContext context, StratumToastNotice notice) =>
    const StratumSlot(name: _lookSlot);

String? _none(BuildContext context) => null;

String _text(BuildContext context, SampleText text) =>
    text.resolve(Localizations.localeOf(context));

final _builders = <Preset<StratumToastBuilder>>[
  const Preset('None', _noBuilder),
  Preset('Slot look', (context) => _slotLook),
];

StratumToastBuilder? _noBuilder(BuildContext context) => null;

final _closeLabels = <Preset<String>>[
  const Preset('None', _none),
  Preset('Close', (context) => _text(context, SampleTexts.close)),
];

const _infoLabel = SampleText(th: 'ข้อมูล', en: 'Info');
const _negativeLabel = SampleText(th: 'ผิดพลาด', en: 'Error');
const _warningLabel = SampleText(th: 'คำเตือน', en: 'Warning');
const _positiveLabel = SampleText(th: 'สำเร็จ', en: 'Success');

/// Each kind's accessible name, in both toolbar languages.
const _kindSamples = {
  FeedbackState.info: _infoLabel,
  FeedbackState.negative: _negativeLabel,
  FeedbackState.warning: _warningLabel,
  FeedbackState.positive: _positiveLabel,
};

final _kindLabels = <Preset<Map<FeedbackState, String>>>[
  const Preset('None', _noKindLabels),
  Preset(
    'Sample',
    (context) => {
      for (final MapEntry(:key, :value) in _kindSamples.entries)
        key: _text(context, value),
    },
  ),
];

Map<FeedbackState, String>? _noKindLabels(BuildContext context) => null;

final _focusShortcuts = <Preset<List<SingleActivator>>>[
  const Preset('None', _noShortcuts),
  Preset(
    'Ctrl+Shift+N',
    (context) => const [
      SingleActivator(LogicalKeyboardKey.keyN, control: true, shift: true),
    ],
  ),
];

List<SingleActivator>? _noShortcuts(BuildContext context) => null;

const _shortcutHint = SampleText(
  th: 'กด Ctrl+Shift+N เพื่อไปที่การแจ้งเตือน',
  en: 'Press Ctrl+Shift+N to reach the notice',
);

final _shortcutHints = <Preset<String>>[
  const Preset('None', _none),
  Preset('Sample', (context) => _text(context, _shortcutHint)),
];

final _messages = <Preset<String>>[
  Preset('Message', (context) => _text(context, SampleTexts.message)),
  Preset('Label', (context) => _text(context, SampleTexts.label)),
];

final _actions = <Preset<StratumToastAction>>[
  const Preset('None', _noAction),
  Preset(
    'With action',
    (context) => StratumToastAction(
      label: _text(context, SampleTexts.label),
      onPressed: reportCallback(context, 'onPressed'),
    ),
  ),
];

StratumToastAction? _noAction(BuildContext context) => null;

final _placements = <Preset<StratumToastPlacement>>[
  const Preset('None', _noPlacement),
  for (final corner in StratumToastCorner.values)
    Preset('float ${corner.name}', (context) => StratumToastFloat(corner)),
  for (final edge in StratumToastEdge.values)
    Preset('solid ${edge.name}', (context) => StratumToastSolid(edge)),
];

StratumToastPlacement? _noPlacement(BuildContext context) => null;

const meta = Meta(StratumToastHost.new, argsType: ToastKnobs.new);

final componentMeta = ComponentMeta(
  name: 'Toast',
  path: CatalogSection.feedback.label,
  docsBuilder: stratumDocs(
    _docs,
    args: [for (final arg in $Playground.args.list) ?arg],
  ),
);

/// A fresh set of knobs: one per host param, then one per `showToast` param.
ToastKnobsArgs _knobs() => ToastKnobsArgs(
  child: EnumArg<SlotPreset>(
    SlotPreset.slot,
    name: 'child',
    values: SlotPreset.values,
  ),
  builder: PresetArg(_builders.first, name: 'builder', values: _builders),
  closeButtonLabel: PresetArg(
    _closeLabels.first,
    name: 'closeButtonLabel',
    values: _closeLabels,
  ),
  kindLabels: PresetArg(
    _kindLabels.first,
    name: 'kindLabels',
    values: _kindLabels,
  ),
  focusShortcuts: PresetArg(
    _focusShortcuts.first,
    name: 'focusShortcuts',
    values: _focusShortcuts,
  ),
  focusShortcutHint: PresetArg(
    _shortcutHints.first,
    name: 'focusShortcutHint',
    values: _shortcutHints,
  ),
  message: PresetArg(_messages.first, name: 'message', values: _messages),
  action: PresetArg(_actions.first, name: 'action', values: _actions),
  kind: EnumArg<FeedbackState>(
    FeedbackState.info,
    name: 'kind',
    values: FeedbackState.values,
  ),
  placement: PresetArg(
    _placements.first,
    name: 'placement',
    values: _placements,
  ),
  customStyle: PresetArg(
    widgetStylePresets.first,
    name: 'customStyle',
    values: widgetStylePresets,
  ),
);

/// Knobs for a story that has no Playground: fixed, so the panel hides them.
ToastKnobsArgs _fixedKnobs({
  FeedbackState kind = FeedbackState.info,
  Preset<StratumToastAction>? action,
}) => ToastKnobsArgs.fixed(
  child: SlotPreset.slot,
  builder: _builders.first,
  closeButtonLabel: _closeLabels.first,
  kindLabels: _kindLabels.first,
  focusShortcuts: _focusShortcuts.first,
  focusShortcutHint: _shortcutHints.first,
  message: _messages.first,
  action: action ?? _actions.first,
  kind: kind,
  placement: _placements.first,
  customStyle: widgetStylePresets.first,
);

/// The `Show toast` trigger: one `showToast` call with the knobs' values.
Widget _trigger(BuildContext context, ToastKnobsArgs args) => TextButton(
  onPressed: () => context.showToast(
    message: args.message.valueOf(context),
    action: args.action.build(context),
    kind: args.kind,
    placement: args.placement.build(context),
    customStyle: args.customStyle.build(context),
  ),
  child: Text(_text(context, _showToastText)),
);

/// The app the host wraps: the trigger beside the `child` knob's slot.
Widget _app(ToastKnobsArgs args) => Builder(
  builder: (context) => ColumnLayout(
    mainAxisSize: MainAxisSize.min,
    gap: 8,
    children: [
      _trigger(context, args),
      ?slotFor(context, args.child, name: _appSlot),
    ],
  ),
);

/// The whole host, every knob as passed.
StratumToastHost _hostOf(BuildContext context, ToastKnobsArgs args) =>
    StratumToastHost(
      builder: args.builder.build(context),
      closeButtonLabel: args.closeButtonLabel.build(context),
      kindLabels: args.kindLabels.build(context),
      focusShortcuts: args.focusShortcuts.build(context),
      focusShortcutHint: args.focusShortcutHint.build(context),
      child: _app(args),
    );

/// [child] in an [Overlay] of its own.
///
/// An app mounts the host in `MaterialApp.builder`, above its navigator, so
/// the host draws a notice in its own wrapper. The catalog mounts it under
/// Widgetbook's navigator, whose overlay sits above the theme, direction,
/// and viewport addons, so a notice would draw outside them; this overlay
/// is the nearest one, under the addons.
Widget _toastStage(Widget child) => Overlay.wrap(child: child);

/// The page widget Widgetbook's builder must return; the frame stories show
/// their own layout through `setup`, which drops this child.
StratumToastHost _frameChild(BuildContext context, ToastKnobsArgs args) =>
    const StratumToastHost(child: SizedBox.shrink());

/// One frame of a frame story: a host of its own, nested under the story's
/// root host, so it reads this frame's window size and text scale.
Widget _frame(BuildContext context) => StratumToastHost(
  child: Builder(builder: (context) => _trigger(context, _fixedKnobs())),
);

/// [frames] under the one root host; every frame's host nests in it
/// (toast_host.dart: a second root host throws in a debug build).
Widget _underRootHost(Widget frames) =>
    _toastStage(StratumToastHost(child: frames));

/// One notice that stays where it is drawn: no host, so no timer.
StratumToastNotice _noticeOf(
  BuildContext context,
  FeedbackState kind, {
  required bool withAction,
}) => StratumToastNotice(
  message: _text(context, SampleTexts.message),
  kind: kind,
  placement: const StratumToastFloat(StratumToastCorner.bottomCenter),
  insets: EdgeInsets.zero,
  pageSnack: null,
  customStyle: null,
  action: withAction ? _actions.last.build(context) : null,
  close: reportCallback(context, 'close'),
  closeLabel: _text(context, SampleTexts.close),
  kindLabel: _text(context, _kindSamples[kind]!),
);

/// Every [FeedbackState] with and without an action, each a static
/// [StratumToastPlainLook] under its label (US-01 FR-06 E07).
Widget _variantsGrid() => CallbackReport(
  child: Builder(
    builder: (context) => ColumnLayout(
      scroll: const Scroll(),
      crossAxisAlignment: CrossAxisAlignment.start,
      gap: 16,
      children: [
        for (final kind in FeedbackState.values)
          for (final withAction in [false, true])
            ColumnLayout(
              crossAxisAlignment: CrossAxisAlignment.start,
              gap: 4,
              children: [
                Text(withAction ? '${kind.name} with action' : kind.name),
                StratumToastPlainLook(
                  notice: _noticeOf(context, kind, withAction: withAction),
                ),
              ],
            ),
      ],
    ),
  ),
);

/// The `setup:` of a story with a trigger: the report line under the stage.
Widget _reportingStage(
  BuildContext context,
  Widget child,
  StoryArgs<Widget> args,
) => _toastStage(reportingSetup(context, child, args));

final $Playground = _Story(
  args: _knobs(),
  setup: _reportingStage,
  builder: _hostOf,
);

final $Variants = _Story(
  args: _fixedKnobs(),
  builder: _frameChild,
  setup: (_, _, _) => _variantsGrid(),
);

final $Responsive = _Story(
  args: _fixedKnobs(),
  builder: _frameChild,
  setup: (_, _, _) => _underRootHost(responsiveFrames(_frame)),
);

final $Accessibility = _Story(
  args: _fixedKnobs(),
  builder: _frameChild,
  setup: (_, _, _) => _underRootHost(accessibilityFrames(build: _frame)),
);

final $ExampleErrorWithAction = _Story(
  name: StoryNames.example('error with action'),
  args: _fixedKnobs(kind: FeedbackState.negative, action: _actions.last),
  setup: _reportingStage,
  builder: _hostOf,
);
