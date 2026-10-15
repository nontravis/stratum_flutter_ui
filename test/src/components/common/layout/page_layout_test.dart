import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/l10n/built_in_labels.dart';
import 'package:stratum_ui/src/src.dart';

import '../fakes/fake_stratum_theme.dart';

// NFR-U05 n/a: the page draws no target of its own; the loading layer
// covers the whole page, and each slot's children carry their own targets.
// NFR-U09 n/a: the page itself takes no gesture; the drawers and side panes
// it holds answer theirs under US-19 (M3-T19, M3-T20).

const _desktop = Size(1400, 900);
const _phone = Size(390, 844);
const _landscape = Size(844, 390);

/// A slot 40 px tall that shows [name].
Widget _slot(String name) => SizedBox(height: 40, child: Text(name));

/// A controller whose chosen inline pane widths are [left] and [right],
/// disposed after the test.
PageLayoutController _widths({double? left, double? right}) {
  final controller = PageLayoutController(leftWidth: left, rightWidth: right);
  addTearDown(controller.dispose);
  return controller;
}

/// A test view [size] logical pixels large with [padding] as its system
/// insets and a keyboard [keyboard] px tall, reset after the test.
void _view(
  WidgetTester tester, {
  Size size = _desktop,
  FakeViewPadding padding = FakeViewPadding.zero,
  double keyboard = 0,
}) {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1
    ..padding = padding
    ..viewPadding = padding
    ..viewInsets = FakeViewPadding(bottom: keyboard);
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
  Map<Type, Object> parts = const {},
  bool highContrast = false,
}) => StratumThemeApplication(
  themes: highContrast
      ? defaultThemeSet
      : StratumThemeSet(light: theme ?? fakeTheme),
  themeMode: ThemeMode.light,
  highContrast: highContrast
      ? StratumHighContrastMode.on
      : StratumHighContrastMode.system,
  componentPartDefaults: (_) => parts,
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

Rect _rect(WidgetTester tester, String name) => tester.getRect(find.text(name));

/// The fill box of the slot that shows [name]: its nearest
/// `ContainerLayout`.
Finder _fill(String name) => find
    .ancestor(of: find.text(name), matching: find.byType(ContainerLayout))
    .first;

WidgetStyle _style(WidgetTester tester, String name) =>
    tester.widget<ContainerLayout>(_fill(name)).style!;

/// The page's own box: the first `ContainerLayout` under the page layout.
Finder get _outer => find
    .descendant(
      of: find.byType(PageLayout).first,
      matching: find.byType(ContainerLayout),
    )
    .first;

Finder get _loading => find.bySemanticsLabel('Loading');

/// The opacity the loading layer's fade reaches this frame.
double _opacity(WidgetTester tester) => tester
    .widget<FadeTransition>(
      find.descendant(
        of: find.byType(PageLayout),
        matching: find.byType(FadeTransition),
      ),
    )
    .opacity
    .value;

/// A body text only as large as its glyphs: a full-body text node's rect,
/// grown by the guideline's 4 px margin, would sample the header fill
/// beside it and hide the body's own contrast (NFR-U01, NFR-U07).
const _centerBody = Center(child: Text('Body'));

/// A body button `Act` that counts its taps in [taps].
Widget _act(List<int> taps, {FocusNode? node}) => TextButton(
  focusNode: node,
  onPressed: () => taps.add(1),
  child: const Text('Act'),
);

void main() {
  group('PageLayout geometry', () {
    testWidgets(
      'fo06/us18/s1: fo06/us18/fr01: header on top, left full height, top '
      'over body, footer at the end',
      (tester) async {
        _view(tester);
        await tester.pumpWidget(
          _host(
            PageLayout(
              controller: _widths(left: 200),
              header: _slot('header'),
              left: const Text('left'),
              top: _slot('top'),
              body: const Text('body'),
              footer: _slot('footer'),
            ),
          ),
        );
        expect(_rect(tester, 'header'), const Rect.fromLTRB(0, 0, 1400, 40));
        expect(_rect(tester, 'left'), const Rect.fromLTRB(0, 40, 200, 860));
        expect(_rect(tester, 'top'), const Rect.fromLTRB(200, 40, 1400, 80));
        expect(_rect(tester, 'body'), const Rect.fromLTRB(200, 80, 1400, 860));
        expect(_rect(tester, 'footer'), const Rect.fromLTRB(0, 860, 1400, 900));
      },
    );

    testWidgets(
      'fo06/us18/s2: fo06/us18/fr01/e01: with every other slot null the '
      'body fills the page',
      (tester) async {
        _view(tester);
        await tester.pumpWidget(
          _host(const PageLayout(body: SizedBox.expand(key: Key('b')))),
        );
        expect(
          tester.getRect(find.byKey(const Key('b'))),
          Offset.zero & _desktop,
        );
      },
    );

    testWidgets('fo06/us18/fr01/e02: with left null the main column takes the '
        'full width', (tester) async {
      _view(tester);
      await tester.pumpWidget(
        _host(
          PageLayout(
            header: _slot('header'),
            top: _slot('top'),
            body: const Text('body'),
          ),
        ),
      );
      expect(_rect(tester, 'top'), const Rect.fromLTRB(0, 40, 1400, 80));
      expect(_rect(tester, 'body'), const Rect.fromLTRB(0, 80, 1400, 900));
    });

    testWidgets('fo06/us18/fr01/e03: with top null tab and right start under '
        'the header', (tester) async {
      _view(tester);
      await tester.pumpWidget(
        _host(
          PageLayout(
            controller: _widths(right: 300),
            header: _slot('header'),
            tab: _slot('tab'),
            right: const Text('right'),
            body: const Text('body'),
          ),
        ),
      );
      expect(_rect(tester, 'tab'), const Rect.fromLTRB(0, 40, 1100, 80));
      expect(_rect(tester, 'right').top, 40);
      expect(_rect(tester, 'body'), const Rect.fromLTRB(0, 80, 1100, 900));
    });

    testWidgets(
      'fo06/us18/fr01/e04: with right set and top null right runs from '
      'under the header to above the footer',
      (tester) async {
        _view(tester);
        await tester.pumpWidget(
          _host(
            PageLayout(
              controller: _widths(right: 300),
              header: _slot('header'),
              right: const Text('right'),
              body: const Text('body'),
              bottom: _slot('bottom'),
              footer: _slot('footer'),
            ),
          ),
        );
        expect(
          _rect(tester, 'right'),
          const Rect.fromLTRB(1100, 40, 1400, 860),
        );
        expect(_rect(tester, 'bottom'), const Rect.fromLTRB(0, 820, 1100, 860));
      },
    );

    testWidgets('fo06/us18/fr01/e04: top spans the center column and right, '
        'which starts under it', (tester) async {
      _view(tester);
      await tester.pumpWidget(
        _host(
          PageLayout(
            controller: _widths(right: 300),
            top: _slot('top'),
            tab: _slot('tab'),
            right: const Text('right'),
            body: const Text('body'),
          ),
        ),
      );
      expect(_rect(tester, 'top'), const Rect.fromLTRB(0, 0, 1400, 40));
      expect(_rect(tester, 'right'), const Rect.fromLTRB(1100, 40, 1400, 900));
      expect(_rect(tester, 'tab'), const Rect.fromLTRB(0, 40, 1100, 80));
    });

    testWidgets('fo06/us18/fr01/e05: under RTL left sits on the right edge and '
        'right on the left edge', (tester) async {
      _view(tester);
      await tester.pumpWidget(
        _host(
          PageLayout(
            controller: _widths(left: 200, right: 300),
            left: const Text('left'),
            right: const Text('right'),
            body: const Text('body'),
          ),
          direction: TextDirection.rtl,
        ),
      );
      expect(_rect(tester, 'left'), const Rect.fromLTRB(1200, 0, 1400, 900));
      expect(_rect(tester, 'right'), const Rect.fromLTRB(0, 0, 300, 900));
    });

    testWidgets('fo06/us18/fr01/e06: snack floats at the bottom center and the '
        'body keeps its size', (tester) async {
      _view(tester);
      await tester.pumpWidget(
        _host(const PageLayout(body: SizedBox.expand(key: Key('b')))),
      );
      final alone = tester.getRect(find.byKey(const Key('b')));
      await tester.pumpWidget(
        _host(
          const PageLayout(
            body: SizedBox.expand(key: Key('b')),
            snack: SizedBox(width: 100, height: 48, child: Text('snack')),
          ),
        ),
      );
      expect(tester.getRect(find.byKey(const Key('b'))), alone);
      expect(_rect(tester, 'snack'), const Rect.fromLTRB(650, 852, 750, 900));
    });

    testWidgets('Q36: snack sits above the bottom inset and the keyboard', (
      tester,
    ) async {
      const snack = SizedBox(width: 100, height: 48, child: Text('snack'));
      _view(tester, size: _phone, padding: const FakeViewPadding(bottom: 34));
      await tester.pumpWidget(
        _host(const PageLayout(body: Text('b'), snack: snack)),
      );
      expect(_rect(tester, 'snack').bottom, 844 - 34);
      _view(tester, size: _phone, keyboard: 300);
      await tester.pumpWidget(
        _host(const PageLayout(body: Text('b'), snack: snack)),
      );
      expect(_rect(tester, 'snack').bottom, 844 - 300);
    });

    testWidgets('Q17: a slot hosts a Material widget and draws its text '
        'and ink on the slot fill with no Scaffold', (tester) async {
      _view(tester);
      await tester.pumpWidget(
        _host(
          PageLayout(
            header: const Text('Header'),
            body: ListTile(title: const Text('Row'), onTap: () {}),
          ),
          theme: defaultThemeSet.light,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        DefaultTextStyle.of(tester.element(find.text('Header'))).style.color,
        defaultThemeSet.light.color.text.defaults.primary,
      );
      // The ink surface of the row sits inside the body fill, so a splash
      // paints over the fill, not under it.
      expect(
        find.descendant(
          of: _fill('Row'),
          matching: find.ancestor(
            of: find.text('Row'),
            matching: find.byType(Material),
          ),
        ),
        findsWidgets,
      );
    });
  });

  group('PageLayout insets', () {
    const statusBar = FakeViewPadding(top: 44, bottom: 34);

    testWidgets(
      'fo06/us18/s3: fo06/us18/fr04: the header pads by the top inset while '
      'its fill runs under it',
      (tester) async {
        _view(tester, size: _phone, padding: statusBar);
        await tester.pumpWidget(
          _host(PageLayout(header: _slot('header'), body: const Text('b'))),
        );
        expect(_rect(tester, 'header').top, 44);
        expect(tester.getRect(_fill('header')).top, 0);
        expect(tester.getTopLeft(find.byType(PageLayout)).dy, 0);
      },
    );

    testWidgets('fo06/us18/fr04/e01: with header null top pads by the top '
        'inset', (tester) async {
      _view(tester, size: _phone, padding: statusBar);
      await tester.pumpWidget(
        _host(PageLayout(top: _slot('top'), body: const Text('b'))),
      );
      expect(_rect(tester, 'top').top, 44);
      expect(tester.getRect(_fill('top')).top, 0);
    });

    testWidgets(
      'fo06/us18/s3: fo06/us18/fr04/e02: a body list scrolls under the home '
      'indicator and its last row scrolls clear of it',
      (tester) async {
        _view(tester, size: _phone, padding: statusBar);
        late EdgeInsets bodyPadding;
        await tester.pumpWidget(
          _host(
            PageLayout(
              header: _slot('header'),
              body: Builder(
                builder: (context) {
                  bodyPadding = MediaQuery.paddingOf(context);
                  return ListView(
                    children: [
                      for (var i = 0; i < 30; i++)
                        SizedBox(height: 50, child: Text('row $i')),
                    ],
                  );
                },
              ),
            ),
          ),
        );
        expect(bodyPadding, const EdgeInsets.only(bottom: 34));
        expect(tester.getRect(_fill('row 0')).bottom, 844);
        await tester.drag(find.byType(ListView), const Offset(0, -5000));
        await tester.pumpAndSettle();
        expect(_rect(tester, 'row 29').bottom, 844 - 34);
      },
    );

    testWidgets(
      'R20: fo06/us18/fr04/e03: safeArea top false drops the top padding '
      "of every slot, while the top slot's children keep the inset to pad "
      'themselves',
      (tester) async {
        _view(tester, size: _phone, padding: statusBar);
        late EdgeInsets headerPadding;
        late EdgeInsets topPadding;
        await tester.pumpWidget(
          _host(
            PageLayout(
              header: Builder(
                builder: (context) {
                  headerPadding = MediaQuery.paddingOf(context);
                  return _slot('header');
                },
              ),
              top: Builder(
                builder: (context) {
                  topPadding = MediaQuery.paddingOf(context);
                  return _slot('top');
                },
              ),
              safeArea: const PageSafeArea(top: false),
              body: const Text('b'),
            ),
          ),
        );
        expect(_rect(tester, 'header').top, 0);
        expect(headerPadding.top, 44);
        expect(topPadding.top, 0);
      },
    );

    testWidgets(
      'R20: fo06/us18/fr04/e03: safeArea bottom false leaves the body '
      'list the bottom inset to pad itself',
      (tester) async {
        _view(tester, size: _phone, padding: statusBar);
        late EdgeInsets bodyPadding;
        await tester.pumpWidget(
          _host(
            PageLayout(
              header: _slot('header'),
              safeArea: const PageSafeArea(bottom: false),
              body: Builder(
                builder: (context) {
                  bodyPadding = MediaQuery.paddingOf(context);
                  return const SizedBox.expand();
                },
              ),
            ),
          ),
        );
        expect(bodyPadding, const EdgeInsets.only(bottom: 34));
      },
    );

    testWidgets(
      'R20: fo06/us18/fr04/e06: under RTL a false left flag leaves the '
      "start inset, on the right edge, to left's children",
      (tester) async {
        _view(
          tester,
          size: const Size(1024, 768),
          padding: const FakeViewPadding(right: 44),
        );
        late EdgeInsets leftPadding;
        late EdgeInsets bodyPadding;
        await tester.pumpWidget(
          _host(
            PageLayout(
              safeArea: const PageSafeArea(left: false),
              left: Builder(
                builder: (context) {
                  leftPadding = MediaQuery.paddingOf(context);
                  return const Text('left');
                },
              ),
              body: Builder(
                builder: (context) {
                  bodyPadding = MediaQuery.paddingOf(context);
                  return const Text('body');
                },
              ),
            ),
            direction: TextDirection.rtl,
          ),
        );
        expect(_rect(tester, 'left').right, 1024);
        expect(leftPadding, const EdgeInsets.only(right: 44));
        expect(bodyPadding, EdgeInsets.zero);
      },
    );

    testWidgets(
      'fo06/us18/s5: fo06/us18/fr04/e04: a nested page adds no second top '
      'gap',
      (tester) async {
        _view(tester, size: _phone, padding: statusBar);
        await tester.pumpWidget(
          _host(
            PageLayout(
              header: _slot('outer'),
              body: PageLayout(header: _slot('inner'), body: const Text('b')),
            ),
          ),
        );
        expect(_rect(tester, 'outer').top, 44);
        expect(_rect(tester, 'inner').top, _rect(tester, 'outer').bottom);
      },
    );

    testWidgets('fo06/us18/fr04/e05: on a landscape phone with left null the '
        'center column pads by the side inset', (tester) async {
      _view(tester, size: _landscape, padding: const FakeViewPadding(left: 44));
      await tester.pumpWidget(
        _host(PageLayout(top: _slot('top'), body: const Text('body'))),
      );
      expect(_rect(tester, 'top').left, 44);
      expect(_rect(tester, 'body').left, 44);
      expect(tester.getRect(_fill('body')).left, 0);
    });

    testWidgets(
      'fo06/us18/fr04/e06: under RTL the start inset pads left, which '
      'sits on the right edge',
      (tester) async {
        _view(
          tester,
          size: const Size(1024, 768),
          padding: const FakeViewPadding(right: 44),
        );
        await tester.pumpWidget(
          _host(
            const PageLayout(left: Text('left'), body: Text('body')),
            direction: TextDirection.rtl,
          ),
        );
        expect(_rect(tester, 'left').right, 1024 - 44);
        expect(tester.getRect(_fill('left')).right, 1024);
        expect(_rect(tester, 'body').left, 0);
      },
    );

    testWidgets(
      'M1: fo06/us18/fr04: bottom never pads the top inset, even with '
      'body null',
      (tester) async {
        _view(tester, size: _phone, padding: const FakeViewPadding(top: 44));
        await tester.pumpWidget(_host(PageLayout(bottom: _slot('bottom'))));
        expect(_rect(tester, 'bottom'), const Rect.fromLTRB(0, 804, 390, 844));
        expect(tester.getRect(_fill('bottom')).height, 40);
      },
    );

    testWidgets(
      'R20: fo06/us18/fr04/e07: with header and footer null the inline '
      'sides pad by the top and bottom insets',
      (tester) async {
        _view(tester, size: const Size(768, 1024), padding: statusBar);
        await tester.pumpWidget(
          _host(
            PageLayout(
              controller: _widths(left: 100, right: 100),
              left: const Text('left'),
              right: const Text('right'),
              body: const Text('body'),
            ),
          ),
        );
        expect(_rect(tester, 'left'), const Rect.fromLTRB(0, 44, 100, 990));
        expect(_rect(tester, 'right'), const Rect.fromLTRB(668, 44, 768, 990));
        expect(tester.getRect(_fill('left')).top, 0);
      },
    );

    testWidgets('R20: fo06/us18/fr04/e03: safeArea flags off leave the inline '
        'sides unpadded', (tester) async {
      _view(tester, size: const Size(768, 1024), padding: statusBar);
      await tester.pumpWidget(
        _host(
          PageLayout(
            controller: _widths(left: 100, right: 100),
            left: const Text('left'),
            right: const Text('right'),
            safeArea: const PageSafeArea(top: false, bottom: false),
            body: const Text('body'),
          ),
        ),
      );
      expect(_rect(tester, 'left'), const Rect.fromLTRB(0, 0, 100, 1024));
      expect(_rect(tester, 'right'), const Rect.fromLTRB(668, 0, 768, 1024));
    });

    test('fo06/us18/fr04: PageSafeArea has value equality and copyWith', () {
      // Built at run time from a parameter, so no const canonicalization
      // makes them one instance and the check reads `==`, not identity.
      PageSafeArea make(bool top) => PageSafeArea(top: top, left: false);
      final a = make(false);
      final b = make(false);
      expect(identical(a, b), isFalse);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      final c = a.copyWith(left: true);
      expect(c.left, isTrue);
      expect(c.top, isFalse);
    });

    testWidgets('R20: right under top takes no top inset', (tester) async {
      _view(tester, size: const Size(768, 1024), padding: statusBar);
      await tester.pumpWidget(
        _host(
          PageLayout(
            controller: _widths(right: 100),
            top: _slot('top'),
            right: const Text('right'),
            body: const Text('body'),
          ),
        ),
      );
      expect(_rect(tester, 'top').top, 44);
      expect(_rect(tester, 'right').top, _rect(tester, 'top').bottom);
    });
  });

  group('PageLayout keyboard', () {
    testWidgets(
      'fo06/us18/s4: fo06/us18/fr05/e01: the keyboard shrinks the body and '
      'bottom rides above it',
      (tester) async {
        _view(tester, size: _phone, keyboard: 300);
        await tester.pumpWidget(
          _host(
            PageLayout(
              body: const SizedBox.expand(key: Key('b')),
              bottom: _slot('bottom'),
            ),
          ),
        );
        expect(_rect(tester, 'bottom').bottom, 844 - 300);
        expect(tester.getRect(find.byKey(const Key('b'))).bottom, 844 - 340);
      },
    );

    testWidgets(
      'fo06/us18/fr05/e02: resizeToAvoidKeyboard false moves nothing',
      (tester) async {
        _view(tester, size: _phone, keyboard: 300);
        await tester.pumpWidget(
          _host(
            PageLayout(
              resizeToAvoidKeyboard: false,
              body: const SizedBox.expand(),
              bottom: _slot('bottom'),
            ),
          ),
        );
        expect(_rect(tester, 'bottom').bottom, 844);
      },
    );

    testWidgets('review focus 1: fo06/us18/fr05/e03: a nested page under the '
        'keyboard shrinks once', (tester) async {
      _view(tester, size: _phone, keyboard: 300);
      await tester.pumpWidget(
        _host(
          PageLayout(
            body: PageLayout(
              body: const SizedBox.expand(),
              bottom: _slot('inner bottom'),
            ),
          ),
        ),
      );
      expect(_rect(tester, 'inner bottom').bottom, 844 - 300);
    });

    testWidgets(
      'fo06/us18/fr05/e04: a keyboard no taller than the footer moves '
      'nothing, and the footer stays docked',
      (tester) async {
        _view(tester, size: _phone, keyboard: 30);
        await tester.pumpWidget(
          _host(
            PageLayout(
              body: const SizedBox.expand(),
              bottom: _slot('bottom'),
              footer: const SizedBox(height: 48, child: Text('footer')),
            ),
          ),
        );
        expect(_rect(tester, 'bottom').bottom, 844 - 48);
        expect(_rect(tester, 'footer').bottom, 844);
      },
    );

    testWidgets('fo06/us18/fr05/e05: a keyboard taller than the footer lifts '
        'bottom only by the difference', (tester) async {
      _view(tester, size: _phone, keyboard: 300);
      await tester.pumpWidget(
        _host(
          PageLayout(
            body: const SizedBox.expand(),
            bottom: _slot('bottom'),
            footer: const SizedBox(height: 48, child: Text('footer')),
          ),
        ),
      );
      expect(_rect(tester, 'bottom').bottom, 844 - 300);
      expect(_rect(tester, 'footer').bottom, 844);
    });
  });

  group('PageLayout style', () {
    testWidgets(
      'R18: fo06/us18/fr03/e01: edge slots fill the surface token, the '
      'page and body the normal token',
      (tester) async {
        _view(tester);
        final colors = defaultThemeSet.light.color.background.defaults;
        await tester.pumpWidget(
          _host(
            PageLayout(
              header: _slot('header'),
              left: const Text('left'),
              top: _slot('top'),
              tab: _slot('tab'),
              body: const Text('body'),
              bottom: _slot('bottom'),
              right: const Text('right'),
              footer: _slot('footer'),
            ),
            theme: defaultThemeSet.light,
          ),
        );
        for (final edge in [
          'header',
          'left',
          'top',
          'tab',
          'bottom',
          'right',
          'footer',
        ]) {
          expect(
            _style(tester, edge).backgroundColor,
            colors.surface,
            reason: edge,
          );
        }
        expect(_style(tester, 'body').backgroundColor, colors.normal);
        expect(
          tester.widget<ContainerLayout>(_outer).style!.backgroundColor,
          colors.normal,
        );
      },
    );

    testWidgets('NFR-E01: fo06/us18/fr03/e05: slot fills follow the theme', (
      tester,
    ) async {
      _view(tester);
      Widget page(StratumThemeData theme) => _host(
        PageLayout(header: _slot('header'), body: const Text('b')),
        theme: theme,
      );
      await tester.pumpWidget(page(defaultThemeSet.light));
      final body = _style(tester, 'b').backgroundColor;
      final header = _style(tester, 'header').backgroundColor;
      await tester.pumpWidget(page(defaultThemeSet.dark!));
      expect(_style(tester, 'b').backgroundColor, isNot(body));
      expect(_style(tester, 'header').backgroundColor, isNot(header));
    });

    testWidgets(
      'NFR-E02: fo06/us18/fr03/e03: customStyle sets one field and the '
      'others keep the theme',
      (tester) async {
        _view(tester);
        await tester.pumpWidget(
          _host(
            PageLayout(
              customStyle: const PageLayoutStyle(
                body: WidgetStyle(border: Border.fromBorderSide(BorderSide())),
              ),
              header: _slot('header'),
              body: const Text('b'),
            ),
          ),
        );
        final body = _style(tester, 'b');
        expect(body.border, const Border.fromBorderSide(BorderSide()));
        expect(
          body.backgroundColor,
          fakeTheme.color.background.defaults.normal,
        );
        expect(
          _style(tester, 'header').backgroundColor,
          fakeTheme.color.background.defaults.surface,
        );
      },
    );

    testWidgets(
      'fo06/us18/fr03/e02: customStyle wins over the app-wide default, '
      'which wins over the theme',
      (tester) async {
        _view(tester);
        const red = Color(0xFFFF0000);
        const green = Color(0xFF00FF00);
        const blue = Color(0xFF0000FF);
        await tester.pumpWidget(
          _host(
            PageLayout(
              customStyle: const PageLayoutStyle(
                body: WidgetStyle(backgroundColor: red),
              ),
              header: _slot('header'),
              body: const Text('b'),
            ),
            parts: const {
              PageLayout: PageLayoutStyle(
                header: WidgetStyle(backgroundColor: green),
                body: WidgetStyle(backgroundColor: blue),
              ),
            },
          ),
        );
        expect(_style(tester, 'b').backgroundColor, red);
        expect(_style(tester, 'header').backgroundColor, green);
      },
    );

    testWidgets('fo06/us18/fr03/e04: a null slot draws nothing', (
      tester,
    ) async {
      _view(tester);
      final surface = fakeTheme.color.background.defaults.surface;
      await tester.pumpWidget(_host(const PageLayout(body: Text('b'))));
      expect(
        find.descendant(
          of: find.byType(PageLayout),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is ContainerLayout &&
                widget.style?.backgroundColor == surface,
          ),
        ),
        findsNothing,
      );
    });

    test('Q18: PageLayoutStyle has value equality over every field', () {
      // Non-const values, so canonicalization cannot stand in for ==.
      PageLayoutStyle style([int? differ]) {
        WidgetStyle at(int field) => WidgetStyle(
          width: double.parse('$field') + (field == differ ? 100 : 0),
        );
        return PageLayoutStyle(
          outer: at(0),
          header: at(1),
          top: at(2),
          tab: at(3),
          left: at(4),
          body: at(5),
          right: at(6),
          bottom: at(7),
          footer: at(8),
          snack: at(9),
        );
      }

      expect(style(), isNot(same(style())));
      expect(style(), style());
      expect(style().hashCode, style().hashCode);
      for (var field = 0; field < 10; field++) {
        expect(style(field), isNot(style()), reason: 'field $field');
      }
    });

    test('fo06/us18/fr03: PageLayoutStyle has value equality and copyWith', () {
      // Built at run time from a parameter, so no const canonicalization
      // makes them one instance and the check reads `==`, not identity.
      PageLayoutStyle make(double width) =>
          PageLayoutStyle(header: WidgetStyle(width: width));
      final a = make(1);
      final b = make(1);
      expect(identical(a, b), isFalse);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      final c = a.copyWith(header: const WidgetStyle(width: 2));
      expect(c.header, const WidgetStyle(width: 2));
      expect(c.outer, a.outer);
    });

    test(
      'fo06/us18/fr03: PageLayoutStyle copyWith sets a nullable field back to '
      'null',
      () {
        const a = PageLayoutStyle(header: WidgetStyle(width: 1));
        final c = a.copyWith(header: null);
        expect(c.header, isNull);
      },
    );

    test(
      'fo06/us18/fr03: merge replaces only the fields the other style sets',
      () {
        const base = PageLayoutStyle(
          body: WidgetStyle(width: 1, height: 2),
          header: WidgetStyle(width: 3),
        );
        final merged = base.merge(
          const PageLayoutStyle(
            body: WidgetStyle(width: 10),
            footer: WidgetStyle(height: 4),
          ),
        );
        expect(merged.body, const WidgetStyle(width: 10, height: 2));
        expect(merged.header, const WidgetStyle(width: 3));
        expect(merged.footer, const WidgetStyle(height: 4));
        expect(base.merge(null), same(base));
      },
    );
  });

  group('PageLayout loading', () {
    testWidgets(
      'fo06/us18/s7: fo06/us18/fr06/e01: taps do nothing while loading, and '
      'it reads Loading',
      (tester) async {
        _view(tester);
        final taps = <int>[];
        await tester.pumpWidget(
          _host(PageLayout(loading: true, body: _act(taps))),
        );
        await tester.pump(const Duration(milliseconds: 200));
        await tester.tap(find.text('Act'), warnIfMissed: false);
        expect(taps, isEmpty);
        expect(_loading, findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      },
    );

    testWidgets('fo06/us18/fr06/e02: in Thai the layer reads the Thai built-in '
        'loading label', (tester) async {
      _view(tester);
      await tester.pumpWidget(
        Localizations(
          locale: const Locale('th'),
          delegates: const [DefaultWidgetsLocalizations.delegate],
          child: _host(const PageLayout(loading: true, body: Text('b'))),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        find.bySemanticsLabel(
          builtInLabelsFor(const Locale('th')).loadingLabel,
        ),
        findsOneWidget,
      );
    });

    testWidgets('fo06/us18/fr06/e04: loading false lets taps through again and '
        'removes the layer', (tester) async {
      _view(tester);
      final taps = <int>[];
      Widget page(bool loading) =>
          _host(PageLayout(loading: loading, body: _act(taps)));
      await tester.pumpWidget(page(true));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpWidget(page(false));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Act'));
      expect(taps, hasLength(1));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(_loading, findsNothing);
    });

    testWidgets(
      'R19: fo06/us18/fr06/e05: fo06/us18/fr06/e06: Tab reaches no body '
      'control while loading, and focus returns after',
      (tester) async {
        _view(tester);
        final node = FocusNode();
        addTearDown(node.dispose);
        Widget page(bool loading) => _host(
          PageLayout(
            loading: loading,
            body: _act([], node: node),
          ),
        );
        await tester.pumpWidget(page(false));
        node.requestFocus();
        await tester.pump();
        expect(node.hasFocus, isTrue);

        await tester.pumpWidget(page(true));
        await tester.pump(const Duration(milliseconds: 200));
        expect(node.hasFocus, isFalse);
        for (var i = 0; i < 3; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          expect(node.hasFocus, isFalse);
        }

        await tester.pumpWidget(page(false));
        await tester.pump();
        expect(node.hasFocus, isTrue);
      },
    );

    testWidgets('R19: fo06/us18/fr06/e05: a dialog opened during loading keeps '
        'its focus when loading ends', (tester) async {
      _view(tester);
      final pageNode = FocusNode();
      final dialogNode = FocusNode();
      final loading = ValueNotifier(false);
      final navigator = GlobalKey<NavigatorState>();
      addTearDown(() {
        pageNode.dispose();
        dialogNode.dispose();
        loading.dispose();
      });
      await tester.pumpWidget(
        _host(
          Navigator(
            key: navigator,
            onGenerateRoute: (_) => PageRouteBuilder<void>(
              pageBuilder: (_, _, _) => ValueListenableBuilder(
                valueListenable: loading,
                builder: (_, value, _) => PageLayout(
                  loading: value,
                  body: _act([], node: pageNode),
                ),
              ),
            ),
          ),
        ),
      );
      pageNode.requestFocus();
      await tester.pump();
      loading.value = true;
      await tester.pump();
      navigator.currentState!.push(
        RawDialogRoute<void>(
          pageBuilder: (_, _, _) => Focus(
            focusNode: dialogNode,
            autofocus: true,
            child: const Text('dialog'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(dialogNode.hasFocus, isTrue);

      loading.value = false;
      await tester.pump();
      await tester.pump();
      expect(dialogNode.hasFocus, isTrue);
      expect(pageNode.hasFocus, isFalse);
    });

    testWidgets('R19: fo06/us18/fr06/e05: a control outside the page focused '
        'during loading keeps its focus when loading ends', (tester) async {
      _view(tester);
      final pageNode = FocusNode();
      final outside = FocusNode();
      addTearDown(() {
        pageNode.dispose();
        outside.dispose();
      });
      Widget page(bool loading) => _host(
        RowLayout(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Focus(focusNode: outside, child: const Text('outside')),
            Expanded(
              child: PageLayout(
                loading: loading,
                body: _act([], node: pageNode),
              ),
            ),
          ],
        ),
      );
      await tester.pumpWidget(page(false));
      pageNode.requestFocus();
      await tester.pump();
      await tester.pumpWidget(page(true));
      await tester.pump();
      outside.requestFocus();
      await tester.pump();

      await tester.pumpWidget(page(false));
      await tester.pump();
      expect(outside.hasFocus, isTrue);
      expect(pageNode.hasFocus, isFalse);
    });

    testWidgets(
      'R19: fo06/us18/fr06/e05: focus returns to the body control even '
      'when an outside control was focused before it',
      (tester) async {
        _view(tester);
        final pageNode = FocusNode();
        final outside = FocusNode();
        addTearDown(() {
          pageNode.dispose();
          outside.dispose();
        });
        Widget page(bool loading) => _host(
          RowLayout(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Focus(focusNode: outside, child: const Text('outside')),
              Expanded(
                child: PageLayout(
                  loading: loading,
                  body: _act([], node: pageNode),
                ),
              ),
            ],
          ),
        );
        await tester.pumpWidget(page(false));
        outside.requestFocus();
        await tester.pump();
        pageNode.requestFocus();
        await tester.pump();

        await tester.pumpWidget(page(true));
        await tester.pump();
        expect(pageNode.hasFocus, isFalse);

        await tester.pumpWidget(page(false));
        await tester.pump();
        expect(pageNode.hasFocus, isTrue);
        expect(outside.hasFocus, isFalse);
      },
    );

    testWidgets(
      'R19: fo06/us18/fr06: a loadingBuilder replaces the plain spinner '
      'while the layer still blocks',
      (tester) async {
        _view(tester);
        final taps = <int>[];
        await tester.pumpWidget(
          _host(
            PageLayout(
              loading: true,
              loadingBuilder: (_) => const Text('mine'),
              body: _act(taps),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text('mine'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        await tester.tap(find.text('Act'), warnIfMissed: false);
        expect(taps, isEmpty);
      },
    );
  });

  group('PageLayoutController', () {
    test('R22: holds the widths it starts with and notifies once per changed '
        'set', () {
      final controller = PageLayoutController(leftWidth: 280, rightWidth: 320);
      addTearDown(controller.dispose);
      var notes = 0;
      controller.addListener(() => notes++);
      expect(controller.leftWidth, 280);
      expect(controller.rightWidth, 320);
      controller.leftWidth = 300;
      expect(notes, 1);
      controller.leftWidth = 300;
      expect(notes, 1);
      controller.rightWidth = null;
      expect(notes, 2);
      expect(controller.rightWidth, isNull);
    });

    testWidgets('R22: PageLayout.of returns the passed controller, which the '
        'page never disposes', (tester) async {
      _view(tester);
      final controller = PageLayoutController();
      addTearDown(controller.dispose);
      PageLayoutController? found;
      await tester.pumpWidget(
        _host(
          PageLayout(
            controller: controller,
            body: Builder(
              builder: (context) {
                found = PageLayout.of(context);
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      );
      expect(found, same(controller));
      await tester.pumpWidget(const SizedBox.shrink());
      void listener() {}
      controller
        ..addListener(listener)
        ..removeListener(listener);
    });

    testWidgets('R22: with none passed the page makes its own controller and '
        'disposes it with the page', (tester) async {
      _view(tester);
      PageLayoutController? found;
      await tester.pumpWidget(
        _host(
          PageLayout(
            body: Builder(
              builder: (context) {
                found = PageLayout.of(context);
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      );
      expect(found, isNotNull);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(() => found!.addListener(() {}), throwsFlutterError);
    });

    testWidgets('R22: a passed controller replaces the own one, and the own '
        'one that follows starts from its widths', (tester) async {
      _view(tester);
      final passed = PageLayoutController(leftWidth: 240);
      addTearDown(passed.dispose);
      PageLayoutController? found;
      Widget page(PageLayoutController? controller) => _host(
        PageLayout(
          controller: controller,
          body: Builder(
            builder: (context) {
              found = PageLayout.of(context);
              return const SizedBox.expand();
            },
          ),
        ),
      );
      await tester.pumpWidget(page(null));
      final own = found!;
      await tester.pumpWidget(page(passed));
      expect(found, same(passed));
      expect(() => own.addListener(() {}), throwsFlutterError);
      await tester.pumpWidget(page(null));
      expect(found, isNot(same(passed)));
      expect(found!.leftWidth, 240);
    });

    testWidgets('R22: PageLayout.of throws a FlutterError naming PageLayout '
        'with none above', (tester) async {
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            PageLayout.of(context);
            return const SizedBox.shrink();
          },
        ),
      );
      final error = tester.takeException();
      expect(error, isA<FlutterError>());
      expect('$error', contains('PageLayout'));
    });
  });

  group('PageLayout accessibility gate', () {
    testWidgets('NFR-U01: slot text on the slot fills passes contrast', (
      tester,
    ) async {
      _view(tester, size: _phone);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          const PageLayout(header: Text('Header'), body: _centerBody),
          theme: defaultThemeSet.light,
        ),
      );
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });

    testWidgets('NFR-U02: Tab follows header, left, its divider, top, tab, '
        'body, bottom, the right divider, right, footer (Q8)', (tester) async {
      _view(tester);
      final order = <String>[];
      Widget stop(String name) => Focus(
        onFocusChange: (focused) {
          if (focused) order.add(name);
        },
        child: Text(name),
      );
      // A divider takes focus on its own node, which no slot stop hears.
      void onFocus() {
        final label = FocusManager.instance.primaryFocus?.debugLabel ?? '';
        if (label.startsWith('SplitLayout divider')) order.add('divider');
      }

      FocusManager.instance.addListener(onFocus);
      addTearDown(() => FocusManager.instance.removeListener(onFocus));
      await tester.pumpWidget(
        _host(
          PageLayout(
            header: stop('header'),
            left: stop('left'),
            top: stop('top'),
            tab: stop('tab'),
            // Reading order would visit right's top stop before the
            // body's stop at its foot; the slot order puts body first.
            body: Align(alignment: Alignment.bottomCenter, child: stop('body')),
            bottom: stop('bottom'),
            right: Align(alignment: Alignment.topCenter, child: stop('right')),
            footer: stop('footer'),
          ),
        ),
      );
      for (var i = 0; i < 10; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      expect(order, [
        'header',
        'left',
        'divider',
        'top',
        'tab',
        'body',
        'bottom',
        'divider',
        'right',
        'footer',
      ]);
    });

    // The layer only fades, whatever the motion setting: one frame after
    // loading turns true its bounds are the settled ones, and the fade still
    // runs over the theme's fast level (us18/fr06/e03).
    for (final (source, app, platform) in [
      ('no', false, false),
      ('app', true, false),
      ('platform', false, true),
    ]) {
      testWidgets(
        'NFR-U03: fo06/us18/fr06/e03: with $source reduced motion the '
        'loading layer only fades, over the fast level',
        (tester) async {
          _view(tester);
          if (platform) {
            tester.platformDispatcher.accessibilityFeaturesTestValue =
                const FakeAccessibilityFeatures(reduceMotion: true);
            addTearDown(
              tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
            );
          }
          Widget page(bool loading) => _host(
            PageLayout(loading: loading, body: const Text('b')),
            theme: motionTheme(fast: const Duration(milliseconds: 100)),
            media: (data) => data.copyWith(disableAnimations: app),
          );
          await tester.pumpWidget(page(false));
          await tester.pumpWidget(page(true));
          expect(tester.getRect(_loading), Offset.zero & _desktop);
          await tester.pump(const Duration(milliseconds: 50));
          expect(tester.getRect(_loading), Offset.zero & _desktop);
          expect(_opacity(tester), inExclusiveRange(0, 1));
          await tester.pump(const Duration(milliseconds: 50));
          expect(_opacity(tester), 1);
        },
      );
    }

    testWidgets('NFR-U04: at twice the text size the hug slots grow with no '
        'overflow', (tester) async {
      _view(tester, size: _phone);
      Widget page(double scale) => _host(
        const PageLayout(
          header: Text('A header title'),
          footer: Text('A footer line'),
          body: Text('b'),
        ),
        media: (data) => data.copyWith(textScaler: TextScaler.linear(scale)),
      );
      await tester.pumpWidget(page(1));
      final header = tester.getSize(_fill('A header title')).height;
      await tester.pumpWidget(page(2));
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(_fill('A header title')).height,
        greaterThan(header),
      );
    });

    testWidgets('NFR-U06: slots keep their child nodes unchanged', (
      tester,
    ) async {
      _view(tester);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          PageLayout(
            body: TextButton(onPressed: () {}, child: const Text('Act')),
          ),
        ),
      );
      expect(
        tester.getSemantics(find.text('Act')),
        matchesSemantics(
          label: 'Act',
          isButton: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
          hasEnabledState: true,
          isEnabled: true,
        ),
      );
      handle.dispose();
    });

    testWidgets(
      'NFR-U06: fo06/us18/fr06/e02: the loading layer reads as a live '
      'region labeled Loading',
      (tester) async {
        _view(tester);
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          _host(const PageLayout(loading: true, body: Text('b'))),
        );
        await tester.pump(const Duration(milliseconds: 200));
        expect(
          tester.getSemantics(_loading),
          matchesSemantics(label: 'Loading', isLiveRegion: true),
        );
        handle.dispose();
      },
    );

    testWidgets('NFR-U07: slot text passes contrast in every bundled theme', (
      tester,
    ) async {
      _view(tester, size: _phone);
      final handle = tester.ensureSemantics();
      final themes = [
        defaultThemeSet.light,
        defaultThemeSet.dark,
        defaultThemeSet.highContrastLight,
        defaultThemeSet.highContrastDark,
      ].nonNulls;
      for (final theme in themes) {
        await tester.pumpWidget(
          _host(
            const PageLayout(header: Text('Header'), body: _centerBody),
            theme: theme,
          ),
        );
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      }
      handle.dispose();
    });

    testWidgets('NFR-U08: loading also shows a spinner shape under high '
        'contrast', (tester) async {
      _view(tester);
      await tester.pumpWidget(
        _host(
          const PageLayout(loading: true, body: Text('b')),
          highContrast: true,
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
