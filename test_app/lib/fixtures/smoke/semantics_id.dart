import 'package:stratum_ui/stratum_ui.dart';

/// Smoke fixture proving the semantics-identifier contract e2e tests rely on.
///
/// Button `Smoke button` (id `smoke.button`), text `taps: <n>` (id `smoke.taps`).
class SmokeSemanticsIdFixture extends StatefulWidget {
  const SmokeSemanticsIdFixture({super.key});

  @override
  State<SmokeSemanticsIdFixture> createState() =>
      _SmokeSemanticsIdFixtureState();
}

class _SmokeSemanticsIdFixtureState extends State<SmokeSemanticsIdFixture> {
  var _taps = 0;

  @override
  Widget build(BuildContext context) {
    return ColumnLayout(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Semantics(
          identifier: 'smoke.button',
          button: true,
          child: FilledButton(
            onPressed: () => setState(() => _taps++),
            child: const Text('Smoke button'),
          ),
        ),
        Semantics(identifier: 'smoke.taps', child: Text('taps: $_taps')),
      ],
    );
  }
}
