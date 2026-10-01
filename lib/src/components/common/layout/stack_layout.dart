import 'package:stratum_ui/src/src.dart';

/// A [Stack] on [BoxLayout]: style, interaction, semantics, and scrolling
/// come from the base class.
///
/// [clipBehavior] clips the stack's own children; the box clips through
/// `style.clipBehavior`. `scrollable` scrolls vertically.
class StackLayout extends BoxLayout {
  const new({
    super.key,
    super.style,
    super.ratio,
    super.rotate,
    super.transform,
    super.transformAlignment,
    super.keepAlive,
    super.repaintBoundary,
    super.debug,
    super.semantics,
    super.onEndAnimate,
    super.interaction,
    super.scrollable,
    this.alignment = AlignmentDirectional.topStart,
    this.fit = StackFit.loose,
    this.textDirection,
    this.clipBehavior = Clip.hardEdge,
    required this.children,
  });

  /// Aligns each non-positioned child within the stack's own bounds;
  /// [WidgetStyle.alignment] places the whole stack inside the box's padded
  /// content instead.
  final AlignmentGeometry alignment;
  final StackFit fit;
  final TextDirection? textDirection;

  /// Clips the stack's children that overflow its bounds;
  /// [WidgetStyle.clipBehavior] cuts at the box edge instead.
  final Clip clipBehavior;
  final List<Widget> children;

  @override
  Widget buildContent(BuildContext context) {
    return Stack(
      alignment: alignment,
      textDirection: textDirection,
      fit: fit,
      clipBehavior: clipBehavior,
      children: children,
    );
  }
}
