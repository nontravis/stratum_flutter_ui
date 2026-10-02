import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/themes/config/pipeline/check_keys.dart';
import 'package:stratum_ui/src/themes/config/pipeline/load.dart';
import 'package:stratum_ui/src/themes/config/pipeline/merge.dart';
import 'package:stratum_ui/src/themes/config/pipeline/resolve_aliases.dart';
import 'package:stratum_ui/src/themes/config/reader.dart';
import 'package:stratum_ui/src/themes/config/transparent.dart';

import '../theme_fixtures.dart';

/// Runs stages 1 to 4 on the base fixture and [layers].
(ResolvedTheme, ThemeErrors) _resolve(List<String> layers) {
  final all = sources(layers);
  final errors = errorsFor(all);
  final roots = loadThemes(all, errors);
  expect(problems(errors), isEmpty, reason: 'stage 1');
  final checked = checkThemeKeys(roots, errors);
  final merged = mergeThemes(checked, errors);
  return (resolveThemeAliases(merged, checked.schema, errors), errors);
}

/// The value at the dotted [path] of [tree].
Object? _at(Map<String, Object?> tree, String path) {
  Object? node = tree;
  for (final key in path.split('.')) {
    node = (node! as Map<String, Object?>)[key];
  }
  return node;
}

/// The alpha byte of each step of Figma's `transparent/black` and
/// `transparent/white` variables (file wjRe9eL7863nMRfFats8jZ).
const _figmaAlphas = {
  '0': '00', '1': '03', '2': '05', '3': '08', '4': '0A', '5': '0D', //
  '6': '0F', '7': '12', '8': '14', '9': '17', '10': '1A', '11': '1C', //
  '12': '1F', '13': '21', '14': '24', '15': '26', '16': '29', '17': '2B', //
  '18': '2E', '19': '30', '20': '33', '25': '40', '30': '4D', '35': '59', //
  '40': '66', '45': '73', '50': '80', '60': '99', '70': 'B2', '80': 'CC', //
  '90': 'E5', '100': 'FF', //
};

void main() {
  group('resolveThemeAliases values', () {
    test('a palette alias takes the shade and records its chain', () {
      final (resolved, errors) = _resolve([]);

      expect(problems(errors), isEmpty);
      expect(_at(resolved.tree, 'color.light.brand.normal'), '#3B82F6');
      expect(resolved.chains['color.light.brand.normal'], [
        'palette.brand.500',
      ]);
      expect(
        resolved.aliases['color.light.brand.normal'],
        '{palette.brand.500}',
      );
    });

    test('a two-hop chain reaches the palette through the color set', () {
      final (resolved, _) = _resolve([]);

      expect(
        _at(resolved.tree, 'color.light.button.primary.normal'),
        '#3B82F6',
      );
      expect(resolved.chains['color.light.button.primary.normal'], [
        'color.light.brand.normal',
        'palette.brand.500',
      ]);
      expect(
        _at(resolved.tree, 'color.highContrastDark.button.primary.normal'),
        '#2563EB',
      );
    });

    test("a layer's palette override reaches the default's alias", () {
      final (resolved, _) = _resolve([
        layer('palette:\n  brand:\n    500: "#000000"'),
      ]);

      expect(_at(resolved.tree, 'color.light.brand.normal'), '#000000');
      expect(
        _at(resolved.tree, 'color.light.button.primary.normal'),
        '#000000',
      );
    });

    test('a whole-token alias copies a window-size map', () {
      final (resolved, errors) = _resolve([
        layer('space:\n  lg: "{space.gutter}"\n  md: { mobile: "{space.lg}" }'),
      ]);

      expect(problems(errors), isEmpty);
      expect(_at(resolved.tree, 'space.lg'), {'mobile': 16, 'desktop': 32});
      expect(_at(resolved.tree, 'space.md'), {
        'mobile': {'mobile': 16, 'desktop': 32},
      });
      expect(
        identical(
          _at(resolved.tree, 'space.lg'),
          _at(resolved.tree, 'space.gutter'),
        ),
        isFalse,
      );
    });

    test('brace strings in name, typography, and extensions stay plain', () {
      final (resolved, errors) = _resolve([
        layer('''
name: "{palette.brand.500}"
typography:
  fonts:
    inter: { family: "{palette.brand.500}" }
extensions:
  link: "{palette.brand.500}"'''),
      ]);

      expect(problems(errors), isEmpty);
      expect(resolved.tree['name'], '{palette.brand.500}');
      expect(
        _at(resolved.tree, 'typography.fonts.inter.family'),
        '{palette.brand.500}',
      );
      expect(_at(resolved.tree, 'extensions.link'), '{palette.brand.500}');
    });
  });

  group('resolveThemeAliases built-in transparent steps', () {
    test("hold Figma's 64 values byte for byte", () {
      expect(transparentColors.keys, ['black', 'white']);
      expect(transparentColors['black'], {
        for (final MapEntry(key: step, value: alpha) in _figmaAlphas.entries)
          step: '#000000$alpha',
      });
      expect(transparentColors['white'], {
        for (final MapEntry(key: step, value: alpha) in _figmaAlphas.entries)
          step: '#FFFFFF$alpha',
      });
    });

    test('resolve as alias targets', () {
      final (resolved, _) = _resolve([
        layer(
          'color:\n  light:\n    brand:\n      hover: "{transparent.black.70}"',
        ),
      ]);

      expect(_at(resolved.tree, 'color.light.brand.hover'), '#000000B2');
      expect(
        _at(resolved.tree, 'color.light.background.control.input-disabled'),
        '#00000008',
      );
      expect(
        _at(resolved.tree, 'color.dark.background.control.input-disabled'),
        '#FFFFFF08',
      );
    });

    test('a color-set token named transparent differs from the built-in', () {
      final (resolved, _) = _resolve([
        layer('''
color:
  light:
    brand:
      normal: "{transparent.white.0}"
      hover: "{color.light.transparent.0}"
  dark:
    brand:
      hover: "{color.dark.transparent.0}"'''),
      ]);

      expect(_at(resolved.tree, 'color.light.brand.normal'), '#FFFFFF00');
      expect(resolved.chains['color.light.brand.normal'], [
        'transparent.white.0',
      ]);
      expect(_at(resolved.tree, 'color.light.brand.hover'), '#FFFFFF00');
      expect(resolved.chains['color.light.brand.hover'], [
        'color.light.transparent.0',
        'transparent.white.0',
      ]);
      expect(_at(resolved.tree, 'color.dark.brand.hover'), '#00000000');
    });
  });

  group('resolveThemeAliases errors', () {
    final cases = <(String, String, String)>[
      (
        'a path with no token',
        '{palette.brand.555}',
        'unknown_alias: "{palette.brand.555}" names no token',
      ),
      (
        'a built-in step outside the 32',
        '{transparent.black.21}',
        'unknown_alias: "{transparent.black.21}" names no token',
      ),
      (
        'a palette ramp',
        '{palette.brand}',
        'alias_not_token: "{palette.brand}" names a group, not a token',
      ),
      (
        'a built-in color',
        '{transparent.black}',
        'alias_not_token: "{transparent.black}" names a group, not a token',
      ),
      (
        'a typography path',
        '{typography.scaleByWindowSize.tablet}',
        'alias_not_token: "{typography.scaleByWindowSize.tablet}" '
            'is outside the token groups',
      ),
      (
        'an extensions path',
        '{extensions.x}',
        'alias_not_token: "{extensions.x}" is outside the token groups',
      ),
      (
        'an entry inside a window-size token',
        '{space.gutter.desktop}',
        'alias_not_token: "{space.gutter.desktop}" names a group, not a '
            'token',
      ),
    ];
    for (final (name, alias, expected) in cases) {
      test('reports $name at the holder, once', () {
        final (resolved, errors) = _resolve([
          layer('color:\n  light:\n    brand:\n      normal: "$alias"'),
        ]);
        final error = errors.sorted.single;

        expect('${error.code.key}: ${error.message}', expected);
        expect(error.path, 'color.light.brand.normal');
        expect(error.source, 'layer1');
        expect(
          resolved.failed,
          containsAll([
            'color.light.brand.normal',
            'color.light.button.primary.normal',
            'color.highContrastLight.brand.normal',
          ]),
        );
      });
    }

    test('reports a cycle once, at its first member, and fails every holder '
        'that reaches it', () {
      final (resolved, errors) = _resolve([
        layer('''
color:
  light:
    brand:
      normal: "{color.light.brand.hover}"
      hover: "{color.light.brand.normal}"'''),
      ]);

      const cycle =
          'layer1 color.light.brand.normal: alias cycle: '
          'color.light.brand.normal -> color.light.brand.hover -> '
          'color.light.brand.normal [alias_cycle]';
      expect(problems(errors), [cycle]);
      expect(
        resolved.failed,
        containsAll([
          'color.light.brand.normal',
          'color.light.brand.hover',
          'color.light.button.primary.normal',
          'color.highContrastLight.brand.normal',
          'color.highContrastLight.brand.hover',
        ]),
      );
    });
  });
}
