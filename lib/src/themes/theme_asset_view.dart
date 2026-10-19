import 'package:lottie/lottie.dart' show Lottie;
import 'package:stratum_ui/src/src.dart';
import 'package:stratum_ui/src/themes/remote/remote_theme_bundle.dart';

enum _Slot { splashScreen, loading }

/// Shows an asset slot of the active theme by its kind (spec D4, section
/// 11): an image, an SVG, or a Lottie animation.
///
/// Reads `StratumTheme.of(context).assets`, so a theme switch shows the new
/// theme's asset. A slot a theme installed from a zip sets reads its file
/// from that zip through the controller's overlay bundle; every other slot
/// reads from [DefaultAssetBundle] (FO-03 US-07 FR-02 E04). Under reduced
/// motion a Lottie asset holds a still frame, and an animated GIF or WebP
/// pauses on its first frame too, by the same `context.reducesMotion` rule
/// (FO-03 US-07 FR-02 E05).
class StratumThemeAssetView extends StatelessWidget {
  /// The `loading` slot.
  const new loading({
    super.key,
    this.placeholder = const SizedBox.shrink(),
    this.width,
    this.height,
    this.fit,
  }) : _slot = _Slot.loading;

  /// The `splash-screen` slot.
  const new splashScreen({
    super.key,
    this.placeholder = const SizedBox.shrink(),
    this.width,
    this.height,
    this.fit,
  }) : _slot = _Slot.splashScreen;

  final _Slot _slot;

  /// Shown when the slot is empty or its file fails to load.
  final Widget placeholder;
  final double? width;
  final double? height;
  final BoxFit? fit;

  @override
  Widget build(BuildContext context) {
    final assets = StratumTheme.of(context).assets;
    final asset = switch (_slot) {
      _Slot.splashScreen => assets.splashScreen,
      _Slot.loading => assets.loading,
    };
    if (asset == null) return placeholder;
    final bundle = asset.path.startsWith('${RemoteThemeBundle.root}/')
        ? StratumThemeController.maybeOf(context)?.remoteBundle
        : null;
    return switch (asset.kind) {
      StratumAssetKind.image => TickerMode(
        // Flutter's Image already pauses an animated GIF or WebP when
        // MediaQueryData.disableAnimations is true; TickerMode.of(context)
        // folds in the platform's reduce-motion flag too, the half
        // context.reducesMotion adds (FO-03 US-07 FR-02 E05).
        enabled: !context.reducesMotion,
        child: Image.asset(
          asset.path,
          bundle: bundle,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => placeholder,
        ),
      ),
      StratumAssetKind.svg => SvgPicture.asset(
        asset.path,
        bundle: bundle,
        width: width,
        height: height,
        fit: fit ?? BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => placeholder,
      ),
      StratumAssetKind.lottie => Lottie.asset(
        asset.path,
        bundle: bundle,
        width: width,
        height: height,
        fit: fit,
        animate: !context.reducesMotion,
        errorBuilder: (context, error, stackTrace) => placeholder,
      ),
    };
  }
}
