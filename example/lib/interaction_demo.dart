// A page for checking HoverBuilder, FocusBuilder, and ContainerLayout.builder
// by hand with a mouse, a keyboard, and a screen reader:
//
//   flutter run -d chrome -t lib/interaction_demo.dart
//   flutter run -d macos -t lib/interaction_demo.dart
import 'dart:async';

import 'package:stratum_ui/stratum_ui.dart';
import 'package:stratum_ui_example/font_licenses.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerGoogleFontLicenses();
  runApp(InteractionDemoApp(themes: await loadInteractionDemoTheme()));
}

/// The package default theme, read from the stratum_ui package assets.
Future<StratumThemeSet> loadInteractionDemoTheme() async {
  final text = await rootBundle.loadString(
    'packages/stratum_ui/assets/themes/default/theme.yaml',
  );
  return StratumThemeSet.fromConfig(
    StratumThemeConfig.parse(
      base: StratumThemeSource(
        id: 'stratum-default',
        folder: 'packages/stratum_ui/assets/themes/default',
        yaml: text,
      ),
    ),
  );
}

/// How long a toggle waits after its press, so the pointer can come to rest
/// on the card before the flip (US-12 FR-01 E03).
const toggleDelay = Duration(seconds: 3);

/// [name] and the words of [state]'s true values, else 'Idle': every state
/// reads as text, never by color alone (US-12 FR-01 E02).
String stateText(String name, InteractionState state) {
  final words = [
    if (state.hovered) 'Hovered',
    if (state.pressed) 'Pressed',
    if (state.focused) 'Focused',
    if (state.disabled) 'Disabled',
  ];
  return '$name: ${words.isEmpty ? 'Idle' : words.join(', ')}';
}

const _cardStyle = WidgetStyle(
  width: 220,
  height: 64,
  padding: EdgeInsets.all(12),
  alignment: Alignment.centerLeft,
  backgroundColor: Color(0xFFE3E8F4),
  borderRadius: BorderRadius.all(Radius.circular(12)),
);

class InteractionDemoApp extends StatelessWidget {
  const InteractionDemoApp({super.key, required this.themes});

  final StratumThemeSet themes;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stratum hover and focus demo',
      builder: (context, child) => StratumThemeApplication(
        themes: themes,
        themeMode: ThemeMode.light,
        child: child!,
      ),
      home: const _InteractionDemoPage(),
    );
  }
}

/// A section that disables everything inside it, as a disabled component
/// does.
class _Section extends StratumStatelessWidget {
  const _Section({super.disabled, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

class _InteractionDemoPage extends StatefulWidget {
  const _InteractionDemoPage();

  @override
  State<_InteractionDemoPage> createState() => _InteractionDemoPageState();
}

class _InteractionDemoPageState extends State<_InteractionDemoPage> {
  final _log = ValueNotifier<List<String>>(const []);
  final _timers = <Timer>[];
  var _cardDisabled = false;
  var _sectionDisabled = false;

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _log.dispose();
    super.dispose();
  }

  void _record(String call) {
    final calls = [..._log.value, call];
    _log.value = calls.length > 6 ? calls.sublist(calls.length - 6) : calls;
  }

  void _toggleLater(VoidCallback flip) {
    _timers.add(
      Timer(toggleDelay, () {
        if (mounted) setState(flip);
      }),
    );
  }

  Widget _stateCard(
    String name, {
    required FocusType focusType,
    bool disabled = false,
  }) {
    return ContainerLayout(
      style: _cardStyle,
      interaction: Interaction(
        onTap: () => _record('$name tapped'),
        onHover: (hovered) => _record('$name onHover($hovered)'),
        focusType: focusType,
        disabled: disabled,
      ),
      builder: (context, state) => Text(stateText(name, state)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hover and focus demo')),
      bottomNavigationBar: Material(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ValueListenableBuilder(
            valueListenable: _log,
            builder: (context, calls, _) => Text(
              calls.isEmpty ? 'Log: nothing yet.' : 'Log: ${calls.join('; ')}',
            ),
          ),
        ),
      ),
      body: ColumnLayout(
        style: const WidgetStyle(padding: EdgeInsets.all(24)),
        scroll: const Scroll(),
        crossAxisAlignment: CrossAxisAlignment.start,
        gap: 16,
        children: [
          const Text(
            '1. Hover. Move the mouse onto the card and off it: it reads '
            '"Hovered", then "Not hovered", and the log shows onHover(true) '
            'and onHover(false). Rest the mouse on a row of the list below '
            'and scroll with the wheel or the trackpad: the row under the '
            'pointer reads "hovered". On touch screens nothing hovers.',
          ),
          HoverBuilder(
            onHover: (hovered) => _record('Hover card onHover($hovered)'),
            builder: (context, hovered, child) => ContainerLayout(
              style: _cardStyle,
              child: Text(hovered ? 'Hovered' : 'Not hovered'),
            ),
          ),
          ColumnLayout(
            style: const WidgetStyle(width: 220, height: 160),
            scroll: const Scroll(),
            children: [
              for (var i = 1; i <= 12; i++)
                HoverBuilder(
                  builder: (context, hovered, child) => ContainerLayout(
                    style: const WidgetStyle(
                      height: 40,
                      alignment: Alignment.centerLeft,
                    ),
                    child: Text(hovered ? 'Row $i, hovered' : 'Row $i'),
                  ),
                ),
            ],
          ),
          const Text(
            '2. Cards built from their state. Hover, press and hold, Tab '
            'to, and click each card: its text names every state it is in. '
            'Card A reads "Focused", with its ring, after Tab but not after '
            'a click; card B shows its ring on any focus, so a click makes '
            'it read "Focused" too. A screen reader reads each card as a '
            'button.',
          ),
          _Section(
            disabled: _sectionDisabled,
            child: RowLayout(
              mainAxisSize: MainAxisSize.min,
              gap: 16,
              children: [
                _stateCard(
                  'Card A',
                  focusType: FocusType.focusedVisible,
                  disabled: _cardDisabled,
                ),
                _stateCard('Card B', focusType: FocusType.focused),
              ],
            ),
          ),
          const Text(
            '3. Disabled under a still mouse. Press a button below, then '
            'rest the mouse on card A within 3 s and keep it still: when it '
            'turns disabled it reads "Disabled" and the log shows '
            'onHover(false) once. Press the same button again and rest on '
            'card A: when it turns enabled it reads "Hovered" and the log '
            'shows onHover(true) once. The section button disables both '
            'cards, as a disabled component does.',
          ),
          RowLayout(
            mainAxisSize: MainAxisSize.min,
            gap: 8,
            children: [
              OutlinedButton(
                onPressed: () =>
                    _toggleLater(() => _cardDisabled = !_cardDisabled),
                child: const Text('Toggle card A in 3 s'),
              ),
              OutlinedButton(
                onPressed: () =>
                    _toggleLater(() => _sectionDisabled = !_sectionDisabled),
                child: const Text('Toggle the section in 3 s'),
              ),
            ],
          ),
          const Text(
            '4. Focus inside a group. Click the street field: the group '
            'reads "Group: focus inside" and the log shows '
            'onFocusChange(true). Press Tab to the city field: nothing '
            'changes and the log adds nothing. Press Tab again to leave: the '
            'group reads "Group: no focus" and the log shows '
            'onFocusChange(false). The group adds no Tab stop of its own. A '
            'screen reader reads "ที่อยู่จัดส่ง" before the street field.',
          ),
          FocusBuilder(
            semantics: const SemanticsProperties(label: 'ที่อยู่จัดส่ง'),
            onFocusChange: (focused) =>
                _record('Group onFocusChange($focused)'),
            builder: (context, focused, child) => ColumnLayout(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              gap: 8,
              children: [
                // Its own semantics node, so it joins, rather than merges
                // into, the group label above (the `ถนน` field precedent
                // of focus_builder_test.dart's us16/s7).
                Semantics(
                  container: true,
                  child: Text(
                    focused ? 'Group: focus inside' : 'Group: no focus',
                  ),
                ),
                child!,
              ],
            ),
            child: const ColumnLayout(
              mainAxisSize: MainAxisSize.min,
              gap: 8,
              children: [
                SizedBox(
                  width: 280,
                  child: TextField(
                    decoration: InputDecoration(labelText: 'ถนน'),
                  ),
                ),
                SizedBox(
                  width: 280,
                  child: TextField(
                    decoration: InputDecoration(labelText: 'เมือง'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(
            width: 280,
            child: TextField(
              decoration: InputDecoration(labelText: 'Next field'),
            ),
          ),
          const SizedBox(height: 400),
        ],
      ),
    );
  }
}
