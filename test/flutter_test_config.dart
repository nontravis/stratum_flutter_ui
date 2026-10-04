import 'dart:async';

import 'package:stratum_ui/src/themes/typography/google_fonts_lookup.dart';

/// Runs every test of the package with a Google Fonts family lookup that
/// answers the bare family name and starts no fetch.
///
/// The package default theme names its fonts as Google fonts (FO-02 US-07
/// FR-01 E06), and `GoogleFonts.getFont` would load each one over HTTP. A
/// test that checks the lookup replaces it and restores this fake in
/// `tearDown`.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFontsLookup.family = (name, {required weight, required style}) => name;
  await testMain();
}
