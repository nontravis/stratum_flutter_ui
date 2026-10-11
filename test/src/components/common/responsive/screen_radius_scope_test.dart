// The scope draws nothing, owns no semantics node, and takes no input or
// motion, so of the stratum-create-widget build gate only NFR-U06 (its
// child's node reads unchanged) applies; NFR-U01..U05, U07..U09, E01, and
// E02 are n/a: an internal scope apps never write (D21), with no look,
// target, gesture, or style.
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/responsive/device_window.dart';
import 'package:stratum_ui/src/components/common/responsive/screen_radius_scope.dart';

const _channel = EventChannel('stratum_ui/screen_radius');

const _r46 = {
  'topLeft': 46.0,
  'topRight': 46.0,
  'bottomLeft': 46.0,
  'bottomRight': 46.0,
};

const _r12 = {
  'topLeft': 12.0,
  'topRight': 12.0,
  'bottomLeft': 12.0,
  'bottomRight': 12.0,
};

/// Mocks the native probe for this test only: [onListen] gets the sink the
/// scope's listen opens, [onCancel] runs when the scope cancels.
///
/// Block bodies: the mock replies with whatever its callbacks return, and
/// the codec cannot encode a sink.
void _mockProbe(
  WidgetTester tester, {
  void Function(MockStreamHandlerEventSink sink)? onListen,
  void Function()? onCancel,
}) {
  tester.binding.defaultBinaryMessenger.setMockStreamHandler(
    _channel,
    MockStreamHandler.inline(
      onListen: (_, sink) {
        onListen?.call(sink);
      },
      onCancel: (_) {
        onCancel?.call();
      },
    ),
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockStreamHandler(
      _channel,
      null,
    ),
  );
}

/// Mocks a probe that sends [events] on listen.
void _mockEvents(WidgetTester tester, List<Object?> events) =>
    _mockProbe(tester, onListen: (sink) => events.forEach(sink.success));

/// Pumps an event sent through a [MockStreamHandlerEventSink] into a
/// frame: the first pump delivers it, since its delivery takes microtasks
/// that run after the pump's frame check; the second builds the frame the
/// event schedules.
Future<void> _pumpEvent(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

/// Lets the test engine answer a channel call that has no mock, then
/// pumps the answer in: the reply arrives on the real event loop, which
/// fake time never runs.
Future<void> _pumpPlatformReply(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pump();
}

Widget _reader(void Function(BorderRadius?) onRadius, {MediaQueryData? data}) =>
    MediaQuery(
      data: data ?? const MediaQueryData(),
      child: ScreenRadiusScope(
        child: Builder(
          builder: (context) {
            onRadius(context.deviceWindow.radius);
            return const SizedBox();
          },
        ),
      ),
    );

/// Counts its State's [State.initState], [State.deactivate], and
/// [State.activate] calls, so a move that remounts the tree, rather than
/// an in-place rebuild, shows up even when [initStates] alone would not
/// (deactivate/activate never touch initState).
class _Counter extends StatefulWidget {
  const new(this.initStates, {this.deactivates, this.activates});

  final List<int> initStates;
  final List<int>? deactivates;
  final List<int>? activates;

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  @override
  void initState() {
    super.initState();
    widget.initStates.add(1);
  }

  @override
  void deactivate() {
    widget.deactivates?.add(1);
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    widget.activates?.add(1);
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

/// A non-radius dependent: reads `deviceWindow.height` and counts
/// [State.deactivate]/[State.activate] alongside builds, so a move that
/// remounts it, rather than an in-place rebuild, is visible.
class _HeightProbe extends StatefulWidget {
  const new({
    required this.builds,
    required this.deactivates,
    required this.activates,
  });

  final List<int> builds;
  final List<int> deactivates;
  final List<int> activates;

  @override
  State<_HeightProbe> createState() => _HeightProbeState();
}

class _HeightProbeState extends State<_HeightProbe> {
  @override
  void deactivate() {
    widget.deactivates.add(1);
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    widget.activates.add(1);
  }

  @override
  Widget build(BuildContext context) {
    context.deviceWindow.height;
    widget.builds.add(1);
    return const SizedBox();
  }
}

void main() {
  setUp(ScreenRadiusScope.reset);

  testWidgets(
    'us04/fr03/e03: on iOS publishes the probe radius while Flutter reads null',
    (tester) async {
      _mockEvents(tester, [_r46]);
      BorderRadius? radius;

      await tester.pumpWidget(_reader((r) => radius = r));
      await tester.pump();

      expect(radius, const BorderRadius.all(Radius.circular(46)));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('us04/fr03/e04: an older iOS sends null and radius stays null', (
    tester,
  ) async {
    _mockEvents(tester, [null]);
    BorderRadius? radius = BorderRadius.zero;

    await tester.pumpWidget(_reader((r) => radius = r));
    await tester.pump();

    expect(radius, isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('us04/fr03: a nil event after a value drops the radius to null', (
    tester,
  ) async {
    late MockStreamHandlerEventSink sink;
    _mockProbe(tester, onListen: (s) => sink = s..success(_r46));
    BorderRadius? radius;
    await tester.pumpWidget(_reader((r) => radius = r));
    await tester.pump();

    sink.success(null);
    await _pumpEvent(tester);

    expect(radius, isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('us04/fr03: a corner the probe leaves out reads zero', (
    tester,
  ) async {
    _mockEvents(tester, [
      const {'topLeft': 46, 'topRight': 46.0},
    ]);
    BorderRadius? radius;

    await tester.pumpWidget(_reader((r) => radius = r));
    await tester.pump();

    expect(
      radius,
      const BorderRadius.only(
        topLeft: Radius.circular(46),
        topRight: Radius.circular(46),
      ),
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('us04/fr03: never overrides a radius Flutter fills', (
    tester,
  ) async {
    _mockEvents(tester, [_r46]);
    const own = BorderRadius.all(Radius.circular(30));
    BorderRadius? radius;

    await tester.pumpWidget(
      _reader(
        (r) => radius = r,
        data: const MediaQueryData(displayCornerRadii: own),
      ),
    );
    await tester.pump();

    expect(radius, own);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets(
    'us04/fr03: with no native plugin, iOS reads null and reports no error',
    (tester) async {
      BorderRadius? radius = BorderRadius.zero;

      await tester.pumpWidget(_reader((r) => radius = r));
      await _pumpPlatformReply(tester);
      await tester.pumpWidget(const SizedBox());
      await _pumpPlatformReply(tester);

      expect(radius, isNull);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('us04/fr03: an error event is reported and reads null', (
    tester,
  ) async {
    late MockStreamHandlerEventSink sink;
    _mockProbe(tester, onListen: (s) => sink = s..success(_r46));
    BorderRadius? radius;
    await tester.pumpWidget(_reader((r) => radius = r));
    await tester.pump();

    sink.error(code: 'probe');
    await _pumpEvent(tester);

    expect(tester.takeException(), isA<PlatformException>());
    expect(radius, isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('us04/fr03: the end of the stream keeps the last radius', (
    tester,
  ) async {
    _mockEvents(tester, [_r46]);
    BorderRadius? radius;
    await tester.pumpWidget(_reader((r) => radius = r));
    await tester.pump();

    // The wire form of the end of the stream: a null message. Sent
    // directly, since MockStreamHandlerEventSink.endOfStream hangs the
    // test at Flutter 3.47.7.
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      _channel.name,
      null,
      null,
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(radius, const BorderRadius.all(Radius.circular(46)));
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  // Web never subscribes (`kIsWeb` in `_darwin`); were it to, the
  // MissingPluginException path the no-plugin test proves reads null.
  testWidgets(
    'us04/fr03/e05: on Windows, Linux, and Android it listens to no probe',
    (tester) async {
      var listened = false;
      _mockProbe(
        tester,
        onListen: (sink) {
          listened = true;
          sink.success(_r46);
        },
      );
      BorderRadius? radius = BorderRadius.zero;

      await tester.pumpWidget(_reader((r) => radius = r));
      await tester.pump();

      expect(listened, isFalse);
      expect(radius, isNull);
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.windows,
      TargetPlatform.linux,
      TargetPlatform.android,
    }),
  );

  testWidgets('us04/fr03: unmounting the scope cancels the probe', (
    tester,
  ) async {
    var cancels = 0;
    _mockProbe(
      tester,
      onListen: (sink) => sink.success(_r46),
      onCancel: () => cancels++,
    );
    await tester.pumpWidget(_reader((_) {}));
    await tester.pump();

    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    expect(cancels, 1);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('us04/fr03: a failed listen is reported', (tester) async {
    _mockProbe(tester, onListen: (_) => throw PlatformException(code: 'error'));

    await tester.pumpWidget(_reader((_) {}));
    await _pumpEvent(tester);

    expect(tester.takeException(), isA<PlatformException>());
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets(
    'us04/fr03: a failed cancel is reported, never an unhandled error',
    (tester) async {
      _mockProbe(
        tester,
        onListen: (sink) => sink.success(_r46),
        onCancel: () => throw PlatformException(
          code: 'error',
          message: 'No active stream to cancel',
        ),
      );
      await tester.pumpWidget(_reader((_) {}));
      await tester.pump();

      await tester.pumpWidget(const SizedBox());
      await _pumpEvent(tester);

      expect(tester.takeException(), isA<PlatformException>());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    'us04/fr03/e06: a change event rebuilds the radius reader once and no '
    'height reader, on the first event, a value change, and a nil event',
    (tester) async {
      late MockStreamHandlerEventSink sink;
      // No value on listen: the first event below is null to value, the
      // gap left by the old e06, which sent the first value on listen and
      // only ever measured a later value-to-value change.
      _mockProbe(tester, onListen: (s) => sink = s);
      var radiusBuilds = 0;
      var heightBuilds = 0;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(400, 800)),
          child: ScreenRadiusScope(
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Column(
                children: [
                  Builder(
                    builder: (c) {
                      c.deviceWindow.radius;
                      radiusBuilds++;
                      return const SizedBox();
                    },
                  ),
                  Builder(
                    builder: (c) {
                      c.deviceWindow.height;
                      heightBuilds++;
                      return const SizedBox();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      radiusBuilds = 0;
      heightBuilds = 0;

      sink.success(_r46);
      await _pumpEvent(tester);
      expect(radiusBuilds, 1, reason: 'first event, null to value');
      expect(heightBuilds, 0, reason: 'first event, null to value');
      radiusBuilds = 0;
      heightBuilds = 0;

      sink.success(_r12);
      await _pumpEvent(tester);
      expect(radiusBuilds, 1, reason: 'later event, value to value');
      expect(heightBuilds, 0, reason: 'later event, value to value');
      radiusBuilds = 0;
      heightBuilds = 0;

      sink.success(null);
      await _pumpEvent(tester);
      expect(radiusBuilds, 1, reason: 'nil event, value to null');
      expect(heightBuilds, 0, reason: 'nil event, value to null');
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    'us04/fr03: the first probe event moves nothing — zero rebuilds, '
    'deactivate, or activate on a non-radius State',
    (tester) async {
      late MockStreamHandlerEventSink sink;
      _mockProbe(tester, onListen: (s) => sink = s);
      var radiusBuilds = 0;
      final heightBuilds = <int>[];
      final deactivates = <int>[];
      final activates = <int>[];
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(400, 800)),
          child: ScreenRadiusScope(
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Column(
                children: [
                  Builder(
                    builder: (c) {
                      c.deviceWindow.radius;
                      radiusBuilds++;
                      return const SizedBox();
                    },
                  ),
                  _HeightProbe(
                    builds: heightBuilds,
                    deactivates: deactivates,
                    activates: activates,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      radiusBuilds = 0;
      heightBuilds.clear();
      deactivates.clear();
      activates.clear();

      sink.success(_r46);
      await _pumpEvent(tester);

      expect(radiusBuilds, 1);
      expect(heightBuilds, isEmpty);
      expect(deactivates, isEmpty);
      expect(activates, isEmpty);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'us04/fr03: a reverse event (value to null) moves nothing either',
    (tester) async {
      late MockStreamHandlerEventSink sink;
      _mockProbe(tester, onListen: (s) => sink = s..success(_r46));
      var radiusBuilds = 0;
      final heightBuilds = <int>[];
      final deactivates = <int>[];
      final activates = <int>[];
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(400, 800)),
          child: ScreenRadiusScope(
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Column(
                children: [
                  Builder(
                    builder: (c) {
                      c.deviceWindow.radius;
                      radiusBuilds++;
                      return const SizedBox();
                    },
                  ),
                  _HeightProbe(
                    builds: heightBuilds,
                    deactivates: deactivates,
                    activates: activates,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      radiusBuilds = 0;
      heightBuilds.clear();
      deactivates.clear();
      activates.clear();

      sink.success(null);
      await _pumpEvent(tester);

      expect(radiusBuilds, 1);
      expect(heightBuilds, isEmpty);
      expect(deactivates, isEmpty);
      expect(activates, isEmpty);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'us04/fr03: on iOS the pass-through MediaQuery is present before any '
    'probe event',
    (tester) async {
      _mockProbe(tester, onListen: (_) {});

      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(),
          child: ScreenRadiusScope(child: SizedBox()),
        ),
      );
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(ScreenRadiusScope),
          matching: find.byType(MediaQuery),
        ),
        findsOneWidget,
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'us04/fr03: on Android the scope inserts no MediaQuery before any '
    "probe event, matching today's tree",
    (tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(),
          child: ScreenRadiusScope(child: SizedBox()),
        ),
      );
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(ScreenRadiusScope),
          matching: find.byType(MediaQuery),
        ),
        findsNothing,
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'us04/fr03: the first probe value and a later nil keep every State '
    'below the scope',
    (tester) async {
      late MockStreamHandlerEventSink sink;
      _mockProbe(tester, onListen: (s) => sink = s);
      final initStates = <int>[];
      final deactivates = <int>[];
      final activates = <int>[];
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: ScreenRadiusScope(
            child: _Counter(
              initStates,
              deactivates: deactivates,
              activates: activates,
            ),
          ),
        ),
      );
      await tester.pump();
      deactivates.clear();
      activates.clear();

      sink.success(_r46);
      await _pumpEvent(tester);
      sink.success(null);
      await _pumpEvent(tester);

      expect(initStates, hasLength(1));
      expect(deactivates, isEmpty);
      expect(activates, isEmpty);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'NFR-U06: the child semantics node reads unchanged under a published '
    'radius',
    (tester) async {
      final semantics = tester.ensureSemantics();
      _mockEvents(tester, [_r46]);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: ScreenRadiusScope(
            child: Semantics(
              label: 'Content',
              textDirection: TextDirection.ltr,
              child: const SizedBox(width: 10, height: 10),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        tester.getSemantics(find.bySemanticsLabel('Content')),
        matchesSemantics(label: 'Content', textDirection: TextDirection.ltr),
      );
      semantics.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  group('ScreenRadiusScope.hasScope', () {
    testWidgets('is true below a scope', (tester) async {
      bool? found;

      await tester.pumpWidget(
        ScreenRadiusScope(
          child: Builder(
            builder: (context) {
              found = ScreenRadiusScope.hasScope(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(found, isTrue);
    });

    testWidgets('is false with no scope above', (tester) async {
      bool? found;

      await tester.pumpWidget(
        Builder(
          builder: (context) {
            found = ScreenRadiusScope.hasScope(context);
            return const SizedBox();
          },
        ),
      );

      expect(found, isFalse);
    });
  });
}
