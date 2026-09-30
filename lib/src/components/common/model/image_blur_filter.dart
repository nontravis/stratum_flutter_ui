import 'dart:ui' show ImageFilter, TileMode, lerpDouble;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'generated/image_blur_filter.freezed.dart';

@freezed
abstract class ImageBlurFilter with _$ImageBlurFilter {
  const factory ImageBlurFilter({
    @Default(0.0) double sigmaX,
    @Default(0.0) double sigmaY,
    TileMode? tileMode,
  }) = _ImageBlurFilter;

  const ImageBlurFilter._();

  ImageFilter get blur => ImageFilter.blur(
        sigmaX: sigmaX,
        sigmaY: sigmaY,
        tileMode: tileMode,
      );

  /// Interpolates the sigmas; a null side counts as sigma 0.
  ///
  /// [tileMode] switches at `t = 0.5`. Sigmas never go below 0, so a curve
  /// that overshoots cannot produce an invalid blur.
  static ImageBlurFilter? lerp(
    ImageBlurFilter? a,
    ImageBlurFilter? b,
    double t,
  ) {
    if (identical(a, b)) return a;
    double sigma(double? from, double? to) {
      final value = lerpDouble(from ?? 0, to ?? 0, t)!;
      return value < 0 ? 0 : value;
    }

    return ImageBlurFilter(
      sigmaX: sigma(a?.sigmaX, b?.sigmaX),
      sigmaY: sigma(a?.sigmaY, b?.sigmaY),
      tileMode: t < 0.5 ? a?.tileMode : b?.tileMode,
    );
  }
}
