import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:stratum_ui/src/components/common/layout/container_layout.dart';
import 'package:stratum_ui/src/components/common/model/widget_style.dart';

class RowLayout extends StatelessWidget {
  const RowLayout({
    super.key,
    this.style,
    this.ratio,
    this.rotate,
    this.keepAlive = false,
    this.repaintBoundary = false,
    this.debug = false,
    this.transform,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.max,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.textDirection,
    this.verticalDirection = VerticalDirection.down,
    this.textBaseline,
    this.crossAxisIntrinsic = false,
    this.gap,
    this.scrollable = false,
    this.onEndAnimate,
    this.semantics,
    required this.children,
  });

  ///========== Frame ==========///
  final double? rotate; // 0-360 degree
  final double? ratio;

  ///========== Layout ==========///
  final Matrix4? transform;
  final bool keepAlive;
  final bool repaintBoundary;
  final bool debug;

  ///========== Style ==========///
  final WidgetStyle? style;

  MainAxisSize get _effectiveMainAxisSize =>
      style?.width != null || style?.maxWidth != null
          ? MainAxisSize.max
          : mainAxisSize;

  bool get _needsIntrinsicHeight =>
      crossAxisIntrinsic && style?.height == null;

  ///===== Semantics ======///
  final SemanticsProperties? semantics;


  ///===== Animate ======///
  final VoidCallback? onEndAnimate;

  ///===== Effect ======///

  ///====== Row ======///
  final MainAxisAlignment mainAxisAlignment;
  final MainAxisSize mainAxisSize;
  final CrossAxisAlignment crossAxisAlignment;
  final TextDirection? textDirection;
  final VerticalDirection verticalDirection;
  final TextBaseline? textBaseline;
  final bool crossAxisIntrinsic;
  final double? gap;
  final bool scrollable;

  ///===== Child Widget ======///
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    // Build Row content first
    var rowContent = _buildRowContent();

    // Apply intrinsic height only if needed
    if (_needsIntrinsicHeight) {
      rowContent = IntrinsicHeight(child: rowContent);
    }

    // Apply decorations and effects through ContainerLayout
    Widget result = ContainerLayout(
      style: style,
      ratio: ratio,
      rotate: rotate,
      keepAlive: keepAlive,
      repaintBoundary: repaintBoundary,
      debug: debug,
      transform: transform,
      onEndAnimate: onEndAnimate,
      semantics: semantics,
      child: rowContent,
    );

    // Apply scrollable wrapper last if needed
    if (scrollable) {
      result = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: result,
      );
    }

    return result;
  }

  Widget _buildRowContent() {
    return Row(
      mainAxisAlignment: mainAxisAlignment,
      mainAxisSize: _effectiveMainAxisSize,
      crossAxisAlignment: crossAxisAlignment,
      textDirection: textDirection,
      verticalDirection: verticalDirection,
      textBaseline: textBaseline,
      spacing: gap ?? 0,
      children: children,
    );
  }
}
