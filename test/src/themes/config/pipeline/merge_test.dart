import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/themes/config/pipeline/check_keys.dart';
import 'package:stratum_ui/src/themes/config/pipeline/load.dart';
import 'package:stratum_ui/src/themes/config/pipeline/merge.dart';
import 'package:stratum_ui/src/themes/config/reader.dart';

import '../theme_fixtures.dart';

/// Runs stages 1 to 3 on the base fixture and [layers].
(MergedTheme, ThemeErrors) _merge(List<String> layers) {
  final all = sources(layers);
  final errors = errorsFor(all);
  final roots = loadThemes(all, errors);
  expect(problems(errors), isEmpty, reason: 'stage 1');
  return (mergeThemes(checkThemeKeys(roots, errors), errors), errors);
}

/// The value at the dotted [path] of [tree].
Object? _at(Map<String, Object?> tree, String path) {
  Object? node = tree;
  for (final key in path.split('.')) {
    node = (node! as Map<String, Object?>)[key];
  }
  return node;
}

void main() {
  group('mergeThemes layers', () {
    test('fo01/us04/s1: maps merge by key and values replace', () {
      final (merged, errors) = _merge([
        layer('color:\n  light:\n    brand:\n      normal: "#000000"'),
      ]);

      expect(problems(errors), isEmpty);
      expect(_at(merged.tree, 'color.light.brand.normal'), '#000000');
      expect(
        _at(merged.tree, 'color.light.brand.hover'),
        '{palette.brand.600}',
      );
    });

    test('three files merge in order and each path keeps the origin of the '
        'last file that wrote it', () {
      final (merged, _) = _merge([
        layer('space:\n  md: 12\n  lg: 22'),
        layer('space:\n  md: 10'),
      ]);

      expect(_at(merged.tree, 'space.md'), 10);
      expect(_at(merged.tree, 'space.lg'), 22);
      expect(merged.origins['space.md']?.source, 2);
      expect(merged.origins['space.lg']?.source, 1);
      expect(merged.origins['radius.sm']?.source, 0);
    });

    test('a window-size token is one leaf: a map replaces the whole token '
        '(fo01 Q12)', () {
      final (merged, _) = _merge([layer('space:\n  gutter: { mobile: 12 }')]);

      expect(_at(merged.tree, 'space.gutter'), {'mobile': 12});
    });

    test(r'$schema does not merge', () {
      final (merged, _) = _merge([layer('name: x')]);

      expect(merged.tree.containsKey(r'$schema'), isFalse);
      expect(merged.tree['name'], 'x');
    });
  });

  group('mergeThemes app colors', () {
    test('a name in only one of light.app and dark.app is required at the '
        'other, at the position of the entry that exists', () {
      final (_, errors) = _merge([
        layer('''
color:
  light:
    app:
      mango: "#FFAA00"
  dark:
    app:
      kiwi: "#00FF00"'''),
      ]);

      const mangoRequired =
          'layer1 color.dark.app.mango: '
          'required; color.light.app.mango has no dark value [required]';
      const kiwiRequired =
          'layer1 color.light.app.kiwi: '
          'required; color.dark.app.kiwi has no light value [required]';
      expect(problems(errors), [mangoRequired, kiwiRequired]);
      expect(
        [for (final error in errors.sorted) (error.line, error.column)],
        [(5, 7), (8, 7)],
      );
    });

    test('a high-contrast app name that light.app lacks is unknown_key and '
        'leaves the overlay', () {
      final (merged, errors) = _merge([
        layer('color:\n  highContrastLight:\n    app:\n      mango: "#000000"'),
      ]);

      const mangoUnknown =
          'layer1 color.highContrastLight.app.mango: '
          'no color "mango" in color.light.app [unknown_key]';
      expect(problems(errors), [mangoUnknown]);
      expect(_at(merged.tree, 'color.highContrastLight.app'), isEmpty);
    });
  });

  group('mergeThemes high-contrast sets', () {
    test('come out full, inherited leaves keeping their base-set origin', () {
      final (merged, _) = _merge([]);

      expect(
        _at(merged.tree, 'color.highContrastLight.brand.hover'),
        '{palette.brand.600}',
      );
      expect(_at(merged.tree, 'color.highContrastDark.background.control'), {
        'input-disabled': '{transparent.white.3}',
      });
      expect(
        merged.origins['color.highContrastLight.brand.hover'],
        merged.origins['color.light.brand.hover'],
      );
      expect(merged.inherited, contains('color.highContrastLight.brand.hover'));
    });

    test('fo01/us04/fr01/e06: an inherited alias into the base set points into the overlay', () {
      final (merged, _) = _merge([]);

      expect(
        _at(merged.tree, 'color.highContrastLight.button.primary.normal'),
        '{color.highContrastLight.brand.normal}',
      );
      expect(
        _at(merged.tree, 'color.highContrastDark.button.primary.normal'),
        '{color.highContrastDark.brand.normal}',
      );
    });

    test('an explicit overlay value stays as written and is not inherited', () {
      final (merged, _) = _merge([
        layer('''
color:
  highContrastLight:
    button:
      primary:
        normal: "{color.light.brand.hover}"'''),
      ]);

      const path = 'color.highContrastLight.button.primary.normal';
      expect(_at(merged.tree, path), '{color.light.brand.hover}');
      expect(merged.inherited, isNot(contains(path)));
      expect(merged.origins[path]?.source, 1);
    });

    test("the overlay wins over a higher layer's change to the base set", () {
      final (merged, _) = _merge([
        layer(
          'color:\n  highContrastLight:\n    brand:\n'
          '      normal: "{palette.brand.700}"',
        ),
        layer('color:\n  light:\n    brand:\n      normal: "#000000"'),
      ]);

      expect(_at(merged.tree, 'color.light.brand.normal'), '#000000');
      expect(
        _at(merged.tree, 'color.highContrastLight.brand.normal'),
        '{palette.brand.700}',
      );
    });
  });
}
