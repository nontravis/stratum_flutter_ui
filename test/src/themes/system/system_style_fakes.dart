import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';
import 'package:stratum_ui/src/themes/system/system_style_resolver.dart';

import '../../components/common/fakes/fake_stratum_theme.dart';

/// The status bar and navigation bar heights of [systemBarsView]: 24 and
/// 16 logical pixels at the test view's device pixel ratio of 3.
const statusBarHeight = 24.0;
const navigationBarHeight = 16.0;

/// Where the theme application paints the status bar color and the
/// navigation bar color on the 800 by 600 test view of [systemBarsView].
const statusStrip = Rect.fromLTWH(0, 0, 800, statusBarHeight);
const navigationStrip = Rect.fromLTRB(0, 600 - navigationBarHeight, 800, 600);

/// Gives the test view a status bar and a navigation bar, records every
/// `SystemChannels.platform` call, and resets the web override after the
/// test. Returns the recorded calls.
List<MethodCall> systemBarsView(WidgetTester tester) {
  tester.view.padding = const FakeViewPadding(top: 72, bottom: 48);
  addTearDown(tester.view.reset);
  final calls = <MethodCall>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      calls.add(call);
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  addTearDown(() => debugSystemStyleIsWebOverride = null);
  return calls;
}

/// The arguments of every recorded call named [method], in order.
List<Object?> argumentsOf(List<MethodCall> calls, String method) => [
  for (final call in calls)
    if (call.method == method) call.arguments,
];

/// The bar mode the last `setEnabledSystemUIMode` call sent, by its
/// `SystemUiMode` name, or null when none was sent.
String? lastMode(List<MethodCall> calls) {
  final modes = argumentsOf(calls, 'SystemChrome.setEnabledSystemUIMode');
  if (modes.isEmpty) return null;
  final last = modes.last;
  return last is String ? last : null;
}

/// The overlays the last manual `setEnabledSystemUIOverlays` call sent.
List<Object?>? lastOverlays(List<MethodCall> calls) {
  final overlays = argumentsOf(
    calls,
    'SystemChrome.setEnabledSystemUIOverlays',
  );
  return overlays.isEmpty ? null : overlays.last! as List<Object?>;
}

/// The orientations the last `setPreferredOrientations` call sent.
List<Object?>? lastOrientations(List<MethodCall> calls) {
  final sent = argumentsOf(calls, 'SystemChrome.setPreferredOrientations');
  return sent.isEmpty ? null : sent.last! as List<Object?>;
}

/// The label the last `setApplicationSwitcherDescription` call sent.
String? lastLabel(List<MethodCall> calls) {
  final sent = argumentsOf(
    calls,
    'SystemChrome.setApplicationSwitcherDescription',
  );
  return sent.isEmpty
      ? null
      : (sent.last! as Map<Object?, Object?>)['label'] as String?;
}

/// The color the last `setApplicationSwitcherDescription` call sent.
int? lastSwitcherColor(List<MethodCall> calls) {
  final sent = argumentsOf(
    calls,
    'SystemChrome.setApplicationSwitcherDescription',
  );
  return sent.isEmpty
      ? null
      : (sent.last! as Map<Object?, Object?>)['primaryColor'] as int?;
}

/// A `MaterialApp` titled [title] whose builder places the Stratum theme
/// application of [themes], in [themeMode] and [highContrast], with the
/// app-wide [systemStyle].
Widget systemStyleApp({
  required Widget home,
  StratumThemeSet? themes,
  ThemeMode themeMode = ThemeMode.light,
  StratumHighContrastMode highContrast = StratumHighContrastMode.off,
  SystemStyle? systemStyle,
  String title = 'App',
  GlobalKey<NavigatorState>? navigatorKey,
}) => MaterialApp(
  title: title,
  navigatorKey: navigatorKey,
  builder: (context, child) => StratumThemeApplication(
    themes: themes ?? defaultThemeSet,
    themeMode: themeMode,
    highContrast: highContrast,
    systemStyle: systemStyle,
    child: child!,
  ),
  home: home,
);

/// The bar color strips that the theme application at [index], counted
/// from the outermost, paints over every page, as a painter for the
/// `paints` matcher.
void Function(Canvas) barStrips(WidgetTester tester, {int index = 0}) {
  final strips = find
      .descendant(
        of: find.byType(SystemStyleRoot).at(index),
        matching: find.byType(CustomPaint),
      )
      .first;
  final painter = tester.widget<CustomPaint>(strips).foregroundPainter!;
  final size = tester.getSize(strips);
  return (canvas) => painter.paint(canvas, size);
}

/// The semantics tree of [tester] as text, with no node ids, so two trees
/// built by different widgets compare by what a screen reader reads.
String semanticsTree(WidgetTester tester) => tester
    .binding
    .renderViews
    .single
    .owner!
    .semanticsOwner!
    .rootSemanticsNode!
    .toStringDeep()
    .replaceAll(RegExp(r'#\d+'), '');

/// The color of the status bar icons [SystemChrome.latestStyle] names.
Color latestStatusIconColor() =>
    SystemChrome.latestStyle?.statusBarIconBrightness == Brightness.light
    ? const Color(0xFFFFFFFF)
    : const Color(0xFF000000);

/// A page body that paints [color] under the status bar, a
/// [statusBarHeight] header, declared with `SystemBarFill`.
Widget headerPage(Color color, {Widget? body}) => ColumnLayout(
  children: [
    SystemBarFill(
      color: color,
      child: ColoredBox(
        color: color,
        child: const SizedBox(
          width: double.infinity,
          height: statusBarHeight + 32,
        ),
      ),
    ),
    Expanded(child: body ?? const SizedBox()),
  ],
);

/// A page whose one control is a 48 px Play button, aligned by
/// [alignment], inside [wrap].
Widget playButtonPage(
  Alignment alignment,
  Widget Function(Widget child) wrap, {
  VoidCallback? onTap,
}) => systemStyleApp(
  home: Align(
    alignment: alignment,
    child: wrap(
      Semantics(
        button: true,
        label: 'Play',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap ?? () {},
          child: const SizedBox(width: 48, height: 48),
        ),
      ),
    ),
  ),
);
