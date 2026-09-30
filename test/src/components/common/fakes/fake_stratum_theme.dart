import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/themes/color/transparent.dart';
import 'package:stratum_ui/src/themes/theme_application.dart';
import 'package:stratum_ui/src/themes/theme_color.dart';
import 'package:stratum_ui/src/themes/theme_data.dart';

/// Hover overlay color of [fakeTheme].
const fakeHover = Color(0x11000000);

/// Press overlay color of [fakeTheme].
const fakeActive = Color(0x22000000);

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
}

/// A theme that answers only what the interaction widgets read.
class FakeStratumTheme extends Fake implements StratumThemeData {
  new({Color hover = fakeHover, Color active = fakeActive})
    : color = _FakeColors(hover, active);

  @override
  final BaseThemeColor color;
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
