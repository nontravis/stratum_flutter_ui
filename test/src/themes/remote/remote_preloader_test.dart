import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import 'remote_fakes.dart';
import 'remote_test_zip.dart';

void main() {
  setUp(() {
    useSyncParse();
    recordRemoteFontLoads();
    recordRemoteGoogleFonts();
  });

  testWidgets('us01/fr04: the preloader installs kept zips and reports the '
      'one that fails', (tester) async {
    final errors = <(String, StratumRemoteThemeErrorCode)>[];
    final good = remoteTheme('brand');
    final bad = StratumRemoteTheme(
      id: 'songkran',
      bytes: good.bytes,
      checksum: checksumOf([0]),
    );

    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: RemoteFakeBundle(),
        child: StratumThemePreloader(
          initialThemeId: 'brand',
          remoteThemes: [bad, good],
          onRemoteThemeError: (id, error) => errors.add((id, error.code)),
          builder: (context, controller) => Text(
            'ready ${controller.activeId} ${controller.themeIds.join(',')}',
            textDirection: TextDirection.ltr,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ready brand default,brand'), findsOneWidget);
    expect(errors, [
      ('songkran', StratumRemoteThemeErrorCode.checksumMismatch),
    ]);
  });

  testWidgets('q11/minor3, us01/fr04/e02, s03/inv11: an initialThemeId whose '
      'kept zip fails starts the app on default', (tester) async {
    final errors = <(String, StratumRemoteThemeErrorCode)>[];
    final good = remoteTheme('brand');
    final bad = StratumRemoteTheme(
      id: 'songkran',
      bytes: good.bytes,
      checksum: checksumOf([0]),
    );

    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: RemoteFakeBundle(),
        child: StratumThemePreloader(
          initialThemeId: 'songkran',
          remoteThemes: [bad, good],
          onRemoteThemeError: (id, error) => errors.add((id, error.code)),
          builder: (context, controller) => Text(
            'ready ${controller.activeId} ${controller.themeIds.join(',')}',
            textDirection: TextDirection.ltr,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ready default default,brand'), findsOneWidget);
    expect(errors, [
      ('songkran', StratumRemoteThemeErrorCode.checksumMismatch),
    ]);
  });
}
