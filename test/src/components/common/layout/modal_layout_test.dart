import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/layout/modal_layout.dart'
    show
        ModalLayoutScope,
        modalContentWidth,
        modalCorners,
        resolveModalLayoutType;
import 'package:stratum_ui/src/src.dart';

import '../fakes/fake_stratum_theme.dart';

// NFR-U03 has no row here: the modal layout itself moves and resizes
// nothing; the route's enter, exit, and snap motion belong to
// `showModalLayout` (layout s03 inv. 73 and 74).

void _noop() {}

Widget _modal({
  ModalLayoutType? type = ModalLayoutType.modal,
  ModalLayoutSize size = ModalLayoutSize.medium,
  ModalLayoutStyle? style,
  bool showClose = true,
  VoidCallback? onClose,
  Widget? top,
  Widget? tab,
  Widget body = const Text('Body'),
  BorderRadiusGeometry? radius,
  bool? safeArea,
  bool? fullHeight,
  bool scrollBody = true,
}) => ModalLayout(
  type: type,
  size: size,
  top: top,
  tab: tab,
  body: body,
  showClose: showClose,
  onClose: onClose,
  borderRadius: radius,
  safeArea: safeArea,
  fullHeight: fullHeight,
  scrollBody: scrollBody,
  customStyle: style,
);

/// [child] under the route scope `showModalLayout` publishes.
Widget _scoped(
  Widget child, {
  ModalLayoutType type = ModalLayoutType.floating,
  bool showBackground = true,
  bool fullHeight = false,
  VoidCallback onDismiss = _noop,
}) => ModalLayoutScope(
  type: type,
  showBackground: showBackground,
  fullHeight: fullHeight,
  onDismiss: onDismiss,
  child: child,
);

/// [child] under its own context's media data, edited by [edit], so the
/// window size and width stay the test view's.
Widget _media(
  Widget child,
  MediaQueryData Function(MediaQueryData data) edit,
) => Builder(
  builder: (context) =>
      MediaQuery(data: edit(MediaQuery.of(context)), child: child),
);

/// A test view [size] logical pixels large, reset after the test.
void _view(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

const _phone = Size(390, 844);

/// The surface box: the first `ContainerLayout` under the modal layout.
Finder get _surface => find
    .descendant(
      of: find.byType(ModalLayout),
      matching: find.byType(ContainerLayout),
    )
    .first;

WidgetStyle _surfaceStyle(WidgetTester tester) =>
    tester.widget<ContainerLayout>(_surface).style!;

/// The part box whose semantics label is [label]: `Close` or `Dismiss`.
Finder _part(String label) => find.byWidgetPredicate(
  (widget) => widget is ContainerLayout && widget.semantics?.label == label,
);

Finder get _close => _part('Close');

/// The scroll view the modal layout wraps its body in.
Finder get _bodyScroll => find.descendant(
  of: find.byType(ModalLayout),
  matching: find.byType(SingleChildScrollView),
);

SingleChildScrollView _bodyScrollView(WidgetTester tester) =>
    tester.widget<SingleChildScrollView>(_bodyScroll);

Finder get _handle => _part('Dismiss');

WidgetStyle _partStyle(WidgetTester tester, Finder part) =>
    tester.widget<ContainerLayout>(part).style!;

/// The color of the ring the close button's `StratumInkWell` paints.
Color _closeRing(WidgetTester tester) {
  late Color color;
  expect(
    tester.renderObject(
      find.descendant(of: _close, matching: find.byType(StratumFocusBorder)),
    ),
    paints..everything((method, arguments) {
      if (method == #drawDRRect) {
        color = arguments.whereType<Paint>().single.color;
      }
      return true;
    }),
  );
  return color;
}

bool _focused(WidgetTester tester, String label) => isSemantics(isFocused: true)
    .matches(
      tester.getSemantics(find.bySemanticsLabel(label)),
      <dynamic, dynamic>{},
    );

/// [child] under the app's default Tab and activation keys, in a focused
/// scope so the first Tab press reaches the keys.
Widget _keyboardHost(Widget child) => themedHost(
  Shortcuts(
    shortcuts: WidgetsApp.defaultShortcuts,
    child: Actions(
      actions: WidgetsApp.defaultActions,
      child: FocusScope(autofocus: true, child: child),
    ),
  ),
);

/// A body text only as wide as its glyphs, at the start: the close button
/// overlays the top end corner of the slots, so a full-width text would
/// sample the close icon as well and hide the surface contrast (NFR-U07).
const _startBody = Align(
  alignment: AlignmentDirectional.centerStart,
  child: Text('Body'),
);

/// A focusable box labeled [label], standing in for an app's control.
Widget _button(String label) => ContainerLayout(
  style: const WidgetStyle(width: 48, height: 48),
  interaction: const Interaction(onTap: _noop),
  semantics: SemanticsProperties(label: label),
);

void main() {
  group('rules', () {
    test('us20/fr03/e01: no type below tablet is a bottom sheet', () {
      expect(
        resolveModalLayoutType(null, WindowSize.mobile),
        ModalLayoutType.bottomSheet,
      );
    });
    test('us20/fr03/e02: no type at tablet and up is a modal', () {
      expect(
        resolveModalLayoutType(null, WindowSize.tablet),
        ModalLayoutType.modal,
      );
      expect(
        resolveModalLayoutType(null, WindowSize.bigDesktop),
        ModalLayoutType.modal,
      );
    });
    test('us20/fr03: a set type wins over the window size', () {
      expect(
        resolveModalLayoutType(ModalLayoutType.floating, WindowSize.desktop),
        ModalLayoutType.floating,
      );
    });
    test('us20/fr03: content widths by size', () {
      double w(ModalLayoutSize s) => modalContentWidth(
        type: ModalLayoutType.modal,
        size: s,
        window: WindowSize.desktop,
        windowWidth: 1400,
        edgeMargin: 20,
      );
      expect(w(ModalLayoutSize.medium), 400);
      expect(w(ModalLayoutSize.large), 800);
      expect(w(ModalLayoutSize.extraLarge), 1000);
      expect(w(ModalLayoutSize.fillWidth), 1360); // fr03/e04
    });
    test('us20/fr03/e03: a sheet below tablet takes the full width', () {
      expect(
        modalContentWidth(
          type: ModalLayoutType.bottomSheet,
          size: ModalLayoutSize.large,
          window: WindowSize.mobile,
          windowWidth: 390,
          edgeMargin: 20,
        ),
        390,
      );
    });
    test('us20/fr04: a floating sheet below tablet sits 8 px in from each '
        'side', () {
      expect(
        modalContentWidth(
          type: ModalLayoutType.floating,
          size: ModalLayoutSize.large,
          window: WindowSize.mobile,
          windowWidth: 390,
          edgeMargin: 20,
        ),
        374,
      );
    });
    test('us20/fr03/e05: a medium modal on a 390 px window clamps to 350', () {
      expect(
        modalContentWidth(
          type: ModalLayoutType.modal,
          size: ModalLayoutSize.medium,
          window: WindowSize.mobile,
          windowWidth: 390,
          edgeMargin: 20,
        ),
        350,
      );
    });
    test('us20/fr03: every width clamps to the window less both margins', () {
      for (final size in ModalLayoutSize.values) {
        expect(
          modalContentWidth(
            type: ModalLayoutType.bottomSheet,
            size: size,
            window: WindowSize.tablet,
            windowWidth: 768,
            edgeMargin: 20,
          ),
          lessThanOrEqualTo(728),
          reason: size.name,
        );
      }
      expect(
        modalContentWidth(
          type: ModalLayoutType.modal,
          size: ModalLayoutSize.medium,
          window: WindowSize.watch,
          windowWidth: 30,
          edgeMargin: 20,
        ),
        0,
      );
    });

    const r40 = BorderRadius.all(Radius.circular(40));
    const r46 = BorderRadius.all(Radius.circular(46));
    BorderRadius corners(
      ModalLayoutType t,
      BorderRadius? s, {
      bool full = false,
    }) => modalCorners(
      type: t,
      screen: s,
      sheetTop: 40,
      cardLarge: 24,
      fullHeight: full,
    );
    test('us20/fr04/e01: a sheet on a 40 px screen radius', () {
      expect(corners(ModalLayoutType.bottomSheet, r40), r40);
    });
    test('us20/fr04/e02: a sheet with the radius unknown', () {
      expect(
        corners(ModalLayoutType.bottomSheet, null),
        const BorderRadius.vertical(top: Radius.circular(40)),
      );
    });
    test('us20/fr04/e03: a full-height sheet takes the screen radius on '
        'top', () {
      expect(
        corners(ModalLayoutType.bottomSheet, r46, full: true).topLeft,
        const Radius.circular(46),
      );
      expect(
        corners(ModalLayoutType.bottomSheet, null, full: true).topLeft,
        const Radius.circular(40),
      );
    });
    test('us20/fr04/e04: floating is the screen radius less 8, else 38', () {
      expect(
        corners(ModalLayoutType.floating, r46),
        const BorderRadius.all(Radius.circular(38)),
      );
      expect(
        corners(ModalLayoutType.floating, null),
        const BorderRadius.all(Radius.circular(38)),
      );
    });
    test('us20/fr04/e05: a modal takes card-large whatever the screen', () {
      expect(
        corners(ModalLayoutType.modal, r46),
        const BorderRadius.all(Radius.circular(24)),
      );
    });
  });

  group('ModalLayoutStyle', () {
    test('NFR-E02: merge replaces each part field by field', () {
      const base = ModalLayoutStyle(
        surface: WidgetStyle(width: 1, height: 2),
        close: WidgetStyle(opacity: 0.5),
      );
      final merged = base.merge(
        const ModalLayoutStyle(
          surface: WidgetStyle(height: 3),
          top: WidgetStyle(width: 4),
        ),
      );
      expect(merged.surface, const WidgetStyle(width: 1, height: 3));
      expect(merged.top, const WidgetStyle(width: 4));
      expect(merged.close, const WidgetStyle(opacity: 0.5));
      expect(merged.tab, isNull);
      expect(base.merge(null), base);
    });

    test('us06/fr01: equal part styles are equal, so an equal app-wide map '
        'rebuilds no modal layout', () {
      // Built at run time, so no const canonicalization makes them one
      // instance and the check reads `==`, not identity.
      ModalLayoutStyle make(double width) =>
          ModalLayoutStyle(surface: WidgetStyle(width: width));
      final a = make(1);
      final b = make(1);
      expect(identical(a, b), isFalse);
      expect(a == b, isTrue);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(make(2)));
      expect(a, isNot(const ModalLayoutStyle(handle: WidgetStyle(width: 1))));
    });
  });

  group('ModalLayout', () {
    testWidgets('us20/fr01/e01: null top and tab do not show', (tester) async {
      await tester.pumpWidget(themedHost(_modal()));
      expect(find.text('Body'), findsOneWidget);
      expect(find.byType(ModalLayout), findsOneWidget);
      // The body's box only: no top, tab, or handle box.
      expect(
        find.descendant(
          of: find.byType(ColumnLayout),
          matching: find.byType(ContainerLayout),
        ),
        findsOneWidget,
      );
    });

    testWidgets('us20/fr01: top, tab, body in that order', (tester) async {
      await tester.pumpWidget(
        themedHost(_modal(top: const Text('Top'), tab: const Text('Tab'))),
      );
      final y = [
        for (final t in ['Top', 'Tab', 'Body'])
          tester.getTopLeft(find.text(t)).dy,
      ];
      expect(y, orderedEquals([...y]..sort()));
      expect(y.toSet(), hasLength(3));
    });

    testWidgets('us20/fr01/e02: showClose hides or shows the close button', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(themedHost(_modal(showClose: false)));
      expect(find.bySemanticsLabel('Close'), findsNothing);
      await tester.pumpWidget(themedHost(_modal()));
      expect(find.bySemanticsLabel('Close'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('us20/fr01/e03: inline, with no onClose, the close button '
        'pops nothing', (tester) async {
      await tester.pumpWidget(
        themedHost(
          Navigator(
            onGenerateInitialRoutes: (navigator, _) => [
              PageRouteBuilder<void>(
                pageBuilder: (_, _, _) => const Text('Home'),
              ),
              PageRouteBuilder<void>(pageBuilder: (_, _, _) => _modal()),
            ],
          ),
        ),
      );
      await tester.tap(_close);
      await tester.pumpAndSettle();
      expect(find.byType(ModalLayout), findsOneWidget);
      expect(find.text('Home'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(ModalLayout),
          matching: find.byType(ModalBarrier),
        ),
        findsNothing,
      );
    });

    testWidgets('us20/fr01/e03: inline in a scrolling page, it sizes to its '
        'content', (tester) async {
      await tester.pumpWidget(
        themedHost(
          ListViewLayout.builder(
            itemCount: 2,
            itemBuilder: (_, index) => index == 0
                ? _modal(top: const Text('Top'))
                : const Text('After'),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('After'), findsOneWidget);
    });

    testWidgets('us20/fr03/e01: no type on a phone is a full-width bottom '
        'sheet with a handle', (tester) async {
      _view(tester, _phone);
      await tester.pumpWidget(themedHost(_modal(type: null)));
      expect(_surfaceStyle(tester).width, 390);
      expect(_handle, findsOneWidget);
    });

    testWidgets('us20/fr03/e02: no type on a tablet is a 400 px modal with '
        'no handle', (tester) async {
      await tester.pumpWidget(themedHost(_modal(type: null)));
      expect(tester.getSize(_surface).width, 400);
      expect(_surfaceStyle(tester).borderRadius, BorderRadius.circular(24));
      expect(_handle, findsNothing);
    });

    testWidgets('us20/fr03/e05: a medium modal on a 390 px window draws '
        '350 px', (tester) async {
      _view(tester, _phone);
      await tester.pumpWidget(themedHost(_modal()));
      expect(tester.getSize(_surface).width, 350);
    });

    testWidgets('us20/fr04: a floating sheet on a phone opens 8 px in from '
        'the screen edges with concentric corners', (tester) async {
      _view(tester, _phone);
      const r46 = BorderRadius.all(Radius.circular(46));
      await tester.pumpWidget(
        themedHost(
          _media(
            _modal(type: ModalLayoutType.floating),
            (data) => data.applyDisplayCornerRadii(r46),
          ),
        ),
      );
      final style = _surfaceStyle(tester);
      expect(style.width, 374);
      expect(style.margin, const EdgeInsets.all(8));
      expect(style.borderRadius, BorderRadius.circular(38));
    });

    testWidgets('us20/fr04/e06: an app borderRadius wins', (tester) async {
      const r12 = BorderRadius.all(Radius.circular(12));
      await tester.pumpWidget(
        themedHost(_modal(type: ModalLayoutType.bottomSheet, radius: r12)),
      );
      expect(_surfaceStyle(tester).borderRadius, r12);
    });

    testWidgets('us20/fr04: the app-wide parts style beats the corner rule, '
        'borderRadius beats it, and customStyle beats both', (tester) async {
      const r8 = BorderRadius.all(Radius.circular(8));
      const r12 = BorderRadius.all(Radius.circular(12));
      const r16 = BorderRadius.all(Radius.circular(16));
      Widget host(Widget child) => StratumThemeApplication(
        themes: StratumThemeSet(light: fakeTheme),
        themeMode: ThemeMode.light,
        componentPartDefaults: (theme) => {
          ModalLayout: const ModalLayoutStyle(
            surface: WidgetStyle(borderRadius: r8),
          ),
        },
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(child: child),
        ),
      );
      await tester.pumpWidget(host(_modal()));
      expect(_surfaceStyle(tester).borderRadius, r8);
      await tester.pumpWidget(host(_modal(radius: r12)));
      expect(_surfaceStyle(tester).borderRadius, r12);
      await tester.pumpWidget(
        host(
          _modal(
            radius: r12,
            style: const ModalLayoutStyle(
              surface: WidgetStyle(borderRadius: r16),
            ),
          ),
        ),
      );
      expect(_surfaceStyle(tester).borderRadius, r16);
    });

    testWidgets('us20/fr01: the surface pads by type and size from the '
        'space 4xl and lg tokens', (tester) async {
      await tester.pumpWidget(themedHost(_modal()));
      expect(
        _surfaceStyle(tester).padding,
        const EdgeInsets.fromLTRB(20, 40, 20, 40),
      );
      await tester.pumpWidget(themedHost(_modal(size: ModalLayoutSize.large)));
      expect(_surfaceStyle(tester).padding, const EdgeInsets.all(40));
      await tester.pumpWidget(
        themedHost(_modal(type: ModalLayoutType.floating)),
      );
      expect(_surfaceStyle(tester).padding, EdgeInsets.zero);
    });

    testWidgets('us20/fr05/e01: a bottom sheet keeps its content above the '
        'home indicator; e02: at full height, below the status bar', (
      tester,
    ) async {
      _view(tester, _phone);
      const insets = EdgeInsets.only(top: 47, bottom: 34);
      Widget sheet({bool? fullHeight}) => themedHost(
        _media(
          _modal(type: ModalLayoutType.bottomSheet, fullHeight: fullHeight),
          (data) => data.copyWith(padding: insets),
        ),
      );
      await tester.pumpWidget(sheet());
      expect(_surfaceStyle(tester).padding, const EdgeInsets.only(bottom: 34));
      await tester.pumpWidget(sheet(fullHeight: true));
      expect(_surfaceStyle(tester).padding, insets);
    });

    testWidgets('us20/fr05: a modal adds no inset by default; e03: with '
        'safeArea it keeps clear of every inset', (tester) async {
      const insets = EdgeInsets.fromLTRB(10, 20, 30, 40);
      Widget modal({bool? safeArea}) => themedHost(
        _media(
          _modal(safeArea: safeArea),
          (data) => data.copyWith(padding: insets),
        ),
      );
      await tester.pumpWidget(modal());
      expect(
        _surfaceStyle(tester).padding,
        const EdgeInsets.fromLTRB(20, 40, 20, 40),
      );
      await tester.pumpWidget(modal(safeArea: true));
      expect(
        _surfaceStyle(tester).padding,
        const EdgeInsets.fromLTRB(30, 60, 50, 80),
      );
    });

    testWidgets('us20/fr06/e03: the surface draws the theme shadow/4', (
      tester,
    ) async {
      final shadow = fakeTheme.shadow;
      const level4 = [BoxShadow(blurRadius: 7)];
      final theme = fakeTheme.copyWith(
        shadow: StratumShadowTokens.fromMap({
          '1': shadow.level1,
          '2': shadow.level2,
          '3': shadow.level3,
          '4': level4,
          '5': shadow.level5,
          '6': shadow.level6,
        }),
      );
      await tester.pumpWidget(themedHost(_modal()));
      expect(_surfaceStyle(tester).dropShadow, shadow.level4);
      await tester.pumpWidget(themedHost(_modal(), theme: theme));
      expect(_surfaceStyle(tester).dropShadow, level4);
    });

    testWidgets('us20/fr06/e05: the close button blurs its own background '
        'by the theme blur/3', (tester) async {
      await tester.pumpWidget(themedHost(_modal()));
      expect(_partStyle(tester, _close).backgroundBlur, fakeTheme.blur.level3);
    });

    testWidgets('us20/fr01/e05: with scrollBody false a list body gets the '
        'bounded height unwrapped and scrolls itself', (tester) async {
      _view(tester, const Size(390, 600));
      await tester.pumpWidget(
        themedHost(
          _modal(
            type: null,
            scrollBody: false,
            top: const Text('Top'),
            body: ListView.builder(
              itemCount: 77,
              itemBuilder: (_, index) =>
                  SizedBox(height: 40, child: Text('Row $index')),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        find.descendant(
          of: find.byType(ModalLayout),
          matching: find.byType(SingleChildScrollView),
        ),
        findsNothing,
      );
      expect(tester.getBottomLeft(_surface).dy, lessThanOrEqualTo(600));
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pump();
      expect(find.text('Row 0'), findsNothing);
      expect(find.text('Row 12'), findsOneWidget);
    });

    testWidgets('us20/fr01: the body scroll view takes the primary scroll '
        'controller under a route scope, never inline', (tester) async {
      _view(tester, _phone);
      await tester.pumpWidget(themedHost(_modal(type: null)));
      expect(_bodyScrollView(tester).primary, isFalse);
      await tester.pumpWidget(
        themedHost(
          _scoped(_modal(type: null), type: ModalLayoutType.bottomSheet),
        ),
      );
      expect(_bodyScrollView(tester).primary, isTrue);
    });

    group('route scope', () {
      testWidgets('us20/fr03: a null type takes the scope type; an own type '
          'wins', (tester) async {
        await tester.pumpWidget(themedHost(_scoped(_modal(type: null))));
        expect(_surfaceStyle(tester).borderRadius, BorderRadius.circular(38));
        expect(_surfaceStyle(tester).margin, const EdgeInsets.all(8));
        await tester.pumpWidget(themedHost(_scoped(_modal())));
        expect(_surfaceStyle(tester).borderRadius, BorderRadius.circular(24));
      });

      testWidgets('us20/fr04/e03: the scope full height gives a sheet the '
          'screen radius on top; an own false wins', (tester) async {
        const r46 = BorderRadius.all(Radius.circular(46));
        Widget sheet({bool? fullHeight}) => themedHost(
          _media(
            _scoped(
              _modal(type: null, fullHeight: fullHeight),
              type: ModalLayoutType.bottomSheet,
              fullHeight: true,
            ),
            (data) => data.applyDisplayCornerRadii(r46),
          ),
        );
        await tester.pumpWidget(sheet());
        expect(_surfaceStyle(tester).borderRadius, r46);
        await tester.pumpWidget(sheet(fullHeight: false));
        expect(
          (_surfaceStyle(tester).borderRadius! as BorderRadius).topLeft,
          const Radius.circular(40),
        );
      });

      testWidgets('us20/fr02: the close button and the handle dismiss through '
          'the scope; onClose wins', (tester) async {
        var dismissed = 0;
        var closed = 0;
        Widget sheet({VoidCallback? onClose}) => themedHost(
          _scoped(
            _modal(type: null, onClose: onClose),
            type: ModalLayoutType.bottomSheet,
            onDismiss: () => dismissed++,
          ),
        );
        await tester.pumpWidget(sheet());
        await tester.tap(_close);
        await tester.tap(_handle);
        await tester.pump();
        expect(dismissed, 2);
        await tester.pumpWidget(sheet(onClose: () => closed++));
        await tester.tap(_close);
        await tester.pump();
        expect((dismissed, closed), (2, 1));
      });

      testWidgets('NFR-U08: with no scrim the surface also shows its outline '
          'with its shadow', (tester) async {
        await tester.pumpWidget(themedHost(_modal()));
        expect(_surfaceStyle(tester).border, isNull);
        await tester.pumpWidget(
          themedHost(
            _scoped(
              _modal(),
              type: ModalLayoutType.modal,
              showBackground: false,
            ),
          ),
        );
        final style = _surfaceStyle(tester);
        expect(
          style.border,
          Border.all(
            color: fakeTheme.color.border.defaults.normal,
            width: fakeTheme.border.sm,
          ),
        );
        expect(style.dropShadow, isNotEmpty);
      });
    });

    group('accessibility gate', () {
      testWidgets('NFR-U01: text contrast and labeled tap targets pass', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          themedHost(
            _modal(
              type: ModalLayoutType.bottomSheet,
              onClose: _noop,
              body: _startBody,
            ),
          ),
        );
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });

      testWidgets('NFR-U02: Tab reaches the close button and changes its '
          'look', (tester) async {
        await tester.pumpWidget(_keyboardHost(_modal(onClose: _noop)));
        final idle = _closeRing(tester);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(_closeRing(tester), isNot(isSameColorAs(idle)));
      });

      testWidgets('NFR-U02: Tab order is top, tab, body, then the handle and '
          'the close button', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          _keyboardHost(
            _modal(
              type: ModalLayoutType.bottomSheet,
              onClose: _noop,
              top: _button('Top'),
              tab: _button('Tab'),
              body: _button('Body'),
            ),
          ),
        );
        const order = ['Top', 'Tab', 'Body', 'Dismiss', 'Close'];
        final visited = <String>[];
        for (var i = 0; i < order.length; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          visited.add(order.singleWhere((label) => _focused(tester, label)));
        }
        expect(visited, order);
        handle.dispose();
      });

      testWidgets('NFR-U04: renders at twice the text size with no '
          'overflow; the body scrolls in a short window', (tester) async {
        Widget scaled(Widget child) => themedHost(
          _media(
            child,
            (data) => data.copyWith(textScaler: const TextScaler.linear(2)),
          ),
        );
        await tester.pumpWidget(
          scaled(
            _modal(top: const Text('A title that wraps at twice the size')),
          ),
        );
        expect(tester.takeException(), isNull);
        _view(tester, const Size(390, 400));
        await tester.pumpWidget(
          scaled(
            _modal(
              type: null,
              top: const Text('Top'),
              body: ColumnLayout(
                children: [for (var i = 0; i < 20; i++) Text('Field label $i')],
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(_bodyScroll, findsOneWidget);
        await tester.drag(_bodyScroll, const Offset(0, -200));
        await tester.pump();
        expect(tester.getTopLeft(find.text('Field label 0')).dy, lessThan(0));
      });

      for (final type in [ModalLayoutType.modal, ModalLayoutType.bottomSheet]) {
        testWidgets('NFR-U05: every target of a ${type.name} meets the '
            'platform size', (tester) async {
          final handle = tester.ensureSemantics();
          await tester.pumpWidget(
            themedHost(_modal(type: type, onClose: _noop)),
          );
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          await expectLater(
            tester,
            meetsGuideline(
              const MinimumTapTargetGuideline(size: Size(24, 24), link: ''),
            ),
          );
          handle.dispose();
        });
      }

      testWidgets('NFR-U06: the close button and the handle read as labeled '
          'buttons', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          themedHost(_modal(type: ModalLayoutType.bottomSheet, onClose: _noop)),
        );
        for (final label in ['Close', 'Dismiss']) {
          expect(
            tester.getSemantics(find.bySemanticsLabel(label)),
            matchesSemantics(
              label: label,
              isButton: true,
              hasEnabledState: true,
              isEnabled: true,
              isFocusable: true,
              hasTapAction: true,
              hasFocusAction: true,
            ),
            reason: label,
          );
        }
        handle.dispose();
      });

      testWidgets('NFR-U07: text contrast passes in every bundled theme', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        final themes = [
          defaultThemeSet.light,
          defaultThemeSet.dark,
          defaultThemeSet.highContrastLight,
          defaultThemeSet.highContrastDark,
        ].nonNulls;
        for (final theme in themes) {
          await tester.pumpWidget(
            themedHost(
              _modal(onClose: _noop, body: _startBody),
              theme: theme,
            ),
          );
          await tester.pumpAndSettle();
          await expectLater(tester, meetsGuideline(textContrastGuideline));
        }
        handle.dispose();
      });

      testWidgets('NFR-U08: shown also reads as a shape: the surface draws '
          'its shadow under high contrast', (tester) async {
        await tester.pumpWidget(
          StratumThemeApplication(
            themes: defaultThemeSet,
            themeMode: ThemeMode.light,
            highContrast: StratumHighContrastMode.on,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Center(child: _modal()),
            ),
          ),
        );
        expect(_surfaceStyle(tester).dropShadow, isNotEmpty);
      });

      testWidgets('NFR-U09: the handle and the close button close by tap '
          'or key alone', (tester) async {
        var closed = 0;
        await tester.pumpWidget(
          _keyboardHost(
            _modal(type: ModalLayoutType.bottomSheet, onClose: () => closed++),
          ),
        );
        await tester.tap(_handle);
        await tester.tap(_close);
        await tester.pump();
        expect(closed, 2);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(closed, 3);
      });

      testWidgets('NFR-E01: us20/fr01/e04: the surface follows the theme', (
        tester,
      ) async {
        await tester.pumpWidget(
          themedHost(_modal(), theme: defaultThemeSet.light),
        );
        final light = _surfaceStyle(tester).backgroundColor;
        await tester.pumpWidget(
          themedHost(_modal(), theme: defaultThemeSet.dark),
        );
        final dark = _surfaceStyle(tester).backgroundColor;
        expect(light, defaultThemeSet.light.color.background.defaults.normal);
        expect(dark, isNot(light));
      });

      testWidgets('NFR-E02: a customStyle surface color shows and the shadow '
          'keeps the theme default', (tester) async {
        const red = Color(0xFFFF0000);
        await tester.pumpWidget(
          themedHost(
            _modal(
              style: const ModalLayoutStyle(
                surface: WidgetStyle(backgroundColor: red),
              ),
            ),
          ),
        );
        expect(_surfaceStyle(tester).backgroundColor, red);
        expect(_surfaceStyle(tester).dropShadow, fakeTheme.shadow.level4);
      });
    });
  });
}
