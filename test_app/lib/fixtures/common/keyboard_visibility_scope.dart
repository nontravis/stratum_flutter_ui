import 'package:stratum_ui/stratum_ui.dart';

/// Fixture for what a `KeyboardVisibilityScope` reads next to the raw bottom
/// view inset (FO-07 US-04 FR-02 E04, E07).
///
/// Button `Close keyboard` drops the field focus, then text `keyboard: open`
/// or `keyboard: closed` (id `keyboard_visibility_scope.state`) from
/// `KeyboardVisibilityScope.of`, then text `inset: <n>` (id
/// `keyboard_visibility_scope.inset`), the raw bottom view inset in physical
/// pixels rounded, read from `View.of` — never a `MediaQuery` the fixture
/// page's `Scaffold` already consumed — and refreshed on metric changes. The
/// button and both texts sit above the field `Type here`, so a keyboard never
/// covers them.
class KeyboardVisibilityScopeFixture extends StatefulWidget {
  const KeyboardVisibilityScopeFixture({super.key});

  @override
  State<KeyboardVisibilityScopeFixture> createState() =>
      _KeyboardVisibilityScopeFixtureState();
}

class _KeyboardVisibilityScopeFixtureState
    extends State<KeyboardVisibilityScopeFixture>
    with WidgetsBindingObserver {
  // MARK: - Lifecycle

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    setState(() {});
  }

  // MARK: - Build

  @override
  Widget build(BuildContext context) {
    final inset = View.of(context).viewInsets.bottom.round();
    final keyboardOpen = KeyboardVisibilityScope.of(context);
    return ColumnLayout(
      mainAxisAlignment: MainAxisAlignment.center,
      gap: 8,
      children: [
        FilledButton(
          onPressed: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: const Text('Close keyboard'),
        ),
        Semantics(
          identifier: 'keyboard_visibility_scope.state',
          child: Text(keyboardOpen ? 'keyboard: open' : 'keyboard: closed'),
        ),
        Semantics(
          identifier: 'keyboard_visibility_scope.inset',
          child: Text('inset: $inset'),
        ),
        const TextField(decoration: InputDecoration(labelText: 'Type here')),
      ],
    );
  }
}
