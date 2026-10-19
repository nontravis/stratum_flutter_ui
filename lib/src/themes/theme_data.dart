import 'package:stratum_ui/src/animations/stratum_page_transitions_builder.dart';
import 'package:stratum_ui/src/src.dart';
import 'package:stratum_ui/src/themes/value_model.dart';

part 'generated/theme_data.freezed.dart';

/// The theme data of one color set (spec section 7.2). Build it through
/// [StratumThemeSet.fromConfig]; change a field through [copyWith]. Every
/// `copyWith` parameter takes that field's own non-nullable type, so pass a
/// field only when changing it: there is no "pass null to keep it" form.
@valueModel
abstract class StratumThemeData with _$StratumThemeData {
  const factory({
    /// `ThemeMode.light` for the light and high-contrast light data,
    /// `ThemeMode.dark` for the other two.
    required ThemeMode themeMode,

    /// `color.<set>` without `app`.
    required StratumColorTokens color,

    /// `palette` without `app`.
    required StratumPaletteTokens palette,
    required Map<String, StratumByWindowSize<StratumDimension>> space,
    required Map<String, StratumByWindowSize<StratumDimension>> radius,
    required Map<String, StratumByWindowSize<StratumDimension>> layouts,

    /// `color.<set>.app`, by name.
    required Map<String, Color> appColors,

    /// `palette.app`, by ramp, then shade.
    required Map<String, Map<String, Color>> appPalettes,
    required StratumAssetTokens assets,
    required Map<String, Object?> extensions,
    required StratumTypography typography,

    /// The yaml values; `StratumTheme.animation` returns them unchanged,
    /// reduced motion included (spec C1).
    required StratumAnimation animation,

    /// `opacity`: `disabled`, the opacity of a disabled component, which the
    /// component base's disabled wrapper paints (FO-08 US-07).
    required StratumOpacityTokens opacity,

    /// `border`: `sm`, `md`, `lg`, each a width in logical pixels from the
    /// theme file; a widget that needs the usual width reads `md`.
    required StratumBorderTokens border,

    /// `shadow`: `level1` to `level6`, each a list of `BoxShadow` in Figma
    /// order, colored from this data's own color set.
    required StratumShadowTokens shadow,

    /// `blur`: `level1` to `level6`, each a background blur at sigma half
    /// the Figma radius.
    required StratumBlurTokens blur,

    /// `system`: the look of the system bars from the theme file's `system`
    /// set for this data's mode, a high-contrast set laid over its base; the
    /// one system bar style the theme exposes and the lowest layer of the
    /// system style merge (FO-03 US-10 FR-01 E05, US-14 FR-01). Its bar mode,
    /// rotation lock, and app switcher label stay null: an app sets those in
    /// code.
    required SystemStyle systemStyle,

    /// `focus`: the focus ring's level 0 from the theme file's `focus` set
    /// for this data's mode, a high-contrast set laid over its base, each
    /// color from this data's own color set (FO-06 US-04 FR-03; themes s03
    /// invariant 46).
    required StratumFocusTokens focus,

    /// The 64 built-in transparent steps.
    @Default(StratumTransparentTokens.builtIn)
    StratumTransparentTokens transparent,
    @Default(WidgetSize.medium) WidgetSize defaultWidgetSize,
    @Default(NoSplash.splashFactory) InteractiveInkFeatureFactory splashFactory,
    @Default(StratumScrollBehavior()) ScrollBehavior scrollBehavior,
    @Default(ClampingScrollPhysics()) ScrollPhysics physics,
  }) = _StratumThemeData;

  const new _();

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

  /// The Material theme: the [ColorScheme], its fields, and the text theme,
  /// resolved for [locale], [windowSize], and [textScaler]. No slot sets a
  /// weight, so each draws its type's yaml weight. A null [windowSize] adds
  /// no window scale to the text theme.
  /// Its page transitions install one `StratumPageTransitionsBuilder` of
  /// [animation] for every [TargetPlatform], so every plain Material page
  /// takes the theme's transition (FO-03 US-08 FR-01 E04). It sets no
  /// system bar style for the app bar, so a Material `AppBar` declares the
  /// style of its own fill, which the system style resolver reads as one
  /// fill layer (FO-03 US-08 FR-01 E05).
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
        thickness: border.md,
        color: color.border.defaults.normal,
      ),
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
}

/// One app ramp of `palette.app`.
@valueModel
abstract class StratumAppPalette with _$StratumAppPalette {
  const factory(
    String name,

    /// Shade name to color, as `palette.app.<name>` writes them.
    Map<String, Color> shades,
  ) = _StratumAppPalette;

  const new _();

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
