import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart';
import 'package:stratum_ui_widgetbook/shell/catalog_config.dart';
import 'package:stratum_ui_widgetbook/shell/grid_overlay_addon.dart';
import 'package:stratum_ui_widgetbook/shell/rtl_addon.dart';
import 'package:stratum_ui_widgetbook/shell/stage_addon.dart';
import 'package:stratum_ui_widgetbook/shell/text_scale_addon.dart';
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
  const _Probe(this.onRead, {super.key});

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

/// A story whose page holds [key], the context a test opens a dialog from.
class _OpenerStory extends Story<_Probe, _NoArgs> {
  _OpenerStory(GlobalKey key)
    : super(
        name: 'OpenerStory',
        args: const _NoArgs(),
        builder: (_, _) => _Probe((_) {}, key: key),
      );
}

Component _page(String name, ValueChanged<_Reading> onRead) => Component(
  name: name,
  path: 'Foundation',
  stories: [_ProbeStory('${name}Story', onRead)],
);

/// A route that opens [story] with the toolbar settings in [groups], keyed
/// as Widgetbook keys them: by `slugify(addon name)`, each to that addon's
/// own query fields.
String _route(String story, Map<String, Map<String, String>> groups) => Uri(
  path: '/',
  queryParameters: {
    'path': story,
    for (final MapEntry(:key, :value) in groups.entries)
      key: QueryGroup(value).toParam(),
  },
).toString();

/// Sizes the test view to a desktop window, so Widgetbook lays out its
/// desktop panels.
void _desktopView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  test('fo11/us02/fr01: catalogAddons holds the seven toolbar addons in order, '
      'then the stage', () async {
    final set = await loadDefaultThemeSet();

    final addons = catalogAddons({'default': set});

    expect(addons, [
      isA<WindowSizeAddon>(),
      isA<LocaleAddon>(),
      isA<RtlAddon>(),
      isA<CatalogTextScaleAddon>(),
      isA<ThemeAddon<dynamic>>(),
      isA<GridOverlayAddon>(),
      isA<SemanticsAddon>(),
      isA<StageAddon>(),
    ]);
  });

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
    expect(config.addons, hasLength(8));
  });

  testWidgets(
    'fo11/us02/fr01/e02, fo11/us02/s1: the settings follow the Developer '
    'across pages',
    (tester) async {
      _desktopView(tester);
      final set = await loadDefaultThemeSet();
      final readings = <String, _Reading>{};

      await tester.pumpWidget(
        WidgetbookApp(
          config: catalogConfig(
            components: [
              _page('Alpha', (r) => readings['Alpha'] = r),
              _page('Beta', (r) => readings['Beta'] = r),
            ],
            themes: {'default': set},
            initialRoute: _route('Foundation/Alpha/AlphaStory', {
              'theme': {'name': 'default · Dark'},
              'viewport': {'name': WindowSize.tablet.name},
              'locale': {'name': 'th'},
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

  testWidgets(
    'fo11/us02/fr01: a dialog a story opens renders under the toolbar '
    'settings',
    (tester) async {
      _desktopView(tester);
      final set = await loadDefaultThemeSet();
      final opener = GlobalKey();
      _Reading? reading;

      await tester.pumpWidget(
        WidgetbookApp(
          config: catalogConfig(
            components: [
              Component(
                name: 'Opener',
                path: 'Foundation',
                stories: [_OpenerStory(opener)],
              ),
            ],
            themes: {'default': set},
            initialRoute: _route('Foundation/Opener/OpenerStory', {
              'theme': {'name': 'default · Dark'},
              'locale': {'name': 'th'},
              'right-to-left': {'enabled': 'true'},
              'text-scale': {'factor': '2.0'},
            }),
          ),
        ),
      );
      await tester.pumpAndSettle();
      unawaited(
        showDialog<void>(
          context: opener.currentContext!,
          useRootNavigator: false,
          builder: (_) => _Probe((r) => reading = r),
        ),
      );
      await tester.pumpAndSettle();

      expect(reading, isNotNull);
      expect(reading!.theme, same(set.dark));
      expect(reading!.locale, const Locale('th'));
      expect(reading!.direction, TextDirection.rtl);
      expect(reading!.textScaler, const TextScaler.linear(2));
      expect(reading!.windowSize, WindowSize.mobile);
    },
  );
}
