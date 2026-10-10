import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/src.dart';

import '../components/common/fakes/fake_stratum_theme.dart';
import 'config/theme_fixtures.dart';

/// An app theme over the package default: app colors, an app ramp, an
/// asset slot, and extensions.
const _ocean = r'''
$schema: stratum-theme/v1.0.0
name: Ocean
assets:
  loading: images/loading.json
palette:
  app:
    mint: { 500: "#00FF88", 600: "#00CC66" }
color:
  light:
    app: { mango: "#FFAA00", brand-accent: "#112233" }
  dark:
    app: { mango: "#AA7700", brand-accent: "#445566" }
extensions:
  promo: { enabled: true }
''';

StratumThemeSet _oceanSet() => StratumThemeSet.fromConfig(
  StratumThemeConfig.parse(
    base: StratumThemeSource(
      id: 'stratum-default',
      folder: 'packages/stratum_ui/assets/themes/default',
      yaml: defaultThemeSource,
    ),
    layers: const [
      StratumThemeSource(id: 'ocean', folder: 'themes/ocean', yaml: _ocean),
    ],
  ),
);

void main() {
  group('StratumThemeSet.fromConfig', () {
    test('the package default gives four data, light, dark, light, dark', () {
      final set = defaultThemeSet;

      expect(
        [
          set.light.themeMode,
          set.dark?.themeMode,
          set.highContrastLight?.themeMode,
          set.highContrastDark?.themeMode,
        ],
        [ThemeMode.light, ThemeMode.dark, ThemeMode.light, ThemeMode.dark],
      );
    });

    test('each data reads its set through the generated classes', () {
      final set = defaultThemeSet;

      expect(set.light.color.brand.normal, const Color(0xFF3B82F6));
      expect(set.dark!.color.brand.normal, const Color(0xFF2563EB));
      expect(
        set.light.color.state.hover,
        defaultThemeConfig.color.light['state.hover'],
      );
      expect(
        set.dark!.color.text.defaults.primary,
        defaultThemeConfig.color.dark['text.default.primary'],
      );
      expect(
        set.light.color.transparent.p3Inverse,
        defaultThemeConfig.color.light['transparent.3-inverse'],
      );
      expect(
        set.light.palette.brand.c500,
        defaultThemeConfig.palette['brand.500'],
      );
      expect(set.light.transparent.black.p3, const Color(0x08000000));
    });

    test('the empty high-contrast overlays give the light and dark '
        'colors', () {
      final set = defaultThemeSet;
      final pairs = [
        (set.light, set.highContrastLight!),
        (set.dark!, set.highContrastDark!),
      ];

      for (final (base, contrast) in pairs) {
        expect(contrast.color.brand.normal, base.color.brand.normal);
        expect(
          contrast.color.text.defaults.secondary,
          base.color.text.defaults.secondary,
        );
        expect(
          contrast.color.background.defaults.normal,
          base.color.background.defaults.normal,
        );
      }
    });

    test('the four data share every group but the colors', () {
      final set = defaultThemeSet;
      final all = [
        set.light,
        set.dark!,
        set.highContrastLight!,
        set.highContrastDark!,
      ];

      for (final data in all.skip(1)) {
        expect(data.palette, same(set.light.palette));
        expect(data.space, same(set.light.space));
        expect(data.appPalettes, same(set.light.appPalettes));
        expect(data.animation, same(set.light.animation));
        expect(data.typography, same(set.light.typography));
        expect(data.opacity, same(set.light.opacity));
        expect(data.border, same(set.light.border));
        expect(data.blur, same(set.light.blur));
      }
      expect(set.light.animation, StratumAnimation.packageDefault);
      expect(set.light.opacity.disabled, 0.5);
    });

    test('app colors per set, app ramps shared, extensions, assets', () {
      final set = _oceanSet();

      expect(set.light.appColors, {
        'mango': const Color(0xFFFFAA00),
        'brand-accent': const Color(0xFF112233),
      });
      expect(set.dark!.appColor('mango'), const Color(0xFFAA7700));
      expect(set.highContrastDark!.appColor('mango'), const Color(0xFFAA7700));
      expect(set.light.appPalettes, {
        'mint': {
          '500': const Color(0xFF00FF88),
          '600': const Color(0xFF00CC66),
        },
      });
      expect(set.light.extensions, {
        'promo': {'enabled': true},
      });
      expect(
        set.light.assets.loading,
        const StratumThemeAsset(
          kind: StratumAssetKind.lottie,
          path: 'themes/ocean/images/loading.json',
        ),
      );
      expect(set.light.assets.splashScreen, isNull);
      expect(defaultThemeSet.light.extensions, isEmpty);
      expect(defaultThemeSet.light.assets.loading, isNull);
    });

    test('the section 7.10 defaults, the overlay styles swapped for dark', () {
      final set = defaultThemeSet;
      final light = set.light;

      expect(light.defaultWidgetSize, WidgetSize.medium);
      expect(light.splashFactory, same(NoSplash.splashFactory));
      expect(light.scrollBehavior, isA<StratumScrollBehavior>());
      expect(light.physics, isA<ClampingScrollPhysics>());
      expect(light.transparent, same(StratumTransparentTokens.builtIn));
      expect(light.systemOverlayStyle, AppSystemUI.light);
      expect(light.systemOverlayInverseStyle, AppSystemUI.dark);
      expect(set.highContrastLight!.systemOverlayStyle, AppSystemUI.light);
      expect(set.dark!.systemOverlayStyle, AppSystemUI.dark);
      expect(set.dark!.systemOverlayInverseStyle, AppSystemUI.light);
      expect(set.highContrastDark!.systemOverlayStyle, AppSystemUI.dark);
    });

    test('a config over a small base throws an ArgumentError naming the '
        'first path the generated classes need', () {
      final config = StratumThemeConfig.parse(base: sources(const []).single);

      expect(
        () => StratumThemeSet.fromConfig(config),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.invalidValue,
            'invalidValue',
            'background.color.blue',
          ),
        ),
      );
    });

    test('fo08/us07/fr01/e02: an app theme that sets opacity.disabled to '
        '0.3 gives every data 0.3', () {
      final set = StratumThemeSet.fromConfig(
        StratumThemeConfig.parse(
          base: StratumThemeSource(
            id: 'stratum-default',
            folder: 'packages/stratum_ui/assets/themes/default',
            yaml: defaultThemeSource,
          ),
          layers: const [
            StratumThemeSource(
              id: 'dim',
              folder: 'themes/dim',
              yaml:
                  '\$schema: stratum-theme/v1.1.0\n'
                  'opacity:\n'
                  '  disabled: 0.3\n',
            ),
          ],
        ),
      );

      expect(set.light.opacity.disabled, 0.3);
      expect(set.dark!.opacity.disabled, 0.3);
      expect(set.highContrastDark!.opacity.disabled, 0.3);
    });

    test('fo08/us07/fr01/e03: an app theme that leaves opacity out gives '
        '0.5', () {
      expect(_oceanSet().light.opacity.disabled, 0.5);
    });

    test('us10/fr01: border, shadow, and blur come from the theme file at '
        'the Figma values', () {
      final light = defaultThemeSet.light;
      final levels = [
        light.shadow.level1,
        light.shadow.level2,
        light.shadow.level3,
        light.shadow.level4,
        light.shadow.level5,
        light.shadow.level6,
      ];
      const ambient = [
        (1.0, 1.0),
        (4.0, 4.0),
        (8.0, 8.0),
        (12.0, 12.0),
        (24.0, 16.0),
        (40.0, 32.0),
      ];

      expect(
        [light.border.sm, light.border.md, light.border.lg],
        [0.5, 1, 1.5],
      );
      expect(
        [
          light.blur.level1,
          light.blur.level2,
          light.blur.level3,
          light.blur.level4,
          light.blur.level5,
          light.blur.level6,
        ],
        [
          for (final sigma in [2.0, 4.0, 8.0, 12.0, 20.0, 40.0])
            ImageBlurFilter(sigmaX: sigma, sigmaY: sigma),
        ],
      );
      for (final (index, layers) in levels.indexed) {
        final (y, sigma) = ambient[index];
        final reason = 'level${index + 1}';
        expect(layers, hasLength(2), reason: reason);
        expect(layers[0].offset, Offset(0, y), reason: reason);
        expect(layers[0].spreadRadius, 0, reason: reason);
        expect(layers[0].blurSigma, sigma, reason: reason);
        expect(layers[1].offset, Offset.zero, reason: reason);
        expect(layers[1].blurSigma, 0.5, reason: reason);
      }
    });

    test('us10/fr01: each data colors its shadows from its own set', () {
      final set = defaultThemeSet;
      List<Color> colorsOf(StratumThemeData data) => [
        for (final shadow in data.shadow.level2) shadow.color,
      ];

      expect(colorsOf(set.light), const [Color(0x1F000000), Color(0x26000000)]);
      expect(colorsOf(set.dark!), const [Color(0x59000000), Color(0x73000000)]);
      expect(colorsOf(set.highContrastLight!), colorsOf(set.light));
      expect(colorsOf(set.highContrastDark!), colorsOf(set.dark!));
    });

    test('us10/fr01: a high-contrast overlay of color.<set>.shadow reaches '
        "that set's shadows only", () {
      final set = StratumThemeSet.fromConfig(
        StratumThemeConfig.parse(
          base: const StratumThemeSource(
            id: 'stratum-default',
            folder: 'packages/stratum_ui/assets/themes/default',
            yaml: defaultThemeSource,
          ),
          layers: const [
            StratumThemeSource(
              id: 'contrast',
              folder: 'themes/contrast',
              yaml:
                  '\$schema: stratum-theme/v1.0.0\n'
                  'color:\n'
                  '  highContrastDark:\n'
                  '    shadow:\n'
                  '      primary: "#FF0000"\n',
            ),
          ],
        ),
      );

      expect(
        set.highContrastDark!.shadow.level1[1].color,
        const Color(0xFFFF0000),
      );
      expect(
        set.highContrastDark!.shadow.level1[0].color,
        const Color(0x59000000),
      );
      expect(set.dark!.shadow.level1[1].color, const Color(0x73000000));
    });

    test('us10/fr01, fo01/us04/fr01/e05: an app theme that sets a level to '
        '[] gives that level no shadow', () {
      final set = StratumThemeSet.fromConfig(
        StratumThemeConfig.parse(
          base: const StratumThemeSource(
            id: 'stratum-default',
            folder: 'packages/stratum_ui/assets/themes/default',
            yaml: defaultThemeSource,
          ),
          layers: const [
            StratumThemeSource(
              id: 'flat',
              folder: 'themes/flat',
              yaml: '\$schema: stratum-theme/v1.2.0\nshadow:\n  "3": []\n',
            ),
          ],
        ),
      );

      expect(set.light.shadow.level3, isEmpty);
      expect(set.light.shadow.level2, hasLength(2));
    });

    test('us10/fr01: a hand-built config whose layer names a color its set '
        'lacks throws an ArgumentError naming the path', () {
      final config = defaultThemeConfig.copyWith(
        shadow: {
          ...defaultThemeConfig.shadow,
          '1': const [
            StratumShadowLayer(
              x: 0,
              y: 1,
              blur: 2,
              spread: 0,
              color: StratumSetLayerColor('shadow.tertiary'),
            ),
          ],
        },
      );

      expect(
        () => StratumThemeSet.fromConfig(config),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.invalidValue,
            'invalidValue',
            'shadow.tertiary',
          ),
        ),
      );
    });
  });

  group('StratumThemeSet.pick', () {
    final light = fakeTheme;
    final dark = fakeTheme.copyWith(themeMode: ThemeMode.dark);
    final contrastLight = fakeTheme.copyWith();
    final contrastDark = dark.copyWith();

    List<StratumThemeData> picks(StratumThemeSet set) => [
      set.pick(dark: false, highContrast: false),
      set.pick(dark: true, highContrast: false),
      set.pick(dark: false, highContrast: true),
      set.pick(dark: true, highContrast: true),
    ];

    test('a full set picks each member', () {
      final set = StratumThemeSet(
        light: light,
        dark: dark,
        highContrastLight: contrastLight,
        highContrastDark: contrastDark,
      );

      expect(picks(set), [light, dark, contrastLight, contrastDark]);
    });

    test('pick falls back for every missing member', () {
      expect(picks(StratumThemeSet(light: light)), [
        light,
        light,
        light,
        light,
      ]);
      expect(picks(StratumThemeSet(light: light, dark: dark)), [
        light,
        dark,
        light,
        dark,
      ]);
      expect(
        picks(StratumThemeSet(light: light, highContrastDark: contrastDark)),
        [light, light, light, contrastDark],
      );
    });
  });

  test('two sets are equal when each member is the same instance', () {
    final light = fakeTheme;

    expect(StratumThemeSet(light: light), StratumThemeSet(light: light));
    expect(
      StratumThemeSet(light: light).hashCode,
      StratumThemeSet(light: light).hashCode,
    );
    expect(
      StratumThemeSet(light: light),
      isNot(StratumThemeSet(light: light.copyWith())),
    );
  });
}
