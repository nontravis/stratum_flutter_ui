import 'package:lottie/lottie.dart' show Lottie;
import 'package:stratum_ui/src/components/common/style/reduced_motion.dart';
import 'package:stratum_ui/src/src.dart';

enum _Slot { splashScreen, loading }

/// Shows an asset slot of the active theme by its kind (spec D4, section
/// 11): an image, an SVG, or a Lottie animation.
///
/// Reads `StratumTheme.of(context).assets`, so a theme switch shows the new
/// theme's asset. Bundled assets only: the files of an installed zip
/// theme are sub-project 5. Under reduced motion a Lottie asset holds a
/// still frame; an animated GIF or WebP plays as Flutter's [Image] plays
/// it.
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
    return switch (asset.kind) {
      StratumAssetKind.image => Image.asset(
        asset.path,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => placeholder,
      ),
      StratumAssetKind.svg => SvgPicture.asset(
        asset.path,
        width: width,
        height: height,
        fit: fit ?? BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => placeholder,
      ),
      StratumAssetKind.lottie => Lottie.asset(
        asset.path,
        width: width,
        height: height,
        fit: fit,
        animate: !reducesMotion(context),
        errorBuilder: (context, error, stackTrace) => placeholder,
      ),
    };
  }
}
