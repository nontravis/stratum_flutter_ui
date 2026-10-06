import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stratum_ui/src/themes/config/theme_model.dart';
import 'package:stratum_ui/src/themes/constant/font_type.dart';
import 'package:stratum_ui/src/themes/typography/dimension.dart';

part 'generated/typography_models.freezed.dart';

/// The fonts one type uses under one locale tag.
@immutable
@themeModel
class StratumFontRef with _$StratumFontRef {
  const new({required this.font, this.mono});

  /// Key into `StratumTypography.fonts`.
  final String font;

  /// Key into `StratumTypography.fonts` that `.mono` swaps to, or null.
  final String? mono;

  @override
  String toString() => 'StratumFontRef(font: $font, mono: $mono)';
}

/// The fonts of one `typography.families` entry, that is one locale tag.
@themeModel
abstract class StratumFamilySet with _$StratumFamilySet {
  const factory({
    /// The fonts of each type this tag names.
    required Map<FontType, StratumFontRef> types,

    /// Key of the theme-wide mono font of this tag, for `.mono` on a type
    /// without a mono font of its own, or null.
    String? mono,
  }) = _StratumFamilySet;

  const new _();

  @override
  String toString() => 'StratumFamilySet(types: $types, mono: $mono)';
}

/// The line spacing and tracking of one type at one size.
@immutable
@themeModel
class StratumSizeMetrics with _$StratumSizeMetrics {
  const new({
    required this.spaceHeight,
    this.letterSpacing = const StratumDimension.fixed(0),
  });

  /// Added to the size to give the line box; a percent resolves against
  /// the scaled requested size, before the window scale.
  final StratumDimension spaceHeight;

  /// The tracking; a percent resolves against the scaled size.
  final StratumDimension letterSpacing;

  @override
  String toString() =>
      'StratumSizeMetrics(spaceHeight: $spaceHeight, '
      'letterSpacing: $letterSpacing)';
}
