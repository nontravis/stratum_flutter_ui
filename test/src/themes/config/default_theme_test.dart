import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

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
    expect(config.radius, hasLength(17));
    expect(config.layouts, hasLength(7));
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

  test('the high-contrast sets equal light and dark', () {
    expect(config.color.highContrastLight, config.color.light);
    expect(config.color.highContrastDark, config.color.dark);
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
          'veryFast': Duration(milliseconds: 50),
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
