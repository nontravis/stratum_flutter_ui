import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import 'remote_fakes.dart';

/// The package default's Google families, which a zip theme merges over.
const _baseGoogle = ['Inter', 'Geist', 'Geist Mono', 'Roboto Mono', 'Kanit'];

const _brand = '''
color:
  light:
    app: { mango: "#FFAA00" }
  dark:
    app: { mango: "#AA7700" }
assets:
  loading: images/loading.png
typography:
  fonts:
    brand: { family: Prompt, files: [fonts/Prompt-Regular.ttf] }
  families:
    default:
      body: brand''';

const _google = '''
typography:
  fonts:
    prompt: { family: Google/Prompt }
  families:
    default:
      body: prompt''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<(String, int)> loads;
  late List<String> google;
  setUp(() {
    useSyncParse();
    loads = recordRemoteFontLoads();
    google = recordRemoteGoogleFonts();
  });

  test("d5, fo04/us01/s1, fo04/us01/s2: install then switch shows the zip's colors, "
      'fonts, and asset', () async {
    final controller = await StratumThemeController.preload(
      bundle: RemoteFakeBundle(),
    );
    addTearDown(controller.dispose);

    await controller.install(
      remoteTheme(
        'brand',
        body: _brand,
        files: {
          'fonts/Prompt-Regular.ttf': [1, 2, 3],
          'images/loading.png': [4, 5],
        },
      ),
    );
    await controller.switchTo('brand');

    final light = controller.themes.light;
    expect(light.appColors['mango'], const Color(0xFFFFAA00));
    expect(light.typography.fonts['brand']!.family, 'brand@1/Prompt');
    expect(loads, [('brand@1/Prompt', 1)]);
    expect(
      light.assets.loading!.path,
      'stratum-remote/brand/1/images/loading.png',
    );
    expect(
      (await controller.remoteBundle.load(light.assets.loading!.path)).buffer
          .asUint8List(),
      [4, 5],
    );
  });

  test('fo04/us01/s2, typography s01 FO-04 row: body text resolves to the zip '
      'font family, and the zip font asks Google for nothing', () async {
    final controller = await StratumThemeController.preload(
      bundle: RemoteFakeBundle(),
    );
    addTearDown(controller.dispose);
    await controller.install(
      remoteTheme(
        'brand',
        body: _brand,
        files: {
          'fonts/Prompt-Regular.ttf': [1, 2, 3],
          'images/loading.png': [4, 5],
        },
      ),
    );
    await controller.switchTo('brand');
    google.clear();

    final style = TypographyResolver.resolve(
      StratumTextStyle.body.s16,
      theme: controller.themes.light,
      locale: const Locale('en'),
      windowSize: WindowSize.mobile,
      textScaler: TextScaler.noScaling,
    );

    expect(style.fontFamily, 'brand@1/Prompt');
    expect(google, everyElement(isIn(_baseGoogle)));
  });

  test("fo04/us01/s7, fo04/us01/fr03/e10: a Google font a zip names loads by FO-03's "
      'path, with no download path of its own', () async {
    final controller = await StratumThemeController.preload(
      bundle: RemoteFakeBundle(),
    );
    addTearDown(controller.dispose);
    google.clear();

    await controller.install(remoteTheme('brand', body: _google));
    await controller.switchTo('brand');

    expect(google, contains('Prompt'));
    expect(loads, isEmpty);
  });
}
