import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import '../components/common/fakes/fake_stratum_theme.dart';

class _Probe extends StratumStatelessWidget {
  const new({super.customStyle});

  @override
  Widget build(BuildContext context) => const SizedBox();
}

class _SubProbe extends _Probe {
  const new();
}

const _red = Color(0xFFFF0000);
const _blue = Color(0xFF0000FF);
const _green = Color(0xFF00FF00);

/// The component's own style: padding, opacity, and a fill.
const _own = WidgetStyle(
  padding: EdgeInsets.all(8),
  opacity: 0.5,
  backgroundColor: _red,
);

/// Resolves [probe] against [_own] in a build under [wrap], when given.
Future<WidgetStyle> _resolve(
  WidgetTester tester,
  StratumWidgetProps probe, {
  Widget Function(Widget child)? wrap,
}) async {
  late WidgetStyle style;
  final reader = Builder(
    builder: (context) {
      style = probe.resolveStyle(context, _own);
      return const SizedBox();
    },
  );
  await tester.pumpWidget(wrap == null ? reader : wrap(reader));
  return style;
}

Widget Function(Widget child) _app(
  StratumComponentDefaultsBuilder? defaults, {
  ThemeMode themeMode = ThemeMode.light,
}) =>
    (child) => StratumThemeApplication(
      themes: StratumThemeSet(
        light: fakeTheme,
        dark: fakeTheme.copyWith(
          themeMode: ThemeMode.dark,
          color: defaultThemeSet.dark!.color,
        ),
      ),
      themeMode: themeMode,
      componentDefaults: defaults,
      child: child,
    );

void main() {
  group('fr01: StratumWidgetProps.resolveStyle layers', () {
    testWidgets('own, then app-wide, then customStyle, each replacing only '
        'its fields', (tester) async {
      final style = await _resolve(
        tester,
        const _Probe(customStyle: WidgetStyle(backgroundColor: _green)),
        wrap: _app(
          (theme) => {
            _Probe: const WidgetStyle(opacity: 0.8, backgroundColor: _blue),
          },
        ),
      );

      expect(style.padding, const EdgeInsets.all(8));
      expect(style.opacity, 0.8);
      expect(style.backgroundColor, _green);
    });

    testWidgets('fr01/e01: no entry for the type leaves own and '
        'customStyle', (tester) async {
      final style = await _resolve(
        tester,
        const _Probe(customStyle: WidgetStyle(opacity: 1)),
        wrap: _app((theme) => {_SubProbe: const WidgetStyle(opacity: 0.1)}),
      );

      expect(style.opacity, 1);
      expect(style.backgroundColor, _red);
    });

    testWidgets('G14: a subclass gets the entry of its own type only', (
      tester,
    ) async {
      final style = await _resolve(
        tester,
        const _SubProbe(),
        wrap: _app((theme) => {_Probe: const WidgetStyle(opacity: 0.1)}),
      );

      expect(style.opacity, 0.5);
    });

    testWidgets('with no application the defaults and customStyle apply', (
      tester,
    ) async {
      final style = await _resolve(
        tester,
        const _Probe(customStyle: WidgetStyle(opacity: 1)),
      );

      expect(style.opacity, 1);
      expect(style.padding, const EdgeInsets.all(8));
    });

    testWidgets('returns the defaults themselves when no layer sets a '
        'field', (tester) async {
      final style = await _resolve(tester, const _Probe());

      expect(style, same(_own));
    });
  });

  group('StratumComponentDefaults', () {
    testWidgets('D5: the map follows the active theme', (tester) async {
      Map<Type, WidgetStyle> defaults(StratumTheme theme) => {
        _Probe: WidgetStyle(backgroundColor: theme.color.brand.normal),
      };

      final light = await _resolve(
        tester,
        const _Probe(),
        wrap: _app(defaults),
      );
      final dark = await _resolve(
        tester,
        const _Probe(),
        wrap: _app(defaults, themeMode: ThemeMode.dark),
      );

      expect(light.backgroundColor, fakeTheme.color.brand.normal);
      expect(dark.backgroundColor, defaultThemeSet.dark!.color.brand.normal);
    });

    testWidgets('an equal map from a new closure rebuilds no component', (
      tester,
    ) async {
      var builds = 0;
      final reader = Builder(
        builder: (context) {
          builds++;
          StratumComponentDefaults.of<_Probe>(context);
          return const SizedBox();
        },
      );
      for (var pump = 0; pump < 2; pump++) {
        await tester.pumpWidget(
          _app((theme) => {_Probe: const WidgetStyle(opacity: 0.8)})(reader),
        );
      }

      expect(builds, 1);
    });

    testWidgets('of<T> is null with no application or no entry', (
      tester,
    ) async {
      WidgetStyle? alone;
      WidgetStyle? missing;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            alone = StratumComponentDefaults.of<_Probe>(context);
            return const SizedBox();
          },
        ),
      );
      await tester.pumpWidget(
        _app(null)(
          Builder(
            builder: (context) {
              missing = StratumComponentDefaults.of<_Probe>(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect((alone, missing), (null, null));
    });
  });
}
