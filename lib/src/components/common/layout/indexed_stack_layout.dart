import 'package:stratum_ui/src/components/common/layout/focus_group.dart';
import 'package:stratum_ui/src/src.dart';

/// An [IndexedStack] on [BoxLayout]: shows the child at [index] and keeps
/// the others built, with style, interaction, semantics, and scrolling
/// from the base class.
///
/// As with [IndexedStack], only the shown child paints, takes hits, takes
/// focus, and appears in semantics. Hidden children's tickers stop through
/// [TickerMode], so their animations stop ticking and tick again when the
/// child shows; time still passes while they are hidden. A switch has no
/// animation; wrap the content in [AnimatedSwitcher] for a cross-fade.
///
/// When [index] changes while focus sits inside the outgoing child, focus
/// moves after the frame to the first node of the incoming child in Tab
/// order, else to the stack's own node, which is not a Tab stop, so the
/// next Tab moves on from the stack's place. Focus outside the stack, such
/// as on the tab bar that changed [index], stays where it is.
///
/// [alignment] and [clipBehavior] act on the stack; `style.alignment` and
/// `style.clipBehavior` act on the box.
class IndexedStackLayout extends BoxLayout {
  const new({
    super.key,
    super.style,
    super.ratio,
    super.rotate,
    super.transform,
    super.transformAlignment,
    super.keepAlive,
    super.repaintBoundary,
    super.semantics,
    super.onEndAnimate,
    super.interaction,
    super.scroll,
    this.index = 0,
    this.alignment = AlignmentDirectional.topStart,
    this.sizing = StackFit.loose,
    this.textDirection,
    this.clipBehavior = Clip.hardEdge,
    required this.children,
  });

  /// The child to show; null shows none. An index at or past the child
  /// count fails [IndexedStack]'s assertion in debug mode.
  final int? index;

  /// Aligns each non-positioned child within the stack's own bounds.
  final AlignmentGeometry alignment;
  final StackFit sizing;
  final TextDirection? textDirection;

  /// Clips the stack's children that overflow its bounds;
  /// `style.clipBehavior` cuts at the box edge instead.
  final Clip clipBehavior;
  final List<Widget> children;

  @override
  Widget buildContent(BuildContext context) {
    return _IndexedStackFrame(
      index: index,
      alignment: alignment,
      sizing: sizing,
      textDirection: textDirection,
      clipBehavior: clipBehavior,
      children: children,
    );
  }
}

/// The stack with a focus node per child and the focus handoff on an
/// [index] change.
class _IndexedStackFrame extends StatefulWidget {
  const new({
    required this.index,
    required this.alignment,
    required this.sizing,
    required this.textDirection,
    required this.clipBehavior,
    required this.children,
  });

  final int? index;
  final AlignmentGeometry alignment;
  final StackFit sizing;
  final TextDirection? textDirection;
  final Clip clipBehavior;
  final List<Widget> children;

  @override
  State<_IndexedStackFrame> createState() => _IndexedStackFrameState();
}

class _IndexedStackFrameState extends State<_IndexedStackFrame> {
  /// Takes focus when the incoming child has no node that can; skipped by
  /// Tab.
  final _stackNode = FocusNode(
    debugLabel: 'IndexedStackLayout',
    skipTraversal: true,
  );

  /// One node per child, which only marks the child's subtree.
  final _childNodes = <FocusNode>[];

  FocusNode _childNode(int index) {
    while (_childNodes.length <= index) {
      _childNodes.add(
        FocusNode(
          debugLabel: 'IndexedStackLayout child ${_childNodes.length}',
          canRequestFocus: false,
          skipTraversal: true,
        ),
      );
    }
    return _childNodes[index];
  }

  @override
  void didUpdateWidget(_IndexedStackFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    final outgoing = oldWidget.index;
    if (outgoing == widget.index) return;
    // The build below excludes the outgoing child from focus, so check now
    // whether focus sits inside it.
    if (outgoing == null || outgoing >= _childNodes.length) return;
    if (!_childNodes[outgoing].hasFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _handOff());
  }

  @override
  void dispose() {
    _stackNode.dispose();
    for (final node in _childNodes) {
      node.dispose();
    }
    super.dispose();
  }

  /// Focuses the incoming child's first node in Tab order, else the stack.
  void _handOff() {
    if (!mounted) return;
    final index = widget.index;
    final incoming = index == null || index >= _childNodes.length
        ? null
        : firstTabStopIn(_childNodes[index]);
    (incoming ?? _stackNode).requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final index = widget.index;
    return Focus(
      focusNode: _stackNode,
      includeSemantics: false,
      child: IndexedStack(
        index: index,
        alignment: widget.alignment,
        sizing: widget.sizing,
        textDirection: widget.textDirection,
        clipBehavior: widget.clipBehavior,
        children: [
          for (final (i, child) in widget.children.indexed)
            TickerMode(
              enabled: i == index,
              child: Focus(
                focusNode: _childNode(i),
                includeSemantics: false,
                child: child,
              ),
            ),
        ],
      ),
    );
  }
}
