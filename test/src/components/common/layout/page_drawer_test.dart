import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/layout/page_drawer.dart'
    show defaultDrawerType, drawerWidth;
import 'package:stratum_ui/src/components/common/layout/scrim.dart' show Scrim;
import 'package:stratum_ui/src/src.dart';

import '../fakes/fake_stratum_theme.dart';

// NFR-U05: the drawer's own target is its scrim, which covers the whole
// page (tested below); the right overlay drawer's close button and its
// target size arrive with M3-T20, which adds that button.

const _phone = Size(360, 780);
const _tablet = Size(1000, 800);

/// A test view [size] logical pixels large, reset after the test.
void _view(WidgetTester tester, [Size size = _phone]) {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// [page] under [theme], else [fakeTheme], in [direction], with the app's
/// default Tab and activation keys in a focused scope, and the view's media
/// data edited by [media] below the theme: a sized view and an edit of the
/// context's own media data, never an outer `MediaQuery` the host shadows
/// (P2).
Widget _host(
  Widget page, {
  TextDirection direction = TextDirection.ltr,
  StratumThemeData? theme,
  MediaQueryData Function(MediaQueryData data)? media,
  bool highContrast = false,
}) => StratumThemeApplication(
  themes: highContrast
      ? defaultThemeSet
      : StratumThemeSet(light: theme ?? fakeTheme),
  themeMode: ThemeMode.light,
  highContrast: highContrast
      ? StratumHighContrastMode.on
      : StratumHighContrastMode.system,
  child: Directionality(
    textDirection: direction,
    child: Shortcuts(
      shortcuts: WidgetsApp.defaultShortcuts,
      child: Actions(
        actions: WidgetsApp.defaultActions,
        child: FocusScope(
          autofocus: true,
          child: media == null
              ? page
              : Builder(
                  builder: (context) => MediaQuery(
                    data: media(MediaQuery.of(context)),
                    child: page,
                  ),
                ),
        ),
      ),
    ),
  ),
);

/// [home] in a `MaterialApp` under [fakeTheme], so pages push and pop.
Widget _app(Widget home) => MaterialApp(
  builder: (context, child) => StratumThemeApplication(
    themes: StratumThemeSet(light: fakeTheme),
    themeMode: ThemeMode.light,
    child: child ?? const SizedBox.shrink(),
  ),
  home: home,
);

/// A body button `Menu` that opens the start drawer, as an app's menu
/// button does.
class _Menu extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => PageLayout.of(context).openLeft(),
    child: const Text('Menu'),
  );
}

/// A phone page with a start drawer that shows `drawer item` and a body
/// [_Menu] button.
Widget _page({
  Key? key,
  ValueChanged<PageDrawerSide?>? changed,
  bool edgeSwipe = true,
  PageSide leftSide = const PageSide(),
  PageSide rightSide = const PageSide(),
  Widget left = const Text('drawer item'),
  Widget? right,
  PageLayoutController? controller,
  PageLayoutStyle? style,
  bool loading = false,
}) => PageLayout(
  key: key,
  loading: loading,
  controller: controller,
  onDrawerChanged: changed,
  edgeSwipe: edgeSwipe,
  leftSide: leftSide,
  rightSide: rightSide,
  customStyle: style,
  left: left,
  right: right,
  body: const _Menu(),
);

/// Pumps [page] in a [size] view under [_host].
Future<void> _pump(
  WidgetTester tester,
  Widget page, {
  Size size = _phone,
  TextDirection direction = TextDirection.ltr,
  StratumThemeData? theme,
  MediaQueryData Function(MediaQueryData data)? media,
  bool highContrast = false,
}) async {
  _view(tester, size);
  await tester.pumpWidget(
    _host(
      page,
      direction: direction,
      theme: theme,
      media: media,
      highContrast: highContrast,
    ),
  );
}

/// Taps `Menu` and lets the drawer settle open.
Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(find.text('Menu'));
  await tester.pumpAndSettle();
}

/// A drawer text only as large as its glyphs: a full-panel text node's
/// rect, grown by the guideline's 4 px margin, would sample the scrim beside
/// the panel and hide the panel's own contrast (NFR-U01, NFR-U07).
const _glyphs = Align(
  alignment: Alignment.topCenter,
  child: Text('drawer item'),
);

Finder get _drawer => find.bySemanticsLabel('Navigation menu');

/// The drawer panel: the nearest `ContainerLayout` above `drawer item`.
Finder get _panel => find
    .ancestor(
      of: find.text('drawer item'),
      matching: find.byType(ContainerLayout),
    )
    .first;

WidgetStyle _panelStyle(WidgetTester tester) =>
    tester.widget<ContainerLayout>(_panel).style!;

/// The body slot's box, which holds `Menu`.
Finder get _body => find
    .ancestor(of: find.text('Menu'), matching: find.byType(ContainerLayout))
    .first;

/// The scrim's fill box.
Finder get _scrim => find.descendant(
  of: find.byType(Scrim),
  matching: find.byType(ContainerLayout),
);

/// The opacity the panel's fade reaches this frame.
double _panelOpacity(WidgetTester tester) => tester
    .widget<FadeTransition>(
      find
          .ancestor(
            of: find.text('drawer item'),
            matching: find.byType(FadeTransition),
          )
          .first,
    )
    .opacity
    .value;

/// The opacity the scrim's fade reaches this frame.
double _scrimOpacity(WidgetTester tester) => tester
    .widget<FadeTransition>(
      find.descendant(
        of: find.byType(Scrim),
        matching: find.byType(FadeTransition),
      ),
    )
    .opacity
    .value;

/// Moves focus to `Menu` by Tab and presses Enter on it, as a keyboard
/// user opens the drawer, and returns `Menu`'s focus node.
Future<FocusNode> _openByKeyboard(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.pump();
  final menu = Focus.of(tester.element(find.text('Menu')));
  expect(FocusManager.instance.primaryFocus, menu);
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.pumpAndSettle();
  return menu;
}

void main() {
  group('PageDrawer helpers', () {
    test('us19/fr02/e01: e02: the default type is slide on iOS and front '
        'elsewhere', () {
      expect(defaultDrawerType(TargetPlatform.iOS), PageDrawerType.slide);
      for (final platform in [
        TargetPlatform.android,
        TargetPlatform.fuchsia,
        TargetPlatform.linux,
        TargetPlatform.macOS,
        TargetPlatform.windows,
      ]) {
        expect(defaultDrawerType(platform), PageDrawerType.front);
      }
    });

    test('us19/fr04/e01: e02: e03: 80% of the screen within min and max', () {
      expect(drawerWidth(360), 288);
      expect(drawerWidth(500), 360);
      expect(drawerWidth(320, min: 300), 300);
      expect(drawerWidth(500, max: 320), 320);
    });
  });

  group('PageDrawer open and close', () {
    testWidgets('us19/s1: us19/fr03/e01: the menu button opens the start '
        'drawer at 80% width, focus moves in, and the change reports', (
      tester,
    ) async {
      final reports = <PageDrawerSide?>[];
      await _pump(tester, _page(changed: reports.add));
      final menu = Focus.of(tester.element(find.text('Menu')));
      await _openMenu(tester);
      expect(tester.getRect(_panel), const Rect.fromLTWH(0, 0, 288, 780));
      expect(reports, [PageDrawerSide.left]);
      final focused = FocusManager.instance.primaryFocus!;
      expect(focused, isNot(menu));
      expect(focused.rect, tester.getRect(_panel));
    });

    testWidgets('us19/fr03/e02: close with no drawer open reports nothing', (
      tester,
    ) async {
      var reports = 0;
      await _pump(tester, _page(changed: (_) => reports++));
      PageLayout.of(tester.element(find.text('Menu'))).close();
      await tester.pumpAndSettle();
      expect(reports, 0);
      expect(_drawer, findsNothing);
    });

    testWidgets("us19/fr03/e08: PageLayout.of returns the app's own "
        'controller, which opens the drawer', (tester) async {
      final controller = PageLayoutController();
      addTearDown(controller.dispose);
      await _pump(tester, _page(controller: controller));
      expect(
        PageLayout.of(tester.element(find.text('Menu'))),
        same(controller),
      );
      controller.openLeft();
      await tester.pumpAndSettle();
      expect(_drawer, findsOneWidget);
      controller.close();
      await tester.pumpAndSettle();
      expect(_drawer, findsNothing);
    });

    testWidgets('R21: openLeft on a side shown inline does nothing and '
        'reports nothing', (tester) async {
      var reports = 0;
      await _pump(tester, _page(changed: (_) => reports++), size: _tablet);
      expect(tester.getRect(find.text('drawer item')).left, 0);
      await _openMenu(tester);
      expect(reports, 0);
      expect(_drawer, findsNothing);
      expect(find.text('drawer item'), findsOneWidget);
    });

    testWidgets('us19: an empty side opens no drawer', (tester) async {
      var reports = 0;
      await _pump(tester, _page(changed: (_) => reports++));
      PageLayout.of(tester.element(find.text('Menu'))).openRight();
      await tester.pumpAndSettle();
      expect(reports, 0);
      expect(_drawer, findsNothing);
    });

    testWidgets('us19/fr03: openRight opens the end drawer from the end '
        'edge', (tester) async {
      await _pump(tester, _page(right: const Text('end item')));
      PageLayout.of(tester.element(find.text('Menu'))).openRight();
      await tester.pumpAndSettle();
      expect(
        tester.getRect(
          find
              .ancestor(
                of: find.text('end item'),
                matching: find.byType(ContainerLayout),
              )
              .first,
        ),
        const Rect.fromLTRB(72, 0, 360, 780),
      );
    });

    testWidgets('us19/s2: an edge swipe opens the start drawer on Android', (
      tester,
    ) async {
      final reports = <PageDrawerSide?>[];
      await _pump(tester, _page(changed: reports.add));
      await tester.dragFrom(const Offset(2, 400), const Offset(250, 0));
      await tester.pumpAndSettle();
      expect(_drawer, findsOneWidget);
      expect(reports, [PageDrawerSide.left]);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('us19/fr03: an edge swipe from the end edge opens the end '
        'drawer', (tester) async {
      await _pump(tester, _page(right: const Text('end item')));
      await tester.dragFrom(const Offset(358, 400), const Offset(-250, 0));
      await tester.pumpAndSettle();
      expect(find.text('end item'), findsOneWidget);
      expect(_drawer, findsOneWidget);
    });

    testWidgets('us19/fr03/e05: edge swipe off opens nothing, and the menu '
        'button still opens the drawer', (tester) async {
      await _pump(tester, _page(edgeSwipe: false));
      await tester.dragFrom(const Offset(2, 400), const Offset(250, 0));
      await tester.pumpAndSettle();
      expect(_drawer, findsNothing);
      await _openMenu(tester);
      expect(_drawer, findsOneWidget);
    });

    testWidgets(
      'us19/s3: us19/fr03/e03: on iOS a page that can go back keeps the '
      'back swipe',
      (tester) async {
        _view(tester, const Size(390, 844));
        await tester.pumpWidget(
          _app(
            Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PageLayout(
                      left: Text('drawer item'),
                      body: Text('second'),
                    ),
                  ),
                ),
                child: const Text('go'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('go'));
        await tester.pumpAndSettle();
        await tester.dragFrom(const Offset(2, 400), const Offset(300, 0));
        await tester.pumpAndSettle();
        expect(find.text('second'), findsNothing);
        expect(find.text('go'), findsOneWidget);
        expect(_drawer, findsNothing);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets(
      'us19/fr03/e03: on iOS the start edge of a page that can go back opens '
      'no drawer, even in a route with no back swipe',
      (tester) async {
        _view(tester, const Size(390, 844));
        await tester.pumpWidget(
          _app(
            Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  PageRouteBuilder<void>(pageBuilder: (_, _, _) => _page()),
                ),
                child: const Text('go'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('go'));
        await tester.pumpAndSettle();
        await tester.dragFrom(const Offset(2, 400), const Offset(250, 0));
        await tester.pumpAndSettle();
        expect(find.text('Menu'), findsOneWidget);
        expect(_drawer, findsNothing);
        await _openMenu(tester);
        expect(_drawer, findsOneWidget);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets(
      'us19/fr03/e04: on the first page of an iPhone app a swipe from the '
      'left edge opens the start drawer',
      (tester) async {
        _view(tester, const Size(390, 844));
        await tester.pumpWidget(
          _app(const PageLayout(left: Text('drawer item'), body: _Menu())),
        );
        await tester.dragFrom(const Offset(2, 400), const Offset(250, 0));
        await tester.pumpAndSettle();
        expect(_drawer, findsOneWidget);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets('us19/s9: us19/fr03/e06: back with a drawer open closes it '
        'and the page stays; a second back leaves the page', (tester) async {
      _view(tester, const Size(390, 844));
      final reports = <PageDrawerSide?>[];
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _page(changed: reports.add),
                ),
              ),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await _openMenu(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Menu'), findsOneWidget);
      expect(_drawer, findsNothing);
      expect(reports, [PageDrawerSide.left, null]);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Menu'), findsNothing);
      expect(find.text('go'), findsOneWidget);
    });

    testWidgets('R19: us19/fr05: a drawer opened while loading takes focus '
        'once loading ends, and Esc returns focus to the opener', (
      tester,
    ) async {
      await _pump(tester, _page());
      final menu = Focus.of(tester.element(find.text('Menu')))..requestFocus();
      await tester.pump();
      await _pump(tester, _page(loading: true));
      await tester.pump(const Duration(milliseconds: 200));
      PageLayout.of(tester.element(find.text('Menu'))).openLeft();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(menu.hasFocus, isFalse);

      await _pump(tester, _page());
      await tester.pumpAndSettle();
      final focused = FocusManager.instance.primaryFocus!;
      expect(focused, isNot(menu));
      expect(focused.rect, tester.getRect(_panel));

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(_drawer, findsNothing);
      expect(FocusManager.instance.primaryFocus, menu);
    });

    testWidgets('us19/fr05: a drawer a keyboard opened hands focus back to '
        'its opener on Esc', (tester) async {
      await _pump(tester, _page());
      final menu = await _openByKeyboard(tester);
      expect(_drawer, findsOneWidget);
      expect(FocusManager.instance.primaryFocus, isNot(menu));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(_drawer, findsNothing);
      expect(FocusManager.instance.primaryFocus, menu);
    });

    testWidgets('us19/fr05: focus stays in the page when the opener is gone '
        'by the time the drawer closes', (tester) async {
      final show = ValueNotifier(true);
      addTearDown(show.dispose);
      await _pump(
        tester,
        PageLayout(
          left: const Text('drawer item'),
          body: ValueListenableBuilder<bool>(
            valueListenable: show,
            builder: (_, on, _) => on ? const _Menu() : const Text('gone'),
          ),
        ),
      );
      final menu = await _openByKeyboard(tester);
      show.value = false;
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(_drawer, findsNothing);
      final focused = FocusManager.instance.primaryFocus;
      expect(focused, isNot(menu));
      expect(focused?.context?.mounted, isTrue);
    });

    testWidgets('us19/fr05: a drawer opened from code behind a covering route '
        'leaves focus on that route', (tester) async {
      _view(tester, const Size(390, 844));
      final controller = PageLayoutController();
      addTearDown(controller.dispose);
      final cover = FocusNode(debugLabel: 'cover');
      addTearDown(cover.dispose);
      await tester.pumpWidget(_app(_page(controller: controller)));
      Navigator.of(tester.element(find.text('Menu'))).push(
        PageRouteBuilder<void>(
          opaque: false,
          pageBuilder: (_, _, _) => Focus(
            focusNode: cover,
            autofocus: true,
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus, cover);
      controller.openLeft();
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus, cover);
    });

    testWidgets('us19/fr03/e07: Esc closes the open drawer', (tester) async {
      final reports = <PageDrawerSide?>[];
      await _pump(tester, _page(changed: reports.add));
      await _openMenu(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(_drawer, findsNothing);
      expect(reports, [PageDrawerSide.left, null]);
    });

    testWidgets('us19/fr03: a drag toward the closed side closes the open '
        'drawer', (tester) async {
      await _pump(tester, _page());
      await _openMenu(tester);
      await tester.dragFrom(const Offset(200, 400), const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(_drawer, findsNothing);
    });

    testWidgets('us19/s7: us19/fr02: under right-to-left text the start '
        'drawer opens from the right edge', (tester) async {
      await _pump(tester, _page(), direction: TextDirection.rtl);
      await _openMenu(tester);
      expect(tester.getRect(_panel), const Rect.fromLTRB(72, 0, 360, 780));
    });
  });

  group('PageDrawer types and motion', () {
    testWidgets(
      'us19/fr02/e02: with no type on Android the drawer moves in over the '
      'still page',
      (tester) async {
        await _pump(tester, _page());
        await tester.tap(find.text('Menu'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.getRect(_panel).left, inExclusiveRange(-288, 0));
        expect(tester.getRect(_body), Offset.zero & _phone);
        await tester.pumpAndSettle();
        expect(tester.getRect(_panel).left, 0);
        expect(tester.getRect(_body), Offset.zero & _phone);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets(
      'us19/fr02/e01: with no type on iOS the drawer and the page slide '
      'together',
      (tester) async {
        await _pump(tester, _page());
        await tester.tap(find.text('Menu'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final panel = tester.getRect(_panel);
        final body = tester.getRect(_body);
        expect(body.left, inExclusiveRange(0, 288));
        expect(panel.right, moreOrLessEquals(body.left));
        await tester.pumpAndSettle();
        expect(tester.getRect(_body).left, 288);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets('us19/fr02/e04: back with a page scale moves the page aside '
        'over the still drawer, scales it, and rounds it with the screen '
        'radius', (tester) async {
      await _pump(
        tester,
        _page(
          leftSide: const PageSide(type: PageDrawerType.back, pageScale: 0.9),
        ),
        media: (data) =>
            data.applyDisplayCornerRadii(BorderRadius.circular(40)),
      );
      await tester.tap(find.text('Menu'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.getRect(_panel), const Rect.fromLTWH(0, 0, 288, 780));
      await tester.pumpAndSettle();
      expect(tester.getRect(_panel), const Rect.fromLTWH(0, 0, 288, 780));
      // Scaled by 0.9 about its center, then moved aside by the drawer width.
      expect(tester.getRect(_body), const Rect.fromLTRB(306, 39, 630, 741));
      final clip = tester.widget<ClipRRect>(
        find
            .ancestor(of: find.text('Menu'), matching: find.byType(ClipRRect))
            .first,
      );
      expect(clip.borderRadius, BorderRadius.circular(40));
    });

    testWidgets('us19/fr02/e04: back with no page scale keeps the page '
        'unscaled', (tester) async {
      await _pump(
        tester,
        _page(leftSide: const PageSide(type: PageDrawerType.back)),
      );
      await _openMenu(tester);
      expect(tester.getRect(_body), const Rect.fromLTWH(288, 0, 360, 780));
    });

    testWidgets('us19/fr02/e06: a drag on a half-open slide drawer moves the '
        'drawer and the page in step', (tester) async {
      await _pump(
        tester,
        _page(leftSide: const PageSide(type: PageDrawerType.slide)),
      );
      await _openMenu(tester);
      final gesture = await tester.startGesture(const Offset(250, 400));
      await gesture.moveBy(const Offset(-40, 0));
      await gesture.moveBy(const Offset(-60, 0));
      await tester.pump();
      final panel = tester.getRect(_panel);
      final body = tester.getRect(_body);
      expect(body.left, inExclusiveRange(0, 288));
      expect(panel.right, moreOrLessEquals(body.left));
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('us19/fr02: permanent shows the drawer with no motion', (
      tester,
    ) async {
      await _pump(
        tester,
        _page(leftSide: const PageSide(type: PageDrawerType.permanent)),
      );
      await tester.tap(find.text('Menu'));
      await tester.pump();
      expect(tester.getRect(_panel), const Rect.fromLTWH(0, 0, 288, 780));
      expect(tester.getRect(_body), Offset.zero & _phone);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(_drawer, findsNothing);
    });

    testWidgets('us19/fr02/e03: page opens the drawer content as a new page, '
        'and back returns to the page it opened from', (tester) async {
      _view(tester, const Size(390, 844));
      final reports = <PageDrawerSide?>[];
      await tester.pumpWidget(
        _app(
          _page(
            changed: reports.add,
            leftSide: const PageSide(type: PageDrawerType.page),
          ),
        ),
      );
      await _openMenu(tester);
      expect(find.text('drawer item'), findsOneWidget);
      expect(find.text('Menu'), findsNothing);
      expect(find.byType(Scrim), findsNothing);
      expect(reports, [PageDrawerSide.left]);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Menu'), findsOneWidget);
      expect(find.text('drawer item'), findsNothing);
      expect(reports, [PageDrawerSide.left, null]);
    });

    testWidgets(
      'us19/fr03/e07: NFR-U09: Esc closes a page drawer on a desktop, and '
      'focus returns to the opener',
      (tester) async {
        // Under 600 on its shortest side, a desktop window is mobile, so its
        // sides are drawers.
        _view(tester, const Size(1000, 550));
        final reports = <PageDrawerSide?>[];
        await tester.pumpWidget(
          _app(
            _page(
              changed: reports.add,
              leftSide: const PageSide(type: PageDrawerType.page),
            ),
          ),
        );
        final menu = await _openByKeyboard(tester);
        expect(find.text('drawer item'), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text('drawer item'), findsNothing);
        expect(find.text('Menu'), findsOneWidget);
        expect(reports, [PageDrawerSide.left, null]);
        expect(FocusManager.instance.primaryFocus, menu);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

    testWidgets('NFR-U06: us19/fr05: a page drawer reads as a named screen, '
        'and the page it opened from stays silent', (tester) async {
      _view(tester, const Size(390, 844));
      await tester.pumpWidget(
        _app(_page(leftSide: const PageSide(type: PageDrawerType.page))),
      );
      await _openMenu(tester);
      expect(
        tester.getSemantics(_drawer),
        isSemantics(
          label: 'Navigation menu',
          scopesRoute: true,
          namesRoute: true,
        ),
      );
      expect(find.semantics.byLabel('drawer item'), findsOne);
      expect(find.semantics.byLabel('Menu'), findsNothing);
    });

    for (final (source, app, platform) in [
      ('app', true, false),
      ('platform', false, true),
    ]) {
      testWidgets('NFR-U03: us19/s6: us19/fr02/e05: with $source reduced '
          'motion a slide drawer fades with no movement', (tester) async {
        if (platform) {
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              const FakeAccessibilityFeatures(reduceMotion: true);
          addTearDown(
            tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
          );
        }
        await _pump(
          tester,
          _page(leftSide: const PageSide(type: PageDrawerType.slide)),
          media: (data) => data.copyWith(disableAnimations: app),
        );
        await tester.tap(find.text('Menu'));
        await tester.pump();
        expect(tester.getRect(_panel), const Rect.fromLTWH(0, 0, 288, 780));
        expect(tester.getRect(_body), Offset.zero & _phone);
        await tester.pump(const Duration(milliseconds: 100));
        expect(_panelOpacity(tester), inExclusiveRange(0, 1));
        expect(tester.getRect(_panel), const Rect.fromLTWH(0, 0, 288, 780));
        expect(tester.getRect(_body), Offset.zero & _phone);
      });
    }
  });

  group('PageDrawer width and scrim', () {
    testWidgets('us19/fr04/e04: e05: the corners on the screen corners take '
        'the screen radius, else 0', (tester) async {
      for (final (radius, expected) in [
        (BorderRadius.circular(40), const Radius.circular(40)),
        (null, Radius.zero),
      ]) {
        await _pump(
          tester,
          _page(key: ValueKey(radius)),
          media: (data) => data.applyDisplayCornerRadii(radius),
        );
        await _openMenu(tester);
        final corners = _panelStyle(tester).borderRadius! as BorderRadius;
        expect(corners.topLeft, expected);
        expect(corners.bottomLeft, expected);
        expect(corners.topRight, Radius.zero);
        expect(corners.bottomRight, Radius.zero);
      }
    });

    testWidgets("R18: us19/fr04/e07: the panel fills its side's slot fill "
        'under shadow/4', (tester) async {
      await _pump(tester, _page());
      await _openMenu(tester);
      final style = _panelStyle(tester);
      expect(
        style.backgroundColor,
        fakeTheme.color.background.defaults.surface,
      );
      expect(style.dropShadow, fakeTheme.shadow.level4);
    });

    testWidgets('us19/s1: us19/fr04: the scrim dims and blurs the page with '
        'the modal scrim tokens', (tester) async {
      await _pump(tester, _page());
      await _openMenu(tester);
      final style = tester.widget<ContainerLayout>(_scrim).style!;
      final color = fakeTheme.color.background.defaults.normalInverse;
      expect(
        style.backgroundColor,
        color.withValues(alpha: color.a * fakeTheme.opacity.scrim),
      );
      expect(style.backgroundBlur, fakeTheme.blur.level1);
    });

    testWidgets('us19/fr04: the scrim fades once on the standard curve, as '
        'the modal scrim does', (tester) async {
      await _pump(tester, _page());
      await tester.tap(find.text('Menu'));
      await tester.pump();
      final normal = fakeTheme.animation.normal.duration!;
      await tester.pump(normal ~/ 4);
      expect(
        _scrimOpacity(tester),
        closeTo(Curves.easeInOutSine.transform(0.25), 0.01),
      );
    });

    testWidgets('NFR-E01: us19/fr04/e06: the scrim follows the theme', (
      tester,
    ) async {
      Future<Color?> scrimOf(StratumThemeData theme) async {
        await _pump(tester, _page(key: ObjectKey(theme)), theme: theme);
        await _openMenu(tester);
        return tester.widget<ContainerLayout>(_scrim).style!.backgroundColor;
      }

      final light = await scrimOf(defaultThemeSet.light);
      final dark = await scrimOf(defaultThemeSet.dark!);
      expect(light, isNot(dark));
    });

    testWidgets('NFR-E02: a customStyle left fill restyles the panel, and '
        'its shadow keeps the theme default', (tester) async {
      const fill = Color(0xFF123456);
      await _pump(
        tester,
        _page(
          style: const PageLayoutStyle(
            left: WidgetStyle(backgroundColor: fill),
          ),
        ),
      );
      await _openMenu(tester);
      expect(_panelStyle(tester).backgroundColor, fill);
      expect(_panelStyle(tester).dropShadow, fakeTheme.shadow.level4);
    });

    testWidgets('NFR-U09: us19/fr03: a scrim tap closes the drawer', (
      tester,
    ) async {
      final reports = <PageDrawerSide?>[];
      await _pump(tester, _page(changed: reports.add));
      await _openMenu(tester);
      await tester.tapAt(const Offset(350, 400));
      await tester.pumpAndSettle();
      expect(_drawer, findsNothing);
      expect(reports, [PageDrawerSide.left, null]);
    });
  });

  group('PageDrawer accessibility gate', () {
    testWidgets('NFR-U01: drawer text passes contrast and the scrim target is '
        'labeled', (tester) async {
      await _pump(tester, _page(left: _glyphs), theme: defaultThemeSet.light);
      await _openMenu(tester);
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    });

    testWidgets('NFR-U02: us19/fr05/e01: Tab and Shift+Tab stay inside the '
        'open drawer', (tester) async {
      await _pump(
        tester,
        _page(
          left: ColumnLayout(
            children: [
              TextButton(onPressed: () {}, child: const Text('one')),
              TextButton(onPressed: () {}, child: const Text('two')),
            ],
          ),
        ),
      );
      await _openMenu(tester);
      final one = Focus.of(tester.element(find.text('one')));
      final two = Focus.of(tester.element(find.text('two')));
      final seen = <FocusNode?>[];
      for (var i = 0; i < 4; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        seen.add(FocusManager.instance.primaryFocus);
      }
      expect(seen, [one, two, one, two]);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, one);
    });

    testWidgets('NFR-U04: at twice the text size the drawer keeps its width '
        'and its content wraps with no overflow', (tester) async {
      await _pump(
        tester,
        _page(left: const Text('drawer item with a long label that wraps')),
        media: (data) => data.copyWith(textScaler: const TextScaler.linear(2)),
      );
      await tester.tap(find.text('Menu'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester
            .getRect(
              find
                  .ancestor(
                    of: find.textContaining('long label'),
                    matching: find.byType(ContainerLayout),
                  )
                  .first,
            )
            .width,
        288,
      );
    });

    testWidgets('NFR-U05: the scrim target covers the whole page', (
      tester,
    ) async {
      await _pump(tester, _page());
      await _openMenu(tester);
      expect(
        tester.getRect(find.bySemanticsLabel('Dismiss')),
        Offset.zero & _phone,
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    });

    testWidgets('NFR-U06: us19/s8: us19/fr05: the drawer reads as a named '
        'screen, the page behind is hidden, and the scrim reads Dismiss', (
      tester,
    ) async {
      await _pump(tester, _page());
      await _openMenu(tester);
      expect(
        tester.getSemantics(_drawer),
        isSemantics(
          label: 'Navigation menu',
          scopesRoute: true,
          namesRoute: true,
        ),
      );
      expect(find.semantics.byLabel('Menu'), findsNothing);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Dismiss')),
        isSemantics(label: 'Dismiss', hasTapAction: true),
      );
    });

    testWidgets('NFR-U06: us19/fr05: a back drawer painted under the page '
        'still reads, and the page behind is hidden', (tester) async {
      await _pump(
        tester,
        _page(leftSide: const PageSide(type: PageDrawerType.back)),
      );
      await _openMenu(tester);
      expect(find.semantics.byLabel('Navigation menu'), findsOne);
      expect(find.semantics.byLabel('drawer item'), findsOne);
      expect(find.semantics.byLabel('Menu'), findsNothing);
    });

    testWidgets('NFR-U06: us19/fr05/e02: in Thai the drawer and the scrim '
        'read the Thai built-in labels', (tester) async {
      tester.platformDispatcher.localeTestValue = const Locale('th');
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);
      await _pump(tester, _page());
      await _openMenu(tester);
      expect(find.bySemanticsLabel('เมนูการนำทาง'), findsOneWidget);
      expect(find.bySemanticsLabel('ปิด'), findsOneWidget);
    });

    testWidgets("NFR-U06: us19/fr05/e03: the app's drawer label replaces "
        'the built-in one', (tester) async {
      await _pump(
        tester,
        _page(leftSide: const PageSide(semanticsLabel: 'Main menu')),
      );
      await _openMenu(tester);
      expect(find.bySemanticsLabel('Main menu'), findsOneWidget);
      expect(_drawer, findsNothing);
    });

    testWidgets('NFR-U06: us19/fr05/e04: a screen reader activating the '
        'scrim closes the drawer', (tester) async {
      await _pump(tester, _page());
      await _openMenu(tester);
      tester.semantics.tap(find.semantics.byLabel('Dismiss'));
      await tester.pumpAndSettle();
      expect(_drawer, findsNothing);
    });

    testWidgets('NFR-U07: drawer text passes contrast in every bundled '
        'theme', (tester) async {
      final themes = [
        defaultThemeSet.light,
        defaultThemeSet.dark,
        defaultThemeSet.highContrastLight,
        defaultThemeSet.highContrastDark,
      ].nonNulls;
      for (final theme in themes) {
        await _pump(
          tester,
          _page(key: ObjectKey(theme), left: _glyphs),
          theme: theme,
        );
        await _openMenu(tester);
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      }
    });

    testWidgets('NFR-U08: under high contrast the open drawer also shows its '
        'panel shape over the scrim', (tester) async {
      await _pump(tester, _page(), highContrast: true);
      await _openMenu(tester);
      expect(tester.getRect(_panel), const Rect.fromLTWH(0, 0, 288, 780));
      expect(_panelStyle(tester).dropShadow, isNotEmpty);
      expect(_scrim, findsOneWidget);
    });

    testWidgets('NFR-U09: Esc alone closes the drawer an edge swipe '
        'opened', (tester) async {
      await _pump(tester, _page());
      await tester.dragFrom(const Offset(2, 400), const Offset(250, 0));
      await tester.pumpAndSettle();
      expect(_drawer, findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(_drawer, findsNothing);
    });
  });

  group('PageDrawer rebuilds', () {
    testWidgets('NFR-P01: opening and closing the drawer builds no slot and '
        'no PageLayout.of reader again', (tester) async {
      var builds = 0;
      late PageLayoutController controller;
      await _pump(
        tester,
        PageLayout(
          left: const Text('drawer item'),
          body: Builder(
            builder: (context) {
              builds++;
              controller = PageLayout.of(context);
              return const Text('body');
            },
          ),
        ),
      );
      expect(builds, 1);
      controller.openLeft();
      await tester.pumpAndSettle();
      expect(_drawer, findsOneWidget);
      controller.close();
      await tester.pumpAndSettle();
      expect(_drawer, findsNothing);
      expect(builds, 1);
    });
  });
}
