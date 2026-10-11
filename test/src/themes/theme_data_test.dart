import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import '../components/common/fakes/fake_stratum_theme.dart';

StratumThemeData _withApp() => fakeTheme.copyWith(
  appColors: const {
    'mango': Color(0xFFFFAA00),
    'brand-accent': Color(0xFF112233),
  },
  appPalettes: const {
    'mint': {'500': Color(0xFF00FF88), '600': Color(0xFF00CC66)},
  },
);

void main() {
  group('app colors', () {
    test('appColor and maybeAppColor read color.<set>.app', () {
      final data = _withApp();

      expect(data.appColor('mango'), const Color(0xFFFFAA00));
      expect(data.maybeAppColor('mango'), const Color(0xFFFFAA00));
      expect(data.maybeAppColor('promo-banner'), isNull);
    });

    test('an unknown app color throws, listing the names', () {
      const message =
          'no app color "promo-banner"; this theme has: brand-accent, mango';

      expect(
        () => _withApp().appColor('promo-banner'),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            message,
          ),
        ),
      );
      expect(
        () => fakeTheme.appColor('x'),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            'no app color "x"; this theme has: none',
          ),
        ),
      );
    });

    test('appPalette and shade read palette.app, and throw listing the '
        'names', () {
      final data = _withApp();

      expect(data.appPalette('mint').shade('500'), const Color(0xFF00FF88));
      expect(data.appPalette('mint').name, 'mint');
      expect(
        () => data.appPalette('kiwi'),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            'no app palette "kiwi"; this theme has: mint',
          ),
        ),
      );
      expect(
        () => data.appPalette('mint').shade('950'),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            'no shade "950" in app palette "mint"; it has: 500, 600',
          ),
        ),
      );
    });
  });

  group('copyWith', () {
    test('with no argument keeps every field', () {
      final data = fakeTheme;
      final copy = data.copyWith();

      expect(copy.color, same(data.color));
      expect(copy.physics, same(data.physics));
      expect(copy.animation, same(data.animation));
      expect(copy.opacity, same(data.opacity));
      expect(copy.border, same(data.border));
      expect(copy.shadow, same(data.shadow));
      expect(copy.blur, same(data.blur));
    });

    test('covers every field, physics included', () {
      final base = defaultThemeSet.light;
      final other = defaultThemeSet.dark!;
      const typography = StratumTypography(
        fonts: {'geist': StratumFontData(family: 'Geist')},
        families: {},
        types: {},
      );
      final animation = motionTheme().animation;
      final opacity = StratumOpacityTokens.fromMap(const {
        'disabled': 0.3,
        'scrim': 0.5,
      });
      const transparent = StratumTransparentTokens.builtIn;
      const space = {'md': StratumByWindowSize.all(StratumDimension.fixed(1))};
      const radius = {'md': StratumByWindowSize.all(StratumDimension.fixed(2))};
      const layouts = {
        'max': StratumByWindowSize.all(StratumDimension.fixed(3)),
      };
      const appColors = {'x': Color(0xFF000001)};
      const appPalettes = {
        'y': {'500': Color(0xFF000002)},
      };
      const extensions = <String, Object?>{'z': 1};
      final border = StratumBorderTokens.fromMap(const {
        'sm': 2,
        'md': 3,
        'lg': 4,
      });
      final shadow = other.shadow;
      final blur = StratumBlurTokens.fromMap({
        for (final level in ['1', '2', '3', '4', '5', '6'])
          level: const ImageBlurFilter(sigmaX: 1, sigmaY: 1),
      });
      const systemStyle = SystemStyle(statusBarIcons: SystemBarIcons.dark);
      const scrollBehavior = ScrollBehavior();
      const physics = BouncingScrollPhysics();

      final copy = base.copyWith(
        themeMode: ThemeMode.dark,
        color: other.color,
        palette: other.palette,
        transparent: transparent,
        space: space,
        radius: radius,
        layouts: layouts,
        appColors: appColors,
        appPalettes: appPalettes,
        assets: other.assets,
        extensions: extensions,
        typography: typography,
        animation: animation,
        opacity: opacity,
        defaultWidgetSize: WidgetSize.huge,
        border: border,
        shadow: shadow,
        blur: blur,
        systemStyle: systemStyle,
        splashFactory: InkRipple.splashFactory,
        scrollBehavior: scrollBehavior,
        physics: physics,
      );

      expect(copy.themeMode, ThemeMode.dark);
      expect(copy.color, same(other.color));
      expect(copy.palette, same(other.palette));
      expect(copy.transparent, same(transparent));
      expect(copy.space, same(space));
      expect(copy.radius, same(radius));
      expect(copy.layouts, same(layouts));
      expect(copy.appColors, same(appColors));
      expect(copy.appPalettes, same(appPalettes));
      expect(copy.assets, same(other.assets));
      expect(copy.extensions, same(extensions));
      expect(copy.typography, same(typography));
      expect(copy.animation, same(animation));
      expect(copy.opacity, same(opacity));
      expect(copy.defaultWidgetSize, WidgetSize.huge);
      expect(copy.border, same(border));
      expect(copy.shadow, same(shadow));
      expect(copy.blur, same(blur));
      expect(copy.systemStyle, systemStyle);
      expect(copy.splashFactory, same(InkRipple.splashFactory));
      expect(copy.scrollBehavior, same(scrollBehavior));
      expect(copy.physics, same(physics));
    });
  });
}
