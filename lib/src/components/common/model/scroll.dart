import 'package:stratum_ui/src/src.dart';
import 'package:stratum_ui/src/themes/value_model.dart';

part 'generated/scroll.freezed.dart';

/// How a box layout scrolls its padding and content inside the box.
///
/// Fill, border, radius, and shadow stay in place while the padding and
/// the content scroll, as Figma overflow scrolling does; a layout with a
/// null `scroll` does not scroll. [reverse], [controller], [primary],
/// [keyboardDismissBehavior], and [restorationId] reach the
/// [SingleChildScrollView] unchanged. On web and desktop the scrolling box
/// is a Tab stop whose arrows, Page Up, Page Down, Home, and End scroll it.
///
/// `==` compares every field; [controller] compares by identity (R1).
@valueModel
abstract class Scroll with _$Scroll {
  @Assert(
    '!(controller != null && (primary ?? false))',
    'A primary scroll view takes its controller from the '
        'PrimaryScrollController; pass controller or primary: true, '
        'not both',
  )
  const factory({
    /// The scroll axis; null keeps the layout's own axis: vertical, or
    /// horizontal for a row, or across `direction` for a wrap.
    Axis? direction,

    /// Stretches content shorter than the viewport to the viewport, minus
    /// the padding, so `spaceBetween` and `end` alignments work.
    ///
    /// A stretching layout builds a [LayoutBuilder], which is not supported
    /// under [IntrinsicWidth], [IntrinsicHeight], `AlertDialog` content, or a
    /// parent's `crossAxisIntrinsic`. Only a finite viewport stretches: in a
    /// parent unbounded along the scroll axis the layout sizes to its
    /// content. Flipping this value between builds resets the scroll offset.
    @Default(false) bool fillViewport,
    @Default(false) bool reverse,
    ScrollController? controller,
    bool? primary,

    /// Applies on top of the theme's physics.
    ScrollPhysics? physics,

    /// Null keeps the scroll behavior's choice: a scrollbar on desktop.
    bool? showScrollbar,
    ScrollViewKeyboardDismissBehavior? keyboardDismissBehavior,
    String? restorationId,

    /// A scrolling box's focus ring style, level 3, beside the box layout's
    /// `style`, which draws the box; the box hands it to its `ScrollFocus`
    /// as `customStyle` (FO-06 US-07 FR-03).
    ScrollFocusStyle? scrollFocusStyle,
  }) = _Scroll;
}
