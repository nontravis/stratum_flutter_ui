import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui_example/font_licenses.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every bundled family folder holds its OFL text', () async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);

    expect(
      manifest.listAssets(),
      containsAll([
        for (final folder in googleFontFolders.values)
          'assets/google_fonts/$folder/OFL.txt',
      ]),
    );
  });

  test('registers one OFL entry per bundled family', () async {
    LicenseRegistry.reset();
    addTearDown(LicenseRegistry.reset);
    registerGoogleFontLicenses();

    final entries = await LicenseRegistry.licenses.toList();

    expect([
      for (final entry in entries) ...entry.packages,
    ], googleFontFolders.keys.toList());
    for (final entry in entries) {
      expect(
        entry.paragraphs.map((paragraph) => paragraph.text).join('\n'),
        contains('SIL Open Font License, Version 1.1'),
      );
    }
  });
}
