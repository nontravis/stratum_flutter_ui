import 'package:stratum_ui/src/src.dart';

/// Wraps the app in Stratum's layers, outer to inner: the theme runtime
/// (US-01 FR-03, or [controller]), then, inside
/// [StratumAppConfig.builder], `StratumThemeApplication`, [updateGate],
/// the notice host, and [webZoom], around the app widget [appBuilder]
/// returns (themes s03 invariant 34). Add the two `## Install` override
/// lines to the app's `pubspec.yaml`
/// (`dependency_overrides: equatable: ^3.0.0`) per US-13 FR-01's last
/// sentence.
class StratumApplication extends StatelessWidget {
  const new({
    super.key,
    this.controller,
    this.initialThemeId,
    this.onThemeChanged,
    this.googleFontsTimeout = const Duration(seconds: 3),
    this.remoteThemes = const [],
    this.onRemoteThemeError,
    this.error,
    this.loadingBuilder,
    this.themeMode = ThemeMode.system,
    this.highContrast = StratumHighContrastMode.system,
    this.componentDefaults,
    this.componentPartDefaults,
    this.systemStyle,
    this.webZoom,
    this.notices = true,
    this.noticeHost,
    this.updateGate,
    required this.appBuilder,
  });

  /// The app's own theme controller; with none, the theme runtime
  /// preloads its own from [initialThemeId] (US-01 FR-03, US-02 FR-01).
  final StratumThemeController? controller;

  /// The theme id the app saved, forwarded to preload with no
  /// [controller].
  final String? initialThemeId;

  /// Called with each new active theme id, forwarded to preload.
  final ValueChanged<String>? onThemeChanged;

  /// How long preload and every switch wait for Google fonts, forwarded
  /// to preload.
  final Duration googleFontsTimeout;

  /// The theme zips the app kept, forwarded to preload (FO-04 US-01
  /// FR-04).
  final List<StratumRemoteTheme> remoteThemes;

  /// Called once for each kept zip that fails to install, forwarded to
  /// preload.
  final void Function(String id, StratumRemoteThemeException error)?
  onRemoteThemeError;

  /// The frame for a start theme preload could not read, forwarded to
  /// preload; the exception goes unreported with none.
  final Widget Function(BuildContext context, Object error)? error;

  /// The frames until the start theme is active; [_background] with none
  /// (FR-01 E04).
  final WidgetBuilder? loadingBuilder;

  /// The theme mode the active data follows.
  final ThemeMode themeMode;

  /// Whether the active data is a high-contrast one, forwarded to the
  /// theme application.
  final StratumHighContrastMode highContrast;

  /// The app-wide component defaults (L2), forwarded to the theme
  /// application.
  final StratumComponentDefaultsBuilder? componentDefaults;

  /// The app-wide parts style per multi-part component type, forwarded
  /// to the theme application (FO-03 US-06 FR-01).
  final StratumComponentPartDefaultsBuilder? componentPartDefaults;

  /// The app-wide system bar style, forwarded to the theme application
  /// (FO-03 US-14 FR-01).
  final SystemStyle? systemStyle;

  /// Wraps the app widget in the EndUser's web pinch zoom (CO-01-04);
  /// absent leaves the layer out.
  final Widget Function(Widget child)? webZoom;

  /// Whether the notice host sits in the layers; false leaves it out
  /// whatever [noticeHost] holds (FR-01 E05, E06).
  final bool notices;

  /// Replaces the plain `StratumToastHost(child:)` the layers build when
  /// [notices] is true (CO-05-07; R31).
  final StratumToastHost Function(Widget child)? noticeHost;

  /// Wraps the inner layers in the update gate (CO-05-09); absent leaves
  /// the layer out.
  final Widget Function(Widget child)? updateGate;

  /// Builds the app's own Material, iOS-style, or plain app widget from
  /// the config FR-02 hands it.
  final StratumAppBuilder appBuilder;

  /// The background [_background] shows under a light [themeMode] (FR-01
  /// E04): the default theme's `background.default.normal` in its light
  /// set (`assets/themes/default/theme.yaml:193`, alias
  /// `transparent.white.100`).
  @visibleForTesting
  static const Color noSplashLightBackground = Color(0xFFFFFFFF);

  /// The background [_background] shows under a dark [themeMode] (FR-01
  /// E04): the default theme's `background.default.normal` in its dark
  /// set (`assets/themes/default/theme.yaml:416`, alias
  /// `palette.gray.900`).
  @visibleForTesting
  static const Color noSplashDarkBackground = Color(0xFF111827);

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;
    if (controller != null) return _assemble(context, controller);
    return StratumThemePreloader(
      initialThemeId: initialThemeId,
      onThemeChanged: onThemeChanged,
      googleFontsTimeout: googleFontsTimeout,
      remoteThemes: remoteThemes,
      onRemoteThemeError: onRemoteThemeError,
      error: error,
      loading: loadingBuilder ?? _background,
      builder: _assemble,
    );
  }

  /// The no-splash background, picked by [themeMode]; platform brightness
  /// only for `system` (R32).
  Widget _background(BuildContext context) {
    final dark = switch (themeMode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system =>
        MediaQuery.platformBrightnessOf(context) == Brightness.dark,
    };
    return ColoredBox(
      color: dark ? noSplashDarkBackground : noSplashLightBackground,
    );
  }

  /// Builds the config for [controller]'s active theme, again whenever it
  /// changes (FR-02 E03; themes s03 invariant 35).
  Widget _assemble(BuildContext context, StratumThemeController controller) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final themes = controller.themes;
        final locale = View.of(context).platformDispatcher.locale;
        final windowSize = WindowSize.fromSize(MediaQuery.sizeOf(context));
        final textScaler = MediaQuery.textScalerOf(context);
        return appBuilder(
          context,
          StratumAppConfig(
            theme: themes.light.toThemeData(
              locale: locale,
              windowSize: windowSize,
              textScaler: textScaler,
            ),
            darkTheme: themes.dark?.toThemeData(
              locale: locale,
              windowSize: windowSize,
              textScaler: textScaler,
            ),
            themeMode: themeMode,
            builder: _inner(controller),
          ),
        );
      },
    );
  }

  /// The layers inside the app widget's builder, outer to inner:
  /// `StratumThemeApplication`, [updateGate], the notice host, [webZoom],
  /// then the app's own child (themes s03 invariant 34).
  TransitionBuilder _inner(StratumThemeController controller) {
    return (context, child) {
      var w = child ?? const SizedBox.shrink();
      final zoom = webZoom;
      if (zoom != null) w = zoom(w);
      if (notices) w = (noticeHost ?? _plainNoticeHost)(w);
      final gate = updateGate;
      if (gate != null) w = gate(w);
      return StratumThemeApplication.controlled(
        controller: controller,
        themeMode: themeMode,
        highContrast: highContrast,
        componentDefaults: componentDefaults,
        componentPartDefaults: componentPartDefaults,
        systemStyle: systemStyle,
        child: w,
      );
    };
  }

  static Widget _plainNoticeHost(Widget child) =>
      StratumToastHost(child: child);
}
