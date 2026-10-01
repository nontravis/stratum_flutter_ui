import 'package:stratum_ui/src/src.dart';

class AppCustomScrollView extends StatelessWidget {
  const AppCustomScrollView({
    super.key,
    super.padding,
    this.controller,
    this.width,
    this.reverse = false,
    super.border,
    this.showScrollbar = true,
    this.scrollDirection = Axis.vertical,
    this.scrollBehavior = const NoGlowScrollBehavior(),
    this.physics = const ClampingScrollPhysics(),
    this.slivers,
    this.shrinkWrap = false,
    this.children,
  }) : assert(
         slivers != null || children != null,
         'You need to use slivers or children',
       );

  final double? width;
  final Axis scrollDirection;
  final ScrollController? controller;
  final bool showScrollbar;
  final bool reverse;
  final bool shrinkWrap;
  final ScrollBehavior? scrollBehavior;
  final ScrollPhysics? physics;
  final List<Widget>? slivers;
  final List<Widget>? children;

  @override
  Widget build(BuildContext context) {
    // Pre-compute values
    final hasContainer = width != null || border != null;
    final effectiveScrollBehavior = showScrollbar
        ? scrollBehavior?.copyWith(scrollbars: true)
        : scrollBehavior?.copyWith(scrollbars: false);

    // Build the scroll view
    Widget scrollView = CustomScrollView(
      shrinkWrap: shrinkWrap,
      physics: physics,
      scrollDirection: scrollDirection,
      controller: controller,
      reverse: reverse,
      scrollBehavior: effectiveScrollBehavior,
      slivers: _buildSlivers(),
    );

    // Wrap with notification listener
    scrollView = NotificationListener<OverscrollIndicatorNotification>(
      onNotification: _onNotification,
      child: scrollView,
    );

    // Apply container only if needed
    if (hasContainer) {
      return ContainerLayout(
        style: WidgetStyle(width: width, border: border),
        child: scrollView,
      );
    }

    return scrollView;
  }

  List<Widget> _buildSlivers() {
    if (slivers != null) return slivers!;

    // Convert children to slivers efficiently
    return [
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => children![index],
          childCount: children!.length,
        ),
      ),
    ];
  }

  bool _onNotification(OverscrollIndicatorNotification? notification) {
    // Consumes the overscroll notification and disables the glow effect
    notification?.disallowIndicator();
    return true;
  }
}
