import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import 'support/catalog_theme.dart';

void main() {
  test('fo11/us01/fr01: the catalog depends on stratum_ui by path', () {
    final catalog =
        loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;
    expect(catalog['name'], 'stratum_ui_widgetbook');
    expect((catalog['dependencies'] as YamlMap)['stratum_ui'], {'path': '../'});
    expect((catalog['dependencies'] as YamlMap)['widgetbook'], '4.0.0-beta.14');
  });
  test('fo11/us01/fr01/e01: the package depends on no catalog code', () {
    final package = File('../pubspec.yaml').readAsStringSync();
    expect(package, isNot(contains('stratum_ui_widgetbook')));
    expect(package, isNot(contains('widgetbook:')));
  });
  test(
    'fo11/us01/fr01: loadDefaultThemeSet reads the package default theme',
    () async {
      expect((await loadDefaultThemeSet()).dark, isNotNull);
    },
  );
}
