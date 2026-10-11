// The Build Gate of `stratum-create-widget` for `SystemStyleScope` (FO-03
// US-14; design `## Accessibility and UX`). One test per row below; the
// rows answered n/a, each with its reason:
// - NFR-U02 n/a: the scope holds no focusable node.
// - NFR-U03 n/a: the scope runs no animation; the bars show and hide with
//   the platform's own motion.
// - NFR-U04 n/a: the scope draws no text; the app switcher label is text
//   the operating system draws.
// - NFR-U05 n/a: the scope holds no target.
// - NFR-U08 n/a: the scope shows no state.
// - NFR-U09 n/a: the scope handles no gesture of its own; the EndUser
//   reveals hidden bars with the platform's own edge swipe.
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';
import 'package:stratum_ui/src/themes/system/system_bars.dart';

import '../../components/common/fakes/fake_stratum_theme.dart';
import 'system_style_fakes.dart';

const _style = SystemStyle(
  statusBarIcons: SystemBarIcons.light,
  barMode: SystemBarMode.immersive,
  appSwitcherLabel: 'Video',
);

void main() {
  testWidgets('NFR-U06, us14/fr05/e04: the scope owns no semantics node and '
      'the child reads unchanged', (tester) async {
    systemBarsView(tester);
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      playButtonPage(Alignment.topLeft, (child) => child),
    );
    final plain = semanticsTree(tester);

    await tester.pumpWidget(
      playButtonPage(
        Alignment.topLeft,
        (child) => SystemStyleScope(style: _style, child: child),
      ),
    );

    expect(semanticsTree(tester), plain);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Play')),
      matchesSemantics(label: 'Play', isButton: true, hasTapAction: true),
    );
    handle.dispose();
  });

  testWidgets('us14/fr05: the scope paints nothing, takes no focus, and '
      'leaves a tap to its child', (tester) async {
    systemBarsView(tester);
    var taps = 0;
    await tester.pumpWidget(
      playButtonPage(Alignment.topLeft, (child) => child, onTap: () => taps++),
    );
    final focusNodes = FocusManager.instance.rootScope.descendants.length;

    await tester.pumpWidget(
      playButtonPage(
        Alignment.topLeft,
        (child) => SystemStyleScope(style: _style, child: child),
        onTap: () => taps++,
      ),
    );
    await tester.tap(find.bySemanticsLabel('Play'));

    expect(taps, 1);
    expect(FocusManager.instance.rootScope.descendants, hasLength(focusNodes));
    expect(tester.renderObject(find.byType(SystemStyleScope)), paintsNothing);
  });

  testWidgets('with no theme application above, a scope and a fill set no '
      'bar mode or rotation and throw nothing', (tester) async {
    final calls = systemBarsView(tester);
    await tester.pumpWidget(
      const MaterialApp(
        home: SystemStyleScope(
          style: _style,
          child: SystemBarFill(color: Color(0xFF000000), child: SizedBox()),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(argumentsOf(calls, 'SystemChrome.setEnabledSystemUIMode'), isEmpty);
    expect(
      argumentsOf(calls, 'SystemChrome.setPreferredOrientations'),
      isEmpty,
    );
  });

  for (final (name, mode, highContrast) in [
    ('light', ThemeMode.light, StratumHighContrastMode.off),
    ('dark', ThemeMode.dark, StratumHighContrastMode.off),
    ('high-contrast light', ThemeMode.light, StratumHighContrastMode.on),
    ('high-contrast dark', ThemeMode.dark, StratumHighContrastMode.on),
  ]) {
    testWidgets('NFR-U01, NFR-U07, us14/fr02: automatic icons hold 3:1 '
        'against the $name page background', (tester) async {
      systemBarsView(tester);
      await tester.pumpWidget(
        systemStyleApp(
          themeMode: mode,
          highContrast: highContrast,
          home: const SystemStyleScope(
            style: SystemStyle(barMode: SystemBarMode.edgeToEdge),
            child: SizedBox(),
          ),
        ),
      );
      final data = defaultThemeSet.pick(
        dark: mode == ThemeMode.dark,
        highContrast: highContrast == StratumHighContrastMode.on,
      );

      expect(data.systemStyle.statusBarIcons, SystemBarIcons.auto);
      expect(
        contrastRatio(
          latestStatusIconColor(),
          data.color.background.defaults.normal,
        ),
        greaterThanOrEqualTo(3),
      );
    });
  }

  testWidgets('NFR-E01: with no style field set, the bar look follows the '
      'theme', (tester) async {
    systemBarsView(tester);
    Widget page(ThemeMode mode) => systemStyleApp(
      themeMode: mode,
      home: const SystemStyleScope(style: SystemStyle(), child: SizedBox()),
    );
    await tester.pumpWidget(page(ThemeMode.light));
    final light = SystemChrome.latestStyle;

    await tester.pumpWidget(page(ThemeMode.dark));

    expect(light?.statusBarIconBrightness, Brightness.dark);
    expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.light);
  });

  testWidgets('NFR-E02, us14/fr01: one set field shows, and the other fields '
      'keep the theme default', (tester) async {
    systemBarsView(tester);
    await tester.pumpWidget(
      systemStyleApp(
        home: const SystemStyleScope(
          style: SystemStyle(statusBarColor: Color(0xFF0000AA)),
          child: SizedBox(),
        ),
      ),
    );

    expect(
      barStrips(tester),
      paints..rect(rect: statusStrip, color: const Color(0xFF0000AA)),
    );
    expect(barStrips(tester), paintsExactlyCountTimes(#drawRect, 1));
    expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.light);
    expect(
      SystemChrome.latestStyle?.systemNavigationBarIconBrightness,
      Brightness.dark,
    );
  });
}
