// A page for checking keyboard focus by hand on Chrome and macOS:
//
//   flutter run -d chrome -t lib/focus_demo.dart
//   flutter run -d macos -t lib/focus_demo.dart
import 'package:stratum_ui/stratum_ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(FocusDemoApp(themes: await loadFocusDemoTheme()));
}

/// The package default theme, read from the stratum_ui package assets.
Future<StratumThemeSet> loadFocusDemoTheme() async {
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

class FocusDemoApp extends StatelessWidget {
  const FocusDemoApp({super.key, required this.themes});

  final StratumThemeSet themes;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stratum focus demo',
      builder: (context, child) => StratumThemeApplication(
        themes: themes,
        themeMode: ThemeMode.light,
        child: child!,
      ),
      home: const _FocusDemoPage(),
    );
  }
}

class _FocusDemoPage extends StatefulWidget {
  const _FocusDemoPage();

  @override
  State<_FocusDemoPage> createState() => _FocusDemoPageState();
}

class _FocusDemoPageState extends State<_FocusDemoPage> {
  final _status = ValueNotifier('Press Tab to start.');
  var _boxDisabled = false;

  @override
  void dispose() {
    _status.dispose();
    super.dispose();
  }

  void _report(String message) => _status.value = message;

  void _toggleBox() {
    setState(() => _boxDisabled = !_boxDisabled);
    _report(_boxDisabled ? 'Box disabled.' : 'Box enabled.');
  }

  Widget _groupRow(String name) {
    return RowLayout(
      mainAxisSize: MainAxisSize.min,
      gap: 8,
      focusGroup: const StratumFocusGroup(),
      children: [
        for (var i = 1; i <= 5; i++)
          ContainerLayout(
            style: const WidgetStyle(
              width: 64,
              height: 48,
              alignment: Alignment.center,
              backgroundColor: Color(0xFFE3E8F4),
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            interaction: StratumInteraction(
              onTap: () => _report('$name: item $i activated.'),
            ),
            child: Text('$i'),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Keyboard focus demo')),
      bottomNavigationBar: Material(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ValueListenableBuilder(
            valueListenable: _status,
            builder: (context, status, _) => Text(status),
          ),
        ),
      ),
      body: ColumnLayout(
        style: const WidgetStyle(padding: EdgeInsets.all(24)),
        scroll: const StratumScroll(),
        crossAxisAlignment: CrossAxisAlignment.start,
        gap: 16,
        children: [
          const Text(
            '1. Focus group. Tab into the row; the page itself is the stop '
            'before it. The row is one Tab stop: Left and Right move, Home '
            'and End jump to the ends, Enter activates, and Tab leaves it.',
          ),
          _groupRow('First row'),
          const SizedBox(
            height: 1600,
            child: Align(
              alignment: Alignment.topLeft,
              child: Text('Filler. Keep scrolling, or press Page Down.'),
            ),
          ),
          const Text(
            '2. Reveal past the viewport. Tab into the row below, then '
            'press Page Up until the row drops below the window, and '
            'press Right or End: the page scrolls the row back into view. '
            'Then press Page Down until the row leaves the top of the '
            'window, and press Left or Home: same.',
          ),
          _groupRow('Second row'),
          const SizedBox(height: 600),
          const Text(
            '3. Focus handoff. Tab to the box below; its ring shows. Press D '
            'or click the switch with the mouse to disable it: the ring '
            'stays on the box, and Down still scrolls it. Press D again: '
            'focus stays on the box, and Enter reports a tap.',
          ),
          CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.keyD): _toggleBox,
            },
            child: ColumnLayout(
              style: const WidgetStyle(
                width: 320,
                height: 200,
                padding: EdgeInsets.all(12),
                backgroundColor: Color(0xFFF1F3F8),
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              interaction: StratumInteraction(
                onTap: () => _report('Box tapped.'),
                disabled: _boxDisabled,
              ),
              scroll: const StratumScroll(),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [for (var i = 1; i <= 30; i++) Text('Box line $i')],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch(value: _boxDisabled, onChanged: (_) => _toggleBox()),
              const SizedBox(width: 8),
              const Text('Box disabled'),
            ],
          ),
          const Text(
            '4. Text field. Arrows, Home, and End edit the text and move '
            'neither the page nor a group.',
          ),
          const SizedBox(
            width: 320,
            child: TextField(
              decoration: InputDecoration(labelText: 'Type here'),
            ),
          ),
          const SizedBox(height: 400),
        ],
      ),
    );
  }
}
