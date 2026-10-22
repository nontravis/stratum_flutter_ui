import 'package:stratum_ui/stratum_ui.dart';

/// Shortcut-bearing button fixture for the menu key and the screen-reader
/// menu action of a `StratumInkWell` (FO-06 US-05 FR-01).
///
/// Button `Menu target` (id `ink_well.button`) takes a tap and a secondary
/// tap, which the menu key, Shift+F10, and the custom semantics action
/// `Show menu` (the built-in label) all run. The id sits on the focusable,
/// tappable node; its parent node holds the button role and the menu action.
/// Text `Log: nothing yet.`, then `Log: tapped` or `Log: menu` for the last
/// one (id `ink_well.log`).
class InkWellFixture extends StatefulWidget {
  const InkWellFixture({super.key});

  @override
  State<InkWellFixture> createState() => _InkWellFixtureState();
}

class _InkWellFixtureState extends State<InkWellFixture> {
  // MARK: - Properties

  /// What the button did last, or null before it did anything.
  String? _last;

  // MARK: - Build

  @override
  Widget build(BuildContext context) {
    return ColumnLayout(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        StratumInkWell(
          semantics: const SemanticsProperties(identifier: 'ink_well.button'),
          onTap: () => setState(() => _last = 'tapped'),
          onSecondaryTap: () => setState(() => _last = 'menu'),
          child: const ContainerLayout(
            style: WidgetStyle(
              height: 48,
              padding: EdgeInsetsDirectional.symmetric(horizontal: 12),
              alignment: AlignmentDirectional.centerStart,
            ),
            child: Text('Menu target'),
          ),
        ),
        Semantics(
          identifier: 'ink_well.log',
          child: Text(_last == null ? 'Log: nothing yet.' : 'Log: $_last'),
        ),
      ],
    );
  }
}
