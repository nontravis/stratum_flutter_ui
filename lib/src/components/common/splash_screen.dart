import 'package:animations/animations.dart' show PageTransitionSwitcher;
import 'package:stratum_ui/src/animations/screen_transition.dart';
import 'package:stratum_ui/src/components/common/l10n/built_in_labels.dart';
import 'package:stratum_ui/src/components/common/splash_signal/splash_signal_none.dart'
    if (dart.library.js_interop) 'package:stratum_ui/src/components/common/splash_signal/splash_signal_web.dart';
import 'package:stratum_ui/src/components/common/widget_settings/widget_settings_resolution.dart';
import 'package:stratum_ui/src/src.dart';

/// The step of [StratumSplashScreen] that failed, which
/// [StratumSplashFailed.retry] runs again (FO-03 US-12 FR-01, FR-06).
enum StratumSplashPhase {
  /// The start theme preload.
  theme,

  /// The app's start-up work, [StratumSplashScreen.postload].
  postload,
}

/// The one state [StratumSplashScreen.builder] draws at a time (FO-03 US-12
/// FR-01; themes `s03_domain.md` invariant 25).
sealed class StratumSplashState<T> {
  const new();
}

/// The start theme loads. No frame of it reaches the screen at launch,
/// since the splash holds the engine's first frame until preload ends
/// (FR-02 E01); a retry after a theme failure shows it (FR-06).
final class StratumSplashLoadingTheme<T> extends StratumSplashState<T> {
  const new();
}

/// The start theme is active, and [StratumSplashScreen.postload] runs with
/// [controller].
final class StratumSplashLoadingApp<T> extends StratumSplashState<T> {
  const new(this.controller);

  /// The controller of the active start theme.
  final StratumThemeController controller;
}

/// A step failed: [error] is what it threw, unchanged, [phase] is the step,
/// and [retry] runs that step again on the EndUser's tap (FR-06).
///
/// If the app's own [AssetBundle] cannot read the package's embedded
/// default theme either, this frame has no theme above it at all —
/// `StratumThemeApplication.of` throws inside it — and the read failure
/// reaches `FlutterError.reportError` on its own; fix the bundle, since the
/// package has nothing left to fall back to (FR-07 E01).
final class StratumSplashFailed<T> extends StratumSplashState<T> {
  const new(
    this.error,
    this.phase,
    this.retry, {
    this.stackTrace = StackTrace.empty,
  });

  /// What the step threw: a `StratumThemeFormatException` for a start theme
  /// file with problems, else what `postload` threw (FR-01 E01, E02).
  final Object error;

  /// [error]'s stack trace, for your own crash reporting; `StackTrace.empty`
  /// when none was caught with it.
  final StackTrace stackTrace;

  /// The step that failed.
  final StratumSplashPhase phase;

  /// Runs [phase] again. It does nothing once this state has left the
  /// screen, so a second tap runs the step once.
  final VoidCallback retry;
}

/// `postload` returned [data] and the minimum display time passed: the
/// builder returns the app itself, which takes [controller] (FR-01 E05).
final class StratumSplashDone<T> extends StratumSplashState<T> {
  const new(this.controller, this.data);

  /// The controller of the active theme; the app hands it to its own
  /// `StratumThemeApplication.controlled`.
  final StratumThemeController controller;

  /// What `postload` returned.
  final T data;
}

/// A splash screen above the app's `MaterialApp` (FO-03 US-12).
///
/// Holds the engine's first frame while it preloads the start theme
/// through [StratumThemeController.preload], the call
/// `StratumThemePreloader` makes, then runs [postload] with the controller
/// and hands [builder] one [StratumSplashState] at a time, every state
/// included: it draws no frame of its own. Preload starts once, with the
/// [AssetBundle] of [DefaultAssetBundle.of]; the controller it makes lives
/// until this widget leaves the tree.
class StratumSplashScreen<T> extends StatefulWidget {
  const new({
    super.key,
    this.initialThemeId,
    this.onThemeChanged,
    this.googleFontsTimeout = const Duration(seconds: 3),
    this.remoteThemes = const [],
    this.onRemoteThemeError,
    required this.postload,
    required this.builder,
    this.minimumDuration = Duration.zero,
    this.exitTransition = ScreenTransitionType.fadeThrough,
    this.exitDuration,
    this.exitCurve,
    this.themeMode = ThemeMode.system,
    this.highContrast = StratumHighContrastMode.system,
    this.loadingLabel,
    this.widgetSettings,
  });

  /// The theme id the app saved, else null for `default`.
  final String? initialThemeId;

  /// Called with each new active theme id; at preload only on the fallback
  /// to `default`.
  final ValueChanged<String>? onThemeChanged;

  /// How long preload and every switch wait for Google fonts; the theme
  /// step's only time limit (FR-06 E02).
  final Duration googleFontsTimeout;

  /// The theme zips the app kept, installed in list order before the start
  /// theme is picked (FO-04 US-01 FR-04).
  final List<StratumRemoteTheme> remoteThemes;

  /// Called once for each kept zip that fails to install.
  final void Function(String id, StratumRemoteThemeException error)?
  onRemoteThemeError;

  /// The app's own start-up work, run with the controller once the start
  /// theme is active; what it returns reaches [StratumSplashDone.data]. The
  /// package fetches no data and bounds no time of it (FR-06 E02). This
  /// [BuildContext] sits above the splash's own theme scope: read the
  /// active theme through `controller`, never `StratumTheme.of(context)`.
  final Future<T> Function(
    BuildContext context,
    StratumThemeController controller,
  )
  postload;

  /// Draws the frame of every state, [StratumSplashDone]'s the app itself
  /// (FR-01 E04, E05). Every frame before done has no `Overlay` and no
  /// `Localizations` above it — no `Tooltip`, no `TextField` — until the
  /// app's own `MaterialApp`; Tab and Enter or Space still reach a
  /// focusable node in it, through the splash's own default `Shortcuts`
  /// and `Actions` (NFR-U02).
  final Widget Function(BuildContext context, StratumSplashState<T> state)
  builder;

  /// How long the splash stays at least, counted from the first frame it
  /// shows and running beside [postload] (FR-03); a retry does not restart
  /// it.
  final Duration minimumDuration;

  /// How the app takes over from the splash, in place with no route
  /// (FR-04): every type of FO-05 US-05 FR-01 but `platform` and
  /// `cupertino`, which need a page route and fail a debug assertion that
  /// names the types an exit takes; a release build plays `fadeThrough`
  /// for them. Under reduced motion it follows FO-05 US-05 FR-03 for its
  /// type, as every page route does.
  final ScreenTransitionType exitTransition;

  /// The exit's duration; null takes the push duration a page route of
  /// [exitTransition] takes, the theme's `slow` level (FR-04 E04).
  final Duration? exitDuration;

  /// The exit's curve; null takes the theme's `standard` curve (FR-04 E04).
  final Curve? exitCurve;

  /// The theme mode of the splash frames: pass the one the app gives its
  /// `StratumThemeApplication`, so the splash and the app show the same
  /// data (FR-07 E02).
  final ThemeMode themeMode;

  /// The high-contrast mode of the splash frames: pass the one the app
  /// gives its `StratumThemeApplication` (FR-07 E02).
  final StratumHighContrastMode highContrast;

  /// What screen readers hear on every loading frame, the app's own frames
  /// included; null reads FO-09's built-in loading label in the platform
  /// locale's language (FR-08).
  final String? loadingLabel;

  /// The widget settings this splash loads beside the start theme, under
  /// the held first frame (PD8): the one passed, else the scope above,
  /// else one of its own (PD9), read once at the first build. Pass one
  /// of your own to call `switchUser` from [postload].
  final StratumWidgetSettingsController? widgetSettings;

  @override
  State<StratumSplashScreen<T>> createState() => _StratumSplashScreenState<T>();
}

class _StratumSplashScreenState<T> extends State<StratumSplashScreen<T>> {
  late final AssetBundle _bundle;
  bool _started = false;

  /// Whether the engine's first frame is still held (FR-02).
  bool _holding = true;

  bool _minimumPassed = false;
  Timer? _minimumTimer;
  StratumThemeController? _controller;

  /// The package's embedded default theme alone, read after a theme-phase
  /// failure (FR-07 E01).
  StratumThemeSet? _packageDefault;

  /// The state on screen; null while the first frame is held.
  StratumSplashState<T>? _state;

  /// What `postload` returned, once it returned.
  ({T data})? _result;

  /// Keys the non-done frame, [_appKey] the app at done, both for the
  /// whole life of this State: a [GlobalKey] moves its Element to a new
  /// slot instead of unmounting it, so a change in the exit's own widget
  /// type (for example, reduced motion flipping `FadeThroughTransition` to
  /// `FadeTransition`) reparents the frame or the app rather than
  /// rebuilding it from scratch (mirrors Flutter's own routes,
  /// `routes.dart:1228-1229`).
  final GlobalKey _frameKey = GlobalKey();
  final GlobalKey _appKey = GlobalKey();

  /// The widget settings this splash resolved at the first build (PD9).
  StratumWidgetSettingsController? _settingsController;

  /// Whether this splash disposes [_settingsController] with itself: true
  /// only for one it made over the default store (PD9).
  bool _ownsSettings = false;

  /// Whether [build] places a [StratumWidgetSettings] scope around its
  /// result: true unless [_settingsController] came from a scope above
  /// (PD9), so the tree shape never changes between states.
  bool _placesSettingsScope = false;

  /// Resolves once [_settingsController]'s load ends, successfully or not
  /// (PD8); set in [didChangeDependencies], awaited in [_loadTheme].
  Future<void>? _settingsLoad;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.deferFirstFrame();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _bundle = DefaultAssetBundle.of(context);
    final (controller, owned) = resolveWidgetSettings(
      context,
      widget.widgetSettings,
    );
    _settingsController = controller;
    _ownsSettings = owned;
    _placesSettingsScope = owned || widget.widgetSettings != null;
    _settingsLoad = controller.load();
    unawaited(_loadTheme());
  }

  /// Preloads the start theme, then runs `postload`; a theme that fails
  /// shows [StratumSplashFailed] with [StratumSplashPhase.theme] (FR-01 E01).
  Future<void> _loadTheme() async {
    final StratumThemeController controller;
    try {
      controller = await StratumThemeController.preload(
        initialThemeId: widget.initialThemeId,
        onThemeChanged: widget.onThemeChanged,
        googleFontsTimeout: widget.googleFontsTimeout,
        bundle: _bundle,
        remoteThemes: widget.remoteThemes,
        onRemoteThemeError: widget.onRemoteThemeError,
      );
    } on Object catch (error, stackTrace) {
      await _readPackageDefault();
      await _settingsLoad;
      if (mounted) {
        _show(_failed(error, StratumSplashPhase.theme, stackTrace));
      }
      return;
    }
    await _settingsLoad;
    if (!mounted) {
      controller.dispose();
      return;
    }
    _controller = controller;
    await _runPostload(controller);
  }

  /// Reads the package default theme alone, once, for the frames of a
  /// theme-phase failure and its retry (FR-07 E01; themes `s03_domain.md`
  /// invariant 29). A read that fails is reported, and the failed state
  /// still ends the first-frame hold (FR-02 E03), with no theme above it.
  Future<void> _readPackageDefault() async {
    if (_packageDefault != null) return;
    try {
      _packageDefault = await StratumThemeController.packageDefaultThemes(
        bundle: _bundle,
      );
    } on Object catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'stratum_ui',
          context: ErrorDescription(
            'while reading the package default theme for the splash screen',
          ),
        ),
      );
    }
  }

  /// Shows [StratumSplashLoadingApp] while `postload` runs; a throw shows
  /// [StratumSplashFailed] with [StratumSplashPhase.postload] (FR-01 E02),
  /// and a result that arrives after this widget left the tree is dropped
  /// (FR-01 E03).
  Future<void> _runPostload(StratumThemeController controller) async {
    _show(StratumSplashLoadingApp<T>(controller));
    final T data;
    try {
      data = await widget.postload(context, controller);
    } on Object catch (error, stackTrace) {
      if (mounted) {
        _show(_failed(error, StratumSplashPhase.postload, stackTrace));
      }
      return;
    }
    if (!mounted) return;
    _result = (data: data);
    _finishIfReady();
  }

  /// A [StratumSplashFailed] whose retry runs [phase] again, only while it
  /// is the state on screen (FR-06); the package itself retries nothing
  /// (E03).
  StratumSplashFailed<T> _failed(
    Object error,
    StratumSplashPhase phase,
    StackTrace stackTrace,
  ) {
    late final StratumSplashFailed<T> failed;
    return failed = StratumSplashFailed<T>(error, phase, () {
      if (!mounted || !identical(_state, failed)) return;
      switch (phase) {
        case StratumSplashPhase.theme:
          _show(StratumSplashLoadingTheme<T>());
          unawaited(_loadTheme());
        case StratumSplashPhase.postload:
          unawaited(_runPostload(_controller!));
      }
    }, stackTrace: stackTrace);
  }

  /// Shows [state]. The first call ends the first-frame hold, signals the
  /// page on the web once that frame is drawn (FR-02, E02), and starts the
  /// minimum display time (FR-03).
  void _show(StratumSplashState<T> state) {
    setState(() => _state = state);
    if (!_holding) return;
    _holding = false;
    WidgetsBinding.instance.allowFirstFrame();
    // `allowFirstFrame` only schedules the warm-up frame; on the web both
    // halves of it run on later tasks. A post-frame callback of the next
    // frame still follows that frame being drawn, which is as close as
    // the framework's own signals get; skwasm rasterizes off the main
    // thread, so this does not promise the page's own paint either.
    WidgetsBinding.instance.addPostFrameCallback((_) => signalSplashShown());
    if (widget.minimumDuration <= Duration.zero) {
      _minimumPassed = true;
      return;
    }
    _minimumTimer = Timer(widget.minimumDuration, () {
      _minimumPassed = true;
      _finishIfReady();
    });
  }

  /// Shows [StratumSplashDone] once `postload` returned and the minimum display
  /// time passed, whichever comes later (FR-03; FR-01 E06).
  void _finishIfReady() {
    final result = _result;
    if (result == null || !_minimumPassed || !mounted) return;
    setState(() => _state = StratumSplashDone<T>(_controller!, result.data));
  }

  @override
  void dispose() {
    // A splash that leaves the tree mid-preload must not keep the app's
    // frames held.
    if (_holding) WidgetsBinding.instance.allowFirstFrame();
    _minimumTimer?.cancel();
    _controller?.dispose();
    if (_ownsSettings) _settingsController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exit = _exitTypeOf(widget.exitTransition);
    final state = _state;
    // The first frame is held: no frame of the theme preload at launch
    // reaches the screen, so the builder first runs when the hold ends
    // (FR-02 E01). The settings scope still wraps it, unchanged, so the
    // tree shape never differs between the held frame and every later
    // state (PD9).
    if (state == null) return _wrapSettings(const SizedBox.shrink());
    // Above `MaterialApp` no `Localizations` exists: the platform locale
    // picks the direction, as it picks FO-09's labels (FR-07).
    final locale =
        Localizations.maybeLocaleOf(context) ??
        View.of(context).platformDispatcher.locale;
    final loading =
        state is StratumSplashLoadingTheme<T> ||
        state is StratumSplashLoadingApp<T>;
    // One Semantics at every state, so a state change never rebuilds the
    // app's frame from scratch. A loading frame sits under a live region
    // that reads the loading label, with the app's own nodes kept apart
    // below it; the failed and done frames add no node (FR-08).
    final frame = Semantics(
      container: loading,
      explicitChildNodes: loading,
      liveRegion: loading,
      label: loading
          ? widget.loadingLabel ?? builtInLabelsFor(locale).loadingLabel
          : null,
      child: Builder(builder: (context) => widget.builder(context, state)),
    );
    final done = state is StratumSplashDone<T>;
    // Every non-done frame has no `Overlay` and no `Localizations` above
    // it, so Tab and Enter or Space would otherwise reach nothing: the
    // splash gives it the same default bindings `WidgetsApp` gives every
    // route (NFR-U02). `MaterialApp` supplies its own at done, so this
    // wrapper sits inside the keyed subtree, present at every non-done
    // state alike, never swapped in or out on a loading-to-failed change.
    final content = done
        ? frame
        : Shortcuts(
            shortcuts: WidgetsApp.defaultShortcuts,
            child: Actions(
              actions: WidgetsApp.defaultActions,
              // `WidgetsApp` autofocuses its own Navigator scope the same
              // way: with nothing focused, Tab's `primaryFocus` falls back
              // to the engine's root scope, above this Shortcuts, and the
              // key event never reaches it (`FocusNode.ancestors`
              // dartdoc, "Key Event Propagation").
              child: FocusScope(autofocus: true, child: frame),
            ),
          );
    return _wrapSettings(
      Directionality(
        textDirection: _directionOf(locale),
        child: _themed(
          _SplashExit(
            type: exit,
            duration: widget.exitDuration,
            curve: widget.exitCurve,
            // The frame and the app each keep one GlobalKey for this
            // State's whole life (FR-04): the exit still swaps between
            // them once, at done, but a later change in the exit's own
            // widget type reparents whichever one is on screen instead of
            // unmounting it.
            child: KeyedSubtree(
              key: done ? _appKey : _frameKey,
              child: content,
            ),
          ),
        ),
      ),
    );
  }

  /// [child] under [_settingsController] when it did not come from a scope
  /// above (PD9); else [child] unchanged.
  Widget _wrapSettings(Widget child) {
    if (!_placesSettingsScope) return child;
    return StratumWidgetSettings(
      controller: _settingsController!,
      child: child,
    );
  }

  /// [child] under the start theme's controller, else, after a theme-phase
  /// failure, under the package default theme alone (FR-07, E01), in the
  /// theme mode and high-contrast mode the app passes.
  Widget _themed(Widget child) {
    if (_controller case final controller?) {
      return StratumThemeApplication.controlled(
        controller: controller,
        themeMode: widget.themeMode,
        highContrast: widget.highContrast,
        child: child,
      );
    }
    if (_packageDefault case final themes?) {
      return StratumThemeApplication(
        themes: themes,
        themeMode: widget.themeMode,
        highContrast: widget.highContrast,
        child: child,
      );
    }
    return child;
  }
}

/// Switches from the splash frame to the app in place, with no route, by
/// [type] (FR-04): each side runs [buildScreenTransition] with no route,
/// the one source of the per-type motion and its reduced-motion rule that
/// every page route of FO-05 US-05 takes.
class _SplashExit extends StatelessWidget {
  const new({
    required this.type,
    required this.duration,
    required this.curve,
    required this.child,
  });

  final ScreenTransitionType type;
  final Duration? duration;
  final Curve? curve;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final slow = slowOf(context);
    return PageTransitionSwitcher(
      duration:
          duration ?? transitionDurationOf(type, platformOf(context), slow),
      // The default layout is `Stack(alignment: Alignment.center)`, loose
      // constraints: a frame with no intrinsic size (a plain ColoredBox,
      // for example) would lay out at 0x0 instead of the view's size.
      layoutBuilder: (entries) =>
          Stack(fit: StackFit.expand, children: entries),
      transitionBuilder: (child, animation, secondaryAnimation) =>
          buildScreenTransition<void>(
            type,
            context: context,
            animation: animation,
            secondaryAnimation: secondaryAnimation,
            child: child,
            standard: curveOf(slow),
            curve: curve,
            alignment: Alignment.center,
            joinOnSecondary: true,
          ),
      child: child,
    );
  }
}

/// [type] when an exit in place takes it, else `fadeThrough` after a debug
/// assertion that names the types an exit takes (FR-04 E01).
ScreenTransitionType _exitTypeOf(ScreenTransitionType type) {
  // `platform` and `cupertino` hand their motion to a Flutter page
  // transition, which needs a page route.
  bool inPlace(ScreenTransitionType type) =>
      flutterTransitionsBuilder(type, defaultTargetPlatform) == null;
  String inPlaceNames() => [
    for (final type in ScreenTransitionType.values)
      if (inPlace(type)) type.name,
  ].join(', ');
  assert(
    inPlace(type),
    'StratumSplashScreen.exitTransition is $type, which needs a page route; '
    'an exit in place takes ${inPlaceNames()}.',
  );
  return inPlace(type) ? type : ScreenTransitionType.fadeThrough;
}

/// The text direction of [locale]'s language (FR-07 E03).
TextDirection _directionOf(Locale locale) =>
    Bidi.isRtlLanguage(locale.languageCode)
    ? TextDirection.rtl
    : TextDirection.ltr;
