import 'package:stratum_ui/src/src.dart';

class ColumnLayout extends StatelessWidget {
  const ColumnLayout({
    super.key,
    this.style,
    this.ratio,
    this.rotate,
    this.keepAlive = false,
    this.repaintBoundary = false,
    this.debug = false,
    this.transform,
    this.crossAxisIntrinsic = false,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.max,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.textDirection,
    this.verticalDirection = VerticalDirection.down,
    this.textBaseline,
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
      style?.height != null || style?.maxHeight != null
          ? MainAxisSize.max
          : mainAxisSize;

  bool get _needsIntrinsicWidth => crossAxisIntrinsic && style?.width == null;

  ///===== Semantics ======///
  final SemanticsProperties? semantics;

  ///===== Animate ======///
  final VoidCallback? onEndAnimate;

  ///===== Effect ======///

  ///====== Column ======///
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
    // Build Column content first
    var columnContent = _buildColumnContent();

    // Apply intrinsic width only if needed
    if (_needsIntrinsicWidth) {
      columnContent = IntrinsicWidth(child: columnContent);
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
      child: columnContent,
    );

    // Apply scrollable wrapper last if needed
    if (scrollable) {
      result = _buildScrollableWrapper(result);
    }

    return result;
  }

  Widget _buildColumnContent() {

    return Column(
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

  Widget _buildScrollableWrapper(Widget child) {
    // Simple case for non-max main axis size
    if (_effectiveMainAxisSize != MainAxisSize.max) {
      return SingleChildScrollView(
        scrollDirection: Axis.vertical,
        clipBehavior: Clip.none,
        child: child,
      );
    }

    // Complex case with layout builder for max size
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.vertical,
        clipBehavior: Clip.none,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.maxHeight,
          ),
          child: child,
        ),
      ),
    );
  }

}
