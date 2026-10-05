@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'default_theme_yaml.g.dart';

void main() {
  test('defaultThemeYaml equals assets/themes/default/theme.yaml', () {
    expect(
      defaultThemeYaml,
      File('assets/themes/default/theme.yaml').readAsStringSync(),
    );
  });
}
