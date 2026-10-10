@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import 'theme_fixtures.dart';

StratumThemeConfig _parsed() => StratumThemeConfig.parse(
  base: const StratumThemeSource(
    id: 'base',
    folder: baseFolder,
    yaml: baseYaml,
  ),
);

void main() {
  group('n1/q8: a freezed map getter gives back the same instance on every '
      'read', () {
    test('StratumThemeConfig', () {
      final config = _parsed();

      expect(config.assets, same(config.assets));
      expect(config.space, same(config.space));
      expect(config.radius, same(config.radius));
      expect(config.layouts, same(config.layouts));
      expect(config.palette, same(config.palette));
      expect(config.extensions, same(config.extensions));
      expect(config.opacity, same(config.opacity));
      expect(config.border, same(config.border));
      expect(config.shadow, same(config.shadow));
      expect(config.blur, same(config.blur));
      expect(config.copyWith(name: 'brand').space, same(config.space));
    });

    test('StratumColorSets', () {
      final color = _parsed().color;

      expect(color.light, same(color.light));
      expect(color.dark, same(color.dark));
      expect(color.highContrastLight, same(color.highContrastLight));
      expect(color.highContrastDark, same(color.highContrastDark));
    });

    test('StratumAnimationConfig', () {
      final animation = _parsed().animation;

      expect(animation.durations, same(animation.durations));
      expect(animation.curves, same(animation.curves));
      expect(animation.transitions, same(animation.transitions));
    });

    test('StratumTypography and the holders inside it', () {
      final typography = _parsed().typography;
      final defaultFamily = typography.families['default']!;
      final headerType = typography.types[FontType.header]!;

      expect(typography.fonts, same(typography.fonts));
      expect(typography.families, same(typography.families));
      expect(typography.types, same(typography.types));
      expect(defaultFamily.types, same(defaultFamily.types));
      expect(headerType.sizes, same(headerType.sizes));
    });
  });
}
