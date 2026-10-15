@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/themes/config/pipeline/load_yaml_text.dart';

void main() {
  for (final path in [
    'assets/themes/default/theme.yaml',
    'example/assets/remote_themes/ocean/theme.yaml',
    'example/assets/remote_themes/sunset/theme.yaml',
    'pubspec.yaml',
    'example/pubspec.yaml',
  ]) {
    test(
      'fo01 fo01/us01/fr01/e07, g4, g10: the committed file $path passes the '
      'gate',
      () {
        expect(
          () => checkYamlGate(File(path).readAsStringSync()),
          returnsNormally,
        );
      },
    );
  }
}
