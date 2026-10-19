import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/layout/modal_layout.dart'
    show
        ModalLayoutScope,
        modalContentWidth,
        modalCorners,
        resolveModalLayoutType;
import 'package:stratum_ui/src/src.dart';

import '../fakes/fake_stratum_theme.dart';

// NFR-U03 has no row in the `ModalLayout` group: the modal layout itself
// moves and resizes nothing. The route's enter, exit, and snap motion
// rows sit in the `showModalLayout` group (layout s03 inv. 73 and 74).

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

/// The handle pill, found by its Figma size, whether or not it has an
/// action and a label.
Finder get _pill => find.byWidgetPredicate(
  (widget) =>
      widget is ContainerLayout &&
      widget.style?.width == 36 &&
      widget.style?.height == 4,
);

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

const _desktop = Size(1400, 900);

/// A page whose `Open` button shows a modal layout and keeps its result,
/// beside a `Page button` that counts its taps.
class _Opener extends StatefulWidget {
  const new({
    this.type,
    this.showBackground = true,
    this.semanticsLabel,
    this.body,
    this.scrollBody = true,
    this.useRootNavigator = true,
  });

  final ModalLayoutType? type;
  final bool showBackground;
  final String? semanticsLabel;

  /// The modal layout's body; null shows a `Choose A` button that closes
  /// it with `เลือก A`.
  final Widget? body;

  final bool scrollBody;
  final bool useRootNavigator;

  @override
  State<_Opener> createState() => _OpenerState();
}

class _OpenerState extends State<_Opener> {
  Object? result = 'none';
  int pageTaps = 0;

  Future<void> _open() async {
    final value = await showModalLayout<String>(
      context,
      type: widget.type,
      showBackground: widget.showBackground,
      semanticsLabel: widget.semanticsLabel,
      useRootNavigator: widget.useRootNavigator,
      builder: (c) => ModalLayout(
        scrollBody: widget.scrollBody,
        body:
            widget.body ??
            TextButton(
              onPressed: () => Navigator.pop(c, 'เลือก A'),
              child: const Text('Choose A'),
            ),
      ),
    );
    if (mounted) setState(() => result = value);
  }

  @override
  Widget build(BuildContext context) => ColumnLayout(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextButton(onPressed: _open, child: const Text('Open')),
      TextButton(onPressed: () => pageTaps++, child: const Text('Page button')),
    ],
  );
}

/// [home] in a `MaterialApp` under [theme], else [fakeTheme], with the
/// view's media data edited by [media], in [locale], else English.
Widget _app(
  Widget home, {
  StratumThemeData? theme,
  MediaQueryData Function(MediaQueryData data)? media,
  Locale locale = const Locale('en'),
}) => MaterialApp(
  locale: locale,
  supportedLocales: const [Locale('en'), Locale('th')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  builder: (context, child) {
    final app = StratumThemeApplication(
      themes: StratumThemeSet(light: theme ?? fakeTheme),
      themeMode: ThemeMode.light,
      child: child!,
    );
    return media == null
        ? app
        : MediaQuery(data: media(MediaQuery.of(context)), child: app);
  },
  home: Scaffold(body: home),
);

/// Pumps [_app] in a test view [size] logical pixels large: a sized view,
/// never an outer `MediaQuery`, so the route reads the view's insets and
/// the app's own media edits (P2).
Future<void> _pumpApp(
  WidgetTester tester,
  Widget home, {
  Size size = _phone,
  StratumThemeData? theme,
  MediaQueryData Function(MediaQueryData data)? media,
}) async {
  _view(tester, size);
  await tester.pumpWidget(_app(home, theme: theme, media: media));
}

_OpenerState _opener(WidgetTester tester) =>
    tester.state<_OpenerState>(find.byType(_Opener));

/// Taps `Open` and lets the route settle.
Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

/// The top edge of the shown modal layout.
double _top(WidgetTester tester) =>
    tester.getTopLeft(find.byType(ModalLayout)).dy;

/// The scrim box `showModalLayout` draws beside the route's barrier.
Finder get _scrim => find.descendant(
  of: find.ancestor(
    of: find.byType(ModalBarrier),
    matching: find.byType(StackLayout),
  ),
  matching: find.byType(ContainerLayout),
);

/// A body box [height] logical pixels tall.
Widget _tall(double height) =>
    ContainerLayout(style: WidgetStyle(height: height));

/// Drags the shown sheet by [dy] from near its top, which stays on screen
/// at half height, in slow steps, then holds still before lifting, so the
/// release carries no fling velocity.
Future<void> _slowDrag(WidgetTester tester, double dy) async {
  final gesture = await tester.startGesture(
    tester.getTopLeft(find.byType(ModalLayout)) + const Offset(40, 24),
  );
  const steps = 10;
  for (var i = 0; i < steps; i++) {
    await gesture.moveBy(Offset(0, dy / steps));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await tester.pump(const Duration(milliseconds: 100));
  await gesture.up();
}

void main() {
  group('rules', () {
    test('fo06/us20/fr03/e01: no type below tablet is a bottom sheet', () {
      expect(
        resolveModalLayoutType(null, WindowSize.mobile),
        ModalLayoutType.bottomSheet,
      );
    });
    test('fo06/us20/fr03/e02: no type at tablet and up is a modal', () {
      expect(
        resolveModalLayoutType(null, WindowSize.tablet),
        ModalLayoutType.modal,
      );
      expect(
        resolveModalLayoutType(null, WindowSize.bigDesktop),
        ModalLayoutType.modal,
      );
    });
    test('fo06/us20/fr03: a set type wins over the window size', () {
      expect(
        resolveModalLayoutType(ModalLayoutType.floating, WindowSize.desktop),
        ModalLayoutType.floating,
      );
    });
    test('fo06/us20/fr03: content widths by size', () {
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
    test('fo06/us20/fr03/e03: a sheet below tablet takes the full width', () {
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
    test('fo06/us20/fr04: a floating sheet below tablet sits 8 px in from each '
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
    test(
      'fo06/us20/fr03/e05: a medium modal on a 390 px window clamps to 350',
      () {
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
      },
    );
    test(
      'fo06/us20/fr03: every width clamps to the window less both margins',
      () {
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
      },
    );

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
    test('fo06/us20/fr04/e01: a sheet on a 40 px screen radius', () {
      expect(corners(ModalLayoutType.bottomSheet, r40), r40);
    });
    test('fo06/us20/fr04/e02: a sheet with the radius unknown', () {
      expect(
        corners(ModalLayoutType.bottomSheet, null),
        const BorderRadius.vertical(top: Radius.circular(40)),
      );
    });
    test('fo06/us20/fr04/e03: a full-height sheet takes the screen radius on '
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
    test(
      'fo06/us20/fr04/e04: floating is the screen radius less 8, else 38',
      () {
        expect(
          corners(ModalLayoutType.floating, r46),
          const BorderRadius.all(Radius.circular(38)),
        );
        expect(
          corners(ModalLayoutType.floating, null),
          const BorderRadius.all(Radius.circular(38)),
        );
      },
    );
    test(
      'fo06/us20/fr04/e05: a modal takes card-large whatever the screen',
      () {
        expect(
          corners(ModalLayoutType.modal, r46),
          const BorderRadius.all(Radius.circular(24)),
        );
      },
    );
  });

  group('ModalLayout', () {
    testWidgets('fo06/us20/fr01/e01: null top and tab do not show', (
      tester,
    ) async {
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

    testWidgets('fo06/us20/fr01: top, tab, body in that order', (tester) async {
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

    testWidgets(
      'fo06/us20/fr01/e02: showClose hides or shows the close button',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          themedHost(_modal(showClose: false, onClose: _noop)),
        );
        expect(find.bySemanticsLabel('Close'), findsNothing);
        await tester.pumpWidget(themedHost(_modal(onClose: _noop)));
        expect(find.bySemanticsLabel('Close'), findsOneWidget);
        handle.dispose();
      },
    );

    testWidgets('NFR-U06: fo06/us20/fr01/e06: inline with no onClose, no close '
        'button shows and the handle is decoration that a screen reader and '
        'Tab skip', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _keyboardHost(
          _modal(type: ModalLayoutType.bottomSheet, body: _button('Body')),
        ),
      );
      expect(find.byIcon(Icons.close), findsNothing);
      expect(find.bySemanticsLabel('Close'), findsNothing);
      expect(find.bySemanticsLabel('Dismiss'), findsNothing);
      expect(_pill, findsOneWidget);
      for (var i = 0; i < 2; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(_focused(tester, 'Body'), isTrue, reason: 'Tab ${i + 1}');
      }
      handle.dispose();
    });

    testWidgets('fo06/us20/fr01/e03: inline with an onClose, the close button '
        'and the handle call it', (tester) async {
      var closed = 0;
      await tester.pumpWidget(
        themedHost(
          _modal(type: ModalLayoutType.bottomSheet, onClose: () => closed++),
        ),
      );
      await tester.tap(_close);
      await tester.tap(_handle);
      await tester.pump();
      expect(closed, 2);
      expect(
        find.descendant(
          of: find.byType(ModalLayout),
          matching: find.byType(ModalBarrier),
        ),
        findsNothing,
      );
    });

    testWidgets(
      'fo06/us20/fr01/e03: inline in a scrolling page, it sizes to its '
      'content',
      (tester) async {
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
      },
    );

    testWidgets('fo06/us20/fr03/e01: no type on a phone is a full-width bottom '
        'sheet with a handle', (tester) async {
      _view(tester, _phone);
      await tester.pumpWidget(themedHost(_modal(type: null)));
      expect(_surfaceStyle(tester).width, 390);
      expect(_pill, findsOneWidget);
    });

    testWidgets(
      'fo06/us20/fr03/e02: no type on a tablet is a 400 px modal with '
      'no handle',
      (tester) async {
        await tester.pumpWidget(themedHost(_modal(type: null)));
        expect(tester.getSize(_surface).width, 400);
        expect(_surfaceStyle(tester).borderRadius, BorderRadius.circular(24));
        expect(_pill, findsNothing);
      },
    );

    testWidgets('fo06/us20/fr03/e05: a medium modal on a 390 px window draws '
        '350 px', (tester) async {
      _view(tester, _phone);
      await tester.pumpWidget(themedHost(_modal()));
      expect(tester.getSize(_surface).width, 350);
    });

    testWidgets(
      'fo06/us20/fr04: a floating sheet on a phone opens 8 px in from '
      'the screen edges with concentric corners',
      (tester) async {
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
      },
    );

    testWidgets('fo06/us20/fr04/e06: an app borderRadius wins', (tester) async {
      const r12 = BorderRadius.all(Radius.circular(12));
      await tester.pumpWidget(
        themedHost(_modal(type: ModalLayoutType.bottomSheet, radius: r12)),
      );
      expect(_surfaceStyle(tester).borderRadius, r12);
    });

    testWidgets(
      'fo06/us20/fr04: the app-wide parts style beats the corner rule, '
      'borderRadius beats it, and customStyle beats both',
      (tester) async {
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
      },
    );

    testWidgets('fo06/us20/fr01: the surface pads by type and size from the '
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

    testWidgets(
      'fo06/us20/fr05/e01: a bottom sheet keeps its content above the '
      'home indicator; e02: at full height, below the status bar',
      (tester) async {
        _view(tester, _phone);
        const insets = EdgeInsets.only(top: 47, bottom: 34);
        Widget sheet({bool? fullHeight}) => themedHost(
          _media(
            _modal(type: ModalLayoutType.bottomSheet, fullHeight: fullHeight),
            (data) => data.copyWith(padding: insets),
          ),
        );
        await tester.pumpWidget(sheet());
        expect(
          _surfaceStyle(tester).padding,
          const EdgeInsets.only(bottom: 34),
        );
        await tester.pumpWidget(sheet(fullHeight: true));
        expect(_surfaceStyle(tester).padding, insets);
      },
    );

    testWidgets('fo06/us20/fr05: a modal adds no inset by default; e03: with '
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

    testWidgets('fo06/us20/fr06/e03: the surface draws the theme shadow/4', (
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

    testWidgets('fo06/us20/fr06/e05: the close button blurs its own background '
        'by the theme blur/3', (tester) async {
      await tester.pumpWidget(themedHost(_modal(onClose: _noop)));
      expect(_partStyle(tester, _close).backgroundBlur, fakeTheme.blur.level3);
    });

    testWidgets(
      'fo06/us20/fr01/e05: with scrollBody false a list body gets the '
      'bounded height unwrapped and scrolls itself',
      (tester) async {
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
      },
    );

    testWidgets('fo06/us20/fr01: the body scroll view takes the primary scroll '
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
      testWidgets(
        'fo06/us20/fr03: a null type takes the scope type; an own type '
        'wins',
        (tester) async {
          await tester.pumpWidget(themedHost(_scoped(_modal(type: null))));
          expect(_surfaceStyle(tester).borderRadius, BorderRadius.circular(38));
          expect(_surfaceStyle(tester).margin, const EdgeInsets.all(8));
          await tester.pumpWidget(themedHost(_scoped(_modal())));
          expect(_surfaceStyle(tester).borderRadius, BorderRadius.circular(24));
        },
      );

      testWidgets('fo06/us20/fr04/e03: the scope full height gives a sheet the '
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

      testWidgets(
        'fo06/us20/fr02: the close button and the handle dismiss through '
        'the scope; onClose wins',
        (tester) async {
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
        },
      );

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

      testWidgets(
        'NFR-E01: fo06/us20/fr01/e04: the surface follows the theme',
        (tester) async {
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
        },
      );

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

  group('showModalLayout', () {
    testWidgets(
      'fo06/us20/s1: fo06/us20/fr02/e01: a choice completes the future with '
      'its value',
      (tester) async {
        await _pumpApp(tester, const _Opener());
        await _open(tester);
        await tester.tap(find.text('Choose A'));
        await tester.pumpAndSettle();
        expect(_opener(tester).result, 'เลือก A');
        expect(find.byType(ModalLayout), findsNothing);
      },
    );

    testWidgets(
      'fo06/us20/s6: fo06/us20/fr02/e02: Esc completes with null and focus '
      'returns to the opener',
      (tester) async {
        await _pumpApp(tester, const _Opener(), size: _desktop);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final opener = Focus.of(tester.element(find.text('Open')));
        expect(FocusManager.instance.primaryFocus, opener);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.byType(ModalLayout), findsOneWidget);
        expect(FocusManager.instance.primaryFocus, isNot(opener));
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byType(ModalLayout), findsNothing);
        expect(_opener(tester).result, isNull);
        expect(FocusManager.instance.primaryFocus, opener);
      },
    );

    for (final type in [ModalLayoutType.modal, ModalLayoutType.bottomSheet]) {
      testWidgets(
        'NFR-U02: fo06/us20/fr02/e03: Tab and Shift+Tab stay inside a '
        '${type.name}',
        (tester) async {
          await _pumpApp(tester, _Opener(type: type), size: _desktop);
          await _open(tester);
          Future<void> expectInside() async {
            await tester.pump();
            final focused = FocusManager.instance.primaryFocus!.context!;
            expect(
              find.descendant(
                of: find.byType(ModalLayout),
                matching: find.byWidget(focused.widget),
              ),
              findsOneWidget,
            );
          }

          for (var i = 0; i < 5; i++) {
            await tester.sendKeyEvent(LogicalKeyboardKey.tab);
            await expectInside();
          }
          await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
          for (var i = 0; i < 5; i++) {
            await tester.sendKeyEvent(LogicalKeyboardKey.tab);
            await expectInside();
          }
          await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        },
      );
    }

    testWidgets('NFR-U06: fo06/us20/fr02/e04: a sheet route is a named scope '
        'labeled Sheet, the page behind hidden', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpApp(tester, const _Opener());
      await _open(tester);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Sheet')),
        isSemantics(label: 'Sheet', scopesRoute: true, namesRoute: true),
      );
      expect(find.semantics.byLabel('Page button'), findsNothing);
      handle.dispose();
    });

    testWidgets('NFR-U06: fo06/us20/fr02/e04: a modal route is labeled Dialog, '
        'and a semantics label overrides it', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpApp(tester, const _Opener(), size: _desktop);
      await _open(tester);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Dialog')),
        isSemantics(label: 'Dialog', scopesRoute: true, namesRoute: true),
      );
      expect(find.semantics.byLabel('Page button'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      await _pumpApp(
        tester,
        const _Opener(semanticsLabel: 'Pick a plan'),
        size: _desktop,
      );
      await _open(tester);
      expect(find.bySemanticsLabel('Pick a plan'), findsOneWidget);
      expect(find.bySemanticsLabel('Dialog'), findsNothing);
      handle.dispose();
    });

    testWidgets('NFR-U06: fo06/us20/fr06/e01: with no background the page '
        'behind stays hidden from a screen reader', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpApp(tester, const _Opener(showBackground: false));
      await _open(tester);
      expect(find.semantics.byLabel('Page button'), findsNothing);
      handle.dispose();
    });

    final reducers = <String, Future<void> Function(WidgetTester tester)>{
      'app disableAnimations': (tester) => _pumpApp(
        tester,
        const _Opener(type: ModalLayoutType.bottomSheet),
        media: (data) => data.copyWith(disableAnimations: true),
      ),
      'platform reduceMotion': (tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(reduceMotion: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        await _pumpApp(
          tester,
          const _Opener(type: ModalLayoutType.bottomSheet),
        );
      },
    };
    for (final MapEntry(key: reason, value: pump) in reducers.entries) {
      testWidgets(
        'NFR-U03: fo06/us20/s7: fo06/us20/fr02/e05: under $reason a sheet '
        'fades in with no slide',
        (tester) async {
          await pump(tester);
          await tester.tap(find.text('Open'));
          await tester.pump();
          await tester.pump();
          final atOnce = tester.getRect(find.byType(ModalLayout));
          final fades = tester
              .widgetList<FadeTransition>(
                find.ancestor(
                  of: find.byType(ModalLayout),
                  matching: find.byType(FadeTransition),
                ),
              )
              .map((fade) => fade.opacity.value);
          expect(fades.any((opacity) => opacity < 1), isTrue);
          await tester.pumpAndSettle();
          expect(tester.getRect(find.byType(ModalLayout)), atOnce);
        },
      );

      testWidgets('NFR-U03: fo06/us20/fr07/e03: under $reason a drag that ends '
          'short of dismissal jumps to the resting height', (tester) async {
        await pump(tester);
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final height = tester.getSize(find.byType(ModalLayout)).height;
        final full = _top(tester);
        await _slowDrag(tester, height * 0.4);
        await tester.pump();
        expect(_top(tester), closeTo(full + height / 2, 1));
      });
    }

    testWidgets('fo06/us20/fr02: a sheet slides in over the normal level and '
        'settles at its end', (tester) async {
      await _pumpApp(tester, const _Opener(type: ModalLayoutType.bottomSheet));
      await tester.tap(find.text('Open'));
      await tester.pump();
      final normal = fakeTheme.animation.normal.duration!;
      await tester.pump(normal ~/ 2);
      final midway = _top(tester);
      await tester.pump(normal ~/ 2);
      final settled = _top(tester);
      await tester.pumpAndSettle();
      expect(midway, greaterThan(settled));
      expect(_top(tester), settled);
    });

    testWidgets('fo06/us20/fr02/e06: back closes the modal with null and the '
        'page stays', (tester) async {
      await _pumpApp(tester, const _Opener());
      await _open(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(ModalLayout), findsNothing);
      expect(find.text('Open'), findsOneWidget);
      expect(_opener(tester).result, isNull);
    });

    testWidgets(
      'fo06/us20/s8: fo06/us20/fr06/e01: with no background a page tap does '
      'not act, closes the modal, and no scrim draws',
      (tester) async {
        await _pumpApp(
          tester,
          const _Opener(showBackground: false),
          size: _desktop,
        );
        await _open(tester);
        expect(_scrim, findsNothing);
        await tester.tapAt(tester.getCenter(find.text('Page button')));
        await tester.pumpAndSettle();
        expect(_opener(tester).pageTaps, 0);
        expect(find.byType(ModalLayout), findsNothing);
        expect(_opener(tester).result, isNull);
      },
    );

    testWidgets(
      'NFR-U09: fo06/us20/fr06/e04: the scrim reads Dismiss and a tap '
      'closes with no drag',
      (tester) async {
        final handle = tester.ensureSemantics();
        await _pumpApp(tester, const _Opener(), size: _desktop);
        await _open(tester);
        expect(find.bySemanticsLabel('Dismiss'), findsOneWidget);
        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();
        expect(find.byType(ModalLayout), findsNothing);
        expect(_opener(tester).result, isNull);
        handle.dispose();
      },
    );

    testWidgets(
      'fo06/us20/fr06: the scrim draws normal-inverse at opacity.scrim '
      'with the blur/1 token',
      (tester) async {
        await _pumpApp(tester, const _Opener());
        await _open(tester);
        final style = tester.widget<ContainerLayout>(_scrim).style!;
        expect(
          style.backgroundColor,
          fakeTheme.color.background.defaults.normalInverse.withValues(
            alpha: fakeTheme.opacity.scrim,
          ),
        );
        expect(style.backgroundBlur, fakeTheme.blur.level1);
      },
    );

    testWidgets('NFR-E01: fo06/us20/fr06/e02: e06: a theme with another blur/1 '
        'and opacity.scrim restyles the open scrim', (tester) async {
      final blur = fakeTheme.blur;
      final other = fakeTheme.copyWith(
        opacity: StratumOpacityTokens.fromMap({
          'disabled': fakeTheme.opacity.disabled,
          'scrim': 0.25,
        }),
        blur: StratumBlurTokens.fromMap({
          '1': const ImageBlurFilter(sigmaX: 9, sigmaY: 9),
          '2': blur.level2,
          '3': blur.level3,
          '4': blur.level4,
          '5': blur.level5,
          '6': blur.level6,
        }),
      );
      await _pumpApp(tester, const _Opener());
      await _open(tester);
      await tester.pumpWidget(_app(const _Opener(), theme: other));
      await tester.pumpAndSettle();
      final style = tester.widget<ContainerLayout>(_scrim).style!;
      expect(style.backgroundColor!.a, closeTo(0.25, 0.01));
      expect(style.backgroundBlur, const ImageBlurFilter(sigmaX: 9, sigmaY: 9));
    });

    testWidgets('NFR-E01: a theme switch restyles the open modal and its '
        'scrim', (tester) async {
      await _pumpApp(
        tester,
        const _Opener(type: ModalLayoutType.modal),
        theme: defaultThemeSet.light,
      );
      await _open(tester);
      final surface = _surfaceStyle(tester).backgroundColor;
      final scrim = tester.widget<ContainerLayout>(_scrim).style!;
      await tester.pumpWidget(
        _app(
          const _Opener(type: ModalLayoutType.modal),
          theme: defaultThemeSet.dark,
        ),
      );
      await tester.pumpAndSettle();
      expect(_surfaceStyle(tester).backgroundColor, isNot(surface));
      expect(
        tester.widget<ContainerLayout>(_scrim).style!.backgroundColor,
        isNot(scrim.backgroundColor),
      );
    });

    testWidgets('NFR-U08: fo06/us20/fr06/e01: with no background the surface '
        'draws its outline', (tester) async {
      await _pumpApp(tester, const _Opener(showBackground: false));
      await _open(tester);
      expect(_surfaceStyle(tester).border, isNotNull);
    });

    testWidgets('fo06/us20/fr07/e04: a tap on the handle dismisses the sheet', (
      tester,
    ) async {
      await _pumpApp(tester, const _Opener(type: ModalLayoutType.bottomSheet));
      await _open(tester);
      await tester.tap(_handle);
      await tester.pumpAndSettle();
      expect(find.byType(ModalLayout), findsNothing);
      expect(_opener(tester).result, isNull);
    });

    testWidgets(
      'fo06/us20/fr02: the close button dismisses through the route',
      (tester) async {
        await _pumpApp(tester, const _Opener(), size: _desktop);
        await _open(tester);
        await tester.tap(_close);
        await tester.pumpAndSettle();
        expect(find.byType(ModalLayout), findsNothing);
        expect(_opener(tester).result, isNull);
      },
    );

    testWidgets(
      'fo06/us20/fr07/e05: an SDK ListTile in a sheet builds and takes '
      'taps',
      (tester) async {
        var taps = 0;
        await _pumpApp(
          tester,
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalLayout<void>(
                context,
                type: ModalLayoutType.bottomSheet,
                builder: (_) => ModalLayout(
                  body: ListTile(
                    title: const Text('Tile'),
                    onTap: () => taps++,
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        );
        await _open(tester);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Tile'));
        expect(taps, 1);
      },
    );

    testWidgets(
      'fo06/us20/fr07/e01: a short drag up snaps to the nearer resting '
      'height over the fast level',
      (tester) async {
        await _pumpApp(tester, _Opener(body: _tall(400)));
        await _open(tester);
        final height = tester.getSize(find.byType(ModalLayout)).height;
        final full = _top(tester);
        await _slowDrag(tester, height * 0.4);
        await tester.pumpAndSettle();
        expect(_top(tester), closeTo(full + height / 2, 1));

        await _slowDrag(tester, -height * 0.35);
        await tester.pump();
        final fast = fakeTheme.animation.fast.duration!;
        await tester.pump(fast ~/ 2);
        expect(_top(tester), lessThan(full + height / 2 - 1));
        expect(_top(tester), greaterThan(full + 1));
        await tester.pump(fast ~/ 2);
        expect(_top(tester), closeTo(full, 0.5));
      },
    );

    testWidgets(
      'fo06/us20/s3: fo06/us20/fr07/e02: a drag down past the closing point '
      'dismisses with null',
      (tester) async {
        await _pumpApp(tester, _Opener(body: _tall(400)));
        await _open(tester);
        await tester.fling(
          find.byType(ModalLayout),
          const Offset(0, 400),
          3000,
        );
        await tester.pumpAndSettle();
        expect(find.byType(ModalLayout), findsNothing);
        expect(_opener(tester).result, isNull);
      },
    );

    testWidgets(
      'fo06/us20/fr07/e06: a 77-row list body at its top hands a '
      'further drag down to the sheet, on desktop too',
      (tester) async {
        await _pumpApp(
          tester,
          _Opener(
            scrollBody: false,
            body: ListView.builder(
              itemCount: 77,
              itemBuilder: (_, i) =>
                  SizedBox(height: 40, child: Text('Row $i')),
            ),
          ),
        );
        await _open(tester);
        final full = _top(tester);
        final row0 = tester.getTopLeft(find.text('Row 0')).dy;
        final gesture = await tester.startGesture(
          tester.getCenter(find.text('Row 3')),
        );
        for (var i = 0; i < 10; i++) {
          await gesture.moveBy(const Offset(0, 20));
          await tester.pump(const Duration(milliseconds: 16));
        }
        final moved = _top(tester) - full;
        expect(moved, greaterThan(100));
        expect(
          tester.getTopLeft(find.text('Row 0')).dy - row0,
          closeTo(moved, 1),
        );
        for (var i = 0; i < 20; i++) {
          await gesture.moveBy(const Offset(0, 25));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await tester.pump(const Duration(milliseconds: 100));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(find.byType(ModalLayout), findsNothing);
        expect(_opener(tester).result, isNull);
      },
      variant: const TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.macOS,
      }),
    );

    testWidgets(
      'fo06/us20/s4: fo06/us20/fr05/e04: the keyboard lifts a sheet by its '
      'height',
      (tester) async {
        tester.view.physicalSize = const Size(390 * 3, 844 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          _app(const _Opener(type: ModalLayoutType.bottomSheet)),
        );
        await _open(tester);
        final before = tester.getBottomLeft(find.byType(ModalLayout)).dy;
        tester.view.viewInsets = const FakeViewPadding(bottom: 300 * 3);
        await tester.pumpAndSettle();
        expect(
          tester.getBottomLeft(find.byType(ModalLayout)).dy,
          closeTo(before - 300, 1),
        );
      },
    );

    testWidgets('fo06/us20/fr05/e05: a centered modal moves clear of the '
        'keyboard', (tester) async {
      await _pumpApp(tester, const _Opener(), size: _desktop);
      await _open(tester);
      final centered = tester.getRect(find.byType(ModalLayout));
      tester.view.viewInsets = const FakeViewPadding(bottom: 500);
      await tester.pumpAndSettle();
      final lifted = tester.getRect(find.byType(ModalLayout));
      expect(lifted.bottom, lessThanOrEqualTo(_desktop.height - 500));
      expect(lifted.top, lessThan(centered.top));
    });

    testWidgets(
      'fo06/us20/fr05/e02: fo06/us20/fr04/e03: a sheet that reaches the '
      'status bar pads below it and takes the screen radius on top',
      (tester) async {
        const corners = BorderRadius.all(Radius.circular(46));
        MediaQueryData media(MediaQueryData data) =>
            data.applyDisplayCornerRadii(corners);
        await _pumpApp(tester, _Opener(body: _tall(2000)), media: media);
        tester.view
          ..padding = const FakeViewPadding(top: 47)
          ..viewPadding = const FakeViewPadding(top: 47);
        await _open(tester);
        expect(_top(tester), 0);
        final radius = _surfaceStyle(tester).borderRadius! as BorderRadius;
        expect(radius.topLeft, const Radius.circular(46));
        expect(tester.getTopLeft(_handle).dy, greaterThanOrEqualTo(47));
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        await _pumpApp(tester, _Opener(body: _tall(200)), media: media);
        await _open(tester);
        final short = _surfaceStyle(tester).borderRadius! as BorderRadius;
        expect(short.topLeft, const Radius.circular(40));
      },
    );

    testWidgets(
      'fo06/us20/s5: fo06/us20/fr04: a floating sheet through the call draws '
      'floating corners 8 px in from the edges',
      (tester) async {
        await _pumpApp(
          tester,
          const _Opener(type: ModalLayoutType.floating),
          media: (data) => data.applyDisplayCornerRadii(
            const BorderRadius.all(Radius.circular(46)),
          ),
        );
        await _open(tester);
        final radius = _surfaceStyle(tester).borderRadius! as BorderRadius;
        expect(radius.topLeft, const Radius.circular(38));
        expect(radius.bottomRight, const Radius.circular(38));
        final style = _surfaceStyle(tester);
        expect(style.margin, const EdgeInsets.all(8));
        expect(style.width, _phone.width - 16);
        expect(
          tester.getRect(_surface),
          Rect.fromLTRB(0, _top(tester), _phone.width, _phone.height),
        );
      },
    );

    testWidgets('fo06/us20/fr03: a bottom sheet on a desktop keeps its 400 px '
        'content width, centered', (tester) async {
      await _pumpApp(
        tester,
        const _Opener(type: ModalLayoutType.bottomSheet),
        size: _desktop,
      );
      await _open(tester);
      final rect = tester.getRect(_surface);
      expect(rect.width, 400);
      expect(rect.center.dx, _desktop.width / 2);
      expect(rect.bottom, _desktop.height);
      expect(_handle, findsOneWidget);
    });

    testWidgets(
      'fo06/us20/fr07/e08: a drag on the scrim beside a desktop bottom '
      'sheet leaves it in place; a tap there dismisses it',
      (tester) async {
        await _pumpApp(
          tester,
          _Opener(type: ModalLayoutType.bottomSheet, body: _tall(400)),
          size: _desktop,
        );
        await _open(tester);
        final rect = tester.getRect(_surface);
        final beside = Offset(rect.left - 100, rect.center.dy);
        final gesture = await tester.startGesture(beside);
        for (var i = 0; i < 12; i++) {
          await gesture.moveBy(Offset(0, rect.height / 10));
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(find.byType(ModalLayout), findsOneWidget);
        expect(_opener(tester).result, 'none');
        await gesture.up();
        await tester.pumpAndSettle();
        expect(tester.getRect(_surface), rect);
        expect(_opener(tester).result, 'none');

        await tester.tapAt(beside);
        await tester.pumpAndSettle();
        expect(find.byType(ModalLayout), findsNothing);
        expect(_opener(tester).result, isNull);
      },
    );

    for (final type in [ModalLayoutType.modal, ModalLayoutType.bottomSheet]) {
      testWidgets('NFR-U01: NFR-U05: every target of a ${type.name} route is '
          'labeled and sized', (tester) async {
        final handle = tester.ensureSemantics();
        await _pumpApp(tester, _Opener(type: type), size: _desktop);
        await _open(tester);
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
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

    final reducedPumps =
        <String, Future<void> Function(WidgetTester tester, Widget home)>{
          'app disableAnimations': (tester, home) => _pumpApp(
            tester,
            home,
            media: (data) => data.copyWith(disableAnimations: true),
          ),
          'platform reduceMotion': (tester, home) async {
            tester.platformDispatcher.accessibilityFeaturesTestValue =
                const FakeAccessibilityFeatures(reduceMotion: true);
            addTearDown(
              tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
            );
            await _pumpApp(tester, home);
          },
        };
    for (final MapEntry(key: reason, value: pump) in reducedPumps.entries) {
      testWidgets(
        'NFR-U03: fo06/us20/fr07/e03: under $reason a drag below half '
        'that ends short of dismissal jumps to half with no slide',
        (tester) async {
          await pump(tester, _Opener(body: _tall(400)));
          await _open(tester);
          final height = tester.getSize(find.byType(ModalLayout)).height;
          final full = _top(tester);
          await _slowDrag(tester, height * 0.7);
          await tester.pump();
          expect(_top(tester), closeTo(full + height / 2, 1));
          await tester.pumpAndSettle();
          expect(_top(tester), closeTo(full + height / 2, 1));
        },
      );
    }

    testWidgets('fo06/us20/fr07/e01: a drag below half that ends short of '
        'dismissal settles on half within the fast level', (tester) async {
      await _pumpApp(tester, _Opener(body: _tall(400)));
      await _open(tester);
      final height = tester.getSize(find.byType(ModalLayout)).height;
      final full = _top(tester);
      await _slowDrag(tester, height * 0.7);
      await tester.pump();
      final fast = fakeTheme.animation.fast.duration!;
      await tester.pump(fast ~/ 2);
      expect(_top(tester), greaterThan(full + height / 2 + 1));
      await tester.pump(fast ~/ 2);
      expect(_top(tester), closeTo(full + height / 2, 0.5));
    });

    testWidgets('fo06/us20/fr07/e02: a slow drag down past the closing point '
        'settles hidden and pops once with null', (tester) async {
      await _pumpApp(tester, _Opener(body: _tall(400)));
      await _open(tester);
      final height = tester.getSize(find.byType(ModalLayout)).height;
      await _slowDrag(tester, height * 0.85);
      await tester.pumpAndSettle();
      expect(find.byType(ModalLayout), findsNothing);
      expect(_opener(tester).result, isNull);
      expect(find.text('Open'), findsOneWidget);
    });

    testWidgets(
      'fo06/us20/fr07/e02: a sheet held down at the bottom edge stays '
      'until the finger lifts',
      (tester) async {
        await _pumpApp(tester, _Opener(body: _tall(400)));
        await _open(tester);
        final height = tester.getSize(find.byType(ModalLayout)).height;
        final gesture = await tester.startGesture(
          tester.getTopLeft(find.byType(ModalLayout)) + const Offset(40, 24),
        );
        for (var i = 0; i < 12; i++) {
          await gesture.moveBy(Offset(0, height / 10));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await tester.pumpAndSettle();
        expect(find.byType(ModalLayout), findsOneWidget);
        expect(_opener(tester).result, 'none');
        await gesture.up();
        await tester.pumpAndSettle();
        expect(find.byType(ModalLayout), findsNothing);
        expect(_opener(tester).result, isNull);
      },
    );

    final motions = <String, Future<void> Function(WidgetTester, Widget)>{
      'motion on': _pumpApp,
      ...reducedPumps,
    };
    for (final MapEntry(key: motion, value: pump) in motions.entries) {
      testWidgets(
        'fo06/us20/fr07/e02: with $motion a sheet a pop scope keeps open '
        'returns to full height, and the scope hears one attempt',
        (tester) async {
          var attempts = 0;
          await pump(
            tester,
            _Opener(
              body: PopScope<Object?>(
                canPop: false,
                onPopInvokedWithResult: (_, _) => attempts++,
                child: _tall(400),
              ),
            ),
          );
          await _open(tester);
          final height = tester.getSize(find.byType(ModalLayout)).height;
          final full = _top(tester);
          await _slowDrag(tester, height * 0.85);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byType(ModalLayout), findsOneWidget);
          expect(_top(tester), closeTo(full, 0.5));
          expect(attempts, 1);
        },
      );
    }

    testWidgets('fo06/us20/fr07/e02: a sheet a deprecated will-pop scope keeps '
        'open returns to full height, and the scope hears one attempt', (
      tester,
    ) async {
      var attempts = 0;
      await _pumpApp(
        tester,
        _Opener(
          // A dependent app may still refuse the pop through this
          // deprecated scope, which the route's pop disposition never reads.
          // ignore: deprecated_member_use
          body: WillPopScope(
            onWillPop: () async {
              attempts++;
              return false;
            },
            child: _tall(400),
          ),
        ),
      );
      await _open(tester);
      final height = tester.getSize(find.byType(ModalLayout)).height;
      final full = _top(tester);
      await _slowDrag(tester, height * 0.85);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(ModalLayout), findsOneWidget);
      expect(_top(tester), closeTo(full, 0.5));
      expect(attempts, 1);
    });

    testWidgets(
      'fo06/us20/fr07/e02: a sheet whose pop scope answers the refusal '
      'with a dialog is back at full height once the dialog closes',
      (tester) async {
        await _pumpApp(
          tester,
          _Opener(
            body: Builder(
              builder: (context) => PopScope<Object?>(
                canPop: false,
                onPopInvokedWithResult: (didPop, _) {
                  if (didPop) return;
                  Navigator.of(context).push(
                    RawDialogRoute<void>(
                      pageBuilder: (_, _, _) => const Text('Discard?'),
                    ),
                  );
                },
                child: _tall(400),
              ),
            ),
          ),
        );
        await _open(tester);
        final height = tester.getSize(find.byType(ModalLayout)).height;
        final full = _top(tester);
        await _slowDrag(tester, height * 0.85);
        await tester.pumpAndSettle();
        expect(find.text('Discard?'), findsOneWidget);
        tester.state<NavigatorState>(find.byType(Navigator)).pop();
        await tester.pumpAndSettle();
        expect(find.text('Discard?'), findsNothing);
        expect(find.byType(ModalLayout), findsOneWidget);
        expect(_top(tester), closeTo(full, 0.5));
        expect(_opener(tester).result, 'none');
      },
    );

    testWidgets('fo06/us20/fr07/e07: a sheet whose settle to hidden ends under '
        'another route is back at full height once that route closes', (
      tester,
    ) async {
      await _pumpApp(tester, _Opener(body: _tall(400)));
      await _open(tester);
      final height = tester.getSize(find.byType(ModalLayout)).height;
      final full = _top(tester);
      await _slowDrag(tester, height * 0.85);
      await tester.pump();
      final navigator = tester.state<NavigatorState>(find.byType(Navigator))
        ..push(
          RawDialogRoute<void>(pageBuilder: (_, _, _) => const Text('Over')),
        );
      await tester.pumpAndSettle();
      expect(find.text('Over'), findsOneWidget);
      navigator.pop();
      await tester.pumpAndSettle();
      expect(find.byType(ModalLayout), findsOneWidget);
      expect(_top(tester), closeTo(full, 0.5));
      expect(_opener(tester).result, 'none');
    });

    testWidgets('fo06/us20/fr07/e02: a sheet popped while it settles hidden '
        'leaves the page below it in place', (tester) async {
      await _pumpApp(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(body: _Opener(body: _tall(400))),
              ),
            ),
            child: const Text('Next'),
          ),
        ),
      );
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await _open(tester);
      final height = tester.getSize(find.byType(ModalLayout)).height;
      await _slowDrag(tester, height * 0.85);
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(ModalLayout), findsNothing);
      expect(find.byType(_Opener), findsOneWidget);
    });

    testWidgets(
      'fo06/us20/fr07/e02: a trackpad drag past hidden that comes back '
      'up keeps the sheet',
      (tester) async {
        await _pumpApp(tester, _Opener(body: _tall(400)));
        await _open(tester);
        final height = tester.getSize(find.byType(ModalLayout)).height;
        final point =
            tester.getTopLeft(find.byType(ModalLayout)) + const Offset(40, 24);
        final gesture = await tester.startGesture(
          point,
          kind: PointerDeviceKind.trackpad,
        );
        for (var i = 0; i < 12; i++) {
          await gesture.panZoomUpdate(
            point,
            pan: Offset(0, height * (i + 1) / 10),
          );
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(find.byType(ModalLayout), findsOneWidget);
        for (var i = 12; i >= 0; i--) {
          await gesture.panZoomUpdate(point, pan: Offset(0, height * i / 10));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await tester.pump(const Duration(milliseconds: 100));
        await gesture.panZoomEnd();
        await tester.pumpAndSettle();
        expect(find.byType(ModalLayout), findsOneWidget);
        expect(_opener(tester).result, 'none');
      },
    );

    testWidgets(
      'fo06/us20/fr06: a tap outside a sheet dismisses it with null',
      (tester) async {
        await _pumpApp(
          tester,
          const _Opener(type: ModalLayoutType.bottomSheet),
        );
        await _open(tester);
        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();
        expect(find.byType(ModalLayout), findsNothing);
        expect(_opener(tester).result, isNull);
      },
    );

    testWidgets('fo06/us20/fr02/e02: Esc dismisses a sheet with null', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        const _Opener(type: ModalLayoutType.bottomSheet),
        size: _desktop,
      );
      await _open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(ModalLayout), findsNothing);
      expect(_opener(tester).result, isNull);
    });

    testWidgets(
      'fo06/us20/fr07: a scrollBody wrapper at its top hands a further '
      'drag down to the sheet',
      (tester) async {
        await _pumpApp(tester, _Opener(body: _tall(2000)));
        await _open(tester);
        final full = _top(tester);
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(ModalLayout)),
        );
        for (var i = 0; i < 10; i++) {
          await gesture.moveBy(const Offset(0, 20));
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(_top(tester) - full, greaterThan(100));
        expect(
          tester
              .state<ScrollableState>(
                find.descendant(
                  of: find.byType(ModalLayout),
                  matching: find.byType(Scrollable),
                ),
              )
              .position
              .pixels,
          0,
        );
        await gesture.up();
        await tester.pumpAndSettle();
      },
    );

    testWidgets('fo06/us20/fr07: two body lists on a desktop each drag their '
        'scrollbar when the second takes its own controller', (tester) async {
      final own = ScrollController();
      addTearDown(own.dispose);
      Widget list(String name, {ScrollController? controller}) => Expanded(
        child: ListView.builder(
          controller: controller,
          itemCount: 77,
          itemBuilder: (_, i) => SizedBox(height: 40, child: Text('$name $i')),
        ),
      );
      await _pumpApp(
        tester,
        _Opener(
          scrollBody: false,
          body: RowLayout(
            children: [
              list('Left'),
              list('Right', controller: own),
            ],
          ),
        ),
      );
      await _open(tester);
      for (final name in ['Left', 'Right']) {
        final rect = tester.getRect(
          find.ancestor(
            of: find.text('$name 0'),
            matching: find.byType(Scrollable),
          ),
        );
        final mouse = TestPointer(1, PointerDeviceKind.mouse);
        await tester.sendEventToBinding(mouse.hover(rect.center));
        await tester.sendEventToBinding(mouse.scroll(const Offset(0, 40)));
        await tester.pumpAndSettle();
        await tester.dragFrom(
          Offset(rect.right - 3, rect.top + 20),
          const Offset(0, 40),
          kind: PointerDeviceKind.mouse,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('fo06/us20/fr06: the scrim multiplies a translucent token by '
        'opacity.scrim', (tester) async {
      final translucent = fakeTheme.copyWith(
        color: StratumColorTokens.fromMap({
          ...defaultThemeConfig.color.light,
          'background.default.normal-inverse': const Color(0x80000000),
        }),
      );
      await _pumpApp(tester, const _Opener(), theme: translucent);
      await _open(tester);
      final color = tester.widget<ContainerLayout>(_scrim).style!;
      expect(
        color.backgroundColor!.a,
        closeTo(0x80 / 0xFF * fakeTheme.opacity.scrim, 0.01),
      );
    });

    testWidgets(
      'NFR-U06: fo06/us20/fr02: an open sheet reads its built-in label '
      'in the language the app switches to',
      (tester) async {
        final handle = tester.ensureSemantics();
        await _pumpApp(tester, const _Opener());
        await _open(tester);
        expect(find.semantics.byLabel('Sheet'), findsOneWidget);
        await tester.pumpWidget(
          _app(const _Opener(), locale: const Locale('th')),
        );
        await tester.pumpAndSettle();
        expect(find.semantics.byLabel('ชีต'), findsOneWidget);
        expect(find.semantics.byLabel('Sheet'), findsNothing);
        handle.dispose();
      },
    );

    group('useRootNavigator', () {
      var tabTaps = 0;
      setUp(() => tabTaps = 0);

      /// A nested navigator showing an opener above a tab bar it does not
      /// cover.
      Widget nested({required bool root}) => ColumnLayout(
        children: [
          Expanded(
            child: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) => _Opener(useRootNavigator: root),
              ),
            ),
          ),
          TextButton(onPressed: () => tabTaps++, child: const Text('Tab bar')),
        ],
      );

      testWidgets('fo06/us20/fr02/e07: by default the route covers a tab bar '
          'outside a nested navigator', (tester) async {
        final handle = tester.ensureSemantics();
        await _pumpApp(tester, nested(root: true), size: _desktop);
        await _open(tester);
        expect(find.semantics.byLabel('Tab bar'), findsNothing);
        await tester.tapAt(tester.getCenter(find.text('Tab bar')));
        await tester.pumpAndSettle();
        expect(tabTaps, 0);
        expect(find.byType(ModalLayout), findsNothing);
        handle.dispose();
      });

      testWidgets('fo06/us20/fr02/e07: useRootNavigator false keeps the route '
          'inside the nearest navigator', (tester) async {
        final handle = tester.ensureSemantics();
        await _pumpApp(tester, nested(root: false), size: _desktop);
        await _open(tester);
        expect(find.semantics.byLabel('Tab bar'), findsOneWidget);
        await tester.tap(find.text('Tab bar'));
        await tester.pumpAndSettle();
        expect(tabTaps, 1);
        expect(find.byType(ModalLayout), findsOneWidget);
        handle.dispose();
      });
    });
  });
}
