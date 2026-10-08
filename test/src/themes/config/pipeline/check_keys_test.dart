import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/themes/config/pipeline/check_keys.dart';
import 'package:stratum_ui/src/themes/config/pipeline/load.dart';
import 'package:stratum_ui/src/themes/config/reader.dart';

import '../theme_fixtures.dart';

/// Runs stages 1 and 2 on the base fixture and [layers].
(CheckedThemes, ThemeErrors) _check(List<String> layers) {
  final all = sources(layers);
  final errors = errorsFor(all);
  final roots = loadThemes(all, errors);
  expect(problems(errors), isEmpty, reason: 'stage 1');
  return (checkThemeKeys(roots, errors), errors);
}

/// The errors stage 2 reports for one layer of [body].
List<String> _problems(String body) => problems(_check([layer(body)]).$2);

void main() {
  group('checkThemeKeys unknown keys', () {
    final cases = <(String, String, String)>[
      ('at the root', 'spcae:\n  md: 12', 'spcae'),
      ('in a group', 'space:\n  huge: 99', 'space.huge'),
      (
        'in a color set',
        'color:\n  light:\n    brand:\n      pressed: "#000000"',
        'color.light.brand.pressed',
      ),
      ('a ramp the default lacks', 'palette:\n  pink: {}', 'palette.pink'),
      (
        'a shade the default lacks',
        'palette:\n  brand:\n    25: "#FFFFFF"',
        'palette.brand.25',
      ),
      ('the Figma name layout', 'layout: {}', 'layout'),
      ('the Figma name theme', 'theme: {}', 'theme'),
      ('the Figma name base_color', 'base_color: {}', 'base_color'),
      ('the Figma name font', 'font: {}', 'font'),
      (
        'a root transparent',
        'transparent:\n  black:\n    3: "#00000008"',
        'transparent',
      ),
      ('an asset slot', 'assets:\n  mascot: mascot.png', 'assets.mascot'),
      ('an animation key', 'animation:\n  speed: 1', 'animation.speed'),
      (
        'an animation curve role',
        'animation:\n  curve:\n    bounce: bounceIn',
        'animation.curve.bounce',
      ),
      (
        'a high-contrast key that color.light lacks',
        'color:\n  highContrastLight:\n    brand:\n      pressed: "#000000"',
        'color.highContrastLight.brand.pressed',
      ),
      (
        'a sixth window size under animation.transition',
        'animation:\n  transition:\n    phablet: fade',
        'animation.transition.phablet',
      ),
    ];
    for (final (name, body, path) in cases) {
      test('reports $name', () {
        final key = path.split('.').last;

        expect(_problems(body), [
          'layer1 $path: unknown key "$key" [unknown_key]',
        ]);
      });
    }

    test("an unknown key sits at its key's position and leaves the tree", () {
      final (checked, errors) = _check([layer('spcae:\n  md: 12\nname: x')]);

      expect(errors.sorted.single.line, 2);
      expect(errors.sorted.single.column, 1);
      expect(checked.files.last.tree, {'name': 'x'});
    });
  });

  group('checkThemeKeys maps', () {
    test('a scalar where the default holds a map is expected_map', () {
      const message =
          'layer1 color.light.brand: expected a map, got "#000000" '
          '[expected_map]';

      expect(_problems('color:\n  light:\n    brand: "#000000"'), [message]);
    });

    test('null where the default holds a map is required', () {
      expect(_problems('color:\n  light:\n    brand:'), [
        'layer1 color.light.brand: required [required]',
      ]);
    });

    test('a refused node leaves the tree', () {
      final (checked, _) = _check([layer('color:\n  light:\n    brand: 1')]);

      expect(checked.files.last.tree, {
        'color': {'light': <String, Object?>{}},
      });
    });
  });

  group('checkThemeKeys open maps and tokens', () {
    test('the open maps take any key', () {
      final (checked, errors) = _check([
        layer('''
extensions:
  anything: { deep: [1, 2] }
palette:
  app:
    mango: { 500: "#FFAA00" }
color:
  light:
    app: { mango: "#FFAA00" }
  highContrastDark:
    app: { kiwi: "#00FF00" }'''),
      ]);

      expect(problems(errors), isEmpty);
      expect(checked.files.last.tree, {
        'extensions': {
          'anything': {
            'deep': [1, 2],
          },
        },
        'palette': {
          'app': {
            'mango': {'500': '#FFAA00'},
          },
        },
        'color': {
          'light': {
            'app': {'mango': '#FFAA00'},
          },
          'highContrastDark': {
            'app': {'kiwi': '#00FF00'},
          },
        },
      });
    });

    test('an unquoted 500 key matches the default 500', () {
      final (checked, errors) = _check([
        layer('palette:\n  brand:\n    500: "#000000"'),
      ]);

      expect(problems(errors), isEmpty);
      expect(checked.files.last.tree, {
        'palette': {
          'brand': {'500': '#000000'},
        },
      });
    });

    test('a token value passes whole, a window-size map included', () {
      final (checked, errors) = _check([
        layer('space:\n  md: { mobile: 12, laptop: 20 }'),
      ]);

      expect(problems(errors), isEmpty);
      expect(checked.files.last.tree, {
        'space': {
          'md': {'mobile': 12, 'laptop': 20},
        },
      });
    });

    test('the typography subtree passes untouched', () {
      final (checked, errors) = _check([
        layer('typography:\n  bogus: 1\n  fonts: { x: { family: X } }'),
      ]);

      expect(problems(errors), isEmpty);
      expect(checked.files.last.tree, {
        'typography': {
          'bogus': 1,
          'fonts': {
            'x': {'family': 'X'},
          },
        },
      });
    });
  });

  group('checkThemeKeys trees and origins', () {
    test(r'no tree holds $schema; the base is the schema', () {
      final (checked, _) = _check([layer('name: x')]);

      expect(checked.files.first.tree.containsKey(r'$schema'), isFalse);
      expect(checked.files.last.tree, {'name': 'x'});
      expect(checked.schema.base, same(checked.files.first.tree));
    });

    test("a layer's leaf keeps its file, key, and value position", () {
      final (checked, _) = _check([layer('space:\n  md: 12')]);

      expect(checked.files.last.origins['space.md'], (
        source: 1,
        key: (line: 3, column: 3),
        value: (line: 3, column: 7),
      ));
    });
  });
}
