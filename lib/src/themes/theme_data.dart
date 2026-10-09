import 'package:stratum_ui/src/animations/stratum_page_transitions_builder.dart';
import 'package:stratum_ui/src/src.dart';

/// The theme data of one color set (spec section 7.2). Build it through
/// [StratumThemeSet.fromConfig]; change a field through [copyWith].
@immutable
class StratumThemeData {
  const new({
    required this.themeMode,
    required this.color,
    required this.palette,
    required this.space,
    required this.radius,
    required this.layouts,
    required this.appColors,
    required this.appPalettes,
    required this.assets,
    required this.extensions,
    required this.typography,
    required this.animation,
    this.transparent = StratumTransparentTokens.builtIn,
    this.defaultWidgetSize = WidgetSize.medium,
    this.border = const AppBorder(),
    this.shadow = const AppShadow(),
    this.filter = const AppFilter(),
    this.systemOverlayStyle = AppSystemUI.light,
    this.systemOverlayInverseStyle = AppSystemUI.dark,
    this.splashFactory = NoSplash.splashFactory,
    this.scrollBehavior = const StratumScrollBehavior(),
    this.physics = const ClampingScrollPhysics(),
    this.screenBorderRadius,
  });

  /// `ThemeMode.light` for the light and high-contrast light data,
  /// `ThemeMode.dark` for the other two.
  final ThemeMode themeMode;

  /// `color.<set>` without `app`.
  final StratumColorTokens color;

  /// `palette` without `app`.
  final StratumPaletteTokens palette;

  /// The 64 built-in transparent steps.
  final StratumTransparentTokens transparent;

  final Map<String, StratumByWindowSize<StratumDimension>> space;
  final Map<String, StratumByWindowSize<StratumDimension>> radius;
  final Map<String, StratumByWindowSize<StratumDimension>> layouts;

  /// `color.<set>.app`, by name.
  final Map<String, Color> appColors;

  /// `palette.app`, by ramp, then shade.
  final Map<String, Map<String, Color>> appPalettes;

  final StratumAssetTokens assets;
  final Map<String, Object?> extensions;
  final StratumTypography typography;

  /// The yaml values; `StratumTheme.animation` returns them unchanged,
  /// reduced motion included (spec C1).
  final StratumAnimation animation;

  final WidgetSize defaultWidgetSize;
  final AppBorder border;
  final AppShadow shadow;
  final AppFilter filter;
  final SystemUiOverlayStyle systemOverlayStyle;
  final SystemUiOverlayStyle systemOverlayInverseStyle;
  final InteractiveInkFeatureFactory splashFactory;
  final ScrollBehavior scrollBehavior;
  final ScrollPhysics physics;
  final BorderRadius? screenBorderRadius;

  /// The app color [name]. Throws an [ArgumentError] that lists the names
  /// in [appColors] (spec G13).
  Color appColor(String name) =>
      appColors[name] ??
      (throw ArgumentError(
        'no app color "$name"; this theme has: ${_names(appColors.keys)}',
      ));

  /// The app color [name], or null.
  Color? maybeAppColor(String name) => appColors[name];

  /// The app ramp [name]. Throws an [ArgumentError] that lists the ramp
  /// names in [appPalettes].
  StratumAppPalette appPalette(String name) {
    final shades = appPalettes[name];
    if (shades == null) {
      throw ArgumentError(
        'no app palette "$name"; this theme has: ${_names(appPalettes.keys)}',
      );
    }
    return StratumAppPalette(name, shades);
  }

  /// The Material theme of spec section 10: the [ColorScheme] of section
  /// 10.2, the fields of section 10.3, and the text theme of
  /// `docs/specs/stratum_ui/themes/s01_architecture.md`
  /// `### Material text theme`, resolved for [locale], [windowSize], and
  /// [textScaler]. No slot sets a weight, so each draws its type's yaml
  /// weight. A null [windowSize] adds no window scale to the text theme.
  /// Its page transitions install one `StratumPageTransitionsBuilder` of
  /// [animation] for every [TargetPlatform], so every plain Material page
  /// takes the theme's transition (FO-03 US-08 FR-01 E04).
  ThemeData toThemeData({
    required Locale locale,
    required WindowSize? windowSize,
    required TextScaler textScaler,
  }) {
    final brightness = themeMode == ThemeMode.dark
        ? Brightness.dark
        : Brightness.light;
    final brand = color.brand.normal;
    final text = color.text;
    final background = color.background;
    TextStyle resolve(StratumTextStyle recipe) => TypographyResolver.resolve(
      recipe,
      theme: this,
      locale: locale,
      windowSize: windowSize,
      textScaler: textScaler,
    );
    return ThemeData(
      brightness: brightness,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: brand,
        onPrimary: text.defaults.primaryOnColor,
        primaryContainer: background.muted.brand,
        onPrimaryContainer: text.color.brand,
        secondary: brand,
        onSecondary: text.defaults.primaryOnColor,
        error: background.color.negative,
        onError: text.defaults.primaryOnColor,
        errorContainer: background.muted.negative,
        onErrorContainer: text.color.negative,
        surface: background.defaults.normal,
        onSurface: text.defaults.primary,
        surfaceDim: background.defaults.surface,
        onSurfaceVariant: text.defaults.secondary,
        outline: color.border.color.gray,
        outlineVariant: color.border.defaults.normal,
        inverseSurface: background.defaults.normalInverse,
        onInverseSurface: text.defaults.primaryInverse,
      ),
      splashFactory: splashFactory,
      primaryColor: brand,
      primaryColorLight: brand.lighten(10),
      primaryColorDark: brand.darken(10),
      hoverColor: color.state.hover,
      focusColor: color.state.hover,
      splashColor: color.state.press,
      highlightColor: brand.withValues(alpha: 0.15),
      canvasColor: background.defaults.normal,
      scaffoldBackgroundColor: background.defaults.normal,
      cardColor: background.control.popover,
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: text.defaults.primary,
        selectionHandleColor: brand,
      ),
      dividerTheme: DividerThemeData(
        thickness: border.md.maxWidth,
        color: color.border.defaults.normal,
      ),
      appBarTheme: AppBarTheme(systemOverlayStyle: systemOverlayStyle),
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          for (final platform in TargetPlatform.values)
            platform: StratumPageTransitionsBuilder(
              motion: animation,
              platform: platform,
            ),
        },
      ),
      textTheme: TextTheme(
        displayLarge: resolve(StratumTextStyle.header.s56),
        displayMedium: resolve(StratumTextStyle.header.s36),
        displaySmall: resolve(StratumTextStyle.header.s24),
        headlineLarge: resolve(StratumTextStyle.header.s24),
        headlineMedium: resolve(StratumTextStyle.header.s20),
        headlineSmall: resolve(StratumTextStyle.header.s18),
        titleLarge: resolve(StratumTextStyle.body.s18),
        titleMedium: resolve(StratumTextStyle.body.s16),
        titleSmall: resolve(StratumTextStyle.body.s14),
        bodyLarge: resolve(StratumTextStyle.body.s16),
        bodyMedium: resolve(StratumTextStyle.body.s14),
        bodySmall: resolve(StratumTextStyle.body.s12),
        labelLarge: resolve(StratumTextStyle.body.s14),
        labelMedium: resolve(StratumTextStyle.body.s12),
        labelSmall: resolve(StratumTextStyle.body.s10),
      ),
    );
  }

  /// Covers every field, `physics` included (FO-03 s03 invariant 8).
  StratumThemeData copyWith({
    ThemeMode? themeMode,
    StratumColorTokens? color,
    StratumPaletteTokens? palette,
    StratumTransparentTokens? transparent,
    Map<String, StratumByWindowSize<StratumDimension>>? space,
    Map<String, StratumByWindowSize<StratumDimension>>? radius,
    Map<String, StratumByWindowSize<StratumDimension>>? layouts,
    Map<String, Color>? appColors,
    Map<String, Map<String, Color>>? appPalettes,
    StratumAssetTokens? assets,
    Map<String, Object?>? extensions,
    StratumTypography? typography,
    StratumAnimation? animation,
    WidgetSize? defaultWidgetSize,
    AppBorder? border,
    AppShadow? shadow,
    AppFilter? filter,
    SystemUiOverlayStyle? systemOverlayStyle,
    SystemUiOverlayStyle? systemOverlayInverseStyle,
    InteractiveInkFeatureFactory? splashFactory,
    ScrollBehavior? scrollBehavior,
    ScrollPhysics? physics,
    BorderRadius? screenBorderRadius,
  }) {
    return StratumThemeData(
      themeMode: themeMode ?? this.themeMode,
      color: color ?? this.color,
      palette: palette ?? this.palette,
      transparent: transparent ?? this.transparent,
      space: space ?? this.space,
      radius: radius ?? this.radius,
      layouts: layouts ?? this.layouts,
      appColors: appColors ?? this.appColors,
      appPalettes: appPalettes ?? this.appPalettes,
      assets: assets ?? this.assets,
      extensions: extensions ?? this.extensions,
      typography: typography ?? this.typography,
      animation: animation ?? this.animation,
      defaultWidgetSize: defaultWidgetSize ?? this.defaultWidgetSize,
      border: border ?? this.border,
      shadow: shadow ?? this.shadow,
      filter: filter ?? this.filter,
      systemOverlayStyle: systemOverlayStyle ?? this.systemOverlayStyle,
      systemOverlayInverseStyle:
          systemOverlayInverseStyle ?? this.systemOverlayInverseStyle,
      splashFactory: splashFactory ?? this.splashFactory,
      scrollBehavior: scrollBehavior ?? this.scrollBehavior,
      physics: physics ?? this.physics,
      screenBorderRadius: screenBorderRadius ?? this.screenBorderRadius,
    );
  }
}

/// One app ramp of `palette.app`.
@immutable
class StratumAppPalette {
  const new(this.name, this.shades);

  final String name;

  /// Shade name to color, as `palette.app.<name>` writes them.
  final Map<String, Color> shades;

  /// Throws an [ArgumentError] that lists the shade names.
  Color shade(String shade) =>
      shades[shade] ??
      (throw ArgumentError(
        'no shade "$shade" in app palette "$name"; it has: '
        '${_names(shades.keys)}',
      ));
}

/// [names] sorted and joined by `, `; `none` when empty.
String _names(Iterable<String> names) {
  final sorted = names.toList()..sort();
  return sorted.isEmpty ? 'none' : sorted.join(', ');
}
