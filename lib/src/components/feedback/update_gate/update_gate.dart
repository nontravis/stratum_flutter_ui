import 'package:stratum_ui/src/src.dart';

/// Puts the app's own update and maintenance screens in place of the app,
/// by the answers of the app's [UpdateChecker] (CO-05-09).
///
/// Place it in `MaterialApp.builder`, below `StratumThemeApplication`,
/// around the navigator, so it covers every route. It draws nothing:
/// [builder] returns the app's screen for each [UpdateGateState]. It
/// shows [child] while the first answer is pending, when the app is up
/// to date, and after a failed check.
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
  /// [UpdateGateMaintenance], which replace [child].
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

  AppLifecycleState? _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = WidgetsBinding.instance.lifecycleState;
    WidgetsBinding.instance.addObserver(this);
    unawaited(_ask(recheck: false));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final returned =
        state == AppLifecycleState.resumed &&
        _lifecycle != AppLifecycleState.resumed;
    _lifecycle = state;
    if (returned) unawaited(_ask(recheck: true));
  }

  void _retry() => unawaited(_ask(recheck: true));

  /// Asks the checker unless an ask runs; [recheck] marks an ask on a
  /// return to the foreground or a retry, which sets `checking`.
  Future<void> _ask({required bool recheck}) async {
    if (_asking) return;
    _asking = true;
    if (recheck) setState(() => _checking = true);
    UpdateStatus? answer;
    try {
      answer = await widget.checker.check();
    } on Object {
      answer = null;
    }
    _asking = false;
    if (!mounted) return;
    setState(() {
      _checking = false;
      _answer = answer;
    });
  }

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
