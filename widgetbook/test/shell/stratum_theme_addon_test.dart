import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart';
import 'package:stratum_ui_widgetbook/shell/catalog_themes.dart';
import 'package:stratum_ui_widgetbook/shell/stratum_theme_addon.dart';

import '../support/catalog_theme.dart';

/// An asset bundle that holds the package default theme file and one
/// bundled theme file, both with [yaml].
class _ThemeBundle extends AssetBundle {
  _ThemeBundle(this.yaml);

  final String yaml;

  static const _keys = [
    'packages/stratum_ui/assets/themes/default/theme.yaml',
    'assets/themes/default/theme.yaml',
  ];

  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin') {
      return const StandardMessageCodec().encodeMessage(<String, Object>{
        for (final asset in _keys) asset: <Object>[],
      })!;
    }
    if (_keys.contains(key)) return ByteData.sublistView(utf8.encode(yaml));
    throw FlutterError('Unable to load asset: "$key".');
  }

  @override
  Future<T> loadStructuredData<T>(
    String key,
    Future<T> Function(String value) parser,
  ) async => parser(await loadString(key));
}

/// Reads the active theme data the theme application publishes.
class _ThemeProbe extends StatelessWidget {
  const _ThemeProbe(this.onRead);

  final ValueChanged<StratumThemeData> onRead;

  @override
  Widget build(BuildContext context) {
    onRead(StratumThemeApplication.of(context));
    return const SizedBox(width: 10, height: 10);
  }
}

void main() {
  testWidgets(
    'fo11/us02/fr01: the theme addon lists each theme in light and dark',
    (tester) async {
      final set = await loadDefaultThemeSet();
      final themes = catalogThemes({'default': set});
      final addon = stratumThemeAddon(themes);

      expect(themes.keys, ['default · Light', 'default · Dark']);
      expect(themes['default · Dark']!.mode, ThemeMode.dark);

      final seen = <StratumThemeData>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => addon.apply(
              context,
              _ThemeProbe(seen.add),
              themes['default · Dark']!,
            ),
          ),
        ),
      );

      expect(seen.last, set.dark);
    },
  );

  testWidgets(
    'fo11/us02/fr01: the addon paints the dark theme background and its '
    'default text style under the story',
    (tester) async {
      final set = await loadDefaultThemeSet();
      final themes = catalogThemes({'default': set});
      final addon = stratumThemeAddon(themes);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => addon.apply(
              context,
              const Text('story text'),
              themes['default · Dark']!,
            ),
          ),
        ),
      );

      final dark = set.dark!;
      expect(
        find.ancestor(
          of: find.text('story text'),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is DecoratedBox &&
                widget.decoration is StyleDecoration &&
                (widget.decoration as StyleDecoration).color ==
                    dark.color.background.defaults.normal,
          ),
        ),
        findsOneWidget,
      );
      expect(
        DefaultTextStyle.of(tester.element(find.text('story text')))
            .style
            .color,
        dark.color.text.defaults.primary,
      );
    },
  );

  test('fo11/us02/fr01: loadCatalogThemes keys each bundled theme', () async {
    final yaml = File('../assets/themes/default/theme.yaml').readAsStringSync();

    final loaded = await loadCatalogThemes(bundle: _ThemeBundle(yaml));

    expect(loaded.keys, ['default']);
    expect(loaded['default'], isA<StratumThemeSet>());
  });
}
