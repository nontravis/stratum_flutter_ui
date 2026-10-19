import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stratum_ui/src/themes/value_model.dart';

part 'generated/page_safe_area.freezed.dart';

/// Which sides of a `PageLayout` pad their slots by the system insets
/// (US-18 FR-04): Figma's `safeStatusBar` is [top] and its `safeIndicator`
/// is [bottom].
///
/// A false flag drops that side's padding from every slot, while every slot
/// fill still runs to the screen edge, and a slot touching that edge keeps
/// the inset in its children's media data, as `SafeArea(top: false)` does,
/// so the app's content there may pad for it (R20). [left] and [right] name
/// the sides the `left` and `right` slots sit on, the start and end sides,
/// so under `TextDirection.rtl` [left] is the right edge.
@valueModel
class PageSafeArea with _$PageSafeArea {
  const new({
    this.top = true,
    this.bottom = true,
    this.left = true,
    this.right = true,
  });

  /// Whether slots pad by the status bar.
  final bool top;

  /// Whether slots pad by the home indicator.
  final bool bottom;

  /// Whether slots pad by the start side's inset.
  final bool left;

  /// Whether slots pad by the end side's inset.
  final bool right;
}
