import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import 'remote_fakes.dart';
import 'remote_test_zip.dart';

const _placeholder = SizedBox(key: ValueKey('placeholder'));

/// A minimal valid svg, because flutter_svg 2.3.0 leaks the parse error of
/// invalid bytes into the test zone.
const _svg =
    '<svg xmlns="http://www.w3.org/2000/svg" width="4" height="4"> '
    '<rect width="4" height="4"/></svg>';

Widget _host(
  Widget child, {
  StratumThemeController? controller,
  StratumThemeSet? themes,
}) => MediaQuery(
  data: const MediaQueryData(size: Size(400, 800)),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: controller != null
        ? StratumThemeApplication.controlled(
            controller: controller,
            themeMode: ThemeMode.light,
            child: child,
          )
        : StratumThemeApplication(
            themes: themes!,
            themeMode: ThemeMode.light,
            child: child,
          ),
  ),
);

void main() {
  setUp(() {
    useSyncParse();
    recordRemoteFontLoads();
    recordRemoteGoogleFonts();
  });

  Future<StratumThemeController> controllerOn(
    WidgetTester tester,
    String id, {
    String loading = 'images/loading.png',
    List<int> loadingBytes = const [1, 2],
  }) async {
    final controller = (await tester.runAsync(() async {
      final c = await StratumThemeController.preload(
        bundle: RemoteFakeBundle(
          themes: {
            'bundled': '$remoteSchemaLine\nassets:\n  loading: images/b.png',
          },
        ),
      );
      await c.install(
        remoteTheme(
          'brand',
          body: 'assets:\n  loading: $loading',
          files: {loading: loadingBytes},
        ),
      );
      await c.switchTo(id);
      return c;
    }))!;
    addTearDown(controller.dispose);
    return controller;
  }

  testWidgets(
    'd3 seam 3: a remote image slot reads through the overlay bundle',
    (tester) async {
      final controller = await controllerOn(tester, 'brand');
      await tester.pumpWidget(
        _host(
          const StratumThemeAssetView.loading(placeholder: _placeholder),
          controller: controller,
        ),
      );

      final image =
          tester.widget<Image>(find.byType(Image)).image as AssetImage;
      expect(image.assetName, 'stratum-remote/brand/1/images/loading.png');
      expect(image.bundle, same(controller.remoteBundle));
    },
  );

  testWidgets('d3 seam 3: a remote svg slot reads through the overlay bundle', (
    tester,
  ) async {
    final controller = await controllerOn(
      tester,
      'brand',
      loading: 'images/loading.svg',
      loadingBytes: utf8.encode(_svg),
    );
    await tester.pumpWidget(
      _host(
        const StratumThemeAssetView.loading(placeholder: _placeholder),
        controller: controller,
      ),
    );

    final loader =
        tester.widget<SvgPicture>(find.byType(SvgPicture)).bytesLoader
            as SvgAssetLoader;
    expect(loader.assetBundle, same(controller.remoteBundle));
  });

  testWidgets('r10/oq3, fo03 us07/fr02/e04: a bundled slot keeps the default '
      'asset bundle', (tester) async {
    final controller = await controllerOn(tester, 'bundled');
    await tester.pumpWidget(
      _host(
        const StratumThemeAssetView.loading(placeholder: _placeholder),
        controller: controller,
      ),
    );

    final image = tester.widget<Image>(find.byType(Image)).image as AssetImage;
    expect(image.assetName, 'assets/themes/bundled/images/b.png');
    expect(image.bundle, isNull);
  });

  testWidgets('review focus 5: a remote slot with no controller above shows '
      'the placeholder', (tester) async {
    final controller = await controllerOn(tester, 'brand');
    // The web test harness never answers a root-bundle miss, so the test
    // pins an empty default bundle and the miss stays pure Dart.
    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: RemoteFakeBundle(),
        child: _host(
          const StratumThemeAssetView.loading(placeholder: _placeholder),
          themes: controller.themes,
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('placeholder')), findsOneWidget);
  });
}
