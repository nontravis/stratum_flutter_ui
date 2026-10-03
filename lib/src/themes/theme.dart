import 'package:stratum_ui/src/src.dart';

/// The active theme data at a context (spec section 7.4).
///
/// Read it inside `build` only: each read registers its dependencies on
/// the context that created the view. A `space`, `radius`, or `layouts`
/// token that is the same on every window size reads no
/// [WindowSizeScope]; a varying one reads [WindowSizeScope.of], so the
/// reader rebuilds when the window crosses a breakpoint; a `layouts`
/// percent reads `MediaQuery.sizeOf(context).width`, so the reader
/// rebuilds on every width change.
class StratumTheme {
  const new _(this._context, this.data);

  /// Throws the [FlutterError] of [StratumThemeApplication.of].
  static StratumTheme of(BuildContext context, {ThemeMode? themeMode}) =>
      StratumTheme._(
        context,
        StratumThemeApplication.of(context, themeMode: themeMode),
      );

  /// Null when no [StratumThemeApplication] is above [context].
  static StratumTheme? maybeOf(BuildContext context, {ThemeMode? themeMode}) {
    final data = StratumThemeApplication.maybeOf(context, themeMode: themeMode);
    return data == null ? null : StratumTheme._(context, data);
  }

  final BuildContext _context;

  /// `StratumThemeApplication.maybeOf(context, themeMode:)`.
  final StratumThemeData data;

  StratumColorTokens get color => data.color;

  StratumPaletteTokens get palette => data.palette;

  StratumTransparentTokens get transparent => data.transparent;

  /// Logical pixels for the current window size.
  StratumSpaceTokens get space =>
      StratumSpaceTokens((name) => _resolve(data.space, 'space', name));

  /// Logical pixels for the current window size; write
  /// `BorderRadius.circular(theme.radius.lg)` (spec G12).
  StratumRadiusTokens get radius =>
      StratumRadiusTokens((name) => _resolve(data.radius, 'radius', name));

  /// Logical pixels; a percent of the window width (spec section 8.3).
  StratumLayoutTokens get layouts =>
      StratumLayoutTokens((name) => _resolve(data.layouts, 'layouts', name));

  /// `data.animation`, unchanged under reduced motion too (spec C1).
  StratumAnimation get animation => data.animation;

  StratumAssetTokens get assets => data.assets;

  Map<String, Object?> get extensions => data.extensions;

  StratumTypography get typography => data.typography;

  Color appColor(String name) => data.appColor(name);

  Color? maybeAppColor(String name) => data.maybeAppColor(name);

  StratumAppPalette appPalette(String name) => data.appPalette(name);

  ThemeMode get themeMode => data.themeMode;

  WidgetSize get defaultWidgetSize => data.defaultWidgetSize;

  AppBorder get border => data.border;

  AppShadow get shadow => data.shadow;

  AppFilter get filter => data.filter;

  SystemUiOverlayStyle get systemOverlayStyle => data.systemOverlayStyle;

  SystemUiOverlayStyle get systemOverlayInverseStyle =>
      data.systemOverlayInverseStyle;

  InteractiveInkFeatureFactory get splashFactory => data.splashFactory;

  ScrollBehavior get scrollBehavior => data.scrollBehavior;

  ScrollPhysics get physics => data.physics;

  BorderRadius? get screenBorderRadius => data.screenBorderRadius;

  /// The token [name] of [group] in logical pixels. Throws an
  /// [ArgumentError] naming `<groupName>.<name>` when the data lacks it.
  double _resolve(
    Map<String, StratumByWindowSize<StratumDimension>> group,
    String groupName,
    String name,
  ) {
    final token =
        group[name] ??
        (throw ArgumentError.value(
          '$groupName.$name',
          'path',
          'no token at this path in the theme data',
        ));
    final value = token.isUniform
        ? token.valueFor(WindowSize.values.first)
        : token.valueFor(WindowSizeScope.of(_context));
    return switch (value) {
      FixedDimension(:final px) => px,
      PercentDimension(:final ratio) =>
        ratio * MediaQuery.sizeOf(_context).width,
    };
  }
}
