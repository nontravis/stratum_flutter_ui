import 'package:stratum_ui/stratum_ui.dart';

/// Notice fixture for the keyboard shortcut that moves focus into a notice
/// and for Esc returning it (CO-05.07 US-01 FR-05 and FR-04).
///
/// Text field `Note` and button `Show notice`; the button shows the notice
/// `Note saved` with its action `Undo`, which does nothing but close it. The
/// fixture sits under its own `StratumToastHost` with the default shortcuts,
/// because the test app's `MaterialApp` has none. Each control is one node
/// found by its label, as `Note`, `Show notice`, and `Undo`.
class ToastShortcutFixture extends StatelessWidget {
  const ToastShortcutFixture({super.key});

  @override
  Widget build(BuildContext context) {
    return StratumToastHost(
      child: ColumnLayout(
        mainAxisAlignment: MainAxisAlignment.center,
        gap: 8,
        children: [
          const TextField(decoration: InputDecoration(labelText: 'Note')),
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
    );
  }
}
