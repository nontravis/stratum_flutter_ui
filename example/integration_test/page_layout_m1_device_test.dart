// Proves the page-layout M1 device cases code can reach, through the
// public surface a device round drives (`StratumThemeApplication` plus
// `context.deviceWindow.radius`), on whichever of pixel_8, pixel_2,
// iphone, mac, chrome, or linux the round runs this on; gated by the
// platform and probe behavior the run observes, never by device name
// (the cases are listed below by what proves them).
//
// Already proven, not re-derived here:
// - The mocked Dart-side consequence of each probe answer (a mocked
//   event publishes the radius; a mocked null keeps it null), and E06 (a
//   probe change rebuilds the radius reader once, never a sibling):
//   `test/src/components/common/responsive/screen_radius_scope_test.dart:173-199,412-475`.
// - E02 (Android API 30 reads null): same file, `:337-361`.
//
// New here:
// - Unmocked, on the real OS this run's own `dart:io` reports (no device
//   name, no channel mock): E01 (Android API 31+ reads Flutter's own
//   filled value), E05 (Windows, Linux, and web read null), and the
//   E03/E04 pair this file's own `AUTHOR` brief names directly — the real
//   native probe on a real iPhone or Mac, gated on the real OS major
//   version this run reads from `Platform.operatingSystemVersion`, never
//   a mock: non-null on iOS 26+ and macOS 27+, null on iOS 25 or earlier
//   and macOS 26 or earlier. A native-probe regression that always
//   answers null, or the wrong corners, on a real iOS 26 or macOS 27
//   device fails this test; no widget test anywhere drives the real
//   plugin, so this is the one place that catches it.
// - F6 (a nested application's outer `ScreenRadiusScope` keeps every
//   probe event once the inner one leaves) and the app-restarted-by-key
//   case (a remounted scope reads the probe's last value before its own
//   first event arrives), both only reachable through
//   `StratumThemeApplication` since `ScreenRadiusScope` itself has no
//   public export (`lib/src/components/common/responsive/responsive.dart`
//   lists `device_window.dart`, `keyboard_visibility_scope.dart`, and
//   `window_size_scope.dart` only) — a seam gap this file works around by
//   mocking the probe's own wire channel, `stratum_ui/screen_radius`, the
//   one contract a native plugin build also speaks. These two stay
//   mocked since no unmocked run can force a leave-then-rejoin or a
//   remount on demand.
//
// Known gap: the mocked test cannot call `ScreenRadiusScope.reset()`
// between tests, since the scope is not exported either — reported to
// main as a `lib/` export seam. Each mocked test restores the channel
// handler in `addTearDown`, but a failed run still risks leaving the
// process-wide probe subscription live for the next test, per the
// scope's own doc comment.
//
// Code cannot judge:
// - The probe's own fallback order on a cold start
//   (`UIWindow.didBecomeKeyNotification`, a scene geometry change) and an
//   iPad windowed-mode resize: OS-level timing with no Dart hook to
//   observe.
//
//   flutter test integration_test/page_layout_m1_device_test.dart -d <device>
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stratum_ui/stratum_ui.dart';

import 'support/os_major_version.dart';

/// The native radius probe's wire channel (`lib/src/components/common/responsive/screen_radius_scope.dart:101`);
/// duplicated here since the scope that owns it is not a public export.
const _probeChannel = EventChannel('stratum_ui/screen_radius');

const _r40 = {
  'topLeft': 40.0,
  'topRight': 40.0,
  'bottomLeft': 40.0,
  'bottomRight': 40.0,
};

const _r20 = {
  'topLeft': 20.0,
  'topRight': 20.0,
  'bottomLeft': 20.0,
  'bottomRight': 20.0,
};

/// Whether this run's own platform subscribes to the probe at all
/// (`_darwin` in `screen_radius_scope.dart`): the gate this file reads at
/// runtime instead of a device name.
bool get _subscribesToProbe =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS);

/// Mocks the probe channel for one test: [onListen] gets the sink the
/// scope's `listen` call opens.
void _mockProbe(
  WidgetTester tester,
  void Function(MockStreamHandlerEventSink sink) onListen,
) {
  tester.binding.defaultBinaryMessenger.setMockStreamHandler(
    _probeChannel,
    // A block body, never `=>`: an expression body's value becomes the
    // mock's reply, and `onListen`'s own cascade return would leak in as
    // an unencodable `listen` reply (an object the codec cannot encode).
    MockStreamHandler.inline(
      onListen: (_, sink) {
        onListen(sink);
      },
    ),
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockStreamHandler(
      _probeChannel,
      null,
    ),
  );
}

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

  testWidgets(
    'f6: the outermost ScreenRadiusScope keeps every probe event once a '
    'nested application leaves, and a remounted app reads the probe\'s '
    'last value before its own first event (app restarted by key)',
    (tester) async {
      if (!_subscribesToProbe) {
        markTestSkipped(
          'only iOS and macOS subscribe to the native radius probe; this '
          'run is $defaultTargetPlatform',
        );
        return;
      }
      final outerController = await StratumThemeController.preload();
      addTearDown(outerController.dispose);
      final innerController = await StratumThemeController.preload();
      addTearDown(innerController.dispose);
      late MockStreamHandlerEventSink sink;
      _mockProbe(tester, (s) => sink = s..success(_r40));

      BorderRadius? outer = BorderRadius.zero;
      BorderRadius? inner = BorderRadius.zero;
      // The outer app stands for the running app; the inner one, nested
      // under it with no key of its own carried across, stands for a
      // splash screen shown in front of it a moment.
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => StratumThemeApplication.controlled(
            controller: outerController,
            themeMode: ThemeMode.light,
            child: Builder(
              builder: (context) {
                outer = context.deviceWindow.radius;
                return child!;
              },
            ),
          ),
          home: MaterialApp(
            builder: (context, child) => StratumThemeApplication.controlled(
              controller: innerController,
              themeMode: ThemeMode.light,
              child: child!,
            ),
            home: Builder(
              builder: (context) {
                inner = context.deviceWindow.radius;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(outer, const BorderRadius.all(Radius.circular(40)));
      expect(
        inner,
        const BorderRadius.all(Radius.circular(40)),
        reason:
            'ScreenRadiusScope.hasScope keeps a nested application from '
            'inserting a second scope, so the inner app reads the same '
            'MediaQuery aspect the outer scope publishes',
      );

      // The inner application leaves, as a splash does once it settles.
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => StratumThemeApplication.controlled(
            controller: outerController,
            themeMode: ThemeMode.light,
            child: Builder(
              builder: (context) {
                outer = context.deviceWindow.radius;
                return child!;
              },
            ),
          ),
          home: const SizedBox(),
        ),
      );
      await tester.pumpAndSettle();

      // A later probe event (standing for a rotation) still reaches the
      // one scope the outer app kept mounted.
      sink.success(_r20);
      await tester.pump();
      await tester.pump();
      expect(
        outer,
        const BorderRadius.all(Radius.circular(20)),
        reason:
            'the shared subscription outlives the inner application, so '
            'the outer scope keeps following the probe (F6)',
      );

      // The whole app remounts, as a restart by key does; a fresh pump
      // with a brand new element tree, mocked to answer `listen` with no
      // value of its own yet.
      _mockProbe(tester, (s) => sink = s);
      final remountController = await StratumThemeController.preload();
      addTearDown(remountController.dispose);
      BorderRadius? remounted = BorderRadius.zero;
      await tester.pumpWidget(
        MaterialApp(
          key: UniqueKey(),
          builder: (context, child) => StratumThemeApplication.controlled(
            controller: remountController,
            themeMode: ThemeMode.light,
            child: child!,
          ),
          home: Builder(
            builder: (context) {
              remounted = context.deviceWindow.radius;
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        remounted,
        const BorderRadius.all(Radius.circular(20)),
        reason:
            'the remounted scope seeds from the probe\'s last known value '
            'before its own listen call ever answers',
      );
    },
  );
}
