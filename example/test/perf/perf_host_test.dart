// The test reaches GoogleFonts through the src barrel, as the perf host
// does: the example does not depend on google_fonts directly.
// ignore_for_file: implementation_imports
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import '../../integration_test/perf/perf_host.dart';

/// Every Google font file the example bundles: the weights the default
/// theme's yaml declares for the types that use each font, under the file
/// name google_fonts matches.
const _bundled = [
  ('Inter', FontWeight.w400, 'assets/google_fonts/inter/Inter-Regular.ttf'),
  ('Inter', FontWeight.w600, 'assets/google_fonts/inter/Inter-SemiBold.ttf'),
  ('Geist', FontWeight.w600, 'assets/google_fonts/geist/Geist-SemiBold.ttf'),
  (
    'Geist Mono',
    FontWeight.w600,
    'assets/google_fonts/geistmono/GeistMono-SemiBold.ttf',
  ),
  (
    'Roboto Mono',
    FontWeight.w400,
    'assets/google_fonts/robotomono/RobotoMono-Regular.ttf',
  ),
  (
    'Roboto Mono',
    FontWeight.w600,
    'assets/google_fonts/robotomono/RobotoMono-SemiBold.ttf',
  ),
  ('Kanit', FontWeight.w400, 'assets/google_fonts/kanit/Kanit-Regular.ttf'),
  ('Kanit', FontWeight.w600, 'assets/google_fonts/kanit/Kanit-SemiBold.ttf'),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadPerfTheme);

  test('loadPerfTheme turns Google Fonts runtime fetching off', () {
    expect(GoogleFonts.config.allowRuntimeFetching, isFalse);
  });

  test('the asset manifest lists every bundled Google font file', () async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);

    expect(
      manifest.listAssets(),
      containsAll([for (final (_, _, path) in _bundled) path]),
    );
  });

  test('fo03/us05/fr02/e03: every bundled weight loads from the assets '
      'with fetching off', () async {
    for (final (family, weight, _) in _bundled) {
      GoogleFonts.getFont(family, fontWeight: weight);
      await GoogleFonts.pendingFonts();
    }
  });

  test(
    'a weight the example does not bundle fails instead of fetching',
    () async {
      final printed = <String>[];
      final saved = debugPrint;
      debugPrint = (message, {wrapWidth}) => printed.add(message ?? '');
      addTearDown(() => debugPrint = saved);

      GoogleFonts.getFont('Inter', fontWeight: FontWeight.w500);

      await expectLater(
        GoogleFonts.pendingFonts(),
        throwsA(
          isA<Exception>().having(
            (error) => '$error',
            'message',
            contains('allowRuntimeFetching is false but font Inter-Medium'),
          ),
        ),
      );
      expect(printed.first, contains('unable to load font Inter-Medium'));
    },
  );
}
