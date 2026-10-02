import 'package:stratum_ui/src/src.dart';

/// An immutable text recipe: a type, a size, a weight, a color, and
/// optional overrides of the screen environment.
///
/// Every getter and method returns a new instance, so a stored recipe is
/// safe to reuse:
///
/// ```dart
/// final caption = StratumTextStyle.body.s12.colorTertiary;
/// Text('a', style: caption.medium.build(context)); // medium
/// Text('b', style: caption.build(context)); // regular; caption unchanged
/// ```
@immutable
class StratumTextStyle {
  const new _({
    required this.fontType,
    this.fontSize = FontSize.s16,
    this.customSize,
    this.fontWeight,
    this.isMono = false,
    this.fontStyle,
    this.textDecoration,
    this.textShadows,
    this.colorRole = FontColor.primary,
    this.customColor,
    this.themeModeOverride,
    this.localeOverride,
    this.windowSizeOverride,
    this.textScalerOverride,
  });

  // Type

  static StratumTextStyle get header =>
      const StratumTextStyle._(fontType: FontType.header);

  static StratumTextStyle get paragraph =>
      const StratumTextStyle._(fontType: FontType.paragraph);

  static StratumTextStyle get number =>
      const StratumTextStyle._(fontType: FontType.number);

  static StratumTextStyle get code =>
      const StratumTextStyle._(fontType: FontType.code);

  static StratumTextStyle get body =>
      const StratumTextStyle._(fontType: FontType.body);

  static StratumTextStyle get table =>
      const StratumTextStyle._(fontType: FontType.table);

  static StratumTextStyle type(FontType type) =>
      StratumTextStyle._(fontType: type);

  // Fields

  /// The type whose fonts, weight, and metrics apply.
  final FontType fontType;

  /// The named size; [customSize], when set, replaces it.
  final FontSize fontSize;

  /// A size in logical pixels that takes the metrics of the nearest named
  /// size, or null.
  final double? customSize;

  /// The weight, or null for the weight of the type in `theme.yaml`.
  final FontWeight? fontWeight;

  /// Whether the mono font of the type replaces its font.
  final bool isMono;

  final FontStyle? fontStyle;

  final TextDecoration? textDecoration;

  final List<Shadow>? textShadows;

  /// The theme text color used when [customColor] is null.
  final FontColor colorRole;

  final Color? customColor;

  /// The theme mode to read the theme for, or null for the app's mode.
  final ThemeMode? themeModeOverride;

  /// The locale that picks the fonts, or null for the context's locale.
  final Locale? localeOverride;

  /// The window size that picks the window scale, or null for the
  /// `WindowSizeScope` above the context.
  final WindowSize? windowSizeOverride;

  /// The text scaler, or null for the `MediaQuery` above the context.
  final TextScaler? textScalerOverride;

  // Size

  StratumTextStyle get s10 => _copy(fontSize: FontSize.s10);

  StratumTextStyle get s12 => _copy(fontSize: FontSize.s12);

  StratumTextStyle get s14 => _copy(fontSize: FontSize.s14);

  StratumTextStyle get s16 => _copy(fontSize: FontSize.s16);

  StratumTextStyle get s18 => _copy(fontSize: FontSize.s18);

  StratumTextStyle get s20 => _copy(fontSize: FontSize.s20);

  StratumTextStyle get s24 => _copy(fontSize: FontSize.s24);

  StratumTextStyle get s36 => _copy(fontSize: FontSize.s36);

  StratumTextStyle get s48 => _copy(fontSize: FontSize.s48);

  StratumTextStyle get s56 => _copy(fontSize: FontSize.s56);

  /// A size of [size] logical pixels with the metrics of the nearest named
  /// size.
  StratumTextStyle size(double size) =>
      _copy(fontSize: FontSize.s16, customSize: size);

  // Weight

  StratumTextStyle get light => weight(FontWeight.w300);

  StratumTextStyle get regular => weight(FontWeight.w400);

  StratumTextStyle get medium => weight(FontWeight.w500);

  StratumTextStyle get semiBold => weight(FontWeight.w600);

  StratumTextStyle get bold => weight(FontWeight.w700);

  StratumTextStyle weight(FontWeight weight) => _copy(fontWeight: weight);

  // Variant and style

  /// Swaps to the mono font of the type, keeping the type's metrics.
  StratumTextStyle get mono => _copy(isMono: true);

  StratumTextStyle get italic => _copy(fontStyle: FontStyle.italic);

  StratumTextStyle get underline => decoration(TextDecoration.underline);

  StratumTextStyle get lineThrough => decoration(TextDecoration.lineThrough);

  StratumTextStyle decoration(TextDecoration decoration) =>
      _copy(textDecoration: decoration);

  StratumTextStyle shadows(List<Shadow> shadows) =>
      _copy(textShadows: List.unmodifiable(shadows));

  // Color

  StratumTextStyle get colorPrimary => fontColor(FontColor.primary);

  StratumTextStyle get colorPrimaryInverse =>
      fontColor(FontColor.primaryInverse);

  StratumTextStyle get colorPrimaryOnColor =>
      fontColor(FontColor.primaryOnColor);

  StratumTextStyle get colorSecondary => fontColor(FontColor.secondary);

  StratumTextStyle get colorSecondaryInverse =>
      fontColor(FontColor.secondaryInverse);

  StratumTextStyle get colorTertiary => fontColor(FontColor.tertiary);

  StratumTextStyle get colorTertiaryInverse =>
      fontColor(FontColor.tertiaryInverse);

  StratumTextStyle get colorBrandPrimary => fontColor(FontColor.brandPrimary);

  StratumTextStyle get colorBrandSecondary =>
      fontColor(FontColor.brandSecondary);

  StratumTextStyle get colorBrandTertiary => fontColor(FontColor.brandTertiary);

  StratumTextStyle fontColor(FontColor color) => _copy(colorRole: color);

  StratumTextStyle color(Color color) => _copy(customColor: color);

  // Environment overrides

  StratumTextStyle themeMode(ThemeMode mode) => _copy(themeModeOverride: mode);

  StratumTextStyle get darkTheme => themeMode(ThemeMode.dark);

  StratumTextStyle get lightTheme => themeMode(ThemeMode.light);

  StratumTextStyle locale(Locale locale) => _copy(localeOverride: locale);

  StratumTextStyle windowSize(WindowSize windowSize) =>
      _copy(windowSizeOverride: windowSize);

  StratumTextStyle textScaler(TextScaler textScaler) =>
      _copy(textScalerOverride: textScaler);

  // Equality

  @override
  bool operator ==(Object other) =>
      other is StratumTextStyle &&
      other.fontType == fontType &&
      other.fontSize == fontSize &&
      other.customSize == customSize &&
      other.fontWeight == fontWeight &&
      other.isMono == isMono &&
      other.fontStyle == fontStyle &&
      other.textDecoration == textDecoration &&
      listEquals(other.textShadows, textShadows) &&
      other.colorRole == colorRole &&
      other.customColor == customColor &&
      other.themeModeOverride == themeModeOverride &&
      other.localeOverride == localeOverride &&
      other.windowSizeOverride == windowSizeOverride &&
      other.textScalerOverride == textScalerOverride;

  @override
  int get hashCode => Object.hash(
    fontType,
    fontSize,
    customSize,
    fontWeight,
    isMono,
    fontStyle,
    textDecoration,
    Object.hashAll(textShadows ?? const <Shadow>[]),
    colorRole,
    customColor,
    themeModeOverride,
    localeOverride,
    windowSizeOverride,
    textScalerOverride,
  );

  // Helpers

  /// A copy with the given fields. Setting [fontSize] also sets
  /// [customSize], and setting [colorRole] also sets [customColor], so the
  /// last size or color call wins.
  StratumTextStyle _copy({
    FontSize? fontSize,
    double? customSize,
    FontWeight? fontWeight,
    bool? isMono,
    FontStyle? fontStyle,
    TextDecoration? textDecoration,
    List<Shadow>? textShadows,
    FontColor? colorRole,
    Color? customColor,
    ThemeMode? themeModeOverride,
    Locale? localeOverride,
    WindowSize? windowSizeOverride,
    TextScaler? textScalerOverride,
  }) => StratumTextStyle._(
    fontType: fontType,
    fontSize: fontSize ?? this.fontSize,
    customSize: fontSize == null ? this.customSize : customSize,
    fontWeight: fontWeight ?? this.fontWeight,
    isMono: isMono ?? this.isMono,
    fontStyle: fontStyle ?? this.fontStyle,
    textDecoration: textDecoration ?? this.textDecoration,
    textShadows: textShadows ?? this.textShadows,
    colorRole: colorRole ?? this.colorRole,
    customColor: colorRole == null
        ? customColor ?? this.customColor
        : customColor,
    themeModeOverride: themeModeOverride ?? this.themeModeOverride,
    localeOverride: localeOverride ?? this.localeOverride,
    windowSizeOverride: windowSizeOverride ?? this.windowSizeOverride,
    textScalerOverride: textScalerOverride ?? this.textScalerOverride,
  );
}
