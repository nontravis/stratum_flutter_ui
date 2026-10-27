import 'package:stratum_ui/stratum_ui.dart';

/// Notice fixture for the keyboard shortcut that moves focus into a notice
/// and for Esc returning it (CO-05.07 US-01 FR-05 and FR-04).
///
/// Text field `Note`, a line `Echo: <text>` that shows the field's text as the
/// framework holds it, and button `Show notice`; the button shows the notice
/// `Note saved` with its action `Undo`, which does nothing but close it. The
/// echo lets a browser test prove that the framework reads typed text, since
/// the browser's own input element can hold text the framework never saw. It
/// sits in the top left corner as its own semantics node, so it covers neither
/// the field nor the label `Note`. The fixture sits under its own
/// `StratumToastHost` with the default shortcuts, because the test app's
/// `MaterialApp` has none. Each control is one node found by its label, as
/// `Note`, `Show notice`, and `Undo`.
class ToastShortcutFixture extends StatefulWidget {
  const ToastShortcutFixture({super.key});

  @override
  State<ToastShortcutFixture> createState() => _ToastShortcutFixtureState();
}

class _ToastShortcutFixtureState extends State<ToastShortcutFixture> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StratumToastHost(
      child: StackLayout(
        fit: StackFit.expand,
        children: [
          ColumnLayout(
            mainAxisAlignment: MainAxisAlignment.center,
            gap: 8,
            children: [
              TextField(
                controller: _controller,
                decoration: const InputDecoration(labelText: 'Note'),
              ),
              Builder(
                builder: (context) => FilledButton(
                  onPressed: () => context.showToast(
                    message: 'Note saved',
                    action: StratumToastAction(label: 'Undo', onPressed: () {}),
                  ),
                  child: const Text('Show notice'),
                ),
              ),
            ],
          ),
          Positioned(
            top: 0,
            left: 0,
            child: ListenableBuilder(
              listenable: _controller,
              builder: (context, _) => Semantics(
                container: true,
                child: Text('Echo: ${_controller.text}'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
