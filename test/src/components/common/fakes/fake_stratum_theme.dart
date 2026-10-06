import 'dart:io';

import 'package:stratum_ui/src/src.dart';

/// Hover overlay color of [fakeTheme].
const fakeHover = Color(0x11000000);

/// Press overlay color of [fakeTheme].
const fakeActive = Color(0x22000000);

/// The `border.color.brand` color of [fakeTheme].
const fakeRing = Color(0xFF0000FF);

/// The text color a [fakeStratumTheme] gives each [FontColor]; the three
/// brand roles share `text.color.brand` (spec G28).
const fakeTextColors = <FontColor, Color>{
  FontColor.brandPrimary: Color(0xFF0000A1),
  FontColor.brandSecondary: Color(0xFF0000A1),
  FontColor.brandTertiary: Color(0xFF0000A1),
  FontColor.primary: Color(0xFF000001),
  FontColor.primaryInverse: Color(0xFF000002),
  FontColor.primaryOnColor: Color(0xFF000003),
  FontColor.secondary: Color(0xFF000004),
  FontColor.secondaryInverse: Color(0xFF000005),
  FontColor.tertiary: Color(0xFF000006),
  FontColor.tertiaryInverse: Color(0xFF000007),
};

/// The package default `theme.yaml`, read from disk.
final String defaultThemeSource = File('assets/themes/default/theme.yaml')
    .readAsStringSync();

/// The package default theme, parsed once per test file.
final StratumThemeConfig defaultThemeConfig = StratumThemeConfig.parse(
  base: StratumThemeSource(
    id: 'stratum-default',
    folder: 'packages/stratum_ui/assets/themes/default',
    yaml: defaultThemeSource,
  ),
);

/// The four theme data of [defaultThemeConfig].
final StratumThemeSet defaultThemeSet = StratumThemeSet.fromConfig(
  defaultThemeConfig,
);

/// The package default's light data with the overlay, ring, and text
/// colors the tests check laid over its color set.
StratumThemeData fakeStratumTheme({
  Color hover = fakeHover,
  Color active = fakeActive,
  ScrollBehavior scrollBehavior = const StratumScrollBehavior(),
  ScrollPhysics physics = const ClampingScrollPhysics(),
  StratumTypography? typography,
}) => defaultThemeSet.light.copyWith(
  color: StratumColorTokens.fromMap({
    ...defaultThemeConfig.color.light,
    'state.hover': hover,
    'state.press': active,
    'border.color.brand': fakeRing,
    'text.color.brand': fakeTextColors[FontColor.brandPrimary]!,
    'text.default.primary': fakeTextColors[FontColor.primary]!,
    'text.default.primary-inverse': fakeTextColors[FontColor.primaryInverse]!,
    'text.default.primary-on-color': fakeTextColors[FontColor.primaryOnColor]!,
    'text.default.secondary': fakeTextColors[FontColor.secondary]!,
    'text.default.secondary-inverse':
        fakeTextColors[FontColor.secondaryInverse]!,
    'text.default.tertiary': fakeTextColors[FontColor.tertiary]!,
    'text.default.tertiary-inverse': fakeTextColors[FontColor.tertiaryInverse]!,
  }),
  scrollBehavior: scrollBehavior,
  physics: physics,
  typography: typography,
);

/// The default theme of [themedHost].
final StratumThemeData fakeTheme = fakeStratumTheme();

/// [theme], else [fakeTheme], with its `fast` level at [fast], its `slow`
/// level at [slow], and [standard] as its standard curve; every other
/// animation value is the package default's.
StratumThemeData motionTheme({
  Duration fast = const Duration(milliseconds: 77),
  Duration slow = const Duration(milliseconds: 333),
  StratumCurve standard = const StratumNamedCurve('easeInOutSine'),
  StratumThemeData? theme,
}) {
  final config = defaultThemeConfig.animation;
  return (theme ?? fakeTheme).copyWith(
    animation: StratumAnimation.fromConfig(
      StratumAnimationConfig(
        durations: {...config.durations, 'fast': fast, 'slow': slow},
        defaultLevel: config.defaultLevel,
        reverseRatio: config.reverseRatio,
        curves: {...config.curves, 'standard': standard},
      ),
    ),
  );
}

/// Places [child] in a [Center] under a [StratumThemeApplication] of
/// [theme], else [fakeTheme], and a [Directionality].
Widget themedHost(
  Widget child, {
  StratumThemeData? theme,
  TextDirection textDirection = TextDirection.ltr,
}) {
  return StratumThemeApplication(
    themes: StratumThemeSet(light: theme ?? fakeTheme),
    themeMode: ThemeMode.light,
    child: Directionality(
      textDirection: textDirection,
      child: Center(child: child),
    ),
  );
}
