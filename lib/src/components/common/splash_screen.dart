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
final class StratumSplashFailed<T> extends StratumSplashState<T> {
  const new(this.error, this.phase, this.retry);

  /// What the step threw: a `StratumThemeFormatException` for a start theme
  /// file with problems, else what `postload` threw (FR-01 E01, E02).
  final Object error;

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
  /// package fetches no data and bounds no time of it (FR-06 E02).
  final Future<T> Function(
    BuildContext context,
    StratumThemeController controller,
  )
  postload;

  /// Draws the frame of every state, [StratumSplashDone]'s the app itself
  /// (FR-01 E04, E05).
  final Widget Function(BuildContext context, StratumSplashState<T> state)
  builder;

  /// How long the splash stays at least, counted from the first frame it
  /// shows and running beside [postload] (FR-03); a retry does not restart
  /// it.
  final Duration minimumDuration;

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

  /// The state on screen; null while the first frame is held.
  StratumSplashState<T>? _state;

  /// What `postload` returned, once it returned.
  ({T data})? _result;

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
    } on Object catch (error) {
      if (mounted) _show(_failed(error, StratumSplashPhase.theme));
      return;
    }
    if (!mounted) {
      controller.dispose();
      return;
    }
    _controller = controller;
    await _runPostload(controller);
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
    } on Object catch (error) {
      if (mounted) _show(_failed(error, StratumSplashPhase.postload));
      return;
    }
    if (!mounted) return;
    _result = (data: data);
    _finishIfReady();
  }

  /// A [StratumSplashFailed] whose retry runs [phase] again, only while it
  /// is the state on screen (FR-06); the package itself retries nothing
  /// (E03).
  StratumSplashFailed<T> _failed(Object error, StratumSplashPhase phase) {
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
    });
  }

  /// Shows [state]. The first call ends the first-frame hold (FR-02) and
  /// starts the minimum display time (FR-03).
  void _show(StratumSplashState<T> state) {
    setState(() => _state = state);
    if (!_holding) return;
    _holding = false;
    WidgetsBinding.instance.allowFirstFrame();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    // The first frame is held: no frame of the theme preload at launch
    // reaches the screen, so the builder first runs when the hold ends
    // (FR-02 E01).
    if (state == null) return const SizedBox.shrink();
    final frame = Builder(builder: (context) => widget.builder(context, state));
    final controller = _controller;
    if (controller == null) return frame;
    return StratumThemeApplication.controlled(
      controller: controller,
      themeMode: ThemeMode.system,
      child: frame,
    );
  }
}
