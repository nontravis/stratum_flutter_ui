import 'package:stratum_ui/src/src.dart';

/// The scroll behavior for a layout scroll view at [context].
///
/// Starts from the theme's `scrollBehavior` with the theme's `physics` when
/// a [StratumThemeApplication] is above [context], else from the inherited
/// [ScrollConfiguration]. A null [scrollbars] keeps the behavior's own
/// choice, which shows a scrollbar on desktop. A scroll view's own
/// `physics` parameter applies on top of the result.
ScrollBehavior resolveScrollBehavior(
  BuildContext context, {
  bool? scrollbars,
}) {
  final theme = StratumThemeApplication.maybeOf(context);
  final behavior = theme?.scrollBehavior ?? ScrollConfiguration.of(context);
  return behavior.copyWith(physics: theme?.physics, scrollbars: scrollbars);
}

/// Applies [resolveScrollBehavior] to the scroll view in [child].
///
/// The behavior also reaches Flutter scroll views inside the items. Layout
/// scroll views among them resolve their own behavior from the theme.
class ScrollFrame extends StatelessWidget {
  const new({super.key, this.showScrollbar, required this.child});

  /// Null keeps the behavior's choice: a scrollbar on desktop.
  final bool? showScrollbar;
  final Widget child;

  /// The style of the box around a viewport.
  ///
  /// The padding moves into the scroll view so it scrolls with the
  /// content, and a rounded box clips the viewport to its corners unless
  /// the style sets its own `clipBehavior`.
  static WidgetStyle boxStyle(WidgetStyle style) {
    return style.copyWith(
      padding: null,
      clipBehavior:
          style.clipBehavior ??
          (style.borderRadius == null ? null : Clip.antiAlias),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: resolveScrollBehavior(context, scrollbars: showScrollbar),
      child: child,
    );
  }
}
