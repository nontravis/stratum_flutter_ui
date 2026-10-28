import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart';
import 'package:stratum_ui_widgetbook/shell/catalog_config.dart';
import 'package:stratum_ui_widgetbook/shell/grid_overlay_addon.dart';
import 'package:stratum_ui_widgetbook/shell/rtl_addon.dart';
import 'package:stratum_ui_widgetbook/shell/window_size_addon.dart';
import 'package:widgetbook/src/core/widgetbook_app.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

import '../support/catalog_theme.dart';

typedef _Reading = ({
  WindowSize? windowSize,
  Locale locale,
  TextDirection direction,
  TextScaler textScaler,
  StratumThemeData? theme,
});

/// Story args of [_ProbeStory].
class _NoArgs extends StoryArgs<_Probe> {
  const _NoArgs();

  @override
  List<Arg?> get list => const [];
}

/// A story that builds a [_Probe] reporting to [onRead].
class _ProbeStory extends Story<_Probe, _NoArgs> {
  _ProbeStory(String name, ValueChanged<_Reading> onRead)
    : super(
        name: name,
        args: const _NoArgs(),
        builder: (_, _) => _Probe(onRead),
      );
}

/// Reads every setting the toolbar changes and holds a labelled node.
class _Probe extends StatelessWidget {
  const _Probe(this.onRead);

  final ValueChanged<_Reading> onRead;

  @override
  Widget build(BuildContext context) {
    onRead((
      windowSize: WindowSizeScope.maybeOf(context),
      locale: Localizations.localeOf(context),
      direction: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      theme: StratumThemeApplication.maybeOf(context),
    ));
    return Semantics(
      label: 'probe label',
      child: const SizedBox(width: 10, height: 10),
    );
  }
}

Component _page(String name, ValueChanged<_Reading> onRead) => Component(
  name: name,
  path: 'Foundation',
  stories: [_ProbeStory('${name}Story', onRead)],
);

/// A route that opens [story] with the toolbar settings in [groups], keyed
/// as Widgetbook keys them: by `slugify(addon name)`.
String _route(String story, Map<String, String> groups) => Uri(
  path: '/',
  queryParameters: {
    'path': story,
    for (final MapEntry(:key, :value) in groups.entries)
      key: QueryGroup({'name': value}).toParam(),
  },
).toString();

void main() {
  test(
    'fo11/us02/fr01: catalogAddons holds the seven addons in order',
    () async {
      final set = await loadDefaultThemeSet();

      final addons = catalogAddons({'default': set});

      expect(addons, [
        isA<WindowSizeAddon>(),
        isA<LocaleAddon>(),
        isA<RtlAddon>(),
        isA<TextScaleAddon>(),
        isA<ThemeAddon<dynamic>>(),
        isA<GridOverlayAddon>(),
        isA<SemanticsAddon>(),
      ]);
    },
  );

  test('fo11/us02/fr01: catalogConfig orders the pages by section', () async {
    final set = await loadDefaultThemeSet();
    Component stub(String section) => Component(
      name: 'Page',
      path: section,
      stories: [_ProbeStory('Story', (_) {})],
    );

    final config = catalogConfig(
      components: [stub('Overlay'), stub('Foundation')],
      themes: {'default': set},
    );

    expect(config.components.map((c) => c.path), ['Foundation', 'Overlay']);
    expect(config.addons, hasLength(7));
  });

  testWidgets(
    'fo11/us02/fr01/e02, fo11/us02/s1: the settings follow the Developer '
    'across pages',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final set = await loadDefaultThemeSet();
      final readings = <String, _Reading>{};

      await tester.pumpWidget(
        WidgetbookApp(
          config: Config(
            components: catalogConfig(
              components: [
                _page('Alpha', (r) => readings['Alpha'] = r),
                _page('Beta', (r) => readings['Beta'] = r),
              ],
              themes: {'default': set},
            ).components,
            addons: catalogAddons({'default': set}),
            initialRoute: _route('Foundation/Alpha/AlphaStory', {
              'theme': 'default · Dark',
              'viewport': WindowSize.tablet.name,
              'locale': 'th',
            }),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(readings['Alpha']!.theme, set.dark);
      expect(readings['Alpha']!.windowSize, WindowSize.tablet);
      expect(readings['Alpha']!.locale, const Locale('th'));

      await tester.tap(find.text('BetaStory'));
      await tester.pumpAndSettle();

      expect(readings['Beta']!.theme, set.dark);
      expect(readings['Beta']!.windowSize, WindowSize.tablet);
      expect(readings['Beta']!.locale, const Locale('th'));
    },
  );
}
