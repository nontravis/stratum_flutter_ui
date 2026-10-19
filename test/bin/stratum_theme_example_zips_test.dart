@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../bin/stratum_theme.dart';

void main() {
  for (final id in ['ocean', 'sunset']) {
    test('us02/fr01/e08, f01/us09/fr01/e03: packing '
        'example/assets/remote_themes/$id gives the committed $id.zip byte '
        'for byte', () async {
      final out = Directory.systemTemp.createTempSync('stratum_theme_ex_');
      addTearDown(() => out.deleteSync(recursive: true));
      final example = p.join(Directory.current.path, 'example');

      final code = await runStratumTheme(
        ['pack', 'assets/remote_themes/$id', '--out', out.path],
        out: StringBuffer(),
        err: StringBuffer(),
        workingDirectory: example,
        packageRoot: Directory.current.path,
      );

      expect(code, exitPass);
      expect(
        File(p.join(out.path, '$id.zip')).readAsBytesSync(),
        File(p.join(example, 'assets', 'remote_themes', '$id.zip'))
            .readAsBytesSync(),
      );
    });
  }
}
