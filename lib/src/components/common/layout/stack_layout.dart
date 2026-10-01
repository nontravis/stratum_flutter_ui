import 'package:stratum_ui/src/src.dart';

class StackLayout extends StatelessWidget {
  const StackLayout({
    super.key,
    this.style,
    this.ratio,
    this.rotate,
    this.keepAlive = false,
    this.repaintBoundary = false,
    this.debug = false,
    this.clipBehavior = Clip.hardEdge,
    this.transform,
    this.alignment = AlignmentDirectional.topStart,
    this.fit = StackFit.loose,
    this.textDirection,
    this.scrollable = false,
    this.onEndAnimate,
    this.semantics,
    required this.children,
  }) : _hasContainerFeatures = style != null ||
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
  final Clip clipBehavior;

  ///===== Animate ======///
  final VoidCallback? onEndAnimate;
  final SemanticsProperties? semantics;


  ///===== Effect ======///

  ///====== Stack ======///
  final TextDirection? textDirection;
  final StackFit fit;
  final AlignmentGeometry alignment;
  final bool scrollable;

  ///========== Style ==========///
  final WidgetStyle? style;

  ///===== Child Widget ======///
  final List<Widget> children;

  // Pre-computed values
  final bool _hasContainerFeatures;

  @override
  Widget build(BuildContext context) {
    // Build the core Stack widget
    Widget stackWidget = Stack(
      textDirection: textDirection,
      fit: fit,
      alignment: alignment,
      clipBehavior: clipBehavior,
      children: children,
    );

    // Apply container features only if needed
    if (_hasContainerFeatures) {
      stackWidget = ContainerLayout(
        style: style,
        ratio: ratio,
        rotate: rotate,
        keepAlive: keepAlive,
        repaintBoundary: repaintBoundary,
        debug: debug,
        transform: transform,
        onEndAnimate: onEndAnimate,
        semantics: semantics,
        child: stackWidget,
      );
    }

    // Apply scrollable wrapper only if needed
    if (scrollable) {
      return SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: stackWidget,
      );
    }

    return stackWidget;
  }
}
