// The harness measures the layouts through their src paths, because the
// gesture layouts are not exported by the layout barrel.
// ignore_for_file: implementation_imports
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stratum_ui/src/components/common/layout/gesture_row_layout.dart';
import 'package:stratum_ui/src/src.dart';

class _PerfTransparent extends Fake implements TransparentColors {
  @override
  Color get t0 => const Color(0x00000000);
}

class _PerfColors extends Fake implements BaseThemeColor {
  @override
  Color get overlayHover => const Color(0x11000000);

  @override
  Color get overlayActive => const Color(0x22000000);

  @override
  Color get borderBrand => const Color(0xFF0000FF);

  @override
  TransparentColors get transparent => _PerfTransparent();
}

/// Answers only what the measured widgets read.
class _PerfTheme extends Fake implements StratumThemeData {
  @override
  final BaseThemeColor color = _PerfColors();

  @override
  ScrollBehavior get scrollBehavior => const StratumScrollBehavior();

  @override
  ScrollPhysics get physics => const ClampingScrollPhysics();
}

final _theme = _PerfTheme();

/// Places a scene in a [MaterialApp] (a real [Theme] platform) under a
/// [StratumThemeApplication].
Widget perfHost(Widget child) {
  return MaterialApp(
    home: StratumThemeApplication(
      themeMode: ThemeMode.light,
      lightTheme: _theme,
      darkTheme: null,
      child: Scaffold(body: child),
    ),
  );
}

/// Scrolls the first [Scrollable] down for half of [duration] and back up
/// for the other half at a constant speed, so every traced frame is a
/// scroll frame and every run scrolls the same way.
Future<void> scrollFor(
  WidgetTester tester,
  Duration duration, {
  double distance = 4000,
}) async {
  final position = tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position;
  expect(position.maxScrollExtent, greaterThanOrEqualTo(distance));
  final half = duration ~/ 2;
  await position.animateTo(distance, duration: half, curve: Curves.linear);
  await position.animateTo(0, duration: half, curve: Curves.linear);
}

/// Timeline streams that carry the `Frame` (Dart) and `GPURasterizer::Draw`
/// (Embedder) events. The default `all` adds the API stream, whose events
/// fill the recorder's buffer and push the traced frames out of it.
const _streams = ['Dart', 'Embedder', 'GC'];

const _rowCount = 1000;

const _cardStyle = WidgetStyle(
  padding: EdgeInsets.all(12),
  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
  backgroundColor: Color(0xFFFFFFFF),
  borderRadius: BorderRadius.all(Radius.circular(12)),
  dropShadow: [
    BoxShadow(color: Color(0x22000000), blurRadius: 8, offset: Offset(0, 2)),
  ],
  innerShadow: [BoxShadow(color: Color(0x11000000), blurRadius: 4)],
);

List<Widget> _rowChildren(int index) {
  return [
    ColumnLayout(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Text('Item $index'), const Text('Subtitle')],
    ),
    ColumnLayout(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [Text('${index * 3}'), const Text('units')],
    ),
  ];
}

/// S1: a row of two columns with text, no style.
Widget sceneRow(int index) {
  return RowLayout(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: _rowChildren(index),
  );
}

/// S2: S1 with fill, radius, drop shadow, and inner shadow.
Widget sceneStyledRow(int index) {
  return RowLayout(
    style: _cardStyle,
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: _rowChildren(index),
  );
}

/// S3: S2 with a tap callback and the 100 ms default style animation.
Widget sceneTappableRow(int index) {
  return GestureRowLayout(
    style: _cardStyle,
    onTap: () {},
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: _rowChildren(index),
  );
}

Widget _list(Widget Function(int index) row) {
  return ListView.builder(
    itemCount: _rowCount,
    itemBuilder: (context, index) => row(index),
  );
}

/// S4: 50 boxes that toggle their style every 250 ms, as long as their
/// animation, so every traced frame animates.
class AnimatingBoxes extends StatefulWidget {
  const AnimatingBoxes({super.key});

  @override
  State<AnimatingBoxes> createState() => _AnimatingBoxesState();
}

class _AnimatingBoxesState extends State<AnimatingBoxes> {
  static const _a = WidgetStyle(
    width: 48,
    height: 48,
    backgroundColor: Color(0xFF2962FF),
    borderRadius: BorderRadius.all(Radius.circular(4)),
    animationStyle: AnimationStyle(duration: Duration(milliseconds: 250)),
  );
  static const _b = WidgetStyle(
    width: 64,
    height: 64,
    backgroundColor: Color(0xFFFF6D00),
    borderRadius: BorderRadius.all(Radius.circular(32)),
    dropShadow: [BoxShadow(color: Color(0x44000000), blurRadius: 12)],
    animationStyle: AnimationStyle(duration: Duration(milliseconds: 250)),
  );

  late final Timer _timer;
  var _flip = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => setState(() => _flip = !_flip),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < 50; i++)
          ContainerLayout(style: (i.isEven ^ _flip) ? _a : _b),
      ],
    );
  }
}

/// S5: 20 glass cards in one [BackdropGroup] over a painted background.
class GlassCards extends StatelessWidget {
  const GlassCards({super.key});

  static const _glass = WidgetStyle(
    height: 120,
    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    backgroundColor: Color(0x33FFFFFF),
    borderRadius: BorderRadius.all(Radius.circular(16)),
    backgroundBlur: ImageBlurFilter(sigmaX: 12, sigmaY: 12),
  );

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: CustomPaint(painter: _Stripes())),
        BackdropGroup(
          child: ListView.builder(
            itemCount: 20,
            itemBuilder: (context, index) =>
                ContainerLayout(style: _glass, child: Text('Card $index')),
          ),
        ),
      ],
    );
  }
}

class _Stripes extends CustomPainter {
  const _Stripes();

  @override
  void paint(Canvas canvas, Size size) {
    const colors = [
      Color(0xFFE53935),
      Color(0xFF43A047),
      Color(0xFF1E88E5),
      Color(0xFFFDD835),
    ];
    final paint = Paint()..strokeWidth = 24;
    for (var x = -size.height; x < size.width; x += 32) {
      paint.color = colors[(x ~/ 32) % colors.length];
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_Stripes oldDelegate) => false;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  // Two seconds fit the timeline recorder's buffer at 144 Hz; a longer
  // trace loses its first frames.
  const traceTime = Duration(seconds: 2);

  testWidgets('S1 plain rows', (tester) async {
    await tester.pumpWidget(perfHost(_list(sceneRow)));
    await binding.traceAction(
      () => scrollFor(tester, traceTime),
      streams: _streams,
      reportKey: 'S1',
    );
    expect(tester.takeException(), isNull);
  }, semanticsEnabled: false);

  testWidgets('S2 styled rows', (tester) async {
    await tester.pumpWidget(perfHost(_list(sceneStyledRow)));
    await binding.traceAction(
      () => scrollFor(tester, traceTime),
      streams: _streams,
      reportKey: 'S2',
    );
    expect(tester.takeException(), isNull);
  }, semanticsEnabled: false);

  testWidgets('S3 tappable rows', (tester) async {
    await tester.pumpWidget(perfHost(_list(sceneTappableRow)));
    await binding.traceAction(
      () => scrollFor(tester, traceTime),
      streams: _streams,
      reportKey: 'S3',
    );
    expect(tester.takeException(), isNull);
  }, semanticsEnabled: false);

  testWidgets('S4 animating boxes', (tester) async {
    await tester.pumpWidget(perfHost(const AnimatingBoxes()));
    await binding.traceAction(
      () => tester.pump(traceTime),
      streams: _streams,
      reportKey: 'S4',
    );
    expect(tester.takeException(), isNull);
  }, semanticsEnabled: false);

  testWidgets('S5 glass cards', (tester) async {
    await tester.pumpWidget(perfHost(const GlassCards()));
    await binding.traceAction(
      () => scrollFor(tester, traceTime, distance: 2000),
      streams: _streams,
      reportKey: 'S5',
    );
    expect(tester.takeException(), isNull);
  }, semanticsEnabled: false);
}
