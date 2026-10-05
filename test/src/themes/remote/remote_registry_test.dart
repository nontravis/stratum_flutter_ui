import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';
import 'package:stratum_ui/src/themes/remote/remote_theme_bundle.dart';

import 'remote_fakes.dart';
import 'remote_test_zip.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    useSyncParse();
    recordRemoteFontLoads();
    recordRemoteGoogleFonts();
  });

  test('d3 seam 1: the controller reads through an overlay over the app '
      'bundle, and a bundled theme reads from its folder', () async {
    final bundle = RemoteFakeBundle(
      themes: {'brand': '$remoteSchemaLine\nname: brand'},
    );
    final controller = await StratumThemeController.preload(
      bundle: bundle,
      initialThemeId: 'brand',
    );
    addTearDown(controller.dispose);

    expect(controller.remoteBundle, isA<RemoteThemeBundle>());
    expect(controller.remoteBundle.parent, same(bundle));
    expect(controller.themeIds, ['default', 'brand']);
    expect(bundle.reads['assets/themes/brand/theme.yaml'], 1);
  });
}
