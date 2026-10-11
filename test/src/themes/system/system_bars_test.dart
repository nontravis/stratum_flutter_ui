import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';
import 'package:stratum_ui/src/themes/system/system_bars.dart';
import 'package:stratum_ui/src/themes/system/system_style_region.dart';

const _white = Color(0xFFFFFFFF);
const _black = Color(0xFF000000);

/// The package default's light look over a white page background.
const _base = SystemStyleBaseRegion(
  style: SystemStyle(
    statusBarIcons: SystemBarIcons.auto,
    statusBarColor: Color(0x00000000),
    statusBarContrast: false,
    navigationBarIcons: SystemBarIcons.auto,
    navigationBarColor: Color(0x00000000),
    navigationBarDividerColor: Color(0x00000000),
    navigationBarContrast: true,
    appSwitcherColor: _white,
  ),
  background: _white,
);

void main() {
  group('pickLightIcons', () {
    test('us14/fr02, NFR-U07: light icons on a dark fill, dark icons on a '
        'light fill', () {
      expect(pickLightIcons(const Color(0xFF101010)), isTrue);
      expect(pickLightIcons(_white), isFalse);
      expect(pickLightIcons(const Color(0xFFFFEB3B)), isFalse);
      expect(pickLightIcons(const Color(0xFF1565C0)), isTrue);
    });

    test('us14/fr02, NFR-U07: the pick holds the higher contrast, so at '
        'least 3:1 on every opaque gray', () {
      for (var level = 0; level <= 255; level++) {
        final fill = Color.fromARGB(255, level, level, level);
        final icon = pickLightIcons(fill) ? _white : _black;
        final other = pickLightIcons(fill) ? _black : _white;

        expect(
          contrastRatio(icon, fill),
          greaterThanOrEqualTo(contrastRatio(other, fill)),
          reason: '$level',
        );
        expect(
          contrastRatio(icon, fill),
          greaterThanOrEqualTo(3),
          reason: '$level',
        );
      }
    });
  });

  group('resolveSystemBars', () {
    test('gives null with no Stratum theme under the bar', () {
      expect(resolveSystemBars(const [SystemBarFillRegion(_black)]), isNull);
    });

    test('us14/fr02/e03: no fill takes the page background', () {
      final bars = resolveSystemBars(const [_base], navigation: const [_base])!;

      expect(bars.overlay.statusBarIconBrightness, Brightness.dark);
      expect(bars.overlay.statusBarBrightness, Brightness.light);
      expect(bars.overlay.systemNavigationBarIconBrightness, Brightness.dark);
      expect(bars.overlay.statusBarColor, const Color(0x00000000));
      expect(bars.overlay.systemStatusBarContrastEnforced, isFalse);
      expect(bars.overlay.systemNavigationBarContrastEnforced, isTrue);
      expect(bars.barMode, SystemBarMode.edgeToEdge);
      expect(bars.orientations, isEmpty);
      expect(bars.appSwitcherLabel, isNull);
      expect(bars.appSwitcherColor, _white);
    });

    test('us14/fr02/e01: a dark opaque fill under the status bar gives '
        'light icons', () {
      final bars = resolveSystemBars(const [
        SystemBarFillRegion(Color(0xFF101010)),
        _base,
      ])!;

      expect(bars.overlay.statusBarIconBrightness, Brightness.light);
      expect(bars.overlay.statusBarBrightness, Brightness.dark);
    });

    test('us14/fr02/e02: a translucent scrim blends over the fill beneath '
        'it', () {
      const header = SystemBarFillRegion(_white);
      const scrim = SystemBarFillRegion(Color(0x99000000));

      expect(
        resolveSystemBars(const [header, _base])!
            .overlay
            .statusBarIconBrightness,
        Brightness.dark,
      );
      expect(
        resolveSystemBars(const [scrim, header, _base])!
            .overlay
            .statusBarIconBrightness,
        Brightness.light,
      );
      expect(
        resolveSystemBars(const [
          SystemBarFillRegion(Color(0x14000000)),
          header,
          _base,
        ])!.overlay.statusBarIconBrightness,
        Brightness.dark,
      );
    });

    test('us14/fr02/e04: an explicit value stands whatever the fills', () {
      final bars = resolveSystemBars(const [
        SystemStyleLayerRegion(
          SystemStyle(statusBarIcons: SystemBarIcons.dark),
        ),
        SystemUiOverlayStyle.light,
        SystemBarFillRegion(_black),
        _base,
      ])!;

      expect(bars.overlay.statusBarIconBrightness, Brightness.dark);
    });

    test('us14/fr02/e05: an app bar style counts as one fill by its own '
        'icons', () {
      const darkBar = SystemUiOverlayStyle(
        statusBarColor: Color(0x00000000),
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      );
      const lightBar = SystemUiOverlayStyle(
        statusBarIconBrightness: Brightness.dark,
      );

      expect(
        resolveSystemBars(const [darkBar, _base])!
            .overlay
            .statusBarIconBrightness,
        Brightness.light,
      );
      expect(
        resolveSystemBars(const [lightBar, SystemBarFillRegion(_black), _base])!
            .overlay
            .statusBarIconBrightness,
        Brightness.dark,
      );
      expect(
        resolveSystemBars(const [
          SystemBarFillRegion(Color(0x99000000)),
          lightBar,
          _base,
        ])!.overlay.statusBarIconBrightness,
        Brightness.light,
      );
    });

    test('us14/fr02/e05: an app bar style with an opaque color counts that '
        'color', () {
      const bar = SystemUiOverlayStyle(
        statusBarColor: Color(0xFF0D47A1),
        statusBarIconBrightness: Brightness.dark,
      );

      expect(
        resolveSystemBars(const [bar, _base])!.overlay.statusBarIconBrightness,
        Brightness.light,
      );
    });

    test('us14/fr01/e02: an inner layer sets the icons, the outer one the '
        'bar mode', () {
      final bars = resolveSystemBars(const [
        SystemStyleLayerRegion(
          SystemStyle(statusBarIcons: SystemBarIcons.light),
        ),
        SystemStyleLayerRegion(
          SystemStyle(
            statusBarIcons: SystemBarIcons.dark,
            barMode: SystemBarMode.immersive,
          ),
        ),
        _base,
      ])!;

      expect(bars.overlay.statusBarIconBrightness, Brightness.light);
      expect(bars.barMode, SystemBarMode.immersive);
    });

    test('us14/fr01: the topmost base wins over an outer one, its page '
        'background included', () {
      const inner = SystemStyleBaseRegion(
        style: SystemStyle(
          statusBarIcons: SystemBarIcons.auto,
          appSwitcherColor: Color(0xFF111827),
          appSwitcherLabel: 'Inner',
        ),
        background: Color(0xFF111827),
      );

      final bars = resolveSystemBars(const [inner, _base])!;

      expect(bars.overlay.statusBarIconBrightness, Brightness.light);
      expect(bars.appSwitcherColor, const Color(0xFF111827));
      expect(bars.appSwitcherLabel, 'Inner');
    });

    test('us14/fr02/e06: with no navigation point the navigation fields '
        'stay unset', () {
      final bars = resolveSystemBars(const [_base])!;
      final overlay = bars.overlay;

      expect(overlay.systemNavigationBarColor, isNull);
      expect(overlay.systemNavigationBarDividerColor, isNull);
      expect(overlay.systemNavigationBarIconBrightness, isNull);
      expect(overlay.systemNavigationBarContrastEnforced, isNull);
      expect(bars.navigationBarColor, isNull);
      expect(bars.navigationBarDividerColor, isNull);
    });

    test('us14/fr02: the navigation bar reads its own point', () {
      final bars = resolveSystemBars(
        const [_base],
        navigation: const [SystemBarFillRegion(Color(0xFF202020)), _base],
      )!;

      expect(bars.overlay.statusBarIconBrightness, Brightness.dark);
      expect(bars.overlay.systemNavigationBarIconBrightness, Brightness.light);
      expect(bars.overlay.systemNavigationBarColor, const Color(0x00000000));
    });

    test('us14/fr03: behavior merges top first over the app-wide style', () {
      const appWide = SystemStyleBaseRegion(
        style: SystemStyle(
          appSwitcherColor: _white,
          barMode: SystemBarMode.edgeToEdge,
          orientations: [DeviceOrientation.portraitUp],
          appSwitcherLabel: 'App',
        ),
        background: _white,
      );
      final bars = resolveSystemBars(const [
        SystemStyleLayerRegion(SystemStyle(appSwitcherLabel: 'Dialog')),
        SystemStyleLayerRegion(
          SystemStyle(
            barMode: SystemBarMode.immersiveSticky,
            orientations: [DeviceOrientation.landscapeLeft],
          ),
        ),
        appWide,
      ])!;

      expect(bars.barMode, SystemBarMode.immersiveSticky);
      expect(bars.orientations, [DeviceOrientation.landscapeLeft]);
      expect(bars.appSwitcherLabel, 'Dialog');
    });
  });

  group('us14/fr01/e06: the bar colors the root paints', () {
    const painted = SystemStyleBaseRegion(
      style: SystemStyle(
        statusBarIcons: SystemBarIcons.auto,
        statusBarColor: Color(0xFF101828),
        statusBarContrast: true,
        navigationBarIcons: SystemBarIcons.auto,
        navigationBarColor: _white,
        navigationBarDividerColor: Color(0xFFFF0000),
        navigationBarContrast: false,
        appSwitcherColor: _white,
      ),
      background: _white,
    );

    test('us14/fr01/e06: the platform gets transparent bar colors, and the '
        'merged ones are left to paint', () {
      final bars = resolveSystemBars(
        const [painted],
        navigation: const [painted],
      )!;

      expect(bars.overlay.statusBarColor, const Color(0x00000000));
      expect(bars.overlay.systemNavigationBarColor, const Color(0x00000000));
      expect(
        bars.overlay.systemNavigationBarDividerColor,
        const Color(0x00000000),
      );
      expect(bars.overlay.systemStatusBarContrastEnforced, isTrue);
      expect(bars.overlay.systemNavigationBarContrastEnforced, isFalse);
      expect(bars.statusBarColor, const Color(0xFF101828));
      expect(bars.navigationBarColor, _white);
      expect(bars.navigationBarDividerColor, const Color(0xFFFF0000));
    });

    test('us14/fr02/e07: an opaque bar color is the topmost fill at its '
        'point', () {
      final bars = resolveSystemBars(
        const [SystemBarFillRegion(_white), painted],
        navigation: const [SystemBarFillRegion(_black), painted],
      )!;

      expect(bars.overlay.statusBarIconBrightness, Brightness.light);
      expect(bars.overlay.systemNavigationBarIconBrightness, Brightness.dark);
    });

    test('us14/fr02/e07: a page bar color blends over the fills beneath '
        'it', () {
      Brightness? icons(Color color) => resolveSystemBars([
        SystemStyleLayerRegion(SystemStyle(statusBarColor: color)),
        const SystemBarFillRegion(_white),
        _base,
      ])!.overlay.statusBarIconBrightness;

      expect(icons(const Color(0x99000000)), Brightness.light);
      expect(icons(const Color(0x14000000)), Brightness.dark);
    });
  });

  test('the Stratum regions compare by value', () {
    expect(
      const SystemBarFillRegion(_black),
      const SystemBarFillRegion(_black),
    );
    expect(
      const SystemBarFillRegion(_black),
      isNot(const SystemBarFillRegion(_white)),
    );
    expect(
      const SystemStyleLayerRegion(
        SystemStyle(barMode: SystemBarMode.leanBack),
      ),
      isNot(const SystemStyleLayerRegion(SystemStyle())),
    );
    expect(
      _base,
      isNot(SystemStyleBaseRegion(style: _base.style, background: _black)),
    );
    expect(
      const SystemBarFillRegion(_black),
      isNot(const SystemUiOverlayStyle()),
    );
  });
}
