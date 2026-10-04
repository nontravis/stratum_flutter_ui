import 'dart:async';

import 'package:stratum_ui/src/themes/typography/google_fonts_lookup.dart';

/// Runs every example test with a Google Fonts family lookup that answers
/// the bare family name and starts no fetch: the package default theme the
/// demos load names its fonts as Google fonts.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFontsLookup.family = (name, {required weight, required style}) => name;
  await testMain();
}
