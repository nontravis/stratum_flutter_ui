import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import '../fakes/fake_stratum_theme.dart';

/// Counts its own builds, by [name], in [counts]; a stable key keeps the
/// same `Element` across a resize that leaves the widget tree in place.
class _Counter extends StatelessWidget {
  new(this.name, this.counts) : super(key: ValueKey(name));

  final String name;
  final Map<String, int> counts;

  @override
  Widget build(BuildContext context) {
    counts.update(name, (n) => n + 1, ifAbsent: () => 1);
    return Text(name);
  }
}

/// Sizes the test view to [size], reset after the test: a mid-test resize
/// sets `tester.view.physicalSize` again and pumps, with no second
/// `pumpWidget`, so the render surface and `MediaQuery.sizeOf` agree and no
/// slot widget is rebuilt from scratch (Q2).
void _view(WidgetTester tester, Size size) {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// [header], [left], [body], and [footer] in one [PageLayout], under a
/// theme and direction only: no ambient `MediaQuery` override, since the
/// view's own size is read directly (Q2).
Widget _page({
  Widget? header,
  Widget? left,
  required Widget body,
  Widget? footer,
  PageLayoutController? controller,
  bool loading = false,
}) => StratumThemeApplication(
  themes: StratumThemeSet(light: fakeTheme),
  themeMode: ThemeMode.light,
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: PageLayout(
      header: header,
      left: left,
      body: body,
      footer: footer,
      controller: controller,
      loading: loading,
    ),
  ),
);

void main() {
  group('PageLayout build counts (US-18 FR-02; layout s03 invariant 63)', () {
    testWidgets('fo06/us18/fr02/e01: a drawer opens and closes, no slot builds '
        'again', (tester) async {
      _view(tester, const Size(390, 844));
      final counts = <String, int>{};
      final controller = PageLayoutController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _page(
          header: _Counter('header', counts),
          left: _Counter('left', counts),
          body: _Counter('body', counts),
          footer: _Counter('footer', counts),
          controller: controller,
        ),
      );
      counts.clear();
      controller.openLeft();
      await tester.pumpAndSettle();
      controller.close();
      await tester.pumpAndSettle();
      // 'left' builds once when the drawer shows its content; every other
      // slot builds zero times.
      expect(counts.keys.where((key) => key != 'left'), isEmpty);
      expect(counts['left'], 1);
    });

    testWidgets(
      'fo06/us18/fr02/e01: the iOS slide drawer opens and closes, no slot '
      'builds again',
      (tester) async {
        _view(tester, const Size(390, 844));
        final counts = <String, int>{};
        final controller = PageLayoutController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          _page(
            header: _Counter('header', counts),
            left: _Counter('left', counts),
            body: _Counter('body', counts),
            footer: _Counter('footer', counts),
            controller: controller,
          ),
        );
        counts.clear();
        controller.openLeft();
        await tester.pumpAndSettle();
        controller.close();
        await tester.pumpAndSettle();
        expect(counts.keys.where((key) => key != 'left'), isEmpty);
        expect(counts['left'], 1);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets(
      'fo06/us18/fr02/e02: fo06/us19/fr06/e04: a 60-frame pane drag builds no slot',
      (tester) async {
        _view(tester, const Size(1300, 800));
        final counts = <String, int>{};
        await tester.pumpWidget(
          _page(
            header: _Counter('header', counts),
            left: _Counter('left', counts),
            body: _Counter('body', counts),
            footer: _Counter('footer', counts),
          ),
        );
        counts.clear();
        final gesture = await tester.startGesture(
          tester.getCenter(find.bySemanticsLabel('Resize panes').first),
        );
        for (var i = 0; i < 60; i++) {
          await gesture.moveBy(const Offset(1, 0));
          await tester.pump();
        }
        await gesture.up();
        await tester.pump();
        expect(counts, isEmpty);
      },
    );

    testWidgets(
      'fo06/us18/fr02/e03: a tablet-to-desktop resize, both above the drawer '
      'cut, builds no slot',
      (tester) async {
        _view(tester, const Size(1000, 800)); // tablet
        final counts = <String, int>{};
        await tester.pumpWidget(
          _page(
            header: _Counter('header', counts),
            left: _Counter('left', counts),
            body: _Counter('body', counts),
            footer: _Counter('footer', counts),
          ),
        );
        counts.clear();
        tester.view.physicalSize = const Size(1300, 800); // desktop
        await tester.pump();
        expect(counts, isEmpty);
      },
    );

    testWidgets(
      'fo06/us19/fr01/e05: a drawer-cut crossing remounts no center slot',
      (tester) async {
        _view(tester, const Size(390, 844)); // mobile: left is a closed
        // drawer, never built.
        final counts = <String, int>{};
        await tester.pumpWidget(
          _page(
            header: _Counter('header', counts),
            left: _Counter('left', counts),
            body: _Counter('body', counts),
            footer: _Counter('footer', counts),
          ),
        );
        counts.clear();
        tester.view.physicalSize = const Size(1000, 800); // tablet: left
        // becomes an inline pane in the same SplitLayout tree.
        await tester.pump();
        expect(counts.keys.where((key) => key != 'left'), isEmpty);
        expect(counts['left'], 1);
      },
    );

    testWidgets(
      'fo06/us19/fr01/e05: a drawer-cut crossing down remounts no center slot',
      (tester) async {
        _view(tester, const Size(1000, 800)); // tablet: left is an inline
        // pane, already built.
        final counts = <String, int>{};
        await tester.pumpWidget(
          _page(
            header: _Counter('header', counts),
            left: _Counter('left', counts),
            body: _Counter('body', counts),
            footer: _Counter('footer', counts),
          ),
        );
        counts.clear();
        tester.view.physicalSize = const Size(390, 844); // mobile: left
        // becomes a closed drawer again; a teardown builds nothing.
        await tester.pump();
        expect(counts, isEmpty);
      },
    );

    testWidgets('R22: a controller width set in code builds no slot', (
      tester,
    ) async {
      _view(tester, const Size(1300, 800));
      final counts = <String, int>{};
      final controller = PageLayoutController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _page(
          header: _Counter('header', counts),
          left: _Counter('left', counts),
          body: _Counter('body', counts),
          footer: _Counter('footer', counts),
          controller: controller,
        ),
      );
      counts.clear();
      controller.leftWidth = 300;
      await tester.pump();
      expect(counts, isEmpty);
    });

    testWidgets('R19: toggling loading rebuilds only the loading layer', (
      tester,
    ) async {
      _view(tester, const Size(390, 844));
      final counts = <String, int>{};
      final header = _Counter('header', counts);
      final left = _Counter('left', counts);
      final body = _Counter('body', counts);
      final footer = _Counter('footer', counts);
      await tester.pumpWidget(
        _page(header: header, left: left, body: body, footer: footer),
      );
      counts.clear();
      // Same slot instances both pumps (Q6): only `loading` changes.
      await tester.pumpWidget(
        _page(
          header: header,
          left: left,
          body: body,
          footer: footer,
          loading: true,
        ),
      );
      // Not pumpAndSettle (Q3): the default spinner is indeterminate and
      // never settles while loading stays true.
      await tester.pump(const Duration(milliseconds: 100));
      expect(counts, isEmpty);
    });

    testWidgets(
      'fo06/us18/fr02/e04: the app wraps only body, only its listener rebuilds',
      (tester) async {
        _view(tester, const Size(390, 844));
        final counts = <String, int>{};
        final state = ValueNotifier(0);
        addTearDown(state.dispose);
        await tester.pumpWidget(
          _page(
            header: _Counter('header', counts),
            body: ValueListenableBuilder<int>(
              valueListenable: state,
              builder: (context, value, _) => _Counter('body $value', counts),
            ),
          ),
        );
        counts.clear();
        state.value = 1;
        await tester.pump();
        expect(counts, {'body 1': 1});
      },
    );

    testWidgets(
      'fo06/us18/fr02/e05: the app wraps the whole page, every slot rebuilds',
      (tester) async {
        final counts = <String, int>{};
        final state = ValueNotifier(0);
        addTearDown(state.dispose);
        _view(tester, const Size(390, 844));
        await tester.pumpWidget(
          ValueListenableBuilder<int>(
            valueListenable: state,
            builder: (context, value, _) => _page(
              header: _Counter('header', counts),
              body: _Counter('body', counts),
            ),
          ),
        );
        counts.clear();
        state.value = 1;
        await tester.pump();
        // The app's own choice of scope: both slots it rebuilds build
        // again, since it passed a new widget for each.
        expect(counts, {'header': 1, 'body': 1});
      },
    );
  });
}
