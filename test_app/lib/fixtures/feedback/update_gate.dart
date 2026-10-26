import 'dart:async';

import 'package:stratum_ui/stratum_ui.dart';

/// How long after `Require update in 10 s` taps the fake checker answers
/// `required`, so a screen reader turned on before the swap still meets the
/// page first.
const updateGateFixtureRequireDelay = Duration(seconds: 10);

/// The update answer the fixture's page offers next.
enum _Offer {
  /// The checker answers `upToDate`: the page shows, no gate state does.
  none,

  /// The checker answers `available` at once: the gate opens its dialog.
  available,

  /// The checker answers `required` after [updateGateFixtureRequireDelay]:
  /// the gate replaces the page with its full screen.
  require,
}

/// An [UpdateChecker] the fixture owns: each button picks the next answer;
/// `require` waits [updateGateFixtureRequireDelay] first.
class _FixtureChecker implements UpdateChecker {
  _FixtureChecker(this._delay);

  /// The delay a `require` answer waits.
  final Duration _delay;

  /// The answer the next ask gives.
  _Offer offer = _Offer.none;

  Timer? _requireTimer;

  /// Stops a pending `require` answer, so a mode switch or a dispose leaves
  /// no timer.
  void cancelPending() {
    _requireTimer?.cancel();
    _requireTimer = null;
  }

  @override
  Future<UpdateStatus> check() async {
    switch (offer) {
      // A gate that mounted before either tap: the page shows.
      case _Offer.none:
        return UpdateStatus.upToDate;
      case _Offer.available:
        return UpdateStatus.available;
      case _Offer.require:
        // The completer's future is returned at once; the timer that
        // answers it is the fixture's own, canceled on the next switch or
        // dispose.
        final answer = Completer<UpdateStatus>();
        _requireTimer = Timer(_delay, () {
          _requireTimer = null;
          answer.complete(UpdateStatus.required);
        });
        return answer.future;
    }
  }
}

/// Update-gate fixture: one page the gate can take over (CO-05-09 US-01,
/// US-02).
///
/// A `StratumUpdateGate`, keyed by a generation each button bumps so the
/// gate asks again on the fresh mount, around a `Navigator` whose one page
/// holds text `Gate page`, button `Offer update` (the checker answers
/// `available` at once), and button `Require update in 10 s` (it answers
/// `required` after [updateGateFixtureRequireDelay]). Before either tap the
/// checker answers `upToDate`, so the page shows and no gate state does.
/// `builder` draws `UpdateGateRequired`: text `Update required` (id
/// `update_gate.screen_title`) and text `Install the new version to go on.`;
/// `UpdateGateMaintenance`: text `Under maintenance`; `UpdateGateAvailable`:
/// a card with text `Update available` (id `update_gate.dialog_title`) and
/// button `Later` (runs `dismiss`). The buttons carry no id: a semantics
/// identifier would split a button's label and role from its tap onto two
/// nodes, so a test finds each by its label, one node with both.
class UpdateGateFixture extends StatefulWidget {
  const UpdateGateFixture({super.key});

  @override
  State<UpdateGateFixture> createState() => _UpdateGateFixtureState();
}

class _UpdateGateFixtureState extends State<UpdateGateFixture> {
  // MARK: - Properties

  /// Bumped by each button, so the gate remounts and asks again.
  int _generation = 0;

  late final _FixtureChecker _checker = _FixtureChecker(
    updateGateFixtureRequireDelay,
  );

  // MARK: - Lifecycle

  @override
  void dispose() {
    _checker.cancelPending();
    super.dispose();
  }

  // MARK: - Actions

  void _offer(_Offer offer) {
    // A pending answer of the last mode never lands: the fresh gate's ask
    // owns the answer.
    _checker.cancelPending();
    _checker.offer = offer;
    setState(() => _generation++);
  }

  // MARK: - Build

  @override
  Widget build(BuildContext context) {
    return StratumUpdateGate(
      key: ValueKey(_generation),
      checker: _checker,
      builder: _gate,
      // The gate pushes the dialog on the first Navigator below it, so the
      // fixture's own navigator is the gate's child, not the host page's.
      child: Navigator(
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (context) => ColumnLayout(
            mainAxisAlignment: MainAxisAlignment.center,
            gap: 8,
            children: [
              const Text('Gate page'),
              FilledButton(
                onPressed: () => _offer(_Offer.available),
                child: const Text('Offer update'),
              ),
              FilledButton(
                onPressed: () => _offer(_Offer.require),
                child: const Text('Require update in 10 s'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The app's screens and dialog, as a Developer draws them.
  Widget _gate(BuildContext context, UpdateGateState gate) {
    return switch (gate) {
      UpdateGateRequired() => ColumnLayout(
        mainAxisAlignment: MainAxisAlignment.center,
        gap: 8,
        children: [
          Semantics(
            identifier: 'update_gate.screen_title',
            child: const Text('Update required'),
          ),
          const Text('Install the new version to go on.'),
        ],
      ),
      UpdateGateMaintenance() => const ColumnLayout(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [Text('Under maintenance')],
      ),
      UpdateGateAvailable(:final dismiss) => Center(
        child: ContainerLayout(
          style: WidgetStyle(
            width: 280,
            padding: const EdgeInsets.all(16),
            backgroundColor: Theme.of(context).colorScheme.surface,
          ),
          child: ColumnLayout(
            mainAxisSize: MainAxisSize.min,
            gap: 8,
            children: [
              Semantics(
                identifier: 'update_gate.dialog_title',
                child: const Text('Update available'),
              ),
              FilledButton(onPressed: dismiss, child: const Text('Later')),
            ],
          ),
        ),
      ),
    };
  }
}
