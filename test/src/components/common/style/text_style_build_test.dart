import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import '../fakes/fake_stratum_theme.dart';

/// A theme whose body is [body] by default and Font A in Thai, with a
/// window scale of 1 on tablet and 2 on desktop.
StratumThemeData _theme({String body = 'inter'}) {
  final document = loadYaml('''
typography:
  fonts:
    inter: { family: Inter }
    geist: { family: Geist }
    font-a: { family: Font A }
  families:
    default:
      header: inter
      paragraph: inter
      number: inter
      code: inter
      body: $body
      table: inter
    th: { body: font-a }
  scaleByWindowSize: { watch: 0, mobile: 0, tablet: 1, desktop: 2 }
  types:
    header: { weight: 600, sizes: { s16: { spaceHeight: 8 } } }
    paragraph: { weight: 400, sizes: { s16: { spaceHeight: 8 } } }
    number: { weight: 600, sizes: { s16: { spaceHeight: 8 } } }
    code: { weight: 400, sizes: { s16: { spaceHeight: 8 } } }
    body: { weight: 400, sizes: { s16: { spaceHeight: 8 } } }
''') as YamlMap;
  return fakeStratumTheme(
    typography: StratumTypography.fromYaml(document['typography'] as YamlMap),
  );
}

/// A widget that builds [recipe] on every build and records the result.
Widget _probe(List<TextStyle> styles, [StratumTextStyle? recipe]) {
  return Builder(
    builder: (context) {
      styles.add((recipe ?? StratumTextStyle.body).build(context));
      return const SizedBox();
    },
  );
}

void main() {
  final theme = _theme();

  void setWindowSize(WidgetTester tester, Size size) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
  }

  Widget localized(Locale locale, Widget child) => Localizations(
    locale: locale,
    delegates: const [DefaultWidgetsLocalizations.delegate],
    child: child,
  );

  testWidgets('a Localizations locale change switches the family', (
    tester,
  ) async {
    final styles = <TextStyle>[];
    final probe = _probe(styles);

    await tester.pumpWidget(
      themedHost(localized(const Locale('en'), probe), theme: theme),
    );
    await tester.pumpWidget(
      themedHost(localized(const Locale('th'), probe), theme: theme),
    );

    expect(styles.map((style) => style.fontFamily), ['Inter', 'Font A']);
  });

  testWidgets('without Localizations the platform locale picks the family', (
    tester,
  ) async {
    tester.platformDispatcher.localeTestValue = const Locale('th');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    final styles = <TextStyle>[];

    await tester.pumpWidget(themedHost(_probe(styles), theme: theme));

    expect(styles.single.fontFamily, 'Font A');
  });

  testWidgets('us01/s1: body 16 in medium weight draws in the theme body '
      'font at the body 16 line height, in medium, or, for a Google body '
      'font the theme loads in no medium weight, in the nearest loaded '
      'weight', (tester) async {
    final styles = <TextStyle>[];
    final recipe = StratumTextStyle.body.s16.medium;

    await tester.pumpWidget(themedHost(_probe(styles, recipe), theme: theme));
    final app = styles.last;
    await tester.pumpWidget(themedHost(_probe(styles, recipe)));
    final google = styles.last;

    expect((app.fontFamily, app.fontWeight), ('Inter', FontWeight.w500));
    expect(app.height! * app.fontSize!, closeTo(24, 1e-9));
    // The package default loads Google Inter in 400 and 600 only; 500 is
    // a tie, which goes to the heavier.
    expect((google.fontFamily, google.fontWeight), ('Inter', FontWeight.w600));
    expect(google.height! * google.fontSize!, closeTo(24, 1e-9));
  });

  testWidgets('a resize inside one breakpoint builds no text', (tester) async {
    setWindowSize(tester, const Size(400, 800));
    addTearDown(tester.view.reset);
    final styles = <TextStyle>[];

    await tester.pumpWidget(
      themedHost(WindowSizeScope(child: _probe(styles)), theme: theme),
    );
    for (var width = 401.0; width < 600; width += 7) {
      setWindowSize(tester, Size(width, 800));
      await tester.pump();
    }

    expect(styles, hasLength(1));
  });

  testWidgets('crossing a breakpoint rebuilds with the new font size', (
    tester,
  ) async {
    setWindowSize(tester, const Size(400, 800));
    addTearDown(tester.view.reset);
    final styles = <TextStyle>[];

    await tester.pumpWidget(
      themedHost(WindowSizeScope(child: _probe(styles)), theme: theme),
    );
    setWindowSize(tester, const Size(800, 1000));
    await tester.pump();

    expect(styles.map((style) => style.fontSize), [16, 17]);
  });

  testWidgets('a text scale change rebuilds with a new height', (tester) async {
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final styles = <TextStyle>[];

    await tester.pumpWidget(themedHost(_probe(styles), theme: theme));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    await tester.pump();

    expect(styles.map((style) => style.height), [24 / 17, 40 / 34]);
  });

  testWidgets("the application's own WindowSizeScope adds the window "
      'scale', (tester) async {
    setWindowSize(tester, const Size(1300, 800));
    addTearDown(tester.view.reset);
    final styles = <TextStyle>[];

    await tester.pumpWidget(themedHost(_probe(styles), theme: theme));

    expect(tester.takeException(), isNull);
    expect(styles.single.fontSize, 18);
  });

  testWidgets(
    'us01/s4: without a StratumThemeApplication it throws a FlutterError',
    (tester) async {
      await tester.pumpWidget(_probe(<TextStyle>[]));

      expect(
        tester.takeException(),
        isA<FlutterError>().having(
          (error) => error.message,
          'message',
          contains('StratumThemeApplication'),
        ),
      );
    },
  );

  testWidgets('the themeMode override reads the theme of that mode', (
    tester,
  ) async {
    final styles = <TextStyle>[];

    await tester.pumpWidget(
      StratumThemeApplication(
        themes: StratumThemeSet(
          light: theme,
          dark: _theme(body: 'geist'),
        ),
        themeMode: ThemeMode.light,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            children: [
              _probe(styles),
              _probe(styles, StratumTextStyle.body.darkTheme),
            ],
          ),
        ),
      ),
    );

    expect(styles.map((style) => style.fontFamily), ['Inter', 'Geist']);
  });

  testWidgets('the locale, windowSize, and textScaler overrides apply', (
    tester,
  ) async {
    final styles = <TextStyle>[];

    await tester.pumpWidget(
      themedHost(
        localized(
          const Locale('en'),
          Column(
            children: [
              _probe(styles, StratumTextStyle.body.locale(const Locale('th'))),
              _probe(
                styles,
                StratumTextStyle.body.windowSize(WindowSize.desktop),
              ),
              _probe(
                styles,
                StratumTextStyle.body.textScaler(const TextScaler.linear(2)),
              ),
            ],
          ),
        ),
        theme: theme,
      ),
    );

    expect(styles[0].fontFamily, 'Font A');
    expect(styles[1].fontSize, 18);
    expect(styles[2].height, 40 / 34);
  });
}
