import 'dart:ui' show TileMode;

import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_ui/src/components/common/model/image_blur_filter.dart';

void main() {
  group('ImageBlurFilter.lerp', () {
    test('returns null when both sides are null', () {
      expect(ImageBlurFilter.lerp(null, null, 0.5), isNull);
    });

    test('interpolates both sigmas', () {
      final result = ImageBlurFilter.lerp(
        const ImageBlurFilter(sigmaX: 4, sigmaY: 8),
        const ImageBlurFilter(sigmaX: 8, sigmaY: 16),
        0.5,
      );

      expect(result, const ImageBlurFilter(sigmaX: 6, sigmaY: 12));
    });

    test('treats a null side as sigma 0', () {
      final result = ImageBlurFilter.lerp(
        null,
        const ImageBlurFilter(sigmaX: 10, sigmaY: 10),
        0.25,
      );

      expect(result, const ImageBlurFilter(sigmaX: 2.5, sigmaY: 2.5));
    });

    test('switches tileMode at t = 0.5', () {
      const a = ImageBlurFilter(tileMode: TileMode.clamp);
      const b = ImageBlurFilter(tileMode: TileMode.mirror);

      expect(ImageBlurFilter.lerp(a, b, 0.4)!.tileMode, TileMode.clamp);
      expect(ImageBlurFilter.lerp(a, b, 0.6)!.tileMode, TileMode.mirror);
    });

    test('never returns a negative sigma when the curve overshoots', () {
      final result = ImageBlurFilter.lerp(
        const ImageBlurFilter(sigmaX: 4, sigmaY: 4),
        const ImageBlurFilter(),
        1.5,
      );

      expect(result!.sigmaX, 0);
      expect(result.sigmaY, 0);
    });
  });
}
