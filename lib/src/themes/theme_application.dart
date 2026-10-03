import 'package:stratum_ui/src/src.dart';

/// Publishes a theme set and picks the active data by theme mode and
/// high-contrast mode (spec section 7.3).
class StratumThemeApplication extends InheritedWidget {
  /// Wraps [child] in a private body that inserts, top to bottom, a
  /// [WindowSizeScope] when none is above the application and a Material
  /// [Theme] of the active data (spec sections 7.3 and 10.1).
  new({
    super.key,
    required this.themes,
    required this.themeMode,
    this.highContrast = HighContrastMode.system,
    required Widget child,
  }) : super(child: _StratumThemeBody(child: child));

  final StratumThemeSet themes;
  final ThemeMode themeMode;
  final HighContrastMode highContrast;

  /// Throws a [FlutterError] that names [StratumThemeApplication] when
  /// none is above [context] (FO-03 US-04 FR-01 E03).
  static StratumThemeData of(BuildContext context, {ThemeMode? themeMode}) {
    final theme = maybeOf(context, themeMode: themeMode);
    if (theme == null) {
      throw FlutterError(
        'StratumThemeApplication.of() called with a context that does not '
        'contain a StratumThemeApplication.',
      );
    }
    return theme;
  }

  /// Dark: [themeMode], else the application's mode; `system` reads the
  /// platform brightness, light with no media query. High contrast: the
  /// application's [highContrast]; `system` reads
  /// `MediaQuery.maybeHighContrastOf`, off with no media query. Then
  /// `themes.pick`. Null when no application is above [context].
  static StratumThemeData? maybeOf(
    BuildContext context, {
    ThemeMode? themeMode,
  }) {
    final application = context
        .dependOnInheritedWidgetOfExactType<StratumThemeApplication>();
    if (application == null) return null;
    final dark = switch (themeMode ?? application.themeMode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system =>
        MediaQuery.maybePlatformBrightnessOf(context) == Brightness.dark,
    };
    final highContrast = switch (application.highContrast) {
      HighContrastMode.on => true,
      HighContrastMode.off => false,
      HighContrastMode.system =>
        MediaQuery.maybeHighContrastOf(context) ?? false,
    };
    return application.themes.pick(dark: dark, highContrast: highContrast);
  }

  /// A new application with every parameter of the nearest one around
  /// [child]; [child] unchanged when none is above (FO-03 US-10 FR-05).
  static Widget wrap(BuildContext context, {required Widget child}) {
    final application = context
        .dependOnInheritedWidgetOfExactType<StratumThemeApplication>();
    if (application == null) return child;
    return StratumThemeApplication(
      themes: application.themes,
      themeMode: application.themeMode,
      highContrast: application.highContrast,
      child: child,
    );
  }

  /// True when [themeMode], [highContrast], or any of the four data of
  /// [themes] differs (FO-03 US-04 FR-02).
  @override
  bool updateShouldNotify(StratumThemeApplication oldWidget) =>
      themeMode != oldWidget.themeMode ||
      highContrast != oldWidget.highContrast ||
      themes != oldWidget.themes;
}

extension AppStratumThemeApplicationExtensions on ThemeMode {
  /// `StratumTheme.of(context, themeMode: this)`.
  StratumTheme theme(BuildContext context) =>
      StratumTheme.of(context, themeMode: this);
}

/// What the application inserts below itself, top to bottom: a
/// [WindowSizeScope] when none is above it, so a varying token always
/// finds a window size (spec section 7.3, OQ11), then the Material theme.
class _StratumThemeBody extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final themed = _StratumMaterialTheme(child: child);
    return WindowSizeScope.hasScope(context)
        ? themed
        : WindowSizeScope(child: themed);
  }
}

/// A Material [Theme] of the active data (spec section 10.1), rebuilt when
/// the data, the locale, the window size, or the text scaler changes
/// (spec G24). The application belongs in `MaterialApp.builder`, below
/// `MaterialApp`'s own theme, so this theme reaches every route (G25).
class _StratumMaterialTheme extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final data = StratumThemeApplication.of(context);
    return Theme(
      data: data.toThemeData(
        locale:
            Localizations.maybeLocaleOf(context) ??
            View.of(context).platformDispatcher.locale,
        windowSize: WindowSizeScope.maybeOf(context),
        textScaler:
            MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling,
      ),
      child: child,
    );
  }
}
