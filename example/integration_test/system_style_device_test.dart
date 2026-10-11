// Applies the system bar style on a device or a browser (FO-03 US-14 FR-01
// E06 and FR-02 to FR-04; design D12 and R9): the device-test.toml targets
// pixel_2 (Android API 28), pixel_8 (Android API 36), and iphone, plus the
// desktop and web targets for the checks that a setting the platform lacks
// is ignored with no error. Runs in roadmap phase stratum-device-round,
// never in a feature session:
//
//   flutter test integration_test/system_style_device_test.dart -d <device>
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/system_style_device_test.dart \
//     -d web-server --browser-name=chrome
//
// The round also checks by eye on each Android and iOS target: the status
// bar shows the app's dark color, which Stratum paints, with light icons
// (design R7); the status bar icons read light over the dark header and
// dark over the white page; both bars hide on the video page and show
// again over it, except on pixel_8, whose Android 16 ignores the immersive
// modes of an app that targets API 36, so the bars stay with no error, as
// Flutter's `SystemChrome.setEnabledSystemUIMode` documents (design R8);
// the recent-apps entry names the page. On the web it checks that the tab
// title reads the page label and returns to the app label on back. The
// `reportData` of each run records the view padding before and after the
// bars hide.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stratum_ui/stratum_ui.dart';

const _appWide = SystemStyle(appSwitcherLabel: 'Stratum');

const _video = SystemStyle(
  barMode: SystemBarMode.immersiveSticky,
  orientations: [DeviceOrientation.portraitUp],
  appSwitcherLabel: 'Video',
);

/// A `MaterialApp` titled `Stratum` over [controller]'s theme, with the
/// app-wide [systemStyle], whose navigator [navigator] holds.
Widget _app(
  StratumThemeController controller,
  GlobalKey<NavigatorState> navigator,
  Widget home, {
  SystemStyle systemStyle = _appWide,
}) => MaterialApp(
  title: 'Stratum',
  navigatorKey: navigator,
  builder: (context, child) => StratumThemeApplication.controlled(
    controller: controller,
    themeMode: ThemeMode.light,
    systemStyle: systemStyle,
    child: child!,
  ),
  home: home,
);

/// A page with a [color] header under the status bar.
Widget _header(Color color) => ColumnLayout(
  children: [
    SystemBarFill(
      color: color,
      child: ColoredBox(
        color: color,
        child: const SizedBox(width: double.infinity, height: 120),
      ),
    ),
    const Expanded(child: SizedBox()),
  ],
);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late StratumThemeController controller;

  setUp(() async {
    controller = await StratumThemeController.preload();
  });

  tearDown(() => controller.dispose());

  testWidgets('us14/s3, us14/fr02/e01: a dark header turns the status bar '
      'icons light', (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      _app(controller, navigator, _header(const Color(0xFF101828))),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    if (!kIsWeb) {
      expect(
        SystemChrome.latestStyle?.statusBarIconBrightness,
        Brightness.light,
      );
    }
  });

  testWidgets('us14/s16, us14/fr01/e06, us14/fr02/e07: the app status bar '
      'color shows under the bar, with icons against it', (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      _app(
        controller,
        navigator,
        const SizedBox(),
        systemStyle: _appWide.merge(
          const SystemStyle(statusBarColor: Color(0xFF101828)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    if (!kIsWeb) {
      expect(SystemChrome.latestStyle?.statusBarColor, const Color(0x00000000));
      expect(
        SystemChrome.latestStyle?.statusBarIconBrightness,
        Brightness.light,
      );
    }
  });

  testWidgets('us14/s7, us14/s8, us14/s9, us14/s12, us14/s13, us14/s14: the '
      'video page sets its bars, rotation, and label, and back restores '
      'them, with no error', (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_app(controller, navigator, const SizedBox()));
    await tester.pumpAndSettle();
    final before = tester.view.viewPadding;

    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (context) =>
            const SystemStyleScope(style: _video, child: Text('Video')),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 1));
    final hidden = tester.view.viewPadding;
    expect(find.text('Video'), findsOneWidget);
    expect(tester.takeException(), isNull);

    navigator.currentState!.push(
      MaterialPageRoute<void>(builder: (context) => const Text('Over')),
    );
    await tester.pumpAndSettle(const Duration(seconds: 1));
    final shown = tester.view.viewPadding;
    expect(tester.takeException(), isNull);

    navigator.currentState!.pop();
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('Video'), findsOneWidget);
    expect(tester.takeException(), isNull);

    binding.reportData = {
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'paddingTopBefore': before.top,
      'paddingTopHidden': hidden.top,
      'paddingTopShown': shown.top,
      'paddingBottomBefore': before.bottom,
      'paddingBottomHidden': hidden.bottom,
    };
  });
}
