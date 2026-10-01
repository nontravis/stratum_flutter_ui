import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import '../components/common/fakes/fake_stratum_theme.dart';

final _light = FakeStratumTheme();
final _dark = FakeStratumTheme();

Widget _themed(ThemeMode mode, WidgetBuilder builder) {
  return StratumThemeApplication(
    themeMode: mode,
    lightTheme: _light,
    darkTheme: _dark,
    child: Builder(builder: builder),
  );
}

void main() {
  group('StratumThemeApplication.maybeOf', () {
    testWidgets('returns null without a theme', (tester) async {
      StratumThemeData? found = _light;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            found = StratumThemeApplication.maybeOf(context);
            return const SizedBox();
          },
        ),
      );
      expect(found, isNull);
    });

    testWidgets('returns the light theme in light mode', (tester) async {
      StratumThemeData? found;
      await tester.pumpWidget(
        _themed(ThemeMode.light, (context) {
          found = StratumThemeApplication.maybeOf(context);
          return const SizedBox();
        }),
      );
      expect(found, same(_light));
    });

    testWidgets('returns the dark theme in dark mode', (tester) async {
      StratumThemeData? found;
      await tester.pumpWidget(
        _themed(ThemeMode.dark, (context) {
          found = StratumThemeApplication.maybeOf(context);
          return const SizedBox();
        }),
      );
      expect(found, same(_dark));
    });

    testWidgets('follows the platform brightness in system mode',
        (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue =
          Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      StratumThemeData? found;
      await tester.pumpWidget(
        _themed(ThemeMode.system, (context) {
          found = StratumThemeApplication.maybeOf(context);
          return const SizedBox();
        }),
      );
      expect(found, same(_dark));
    });

    testWidgets('lets an explicit themeMode win', (tester) async {
      StratumThemeData? found;
      await tester.pumpWidget(
        _themed(ThemeMode.light, (context) {
          found = StratumThemeApplication.maybeOf(
            context,
            themeMode: ThemeMode.dark,
          );
          return const SizedBox();
        }),
      );
      expect(found, same(_dark));
    });
  });

  group('StratumThemeApplication.of', () {
    testWidgets('(pin) throws a FlutterError without a theme',
        (tester) async {
      Object? error;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            try {
              StratumThemeApplication.of(context);
            } on FlutterError catch (caught) {
              error = caught;
            }
            return const SizedBox();
          },
        ),
      );
      expect(error, isA<FlutterError>());
    });
  });
}
