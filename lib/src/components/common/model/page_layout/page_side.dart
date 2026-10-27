import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stratum_ui/src/themes/value_model.dart';

part 'generated/page_side.freezed.dart';

/// How a `PageLayout` side opens as a drawer (US-19 FR-02; layout s03
/// INV-65).
enum PageDrawerType {
  /// The drawer moves in over the still page.
  front,

  /// The page moves aside to show the still drawer behind it.
  back,

  /// The drawer and the page move together.
  slide,

  /// The drawer shows and hides with no motion.
  permanent,

  /// The drawer content opens as a new page through the page transitions,
  /// and closes by going back.
  page,
}

/// How one side of a `PageLayout` behaves as a drawer (US-19 FR-02, FR-04,
/// FR-05); its width bounds also bound the side's inline pane (FR-06).
@valueModel
class PageSide with _$PageSide {
  const new({
    this.type,
    this.minWidth,
    this.maxWidth,
    this.pageScale,
    this.semanticsLabel,
  }) : assert(
         pageScale == null || (pageScale > 0 && pageScale <= 1),
         'A page scale is a share of the page size, above 0 and at most 1.',
       );

  /// How the drawer opens; null takes `slide` on iOS and `front` elsewhere.
  final PageDrawerType? type;

  /// The drawer's and the inline pane's least width, in logical pixels.
  final double? minWidth;

  /// The drawer's and the inline pane's greatest width, in logical pixels;
  /// null takes 360 for the drawer and leaves the pane unbounded.
  final double? maxWidth;

  /// The scale a `back` or `slide` drawer gives the page at full open, which
  /// then rounds its corners with the screen corner radius; null scales
  /// nothing.
  final double? pageScale;

  /// The label screen readers read for the open drawer; null reads the
  /// built-in drawer label in the current language.
  final String? semanticsLabel;
}
