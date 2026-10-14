import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import '../../common/fakes/fake_stratum_theme.dart';

// The page-area registration of M4-T27 (N12 to N14, R26): the areas a
// PageLayout registers with the host and the margins they move — footer,
// bottom, left pane, keyboard — plus the page `snack` style layer
// (s03 invariant 16) and the render-level rect reporting that needs no
// page rebuild (N12).

const _desktop = Size(1400, 900);
const _tablet = Size(700, 1000);
const _phone = Size(390, 844);

/// A test view [size] logical pixels large, reset after the test (N4).
void _view(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// [home] under the theme and the toast host above the app's navigator,
/// as `MaterialApp.builder` places it, in [direction] (E07, E01).
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
      home: home,
    );

/// A button labeled [label] whose tap runs [show] with its context.
Widget _button(String label, void Function(BuildContext) show) => Builder(
  builder: (c) => TextButton(onPressed: () => show(c), child: Text(label)),
);

/// The surface box of the notice holding [message]: the outermost
/// `ContainerLayout` under it.
Finder _fill(String message) => find
    .ancestor(of: find.text(message), matching: find.byType(ContainerLayout))
    .last;

void main() {
  testWidgets(
    'us01/fr02/e05: a solid bottom notice sits directly above the page '
    'footer',
    (tester) async {
      _view(tester, _phone);
      await tester.pumpWidget(
        _app(
          PageLayout(
            body: _button(
              'go',
              (c) => c.showToast(
                message: 'Above',
                placement: const StratumToastPlacement.solid(
                  StratumToastEdge.bottom,
                ),
              ),
            ),
            footer: const SizedBox(height: 60, child: Text('footer')),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      final footerTop = tester.getRect(find.text('footer')).top;
      // Directly above: the fill's bottom equals the footer's top (E05),
      // never over it.
      expect(tester.getRect(_fill('Above')).bottom, closeTo(footerTop, 1));
    },
  );

  testWidgets(
    'us01/fr02/e05: a solid bottom notice sits above the page bottom bar '
    'with no footer',
    (tester) async {
      _view(tester, _phone);
      await tester.pumpWidget(
        _app(
          PageLayout(
            body: _button(
              'go',
              (c) => c.showToast(
                message: 'Bot',
                placement: const StratumToastPlacement.solid(
                  StratumToastEdge.bottom,
                ),
              ),
            ),
            bottom: const SizedBox(height: 40, child: Text('bottombar')),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      final bottomTop = tester.getRect(find.text('bottombar')).top;
      expect(tester.getRect(_fill('Bot')).bottom, closeTo(bottomTop, 1));
    },
  );

  testWidgets('n15: a solid bottom notice sits above the higher of footer and '
      'keyboard', (tester) async {
    _view(tester, _phone);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      _app(
        PageLayout(
          body: _button(
            'go',
            (c) => c.showToast(
              message: 'Both',
              placement: const StratumToastPlacement.solid(
                StratumToastEdge.bottom,
              ),
            ),
          ),
          footer: const SizedBox(height: 60, child: Text('footer')),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    // The keyboard (300) is higher than the footer (60): the notice
    // rides above the keyboard, not one footer height above it (N15).
    expect(tester.getRect(_fill('Both')).bottom, closeTo(844 - 300, 1));
  });

  testWidgets(
    'n15: a footer taller than the keyboard keeps the notice above the '
    'footer',
    (tester) async {
      _view(tester, _phone);
      tester.view.viewInsets = const FakeViewPadding(bottom: 100);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        _app(
          PageLayout(
            body: _button(
              'go',
              (c) => c.showToast(
                message: 'Tall',
                placement: const StratumToastPlacement.solid(
                  StratumToastEdge.bottom,
                ),
              ),
            ),
            footer: const SizedBox(height: 200, child: Text('footer')),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      final footerTop = tester.getRect(find.text('footer')).top;
      expect(tester.getRect(_fill('Tall')).bottom, closeTo(footerTop, 1));
    },
  );

  testWidgets(
    'r26: us01/fr02/e10: a bottom float sits above the footer on mobile',
    (tester) async {
      _view(tester, _phone);
      await tester.pumpWidget(
        _app(
          PageLayout(
            body: _button(
              'go',
              (c) => c.showToast(
                message: 'FloatUp',
                placement: const StratumToastPlacement.float(
                  StratumToastCorner.bottomStart,
                ),
              ),
            ),
            footer: const SizedBox(height: 60, child: Text('footer')),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      final footerTop = tester.getRect(find.text('footer')).top;
      // R26: on mobile and tablet a bottom float rises above the footer
      // too, the float margin above it.
      final lg = tester.element(find.text('FloatUp')).theme.space.lg;
      expect(
        tester.getRect(_fill('FloatUp')).bottom,
        closeTo(footerTop - lg, 1),
      );
    },
  );

  testWidgets(
    'us01/fr02/e07: a desktop float stays inside the body, never over the '
    'left pane',
    (tester) async {
      _view(tester, _desktop);
      await tester.pumpWidget(
        _app(
          PageLayout(
            left: const SizedBox(width: 300, child: Text('left')),
            body: _button(
              'go',
              (c) => c.showToast(
                message: 'Inside',
                placement: const StratumToastPlacement.float(
                  StratumToastCorner.bottomStart,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      // N9: assert against the pane's real rect, not the child's width:
      // the pane opens at its Figma width (260 at desktop), not 300.
      final paneRight = tester.getRect(find.text('left')).right;
      expect(
        tester.getRect(_fill('Inside')).left,
        greaterThanOrEqualTo(paneRight),
      );
    },
  );

  testWidgets('n12: a pane widened after the show moves a float with no page '
      'rebuild', (tester) async {
    _view(tester, _desktop);
    final builds = <String, int>{};
    Widget counter(String name) =>
        _BuilderCounter(name, builds, key: ValueKey(name));
    final controller = PageLayoutController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(
        PageLayout(
          left: counter('left'),
          body: ColumnLayout(
            children: [
              counter('body'),
              _button(
                'go',
                (c) => c.showToast(
                  message: 'Moved',
                  placement: const StratumToastPlacement.float(
                    StratumToastCorner.bottomStart,
                  ),
                ),
              ),
            ],
          ),
          controller: controller,
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    builds.clear();
    // A code-set width needs no rebuild; the render-level reporter
    // must move the float (N12) while every slot builds zero times.
    controller.leftWidth = 500;
    await tester.pumpAndSettle();
    expect(builds, isEmpty);
    final paneRight = tester.getRect(find.text('left')).right;
    expect(
      tester.getRect(_fill('Moved')).left,
      greaterThanOrEqualTo(paneRight),
    );
  });

  testWidgets(
    'n12: a resize within one window size moves a solid bottom notice '
    'with no page rebuild',
    (tester) async {
      _view(tester, _desktop);
      final builds = <String, int>{};
      await tester.pumpWidget(
        _app(
          PageLayout(
            body: ColumnLayout(
              children: [
                _BuilderCounter('body', builds, key: const ValueKey('body')),
                _button(
                  'go',
                  (c) => c.showToast(
                    message: 'Resized',
                    placement: const StratumToastPlacement.solid(
                      StratumToastEdge.bottom,
                    ),
                  ),
                ),
              ],
            ),
            footer: const SizedBox(height: 60, child: Text('footer')),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      builds.clear();
      // Desktop to a still-desktop width: no window-size crossing, so no
      // slot rebuilds, but the footer's rect changed, and the notice
      // follows it (N12).
      tester.view.physicalSize = const Size(1300, 900);
      await tester.pumpAndSettle();
      expect(builds, isEmpty);
      final footerTop = tester.getRect(find.text('footer')).top;
      expect(tester.getRect(_fill('Resized')).bottom, closeTo(footerTop, 1));
    },
  );

  testWidgets(
    'n13: a notice shown before the page writes still follows the page '
    'areas',
    (tester) async {
      _view(tester, _phone);
      // Show from outside the page first: the notice lands with the page
      // still unwritten; the page's first write must move it (N13: the
      // margin reads the registry from its own context, so a later write
      // rebuilds it).
      await tester.pumpWidget(
        _app(
          StackLayout(
            children: [
              const Positioned(top: 0, left: 0, child: Text('page host')),
              PageLayout(
                body: _button(
                  'show',
                  (c) => c.showToast(
                    message: 'Early',
                    placement: const StratumToastPlacement.solid(
                      StratumToastEdge.bottom,
                    ),
                  ),
                ),
                footer: const SizedBox(height: 60, child: Text('footer')),
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.text('show'));
      await tester.pumpAndSettle();
      final footerTop = tester.getRect(find.text('footer')).top;
      expect(tester.getRect(_fill('Early')).bottom, closeTo(footerTop, 1));
    },
  );

  testWidgets('n14: the host reads the innermost page on the current route', (
    tester,
  ) async {
    _view(tester, _phone);
    await tester.pumpWidget(
      _app(
        PageLayout(
          footer: const SizedBox(height: 40, child: Text('outer footer')),
          body: _button(
            'open',
            (c) => Navigator.of(c).push(
              MaterialPageRoute<void>(
                builder: (_) => PageLayout(
                  footer: const SizedBox(height: 80, child: Text('inner')),
                  body: _button(
                    'go',
                    (b) => b.showToast(
                      message: 'Inner',
                      placement: const StratumToastPlacement.solid(
                        StratumToastEdge.bottom,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    // The inner page's footer (80 tall) wins, not the covered outer
    // page's (40): the host reads the innermost handle on the current
    // route (N14).
    final innerTop = tester.getRect(find.text('inner')).top;
    expect(tester.getRect(_fill('Inner')).bottom, closeTo(innerTop, 1));
    // Popping the inner route: the outer page is current again, and a
    // fresh notice reads its own footer with no rect change (N14) —
    // popped through the navigator, since the pushed page draws no
    // back button of its own.
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
    // The revealed page wrote its areas once at mount; the popped
    // route's handle went quiet, so the outer page's own footer wins
    // with no rect change to re-report.
    final outerTop = tester.getRect(find.text('outer footer')).top;
    // Close the first solid notice (its 4 s not yet spent), then show
    // from the revealed page: one solid notice shows at a time.
    await tester.tap(find.bySemanticsLabel('Close'));
    await tester.pumpAndSettle();
    tester
        .element(find.text('open'))
        .showToast(
          message: 'Outer show',
          placement: const StratumToastPlacement.solid(StratumToastEdge.bottom),
        );
    await tester.pumpAndSettle();
    expect(tester.getRect(_fill('Outer show')).bottom, closeTo(outerTop, 1));
  });

  testWidgets(
    'us01/fr06: the page snack style sits between the app-wide layer and '
    'the call',
    (tester) async {
      _view(tester, _phone);
      const page = Color(0xFF00FF00);
      await tester.pumpWidget(
        _app(
          PageLayout(
            customStyle: const PageLayoutStyle(
              snack: WidgetStyle(backgroundColor: page),
            ),
            body: _button('go', (c) => c.showToast(message: 'Snack')),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      final style = tester.widget<ContainerLayout>(_fill('Snack')).style!;
      expect(style.backgroundColor, page);
    },
  );

  testWidgets(
    's03 invariant 16: a call customStyle still wins over the page snack '
    'layer',
    (tester) async {
      _view(tester, _phone);
      const page = Color(0xFF00FF00);
      const call = Color(0xFF0000FF);
      await tester.pumpWidget(
        _app(
          PageLayout(
            customStyle: const PageLayoutStyle(
              snack: WidgetStyle(backgroundColor: page),
            ),
            body: _button(
              'go',
              (c) => c.showToast(
                message: 'Order',
                customStyle: const WidgetStyle(backgroundColor: call),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      final style = tester.widget<ContainerLayout>(_fill('Order')).style!;
      expect(style.backgroundColor, call);
    },
  );

  testWidgets(
    'n14: the registry clears when the page unmounts, and a notice then '
    'ignores it',
    (tester) async {
      _view(tester, _phone);
      late StateSetter setPage;
      var withPage = true;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) {
              setPage = setState;
              return withPage
                  ? PageLayout(
                      footer: const SizedBox(height: 60, child: Text('footer')),
                      body: _button(
                        'go',
                        (c) => c.showToast(
                          message: 'Gone',
                          placement: const StratumToastPlacement.solid(
                            StratumToastEdge.bottom,
                          ),
                        ),
                      ),
                    )
                  : _button(
                      'go2',
                      (c) => c.showToast(
                        message: 'Gone2',
                        placement: const StratumToastPlacement.solid(
                          StratumToastEdge.bottom,
                        ),
                      ),
                    );
            },
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      final footerTop = tester.getRect(find.text('footer')).top;
      expect(tester.getRect(_fill('Gone')).bottom, closeTo(footerTop, 1));
      // The page unmounts: the handle drops, and the next notice sits at
      // the screen edge (the registered areas are gone; only the solid
      // queue shows one at a time, so close the first).
      await tester.tap(find.bySemanticsLabel('Close'));
      await tester.pumpAndSettle();
      setPage(() => withPage = false);
      await tester.pumpAndSettle();
      await tester.tap(find.text('go2'));
      await tester.pumpAndSettle();
      // No page: the fill runs under the home indicator, its bottom at
      // the screen bottom.
      expect(tester.getRect(_fill('Gone2')).bottom, closeTo(844, 1));
    },
  );

  testWidgets(
    'critical: a customStyle.snack change on an already-registered page '
    'does not crash the registry scope',
    (tester) async {
      _view(tester, _phone);
      late StateSetter setColor;
      var color = const Color(0xFF00FF00);
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) {
              setColor = setState;
              return PageLayout(
                customStyle: PageLayoutStyle(
                  snack: WidgetStyle(backgroundColor: color),
                ),
                snack: const Text('snack widget'),
                body: const SizedBox(),
              );
            },
          ),
        ),
      );
      // Settles one frame first: the handle's registry listener attaches
      // only post-frame, so the crash this proves against needs the page
      // already registered before the style write below.
      await tester.pumpAndSettle();
      setColor(() => color = const Color(0xFF0000FF));
      await tester.pumpAndSettle();
      // No `markNeedsBuild() called during build` from `_snack` writing
      // the registry straight from `build()` (the Critical finding).
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('perf: a pane-width write on one mounted page does not rebuild '
      'another mounted page sharing the same registry', (tester) async {
    _view(tester, _desktop);
    final keyA = GlobalKey();
    final keyB = GlobalKey();
    final controllerA = PageLayoutController();
    final controllerB = PageLayoutController();
    addTearDown(controllerA.dispose);
    addTearDown(controllerB.dispose);
    await tester.pumpWidget(
      _app(
        IndexedStack(
          index: 0,
          children: [
            PageLayout(
              key: keyA,
              left: const SizedBox(width: 200, child: Text('leftA')),
              body: const SizedBox(),
              controller: controllerA,
            ),
            PageLayout(
              key: keyB,
              body: const SizedBox(),
              controller: controllerB,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    // `debugOnRebuildDirtyWidget` fires on every dirtied Element's
    // rebuild, unlike a child-widget build counter, which an unchanged
    // widget instance further down the tree would mask (Flutter reuses
    // that Element outright): it catches B's own `PageLayoutState`
    // rebuilding even though every widget it then passes down is
    // unchanged.
    var bRebuilds = 0;
    debugOnRebuildDirtyWidget = (element, _) {
      if (element.widget.key == keyB) bRebuilds++;
    };
    addTearDown(() => debugOnRebuildDirtyWidget = null);
    // A's pane write bumps the shared registry's version; only a
    // dependent of that version should rebuild, and B's own
    // registration bookkeeping must not be one (Performance Important
    // 1).
    controllerA.leftWidth = 500;
    await tester.pumpAndSettle();
    expect(bRebuilds, 0);
  });

  testWidgets(
    'n12: a real pointer drag of the left divider moves a showing float '
    'once it settles',
    (tester) async {
      _view(tester, _desktop);
      final controller = PageLayoutController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(
          PageLayout(
            left: const SizedBox(width: 300, child: Text('left')),
            body: _button(
              'go',
              (c) => c.showToast(
                message: 'Dragged',
                placement: const StratumToastPlacement.float(
                  StratumToastCorner.bottomStart,
                ),
              ),
            ),
            controller: controller,
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      final divider = find.bySemanticsLabel('Resize panes');
      await tester.dragFrom(tester.getCenter(divider), const Offset(200, 0));
      await tester.pumpAndSettle();
      final paneRight = tester.getRect(find.text('left')).right;
      expect(
        tester.getRect(_fill('Dragged')).left,
        greaterThanOrEqualTo(paneRight),
      );
    },
  );

  testWidgets(
    'r26: a bottom float with the keyboard open rises above the footer '
    'beyond it',
    (tester) async {
      _view(tester, _phone);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        _app(
          PageLayout(
            body: _button(
              'go',
              (c) => c.showToast(
                message: 'FloatKeyboard',
                placement: const StratumToastPlacement.float(
                  StratumToastCorner.bottomStart,
                ),
              ),
            ),
            footer: const SizedBox(height: 60, child: Text('footer')),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      // The keyboard (300) is taller than the footer (60): the float
      // rides above the keyboard plus its own margin, not one footer
      // height above it (R26 extends N15's rule to floats).
      final lg = tester.element(find.text('FloatKeyboard')).theme.space.lg;
      expect(
        tester.getRect(_fill('FloatKeyboard')).bottom,
        closeTo(844 - 300 - lg, 1),
      );
    },
  );

  testWidgets(
    'r26: us01/fr02/e10: a bottom float sits above the footer on tablet',
    (tester) async {
      _view(tester, _tablet);
      await tester.pumpWidget(
        _app(
          PageLayout(
            body: _button(
              'go',
              (c) => c.showToast(
                message: 'TabletFloat',
                placement: const StratumToastPlacement.float(
                  StratumToastCorner.bottomStart,
                ),
              ),
            ),
            footer: const SizedBox(height: 60, child: Text('footer')),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      final footerTop = tester.getRect(find.text('footer')).top;
      final lg = tester.element(find.text('TabletFloat')).theme.space.lg;
      expect(
        tester.getRect(_fill('TabletFloat')).bottom,
        closeTo(footerTop - lg, 1),
      );
    },
  );

  testWidgets(
    'us01/fr02/e07: a desktop float mirrors the left-pane clearance under '
    'rtl',
    (tester) async {
      _view(tester, _desktop);
      await tester.pumpWidget(
        _app(
          PageLayout(
            left: const SizedBox(width: 300, child: Text('left')),
            body: _button(
              'go',
              (c) => c.showToast(
                message: 'InsideRtl',
                placement: const StratumToastPlacement.float(
                  StratumToastCorner.bottomStart,
                ),
              ),
            ),
          ),
          direction: TextDirection.rtl,
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      // Under rtl the `left` slot renders at the physically right edge,
      // and `bottomStart` mirrors to that same corner: the float still
      // clears the pane, now measured from the right (E07).
      final paneLeft = tester.getRect(find.text('left')).left;
      expect(
        tester.getRect(_fill('InsideRtl')).right,
        lessThanOrEqualTo(paneLeft),
      );
    },
  );

  testWidgets(
    'us01/fr02/e07: a desktop float stays inside the body, never over the '
    'right pane',
    (tester) async {
      _view(tester, _desktop);
      await tester.pumpWidget(
        _app(
          PageLayout(
            right: const SizedBox(width: 300, child: Text('right')),
            body: _button(
              'go',
              (c) => c.showToast(
                message: 'InsideEnd',
                placement: const StratumToastPlacement.float(
                  StratumToastCorner.bottomEnd,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      final paneLeft = tester.getRect(find.text('right')).left;
      expect(
        tester.getRect(_fill('InsideEnd')).right,
        lessThanOrEqualTo(paneLeft),
      );
    },
  );

  testWidgets(
    'desktop float at bottomCenter centers in the body, never over the '
    'left pane',
    (tester) async {
      _view(tester, _desktop);
      await tester.pumpWidget(
        _app(
          PageLayout(
            left: const SizedBox(width: 300, child: Text('left')),
            body: _button(
              'go',
              (c) => c.showToast(
                message: 'Center',
                placement: const StratumToastPlacement.float(
                  StratumToastCorner.bottomCenter,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      final paneRight = tester.getRect(find.text('left')).right;
      final expectedCenter = (paneRight + _desktop.width) / 2;
      expect(
        tester.getRect(_fill('Center')).center.dx,
        closeTo(expectedCenter, 1),
      );
      expect(
        tester.getRect(_fill('Center')).left,
        greaterThanOrEqualTo(paneRight),
      );
    },
  );

  // A route transition moves the page by a paint-time transform, with no
  // layout of the page: its areas must follow once the transition
  // settles, not keep the transition's first frame (performance I1,
  // edge I5).
  for (final (name, transitions) in [
    ('Cupertino', const CupertinoPageTransitionsBuilder()),
    ('FadeForwards', const FadeForwardsPageTransitionsBuilder()),
  ]) {
    testWidgets(
      'i1/i5: a desktop float on a page pushed through a $name transition '
      'sits beside the left pane once the transition settles',
      (tester) async {
        _view(tester, _desktop);
        await tester.pumpWidget(
          _app(
            _button(
              'open',
              (c) => Navigator.of(c).push(
                _TransitionRoute(
                  transitions,
                  builder: (_) => PageLayout(
                    left: const SizedBox(width: 300, child: Text('left')),
                    body: _button(
                      'go',
                      (b) => b.showToast(
                        message: 'Pushed',
                        placement: const StratumToastPlacement.float(
                          StratumToastCorner.bottomStart,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('go'));
        await tester.pumpAndSettle();
        // The float's start margin is `space.lg` past the body's left
        // edge, which is the pane's right edge on this page.
        final paneRight = tester.getRect(find.text('left')).right;
        final lg = tester.element(find.text('Pushed')).theme.space.lg;
        expect(
          tester.getRect(_fill('Pushed')).left,
          closeTo(paneRight + lg, 1),
        );
      },
    );
  }

  testWidgets(
    'correctness: a height-only window shrink keeps a solid bottom notice '
    'on the footer, whose offset moved with no layout of its own',
    (tester) async {
      _view(tester, _desktop);
      await tester.pumpWidget(
        _app(
          PageLayout(
            body: _button(
              'go',
              (c) => c.showToast(
                message: 'Shrunk',
                placement: const StratumToastPlacement.solid(
                  StratumToastEdge.bottom,
                ),
              ),
            ),
            footer: const SizedBox(height: 60, child: Text('footer')),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      // Same width, so the footer's constraints hold and it is never laid
      // out again; only its offset moves up.
      tester.view.physicalSize = const Size(1400, 700);
      await tester.pumpAndSettle();
      final footerTop = tester.getRect(find.text('footer')).top;
      expect(tester.getRect(_fill('Shrunk')).bottom, closeTo(footerTop, 1));
    },
  );

  testWidgets(
    'i3: a push and pop over a two-page shell rebuild neither page once a '
    'notice has built',
    (tester) async {
      _view(tester, _phone);
      final keyA = GlobalKey();
      final keyB = GlobalKey();
      await tester.pumpWidget(
        _app(
          IndexedStack(
            index: 0,
            children: [
              PageLayout(
                key: keyA,
                body: _button('go', (c) => c.showToast(message: 'Shell')),
              ),
              PageLayout(key: keyB, body: const SizedBox()),
            ],
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      var rebuilds = 0;
      debugOnRebuildDirtyWidget = (element, _) {
        final key = element.widget.key;
        if (key == keyA || key == keyB) rebuilds++;
      };
      addTearDown(() => debugOnRebuildDirtyWidget = null);
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      )..push(MaterialPageRoute<void>(builder: (_) => const Text('over')));
      await tester.pumpAndSettle();
      navigator.pop();
      await tester.pumpAndSettle();
      // The route-status read that picks the current page lives in a leaf
      // under each page, so a push or pop rebuilds that leaf, never the
      // page (performance I3).
      expect(rebuilds, 0);
    },
  );

  // A branch shell keeps every branch's page mounted on one current route;
  // only the shown branch's page may win (edge I6).
  for (final (name, shell) in [
    (
      'go_router StatefulShellRoute.indexedStack',
      (int index, List<Widget> pages) => IndexedStack(
        index: index,
        children: [
          for (final (i, page) in pages.indexed)
            Offstage(
              offstage: i != index,
              child: TickerMode(enabled: i == index, child: page),
            ),
        ],
      ),
    ),
    (
      'IndexedStack',
      (int index, List<Widget> pages) =>
          IndexedStack(index: index, children: pages),
    ),
  ]) {
    testWidgets('i6: a page in a hidden $name branch never wins the host, '
        'even mounted after the shown one', (tester) async {
      _view(tester, _phone);
      late StateSetter setIndex;
      var index = 1;
      final pages = [
        PageLayout(
          footer: const SizedBox(height: 40, child: Text('footer A')),
          body: _button(
            'go',
            (c) => c.showToast(
              message: 'Branch',
              placement: const StratumToastPlacement.solid(
                StratumToastEdge.bottom,
              ),
            ),
          ),
        ),
        const PageLayout(
          footer: SizedBox(height: 120, child: Text('footer B')),
          body: SizedBox(),
        ),
      ];
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) {
              setIndex = setState;
              return shell(index, pages);
            },
          ),
        ),
      );
      // Visit branch B first, so its page has written its areas, then
      // return to A.
      await tester.pumpAndSettle();
      setIndex(() => index = 0);
      await tester.pumpAndSettle();
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      final footerTop = tester.getRect(find.text('footer A')).top;
      expect(tester.getRect(_fill('Branch')).bottom, closeTo(footerTop, 1));
    });
  }

  testWidgets(
    'i7: a page with no snack slot publishes each snack style change, and '
    'drops a removed one',
    (tester) async {
      _view(tester, _phone);
      late StateSetter setSnack;
      WidgetStyle? snack;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) {
              setSnack = setState;
              return PageLayout(
                customStyle: PageLayoutStyle(snack: snack),
                body: ColumnLayout(
                  children: [
                    for (final message in ['Before', 'Green', 'After'])
                      _button(message, (c) => c.showToast(message: message)),
                  ],
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      Color? fillOf(String message) =>
          tester.widget<ContainerLayout>(_fill(message)).style!.backgroundColor;
      await tester.tap(find.text('Before'));
      await tester.pumpAndSettle();
      final before = fillOf('Before');
      const green = Color(0xFF00FF00);
      setSnack(() => snack = const WidgetStyle(backgroundColor: green));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Green').first);
      await tester.pumpAndSettle();
      expect(fillOf('Green'), green);
      setSnack(() => snack = null);
      await tester.pumpAndSettle();
      await tester.tap(find.text('After').first);
      await tester.pumpAndSettle();
      expect(fillOf('After'), before);
    },
  );

  for (final direction in TextDirection.values) {
    testWidgets(
      'correctness 4, edge I11: us01/fr02/e07: a desktop top float stays '
      'inside the body, beside the left pane and below the header, under '
      '${direction.name}',
      (tester) async {
        _view(tester, _desktop);
        await tester.pumpWidget(
          _app(
            PageLayout(
              header: const SizedBox(height: 64, child: Text('header')),
              left: const SizedBox(width: 300, child: Text('left')),
              body: _button(
                'go',
                (c) => c.showToast(
                  message: 'TopInside',
                  placement: const StratumToastPlacement.float(
                    StratumToastCorner.topStart,
                  ),
                ),
              ),
            ),
            direction: direction,
          ),
        );
        await tester.tap(find.text('go'));
        await tester.pumpAndSettle();
        final pane = tester.getRect(find.text('left'));
        final notice = tester.getRect(_fill('TopInside'));
        // `topStart` mirrors with the pane: the float clears it from the
        // pane's side under either direction.
        if (direction == TextDirection.ltr) {
          expect(notice.left, greaterThanOrEqualTo(pane.right));
        } else {
          expect(notice.right, lessThanOrEqualTo(pane.left));
        }
        expect(
          notice.top,
          greaterThanOrEqualTo(tester.getRect(find.text('header')).bottom),
        );
      },
    );
  }

  testWidgets(
    'edge I2: a bottom float and a solid bottom notice above the footer '
    'leave the footer under their offset tappable',
    (tester) async {
      _view(tester, _phone);
      var footerTaps = 0;
      await tester.pumpWidget(
        _app(
          PageLayout(
            body: _button('go', (c) {
              c
                ..showToast(message: 'FloatOver')
                ..showToast(
                  message: 'SolidOver',
                  placement: const StratumToastPlacement.solid(
                    StratumToastEdge.bottom,
                  ),
                );
            }),
            footer: SizedBox(
              height: 60,
              child: TextButton(
                onPressed: () => footerTaps++,
                child: const Text('footer'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text('FloatOver'), findsOneWidget);
      expect(find.text('SolidOver'), findsOneWidget);
      await tester.tap(find.text('footer'), warnIfMissed: false);
      await tester.pump();
      expect(footerTaps, 1);
    },
  );

  testWidgets(
    'edge I2: a desktop float takes no tap beside it, over the pane or the '
    'body',
    (tester) async {
      _view(tester, _desktop);
      var paneTaps = 0;
      var bodyTaps = 0;
      await tester.pumpWidget(
        _app(
          PageLayout(
            left: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => paneTaps++,
              child: const SizedBox.expand(child: Text('left')),
            ),
            body: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => bodyTaps++,
              child: const SizedBox.expand(child: Text('body')),
            ),
          ),
        ),
      );
      tester
          .element(find.text('body'))
          .showToast(
            message: 'Beside',
            placement: const StratumToastPlacement.float(
              StratumToastCorner.bottomStart,
            ),
          );
      await tester.pumpAndSettle();
      final notice = tester.getRect(_fill('Beside'));
      final pane = tester.getRect(find.text('left'));
      expect(notice.left, greaterThanOrEqualTo(pane.right));
      await tester.tapAt(Offset(pane.center.dx, notice.center.dy));
      await tester.tapAt(Offset(notice.right + 100, notice.center.dy));
      await tester.pump();
      expect(paneTaps, 1);
      expect(bodyTaps, 1);
    },
  );

  // A page's route reads move to the page's probe leaf, so a loading cycle
  // or a drawer focus leaves the page free of push and pop rebuilds
  // (final-fix-c report, out-of-scope note).

  Future<int> pageRebuildsOverPushAndPop(
    WidgetTester tester,
    GlobalKey page,
  ) async {
    var rebuilds = 0;
    debugOnRebuildDirtyWidget = (element, _) {
      if (element.widget.key == page) rebuilds++;
    };
    addTearDown(() => debugOnRebuildDirtyWidget = null);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator).first)
      ..push(MaterialPageRoute<void>(builder: (_) => const Text('over')));
    await tester.pumpAndSettle();
    navigator.pop();
    await tester.pumpAndSettle();
    debugOnRebuildDirtyWidget = null;
    return rebuilds;
  }

  testWidgets('a loading cycle leaves the page free of push and pop rebuilds', (
    tester,
  ) async {
    _view(tester, _phone);
    final key = GlobalKey();
    final loading = ValueNotifier(false);
    addTearDown(loading.dispose);
    await tester.pumpWidget(
      _app(
        ValueListenableBuilder<bool>(
          valueListenable: loading,
          builder: (_, on, _) =>
              PageLayout(key: key, loading: on, body: const Text('page')),
        ),
      ),
    );
    loading.value = true;
    await tester.pump(const Duration(milliseconds: 500));
    loading.value = false;
    await tester.pumpAndSettle();
    expect(await pageRebuildsOverPushAndPop(tester, key), 0);
  });

  testWidgets('a drawer focus leaves the page free of push and pop rebuilds', (
    tester,
  ) async {
    _view(tester, _phone);
    final key = GlobalKey();
    final controller = PageLayoutController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(
        PageLayout(
          key: key,
          controller: controller,
          left: const Text('drawer item'),
          body: const Text('page'),
        ),
      ),
    );
    controller.openLeft();
    await tester.pumpAndSettle();
    controller.close();
    await tester.pumpAndSettle();
    expect(await pageRebuildsOverPushAndPop(tester, key), 0);
  });

  testWidgets(
    'r29: a desktop float sits above the footer, inside the body, beside '
    'the left pane',
    (tester) async {
      _view(tester, _desktop);
      await tester.pumpWidget(
        _app(
          PageLayout(
            left: const SizedBox(width: 300, child: Text('left')),
            body: _button(
              'go',
              (c) => c.showToast(
                message: 'DesktopFloat',
                placement: const StratumToastPlacement.float(
                  StratumToastCorner.bottomEnd,
                ),
              ),
            ),
            footer: const SizedBox(height: 60, child: Text('footer')),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      final footerTop = tester.getRect(find.text('footer')).top;
      final paneRight = tester.getRect(find.text('left')).right;
      final lg = tester.element(find.text('DesktopFloat')).theme.space.lg;
      // R29 extends R26 to desktop: a bottom float rises above the
      // footer there too, still clear of the left pane (E07).
      expect(
        tester.getRect(_fill('DesktopFloat')).bottom,
        closeTo(footerTop - lg, 1),
      );
      expect(
        tester.getRect(_fill('DesktopFloat')).left,
        greaterThanOrEqualTo(paneRight),
      );
    },
  );

  testWidgets(
    'r29: a desktop float with the keyboard open still clears a taller '
    'footer, the max rule unchanged',
    (tester) async {
      _view(tester, _desktop);
      tester.view.viewInsets = const FakeViewPadding(bottom: 100);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        _app(
          PageLayout(
            body: _button(
              'go',
              (c) => c.showToast(
                message: 'DesktopFloatTallFooter',
                placement: const StratumToastPlacement.float(
                  StratumToastCorner.bottomStart,
                ),
              ),
            ),
            footer: const SizedBox(height: 300, child: Text('footer')),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      final footerTop = tester.getRect(find.text('footer')).top;
      final lg = tester
          .element(find.text('DesktopFloatTallFooter'))
          .theme
          .space
          .lg;
      // The footer (300) outranks the keyboard (100): the max rule still
      // picks the taller one on desktop (R29 extends N15 to floats).
      expect(
        tester.getRect(_fill('DesktopFloatTallFooter')).bottom,
        closeTo(footerTop - lg, 1),
      );
    },
  );
}

/// A page route that runs [transitions] whatever the theme's map says.
class _TransitionRoute extends MaterialPageRoute<void> {
  // ignore: unnecessary_type_name_in_constructor, test-local route
  _TransitionRoute(this.transitions, {required super.builder});

  final PageTransitionsBuilder transitions;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => transitions.buildTransitions(
    this,
    context,
    animation,
    secondaryAnimation,
    child,
  );
}

/// Counts its own builds, by [name], in [counts]; a stable key keeps the
/// same `Element` across a resize that leaves the tree in place.
class _BuilderCounter extends StatelessWidget {
  // ignore: unnecessary_type_name_in_constructor, test-local widget
  const _BuilderCounter(this.name, this.counts, {super.key});

  final String name;
  final Map<String, int> counts;

  @override
  Widget build(BuildContext context) {
    counts.update(name, (n) => n + 1, ifAbsent: () => 1);
    return Text(name);
  }
}
