import 'package:stratum_ui/src/src.dart';
class StratumThemeData {
  const new({
    required this.defaultWidgetSize,
    required this.themeMode,
    required this.color,
    required this.borderRadius,
    required this.border,
    required this.shadow,
    required this.size,
    required this.filter,
    required this.systemOverlayStyle,
    required this.systemOverlayInverseStyle,
    required this.space,
    required this.splashFactory,
    required this.fonts,
    this.scrollBehavior = const StratumScrollBehavior(),
    this.physics = const ClampingScrollPhysics(),
    this.animation = const StratumThemeAnimation(),
    this.highContrastTheme,
    this.highContrastDarkTheme,
    this.screenBorderRadius,
  });

  final WidgetSize defaultWidgetSize;
  final ThemeMode themeMode;
  final BaseThemeColor color;
  final AppBorder border;
  final AppRadius borderRadius;
  final AppShadow shadow;
  final AppFilter filter;
  final AppSpace space;
  final AppSize size;
  final SystemUiOverlayStyle systemOverlayStyle;
  final SystemUiOverlayStyle systemOverlayInverseStyle;
  final InteractiveInkFeatureFactory splashFactory;
  final List<AppFont> fonts;
  final ScrollBehavior scrollBehavior;
  final ScrollPhysics physics;
  final StratumThemeAnimation animation;
  final StratumThemeData? highContrastTheme;
  final StratumThemeData? highContrastDarkTheme;
  final BorderRadius? screenBorderRadius;

  ThemeData toThemeData() {
    final brightness =
        themeMode == ThemeMode.dark ? Brightness.dark : Brightness.light;

    return ThemeData(
      brightness: brightness,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: color.brandPrimary,
        onPrimary: color.iconPrimaryOnColor,
        inversePrimary: color.iconPrimaryInverse,
        secondary: color.brandPrimary,
        onSecondary: color.iconPrimaryOnColor,
        error: color.iconNegative,
        onError: color.iconNegative,
        surface: color.bg,
        onSurface: color.bgInverse,
      ),
      splashFactory: splashFactory,
      primaryColorLight: color.brandPrimary.lighten(10),
      primaryColor: color.brandPrimary,
      primaryColorDark: color.brandPrimary.darken(10),
      hoverColor: color.overlayHover,
      focusColor: color.overlayHover,
      splashColor: color.overlayActive,
      highlightColor: color.brandPrimary.withValues(alpha: 0.15),
      canvasColor: color.bg,
      cardColor: color.bgPopover,
      scaffoldBackgroundColor: color.bg,
      fontFamily: FontFamily.primaryEnglish,
      fontFamilyFallback: const [
        FontFamily.primaryEnglish,
        FontFamily.primaryThai,
      ],
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: color.textPrimary,
        selectionHandleColor: color.brandPrimary,
      ),
      dividerTheme: DividerThemeData(
        thickness: border.md.maxWidth,
        color: color.border,
      ),
      appBarTheme: AppBarTheme(
        systemOverlayStyle: systemOverlayStyle,
      ),
    );
  }

  StratumThemeData copyWith({
    WidgetSize? defaultWidgetSize,
    ThemeMode? themeMode,
    BaseThemeColor? color,
    AppBorder? border,
    AppRadius? borderRadius,
    AppShadow? shadow,
    AppFilter? filter,
    AppSpace? space,
    AppSize? size,
    SystemUiOverlayStyle? systemOverlayStyle,
    SystemUiOverlayStyle? systemOverlayInverseStyle,
    InteractiveInkFeatureFactory? splashFactory,
    List<AppFont>? fonts,
    ScrollBehavior? scrollBehavior,
    StratumThemeAnimation? animation,
    Curve? themeAnimationCurve,
    StratumThemeData? highContrastTheme,
    StratumThemeData? highContrastDarkTheme,
    BorderRadius? screenBorderRadius,
  }) {
    return StratumThemeData(
      defaultWidgetSize: defaultWidgetSize ?? this.defaultWidgetSize,
      themeMode: themeMode ?? this.themeMode,
      color: color ?? this.color,
      border: border ?? this.border,
      borderRadius: borderRadius ?? this.borderRadius,
      shadow: shadow ?? this.shadow,
      filter: filter ?? this.filter,
      space: space ?? this.space,
      size: size ?? this.size,
      systemOverlayStyle: systemOverlayStyle ?? this.systemOverlayStyle,
      systemOverlayInverseStyle:
          systemOverlayInverseStyle ?? this.systemOverlayInverseStyle,
      splashFactory: splashFactory ?? this.splashFactory,
      fonts: fonts ?? this.fonts,
      scrollBehavior: scrollBehavior ?? this.scrollBehavior,
      animation: animation ?? this.animation,
      highContrastTheme: highContrastTheme ?? this.highContrastTheme,
      highContrastDarkTheme:
          highContrastDarkTheme ?? this.highContrastDarkTheme,
      screenBorderRadius: screenBorderRadius ?? this.screenBorderRadius,
    );
  }
}

class StratumThemeAnimation {
  const StratumThemeAnimation({
    this.normal = const AnimationStyle(
      duration: Duration(milliseconds: 125),
      curve: Curves.easeInOut,
      reverseDuration: Duration(milliseconds: 80),
      reverseCurve: Curves.easeInOut,
    ),
  });

  final AnimationStyle normal;
}
