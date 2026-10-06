@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

StratumThemeConfig _packageDefault() => StratumThemeConfig.parse(
  base: StratumThemeSource(
    id: 'stratum-default',
    folder: 'packages/stratum_ui/assets/themes/default',
    yaml: File('assets/themes/default/theme.yaml').readAsStringSync(),
  ),
);

void main() {
  group('n1/q8: the theme config is freezed', () {
    test('StratumThemeConfig gains copyWith and keeps value equality', () {
      final config = _packageDefault();

      expect(config, _packageDefault());
      expect(config.hashCode, _packageDefault().hashCode);
      expect(config.copyWith(name: 'brand').name, 'brand');
      expect(config.copyWith(name: 'brand'), isNot(config));
      expect(config.toString(), startsWith('StratumThemeConfig('));
    });

    test('every map of StratumThemeConfig and StratumColorSets refuses '
        'changes', () {
      final config = _packageDefault();

      expect(() => config.palette.clear(), throwsUnsupportedError);
      expect(() => config.space.clear(), throwsUnsupportedError);
      expect(() => config.extensions.clear(), throwsUnsupportedError);
      expect(() => config.color.light.clear(), throwsUnsupportedError);
      expect(
        config.color.copyWith(dark: config.color.light).dark,
        config.color.light,
      );
    });
  });
}
