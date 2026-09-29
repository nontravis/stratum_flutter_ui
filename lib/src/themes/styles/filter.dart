import 'package:stratum_ui/src/src.dart';

part 'generated/filter.freezed.dart';

@freezed
abstract class AppImageFilter with _$AppImageFilter {
  const factory AppImageFilter({
    @Default(0.0) double sigmaX,
    @Default(0.0) double sigmaY,
    TileMode? tileMode,
  }) = _AppImageFilter;

  const AppImageFilter._();

  ImageFilter get blur => ImageFilter.blur(
        sigmaX: sigmaX,
        sigmaY: sigmaY,
        tileMode: tileMode,
      );
}

class AppFilter {
  const AppFilter({
    this.xs = const AppImageFilter(
      sigmaX: 4,
      sigmaY: 4,
    ),
    this.sm = const AppImageFilter(
      sigmaX: 8,
      sigmaY: 8,
    ),
    this.md = const AppImageFilter(
      sigmaX: 16,
      sigmaY: 16,
    ),
    this.lg = const AppImageFilter(
      sigmaX: 24,
      sigmaY: 24,
    ),
    this.xl = const AppImageFilter(
      sigmaX: 40,
      sigmaY: 40,
    ),
  });

  final AppImageFilter xs;
  final AppImageFilter sm;
  final AppImageFilter md;
  final AppImageFilter lg;
  final AppImageFilter xl;
}
