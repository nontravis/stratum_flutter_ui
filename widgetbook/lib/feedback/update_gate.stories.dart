import 'package:stratum_ui/stratum_ui.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

import '../kit/docs/catalog_docs.dart';
import '../kit/docs/stratum_docs.dart';
import '../kit/preset.dart';
import '../kit/sample_text.dart';
import '../kit/slot_preset.dart';
import '../kit/story_set.dart';
import '../shell/catalog_section.dart';
import 'update_gate_knobs.dart';

part 'update_gate.stories.g.dart';

/// The `builder` param's signature, which the package does not typedef; it
/// exists only here (RL from main: never in the package).
typedef UpdateGateBuilder = Widget Function(BuildContext, UpdateGateState);

/// The slot names the gate's stand-in screens carry (US-03 FR-03).
const _forceUpdateScreen = 'force update screen';
const _maintenanceScreen = 'maintenance screen';
const _updateDialog = 'update dialog';
const _appSlot = 'app';

const _docs = CatalogDocs(
  figma: null,
  usage: '''
MaterialApp(
  builder: (context, child) => StratumUpdateGate(
    checker: MyUpdateChecker(),
    builder: (context, gate) => switch (gate) {
      UpdateGateRequired() => MyForceUpdateScreen(),
      UpdateGateMaintenance(:final retry) =>
          MyMaintenanceScreen(onRetry: retry),
      UpdateGateAvailable(:final dismiss) =>
          MyUpdateDialog(onLater: dismiss),
    },
    child: child!,
  ),
  home: MyHomePage(),
)''',
  dos: [
    'Place it in `MaterialApp.builder`, around the navigator, so it covers '
        'every route.',
    'Give the checker its own time limit; the gate sets none.',
  ],
  donts: [
    'Build the screens inside the gate; the app owns them and passes them '
        'through builder.',
    'Lock the app on a failed check; the gate shows the child instead.',
  ],
  accessibility: [
    'The gate draws nothing; each app screen carries its own semantics.',
    'A screen change is announced and focus moves into the screen, staying '
        'inside on Tab.',
    'The dialog maps Esc and the Android back button to dismiss.',
  ],
);

/// An [UpdateChecker] whose every ask answers [status].
final class _StaticChecker implements UpdateChecker {
  const _StaticChecker(this.status);

  final UpdateStatus status;

  @override
  Future<UpdateStatus> check() async => status;
}

/// One checker preset per [UpdateStatus] value (fo11/us04/fr01).
final _checkers = <Preset<UpdateChecker>>[
  for (final status in UpdateStatus.values)
    Preset(status.name, (context) => _StaticChecker(status)),
];

/// The app's own screens, stood in as slots (US-03 FR-03; s01 "Slot
/// stand-ins"): the content a caller passes in, so a slot stands in.
Widget _slotScreens(BuildContext context, UpdateGateState gate) =>
    switch (gate) {
      UpdateGateRequired() => const StratumSlot(name: _forceUpdateScreen),
      UpdateGateMaintenance() => const StratumSlot(name: _maintenanceScreen),
      UpdateGateAvailable() => const StratumSlot(name: _updateDialog),
    };

final _builders = <Preset<UpdateGateBuilder>>[
  Preset('Slots', (context) => _slotScreens),
];

const meta = Meta(StratumUpdateGate.new, argsType: UpdateGateKnobs.new);

final componentMeta = ComponentMeta(
  name: 'Update gate',
  path: CatalogSection.feedback.label,
  docsBuilder: stratumDocs(
    _docs,
    args: [for (final arg in $Playground.args.list) ?arg],
  ),
);

/// The gate's child navigator: one page that shows the `child` knob's slot,
/// so the app the gate covers stands in too.
Navigator _app(SlotPreset child) => Navigator(
  onGenerateRoute: (settings) => PageRouteBuilder<void>(
    pageBuilder: (context, _, _) => Material(
      child: Center(
        child:
            slotFor(context, child, name: _appSlot, text: SampleTexts.label) ??
            const SizedBox.shrink(),
      ),
    ),
  ),
);

/// The whole gate, checker, builder, and child slot preset as passed.
StratumUpdateGate _gateOf(
  BuildContext context,
  UpdateChecker checker,
  UpdateGateBuilder builder,
  SlotPreset child,
) => StratumUpdateGate(checker: checker, builder: builder, child: _app(child));

/// A fresh set of knobs: one per constructor param, in constructor order.
UpdateGateKnobsArgs _knobs() => UpdateGateKnobsArgs(
  checker: PresetArg(_checkers.first, name: 'checker', values: _checkers),
  builder: PresetArg(_builders.first, name: 'builder', values: _builders),
  child: EnumArg<SlotPreset>(
    SlotPreset.slot,
    name: 'child',
    values: SlotPreset.values,
  ),
);

/// Knobs for a story that has no Playground: fixed, so the panel hides them.
UpdateGateKnobsArgs _fixedKnobs() => UpdateGateKnobsArgs.fixed(
  checker: _checkers.first,
  builder: _builders.first,
  child: SlotPreset.slot,
);

/// The page widget Widgetbook's builder must return; the frame stories show
/// their own layout through `setup`, which drops this child.
StratumUpdateGate _frameChild(BuildContext context, UpdateGateKnobsArgs args) =>
    _gateOf(
      context,
      _checkers.first.valueOf(context),
      _builders.first.valueOf(context),
      args.child,
    );

/// [gate] in a box of fixed height: the gate fills the space its parent
/// gives it, which a scrolling frame list leaves unbounded.
Widget _boxed(Widget gate) =>
    ContainerLayout(style: const WidgetStyle(height: 240), child: gate);

/// One frame per [UpdateStatus], each labelled by its status name.
Widget _variantsGrid() => Builder(
  builder: (context) => ColumnLayout(
    scroll: const Scroll(),
    crossAxisAlignment: CrossAxisAlignment.start,
    gap: 16,
    children: [
      for (final preset in _checkers)
        ColumnLayout(
          crossAxisAlignment: CrossAxisAlignment.start,
          gap: 4,
          children: [
            Text(preset.name),
            _boxed(
              _gateOf(
                context,
                preset.valueOf(context),
                _builders.first.valueOf(context),
                SlotPreset.slot,
              ),
            ),
          ],
        ),
    ],
  ),
);

final $Playground = _Story(
  args: _knobs(),
  builder: (context, args) => _gateOf(
    context,
    args.checker.valueOf(context),
    args.builder.valueOf(context),
    args.child,
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
  setup: (_, _, _) => responsiveFrames(
    (context) => _gateOf(
      context,
      _checkers.first.valueOf(context),
      _builders.first.valueOf(context),
      SlotPreset.slot,
    ),
  ),
);

final $Accessibility = _Story(
  args: _fixedKnobs(),
  builder: _frameChild,
  setup: (_, _, _) => accessibilityFrames(
    build: (context) => _boxed(
      _gateOf(
        context,
        _checkers.first.valueOf(context),
        _builders.first.valueOf(context),
        SlotPreset.slot,
      ),
    ),
  ),
);

final $ExampleAvailableDialog = _Story(
  name: StoryNames.example('available dialog'),
  args: UpdateGateKnobsArgs.fixed(
    checker: _checkers[UpdateStatus.available.index],
    builder: _builders.first,
    child: SlotPreset.slot,
  ),
  builder: (context, args) => _gateOf(
    context,
    _checkers[UpdateStatus.available.index].valueOf(context),
    _builders.first.valueOf(context),
    args.child,
  ),
);
