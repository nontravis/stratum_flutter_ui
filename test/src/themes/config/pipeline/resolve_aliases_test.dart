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
    test(
      'fo01/us03/s1: a palette alias takes the shade and records its chain',
      () {
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
      },
    );

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

    test('reports a cycle made only of inherited leaves once, at the layer '
        'value that led into it', () {
      final (resolved, errors) = _resolve([
        layer('''
color:
  light:
    brand:
      normal: "{color.highContrastLight.brand.normal}"'''),
      ]);

      const cycle =
          'layer1 color.light.brand.normal: alias cycle: '
          'color.highContrastLight.brand.normal -> '
          'color.highContrastLight.brand.normal [alias_cycle]';
      expect(problems(errors), [cycle]);
      expect(
        resolved.failed,
        containsAll([
          'color.light.brand.normal',
          'color.light.button.primary.normal',
          'color.highContrastLight.brand.normal',
          'color.highContrastLight.button.primary.normal',
        ]),
      );
    });
  });

  group('resolveThemeAliases border, blur, and shadow layer colors', () {
    // The `color` of layer [index] of `shadow.<level>` in [tree].
    Object? layerColor(Map<String, Object?> tree, String level, int index) {
      final shadow = tree['shadow']! as Map<String, Object?>;
      final layers = shadow[level]! as List<Object?>;
      return (layers[index]! as Map<String, Object?>)['color'];
    }

    String layerWith(String color) =>
        'shadow:\n  "1":\n'
        '    - {x: 0, y: 1, blur: 2, spread: 0, color: "$color"}';

    test('fo01/us03/fr01: a blur alias takes its target radius', () {
      final (resolved, errors) = _resolve([layer('blur:\n  "4": "{blur.3}"')]);

      expect(problems(errors), isEmpty);
      expect(_at(resolved.tree, 'blur.4'), 16);
      expect(resolved.chains['blur.4'], ['blur.3']);
    });

    test('fo01/us03/fr01: a layer color takes a palette shade or a built-in '
        'step, and keeps a color set reference as written', () {
      final (resolved, errors) = _resolve([
        layer('''
shadow:
  "1":
    - {x: 0, y: 1, blur: 2, spread: 0, color: "{palette.brand.600}"}
    - {x: 0, y: 0, blur: 1, spread: 0, color: "{transparent.black.12}"}
    - {x: 0, y: 0, blur: 1, spread: 0, color: "{color.brand.normal}"}'''),
      ]);

      expect(problems(errors), isEmpty);
      expect(layerColor(resolved.tree, '1', 0), '#2563EB');
      expect(resolved.chains['shadow.1.0.color'], ['palette.brand.600']);
      expect(
        layerColor(resolved.tree, '1', 1),
        transparentColors['black']!['12'],
      );
      expect(layerColor(resolved.tree, '1', 2), '{color.brand.normal}');
      expect(resolved.chains.containsKey('shadow.1.2.color'), isFalse);
      expect(resolved.failed, isNot(contains('shadow.1.2.color')));
    });

    final cases = <(String, String, String, String, String)>[
      (
        'fo01/us03/fr01/e05',
        'a border alias into space',
        'border:\n  md: "{space.md}"',
        'border.md',
        'alias_not_token: "{space.md}" names a space token, not a border '
            'token',
      ),
      (
        'fo01/us03/fr01/e05',
        'a blur alias into border',
        'blur:\n  "1": "{border.md}"',
        'blur.1',
        'alias_not_token: "{border.md}" names a border token, not a blur '
            'token',
      ),
      (
        'fo01/us03/fr01/e01',
        'a blur alias with no target',
        'blur:\n  "2": "{blur.9}"',
        'blur.2',
        'unknown_alias: "{blur.9}" names no token',
      ),
      (
        'fo01/us03/fr01/e04',
        'a border alias to its own group',
        'border:\n  sm: "{border}"',
        'border.sm',
        'alias_not_token: "{border}" names a group, not a token',
      ),
      (
        'fo01/us03/fr01/e06',
        'a layer color set path no set holds',
        layerWith('{color.shadow.tertiary}'),
        'shadow.1.0.color',
        'unknown_alias: "{color.shadow.tertiary}" names no token',
      ),
      (
        'fo01/us03/fr01/e06',
        'a layer color set path written with a set name',
        layerWith('{color.light.brand.normal}'),
        'shadow.1.0.color',
        'unknown_alias: "{color.light.brand.normal}" names no token',
      ),
      (
        'fo01/us03/fr01/e04',
        'a layer color that names a color group',
        layerWith('{color.brand}'),
        'shadow.1.0.color',
        'alias_not_token: "{color.brand}" names a group, not a token',
      ),
      (
        'fo01/us03/fr01/e04',
        'a layer color that names a palette ramp',
        layerWith('{palette.brand}'),
        'shadow.1.0.color',
        'alias_not_token: "{palette.brand}" names a group, not a token',
      ),
      (
        'fo01/us03/fr01/e01',
        'a layer color step outside the 32',
        layerWith('{transparent.black.21}'),
        'shadow.1.0.color',
        'unknown_alias: "{transparent.black.21}" names no token',
      ),
      (
        'fo01/us03/fr01/e05',
        'a layer color that names a space token',
        layerWith('{space.md}'),
        'shadow.1.0.color',
        'alias_not_token: "{space.md}" names a space token, not a color',
      ),
      (
        'fo01/us03/fr01/e04',
        'a layer color outside the token groups',
        layerWith('{shadow.2}'),
        'shadow.1.0.color',
        'alias_not_token: "{shadow.2}" is outside the token groups',
      ),
    ];
    for (final (tag, name, body, path, expected) in cases) {
      test('$tag: reports $name at the holder, once', () {
        final (resolved, errors) = _resolve([layer(body)]);
        final error = errors.sorted.single;

        expect('${error.code.key}: ${error.message}', expected);
        expect(error.path, path);
        expect(error.source, 'layer1');
        expect(resolved.failed, contains(path));
      });
    }

    test('fo01/us03/fr01/e03: reports a blur cycle once, at its first '
        'member', () {
      final (resolved, errors) = _resolve([
        layer('blur:\n  "1": "{blur.2}"\n  "2": "{blur.1}"'),
      ]);

      const expected =
          'layer1 blur.1: alias cycle: blur.1 -> blur.2 -> blur.1 '
          '[alias_cycle]';
      expect(problems(errors), [expected]);
      expect(resolved.failed, containsAll(['blur.1', 'blur.2']));
    });
  });
}
