import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

/// The WCAG 1.4.11 contrast ratio between [a] and [b].
double _contrast(Color a, Color b) {
  final luminanceA = a.computeLuminance();
  final luminanceB = b.computeLuminance();
  return (math.max(luminanceA, luminanceB) + 0.05) /
      (math.min(luminanceA, luminanceB) + 0.05);
}

/// Counts the leaves of [node] outside `app` by kind: `alias` or `literal`,
/// and each alias by its group: `palette`, `transparent`, or `color`.
void _count(Object? node, Map<String, int> counts) {
  if (node is! Map) {
    final value = '$node';
    if (value.startsWith('{')) {
      counts.update('alias', (count) => count + 1, ifAbsent: () => 1);
      final group = value.substring(1).split('.').first;
      counts.update(group, (count) => count + 1, ifAbsent: () => 1);
    } else {
      counts.update('literal', (count) => count + 1, ifAbsent: () => 1);
    }
    return;
  }
  for (final MapEntry(:key, :value) in node.entries) {
    if (key != 'app') _count(value, counts);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late String text;
  late StratumThemeConfig config;

  setUpAll(() async {
    text = await rootBundle.loadString('assets/themes/default/theme.yaml');
    config = StratumThemeConfig.parse(
      base: StratumThemeSource(
        id: 'stratum-default',
        folder: 'packages/stratum_ui/assets/themes/default',
        yaml: text,
      ),
    );
  });

  test('parses alone into the Figma token counts', () {
    expect(config.name, 'stratum-default');
    expect(config.color.light, hasLength(192));
    expect(config.color.dark, hasLength(192));
    expect(config.color.highContrastLight, hasLength(192));
    expect(config.color.highContrastDark, hasLength(192));
    expect(config.palette, hasLength(88));
    expect(config.space, hasLength(27));
    expect(config.radius, hasLength(18));
    expect(config.layouts, hasLength(7));
    expect(
      config.radius['sheet'],
      const StratumByWindowSize.all(StratumDimension.fixed(40)),
    );
  });

  test(
    'resolves Figma values through palette, theme, and built-in aliases',
    () {
      expect(config.color.light['brand.normal'], const Color(0xFF3B82F6));
      expect(config.color.dark['brand.normal'], const Color(0xFF2563EB));
      expect(
        config.color.light['button.primary.normal'],
        const Color(0xFF3B82F6),
      );
      expect(
        config.color.light['state.hover-destructive'],
        const Color(0x14FF0000),
      );
      expect(
        config.color.light['background.control.input-disabled'],
        const Color(0x08000000),
      );
      expect(
        config.color.dark['background.default.surface-inverse'],
        const Color(0x0FFFFFFF),
      );
    },
  );

  test('the high-contrast sets equal light and dark save the focus ring '
      'token', () {
    const ring = 'border.subtle.blue';

    expect(
      Map.of(config.color.highContrastLight)..remove(ring),
      Map.of(config.color.light)..remove(ring),
    );
    expect(
      Map.of(config.color.highContrastDark)..remove(ring),
      Map.of(config.color.dark)..remove(ring),
    );
    expect(config.color.highContrastLight[ring], const Color(0xFF2563EB));
    expect(config.color.highContrastDark[ring], const Color(0xFF60A5FA));
  });

  test('NFR-U07, us04/nf01, and us07/nf01: the focus ring holds 3:1 in both '
      'high-contrast sets and keeps its exception in light and dark', () {
    const ring = 'border.subtle.blue';

    for (final contrastSet in [
      config.color.highContrastLight,
      config.color.highContrastDark,
    ]) {
      expect(
        _contrast(
          contrastSet[ring]!,
          contrastSet['background.default.normal']!,
        ),
        greaterThanOrEqualTo(3),
      );
      expect(
        _contrast(
          contrastSet[ring]!,
          contrastSet['background.default.surface']!,
        ),
        greaterThanOrEqualTo(3),
      );
    }

    expect(
      _contrast(
        config.color.light[ring]!,
        config.color.light['background.default.normal']!,
      ),
      closeTo(1.80, 0.01),
    );
    expect(
      _contrast(
        config.color.dark[ring]!,
        config.color.dark['background.default.normal']!,
      ),
      closeTo(2.03, 0.01),
    );
  });

  test('extensions and both asset slots are empty', () {
    expect(config.extensions, isEmpty);
    expect(config.assets, isEmpty);
  });

  test('typography equals StratumTypography.fromYaml of the same subtree', () {
    final document = loadYaml(text) as YamlMap;

    expect(
      config.typography,
      StratumTypography.fromYaml(document['typography'] as YamlMap),
    );
  });

  test('Thai text takes Kanit from Google Fonts for the prose types', () {
    final kanit = config.typography.fonts['kanit'];
    final thai = config.typography.families['th']!.types;

    expect(kanit?.family, 'Kanit');
    expect(kanit?.source, StratumFontSource.google);
    expect(
      {for (final MapEntry(:key, :value) in thai.entries) key: value.font},
      {
        FontType.header: 'kanit',
        FontType.paragraph: 'kanit',
        FontType.body: 'kanit',
        FontType.table: 'kanit',
      },
    );
  });

  test('the raw yaml holds the spec section 11 counts', () {
    final color = (loadYaml(text) as YamlMap)['color'] as YamlMap;
    final light = <String, int>{};
    final dark = <String, int>{};
    _count(color['light'], light);
    _count(color['dark'], dark);

    expect(light['alias'], 188);
    expect(light['literal'], 4);
    expect(dark['alias'], 192);
    expect(dark['literal'], isNull);
    expect((light['palette'] ?? 0) + (dark['palette'] ?? 0), 145);
    expect((light['transparent'] ?? 0) + (dark['transparent'] ?? 0), 219);
    expect((light['color'] ?? 0) + (dark['color'] ?? 0), 16);
  });

  test('the animation group reads the spec section 8.1 values', () {
    expect(
      config.animation,
      const StratumAnimationConfig(
        durations: {
          'micro': Duration(milliseconds: 30),
          'veryFast': Duration(milliseconds: 75),
          'fast': Duration(milliseconds: 125),
          'normal': Duration(milliseconds: 200),
          'slow': Duration(milliseconds: 300),
          'verySlow': Duration(milliseconds: 400),
        },
        defaultLevel: 'fast',
        reverseRatio: 0.64,
        curves: {
          'standard': StratumNamedCurve('easeInOutSine'),
          'enter': StratumNamedCurve('easeOut'),
          'exit': StratumNamedCurve('easeIn'),
        },
        transitions: {
          'watch': 'platform',
          'mobile': 'platform',
          'tablet': 'platform',
          'desktop': 'platform',
          'bigDesktop': 'platform',
        },
      ),
    );
  });

  test('fo01/us01/fr01: the opacity group reads disabled and scrim 0.5', () {
    expect(config.opacity, {'disabled': 0.5, 'scrim': 0.5});
  });

  test('fo01/us01/fr01: border, shadow, and blur read the Figma values, '
      'each shadow level ambient then contact', () {
    expect(config.border, {'sm': 0.5, 'md': 1.0, 'lg': 1.5});
    expect(config.blur, {
      '1': 4.0,
      '2': 8.0,
      '3': 16.0,
      '4': 24.0,
      '5': 40.0,
      '6': 80.0,
    });
    const contact = StratumShadowLayer(
      x: 0,
      y: 0,
      blur: 1,
      spread: 0,
      color: StratumSetLayerColor('shadow.primary'),
    );
    StratumShadowLayer ambient(double y, double blur) => StratumShadowLayer(
      x: 0,
      y: y,
      blur: blur,
      spread: 0,
      color: const StratumSetLayerColor('shadow.secondary'),
    );
    expect(config.shadow, {
      '1': [ambient(1, 2), contact],
      '2': [ambient(4, 8), contact],
      '3': [ambient(8, 16), contact],
      '4': [ambient(12, 24), contact],
      '5': [ambient(24, 32), contact],
      '6': [ambient(40, 64), contact],
    });
  });

  test('fo01/us01/fr01, us14/fr01: the system group reads auto icons, '
      'transparent bars, the Android scrim defaults, and the page '
      'background', () {
    SystemStyle look(Color appSwitcherColor) => SystemStyle(
      statusBarIcons: SystemBarIcons.auto,
      statusBarColor: const Color(0x00000000),
      statusBarContrast: false,
      navigationBarIcons: SystemBarIcons.auto,
      navigationBarColor: const Color(0x00000000),
      navigationBarDividerColor: const Color(0x00000000),
      navigationBarContrast: true,
      appSwitcherColor: appSwitcherColor,
    );
    final light = config.color.light['background.default.normal']!;
    final dark = config.color.dark['background.default.normal']!;

    expect(light, const Color(0xFFFFFFFF));
    expect(dark, const Color(0xFF111827));
    expect(config.system, {
      'light': look(light),
      'dark': look(dark),
      'highContrastLight': look(
        config.color.highContrastLight['background.default.normal']!,
      ),
      'highContrastDark': look(
        config.color.highContrastDark['background.default.normal']!,
      ),
    });
  });

  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  test("the curve table equals the SDK's Curves constants", () {
    final source = File(
      '$flutterRoot/packages/flutter/lib/src/animation/curves.dart',
    ).readAsStringSync();
    final curves = source.substring(
      source.indexOf('abstract final class Curves'),
    );
    final names = RegExp(r'static const \w+ (\w+) =')
        .allMatches(curves)
        .map((match) => match[1]!)
        .toList();

    expect(names, hasLength(43));
    expect(StratumNamedCurve.names, names);
    expect(StratumCurveConvert.byName['easeInOutSine'], Curves.easeInOutSine);
    expect(StratumCurveConvert.byName['elasticInOut'], Curves.elasticInOut);
  }, skip: flutterRoot == null ? 'FLUTTER_ROOT is not set' : null);
}
