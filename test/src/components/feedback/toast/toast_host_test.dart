import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/feedback/toast/toast_placement.dart';
import 'package:stratum_ui/src/src.dart';
import 'package:toastification/toastification.dart' show ToastificationWrapper;

import '../../common/fakes/fake_stratum_theme.dart';

// The Build Gate rows (stratum-create-widget) that draw the notice's
// look sit in the plain-look task (M4-T26), which owns the look; this
// file proves the host's placement, queue, stack, and lifecycle
// behavior.

/// A phone-sized test view, logical pixels, reset after the test (P2).
void _view(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// The test view's system-bar inset, on both `padding` and `viewPadding`,
/// as a device reports them while no keyboard shows.
void _bars(WidgetTester tester, FakeViewPadding padding) {
  tester.view.padding = padding;
  tester.view.viewPadding = padding;
}

const _phone = Size(390, 844);

/// [home] under the theme, a direction, and the toast host above the
/// app's navigator, as `MaterialApp.builder` places it.
Widget _app(Widget home, {TextDirection direction = TextDirection.ltr}) =>
    MaterialApp(
      builder: (context, child) => StratumThemeApplication(
        themes: StratumThemeSet(light: fakeTheme),
        themeMode: ThemeMode.light,
        child: Directionality(
          textDirection: direction,
          child: StratumToastHost(child: child!),
        ),
      ),
      home: Scaffold(body: home),
    );

/// A button labeled [label] whose tap runs [show] with its context.
Widget _button(String label, void Function(BuildContext) show) => Builder(
  builder: (c) => TextButton(onPressed: () => show(c), child: Text(label)),
);

/// Calls `context.showToast` from `initState`, so a test can prove a
/// build-phase call defers past the build instead of crashing
/// `overlay.insert` (edge finding 4).
class _ShowOnMount extends StatefulWidget {
  const new(this.message);

  final String message;

  @override
  State<_ShowOnMount> createState() => _ShowOnMountState();
}

class _ShowOnMountState extends State<_ShowOnMount> {
  @override
  void initState() {
    super.initState();
    // An explicit placement skips `context.windowSize`'s own inherited
    // widget read, isolating the host's build-phase deferral from that
    // unrelated initState restriction.
    context.showToast(
      message: widget.message,
      placement: const StratumToastPlacement.float(
        StratumToastCorner.bottomCenter,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

/// The surface box of the notice holding [message]: the outermost
/// `ContainerLayout` under it.
Finder _fill(String message) => find
    .ancestor(of: find.text(message), matching: find.byType(ContainerLayout))
    .last;

/// Shows one notice per entry of [messages] in one tap, then settles.
Future<void> _show(
  WidgetTester tester,
  List<String> messages, {
  StratumToastPlacement? placement,
}) async {
  await tester.pumpWidget(
    _app(
      _button('go', (c) {
        for (final message in messages) {
          c.showToast(message: message, placement: placement);
        }
      }),
    ),
  );
  await tester.tap(find.text('go'));
  await tester.pumpAndSettle();
}

void main() {
  test('us01/fr01/e04: default placement by window size', () {
    expect(
      defaultToastPlacement(WindowSize.mobile),
      isA<StratumToastFloat>().having(
        (p) => p.corner,
        'corner',
        StratumToastCorner.bottomCenter,
      ),
    );
    expect(
      defaultToastPlacement(WindowSize.tablet),
      isA<StratumToastFloat>().having(
        (p) => p.corner,
        'corner',
        StratumToastCorner.bottomCenter,
      ),
    );
    expect(
      defaultToastPlacement(WindowSize.desktop),
      isA<StratumToastFloat>().having(
        (p) => p.corner,
        'corner',
        StratumToastCorner.bottomStart,
      ),
    );
  });

  testWidgets(
    'us01/s1: a float notice shows in its corner and closes after 4 s',
    (tester) async {
      _view(tester, _phone);
      await _show(
        tester,
        ['Saved'],
        placement: const StratumToastPlacement.float(
          StratumToastCorner.bottomEnd,
        ),
      );
      expect(find.text('Saved'), findsOneWidget);
      // Exact edge (N4): the float margin `space.lg` (20) off the right
      // edge of the phone view.
      expect(tester.getRect(_fill('Saved')).right, closeTo(390 - 20, 0.5));
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('Saved'), findsNothing);
    },
  );

  testWidgets('us01/fr01/e05: no host above throws a FlutterError naming it', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      Builder(
        builder: (c) {
          context = c;
          return const SizedBox();
        },
      ),
    );
    expect(
      () => context.showToast(message: 'x'),
      throwsA(
        isA<FlutterError>().having(
          (e) => e.message,
          'message',
          contains('StratumToastHost'),
        ),
      ),
    );
  });

  testWidgets(
    'us01/fr01/e02: review focus 3: a call from a modal route shows above it',
    (tester) async {
      _view(tester, _phone);
      await tester.pumpWidget(
        _app(
          _button(
            'open',
            (c) => showModalLayout<void>(
              c,
              builder: (m) => ModalLayout(
                body: _button(
                  'notify',
                  (b) => b.showToast(message: 'From modal'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('notify'));
      await tester.pumpAndSettle();
      expect(find.text('From modal'), findsOneWidget);
      expect(tester.getRect(find.text('From modal')).hasNaN, isFalse);
      // The notice, not the modal route under it, receives a tap at its
      // center (N19): the overlay entry sits above every route.
      final center = tester.getCenter(find.text('From modal'));
      final target = tester
          .hitTestOnBinding(center)
          .path
          .map((entry) => entry.target)
          .whereType<RenderObject>()
          .first;
      expect(
        find.text('From modal').evaluate().map((e) => e.findRenderObject()),
        contains(target),
      );
    },
  );

  testWidgets(
    'us01/s4: us01/fr03/e01: a second solid notice waits for the first',
    (tester) async {
      _view(tester, _phone);
      await _show(tester, [
        'one',
        'two',
      ], placement: const StratumToastPlacement.solid(StratumToastEdge.bottom));
      expect(find.text('one'), findsOneWidget);
      expect(find.text('two'), findsNothing);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('two'), findsOneWidget);
    },
  );

  testWidgets(
    'us01/s5: us01/fr03/e04: a corner stacks 3; a 4th drops the oldest',
    (tester) async {
      _view(tester, _phone);
      await tester.pumpWidget(
        _app(
          _button('go', (c) {
            for (final m in ['a', 'b', 'c', 'd']) {
              c.showToast(message: m);
            }
          }),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text('a'), findsNothing);
      for (final m in ['b', 'c', 'd']) {
        expect(find.text(m), findsOneWidget);
      }
    },
  );

  testWidgets(
    'us01/fr03/e05 r25: the newest bottom-corner notice sits nearest the edge',
    (tester) async {
      _view(tester, _phone);
      await _show(tester, ['old', 'new']);
      final oldBottom = tester.getRect(find.text('old')).bottom;
      final newBottom = tester.getRect(find.text('new')).bottom;
      // R25: the newest lands closest to the anchored bottom edge.
      expect(newBottom, greaterThan(oldBottom));
    },
  );

  testWidgets(
    'us01/s3: us01/fr02/e04: a solid top notice runs under the status bar, its text below',
    (tester) async {
      _view(tester, _phone);
      _bars(tester, const FakeViewPadding(top: 44));
      await _show(tester, [
        'Top',
      ], placement: const StratumToastPlacement.solid(StratumToastEdge.top));
      expect(tester.getRect(find.text('Top')).top, greaterThanOrEqualTo(44));
      expect(tester.getRect(_fill('Top')).top, 0);
      expect(tester.getRect(_fill('Top')).width, 390);
    },
  );

  testWidgets(
    'us01/s14: us01/fr02/e06: a bottom notice rides above the keyboard',
    (tester) async {
      _view(tester, _phone);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await _show(tester, ['Up']);
      expect(
        tester.getRect(find.text('Up')).bottom,
        lessThanOrEqualTo(844 - 300),
      );
    },
  );

  testWidgets('us01/s16: us01/fr02/e01: RTL puts bottom start on the right', (
    tester,
  ) async {
    _view(tester, _phone);
    await tester.pumpWidget(
      _app(
        _button(
          'go',
          (c) => c.showToast(
            message: 'Start',
            placement: const StratumToastPlacement.float(
              StratumToastCorner.bottomStart,
            ),
          ),
        ),
        direction: TextDirection.rtl,
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    // Exact edge (N4): bottom start under RTL is the bottom right
    // corner, the float margin off the right edge.
    expect(tester.getRect(_fill('Start')).right, closeTo(390 - 20, 0.5));
    expect(tester.getRect(_fill('Start')).left, closeTo(20, 0.5));
  });

  testWidgets('n1: a remounted host shows again at the same corner', (
    tester,
  ) async {
    _view(tester, _phone);
    await _show(
      tester,
      ['first'],
      placement: const StratumToastPlacement.float(
        StratumToastCorner.bottomEnd,
      ),
    );
    expect(find.text('first'), findsOneWidget);
    // Unmount the tree, then remount a fresh host; the process-wide
    // managers the host cleared on dispose must not swallow the notice.
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await _show(
      tester,
      ['second'],
      placement: const StratumToastPlacement.float(
        StratumToastCorner.bottomEnd,
      ),
    );
    expect(find.text('second'), findsOneWidget);
    // Green teardown proves no timer outlived the first host (N1).
  });

  testWidgets('n23: the host builds no second wrapper above an app one', (
    tester,
  ) async {
    _view(tester, _phone);
    await tester.pumpWidget(
      ToastificationWrapper(
        child: _app(_button('go', (c) => c.showToast(message: 'W'))),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('W'), findsOneWidget);
    expect(
      find.byType(ToastificationWrapper),
      findsOneWidget,
      reason: 'the host must reuse the app wrapper, not assert on a second',
    );
  });

  testWidgets('us01/fr02/e06: a solid bottom notice rides above the keyboard', (
    tester,
  ) async {
    _view(tester, _phone);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await _show(tester, [
      'Up solid',
    ], placement: const StratumToastPlacement.solid(StratumToastEdge.bottom));
    expect(
      tester.getRect(_fill('Up solid')).bottom,
      lessThanOrEqualTo(844 - 300),
    );
  });

  testWidgets(
    'edge i2: a float notice width follows a window widened while it shows',
    (tester) async {
      // A narrow first show freezes a small cap (320 = 360 - 2*lg) if the
      // width lives in toastification's config; widening past the token's
      // own cap (430 = 480 - 2*lg) must still grow the rendered width, or
      // the viewport-clamped frozen value would mask a narrower resize.
      _view(tester, const Size(360, 844));
      await _show(
        tester,
        ['Wide'],
        placement: const StratumToastPlacement.float(
          StratumToastCorner.bottomCenter,
        ),
      );
      final narrowWidth = tester.getRect(_fill('Wide')).width;
      _view(tester, const Size(800, 844));
      await tester.pump();
      expect(tester.getRect(_fill('Wide')).width, greaterThan(narrowWidth));
    },
  );

  testWidgets(
    'edge minor 3: a nested host dispose does not freeze the outer host',
    (tester) async {
      _view(tester, _phone);
      await tester.pumpWidget(
        _app(
          Column(
            children: [
              _button('outer', (c) => c.showToast(message: 'Outer')),
              StratumToastHost(
                child: _button('inner', (c) => c.showToast(message: 'Inner')),
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.text('outer'));
      await tester.pumpAndSettle();
      expect(find.text('Outer'), findsOneWidget);
      // Unmount the inner host only; the outer host and its notice stay.
      await tester.pumpWidget(
        _app(_button('outer', (c) => c.showToast(message: 'Outer'))),
      );
      await tester.pump();
      expect(find.text('Outer'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('Outer'), findsNothing);
    },
  );

  testWidgets(
    'edge minor 4: a showToast call from initState defers past the build phase',
    (tester) async {
      _view(tester, _phone);
      await tester.pumpWidget(_app(const _ShowOnMount('OnMount')));
      await tester.pumpAndSettle();
      expect(find.text('OnMount'), findsOneWidget);
    },
  );

  testWidgets(
    'fr03/e02: three solid notices show one after another in call order',
    (tester) async {
      _view(tester, _phone);
      await _show(tester, [
        'one',
        'two',
        'three',
      ], placement: const StratumToastPlacement.solid(StratumToastEdge.bottom));
      expect(find.text('one'), findsOneWidget);
      expect(find.text('two'), findsNothing);
      expect(find.text('three'), findsNothing);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('one'), findsNothing);
      expect(find.text('two'), findsOneWidget);
      expect(find.text('three'), findsNothing);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('two'), findsNothing);
      expect(find.text('three'), findsOneWidget);
    },
  );

  testWidgets(
    'fr03/e03 e05 top half: the newest top-corner notice sits nearest the edge',
    (tester) async {
      _view(tester, _phone);
      await _show(
        tester,
        ['old', 'new'],
        placement: const StratumToastPlacement.float(
          StratumToastCorner.topCenter,
        ),
      );
      final oldTop = tester.getRect(find.text('old')).top;
      final newTop = tester.getRect(find.text('new')).top;
      // R25 mirrored: at a top corner, the newest lands nearest the edge.
      expect(newTop, lessThan(oldTop));
    },
  );

  testWidgets(
    'us01/fr04: a manual close runs the same bookkeeping as the timer, so '
    'a queued solid notice can show',
    (tester) async {
      _view(tester, _phone);
      final handle = tester.ensureSemantics();
      const solidBottom = StratumToastPlacement.solid(StratumToastEdge.bottom);
      await tester.pumpWidget(
        _app(
          ColumnLayout(
            children: [
              _button(
                'go',
                (c) => c.showToast(message: 'one', placement: solidBottom),
              ),
              _button(
                'go2',
                (c) => c.showToast(message: 'two', placement: solidBottom),
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text('one'), findsOneWidget);
      // A manual close (the close button) must run the same bookkeeping
      // the timer close does, clearing `_solidShowing`, or a queued and a
      // freshly-called solid notice both wait behind it forever.
      await tester.tap(find.bySemanticsLabel('Close'));
      await tester.pumpAndSettle();
      expect(find.text('one'), findsNothing);
      await tester.tap(find.text('go2'));
      await tester.pumpAndSettle();
      expect(find.text('two'), findsOneWidget);
      handle.dispose();
    },
  );

  testWidgets('fr03: a manual close frees its corner, so a later show needs no '
      'extra eviction', (tester) async {
    _view(tester, _phone);
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        ColumnLayout(
          children: [
            _button('go', (c) {
              for (final m in ['a', 'b', 'c']) {
                c.showToast(message: m);
              }
            }),
            _button('go2', (c) => c.showToast(message: 'd')),
          ],
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    for (final m in ['a', 'b', 'c']) {
      expect(find.text(m), findsOneWidget);
    }
    // Manually close the newest ('c'); a stale entry left behind in the
    // corner's own list would still read 3 live and wrongly evict the
    // oldest ('a') once a 4th notice lands, though only 2 are live.
    await tester.tap(
      find.descendant(
        of: find
            .ancestor(of: find.text('c'), matching: find.byType(RowLayout))
            .first,
        matching: find.bySemanticsLabel('Close'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('c'), findsNothing);
    await tester.tap(find.text('go2'));
    await tester.pumpAndSettle();
    expect(find.text('a'), findsOneWidget);
    expect(find.text('b'), findsOneWidget);
    expect(find.text('d'), findsOneWidget);
    handle.dispose();
  });

  testWidgets(
    'fr03/e04 second half: a 4th show at one corner leaves another untouched',
    (tester) async {
      _view(tester, _phone);
      await tester.pumpWidget(
        _app(
          _button('go', (c) {
            for (final m in ['a', 'b', 'c', 'd']) {
              c.showToast(
                message: m,
                placement: const StratumToastPlacement.float(
                  StratumToastCorner.bottomCenter,
                ),
              );
            }
            c.showToast(
              message: 'top',
              placement: const StratumToastPlacement.float(
                StratumToastCorner.topCenter,
              ),
            );
          }),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text('a'), findsNothing);
      for (final m in ['b', 'c', 'd']) {
        expect(find.text(m), findsOneWidget);
      }
      expect(find.text('top'), findsOneWidget);
    },
  );
}
