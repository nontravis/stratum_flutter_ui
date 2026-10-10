import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart' show LottieBuilder;
import 'package:stratum_ui/src/src.dart';

import '../components/common/fakes/fake_stratum_theme.dart';

const _placeholder = SizedBox(key: ValueKey('placeholder'));

/// [fakeTheme] whose `loading` slot is [kind] at [path].
StratumThemeData _withLoading(StratumAssetKind kind, String path) =>
    fakeTheme.copyWith(
      assets: StratumAssetTokens.fromMap({
        'loading': StratumThemeAsset(kind: kind, path: path),
      }),
    );

Widget _view(StratumThemeData theme, {bool disableAnimations = false}) =>
    MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: themedHost(
        const StratumThemeAssetView.loading(placeholder: _placeholder),
        theme: theme,
      ),
    );

void main() {
  final kinds = <(StratumAssetKind, String, Type)>[
    (StratumAssetKind.image, 'themes/app/loading.png', Image),
    (StratumAssetKind.svg, 'themes/app/loading.svg', SvgPicture),
    (StratumAssetKind.lottie, 'themes/app/loading.json', LottieBuilder),
    (StratumAssetKind.lottie, 'themes/app/loading.lottie', LottieBuilder),
  ];
  for (final (kind, path, type) in kinds) {
    testWidgets('fr02: $path builds $type', (tester) async {
      await tester.pumpWidget(_view(_withLoading(kind, path)));

      expect(find.byType(type), findsOneWidget);
    });
  }

  testWidgets('fr02/e02: an empty slot shows the placeholder', (tester) async {
    await tester.pumpWidget(_view(fakeTheme));

    expect(find.byKey(const ValueKey('placeholder')), findsOneWidget);
  });

  testWidgets('the splash screen slot reads splash-screen', (tester) async {
    await tester.pumpWidget(
      themedHost(
        const StratumThemeAssetView.splashScreen(placeholder: _placeholder),
        theme: fakeTheme.copyWith(
          assets: StratumAssetTokens.fromMap({
            'splash-screen': const StratumThemeAsset(
              kind: StratumAssetKind.svg,
              path: 'themes/app/splash.svg',
            ),
          }),
        ),
      ),
    );

    expect(find.byType(SvgPicture), findsOneWidget);
  });

  testWidgets('fr02/e01: a theme switch shows the new theme asset', (
    tester,
  ) async {
    String assetName() =>
        (tester.widget<Image>(find.byType(Image)).image as AssetImage)
            .assetName;

    await tester.pumpWidget(
      _view(_withLoading(StratumAssetKind.image, 'themes/a/loading.png')),
    );
    expect(assetName(), 'themes/a/loading.png');

    await tester.pumpWidget(
      _view(_withLoading(StratumAssetKind.image, 'themes/b/loading.png')),
    );
    expect(assetName(), 'themes/b/loading.png');
  });

  final missingKinds = <(StratumAssetKind, String)>[
    (StratumAssetKind.image, 'themes/app/missing.png'),
    (StratumAssetKind.svg, 'themes/app/missing.svg'),
    (StratumAssetKind.lottie, 'themes/app/missing.json'),
  ];
  for (final (kind, path) in missingKinds) {
    testWidgets('a $kind file missing from the bundle shows the '
        'placeholder', (tester) async {
      await tester.pumpWidget(_view(_withLoading(kind, path)));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('placeholder')), findsOneWidget);
    });
  }

  testWidgets('NFR-U03: a Lottie asset holds a still frame under reduced '
      'motion', (tester) async {
    await tester.pumpWidget(
      _view(
        _withLoading(StratumAssetKind.lottie, 'themes/app/loading.json'),
        disableAnimations: true,
      ),
    );

    expect(
      tester.widget<LottieBuilder>(find.byType(LottieBuilder)).animate,
      isFalse,
    );
  });

  testWidgets('us07/fr02/e05, NFR-U03: an animated image pauses on its '
      'first frame too, under the platform reduce-motion flag alone', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(
      _view(_withLoading(StratumAssetKind.image, 'themes/app/loading.png')),
    );

    expect(
      tester
          .widget<TickerMode>(
            find.ancestor(
              of: find.byType(Image),
              matching: find.byType(TickerMode),
            ),
          )
          .enabled,
      isFalse,
    );
  });
}
