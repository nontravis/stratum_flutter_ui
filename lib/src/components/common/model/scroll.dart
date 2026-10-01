import 'package:stratum_ui/src/src.dart';

/// How a box layout scrolls its padding and content inside the box.
///
/// Fill, border, radius, and shadow stay in place while the padding and
/// the content scroll, as Figma overflow scrolling does; a layout with a
/// null `scroll` does not scroll. [reverse], [controller], [primary],
/// [keyboardDismissBehavior], and [restorationId] reach the
/// [SingleChildScrollView] unchanged.
///
/// The class does not override `==`: a controller compares by identity.
@immutable
class StratumScroll {
  const new({
    this.direction,
    this.fillViewport = false,
    this.reverse = false,
    this.controller,
    this.primary,
    this.physics,
    this.showScrollbar,
    this.keyboardDismissBehavior,
    this.restorationId,
  }) : assert(
         !(controller != null && (primary ?? false)),
         'A primary scroll view takes its controller from the '
         'PrimaryScrollController; pass controller or primary: true, '
         'not both',
       );

  /// The scroll axis; null keeps the layout's own axis: vertical, or
  /// horizontal for a row, or across `direction` for a wrap.
  final Axis? direction;

  /// Stretches content shorter than the viewport to the viewport, minus
  /// the padding, so `spaceBetween` and `end` alignments work.
  ///
  /// A stretching layout builds a [LayoutBuilder], which is not supported
  /// under [IntrinsicWidth], [IntrinsicHeight], `AlertDialog` content, or a
  /// parent's `crossAxisIntrinsic`. Only a finite viewport stretches: in a
  /// parent unbounded along the scroll axis the layout sizes to its
  /// content. Flipping this value between builds resets the scroll offset.
  final bool fillViewport;
  final bool reverse;
  final ScrollController? controller;
  final bool? primary;

  /// Applies on top of the theme's physics.
  final ScrollPhysics? physics;

  /// Null keeps the scroll behavior's choice: a scrollbar on desktop.
  final bool? showScrollbar;
  final ScrollViewKeyboardDismissBehavior? keyboardDismissBehavior;
  final String? restorationId;
}
