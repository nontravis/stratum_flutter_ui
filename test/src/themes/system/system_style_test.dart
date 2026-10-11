import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/themes/system/system_style.dart';

const _full = SystemStyle(
  statusBarIcons: SystemBarIcons.auto,
  statusBarColor: Color(0x00000000),
  statusBarContrast: false,
  navigationBarIcons: SystemBarIcons.auto,
  navigationBarColor: Color(0x00000000),
  navigationBarDividerColor: Color(0x00000000),
  navigationBarContrast: true,
  appSwitcherColor: Color(0xFFFFFFFF),
  barMode: SystemBarMode.edgeToEdge,
  orientations: [DeviceOrientation.portraitUp],
  appSwitcherLabel: 'Home',
);

void main() {
  group('SystemStyle', () {
    test('us14/fr01: a field the upper layer leaves null keeps the lower '
        'value; a set field replaces it', () {
      const lower = SystemStyle(
        statusBarColor: Color(0xFF112233),
        navigationBarColor: Color(0xFF445566),
      );
      const upper = SystemStyle(navigationBarColor: Color(0xFF778899));
      final merged = lower.merge(upper);
      expect(merged.statusBarColor, const Color(0xFF112233));
      expect(merged.navigationBarColor, const Color(0xFF778899));
    });

    test('us14/fr01/e01: the theme sets the status bar color and the app '
        'sets only the navigation bar color', () {
      const theme = SystemStyle(
        statusBarColor: Color(0xFF000001),
        navigationBarColor: Color(0xFF000002),
      );
      const app = SystemStyle(navigationBarColor: Color(0xFF000003));
      final merged = theme.merge(app);
      expect(merged.statusBarColor, const Color(0xFF000001));
      expect(merged.navigationBarColor, const Color(0xFF000003));
    });

    test('us14/fr01/e02: an inner style sets the icons, the outer the bar '
        'mode', () {
      const outer = SystemStyle(
        statusBarIcons: SystemBarIcons.light,
        barMode: SystemBarMode.immersive,
      );
      const inner = SystemStyle(statusBarIcons: SystemBarIcons.dark);
      final merged = const SystemStyle().merge(outer).merge(inner);
      expect(merged.statusBarIcons, SystemBarIcons.dark);
      expect(merged.barMode, SystemBarMode.immersive);
    });

    test('us14/fr01: every field merges, and merge(null) is the same '
        'style', () {
      expect(const SystemStyle().merge(_full), _full);
      expect(_full.merge(const SystemStyle()), _full);
      expect(_full.merge(null), same(_full));
    });

    test('us14/fr01: an empty orientation list replaces a lock whole', () {
      const locked = SystemStyle(orientations: [DeviceOrientation.portraitUp]);
      const unlocked = SystemStyle(orientations: []);
      expect(locked.merge(unlocked).orientations, isEmpty);
    });

    test('us14/fr01: look keeps the eight theme-file fields, behavior the '
        'three Dart-only fields', () {
      expect(
        _full.look,
        const SystemStyle(
          statusBarIcons: SystemBarIcons.auto,
          statusBarColor: Color(0x00000000),
          statusBarContrast: false,
          navigationBarIcons: SystemBarIcons.auto,
          navigationBarColor: Color(0x00000000),
          navigationBarDividerColor: Color(0x00000000),
          navigationBarContrast: true,
          appSwitcherColor: Color(0xFFFFFFFF),
        ),
      );
      expect(
        _full.behavior,
        const SystemStyle(
          barMode: SystemBarMode.edgeToEdge,
          orientations: [DeviceOrientation.portraitUp],
          appSwitcherLabel: 'Home',
        ),
      );
      expect(_full.look.merge(_full.behavior), _full);
    });

    test('equal by value, the orientation list included', () {
      final orientations = [DeviceOrientation.landscapeLeft];
      expect(
        const SystemStyle(orientations: [DeviceOrientation.landscapeLeft]),
        SystemStyle(orientations: orientations),
      );
      expect(
        const SystemStyle(barMode: SystemBarMode.topOnly),
        isNot(const SystemStyle(barMode: SystemBarMode.bottomOnly)),
      );
    });

    test('d11: the bar modes and the icon values, in order', () {
      expect(SystemBarMode.values.map((mode) => mode.name), [
        'edgeToEdge',
        'immersive',
        'immersiveSticky',
        'leanBack',
        'topOnly',
        'bottomOnly',
      ]);
      expect(SystemBarIcons.values.map((icons) => icons.name), [
        'auto',
        'light',
        'dark',
      ]);
    });
  });
}
