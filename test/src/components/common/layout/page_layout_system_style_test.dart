// The system-style declarations of `PageLayout`, `Scrim`, and `ModalLayout`
// (US-18 FR-07; US-19 FR-04 E08; US-20 FR-06 E07, E08; layout s03
// invariants 77 to 79): the page wraps a given system style, every solid
// slot fill declares itself to the bar resolver, the scrim declares the
// color it paints at this frame, and a modal layout's surface declares its
// own fill.
//
// NFR-U02 n/a: the declarations hold no focusable node.
// NFR-U03 n/a: the scrim's declaration follows the fade the route already
//   runs; it adds no animation of its own.
// NFR-U04 n/a: no declaration draws text.
// NFR-U05 n/a: no declaration holds a target.
// NFR-U08 n/a: no declaration shows a state.
// NFR-U09 n/a: no declaration handles a gesture.
import 'package:flutter/rendering.dart' show debugOnProfilePaint;
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/layout/scrim.dart' show Scrim;
import 'package:stratum_ui/src/src.dart';
import 'package:stratum_ui/src/themes/system/system_bars.dart';

import '../../../themes/system/system_style_fakes.dart';
import '../fakes/fake_stratum_theme.dart' show defaultThemeSet;

const _black = Color(0xFF000000);
const _white = Color(0xFFFFFFFF);

/// A mid gray: dark icons win on it bare, and the theme's scrim (gray.800
/// at half alpha) over it flips the auto icons to light, first at about a
/// quarter of the fade.
const _flipGray = Color(0xFF808080);

/// The theme's light page background, an opaque white: the fill the
/// resolver reads where no slot declares one.
Color get _pageBackground =>
    defaultThemeSet.light.color.background.defaults.normal;

Widget _page({
  Widget? header,
  Widget? top,
  Widget? bottom,
  Widget? footer,
  Widget? left,
  SystemStyle? systemStyle,
  PageLayoutStyle? customStyle,
}) => PageLayout(
  header: header,
  top: top,
  body: const Text('Body'),
  bottom: bottom,
  footer: footer,
  left: left,
  systemStyle: systemStyle,
  customStyle: customStyle,
);

/// A phone view, 390 by 844 logical pixels, so `left` opens as a drawer and
/// a bottom sheet spans the window.
void _phoneView(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(1170, 2532)
    ..devicePixelRatio = 3;
}

/// Runs [body] with [defaultTargetPlatform] overridden to [platform],
/// restored before this returns so a failed `expect` inside [body] never
/// leaves the override set for a later test (edge review F3; correctness
/// review Minor 3; `box_layout_test.dart`'s `_withTargetPlatform` pattern).
Future<void> _withTargetPlatform(
  TargetPlatform platform,
  Future<void> Function() body,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  testWidgets('fo06/us18/fr07/e01: a null systemStyle adds no scope; a set one '
      'wins over the auto icons', (tester) async {
    systemBarsView(tester);
    await tester.pumpWidget(
      systemStyleApp(
        home: _page(
          header: const SizedBox(),
          customStyle: const PageLayoutStyle(
            header: WidgetStyle(backgroundColor: _black),
          ),
        ),
      ),
    );

    expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.light);
    expect(find.byType(SystemStyleScope), findsNothing);

    await tester.pumpWidget(
      systemStyleApp(
        home: _page(
          header: const SizedBox(),
          systemStyle: const SystemStyle(statusBarIcons: SystemBarIcons.dark),
          customStyle: const PageLayoutStyle(
            header: WidgetStyle(backgroundColor: _black),
          ),
        ),
      ),
    );

    // The page's dark icons beat the light ones the black fill picks.
    expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.dark);
  });

  testWidgets('fo06/us18/fr07: with no slot at the bar point, the outer fill '
      'declares itself (edge review F1)', (tester) async {
    systemBarsView(tester);
    Widget page(Color fill) => systemStyleApp(
      home: PageLayout(
        customStyle: PageLayoutStyle(outer: WidgetStyle(backgroundColor: fill)),
      ),
    );
    await tester.pumpWidget(page(_black));

    expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.light);

    await tester.pumpWidget(page(_white));

    expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.dark);
  });

  testWidgets(
    'fo06/us18/fr07/e04: with no header, an inline left pane covering '
    'the status bar point declares its fill (correctness review Minor 2)',
    (tester) async {
      systemBarsView(tester);
      Widget page(Color fill) => systemStyleApp(
        home: PageLayout(
          left: const SizedBox(),
          body: const Text('Body'),
          leftSide: const PageSide(minWidth: 500),
          customStyle: PageLayoutStyle(
            left: WidgetStyle(backgroundColor: fill),
          ),
        ),
      );
      await tester.pumpWidget(page(_black));

      expect(
        SystemChrome.latestStyle?.statusBarIconBrightness,
        Brightness.light,
      );

      await tester.pumpWidget(page(_white));

      expect(
        SystemChrome.latestStyle?.statusBarIconBrightness,
        Brightness.dark,
      );
    },
  );

  testWidgets("fo06/us18/fr07/e07: a page systemStyle nested in another page's "
      'body merges over it, field by field (correctness review Minor 2)', (
    tester,
  ) async {
    systemBarsView(tester);
    await _withTargetPlatform(TargetPlatform.android, () async {
      await tester.pumpWidget(
        systemStyleApp(
          home: const PageLayout(
            body: PageLayout(
              body: Text('Body'),
              systemStyle: SystemStyle(statusBarIcons: SystemBarIcons.dark),
            ),
            systemStyle: SystemStyle(
              statusBarIcons: SystemBarIcons.light,
              navigationBarIcons: SystemBarIcons.light,
            ),
          ),
        ),
      );

      // The inner page's statusBarIcons wins; the outer's
      // navigationBarIcons, which the inner page leaves null, still applies.
      expect(
        SystemChrome.latestStyle?.statusBarIconBrightness,
        Brightness.dark,
      );
      expect(
        SystemChrome.latestStyle?.systemNavigationBarIconBrightness,
        Brightness.light,
      );
    });
  });

  testWidgets('fo06/us18/fr07/e09: a page with systemStyle set reads the same '
      'semantics tree as one without (correctness review Minor 2)', (
    tester,
  ) async {
    systemBarsView(tester);
    final handle = tester.ensureSemantics();
    Widget page({SystemStyle? systemStyle}) => systemStyleApp(
      home: PageLayout(
        header: const Text('Head'),
        body: const Text('Body'),
        systemStyle: systemStyle,
      ),
    );
    await tester.pumpWidget(page());
    final bare = semanticsTree(tester);

    await tester.pumpWidget(
      page(systemStyle: const SystemStyle(statusBarIcons: SystemBarIcons.dark)),
    );

    expect(semanticsTree(tester), bare);
    handle.dispose();
  });

  testWidgets('fo06/us18/fr07/e02: a dark, then a light header fill flips the '
      'auto status icons', (tester) async {
    systemBarsView(tester);
    Widget page(Color fill) => systemStyleApp(
      home: _page(
        header: const SizedBox(),
        customStyle: PageLayoutStyle(
          header: WidgetStyle(backgroundColor: fill),
        ),
      ),
    );
    await tester.pumpWidget(page(_black));

    expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.light);

    await tester.pumpWidget(page(_white));

    expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.dark);
  });

  testWidgets('fo06/us18/fr07/e02: with no header, a top slot fill at the top '
      'edge declares itself', (tester) async {
    systemBarsView(tester);
    Widget page(Color fill) => systemStyleApp(
      home: _page(
        top: const SizedBox(),
        customStyle: PageLayoutStyle(top: WidgetStyle(backgroundColor: fill)),
      ),
    );
    // brief's S2: no header, then `top` at the top edge.
    await tester.pumpWidget(page(_black));

    expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.light);

    await tester.pumpWidget(page(_white));

    expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.dark);
  });

  testWidgets('fo06/us18/fr07/e02: with no header, top, or tab, a body fill at '
      'the top edge declares itself', (tester) async {
    systemBarsView(tester);
    Widget page(Color fill) => systemStyleApp(
      home: _page(
        customStyle: PageLayoutStyle(body: WidgetStyle(backgroundColor: fill)),
      ),
    );
    await tester.pumpWidget(page(_black));

    expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.light);

    await tester.pumpWidget(page(_white));

    expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.dark);
  });

  testWidgets('fo06/us18/fr07/e02: a footer, bottom, and body fill under the '
      'navigation bar flip the auto navigation icons (Android)', (
    tester,
  ) async {
    systemBarsView(tester);
    await _withTargetPlatform(TargetPlatform.android, () async {
      // The footer step keeps no bottom; the bottom step keeps no footer;
      // the body step keeps neither, so each tested slot is the one under
      // the navigation bar (US-14 FR-05 E01: the geometry picks the slot).
      Widget page(PageLayoutStyle style, {Widget? footer, Widget? bottom}) =>
          systemStyleApp(
            home: _page(footer: footer, bottom: bottom, customStyle: style),
          );
      await tester.pumpWidget(
        page(
          const PageLayoutStyle(footer: WidgetStyle(backgroundColor: _black)),
          footer: const SizedBox(),
        ),
      );
      expect(
        SystemChrome.latestStyle?.systemNavigationBarIconBrightness,
        Brightness.light,
      );

      await tester.pumpWidget(
        page(
          const PageLayoutStyle(bottom: WidgetStyle(backgroundColor: _white)),
          bottom: const Text('Bottom'),
        ),
      );

      expect(
        SystemChrome.latestStyle?.systemNavigationBarIconBrightness,
        Brightness.dark,
      );

      await tester.pumpWidget(
        page(const PageLayoutStyle(body: WidgetStyle(backgroundColor: _black))),
      );

      expect(
        SystemChrome.latestStyle?.systemNavigationBarIconBrightness,
        Brightness.light,
      );
    });
  });

  testWidgets('fo06/us18/fr07/e03: a gradient header fill declares nothing, so '
      'the icons follow the theme page background', (tester) async {
    systemBarsView(tester);
    await tester.pumpWidget(
      systemStyleApp(
        home: _page(
          header: const SizedBox(),
          customStyle: const PageLayoutStyle(
            header: WidgetStyle(
              backgroundGradient: LinearGradient(colors: [_black, _white]),
            ),
          ),
        ),
      ),
    );

    expect(
      SystemChrome.latestStyle?.statusBarIconBrightness,
      pickLightIcons(_pageBackground) ? Brightness.light : Brightness.dark,
    );
  });

  testWidgets('fo06/us18/fr07/e03: a header fill with both a color and a '
      'gradient declares nothing, so the icons follow the fill beneath '
      '(edge review F2)', (tester) async {
    systemBarsView(tester);
    await tester.pumpWidget(
      systemStyleApp(
        home: _page(
          header: const SizedBox(),
          customStyle: const PageLayoutStyle(
            header: WidgetStyle(
              backgroundColor: _black,
              backgroundGradient: LinearGradient(colors: [_black, _white]),
            ),
          ),
        ),
      ),
    );

    expect(
      SystemChrome.latestStyle?.statusBarIconBrightness,
      pickLightIcons(_pageBackground) ? Brightness.light : Brightness.dark,
    );
  });

  testWidgets("fo06/us18/fr07 correctness: a header fill's opacity folds into "
      'the declared alpha, so the icons match what the eye sees '
      '(correctness review Minor 1)', (tester) async {
    systemBarsView(tester);
    await tester.pumpWidget(
      systemStyleApp(
        home: _page(
          header: const SizedBox(),
          customStyle: const PageLayoutStyle(
            header: WidgetStyle(backgroundColor: _black, opacity: 0.5),
          ),
        ),
      ),
    );

    // Black at half opacity over the white page background blends to a
    // mid gray the same way _flipGray does, where dark icons win bare.
    expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.dark);
  });

  testWidgets(
    'fo06/us19/fr04/e08, fo06/us20/fr06/e07: an open modal blends the scrim '
    'over the header; the mid-fade fill tracks the fade; icons restore '
    'after close',
    (tester) async {
      systemBarsView(tester);
      final navigator = GlobalKey<NavigatorState>();
      Widget page() => systemStyleApp(
        navigatorKey: navigator,
        home: _page(
          header: const SizedBox(),
          customStyle: const PageLayoutStyle(
            header: WidgetStyle(backgroundColor: _flipGray),
          ),
        ),
      );
      await tester.pumpWidget(page());
      expect(
        SystemChrome.latestStyle?.statusBarIconBrightness,
        Brightness.dark,
      );

      unawaited(
        showModalLayout<void>(
          navigator.currentContext!,
          type: ModalLayoutType.modal,
          builder: (context) => const ModalLayout(body: SizedBox()),
        ),
      );
      await tester.pump();
      // The theme's `normal` level runs 200 ms; 30 ms in, the fade on
      // `easeInOutSine` sits near 6 percent, before the quarter-fade flip.
      await tester.pump(const Duration(milliseconds: 30));

      expect(
        SystemChrome.latestStyle?.statusBarIconBrightness,
        Brightness.dark,
      );

      await tester.pumpAndSettle();

      expect(
        SystemChrome.latestStyle?.statusBarIconBrightness,
        Brightness.light,
      );

      navigator.currentState!.pop();
      await tester.pumpAndSettle();

      expect(
        SystemChrome.latestStyle?.statusBarIconBrightness,
        Brightness.dark,
      );
    },
  );

  testWidgets('performance review I1: a RepaintBoundary isolates the '
      "scrim's blurred box from its per-frame fill declaration", (
    tester,
  ) async {
    systemBarsView(tester);
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      systemStyleApp(
        navigatorKey: navigator,
        home: _page(header: const SizedBox()),
      ),
    );
    unawaited(
      showModalLayout<void>(
        navigator.currentContext!,
        type: ModalLayoutType.modal,
        builder: (context) => const ModalLayout(body: SizedBox()),
      ),
    );
    await tester.pump();

    final blurred = tester.renderObject(
      find.descendant(
        of: find.byType(Scrim),
        matching: find.byType(BackdropFilter),
      ),
    );
    var repaints = 0;
    final previous = debugOnProfilePaint;
    debugOnProfilePaint = (object) {
      if (identical(object, blurred)) repaints++;
    };
    try {
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    } finally {
      debugOnProfilePaint = previous;
    }

    expect(
      repaints,
      lessThanOrEqualTo(1),
      reason:
          'the boundary absorbs the fill color change; the blur paints '
          'once, not once per fade frame',
    );
  });

  testWidgets('fo06/us19/fr04/e08: an open drawer blends the scrim over the '
      'header', (tester) async {
    systemBarsView(tester);
    _phoneView(tester);
    await tester.pumpWidget(
      systemStyleApp(
        home: const PageLayout(
          header: SizedBox(),
          body: Text('Body'),
          left: SizedBox(),
          leftSide: PageSide(maxWidth: 40),
          customStyle: PageLayoutStyle(
            header: WidgetStyle(backgroundColor: _flipGray),
          ),
        ),
      ),
    );
    expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.dark);

    PageLayout.of(tester.element(find.text('Body'))).openLeft();
    await tester.pumpAndSettle();

    expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.light);
  });

  testWidgets('fo06/us20/fr06/e07: a scrim with showBackground false declares '
      'nothing', (tester) async {
    systemBarsView(tester);
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      systemStyleApp(
        navigatorKey: navigator,
        home: _page(
          header: const SizedBox(),
          customStyle: const PageLayoutStyle(
            header: WidgetStyle(backgroundColor: _flipGray),
          ),
        ),
      ),
    );

    unawaited(
      showModalLayout<void>(
        navigator.currentContext!,
        type: ModalLayoutType.modal,
        showBackground: false,
        builder: (context) => const ModalLayout(body: SizedBox()),
      ),
    );
    await tester.pumpAndSettle();

    expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.dark);
  });

  testWidgets('fo06/us20/fr06/e08: a bottom sheet surface runs under the '
      'navigation bar and declares its fill', (tester) async {
    systemBarsView(tester);
    _phoneView(tester);
    await _withTargetPlatform(TargetPlatform.android, () async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        systemStyleApp(
          navigatorKey: navigator,
          home: _page(
            customStyle: const PageLayoutStyle(
              body: WidgetStyle(backgroundColor: _black),
            ),
          ),
        ),
      );
      expect(
        SystemChrome.latestStyle?.systemNavigationBarIconBrightness,
        Brightness.light,
      );

      unawaited(
        showModalLayout<void>(
          navigator.currentContext!,
          type: ModalLayoutType.bottomSheet,
          builder: (context) => const ModalLayout(body: SizedBox()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        SystemChrome.latestStyle?.systemNavigationBarIconBrightness,
        Brightness.dark,
      );
    });
  });

  testWidgets(
    'fo06/us20/fr06/e08: a bottom sheet surface with both a color and '
    'a gradient declares nothing, so the icons follow the fill beneath '
    '(edge review F2)',
    (tester) async {
      systemBarsView(tester);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        systemStyleApp(navigatorKey: navigator, home: _page()),
      );

      unawaited(
        showModalLayout<void>(
          navigator.currentContext!,
          type: ModalLayoutType.bottomSheet,
          builder: (context) => const ModalLayout(
            body: SizedBox(height: 600),
            customStyle: ModalLayoutStyle(
              surface: WidgetStyle(
                backgroundColor: _black,
                backgroundGradient: LinearGradient(colors: [_black, _white]),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        SystemChrome.latestStyle?.statusBarIconBrightness,
        pickLightIcons(_pageBackground) ? Brightness.light : Brightness.dark,
      );
    },
  );

  testWidgets('performance review Minor: a header fill crossing the '
      "solid/gradient line keeps the slot's State", (tester) async {
    Widget page(WidgetStyle? header) => systemStyleApp(
      home: PageLayout(
        header: const _StateProbe(),
        body: const SizedBox(),
        customStyle: PageLayoutStyle(header: header),
      ),
    );
    await tester.pumpWidget(page(const WidgetStyle(backgroundColor: _black)));
    final before = tester.state(find.byType(_StateProbe));

    await tester.pumpWidget(
      page(
        const WidgetStyle(
          backgroundColor: _black,
          backgroundGradient: LinearGradient(colors: [_black, _white]),
        ),
      ),
    );
    expect(tester.state(find.byType(_StateProbe)), same(before));

    await tester.pumpWidget(page(const WidgetStyle(backgroundColor: _black)));
    expect(tester.state(find.byType(_StateProbe)), same(before));
  });

  testWidgets('fo06/us18/fr07/e06: a declared fill and an undeclared gradient '
      'read the same semantics tree', (tester) async {
    systemBarsView(tester);
    final handle = tester.ensureSemantics();
    Widget page(WidgetStyle fill) => systemStyleApp(
      home: _page(
        header: const Text('Head'),
        customStyle: PageLayoutStyle(header: fill),
      ),
    );
    await tester.pumpWidget(page(const WidgetStyle(backgroundColor: _black)));
    final declared = semanticsTree(tester);

    await tester.pumpWidget(
      page(
        const WidgetStyle(
          backgroundGradient: LinearGradient(colors: [_black, _white]),
        ),
      ),
    );

    expect(semanticsTree(tester), declared);
    handle.dispose();
  });
}

/// A stateful slot content probe: its `State` identity proves whether a
/// slot's wrapper changing shape remounted it (performance review Minor).
class _StateProbe extends StatefulWidget {
  const new();

  @override
  State<_StateProbe> createState() => _StateProbeState();
}

class _StateProbeState extends State<_StateProbe> {
  @override
  Widget build(BuildContext context) => const SizedBox(width: 8, height: 8);
}
