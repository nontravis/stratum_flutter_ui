import 'dart:ui' as ui;

import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/layout/page_drawer.dart'
    show
        PageDrawerStage,
        defaultDrawerType,
        drawerWidth,
        inlinePaneWidth,
        overlayDrawerWidth;
import 'package:stratum_ui/src/components/common/layout/scrim.dart' show Scrim;
import 'package:stratum_ui/src/src.dart';

import '../fakes/fake_stratum_theme.dart';

// NFR-U05: the drawer's own target is its scrim, which covers the whole
// page; the right overlay drawer adds a close button, and each inline pane
// a divider hit area (both tested in the side pane gate group below).

const _phone = Size(360, 780);
const _tablet = Size(1000, 800);
const _desktop = Size(1300, 900);
const _bigDesktop = Size(1700, 900);

/// The iPhone Duo width, whose 84 px inset leaves a 382 px box (FR-04 E09).
const _duo = Size(466, 1000);

/// What sits behind the PageLayout, in the strip beside its box.
const _behind = Color(0xFF00FF00);

final GlobalKey _shot = GlobalKey();

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
  Widget body = const _Menu(),
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
  body: body,
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

/// Pumps [page] in a [_duo] view whose OS reports [inset], under a host
/// SafeArea over a [_behind] fill, inside the boundary [_pixels] reads.
Future<void> _pumpInBox(
  WidgetTester tester,
  Widget page, {
  required EdgeInsets inset,
  TextDirection direction = TextDirection.ltr,
}) async {
  _view(tester, _duo);
  tester.view.padding = FakeViewPadding(left: inset.left, right: inset.right);
  await tester.pumpWidget(
    _host(
      RepaintBoundary(
        key: _shot,
        child: ColoredBox(
          color: _behind,
          child: SafeArea(child: page),
        ),
      ),
      direction: direction,
    ),
  );
}

/// The colors of [_shot]'s rendered pixels at each logical [points], at a
/// device pixel ratio of 1.
Future<List<Color>> _pixels(WidgetTester tester, List<Offset> points) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_shot),
  );
  final colors = await tester.runAsync(() async {
    final image = await boundary.toImage();
    final width = image.width;
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    if (bytes == null) return null;
    Color colorAt(Offset point) {
      final index = (point.dy.toInt() * width + point.dx.toInt()) * 4;
      return Color.fromARGB(
        255,
        bytes.getUint8(index),
        bytes.getUint8(index + 1),
        bytes.getUint8(index + 2),
      );
    }

    return [for (final point in points) colorAt(point)];
  });
  return colors ?? fail('the boundary rendered no pixels');
}

/// The clip of the first `ClipRect` in the stage, which bounds the drawers.
Clip _stageClip(WidgetTester tester) => tester
    .widget<ClipRect>(
      find
          .descendant(
            of: find.byType(PageDrawerStage),
            matching: find.byType(ClipRect),
          )
          .first,
    )
    .clipBehavior;

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

/// A body button `Open right` that opens the end side, as an app's button
/// does.
class _OpenRight extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => PageLayout.of(context).openRight(),
    child: const Text('Open right'),
  );
}

/// A page with a start side `left pane` kept within 200 and 400 px and an
/// end side `right pane`, each left out when [left] or [right] is false,
/// an optional [top], and [body], else an [_OpenRight] button.
Widget _sides({
  WindowSize cut = WindowSize.tablet,
  bool overlay = false,
  bool left = true,
  bool right = true,
  Widget? top,
  Widget? rightPane,
  Widget body = const _OpenRight(),
  PageLayoutController? controller,
  ValueChanged<PageDrawerSide?>? changed,
  SplitDividerBuilder? leftDivider,
  SplitDividerBuilder? rightDivider,
  PageLayoutStyle? style,
}) => PageLayout(
  drawerCut: cut,
  rightAsOverlay: overlay,
  controller: controller,
  onDrawerChanged: changed,
  leftDividerBuilder: leftDivider,
  rightDividerBuilder: rightDivider,
  customStyle: style,
  leftSide: const PageSide(minWidth: 200, maxWidth: 400),
  left: left ? const Text('left pane') : null,
  top: top,
  right: right ? rightPane ?? const Text('right pane') : null,
  body: body,
);

/// The slot box that shows [text]: its nearest `ContainerLayout`.
Finder _box(String text) => find
    .ancestor(of: find.text(text), matching: find.byType(ContainerLayout))
    .first;

/// Every inline pane's divider: its slider node.
Finder get _dividers => find.bySemanticsLabel('Resize panes');

/// A controller holding [left] and [right] as the chosen pane widths that
/// counts its notifications in [notes], disposed after the test.
PageLayoutController _widths({double? left, double? right, List<int>? notes}) {
  final controller = PageLayoutController(leftWidth: left, rightWidth: right);
  if (notes != null) controller.addListener(() => notes[0]++);
  addTearDown(controller.dispose);
  return controller;
}

/// Kept widths that are no finite number of at least 0, as storage can hand
/// back: NaN, both infinities, a negative, and a JSON number past the
/// double range.
final _unusable = <double>[
  double.nan,
  double.infinity,
  double.negativeInfinity,
  -50,
  (jsonDecode('1e309') as num).toDouble(),
];

/// A controller whose getters hand the page [raw] unchecked, as a subclass
/// may, so a test reaches the page's own read of the widths.
class _Unchecked extends PageLayoutController {
  new(this.raw);

  final double raw;

  @override
  double? get leftWidth => raw;

  @override
  double? get rightWidth => raw;
}

/// Taps `Open right` and lets the end side's drawer settle open.
Future<void> _openRight(WidgetTester tester) async {
  await tester.tap(find.text('Open right'));
  await tester.pumpAndSettle();
}

/// The node that holds focus, a divider's or a slot's.
String? get _focusLabel => FocusManager.instance.primaryFocus?.debugLabel;

/// The color the focus ring of [divider] paints, alpha 0 while hidden.
Color _ring(WidgetTester tester, Finder divider) {
  Color? color;
  expect(
    tester.renderObject(
      find.descendant(of: divider, matching: find.byType(DecoratedBox)).first,
    ),
    paints..everything((method, arguments) {
      color ??= arguments.whereType<Paint>().firstOrNull?.color;
      return true;
    }),
  );
  return color!;
}

/// Counts its own State's creations in [made], so a test sees a remount.
class _Kept extends StatefulWidget {
  const new(this.made);

  final List<int> made;

  @override
  State<_Kept> createState() => _KeptState();
}

class _KeptState extends State<_Kept> {
  @override
  void initState() {
    super.initState();
    widget.made[0]++;
  }

  @override
  Widget build(BuildContext context) => const _OpenRight();
}

void main() {
  group('PageDrawer helpers', () {
    test('fo06/us19/fr02/e01: e02: the default type is slide on iOS and front '
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

    test(
      'fo06/us19/fr04/e01: e02: e03: e09: 80% of the box within min and max',
      () {
        expect(drawerWidth(360), 288);
        expect(drawerWidth(500), 360);
        expect(drawerWidth(320, min: 300), 300);
        expect(drawerWidth(500, max: 320), 320);
        expect(drawerWidth(382), moreOrLessEquals(305.6)); // E09
        // The minimum stays capped at the default maximum (ruling 2026-10-27).
        expect(drawerWidth(466, min: 400), 360);
      },
    );
  });

  group('PageDrawer open and close', () {
    testWidgets(
      'fo06/us19/s1: fo06/us19/fr03/e01: the menu button opens the start '
      'drawer at 80% width, focus moves in, and the change reports',
      (tester) async {
        final reports = <PageDrawerSide?>[];
        await _pump(tester, _page(changed: reports.add));
        final menu = Focus.of(tester.element(find.text('Menu')));
        await _openMenu(tester);
        expect(tester.getRect(_panel), const Rect.fromLTWH(0, 0, 288, 780));
        expect(reports, [PageDrawerSide.left]);
        final focused = FocusManager.instance.primaryFocus!;
        expect(focused, isNot(menu));
        expect(focused.rect, tester.getRect(_panel));
      },
    );

    testWidgets(
      'fo06/us19/fr03/e02: close with no drawer open reports nothing',
      (tester) async {
        var reports = 0;
        await _pump(tester, _page(changed: (_) => reports++));
        PageLayout.of(tester.element(find.text('Menu'))).close();
        await tester.pumpAndSettle();
        expect(reports, 0);
        expect(_drawer, findsNothing);
      },
    );

    testWidgets("fo06/us19/fr03/e08: PageLayout.of returns the app's own "
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

    testWidgets('fo06/us19/fr03: openRight opens the end drawer from the end '
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

    testWidgets(
      'fo06/us19/s2: an edge swipe opens the start drawer on Android',
      (tester) async {
        final reports = <PageDrawerSide?>[];
        await _pump(tester, _page(changed: reports.add));
        await tester.dragFrom(const Offset(2, 400), const Offset(250, 0));
        await tester.pumpAndSettle();
        expect(_drawer, findsOneWidget);
        expect(reports, [PageDrawerSide.left]);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets('fo06/us19/fr03: an edge swipe from the end edge opens the end '
        'drawer', (tester) async {
      await _pump(tester, _page(right: const Text('end item')));
      await tester.dragFrom(const Offset(358, 400), const Offset(-250, 0));
      await tester.pumpAndSettle();
      expect(find.text('end item'), findsOneWidget);
      expect(_drawer, findsOneWidget);
    });

    testWidgets(
      'fo06/us19/fr03/e05: edge swipe off opens nothing, and the menu '
      'button still opens the drawer',
      (tester) async {
        await _pump(tester, _page(edgeSwipe: false));
        await tester.dragFrom(const Offset(2, 400), const Offset(250, 0));
        await tester.pumpAndSettle();
        expect(_drawer, findsNothing);
        await _openMenu(tester);
        expect(_drawer, findsOneWidget);
      },
    );

    testWidgets('fo06/us19/s3: fo06/us19/fr03/e03: on iOS a page that can go back keeps the '
        'back swipe', (tester) async {
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
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('fo06/us19/fr03/e03: on iOS the start edge of a page that can go back opens '
        'no drawer, even in a route with no back swipe', (tester) async {
      _view(tester, const Size(390, 844));
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(
                context,
              ).push(PageRouteBuilder<void>(pageBuilder: (_, _, _) => _page())),
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
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets(
      'fo06/us19/fr03/e04: on the first page of an iPhone app a swipe from the '
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

    testWidgets(
      'fo06/us19/s9: fo06/us19/fr03/e06: back with a drawer open closes it '
      'and the page stays; a second back leaves the page',
      (tester) async {
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
      },
    );

    testWidgets(
      'R19: fo06/us19/fr05: a drawer opened while loading takes focus '
      'once loading ends, and Esc returns focus to the opener',
      (tester) async {
        await _pump(tester, _page());
        final menu = Focus.of(tester.element(find.text('Menu')))
          ..requestFocus();
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
      },
    );

    testWidgets(
      'fo06/us19/fr05: a drawer a keyboard opened hands focus back to '
      'its opener on Esc',
      (tester) async {
        await _pump(tester, _page());
        final menu = await _openByKeyboard(tester);
        expect(_drawer, findsOneWidget);
        expect(FocusManager.instance.primaryFocus, isNot(menu));
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(_drawer, findsNothing);
        expect(FocusManager.instance.primaryFocus, menu);
      },
    );

    testWidgets(
      'fo06/us19/fr05: focus stays in the page when the opener is gone '
      'by the time the drawer closes',
      (tester) async {
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
      },
    );

    testWidgets(
      'fo06/us19/fr05: a drawer opened from code behind a covering route '
      'leaves focus on that route',
      (tester) async {
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
      },
    );

    testWidgets('fo06/us19/fr03/e07: Esc closes the open drawer', (
      tester,
    ) async {
      final reports = <PageDrawerSide?>[];
      await _pump(tester, _page(changed: reports.add));
      await _openMenu(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(_drawer, findsNothing);
      expect(reports, [PageDrawerSide.left, null]);
    });

    testWidgets('fo06/us19/fr03: a drag toward the closed side closes the open '
        'drawer', (tester) async {
      await _pump(tester, _page());
      await _openMenu(tester);
      await tester.dragFrom(const Offset(200, 400), const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(_drawer, findsNothing);
    });

    testWidgets(
      'fo06/us19/s7: fo06/us19/fr02: under right-to-left text the start '
      'drawer opens from the right edge',
      (tester) async {
        await _pump(tester, _page(), direction: TextDirection.rtl);
        await _openMenu(tester);
        expect(tester.getRect(_panel), const Rect.fromLTRB(72, 0, 360, 780));
      },
    );
  });

  group('PageDrawer types and motion', () {
    testWidgets('fo06/us19/fr02/e02: with no type on Android the drawer moves in over the '
        'still page', (tester) async {
      await _pump(tester, _page());
      await tester.tap(find.text('Menu'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.getRect(_panel).left, inExclusiveRange(-288, 0));
      expect(tester.getRect(_body), Offset.zero & _phone);
      await tester.pumpAndSettle();
      expect(tester.getRect(_panel).left, 0);
      expect(tester.getRect(_body), Offset.zero & _phone);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets(
      'fo06/us19/fr02/e01: with no type on iOS the drawer and the page slide '
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

    testWidgets(
      'fo06/us19/fr02/e04: back with a page scale moves the page aside '
      'over the still drawer, scales it, and rounds it with the screen '
      'radius',
      (tester) async {
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
      },
    );

    testWidgets('fo06/us19/fr02/e04: back with no page scale keeps the page '
        'unscaled', (tester) async {
      await _pump(
        tester,
        _page(leftSide: const PageSide(type: PageDrawerType.back)),
      );
      await _openMenu(tester);
      expect(tester.getRect(_body), const Rect.fromLTWH(288, 0, 360, 780));
    });

    testWidgets(
      'fo06/us19/fr02/e06: a drag on a half-open slide drawer moves the '
      'drawer and the page in step',
      (tester) async {
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
      },
    );

    testWidgets('fo06/us19/fr02: permanent shows the drawer with no motion', (
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

    testWidgets(
      'fo06/us19/fr02/e03: page opens the drawer content as a new page, '
      'and back returns to the page it opened from',
      (tester) async {
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
      },
    );

    testWidgets(
      'fo06/us18/fr02/e05: an open page drawer shows the slot the app '
      'rebuilds the page with',
      (tester) async {
        _view(tester, const Size(390, 844));
        var on = false;
        await tester.pumpWidget(
          _app(
            StatefulBuilder(
              builder: (context, setState) => _page(
                leftSide: const PageSide(type: PageDrawerType.page),
                style: PageLayoutStyle(
                  left: WidgetStyle(
                    backgroundColor: on ? Colors.green : Colors.red,
                  ),
                ),
                left: Switch(
                  value: on,
                  onChanged: (value) => setState(() => on = value),
                ),
              ),
            ),
          ),
        );
        await _openMenu(tester);
        Finder fill() => find
            .ancestor(
              of: find.byType(Switch),
              matching: find.byType(ContainerLayout),
            )
            .first;
        expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();
        expect(on, isTrue);
        expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
        expect(
          tester.widget<ContainerLayout>(fill()).style!.backgroundColor,
          Colors.green,
        );
      },
    );

    testWidgets(
      'fo06/us19/fr03/e07: NFR-U09: Esc closes a page drawer on a desktop, and '
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

    testWidgets(
      'NFR-U06: fo06/us19/fr05: a page drawer reads as a named screen, '
      'and the page it opened from stays silent',
      (tester) async {
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
      },
    );

    for (final (source, app, platform) in [
      ('app', true, false),
      ('platform', false, true),
    ]) {
      testWidgets(
        'NFR-U03: fo06/us19/s6: fo06/us19/fr02/e05: with $source reduced '
        'motion a slide drawer fades with no movement',
        (tester) async {
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
        },
      );
    }
  });

  group('PageDrawer width and scrim', () {
    testWidgets(
      'fo06/us19/fr04/e04: e05: the corners on the screen corners take '
      'the screen radius, else 0',
      (tester) async {
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
      },
    );

    testWidgets("R18: fo06/us19/fr04/e07: the panel fills its side's slot fill "
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

    testWidgets(
      'fo06/us19/s1: fo06/us19/fr04: the scrim dims and blurs the page with '
      'the modal scrim tokens',
      (tester) async {
        await _pump(tester, _page());
        await _openMenu(tester);
        final style = tester.widget<ContainerLayout>(_scrim).style!;
        final color = fakeTheme.color.background.defaults.normalInverse;
        expect(
          style.backgroundColor,
          color.withValues(alpha: color.a * fakeTheme.opacity.scrim),
        );
        expect(style.backgroundBlur, fakeTheme.blur.level1);
      },
    );

    testWidgets(
      'fo06/us19/fr04: the scrim fades once on the standard curve, as '
      'the modal scrim does',
      (tester) async {
        await _pump(tester, _page());
        await tester.tap(find.text('Menu'));
        await tester.pump();
        final normal = fakeTheme.animation.normal.duration!;
        await tester.pump(normal ~/ 4);
        expect(
          _scrimOpacity(tester),
          closeTo(Curves.easeInOutSine.transform(0.25), 0.01),
        );
      },
    );

    testWidgets('NFR-E01: fo06/us19/fr04/e06: the scrim follows the theme', (
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

    testWidgets('NFR-U09: fo06/us19/fr03: a scrim tap closes the drawer', (
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

    testWidgets(
      'NFR-U02: fo06/us19/fr05/e01: Tab and Shift+Tab stay inside the '
      'open drawer',
      (tester) async {
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
      },
    );

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

    testWidgets(
      'NFR-U06: fo06/us19/s8: fo06/us19/fr05: the drawer reads as a named '
      'screen, the page behind is hidden, and the scrim reads Dismiss',
      (tester) async {
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
      },
    );

    testWidgets('NFR-U06: fo06/us19/fr05: a back drawer painted under the page '
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

    testWidgets('NFR-U06: fo06/us19/fr05/e02: in Thai the drawer and the scrim '
        'read the Thai built-in labels', (tester) async {
      tester.platformDispatcher.localeTestValue = const Locale('th');
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);
      await _pump(tester, _page());
      await _openMenu(tester);
      expect(find.bySemanticsLabel('เมนูการนำทาง'), findsOneWidget);
      expect(find.bySemanticsLabel('ปิด'), findsOneWidget);
    });

    testWidgets("NFR-U06: fo06/us19/fr05/e03: the app's drawer label replaces "
        'the built-in one', (tester) async {
      await _pump(
        tester,
        _page(leftSide: const PageSide(semanticsLabel: 'Main menu')),
      );
      await _openMenu(tester);
      expect(find.bySemanticsLabel('Main menu'), findsOneWidget);
      expect(_drawer, findsNothing);
    });

    testWidgets('NFR-U06: fo06/us19/fr05/e04: a screen reader activating the '
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

  group('PageDrawer or inline pane by window size', () {
    testWidgets(
      'fo06/us19/fr01/e01: on a phone both sides are drawers that take '
      'no space',
      (tester) async {
        await _pump(tester, _sides());
        expect(find.text('left pane'), findsNothing);
        expect(find.text('right pane'), findsNothing);
        expect(_dividers, findsNothing);
        expect(tester.getRect(_box('Open right')), Offset.zero & _phone);
      },
    );

    testWidgets(
      'fo06/us19/s4: fo06/us19/fr01/e02: a tablet shows both sides inline '
      'beside the center column, one divider each, with top spanning the '
      'center column and right (Q13)',
      (tester) async {
        await _pump(
          tester,
          _sides(
            controller: _widths(left: 240, right: 300),
            top: const Text('top bar'),
          ),
          size: _tablet,
        );
        expect(
          tester.getRect(_box('left pane')),
          const Rect.fromLTRB(0, 0, 240, 800),
        );
        final top = tester.getRect(_box('top bar'));
        expect(top.left, 240);
        expect(top.right, 1000);
        expect(
          tester.getRect(_box('right pane')),
          Rect.fromLTRB(700, top.bottom, 1000, 800),
        );
        expect(
          tester.getRect(_box('Open right')),
          Rect.fromLTRB(240, top.bottom, 700, 800),
        );
        expect(_dividers, findsNWidgets(2));
      },
    );

    testWidgets(
      'fo06/us19/fr01/e03: with the cut at desktop a tablet keeps both '
      'sides as drawers',
      (tester) async {
        await _pump(tester, _sides(cut: WindowSize.desktop), size: _tablet);
        expect(find.text('left pane'), findsNothing);
        expect(_dividers, findsNothing);
        await _openRight(tester);
        expect(_drawer, findsOneWidget);
      },
    );

    testWidgets('fo06/us19/fr01: a cut at mobile shows the sides inline on a '
        'landscape phone', (tester) async {
      await _pump(
        tester,
        _sides(
          cut: WindowSize.mobile,
          right: false,
          controller: _widths(left: 250),
        ),
        size: const Size(844, 390),
      );
      expect(tester.getRect(_box('left pane')).width, 250);
      expect(_dividers, findsOneWidget);
    });

    testWidgets(
      'review focus 2: fo06/us19/fr01/e05: crossing the cut with a drawer '
      'open closes it once the frame ends, so a parent can set its state, '
      'and shows the pane (Q26)',
      (tester) async {
        final reports = <PageDrawerSide?>[];
        Widget page() => StatefulBuilder(
          builder: (context, setState) => PageLayout(
            onDrawerChanged: (side) => setState(() => reports.add(side)),
            left: const Text('left pane'),
            body: const _Menu(),
          ),
        );
        _view(tester);
        await tester.pumpWidget(_host(page()));
        await _openMenu(tester);
        expect(reports, [PageDrawerSide.left]);
        _view(tester, _tablet);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(reports, [PageDrawerSide.left, null]);
        expect(_drawer, findsNothing);
        expect(find.text('left pane'), findsOneWidget);
        expect(tester.getRect(find.text('left pane')).left, 0);
      },
    );

    testWidgets('fo06/us19/fr01/e05: crossing the cut both ways remounts no '
        'center slot (Q14)', (tester) async {
      final made = [0];
      await _pump(tester, _sides(body: _Kept(made)));
      _view(tester, _tablet);
      await tester.pumpAndSettle();
      expect(find.text('left pane'), findsOneWidget);
      _view(tester);
      await tester.pumpAndSettle();
      expect(find.text('left pane'), findsNothing);
      expect(made.single, 1);
    });
  });

  group('PageDrawer right overlay drawer', () {
    test('fo06/us19/fr01/e04: the overlay drawer is 450 wide at bigDesktop and '
        '400 below it', () {
      expect(overlayDrawerWidth(WindowSize.bigDesktop), 450);
      expect(overlayDrawerWidth(WindowSize.desktop), 400);
      expect(overlayDrawerWidth(WindowSize.tablet), 400);
    });

    testWidgets(
      'fo06/us19/s5: fo06/us19/fr01/e04: at bigDesktop right takes no space '
      'closed and opens 450 wide from the end edge over a scrim, with a '
      'close button',
      (tester) async {
        final reports = <PageDrawerSide?>[];
        await _pump(
          tester,
          _sides(overlay: true, changed: reports.add),
          size: _bigDesktop,
        );
        expect(find.text('right pane'), findsNothing);
        expect(_dividers, findsOneWidget);
        expect(tester.getRect(_box('Open right')).right, 1700);
        await _openRight(tester);
        expect(reports, [PageDrawerSide.right]);
        expect(
          tester.getRect(_box('right pane')),
          const Rect.fromLTRB(1250, 0, 1700, 900),
        );
        expect(_scrim, findsOneWidget);
        expect(find.bySemanticsLabel('Close'), findsOneWidget);
      },
    );

    for (final (name, size) in [('desktop', _desktop), ('tablet', _tablet)]) {
      testWidgets('fo06/us19/fr01/e04: at $name the overlay drawer opens 400 '
          'wide', (tester) async {
        await _pump(tester, _sides(overlay: true), size: size);
        await _openRight(tester);
        expect(
          tester.getRect(_box('right pane')),
          Rect.fromLTRB(size.width - 400, 0, size.width, size.height),
        );
      });
    }

    testWidgets('fo06/us19/fr01/e04: the overlay drawer moves in front of the '
        'still page on iOS too', (tester) async {
      await _pump(tester, _sides(overlay: true), size: _desktop);
      final page = tester.getRect(_box('Open right'));
      await _openRight(tester);
      expect(tester.getRect(_box('Open right')), page);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets(
      'fo06/us19/fr01/e04: the close button closes the overlay drawer '
      'and reports it closed',
      (tester) async {
        final reports = <PageDrawerSide?>[];
        await _pump(
          tester,
          _sides(overlay: true, changed: reports.add),
          size: _desktop,
        );
        await _openRight(tester);
        await tester.tap(find.bySemanticsLabel('Close'));
        await tester.pumpAndSettle();
        expect(find.text('right pane'), findsNothing);
        expect(reports, [PageDrawerSide.right, null]);
      },
    );

    testWidgets(
      'fo06/us19/fr01/e06: under right-to-left text the overlay drawer '
      'opens from the left edge',
      (tester) async {
        await _pump(
          tester,
          _sides(overlay: true),
          size: _desktop,
          direction: TextDirection.rtl,
        );
        await _openRight(tester);
        expect(
          tester.getRect(_box('right pane')),
          const Rect.fromLTRB(0, 0, 400, 900),
        );
      },
    );

    testWidgets(
      'fo06/us19/fr01/e04: on a screen narrower than the overlay drawer '
      'it fits the screen',
      (tester) async {
        await _pump(
          tester,
          _sides(cut: WindowSize.mobile, overlay: true, left: false),
        );
        await _openRight(tester);
        expect(
          tester.getRect(_box('right pane')),
          const Rect.fromLTRB(0, 0, 360, 780),
        );
      },
    );

    testWidgets('fo06/us18/fr02/e03: a resize within one window size reruns no '
        'page build for the overlay drawer', (tester) async {
      await _pump(tester, _sides(overlay: true), size: _desktop);
      final outer = find
          .descendant(
            of: find.byType(PageLayout),
            matching: find.byType(ContainerLayout),
          )
          .first;
      final built = tester.widget(outer);
      _view(tester, const Size(1350, 900));
      await tester.pump();
      expect(tester.widget(outer), same(built));
    });

    testWidgets('fo06/us19/fr01: below the cut an overlay right is a plain '
        'drawer with no close button', (tester) async {
      await _pump(tester, _sides(overlay: true));
      await _openRight(tester);
      expect(tester.getRect(_box('right pane')).width, 288);
      expect(find.bySemanticsLabel('Close'), findsNothing);
    });

    testWidgets('fo06/us19/fr01/e05: turning the overlay off while it is open '
        'closes it and shows right inline', (tester) async {
      final reports = <PageDrawerSide?>[];
      await _pump(
        tester,
        _sides(overlay: true, changed: reports.add),
        size: _desktop,
      );
      await _openRight(tester);
      await tester.pumpWidget(
        _host(_sides(overlay: false, changed: reports.add)),
      );
      await tester.pumpAndSettle();
      expect(reports, [PageDrawerSide.right, null]);
      expect(_scrim, findsNothing);
      expect(tester.getRect(_box('right pane')).right, 1300);
      expect(_dividers, findsNWidgets(2));
    });
  });

  group('PageDrawer resizable inline side panes', () {
    testWidgets(
      'fo06/us19/fr06/e03: a controller built with a kept width opens '
      'the pane at it',
      (tester) async {
        await _pump(
          tester,
          _sides(right: false, controller: _widths(left: 240)),
          size: _desktop,
        );
        expect(tester.getRect(_box('left pane')).width, 240);
        expect(tester.getRect(_box('Open right')).left, 240);
      },
    );

    test('fo06/us19/fr06/e10: the Figma side widths: left 280 and right 380 at '
        'bigDesktop, 260 and 320 below', () {
      for (final window in WindowSize.values) {
        final wide = window == WindowSize.bigDesktop;
        expect(inlinePaneWidth(PageDrawerSide.left, window), wide ? 280 : 260);
        expect(inlinePaneWidth(PageDrawerSide.right, window), wide ? 380 : 320);
      }
    });

    for (final (name, size, left, right) in [
      ('tablet', _tablet, 260.0, 320.0),
      ('desktop', _desktop, 260.0, 320.0),
      ('bigDesktop', _bigDesktop, 280.0, 380.0),
    ]) {
      testWidgets(
        'fo06/us19/fr06/e10: at $name a side with no chosen width opens at '
        'its Figma width',
        (tester) async {
          await _pump(
            tester,
            const PageLayout(
              left: Text('left pane'),
              right: Text('right pane'),
              body: _OpenRight(),
            ),
            size: size,
          );
          expect(tester.getRect(_box('left pane')).width, left);
          expect(tester.getRect(_box('right pane')).width, right);
        },
      );
    }

    test('fo06/us19/fr06/e11: a kept width that is NaN, infinite, or negative '
        'reads as none, from the constructor and from a set', () {
      for (final bad in _unusable) {
        final notes = [0];
        final controller = _widths(left: bad, right: bad, notes: notes);
        expect(controller.leftWidth, isNull, reason: '$bad');
        expect(controller.rightWidth, isNull, reason: '$bad');
        controller
          ..leftWidth = 300
          ..leftWidth = bad;
        expect(controller.leftWidth, isNull, reason: '$bad');
        expect(notes.single, 2, reason: '$bad');
        controller.rightWidth = bad;
        expect(notes.single, 2, reason: '$bad');
      }
    });

    testWidgets(
      'fo06/us19/fr06/e11: a pane whose kept width is not finite opens '
      'at its Figma width',
      (tester) async {
        for (final bad in _unusable) {
          final controller = _widths(left: bad, right: bad);
          await _pump(
            tester,
            KeyedSubtree(
              key: ValueKey(controller),
              child: PageLayout(
                controller: controller,
                left: const Text('left pane'),
                right: const Text('right pane'),
                body: const _OpenRight(),
              ),
            ),
            size: _desktop,
          );
          expect(tester.takeException(), isNull, reason: '$bad');
          expect(tester.getRect(_box('left pane')).width, 260, reason: '$bad');
          expect(tester.getRect(_box('right pane')).width, 320, reason: '$bad');
        }
      },
    );

    testWidgets(
      'fo06/us19/fr06/e11: the page reads an unusable width a controller '
      'hands it as none',
      (tester) async {
        for (final bad in _unusable) {
          final controller = _Unchecked(bad);
          addTearDown(controller.dispose);
          await _pump(
            tester,
            KeyedSubtree(
              key: ValueKey(controller),
              child: PageLayout(
                controller: controller,
                left: const Text('left pane'),
                right: const Text('right pane'),
                body: const _OpenRight(),
              ),
            ),
            size: _desktop,
          );
          expect(tester.takeException(), isNull, reason: '$bad');
          expect(tester.getRect(_box('left pane')).width, 260, reason: '$bad');
          expect(tester.getRect(_box('right pane')).width, 320, reason: '$bad');
        }
      },
    );

    testWidgets(
      'fo06/us19/fr06/e03: a chosen width wins over the Figma width of '
      'its side only',
      (tester) async {
        await _pump(
          tester,
          PageLayout(
            controller: _widths(left: 300),
            left: const Text('left pane'),
            right: const Text('right pane'),
            body: const _OpenRight(),
          ),
          size: _desktop,
        );
        expect(tester.getRect(_box('left pane')).width, 300);
        expect(tester.getRect(_box('right pane')).width, 320);
      },
    );

    /// A page at [_desktop] with unbounded sides, `left` 240 and `right` 300
    /// wide, and a center column kept at least [minCenter] wide.
    Widget unbounded(PageLayoutController controller, {double? minCenter}) =>
        PageLayout(
          controller: controller,
          minCenterWidth: minCenter ?? 320,
          left: const Text('left pane'),
          right: const Text('right pane'),
          body: const Text('center'),
        );

    testWidgets(
      'R23: fo06/us19/fr06/e08: a drag of either divider stops where the '
      'center column keeps 320',
      (tester) async {
        final controller = _widths(left: 240, right: 300);
        await _pump(tester, unbounded(controller), size: _desktop);
        await tester.dragFrom(
          tester.getCenter(_dividers.at(1)),
          const Offset(2000, 0),
        );
        await tester.pumpAndSettle();
        expect(tester.getRect(_box('center')).width, closeTo(320, 1e-6));
        expect(controller.leftWidth, closeTo(680, 1e-6));
        expect(controller.rightWidth, 300);
        controller.leftWidth = 240;
        await tester.pump();
        await tester.dragFrom(
          tester.getCenter(_dividers.at(0)),
          const Offset(-2000, 0),
        );
        await tester.pumpAndSettle();
        expect(tester.getRect(_box('center')).width, closeTo(320, 1e-6));
        expect(controller.rightWidth, closeTo(740, 1e-6));
      },
    );

    testWidgets(
      'R23: fo06/us19/fr06/e08: End on the left divider stops where the '
      'center column keeps 320',
      (tester) async {
        final controller = _widths(left: 240, right: 300);
        await _pump(tester, unbounded(controller), size: _desktop);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.end);
        await tester.pump();
        expect(controller.leftWidth, closeTo(680, 1e-6));
        expect(tester.getRect(_box('center')).width, closeTo(320, 1e-6));
      },
    );

    testWidgets('R23: minCenterWidth moves the center minimum', (tester) async {
      final controller = _widths(left: 240, right: 300);
      await _pump(
        tester,
        unbounded(controller, minCenter: 500),
        size: _desktop,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(controller.leftWidth, closeTo(500, 1e-6));
      expect(tester.getRect(_box('center')).width, closeTo(500, 1e-6));
    });

    testWidgets(
      'R23: fo06/us19/fr06/e09: a window too narrow for both panes and '
      'the center minimum narrows the panes first, and notifies nothing',
      (tester) async {
        final notes = [0];
        final controller = _widths(left: 260, right: 320, notes: notes);
        await _pump(tester, unbounded(controller), size: const Size(800, 700));
        final left = tester.getRect(_box('left pane')).width;
        final right = tester.getRect(_box('right pane')).width;
        expect(tester.getRect(_box('center')).width, closeTo(320, 1e-6));
        expect(left + right, closeTo(480, 1e-6));
        expect(left, lessThan(260));
        expect(notes.single, 0);
        expect(controller.leftWidth, 260);
      },
    );

    testWidgets(
      'R23: fo06/us19/fr06/e09: a narrow window keeps left at its own '
      'minimum and narrows right before the center',
      (tester) async {
        await _pump(
          tester,
          const PageLayout(
            leftSide: PageSide(minWidth: 240),
            left: Text('left pane'),
            right: Text('right pane'),
            body: Text('center'),
          ),
          size: const Size(800, 700),
        );
        expect(tester.getRect(_box('left pane')).width, closeTo(240, 1e-6));
        expect(tester.getRect(_box('center')).width, closeTo(320, 1e-6));
        expect(tester.getRect(_box('right pane')).width, closeTo(240, 1e-6));
      },
    );

    testWidgets('R23: fo06/us19/fr06: a large right width set from code never '
        'squeezes left under its minimum', (tester) async {
      final controller = _widths(right: 300);
      await _pump(
        tester,
        PageLayout(
          controller: controller,
          leftSide: const PageSide(minWidth: 200),
          left: const Text('left pane'),
          right: const Text('right pane'),
          body: const Text('center'),
        ),
        size: _desktop,
      );
      controller.rightWidth = 900;
      await tester.pump();
      expect(tester.getRect(_box('left pane')).width, closeTo(200, 1e-6));
      expect(tester.getRect(_box('center')).width, closeTo(320, 1e-6));
      expect(tester.getRect(_box('right pane')).width, closeTo(780, 1e-6));
      expect(controller.rightWidth, 900);
    });

    testWidgets(
      "fo06/us19/fr06: the side's width bounds clamp its Figma width",
      (tester) async {
        await _pump(
          tester,
          const PageLayout(
            leftSide: PageSide(maxWidth: 250),
            rightSide: PageSide(minWidth: 400),
            left: Text('left pane'),
            right: Text('right pane'),
            body: _OpenRight(),
          ),
          size: _desktop,
        );
        expect(tester.getRect(_box('left pane')).width, 250);
        expect(tester.getRect(_box('right pane')).width, 400);
      },
    );

    testWidgets(
      'fo06/us19/fr06/e01: a drag past the maximum stops there, and the '
      'controller notifies once, when the drag ends',
      (tester) async {
        final notes = [0];
        final controller = _widths(left: 240, notes: notes);
        await _pump(
          tester,
          _sides(right: false, controller: controller),
          size: _desktop,
        );
        final drag = await tester.startGesture(tester.getCenter(_dividers));
        for (var i = 0; i < 4; i++) {
          await drag.moveBy(const Offset(100, 0));
          await tester.pump();
        }
        expect(tester.getRect(_box('left pane')).width, closeTo(400, 1e-6));
        expect(notes.single, 0);
        await drag.up();
        await tester.pumpAndSettle();
        expect(notes.single, 1);
        expect(controller.leftWidth, closeTo(400, 1e-6));
        expect(tester.getRect(_box('left pane')).width, closeTo(400, 1e-6));
      },
    );

    testWidgets('fo06/us19/fr06/e02: End takes the focused divider to the pane '
        'maximum and Home to its minimum, one notification per step', (
      tester,
    ) async {
      final notes = [0];
      final controller = _widths(left: 240, notes: notes);
      await _pump(
        tester,
        _sides(right: false, controller: controller),
        size: _desktop,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_focusLabel, startsWith('SplitLayout divider'));
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(tester.getRect(_box('left pane')).width, closeTo(400, 1e-6));
      expect(controller.leftWidth, closeTo(400, 1e-6));
      expect(notes.single, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expect(controller.leftWidth, closeTo(200, 1e-6));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(controller.leftWidth, closeTo(216, 1e-6));
      expect(tester.getRect(_box('left pane')).width, closeTo(216, 1e-6));
      expect(notes.single, 3);
    });

    for (final direction in TextDirection.values) {
      testWidgets(
        'fo06/us19/fr06/e02: under ${direction.name} End takes either '
        "divider's side pane to its maximum and Home to its minimum, while "
        'the arrows move by screen direction',
        (tester) async {
          final controller = _widths(left: 240, right: 300);
          await _pump(
            tester,
            PageLayout(
              controller: controller,
              leftSide: const PageSide(minWidth: 200, maxWidth: 400),
              rightSide: const PageSide(minWidth: 200, maxWidth: 500),
              left: const Text('left pane'),
              right: const Text('right pane'),
              body: const Text('center'),
            ),
            size: _desktop,
            direction: direction,
          );
          final ltr = direction == TextDirection.ltr;
          // The arrow toward the center column on screen widens each pane.
          final towardCenterOfLeft = ltr
              ? LogicalKeyboardKey.arrowRight
              : LogicalKeyboardKey.arrowLeft;
          final towardCenterOfRight = ltr
              ? LogicalKeyboardKey.arrowLeft
              : LogicalKeyboardKey.arrowRight;
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          await tester.sendKeyEvent(LogicalKeyboardKey.end);
          await tester.pump();
          expect(controller.leftWidth, closeTo(400, 1e-6));
          await tester.sendKeyEvent(LogicalKeyboardKey.home);
          await tester.pump();
          expect(controller.leftWidth, closeTo(200, 1e-6));
          await tester.sendKeyEvent(towardCenterOfLeft);
          await tester.pump();
          expect(controller.leftWidth, closeTo(216, 1e-6));
          expect(tester.getRect(_box('left pane')).width, closeTo(216, 1e-6));
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          expect(_focusLabel, startsWith('SplitLayout divider'));
          await tester.sendKeyEvent(LogicalKeyboardKey.end);
          await tester.pump();
          expect(controller.rightWidth, closeTo(500, 1e-6));
          expect(tester.getRect(_box('right pane')).width, closeTo(500, 1e-6));
          await tester.sendKeyEvent(LogicalKeyboardKey.home);
          await tester.pump();
          expect(controller.rightWidth, closeTo(200, 1e-6));
          await tester.sendKeyEvent(towardCenterOfRight);
          await tester.pump();
          expect(controller.rightWidth, closeTo(216, 1e-6));
          expect(tester.getRect(_box('right pane')).width, closeTo(216, 1e-6));
        },
      );
    }

    testWidgets('R22: a width set from code moves the pane and notifies '
        'once', (tester) async {
      final notes = [0];
      final controller = _widths(left: 240, notes: notes);
      await _pump(
        tester,
        _sides(right: false, controller: controller),
        size: _desktop,
      );
      controller.leftWidth = 320;
      await tester.pump();
      expect(tester.getRect(_box('left pane')).width, 320);
      expect(notes.single, 1);
    });

    testWidgets('fo06/us19/fr06/e07: a window narrower than the chosen width '
        'clamps only the drawn width and notifies nothing', (tester) async {
      final notes = [0];
      final controller = _widths(left: 380, notes: notes);
      await _pump(
        tester,
        _sides(right: false, controller: controller),
        size: _desktop,
      );
      expect(tester.getRect(_box('left pane')).width, 380);
      // A 640 px tablet leaves the pane 640 less the center's 320.
      _view(tester, const Size(640, 800));
      await tester.pumpAndSettle();
      expect(tester.getRect(_box('left pane')).width, closeTo(320, 1e-6));
      expect(controller.leftWidth, 380);
      expect(notes.single, 0);
      _view(tester, _desktop);
      await tester.pumpAndSettle();
      expect(tester.getRect(_box('left pane')).width, 380);
    });

    testWidgets('R22: a settled width stays in pixels as the window resizes, '
        'never a share of it', (tester) async {
      final controller = _widths(left: 240);
      await _pump(
        tester,
        _sides(right: false, controller: controller),
        size: _desktop,
      );
      await tester.dragFrom(tester.getCenter(_dividers), const Offset(60, 0));
      await tester.pumpAndSettle();
      expect(controller.leftWidth, closeTo(300, 1e-6));
      _view(tester, _bigDesktop);
      await tester.pumpAndSettle();
      expect(tester.getRect(_box('left pane')).width, closeTo(300, 1e-6));
      controller.leftWidth = 260;
      await tester.pump();
      expect(tester.getRect(_box('left pane')).width, 260);
    });

    testWidgets('fo06/us19/fr06: a drag of the right divider reports the right '
        'width', (tester) async {
      final notes = [0];
      final controller = _widths(right: 300, notes: notes);
      await _pump(
        tester,
        _sides(left: false, controller: controller),
        size: _desktop,
      );
      await tester.dragFrom(tester.getCenter(_dividers), const Offset(-100, 0));
      await tester.pumpAndSettle();
      expect(tester.getRect(_box('right pane')).width, closeTo(400, 1e-6));
      expect(controller.rightWidth, closeTo(400, 1e-6));
      expect(controller.leftWidth, isNull);
      expect(notes.single, 1);
    });

    testWidgets('fo06/us19/fr06/e05: under right-to-left text left sits at the '
        'right edge, and its divider moves by screen direction', (
      tester,
    ) async {
      final controller = _widths(left: 240);
      await _pump(
        tester,
        _sides(right: false, controller: controller),
        size: _desktop,
        direction: TextDirection.rtl,
      );
      expect(
        tester.getRect(_box('left pane')),
        const Rect.fromLTRB(1060, 0, 1300, 900),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(controller.leftWidth, closeTo(256, 1e-6));
      expect(tester.getRect(_box('left pane')).left, closeTo(1044, 1e-6));
    });

    testWidgets('fo06/us19/fr06/e04: a divider drag builds no slot again', (
      tester,
    ) async {
      var builds = 0;
      await _pump(
        tester,
        _sides(
          right: false,
          controller: _widths(left: 240),
          body: Builder(
            builder: (context) {
              builds++;
              return const Text('body');
            },
          ),
        ),
        size: _desktop,
      );
      final drag = await tester.startGesture(tester.getCenter(_dividers));
      for (var i = 0; i < 5; i++) {
        await drag.moveBy(const Offset(20, 0));
        await tester.pump();
      }
      await drag.up();
      await tester.pumpAndSettle();
      expect(tester.getRect(_box('left pane')).width, closeTo(340, 1e-6));
      expect(builds, 1);
    });

    testWidgets(
      'R17: fo06/us19/fr06/e06: with no divider builders nothing paints '
      'over a seam, while each seam still reads as a slider',
      (tester) async {
        await _pump(
          tester,
          _sides(controller: _widths(left: 240, right: 300)),
          size: _desktop,
        );
        expect(_dividers, findsNWidgets(2));
        for (final seam in _dividers.evaluate()) {
          var visible = false;
          expect(
            seam.renderObject,
            paints..everything((method, arguments) {
              for (final paint in arguments.whereType<Paint>()) {
                if (paint.color.a > 0) visible = true;
              }
              return true;
            }),
          );
          expect(visible, isFalse);
        }
        expect(
          tester.getSemantics(_dividers.first),
          isSemantics(label: 'Resize panes', isSlider: true),
        );
      },
    );

    testWidgets(
      'R17: fo06/us19/fr06: the divider builders paint over their seams '
      'with no layout space and hear the focused state',
      (tester) async {
        final states = <String, List<SplitDividerState>>{
          'left': [],
          'right': [],
        };
        SplitDividerBuilder line(String side) => (context, state) {
          states[side]!.add(state);
          return ColoredBox(
            key: ValueKey(side),
            color: const Color(0xFF000000),
          );
        };
        await _pump(
          tester,
          _sides(
            controller: _widths(left: 240, right: 300),
            leftDivider: line('left'),
            rightDivider: line('right'),
          ),
          size: _desktop,
        );
        final minimum = TapTargetSize.minimumFor(defaultTargetPlatform).width;
        expect(tester.getRect(_box('left pane')).right, 240);
        expect(tester.getRect(_box('Open right')).left, 240);
        expect(tester.getCenter(find.byKey(const ValueKey('left'))).dx, 240);
        expect(
          tester.getSize(find.byKey(const ValueKey('left'))).width,
          minimum,
        );
        expect(tester.getCenter(find.byKey(const ValueKey('right'))).dx, 1000);
        expect(states['left']!.last.focused, isFalse);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(states['left']!.last.focused, isTrue);
        expect(states['right']!.last.focused, isFalse);
      },
    );
  });

  group('PageDrawer side pane and overlay accessibility gate', () {
    const glyphs = Align(
      alignment: Alignment.topCenter,
      child: Text('right pane'),
    );

    testWidgets('NFR-U01: the overlay drawer text passes contrast and its '
        'close button is labeled', (tester) async {
      await _pump(
        tester,
        _sides(overlay: true, rightPane: glyphs),
        size: _desktop,
        theme: defaultThemeSet.light,
      );
      await _openRight(tester);
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    });

    testWidgets('NFR-U02: Tab reaches the left divider after the left pane '
        'and shows its focus ring', (tester) async {
      await _pump(
        tester,
        _sides(right: false, controller: _widths(left: 240)),
        size: _desktop,
      );
      final idle = _ring(tester, _dividers);
      expect(idle.a, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(_focusLabel, startsWith('SplitLayout divider'));
      expect(_ring(tester, _dividers), isNot(isSameColorAs(idle)));
    });

    testWidgets(
      'NFR-U02: fo06/us19/fr01/e04: Tab reaches the overlay drawer close '
      'button after the pane and shows its focus ring',
      (tester) async {
        await _pump(tester, _sides(overlay: true), size: _desktop);
        await _openRight(tester);
        final close = find.bySemanticsLabel('Close');
        final idle = _ring(tester, close);
        expect(idle.a, 0);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(
          tester.getSemantics(close),
          isSemantics(label: 'Close', isButton: true, isFocused: true),
        );
        expect(_ring(tester, close), isNot(isSameColorAs(idle)));
      },
    );

    // The inline panes move only under the EndUser's drag or key, with no
    // animation; the overlay drawer slides in, so it carries the row.
    for (final (source, app, platform) in [
      ('no', false, false),
      ('app', true, false),
      ('platform', false, true),
    ]) {
      final reduced = app || platform;
      testWidgets('NFR-U03: with $source reduced motion one frame after it '
          'opens the overlay drawer ${reduced ? 'shows' : 'still moves to'} '
          'its settled place', (tester) async {
        if (platform) {
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              const FakeAccessibilityFeatures(reduceMotion: true);
          addTearDown(
            tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
          );
        }
        Future<void> open() async {
          await _pump(
            tester,
            _sides(overlay: true),
            size: _desktop,
            media: app
                ? (data) => data.copyWith(disableAnimations: true)
                : null,
          );
          await tester.tap(find.text('Open right'));
        }

        await open();
        await tester.pumpAndSettle();
        final target = tester.getRect(_box('right pane'));
        await tester.pumpWidget(const SizedBox.shrink());
        await open();
        await tester.pump();
        final settled = rectMoreOrLessEquals(target);
        expect(
          tester.getRect(_box('right pane')),
          reduced ? settled : isNot(settled),
        );
      });
    }

    testWidgets('NFR-U04: at twice the text size the inline pane and the '
        'overlay drawer keep their widths and wrap with no overflow', (
      tester,
    ) async {
      await _pump(
        tester,
        _sides(
          overlay: true,
          controller: _widths(left: 240),
          rightPane: const Text('right pane with a long label that wraps'),
        ),
        size: _desktop,
        media: (data) => data.copyWith(textScaler: const TextScaler.linear(2)),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getRect(_box('left pane')).width, 240);
      await _openRight(tester);
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
        400,
      );
    });

    testWidgets('NFR-U05: fo06/us19/fr06: each divider hit area spans the '
        'platform minimum centered on its seam', (tester) async {
      await _pump(
        tester,
        _sides(controller: _widths(left: 240, right: 300)),
        size: _desktop,
      );
      final minimum = TapTargetSize.minimumFor(defaultTargetPlatform).width;
      final centers = [
        for (var i = 0; i < 2; i++) tester.getCenter(_dividers.at(i)).dx,
      ]..sort();
      expect(centers, [240, 1000]);
      for (var i = 0; i < 2; i++) {
        expect(tester.getSize(_dividers.at(i)).width, minimum);
      }
    }, variant: TargetPlatformVariant.all());

    testWidgets('NFR-U05: the overlay drawer close button meets the '
        "platform's size", (tester) async {
      // Insets keep the button off the screen edge, which the guideline
      // skips.
      await _pump(
        tester,
        _sides(overlay: true),
        size: _desktop,
        media: (data) =>
            data.copyWith(padding: const EdgeInsets.only(top: 20, right: 20)),
      );
      await _openRight(tester);
      final minimum = TapTargetSize.minimumFor(defaultTargetPlatform);
      final close = tester.getSize(find.bySemanticsLabel('Close'));
      expect(close.width, greaterThanOrEqualTo(minimum.width));
      expect(close.height, greaterThanOrEqualTo(minimum.height));
      await expectLater(
        tester,
        meetsGuideline(MinimumTapTargetGuideline(size: minimum, link: '')),
      );
    }, variant: TargetPlatformVariant.all());

    testWidgets(
      'NFR-U06: fo06/us19/fr06: a divider reads as a slider valued by '
      "the left pane's share, with step actions, and turns focused",
      (tester) async {
        await _pump(
          tester,
          _sides(right: false, controller: _widths(left: 240)),
          size: _desktop,
        );
        expect(
          tester.getSemantics(_dividers),
          matchesSemantics(
            label: 'Resize panes',
            value: '18%',
            increasedValue: '20%',
            decreasedValue: '17%',
            isSlider: true,
            isFocusable: true,
            hasFocusAction: true,
            hasIncreaseAction: true,
            hasDecreaseAction: true,
          ),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(
          tester.getSemantics(_dividers),
          isSemantics(label: 'Resize panes', isSlider: true, isFocused: true),
        );
      },
    );

    testWidgets('NFR-U06: fo06/us19/fr06: the right divider reads as a slider '
        "valued by the right pane's share, and increase widens it", (
      tester,
    ) async {
      final controller = _widths(right: 300);
      await _pump(
        tester,
        _sides(left: false, controller: controller),
        size: _desktop,
      );
      expect(
        tester.getSemantics(_dividers),
        matchesSemantics(
          label: 'Resize panes',
          value: '23%',
          increasedValue: '24%',
          decreasedValue: '22%',
          isSlider: true,
          isFocusable: true,
          hasFocusAction: true,
          hasIncreaseAction: true,
          hasDecreaseAction: true,
        ),
      );
      tester.semantics.increase(find.semantics.byLabel('Resize panes'));
      await tester.pump();
      expect(controller.rightWidth, closeTo(316, 1e-6));
      expect(tester.getRect(_box('right pane')).width, closeTo(316, 1e-6));
    });

    testWidgets(
      'NFR-U06: fo06/us19/fr01/e04: the overlay drawer reads as a named '
      'screen with a labeled close button',
      (tester) async {
        await _pump(tester, _sides(overlay: true), size: _desktop);
        await _openRight(tester);
        expect(
          tester.getSemantics(_drawer),
          isSemantics(
            label: 'Navigation menu',
            scopesRoute: true,
            namesRoute: true,
          ),
        );
        expect(
          tester.getSemantics(find.bySemanticsLabel('Close')),
          matchesSemantics(
            label: 'Close',
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            isFocusable: true,
            hasTapAction: true,
            hasFocusAction: true,
          ),
        );
      },
    );

    testWidgets(
      'NFR-U06: fo06/us19/fr05/e02: in Thai the close button reads the '
      'Thai built-in label',
      (tester) async {
        tester.platformDispatcher.localeTestValue = const Locale('th');
        addTearDown(tester.platformDispatcher.clearLocaleTestValue);
        await _pump(tester, _sides(overlay: true), size: _desktop);
        await _openRight(tester);
        expect(
          tester.getSemantics(find.bySemanticsLabel('ปิด').last),
          isSemantics(label: 'ปิด', isButton: true),
        );
      },
    );

    testWidgets('NFR-U07: the overlay drawer text passes contrast in every '
        'bundled theme', (tester) async {
      final themes = [
        defaultThemeSet.light,
        defaultThemeSet.dark,
        defaultThemeSet.highContrastLight,
        defaultThemeSet.highContrastDark,
      ].nonNulls;
      for (final theme in themes) {
        await _pump(
          tester,
          KeyedSubtree(
            key: ObjectKey(theme),
            child: _sides(overlay: true, rightPane: glyphs),
          ),
          size: _desktop,
          theme: theme,
        );
        await _openRight(tester);
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      }
    });

    testWidgets('NFR-U08: under high contrast a focused divider shows the '
        'ring shape, and the overlay drawer its close icon and shadow', (
      tester,
    ) async {
      await _pump(
        tester,
        _sides(overlay: true, controller: _widths(left: 240)),
        size: _desktop,
        highContrast: true,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(_ring(tester, _dividers).a, greaterThan(0));
      await _openRight(tester);
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(
        tester.widget<ContainerLayout>(_box('right pane')).style!.dropShadow,
        isNotEmpty,
      );
    });

    testWidgets('NFR-U09: a key or a screen reader step resizes a pane with '
        'no drag, and a tap closes the overlay drawer', (tester) async {
      final notes = [0];
      final controller = _widths(left: 240, notes: notes);
      await _pump(
        tester,
        _sides(overlay: true, controller: controller),
        size: _desktop,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(controller.leftWidth, closeTo(400, 1e-6));
      tester.semantics.decrease(find.semantics.byLabel('Resize panes'));
      await tester.pump();
      expect(controller.leftWidth, closeTo(384, 1e-6));
      expect(tester.getRect(_box('left pane')).width, closeTo(384, 1e-6));
      expect(notes.single, 2);
      await _openRight(tester);
      await tester.tap(find.bySemanticsLabel('Close'));
      await tester.pumpAndSettle();
      expect(find.text('right pane'), findsNothing);
    });

    testWidgets('NFR-E01: the overlay drawer fill follows the theme', (
      tester,
    ) async {
      Future<Color?> fill(StratumThemeData theme) async {
        await _pump(
          tester,
          KeyedSubtree(key: ObjectKey(theme), child: _sides(overlay: true)),
          size: _desktop,
          theme: theme,
        );
        await _openRight(tester);
        return tester
            .widget<ContainerLayout>(_box('right pane'))
            .style!
            .backgroundColor;
      }

      final light = await fill(defaultThemeSet.light);
      final dark = await fill(defaultThemeSet.dark!);
      expect(light, defaultThemeSet.light.color.background.defaults.surface);
      expect(dark, isNot(light));
    });

    testWidgets('NFR-E02: a customStyle right fill restyles the overlay '
        'drawer, and its shadow keeps the theme default', (tester) async {
      const fill = Color(0xFF123456);
      await _pump(
        tester,
        _sides(
          overlay: true,
          style: const PageLayoutStyle(
            right: WidgetStyle(backgroundColor: fill),
          ),
        ),
        size: _desktop,
      );
      await _openRight(tester);
      final style = tester.widget<ContainerLayout>(_box('right pane')).style!;
      expect(style.backgroundColor, fill);
      expect(style.dropShadow, fakeTheme.shadow.level4);
    });
  });

  group('PageDrawer in a box smaller than the screen', () {
    testWidgets(
      'fo06/us19/s1: fo06/us19/fr04/e09: s03/inv67: the drawer is 80% of a box '
      'the insets narrow',
      (tester) async {
        await _pumpInBox(
          tester,
          _page(),
          inset: const EdgeInsets.only(right: 84),
        );
        await _openMenu(tester);
        expect(tester.getRect(_panel).width, moreOrLessEquals(305.6));
        expect(tester.getRect(_panel).left, 0);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets(
      'fo06/us19/fr04/e12: s03/inv67: a page layout that fills the screen '
      'sizes its drawer by the screen',
      (tester) async {
        _view(tester, _duo);
        await tester.pumpWidget(
          _host(
            RepaintBoundary(
              key: _shot,
              child: ColoredBox(color: _behind, child: _page()),
            ),
          ),
        );
        await _openMenu(tester);

        final colors = await _pixels(tester, const [Offset(460, 500)]);

        expect(tester.getRect(_panel).width, 360);
        expect(colors.single, isNot(_behind));
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    final sides = <(String, PageSide)>[
      ('slide', const PageSide()),
      ('back', const PageSide(type: PageDrawerType.back)),
    ];
    final cases = [
      (
        name: 'right inset, start drawer',
        inset: const EdgeInsets.only(right: 84),
        direction: TextDirection.ltr,
        endDrawer: false,
        strip: 424.0,
        inner: 376.0,
      ),
      (
        name: 'left inset, end drawer',
        inset: const EdgeInsets.only(left: 84),
        direction: TextDirection.ltr,
        endDrawer: true,
        strip: 42.0,
        inner: 90.0,
      ),
      (
        name: 'left inset, RTL start drawer',
        inset: const EdgeInsets.only(left: 84),
        direction: TextDirection.rtl,
        endDrawer: false,
        strip: 42.0,
        inner: 90.0,
      ),
    ];
    for (final (type, side) in sides) {
      for (final c in cases) {
        testWidgets(
          'fo06/us19/fr04/e09: s03/inv83: nothing paints past the box: $type, '
          '${c.name}',
          (tester) async {
            final page = c.endDrawer
                ? _page(
                    right: const Text('end item'),
                    rightSide: side,
                    body: const _OpenRight(),
                  )
                : _page(leftSide: side);
            await _pumpInBox(
              tester,
              page,
              inset: c.inset,
              direction: c.direction,
            );
            if (c.endDrawer) {
              await _openRight(tester);
            } else {
              await _openMenu(tester);
            }
            final strip = [
              for (final y in [100.0, 300.0, 500.0, 700.0, 900.0])
                Offset(c.strip, y),
            ];
            expect(await _pixels(tester, strip), everyElement(_behind));
            final inner = await _pixels(tester, [Offset(c.inner, 500)]);
            expect(inner.single, isNot(_behind));
          },
          variant: TargetPlatformVariant.only(TargetPlatform.iOS),
        );
      }
    }

    for (final type in [
      PageDrawerType.slide,
      PageDrawerType.back,
      PageDrawerType.front,
    ]) {
      testWidgets(
        'fo06/us19/fr04/e10: fo06/us19/fr05/e04: s03/inv68: a drawer as wide as '
        'the box keeps one Dismiss node, and it closes the drawer: $type',
        (tester) async {
          final handle = tester.ensureSemantics();
          await _pumpInBox(
            tester,
            _page(leftSide: PageSide(type: type, minWidth: 400, maxWidth: 400)),
            inset: const EdgeInsets.only(right: 84),
          );
          await _openMenu(tester);
          expect(tester.getRect(_panel).width, 382);
          final dismiss = find.bySemanticsLabel('Dismiss');
          expect(dismiss, findsOneWidget);
          expect(
            tester.getSemantics(dismiss),
            isSemantics(label: 'Dismiss', hasTapAction: true, isHidden: false),
          );
          expect(tester.getRect(dismiss), const Rect.fromLTWH(0, 0, 382, 1000));
          tester.semantics.tap(find.semantics.byLabel('Dismiss'));
          await tester.pumpAndSettle();
          expect(_drawer, findsNothing);
          await _openMenu(tester);
          await tester.dragFrom(const Offset(200, 500), const Offset(-200, 0));
          await tester.pumpAndSettle();
          expect(_drawer, findsNothing);
          handle.dispose();
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );
    }

    testWidgets(
      'fo06/us19/fr05/e04: s03/inv68: a drawer as wide as the box reads no '
      'Dismiss node on this platform, and Esc closes it',
      (tester) async {
        final handle = tester.ensureSemantics();
        await _pumpInBox(
          tester,
          _page(leftSide: const PageSide(minWidth: 400, maxWidth: 400)),
          inset: const EdgeInsets.only(right: 84),
        );
        await _openMenu(tester);
        expect(find.bySemanticsLabel('Dismiss'), findsNothing);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(_drawer, findsNothing);
        handle.dispose();
      },
      variant: const TargetPlatformVariant({
        TargetPlatform.windows,
        TargetPlatform.linux,
        TargetPlatform.fuchsia,
      }),
    );

    testWidgets(
      'fo06/us19/fr01: fo06/us19/fr04/e10: s03/inv69: an overlay right drawer '
      'in a box narrower than 400 takes the box width and keeps its close '
      'button',
      (tester) async {
        _view(tester, _tablet);
        await tester.pumpWidget(
          _host(
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: SizedBox(
                width: 360,
                child: _sides(overlay: true, left: false),
              ),
            ),
          ),
        );
        await _openRight(tester);
        expect(tester.getSize(_box('right pane')).width, 360);
        expect(find.bySemanticsLabel('Close'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('Close'));
        await tester.pumpAndSettle();
        expect(find.text('right pane'), findsNothing);
      },
    );

    for (final type in [
      PageDrawerType.front,
      PageDrawerType.back,
      PageDrawerType.slide,
      PageDrawerType.permanent,
    ]) {
      testWidgets('fo06/us19/fr04/e11: s03/inv67: the stage clips to the box only while a '
          'drawer shows: $type', (tester) async {
        await _pumpInBox(
          tester,
          _page(leftSide: PageSide(type: type)),
          inset: const EdgeInsets.only(right: 84),
        );
        expect(_stageClip(tester), Clip.none);
        await _openMenu(tester);
        expect(_stageClip(tester), Clip.hardEdge);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(_stageClip(tester), Clip.none);
      }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
    }

    final edgeCases = <(String, TargetPlatform, PageSide)>[
      ('iOS slide', TargetPlatform.iOS, const PageSide()),
      (
        'iOS back',
        TargetPlatform.iOS,
        const PageSide(type: PageDrawerType.back),
      ),
      (
        'Android front',
        TargetPlatform.android,
        const PageSide(type: PageDrawerType.front),
      ),
    ];
    for (final (type, platform, side) in edgeCases) {
      Future<void> openInBox(WidgetTester tester) async {
        await _pumpInBox(
          tester,
          _page(leftSide: side),
          inset: const EdgeInsets.only(right: 84),
        );
        await _openMenu(tester);
      }

      testWidgets(
        'NFR-U05: NFR-U09: fo06/us19/fr04: s03/inv83: a tap on the scrim at '
        'the box edge closes the drawer: $type',
        (tester) async {
          await openInBox(tester);
          await tester.tapAt(const Offset(380, 500));
          await tester.pumpAndSettle();
          expect(_drawer, findsNothing);
        },
        variant: TargetPlatformVariant.only(platform),
      );

      testWidgets(
        'NFR-U09: fo06/us19/fr04: s03/inv83: a drag that starts on the scrim '
        'at the box edge closes the drawer: $type',
        (tester) async {
          await openInBox(tester);
          await tester.dragFrom(const Offset(380, 500), const Offset(-260, 0));
          await tester.pumpAndSettle();
          expect(_drawer, findsNothing);
        },
        variant: TargetPlatformVariant.only(platform),
      );

      testWidgets(
        'fo06/us19/fr04: a tap inside the open panel keeps the drawer open: '
        '$type',
        (tester) async {
          await openInBox(tester);
          await tester.tapAt(const Offset(150, 500));
          await tester.pumpAndSettle();
          expect(_drawer, findsOneWidget);
        },
        variant: TargetPlatformVariant.only(platform),
      );
    }

    testWidgets('fo06/us19/fr04/e09: opening and closing a drawer in a box '
        'remounts no page slot', (tester) async {
      final made = [0];
      await _pumpInBox(
        tester,
        _sides(body: _Kept(made)),
        inset: const EdgeInsets.only(right: 84),
      );
      expect(find.text('right pane'), findsNothing);
      await _openRight(tester);
      expect(find.text('right pane'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('right pane'), findsNothing);
      expect(made.single, 1);
    });
  });
}
