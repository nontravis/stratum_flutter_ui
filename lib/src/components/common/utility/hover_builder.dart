import 'package:stratum_ui/src/components/common/base/disabled.dart'
    show StratumDisabledScope;
import 'package:stratum_ui/src/src.dart';

/// Builds [builder] from whether a pointer is over the widget it builds.
///
/// It only observes: it adds no Tab stop, focus ring, tap handling, hover
/// overlay, cursor, or size, so the wrapped widget keeps its own; for a
/// Tab stop, a ring, or taps, use `ContainerLayout(interaction:)`.
/// [builder] runs, and [onHover] reports, only when `hovered` changes,
/// never on a pointer move that keeps it; content that scrolls under a
/// still pointer changes it as a pointer move does. For the pointer's
/// position on every move, or a delay before hover counts, use a
/// `MouseRegion` or a `Timer`. Inside a disabled component `hovered` stays
/// false and [onHover] is not called.
///
/// Touch screens have no hover: content shown only while hovered needs
/// another way to reach it (WCAG 1.4.13). No state may show by color
/// alone: pair a hover color with text, an icon, or a shape (WCAG 1.4.1).
class HoverBuilder extends StatefulWidget {
  const new({
    super.key,
    required this.builder,
    this.child,
    this.onHover,
    this.semantics,
  });

  /// Builds the look from `hovered`; [child] reaches it unrebuilt.
  final ValueWidgetBuilder<bool> builder;

  /// A subtree that does not depend on `hovered`, handed to [builder] on
  /// every call.
  final Widget? child;

  /// Called with true when a pointer enters and false when it leaves.
  final ValueChanged<bool>? onHover;

  /// The group's semantics, with the name and type of
  /// `BoxLayout.semantics`: null adds no node; set, one container node of
  /// its own around the wrapped widget, read before the nodes inside.
  final SemanticsProperties? semantics;

  @override
  State<HoverBuilder> createState() => _HoverBuilderState();
}

class _HoverBuilderState extends State<HoverBuilder> {
  bool _pointerInside = false;
  bool _disabled = false;

  bool get _hovered => _pointerInside && !_disabled;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A disabled flip rebuilds with the new value and calls no listener
    // (US-16 FR-05 E02).
    _disabled = StratumDisabledScope.of(context);
  }

  void _handlePointer({required bool inside}) {
    final wasHovered = _hovered;
    _pointerInside = inside;
    final hovered = _hovered;
    if (hovered == wasHovered) return;
    setState(() {});
    widget.onHover?.call(hovered);
  }

  @override
  Widget build(BuildContext context) {
    final semantics = widget.semantics;
    // A pass-through region: `translucent` adds this region across its own
    // bounds (so hover still spans the whole box, RQ1) without changing
    // what the wrapped widget's own hit-test returns, so an ancestor
    // detector or a Stack sibling behind sees exactly what it would with
    // no HoverBuilder there at all; it sets no cursor of its own.
    final result = MouseRegion(
      hitTestBehavior: HitTestBehavior.translucent,
      onEnter: (_) => _handlePointer(inside: true),
      onExit: (_) => _handlePointer(inside: false),
      child: widget.builder(context, _hovered, widget.child),
    );
    // Always built as the same widget type, so toggling [semantics] null
    // <-> a value keeps the wrapped subtree mounted instead of remounting
    // it (Minor 2); `container: false` with no properties set still adds
    // no semantics node (FR-04 E02 stays green).
    return Semantics.fromProperties(
      container: semantics != null,
      properties: semantics ?? const SemanticsProperties(),
      child: result,
    );
  }
}
