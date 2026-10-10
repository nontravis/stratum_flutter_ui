import 'package:stratum_ui/src/components/common/responsive/screen_radius_scope.dart';
import 'package:stratum_ui/src/src.dart';

/// Publishes a theme set, or a [StratumThemeController]'s active theme
/// set, and picks the active data by theme mode and high-contrast mode
/// (spec section 7.3; FO-03 US-02 FR-01).
class StratumThemeApplication
    extends InheritedNotifier<StratumThemeController> {
  /// Wraps [child] in a private body that inserts, top to bottom, a
  /// `ScreenRadiusScope` that publishes the native screen radius on iOS
  /// and macOS and a [WindowSizeScope], each when none is above the
  /// application, a Material [Theme] of the active data, and
  /// [StratumComponentDefaults] built by [componentDefaults] from the
  /// active theme (spec sections 7.3, 7.9, and 10.1; FO-07 US-04 FR-03).
  new({
    super.key,
    required StratumThemeSet themes,
    required this.themeMode,
    this.highContrast = HighContrastMode.system,
    this.componentDefaults,
    required Widget child,
  }) : _themes = themes,
       super(child: _StratumThemeBody(child: child));

  /// Publishes [controller]'s active theme set, with the same body as the
  /// unnamed constructor, and rebuilds every dependent once per switch of
  /// [controller] (FO-03 US-02 FR-01).
  new controlled({
    super.key,
    required StratumThemeController controller,
    required this.themeMode,
    this.highContrast = HighContrastMode.system,
    this.componentDefaults,
    required Widget child,
  }) : _themes = null,
       super(
         notifier: controller,
         child: _StratumThemeBody(child: child),
       );

  final StratumThemeSet? _themes;

  /// The theme mode the active data follows.
  final ThemeMode themeMode;

  /// Whether the active data is a high-contrast one.
  final HighContrastMode highContrast;

  /// The app-wide component defaults (L2), built again whenever the
  /// active theme changes. Never compared in [updateShouldNotify]: a
  /// closure literal differs on every build (spec G10).
  final StratumComponentDefaultsBuilder? componentDefaults;

  /// The theme set: the one the unnamed constructor took, else the
  /// [controller]'s active set.
  StratumThemeSet get themes => _themes ?? notifier!.themes;

  /// The controller [StratumThemeApplication.controlled] took, else null.
  StratumThemeController? get controller => notifier;

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
  /// [child], its controller included; [child] unchanged when none is
  /// above (FO-03 US-10 FR-05).
  static Widget wrap(BuildContext context, {required Widget child}) {
    final application = context
        .dependOnInheritedWidgetOfExactType<StratumThemeApplication>();
    if (application == null) return child;
    final controller = application.controller;
    if (controller != null) {
      return StratumThemeApplication.controlled(
        controller: controller,
        themeMode: application.themeMode,
        highContrast: application.highContrast,
        componentDefaults: application.componentDefaults,
        child: child,
      );
    }
    return StratumThemeApplication(
      themes: application.themes,
      themeMode: application.themeMode,
      highContrast: application.highContrast,
      componentDefaults: application.componentDefaults,
      child: child,
    );
  }

  /// True when [themeMode], [highContrast], the controller, or any of the
  /// four data of the passed theme set differs (FO-03 US-04 FR-02); a
  /// switch of the same controller notifies through [InheritedNotifier].
  @override
  bool updateShouldNotify(StratumThemeApplication oldWidget) =>
      themeMode != oldWidget.themeMode ||
      highContrast != oldWidget.highContrast ||
      notifier != oldWidget.notifier ||
      _themes != oldWidget._themes;
}

extension AppStratumThemeApplicationExtensions on ThemeMode {
  /// `StratumTheme.of(context, themeMode: this)`.
  StratumTheme theme(BuildContext context) =>
      StratumTheme.of(context, themeMode: this);
}

/// What the application inserts below itself, top to bottom: a
/// [ScreenRadiusScope] when none is above it, so a tree publishes the
/// screen radius once (FO-07 US-04 FR-03), a [WindowSizeScope]
/// when none is above it, so a varying token always finds a window size
/// (spec section 7.3, OQ11), then the Material theme.
class _StratumThemeBody extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final themed = _StratumMaterialTheme(child: child);
    final sized = WindowSizeScope.hasScope(context)
        ? themed
        : WindowSizeScope(child: themed);
    return ScreenRadiusScope.hasScope(context)
        ? sized
        : ScreenRadiusScope(child: sized);
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
      child: _StratumComponentDefaultsLayer(child: child),
    );
  }
}

/// Publishes the application's component defaults for the active theme
/// (spec section 7.9, G14). Built again with the body, so a new
/// `componentDefaults` closure takes effect, while an equal map notifies
/// no component.
class _StratumComponentDefaultsLayer extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final builder = context
        .getInheritedWidgetOfExactType<StratumThemeApplication>()
        ?.componentDefaults;
    return StratumComponentDefaults(
      styles: builder?.call(StratumTheme.of(context)) ?? const {},
      child: child,
    );
  }
}
