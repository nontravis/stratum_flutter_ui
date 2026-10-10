import 'package:stratum_ui/src/src.dart';

/// Puts the app's own update and maintenance screens in place of the app,
/// or the app's own update dialog over it, by the answers of the app's
/// [UpdateChecker] (CO-05-09).
///
/// Place it in `MaterialApp.builder`, below `StratumThemeApplication`,
/// around the navigator, so it covers every route. It draws nothing:
/// [builder] returns the app's screen or dialog for each
/// [UpdateGateState]. It shows [child] while the first answer is pending,
/// when the app is up to date, and after a failed check.
class StratumUpdateGate extends StatefulWidget {
  const new({
    super.key,
    required this.checker,
    required this.builder,
    required this.child,
  });

  /// The app's update check, asked when the gate mounts, on each return
  /// to the foreground, and on [UpdateGateMaintenance.retry], one ask at a
  /// time.
  final UpdateChecker checker;

  /// Returns the app's screen for [UpdateGateRequired] and
  /// [UpdateGateMaintenance], which replace [child], and the app's dialog,
  /// scrim and card included, for [UpdateGateAvailable], which opens once
  /// per gate lifetime as a route on the navigator in [child].
  final Widget Function(BuildContext context, UpdateGateState gate) builder;

  /// The app's navigator.
  final Widget child;

  @override
  State<StratumUpdateGate> createState() => _StratumUpdateGateState();
}

class _StratumUpdateGateState extends State<StratumUpdateGate>
    with WidgetsBindingObserver {
  /// The last answer; null before the first answer and after a failure.
  UpdateStatus? _answer;

  /// Whether an ask runs.
  bool _asking = false;

  /// Whether an ask started on a return to the foreground or a retry runs.
  bool _checking = false;

  /// Whether the dialog has opened in this gate's lifetime.
  bool _dialogShown = false;

  /// The dialog's route while it is on the navigator.
  Route<void>? _dialog;

  /// The `checking` the dialog's page builds from.
  final ValueNotifier<bool> _dialogChecking = ValueNotifier(false);

  /// Whether the app left the foreground on `hidden` or `paused`;
  /// cleared after the next re-ask. `inactive` alone (a Face ID prompt,
  /// Control Center, a permission dialog) and a cold start's own first
  /// `resumed` never set it, so neither re-asks (R8).
  bool _backgrounded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_ask(recheck: false));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dialogChecking.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _backgrounded = true;
    } else if (state == AppLifecycleState.resumed && _backgrounded) {
      _backgrounded = false;
      unawaited(_ask(recheck: true));
    }
  }

  void _retry() => unawaited(_ask(recheck: true));

  /// Asks the checker unless an ask runs; [recheck] marks an ask on a
  /// return to the foreground or a retry, which sets `checking`.
  Future<void> _ask({required bool recheck}) async {
    if (_asking) return;
    _asking = true;
    if (recheck) {
      setState(() => _checking = true);
      _dialogChecking.value = true;
    }
    UpdateStatus? answer;
    try {
      answer = await widget.checker.check();
    } on Object {
      answer = null;
    }
    _asking = false;
    if (!mounted) return;
    _dialogChecking.value = false;
    if (answer != UpdateStatus.available) _dismiss();
    if (answer == UpdateStatus.available && !_dialogShown) {
      _dialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _openDialog());
    }
    setState(() {
      _checking = false;
      _answer = answer;
    });
  }

  /// Pushes the dialog's route on the navigator below the gate, after the
  /// frame that shows [StratumUpdateGate.child].
  void _openDialog() {
    if (!mounted || _answer != UpdateStatus.available) return;
    final navigator = _navigator();
    assert(
      navigator != null,
      'StratumUpdateGate found no Navigator below it: place it in '
      'MaterialApp.builder, around the navigator.',
    );
    if (navigator == null) return;
    final dialog = RawDialogRoute<void>(
      pageBuilder: (context, _, _) => _dialogPage(),
      barrierDismissible: false,
      barrierColor: null,
      transitionDuration: Duration.zero,
      traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
    );
    _dialog = dialog;
    unawaited(navigator.push(dialog).whenComplete(_dismiss));
  }

  /// The first navigator below the gate: the app's, when the gate sits in
  /// `MaterialApp.builder`.
  NavigatorState? _navigator() {
    NavigatorState? found;
    void visit(Element element) {
      if (found != null) return;
      if (element case StatefulElement(:final NavigatorState state)) {
        found = state;
        return;
      }
      element.visitChildren(visit);
    }

    context.visitChildElements(visit);
    return found;
  }

  /// Closes the dialog. A pop of its route by Android back calls it after
  /// the route left the navigator; Esc and the app's control call it while
  /// the route is there, and it removes that route alone.
  void _dismiss() {
    final dialog = _dialog;
    if (dialog == null) return;
    _dialog = null;
    if (dialog.isActive) dialog.navigator?.removeRoute(dialog);
  }

  /// The dialog's page: the app's dialog, with Esc mapped to `dismiss`,
  /// since the route's own Esc action is off for a barrier that does not
  /// dismiss; a [FocusScope] registers autofocus for the app's own
  /// control inside, so its choice of first focus wins over the gate's,
  /// and with none, focus sits on the scope itself, still inside the Esc
  /// mapping.
  Widget _dialogPage() => Shortcuts(
    shortcuts: const <ShortcutActivator, Intent>{
      SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
    },
    child: Actions(
      actions: <Type, Action<Intent>>{
        DismissIntent: CallbackAction<DismissIntent>(
          onInvoke: (_) {
            _dismiss();
            return null;
          },
        ),
      },
      child: FocusScope(
        autofocus: true,
        child: ValueListenableBuilder<bool>(
          valueListenable: _dialogChecking,
          builder: (context, checking, _) => widget.builder(
            context,
            UpdateGateAvailable(dismiss: _dismiss, checking: checking),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => switch (_answer) {
    UpdateStatus.required => _screen(UpdateGateRequired(checking: _checking)),
    UpdateStatus.maintenance => _screen(
      UpdateGateMaintenance(retry: _retry, checking: _checking),
    ),
    _ => widget.child,
  };

  Widget _screen(UpdateGateState gate) => _GateScope(
    key: ValueKey(gate.runtimeType),
    child: _GateOverlay(gate: gate, builder: widget.builder),
  );
}

/// A route scope of the gate's own: a screen reader announces the change,
/// and focus moves in after the first frame and stays inside on Tab.
class _GateScope extends StatefulWidget {
  const new({super.key, required this.child});

  final Widget child;

  @override
  State<_GateScope> createState() => _GateScopeState();
}

class _GateScopeState extends State<_GateScope> {
  final FocusScopeNode _node = FocusScopeNode(debugLabel: 'StratumUpdateGate');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _node.requestFocus();
    });
  }

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    scopesRoute: true,
    explicitChildNodes: true,
    child: FocusScope(node: _node, child: widget.child),
  );
}

/// Builds [gate] through the app's [builder] in an [Overlay] of the
/// gate's own, so a tooltip or a text field works above the navigator.
class _GateOverlay extends StatefulWidget {
  const new({required this.gate, required this.builder});

  final UpdateGateState gate;
  final Widget Function(BuildContext context, UpdateGateState gate) builder;

  @override
  State<_GateOverlay> createState() => _GateOverlayState();
}

class _GateOverlayState extends State<_GateOverlay> {
  late final OverlayEntry _entry = OverlayEntry(
    builder: (context) => widget.builder(context, widget.gate),
  );

  @override
  void didUpdateWidget(_GateOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _entry.markNeedsBuild();
  }

  @override
  void dispose() {
    _entry
      ..remove()
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Overlay(initialEntries: [_entry]);
}
