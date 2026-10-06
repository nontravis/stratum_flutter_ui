@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('us01/fr02/e04, s03 invariant 13: lib/src/themes/remote/ imports no '
      'dart:io, so no install writes a file', () {
    final files = Directory('lib/src/themes/remote')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList();

    expect(files, isNotEmpty);
    for (final file in files) {
      expect(
        file.readAsStringSync(),
        isNot(contains("'dart:io'")),
        reason: file.path,
      );
    }
  });
}
