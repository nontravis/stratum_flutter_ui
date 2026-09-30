import 'package:stratum_ui/src/src.dart';

class AppFilter {
  const AppFilter({
    this.xs = const ImageBlurFilter(
      sigmaX: 4,
      sigmaY: 4,
    ),
    this.sm = const ImageBlurFilter(
      sigmaX: 8,
      sigmaY: 8,
    ),
    this.md = const ImageBlurFilter(
      sigmaX: 16,
      sigmaY: 16,
    ),
    this.lg = const ImageBlurFilter(
      sigmaX: 24,
      sigmaY: 24,
    ),
    this.xl = const ImageBlurFilter(
      sigmaX: 40,
      sigmaY: 40,
    ),
  });

  final ImageBlurFilter xs;
  final ImageBlurFilter sm;
  final ImageBlurFilter md;
  final ImageBlurFilter lg;
  final ImageBlurFilter xl;
}
