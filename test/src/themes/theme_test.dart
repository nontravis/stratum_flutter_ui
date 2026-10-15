import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import '../components/common/fakes/fake_stratum_theme.dart';

/// The package default with `space.md` varying (16 on mobile, 32 on
/// desktop) and `layouts.max-width-content` at 80%.
final StratumThemeData _data = StratumThemeSet.fromConfig(
  StratumThemeConfig.parse(
    base: const StratumThemeSource(
      id: 'stratum-default',
      folder: 'packages/stratum_ui/assets/themes/default',
      yaml: defaultThemeSource,
    ),
    layers: const [
      StratumThemeSource(
        id: 'app',
        folder: 'themes/app',
        yaml:
            r'$schema: stratum-theme/v1.0.0'
            '\nspace:\n  md: { mobile: 16, desktop: 32 }\n'
            'layouts:\n  max-width-content: 80%',
      ),
    ],
  ),
).light;

void _setWidth(WidgetTester tester, double width) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 800);
}

/// [read] in a builder under an application of [_data], inside a
/// [WindowSizeScope] when [scope] is set.
Widget _host(void Function(StratumTheme theme) read, {bool scope = true}) {
  final reader = Builder(
    builder: (context) {
      read(StratumTheme.of(context));
      return const SizedBox();
    },
  );
  return StratumThemeApplication(
    themes: StratumThemeSet(light: _data),
    themeMode: ThemeMode.light,
    child: scope ? WindowSizeScope(child: reader) : reader,
  );
}

void main() {
  group('fo03/us09/fr01: StratumTheme dimension reads', () {
    final cases = <(double, double)>[
      (400, 16),
      (900, 16),
      (1300, 32),
      (1700, 32),
    ];
    for (final (width, expected) in cases) {
      testWidgets(
        'fo03/us09/s1, fo03/us09/s2: a varying token on a $width px window reads $expected',
        (tester) async {
          _setWidth(tester, width);
          addTearDown(tester.view.reset);
          double? md;

          await tester.pumpWidget(_host((theme) => md = theme.space.md));

          expect(md, expected);
        },
      );
    }

    testWidgets('a uniform token reads no WindowSizeScope', (tester) async {
      double? xs2;
      double? full;

      await tester.pumpWidget(
        _host((theme) {
          xs2 = theme.space.xs2;
          full = theme.radius.full;
        }, scope: false),
      );

      expect(tester.takeException(), isNull);
      expect((xs2, full), (8, 999));
    });

    testWidgets('a layouts percent is that share of the window width', (
      tester,
    ) async {
      _setWidth(tester, 1000);
      addTearDown(tester.view.reset);
      double? content;
      double? read;

      await tester.pumpWidget(
        _host((theme) {
          content = theme.layouts.maxWidthContent;
          read = theme.layouts.maxWidthRead;
        }),
      );

      expect((content, read), (800, 720));
    });

    testWidgets('fr01/e01: with no scope of its own, the application '
        "body's scope serves a varying token", (tester) async {
      _setWidth(tester, 1300);
      addTearDown(tester.view.reset);
      double? md;

      await tester.pumpWidget(
        _host((theme) => md = theme.space.md, scope: false),
      );

      expect(tester.takeException(), isNull);
      expect(md, 32);
    });

    testWidgets('a token the data lacks throws an ArgumentError naming it', (
      tester,
    ) async {
      await tester.pumpWidget(
        StratumThemeApplication(
          themes: StratumThemeSet(light: fakeTheme.copyWith(space: const {})),
          themeMode: ThemeMode.light,
          child: Builder(
            builder: (context) {
              StratumTheme.of(context).space.md;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(
        tester.takeException(),
        isA<ArgumentError>().having(
          (error) => error.invalidValue,
          'invalidValue',
          'space.md',
        ),
      );
    });

    testWidgets('a view kept across a resize reads the new window size', (
      tester,
    ) async {
      _setWidth(tester, 400);
      addTearDown(tester.view.reset);
      late StratumTheme kept;
      await tester.pumpWidget(_host((theme) => kept = theme));

      _setWidth(tester, 1300);
      await tester.pump();

      expect(kept.space.md, 32);
    });
  });

  testWidgets('fo01/us01/fr01: the sheet radius token reads 40 on the '
      'default light theme', (tester) async {
    double? sheet;

    await tester.pumpWidget(
      StratumThemeApplication(
        themes: StratumThemeSet(light: defaultThemeSet.light),
        themeMode: ThemeMode.light,
        child: Builder(
          builder: (context) {
            sheet = StratumTheme.of(context).radius.sheet;
            return const SizedBox();
          },
        ),
      ),
    );

    expect(sheet, 40);
  });

  group('rebuilds on resize', () {
    Future<int> resizes(
      WidgetTester tester,
      void Function(StratumTheme theme) read,
      List<double> widths,
    ) async {
      _setWidth(tester, 400);
      addTearDown(tester.view.reset);
      var builds = 0;
      await tester.pumpWidget(
        _host((theme) {
          builds++;
          read(theme);
        }),
      );
      for (final width in widths) {
        _setWidth(tester, width);
        await tester.pump();
      }
      return builds - 1;
    }

    testWidgets('a reader of colors only rebuilds 0 times', (tester) async {
      expect(
        await resizes(tester, (theme) => theme.color.brand.normal, [500, 1300]),
        0,
      );
    });

    testWidgets('a reader of a varying token rebuilds once per breakpoint '
        'crossing', (tester) async {
      expect(await resizes(tester, (theme) => theme.space.md, [500, 1300]), 1);
    });

    testWidgets('a reader of a percent rebuilds on every width change', (
      tester,
    ) async {
      expect(
        await resizes(tester, (theme) => theme.layouts.maxWidthContent, [
          500,
          550,
        ]),
        2,
      );
    });

    testWidgets('a reader of a uniform token rebuilds 0 times', (tester) async {
      expect(await resizes(tester, (theme) => theme.space.xs2, [500, 1300]), 0);
    });

    testWidgets('a reader of animation only rebuilds 0 times', (tester) async {
      expect(
        await resizes(tester, (theme) => theme.animation.fast, [500, 1300]),
        0,
      );
    });
  });

  testWidgets(
    'fo03/us07/s1, fo03/us07/fr01: the view forwards the data, and context.theme is the view',
    (tester) async {
      late StratumTheme theme;
      late StratumTheme fromContext;
      final data = fakeTheme.copyWith(
        appColors: const {'mango': Color(0xFFFFAA00)},
      );
      await tester.pumpWidget(
        StratumThemeApplication(
          themes: StratumThemeSet(light: data),
          themeMode: ThemeMode.light,
          child: Builder(
            builder: (context) {
              theme = StratumTheme.of(context);
              fromContext = context.theme;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(theme.data, same(data));
      expect(fromContext.data, same(data));
      expect(theme.color, same(data.color));
      expect(theme.palette, same(data.palette));
      expect(theme.transparent, same(data.transparent));
      expect(theme.animation, same(data.animation));
      expect(theme.assets, same(data.assets));
      expect(theme.extensions, same(data.extensions));
      expect(theme.typography, same(data.typography));
      expect(theme.appColor('mango'), const Color(0xFFFFAA00));
      expect(theme.maybeAppColor('kiwi'), isNull);
      expect(theme.themeMode, ThemeMode.light);
      expect(theme.physics, same(data.physics));
      expect(theme.defaultWidgetSize, data.defaultWidgetSize);
      expect(theme.border, same(data.border));
      expect(theme.shadow, same(data.shadow));
      expect(theme.blur, same(data.blur));
      expect(theme.systemStyle, same(data.systemStyle));
      expect(theme.focus, same(data.focus));
    },
  );

  testWidgets('maybeOf is null with no application', (tester) async {
    var built = false;
    StratumTheme? found;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          built = true;
          found = StratumTheme.maybeOf(context);
          return const SizedBox();
        },
      ),
    );

    expect(built, isTrue);
    expect(found, isNull);
  });

  test('StratumByWindowSize.isUniform', () {
    expect(
      const StratumByWindowSize.all(StratumDimension.fixed(8)).isUniform,
      isTrue,
    );
    expect(StratumByWindowSize(const {WindowSize.mobile: 1}).isUniform, isTrue);
    expect(
      StratumByWindowSize(const {WindowSize.mobile: 1, WindowSize.desktop: 2})
          .isUniform,
      isFalse,
    );
  });
}
