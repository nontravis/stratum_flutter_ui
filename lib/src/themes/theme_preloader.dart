import 'package:stratum_ui/src/src.dart';

/// Builds the app on a preloaded theme: shows [loading] while
/// [StratumThemeController.preload] runs, then [builder] with the
/// controller, or [error] with what preload threw (FO-03 US-01 FR-03).
///
/// The widget form of `StratumThemeController.preload`, for an app that
/// shows its own loading screen instead of awaiting preload before
/// `runApp`. Preload starts once, with the [AssetBundle] of
/// [DefaultAssetBundle.of], and keeps the [onThemeChanged],
/// [remoteThemes], and [onRemoteThemeError] this widget had then. The
/// controller it makes lives until the widget leaves the tree.
class StratumThemePreloader extends StatefulWidget {
  const new({
    super.key,
    this.initialThemeId,
    this.onThemeChanged,
    this.googleFontsTimeout = const Duration(seconds: 3),
    this.remoteThemes = const [],
    this.onRemoteThemeError,
    this.loading,
    this.error,
    required this.builder,
  });

  /// The theme id the app saved, else null for `default`.
  final String? initialThemeId;

  /// Called with each new active theme id; at preload only on the fallback
  /// to `default`.
  final ValueChanged<String>? onThemeChanged;

  /// How long preload and every switch wait for Google fonts.
  final Duration googleFontsTimeout;

  /// The theme zips the app kept, installed in list order before the start
  /// theme is picked (FO-04 US-01 FR-04).
  final List<StratumRemoteTheme> remoteThemes;

  /// Called once for each kept zip that fails to install, so the app
  /// deletes it and downloads it again; preload goes on without it. With
  /// none, the failure instead goes to [FlutterError.reportError].
  final void Function(String id, StratumRemoteThemeException error)?
  onRemoteThemeError;

  /// The frames until the start theme is active; an empty box when null.
  final WidgetBuilder? loading;

  /// The frame for what preload threw, a `StratumThemeFormatException` for
  /// a theme file with problems; when null, the exception goes to
  /// [FlutterError.reportError] and an empty box shows.
  final Widget Function(BuildContext context, Object error)? error;

  /// The app, once the start theme is active.
  final Widget Function(BuildContext context, StratumThemeController controller)
  builder;

  @override
  State<StratumThemePreloader> createState() => _StratumThemePreloaderState();
}

class _StratumThemePreloaderState extends State<StratumThemePreloader> {
  StratumThemeController? _controller;
  Object? _error;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    unawaited(_preload(DefaultAssetBundle.of(context)));
  }

  Future<void> _preload(AssetBundle bundle) async {
    StratumThemeController controller;
    try {
      controller = await StratumThemeController.preload(
        initialThemeId: widget.initialThemeId,
        onThemeChanged: widget.onThemeChanged,
        googleFontsTimeout: widget.googleFontsTimeout,
        bundle: bundle,
        remoteThemes: widget.remoteThemes,
        onRemoteThemeError: widget.onRemoteThemeError,
      );
    } on Object catch (error, stack) {
      if (!mounted) return;
      if (widget.error == null) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'stratum_ui',
            context: ErrorDescription('while preloading the start theme'),
          ),
        );
      }
      setState(() => _error = error);
      return;
    }
    if (!mounted) {
      controller.dispose();
      return;
    }
    setState(() => _controller = controller);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller case final controller?) {
      return widget.builder(context, controller);
    }
    if (_error case final error?) {
      return widget.error?.call(context, error) ?? const SizedBox.shrink();
    }
    return widget.loading?.call(context) ?? const SizedBox.shrink();
  }
}
