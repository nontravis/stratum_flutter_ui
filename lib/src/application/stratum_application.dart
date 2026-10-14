import 'package:stratum_ui/src/src.dart';

/// Wraps the app in Stratum's layers, outer to inner: the theme runtime
/// (US-01 FR-03, or [controller]), then, inside
/// [StratumAppConfig.builder], `StratumThemeApplication`, [updateGate],
/// the notice host, and [webZoom], around the app widget [appBuilder]
/// returns (themes s03 invariant 34).
///
/// - Add the two `## Install` override lines to the app's `pubspec.yaml`
///   (`dependency_overrides: equatable: ^3.0.0`) per US-13 FR-01's last
///   sentence.
/// - Mount ONE per process with [notices] true, since toastification under
///   the notice host is process-wide (CO-05-07); every other view's
///   wrapper passes `notices: false`.
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

  /// The app's own theme controller, never disposed by the wrapper; with
  /// none, the theme runtime preloads its own (US-01 FR-03, US-02 FR-01).
  ///
  /// With one, every preload input is ignored: [initialThemeId],
  /// [onThemeChanged], [googleFontsTimeout], [remoteThemes],
  /// [onRemoteThemeError], [error], and [loadingBuilder].
  final StratumThemeController? controller;

  /// The theme id the app saved; a preload input, read once at the first
  /// build.
  final String? initialThemeId;

  /// Called with each new active theme id; a preload input, read once at
  /// the first build.
  final ValueChanged<String>? onThemeChanged;

  /// How long preload and every switch wait for Google fonts; a preload
  /// input, read once at the first build.
  final Duration googleFontsTimeout;

  /// The theme zips the app kept (FO-04 US-01 FR-04); a preload input,
  /// read once at the first build.
  final List<StratumRemoteTheme> remoteThemes;

  /// Called once for each kept zip that fails to install; a preload
  /// input, read once at the first build. With none, a release build
  /// drops the failure unseen.
  final void Function(String id, StratumRemoteThemeException error)?
  onRemoteThemeError;

  /// The frame for a start theme preload could not read; a preload input.
  ///
  /// - The failure reaches only this frame, so log it here; with none, it
  ///   goes to [FlutterError.reportError] and the no-splash background
  ///   stays (FR-01 E07).
  /// - Builds above the app widget, with no `Directionality` or theme.
  final Widget Function(BuildContext context, Object error)? error;

  /// The frames until the start theme is active, in place of the
  /// no-splash background (FR-01 E04); a preload input. Builds above the
  /// app widget, with no `Directionality` or theme.
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

  /// The no-splash background under a light [themeMode] (FR-01 E04,
  /// E07): the default theme's `background.default.normal` in its light
  /// set (`assets/themes/default/theme.yaml:193`, alias
  /// `transparent.white.100`).
  @visibleForTesting
  static const Color noSplashLightBackground = Color(0xFFFFFFFF);

  /// The no-splash background under a dark [themeMode] (FR-01 E04, E07):
  /// the default theme's `background.default.normal` in its dark
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
      error: error ?? _failedStart,
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

  /// The frame for a start theme that failed with no [error] frame: the
  /// no-splash background, with [failure] reported once (FR-01 E07).
  Widget _failedStart(BuildContext context, Object failure) =>
      _ReportedStartFailure(failure: failure, child: _background(context));

  /// Builds the config for [controller]'s active theme, again when the
  /// theme, the window size class, the text scale, or the platform locale
  /// changes (FR-02 E03; themes s03 invariant 35).
  Widget _assemble(BuildContext context, StratumThemeController controller) {
    return WindowSizeScope(
      child: _PlatformLocaleBuilder(
        builder: (context, locale) => ListenableBuilder(
          listenable: controller,
          builder: (context, _) =>
              appBuilder(context, _config(context, controller, locale)),
        ),
      ),
    );
  }

  /// The config for [controller]'s active theme under [locale] and the
  /// window size class and text scale of [context].
  StratumAppConfig _config(
    BuildContext context,
    StratumThemeController controller,
    Locale locale,
  ) {
    final themes = controller.themes;
    final windowSize = WindowSizeScope.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    return StratumAppConfig(
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

/// Builds [builder] with the platform locale, again on each platform
/// locale change: nothing above the app widget notifies one.
class _PlatformLocaleBuilder extends StatefulWidget {
  const new({required this.builder});

  final Widget Function(BuildContext context, Locale locale) builder;

  @override
  State<_PlatformLocaleBuilder> createState() => _PlatformLocaleBuilderState();
}

class _PlatformLocaleBuilderState extends State<_PlatformLocaleBuilder>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeLocales(List<Locale>? locales) => setState(() {});

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, View.of(context).platformDispatcher.locale);
}

/// Shows [child] and reports [failure] to [FlutterError.reportError] once,
/// when first built, however often the frame rebuilds.
class _ReportedStartFailure extends StatefulWidget {
  const new({required this.failure, required this.child});

  final Object failure;

  final Widget child;

  @override
  State<_ReportedStartFailure> createState() => _ReportedStartFailureState();
}

class _ReportedStartFailureState extends State<_ReportedStartFailure> {
  @override
  void initState() {
    super.initState();
    final failure = widget.failure;
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: failure,
        stack: failure is Error ? failure.stackTrace : null,
        library: 'stratum_ui',
        context: ErrorDescription('while preloading the start theme'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
