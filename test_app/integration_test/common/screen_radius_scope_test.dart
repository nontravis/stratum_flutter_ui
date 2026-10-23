// Proves the screen-radius cases of FO-07 US-04 FR-03 that need the real OS,
// through the public surface a device round drives (`StratumThemeApplication`
// plus `context.deviceWindow.radius`), gated by the platform and probe
// behavior the run observes, never by device name:
//
// - Unmocked, on the real OS this run's own `dart:io` reports: E01 (Android
//   API 31+ reads Flutter's own filled value), E05 (Windows, Linux, and web
//   read null), and the E03/E04 pair, the real native probe on a real iPhone
//   or Mac, gated on the real OS major version this run reads from
//   `Platform.operatingSystemVersion`: non-null on iOS 26+ and macOS 27+,
//   null on iOS 25 or earlier and macOS 26 or earlier. A native-probe
//   regression that always answers null, or the wrong corners, on a real iOS
//   26 or macOS 27 device fails this test; no widget test drives the real
//   plugin.
//
// The mocked consequence of each probe answer is a widget test:
// `test/src/components/common/responsive/screen_radius_scope_test.dart` and
// `test/src/themes/theme_application_test.dart`.
//
//   flutter test integration_test/common/screen_radius_scope_test.dart -d <device>
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/common/screen_radius_scope_test.dart \
//     -d web-server --browser-name=chrome
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stratum_ui/stratum_ui.dart';

import 'support/os_major_version.dart';

/// Whether this run's own platform subscribes to the probe at all
/// (`_darwin` in `screen_radius_scope.dart`): the gate this file reads at
/// runtime instead of a device name.
bool get _subscribesToProbe =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS);

/// A minimal app wrapper the device round's own boot path also builds:
/// one `StratumThemeApplication` over a radius reader, sharing
/// [controller] across every pump so the preloaded theme loads once.
Widget _radiusApp(
  StratumThemeController controller,
  void Function(BorderRadius?) onRadius,
) => MaterialApp(
  builder: (context, child) => StratumThemeApplication.controlled(
    controller: controller,
    themeMode: ThemeMode.light,
    child: child!,
  ),
  home: Builder(
    builder: (context) {
      onRadius(context.deviceWindow.radius);
      return const SizedBox();
    },
  ),
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'fo07/us04/fr03: a Flutter-filled radius (Android API 31+) is never '
    'overridden, and Windows/Linux/web/API-30 Android read null with no '
    "probe mocked (E01, E05)",
    (tester) async {
      final controller = await StratumThemeController.preload();
      addTearDown(controller.dispose);
      const flutterValue = BorderRadius.all(Radius.circular(28));
      BorderRadius? radius = BorderRadius.zero;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(displayCornerRadii: flutterValue),
          child: _radiusApp(controller, (r) => radius = r),
        ),
      );
      await tester.pumpAndSettle();

      expect(radius, flutterValue);

      BorderRadius? noFlutterValue = BorderRadius.zero;
      await tester.pumpWidget(
        _radiusApp(controller, (r) => noFlutterValue = r),
      );
      await tester.pumpAndSettle();

      if (!_subscribesToProbe) {
        expect(
          noFlutterValue,
          isNull,
          reason:
              'with no Flutter-filled radius and no probe subscription, '
              'the window reports no corner radii at all',
        );
      }
    },
  );

  testWidgets(
    'fo07/us04/fr03/e03,e04: on the real OS this run reports, unmocked, '
    'radius is non-null on iOS 26+ and macOS 27+, and null on an older '
    'iOS or macOS, Android, Windows, Linux, and web',
    (tester) async {
      final controller = await StratumThemeController.preload();
      addTearDown(controller.dispose);
      BorderRadius? radius = BorderRadius.zero;
      await tester.pumpWidget(_radiusApp(controller, (r) => radius = r));
      await tester.pumpAndSettle();

      if (!_subscribesToProbe) {
        expect(
          radius,
          isNull,
          reason:
              'Android, Windows, Linux, and web read no corner radii '
              'with no plugin subscribed and nothing filling '
              'displayCornerRadii',
        );
        return;
      }
      final cutoff = defaultTargetPlatform == TargetPlatform.iOS ? 26 : 27;
      final major = realOSMajorVersion;
      final expectNonNull = major != null && major >= cutoff;
      expect(
        radius,
        expectNonNull ? isNotNull : isNull,
        reason: expectNonNull
            ? 'the real native probe on $defaultTargetPlatform $major '
                  'should answer with the real screen corners, not stay '
                  'unreadable'
            : 'an older $defaultTargetPlatform than $cutoff has no probe '
                  'to answer, so the radius stays unreadable, null',
      );
    },
  );
}
