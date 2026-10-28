import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart';
import 'package:stratum_ui_widgetbook/components.g.dart';
import 'package:stratum_ui_widgetbook/foundation/tokens_page.dart';
import 'package:stratum_ui_widgetbook/shell/catalog_section.dart';

import '../support/catalog_theme.dart';
import '../support/open_story.dart';

const _pageKey = ValueKey('tokens-page');
const _appKey = ValueKey('tokens-application');

/// Pumps one [TokensPage] under a keyed theme application on an 800 wide
/// surface; pumping again with another [themes] or [mode] updates the same
/// application.
Future<void> _pump(
  WidgetTester tester,
  StratumThemeSet themes,
  ThemeMode mode,
) async {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: StratumThemeApplication(
        key: _appKey,
        themes: themes,
        themeMode: mode,
        child: const TokensPage(key: _pageKey),
      ),
    ),
  );
}

Finder _row(String group, String name) =>
    find.byKey(ValueKey('tokens.row.$group.$name'));

/// The [name] text inside the row of [group].
Finder _label(String group, String name) =>
    find.descendant(of: _row(group, name), matching: find.text(name));

Color? _swatch(WidgetTester tester, String name) => tester
    .widget<ContainerLayout>(find.byKey(ValueKey('tokens.color.$name')))
    .style
    ?.backgroundColor;

/// A copy of [set] whose light data also holds the space token [name].
StratumThemeSet _withSpace(
  StratumThemeSet set,
  String name,
  StratumDimension dimension,
) => StratumThemeSet(
  light: set.light.copyWith(
    space: {...set.light.space, name: StratumByWindowSize.all(dimension)},
  ),
);

void main() {
  late StratumThemeSet set;

  setUpAll(() async {
    set = await loadDefaultThemeSet();
  });

  testWidgets(
    'fo11/us05/fr01, fo11/us05/s1: the page shows each token group of the '
    'active theme',
    (tester) async {
      await _pump(tester, set, ThemeMode.dark);
      final dark = set.dark!;

      for (final heading in [
        'Color',
        'Space',
        'Radius',
        'Typography',
        'Shadow',
      ]) {
        expect(find.text(heading), findsOneWidget, reason: heading);
      }
      expect(dark.color.byName, isNotEmpty);
      for (final MapEntry(:key, :value) in dark.color.byName.entries) {
        expect(_label('color', key), findsOneWidget, reason: key);
        expect(_swatch(tester, key), value, reason: key);
      }
      for (final key in dark.space.keys) {
        expect(_label('space', key), findsOneWidget, reason: key);
      }
      for (final key in dark.radius.keys) {
        expect(_label('radius', key), findsOneWidget, reason: key);
      }
      for (final MapEntry(:key, :value) in dark.typography.types.entries) {
        final label = _label('typography', key.name);
        expect(label, findsOneWidget, reason: key.name);
        // The sample size is the type's own size nearest 16 px.
        final size = value.sizes.keys
            .map((s) => s.value)
            .reduce((a, b) => (a - 16).abs() <= (b - 16).abs() ? a : b);
        expect(
          tester.widget<Text>(label).style,
          StratumTextStyle.type(key).size(size).build(tester.element(label)),
          reason: key.name,
        );
      }
      final shadows = [
        dark.shadow.level1,
        dark.shadow.level2,
        dark.shadow.level3,
        dark.shadow.level4,
        dark.shadow.level5,
        dark.shadow.level6,
      ];
      for (final (index, boxShadows) in shadows.indexed) {
        final name = 'shadow.${index + 1}';
        expect(_label('shadow', name), findsOneWidget, reason: name);
        expect(
          tester
              .widget<ContainerLayout>(find.byKey(ValueKey('tokens.$name')))
              .style
              ?.dropShadow,
          boxShadows,
          reason: name,
        );
      }
    },
  );

  testWidgets('fo11/us05/fr01: a space and a radius row shows its value as '
      'the theme writes it', (tester) async {
    final themes = _withSpace(
      set,
      'catalog-half',
      StratumDimension.percent(.5),
    );
    await _pump(tester, themes, ThemeMode.light);

    expect(
      find.descendant(
        of: _row('space', 'catalog-half'),
        matching: find.text('50%'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: _row('space', 'md'), matching: find.text('16 px')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: _row('radius', 'sm'), matching: find.text('8 px')),
      findsOneWidget,
    );
  });

  testWidgets('fo11/us05/fr01/e01: light to dark shows the dark colors', (
    tester,
  ) async {
    final light = set.light.color.byName;
    final dark = set.dark!.color.byName;
    final name = light.keys.firstWhere((key) => light[key] != dark[key]);

    await _pump(tester, set, ThemeMode.light);
    expect(_swatch(tester, name), light[name]);

    await _pump(tester, set, ThemeMode.dark);
    expect(_swatch(tester, name), dark[name]);
  });

  testWidgets('fo11/us05/s2: another theme shows its own tokens', (
    tester,
  ) async {
    final other = _withSpace(set, 'catalog-test', StratumDimension.fixed(12));

    await _pump(tester, set, ThemeMode.light);
    expect(_row('space', 'catalog-test'), findsNothing);

    await _pump(tester, other, ThemeMode.light);
    expect(_label('space', 'catalog-test'), findsOneWidget);
  });

  testWidgets('fo11/us05/fr01: the page holds no copy of a value', (
    tester,
  ) async {
    final other = _withSpace(set, 'catalog-test', StratumDimension.fixed(12));

    await _pump(tester, set, ThemeMode.light);
    final before = tester.element(find.byKey(_pageKey));
    await _pump(tester, other, ThemeMode.light);

    expect(tester.element(find.byKey(_pageKey)), same(before));
    expect(_label('space', 'catalog-test'), findsOneWidget);
  });

  testWidgets(
    'fo11/us05/fr01: a percent token draws against the window width',
    (tester) async {
      final themes = _withSpace(
        set,
        'catalog-half',
        StratumDimension.percent(.5),
      );

      await _pump(tester, themes, ThemeMode.light);

      expect(
        tester.getSize(find.byKey(const ValueKey('tokens.space.catalog-half'))),
        const Size(400, 8),
      );
    },
  );

  test('fo11/us01/fr02: the Tokens page sits under Foundation', () {
    final pages = [
      for (final component in components)
        if (component.name == 'Tokens') component,
    ];

    expect(pages, hasLength(1));
    expect(pages.single.path, CatalogSection.foundation.label);
    expect([for (final story in pages.single.stories) story.name], ['Tokens']);
  });

  testWidgets('fo11/us01/fr02: the Tokens story opens in the catalog', (
    tester,
  ) async {
    await openStory<TokensPage>(tester, 'Foundation/Tokens/Tokens');

    expect(find.text('Typography'), findsOneWidget);
  });
}
