import 'dart:ui' show ImageFilter, TileMode;

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
}
