import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/stratum_ui.dart';
import 'package:stratum_ui_example/remote_theme_demo.dart';

Uint8List _zip(String id) =>
    File('assets/remote_themes/$id.zip').readAsBytesSync();

/// A controller that preloaded ocean from its kept zip, as `main` does.
Future<StratumThemeController> _preload(WidgetTester tester) async {
  final controller = (await tester.runAsync(
    () => StratumThemeController.preload(
      initialThemeId: 'ocean',
      remoteThemes: [
        StratumRemoteTheme(
          id: 'ocean',
          bytes: _zip('ocean'),
          checksum: oceanChecksum,
        ),
      ],
    ),
  ))!;
  addTearDown(controller.dispose);
  return controller;
}

void main() {
  testWidgets('us09/s1, us09/fr01: the recipe starts on ocean from its kept '
      'zip, its image read from the zip', (tester) async {
    final controller = await _preload(tester);

    await tester.pumpWidget(
      RemoteThemeDemoApp(controller: controller, sunsetZip: _zip('sunset')),
    );

    expect(controller.activeId, 'ocean');
    expect(find.text('Theme: ocean'), findsOneWidget);
    final loader =
        tester.widget<SvgPicture>(find.byType(SvgPicture)).bytesLoader
            as SvgAssetLoader;
    expect(loader.assetName, startsWith('stratum-remote/ocean/'));
    expect(loader.assetName, endsWith('/images/wave.svg'));
    final bytes = await tester.runAsync(
      () => loader.assetBundle!.load(loader.assetName),
    );
    expect(
      bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      equals(
        File('assets/remote_themes/ocean/images/wave.svg').readAsBytesSync(),
      ),
    );
  });

  testWidgets('us09/s2: "Install sunset" installs it and switches at once', (
    tester,
  ) async {
    final controller = await _preload(tester);
    await tester.pumpWidget(
      RemoteThemeDemoApp(controller: controller, sunsetZip: _zip('sunset')),
    );

    await tester.tap(find.text('Install sunset'));
    await tester.pumpAndSettle();

    expect(controller.activeId, 'sunset');
    expect(find.text('Theme: sunset'), findsOneWidget);
  });

  testWidgets('us09/s3, us09/fr01/e01: "Install broken zip" shows '
      'checksum_mismatch and its message, and the theme stays', (tester) async {
    final controller = await _preload(tester);
    await tester.pumpWidget(
      RemoteThemeDemoApp(controller: controller, sunsetZip: _zip('sunset')),
    );

    await tester.tap(find.text('Install broken zip'));
    await tester.pumpAndSettle();

    expect(controller.activeId, 'ocean');
    expect(find.text('Theme: ocean'), findsOneWidget);
    expect(
      find.textContaining(RegExp(r'^checksum_mismatch: .+')),
      findsOneWidget,
    );
  });

  testWidgets('us09/fr01/e03: each committed zip installs under its Dart '
      'checksum, so its SHA-256 equals the constant', (tester) async {
    final controller = await _preload(tester);

    await tester.runAsync(
      () => controller.install(
        StratumRemoteTheme(
          id: 'sunset',
          bytes: _zip('sunset'),
          checksum: sunsetChecksum,
        ),
      ),
    );

    expect(controller.themeIds, containsAll(['ocean', 'sunset']));
  });
}
