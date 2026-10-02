import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/themes/behavior/scroll_behavior.dart';
import 'package:stratum_ui/src/themes/color/transparent.dart';
import 'package:stratum_ui/src/themes/constant/font_color.dart';
import 'package:stratum_ui/src/themes/theme_application.dart';
import 'package:stratum_ui/src/themes/theme_color.dart';
import 'package:stratum_ui/src/themes/theme_data.dart';
import 'package:stratum_ui/src/themes/typography/typography.dart';

/// Hover overlay color of [fakeTheme].
const fakeHover = Color(0x11000000);

/// Press overlay color of [fakeTheme].
const fakeActive = Color(0x22000000);

/// The text color a [FakeStratumTheme] gives each [FontColor].
const fakeTextColors = <FontColor, Color>{
  FontColor.brandPrimary: Color(0xFF0000A1),
  FontColor.brandSecondary: Color(0xFF0000A2),
  FontColor.brandTertiary: Color(0xFF0000A3),
  FontColor.primary: Color(0xFF000001),
  FontColor.primaryInverse: Color(0xFF000002),
  FontColor.primaryOnColor: Color(0xFF000003),
  FontColor.secondary: Color(0xFF000004),
  FontColor.secondaryInverse: Color(0xFF000005),
  FontColor.tertiary: Color(0xFF000006),
  FontColor.tertiaryInverse: Color(0xFF000007),
};

class _FakeTransparent extends Fake implements TransparentColors {
  @override
  Color get t0 => const Color(0x00000000);
}

class _FakeColors extends Fake implements BaseThemeColor {
  new(this.overlayHover, this.overlayActive);

  @override
  final Color overlayHover;

  @override
  final Color overlayActive;

  @override
  Color get borderBrand => const Color(0xFF0000FF);

  @override
  TransparentColors get transparent => _FakeTransparent();

  @override
  Color get brandPrimaryText => fakeTextColors[FontColor.brandPrimary]!;

  @override
  Color get brandSecondaryText => fakeTextColors[FontColor.brandSecondary]!;

  @override
  Color get brandTertiaryText => fakeTextColors[FontColor.brandTertiary]!;

  @override
  Color get textPrimary => fakeTextColors[FontColor.primary]!;

  @override
  Color get textPrimaryInverse => fakeTextColors[FontColor.primaryInverse]!;

  @override
  Color get textPrimaryOnColor => fakeTextColors[FontColor.primaryOnColor]!;

  @override
  Color get textSecondary => fakeTextColors[FontColor.secondary]!;

  @override
  Color get textSecondaryInverse => fakeTextColors[FontColor.secondaryInverse]!;

  @override
  Color get textTertiary => fakeTextColors[FontColor.tertiary]!;

  @override
  Color get textTertiaryInverse => fakeTextColors[FontColor.tertiaryInverse]!;
}

/// A theme that answers only what the interaction widgets, the scroll
/// views, and the text styles read.
class FakeStratumTheme extends Fake implements StratumThemeData {
  new({
    Color hover = fakeHover,
    Color active = fakeActive,
    this.scrollBehavior = const StratumScrollBehavior(),
    this.physics = const ClampingScrollPhysics(),
    this.typography = const StratumTypography(
      fonts: {},
      families: {},
      types: {},
    ),
  }) : color = _FakeColors(hover, active);

  @override
  final BaseThemeColor color;

  @override
  final StratumTypography typography;

  @override
  final ScrollBehavior scrollBehavior;

  @override
  final ScrollPhysics physics;
}

/// The default theme of [themedHost].
final fakeTheme = FakeStratumTheme();

/// Places [child] in a [Center] under a [StratumThemeApplication] and a
/// [Directionality].
Widget themedHost(
  Widget child, {
  StratumThemeData? theme,
  TextDirection textDirection = TextDirection.ltr,
}) {
  return StratumThemeApplication(
    themeMode: ThemeMode.light,
    lightTheme: theme ?? fakeTheme,
    darkTheme: null,
    child: Directionality(
      textDirection: textDirection,
      child: Center(child: child),
    ),
  );
}
