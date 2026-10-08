import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/themes/remote/remote_zip_reader.dart';

import 'tool_zips/tool_zips.g.dart';

void main() {
  for (final tool in ['finder', 'infoZip', 'javaDefault']) {
    test('us01/fr02/e02, us01/fr02/e13, rz3: a theme zipped by $tool '
        'installs', () {
      final read = readRemoteZip(
        base64.decode(toolZips[tool]!),
        maxBytes: 20 * 1024 * 1024,
        maxEntries: 200,
      );

      expect(
        read.files.keys,
        unorderedEquals(['theme.yaml', 'images/logo.svg']),
      );
    });
  }
}
