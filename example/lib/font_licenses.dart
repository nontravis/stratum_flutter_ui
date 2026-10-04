import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The folder under `assets/google_fonts/` of each Google font family the
/// example bundles, keyed by the family name: the default theme's fonts at
/// the weights its yaml declares, each folder with the family's `OFL.txt`.
const googleFontFolders = {
  'Inter': 'inter',
  'Geist': 'geist',
  'Geist Mono': 'geistmono',
  'Roboto Mono': 'robotomono',
  'Kanit': 'kanit',
};

/// Adds the SIL Open Font License text of every bundled Google font family
/// to the [LicenseRegistry], one entry per family, so the license page
/// lists it. Each example entry calls it at the top of its `main`.
void registerGoogleFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final MapEntry(key: family, value: folder)
        in googleFontFolders.entries) {
      yield LicenseEntryWithLineBreaks([
        family,
      ], await rootBundle.loadString('assets/google_fonts/$folder/OFL.txt'));
    }
  });
}
