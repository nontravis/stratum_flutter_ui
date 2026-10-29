import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import 'support/catalog_theme.dart';

/// The names under `dependencies`, `dev_dependencies`, and
/// `dependency_overrides` of the pubspec text [source].
Set<String> _dependencyNames(String source) {
  final pubspec = loadYaml(source) as YamlMap;
  return {
    for (final section in const [
      'dependencies',
      'dev_dependencies',
      'dependency_overrides',
    ])
      if (pubspec[section] case final YamlMap map) ...map.keys.cast<String>(),
  };
}

/// Whether [name] is `widgetbook` or one of its `widgetbook_*` packages.
bool _isWidgetbook(String name) => name.startsWith('widgetbook');

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
    expect(_dependencyNames(package).where(_isWidgetbook), isEmpty);
  });
  test('fo11/us01/fr01: the catalog has no widgetbook generator or '
      'annotation', () {
    final names = _dependencyNames(File('pubspec.yaml').readAsStringSync());
    expect(names, isNot(contains('widgetbook_generator')));
    expect(names, isNot(contains('widgetbook_annotation')));
    expect(names, contains('widgetbook'));
  });
  test(
    'fo11/us01/fr01: loadDefaultThemeSet reads the package default theme',
    () async {
      expect((await loadDefaultThemeSet()).dark, isNotNull);
    },
  );
}
