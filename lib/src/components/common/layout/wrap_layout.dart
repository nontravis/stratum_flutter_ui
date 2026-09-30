import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:stratum_ui/src/components/common/layout/container_layout.dart';
import 'package:stratum_ui/src/components/common/model/widget_style.dart';

class WrapLayout extends StatelessWidget {
  const WrapLayout({
    super.key,
    this.style,
    this.ratio,
    this.rotate,
    this.keepAlive = false,
    this.repaintBoundary = false,
    this.debug = false,
    this.transform,
    this.direction = Axis.horizontal,
    this.alignment = WrapAlignment.start,
    this.spacing,
    this.runAlignment = WrapAlignment.start,
    this.runSpacing,
    this.crossAxisAlignment = WrapCrossAlignment.start,
    this.textDirection,
    this.verticalDirection = VerticalDirection.down,
    this.clipBehavior = Clip.none,
    this.gap,
    this.scrollable = false,
    this.onEndAnimate,
    this.semantics,
    required this.children,
  }) : _effectiveSpacing = spacing ?? gap ?? 0.0,
       _effectiveRunSpacing = runSpacing ?? gap ?? 0.0,
       _hasContainerFeatures = style != null ||
           ratio != null ||
           rotate != null ||
           transform != null ||
           keepAlive ||
           repaintBoundary ||
           debug ||
           semantics != null;

  ///========== Frame ==========///
  final double? rotate; // 0-360 degree
  final double? ratio;

  ///========== Layout ==========///
  final Matrix4? transform;
  final bool keepAlive;
  final bool repaintBoundary;
  final bool debug;


  ///===== Animate ======///
  final VoidCallback? onEndAnimate;

  ///===== Effect ======///

  ///====== Wrap ======///
  final Axis direction;
  final WrapAlignment alignment;
  final double? spacing;
  final WrapAlignment runAlignment;
  final double? runSpacing;
  final WrapCrossAlignment crossAxisAlignment;
  final TextDirection? textDirection;
  final VerticalDirection verticalDirection;
  final Clip clipBehavior;
  final double? gap;
  final bool scrollable;

  final SemanticsProperties? semantics;


  ///========== Style ==========///
  final WidgetStyle? style;

  ///===== Child Widget ======///
  final List<Widget> children;

  // Pre-computed values
  final double _effectiveSpacing;
  final double _effectiveRunSpacing;
  final bool _hasContainerFeatures;

  @override
  Widget build(BuildContext context) {
    // Build the core Wrap widget
    Widget wrapWidget = Wrap(
      direction: direction,
      alignment: alignment,
      spacing: _effectiveSpacing,
      runSpacing: _effectiveRunSpacing,
      runAlignment: runAlignment,
      crossAxisAlignment: crossAxisAlignment,
      textDirection: textDirection,
      verticalDirection: verticalDirection,
      clipBehavior: clipBehavior,
      children: children,
    );

    // Apply container features only if needed
    if (_hasContainerFeatures) {
      wrapWidget = ContainerLayout(
        style: style,
        ratio: ratio,
        rotate: rotate,
        keepAlive: keepAlive,
        repaintBoundary: repaintBoundary,
        debug: debug,
        transform: transform,
        onEndAnimate: onEndAnimate,
        semantics: semantics,
        child: wrapWidget,
      );
    }

    // Apply scrollable wrapper only if needed
    if (scrollable) {
      return SingleChildScrollView(
        scrollDirection: direction,
        child: wrapWidget,
      );
    }

    return wrapWidget;
  }
}
