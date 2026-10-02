// A page for checking typography by hand on Chrome and macOS, above all
// Thai stacked marks at text scales of 100%, 150%, and 200%:
//
//   flutter run -d chrome -t lib/typography_demo.dart
//   flutter run -d macos -t lib/typography_demo.dart
//
// ignore_for_file: implementation_imports
import 'package:stratum_ui/src/src.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(TypographyDemoApp(theme: await loadDemoTheme()));
}

/// The default theme's typography, read from the stratum_ui package assets.
Future<StratumThemeData> loadDemoTheme() async {
  final text = await rootBundle.loadString(
    'packages/stratum_ui/assets/themes/default/theme.yaml',
  );
  final document = loadYaml(text) as YamlMap;
  return _DemoTheme(
    StratumTypography.fromYaml(document['typography'] as YamlMap),
  );
}

/// The smallest theme the text styles read: the typography and the primary
/// text color. Any other member throws, as the test theme does.
class _DemoTheme implements StratumThemeData {
  _DemoTheme(this.typography);

  @override
  final StratumTypography typography;

  @override
  final BaseThemeColor color = _DemoColors();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DemoColors implements BaseThemeColor {
  @override
  final Color textPrimary = const Color(0xFF111827);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _sample = 'ปู่ นี้ ฟุ้ง ญี่ปุ่น · Ag 1,250.00';

const _scales = {'100%': 1.0, '150%': 1.5, '200%': 2.0};

StratumTextStyle _at(StratumTextStyle style, FontSize size) => switch (size) {
  FontSize.s10 => style.s10,
  FontSize.s12 => style.s12,
  FontSize.s14 => style.s14,
  FontSize.s16 => style.s16,
  FontSize.s18 => style.s18,
  FontSize.s20 => style.s20,
  FontSize.s24 => style.s24,
  FontSize.s36 => style.s36,
  FontSize.s48 => style.s48,
  FontSize.s56 => style.s56,
};

class TypographyDemoApp extends StatelessWidget {
  const TypographyDemoApp({super.key, required this.theme});

  final StratumThemeData theme;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stratum typography demo',
      builder: (context, child) => StratumThemeApplication(
        themeMode: ThemeMode.light,
        lightTheme: theme,
        darkTheme: null,
        child: WindowSizeScope(child: child!),
      ),
      home: const _TypographyDemoPage(),
    );
  }
}

class _TypographyDemoPage extends StatefulWidget {
  const _TypographyDemoPage();

  @override
  State<_TypographyDemoPage> createState() => _TypographyDemoPageState();
}

class _TypographyDemoPageState extends State<_TypographyDemoPage> {
  /// The window size the samples use; null follows the real window.
  WindowSize? _windowSize;
  var _scale = 1.0;

  Widget _chip(
    String label, {
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }

  Widget _controls() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text('Window size'),
        _chip(
          'auto (${WindowSizeScope.of(context).name})',
          selected: _windowSize == null,
          onSelected: () => setState(() => _windowSize = null),
        ),
        for (final windowSize in WindowSize.values)
          _chip(
            windowSize.name,
            selected: _windowSize == windowSize,
            onSelected: () => setState(() => _windowSize = windowSize),
          ),
        const SizedBox(width: 16),
        const Text('Text scale'),
        for (final MapEntry(key: label, value: scale) in _scales.entries)
          _chip(
            label,
            selected: _scale == scale,
            onSelected: () => setState(() => _scale = scale),
          ),
      ],
    );
  }

  Widget _sampleRow(BuildContext context, FontType type, FontSize size) {
    var recipe = _at(StratumTextStyle.type(type), size);
    final windowSize = _windowSize;
    if (windowSize != null) recipe = recipe.windowSize(windowSize);
    final label = '${type.name} ${size.name}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label)),
          Expanded(
            child: ColoredBox(
              color: const Color(0xFFE8EEF9),
              child: Text(
                _sample,
                key: ValueKey(label),
                style: recipe.build(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final typography = StratumThemeApplication.of(context).typography;
    return Scaffold(
      appBar: AppBar(title: const Text('Typography demo')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(padding: const EdgeInsets.all(16), child: _controls()),
          Expanded(
            child: MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(_scale)),
              child: Builder(
                builder: (context) => ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final type in FontType.values) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 8),
                        child: Text(
                          type.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      for (final size
                          in typography
                              .types[type == FontType.table
                                  ? FontType.body
                                  : type]!
                              .sizes
                              .keys
                              .toList()
                              .reversed)
                        _sampleRow(context, type, size),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
