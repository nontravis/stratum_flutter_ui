import 'package:stratum_ui/src/components/common/layout/focus_group.dart';
import 'package:stratum_ui/src/components/common/style/reduced_motion.dart';
import 'package:stratum_ui/src/src.dart';

/// The scroll behavior for a layout scroll view at [context].
///
/// Starts from the theme's `scrollBehavior` with the theme's `physics` when
/// a [StratumThemeApplication] is above [context]. Without a theme it
/// starts from the [ScrollConfiguration] above the outermost [ScrollFrame],
/// so an outer frame's choices never reach an inner one. A null
/// [scrollbars] keeps the behavior's own choice, which shows a scrollbar on
/// desktop. A scroll view's own `physics` parameter applies on top of the
/// result.
ScrollBehavior resolveScrollBehavior(
  BuildContext context, {
  bool? scrollbars,
}) {
  final theme = StratumThemeApplication.maybeOf(context);
  final behavior =
      theme?.scrollBehavior ??
      _ScrollFrameScope.maybeBaseOf(context) ??
      ScrollConfiguration.of(context);
  return behavior.copyWith(physics: theme?.physics, scrollbars: scrollbars);
}

/// Applies [resolveScrollBehavior] to the scroll view in [child].
///
/// The behavior also reaches Flutter scroll views inside the items. Layout
/// scroll views among them resolve their own behavior, from the theme or
/// from the configuration above the outermost frame.
class ScrollFrame extends StatelessWidget {
  const new({super.key, this.showScrollbar, required this.child});

  /// Null keeps the behavior's choice: a scrollbar on desktop.
  final bool? showScrollbar;
  final Widget child;

  /// The style of the box around a viewport.
  ///
  /// With [scrollsPadding], the default, the padding moves into the scroll
  /// view so it scrolls with the content; without it the padding stays on
  /// the box and insets the viewport. A rounded box clips the viewport to
  /// its corners unless the style sets its own `clipBehavior`.
  static WidgetStyle boxStyle(
    WidgetStyle style, {
    bool scrollsPadding = true,
  }) {
    return style.copyWith(
      padding: scrollsPadding ? null : style.padding,
      clipBehavior:
          style.clipBehavior ??
          (style.borderRadius == null ? null : Clip.antiAlias),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _ScrollFrameScope(
      base:
          _ScrollFrameScope.maybeBaseOf(context) ??
          ScrollConfiguration.of(context),
      child: ScrollConfiguration(
        behavior: resolveScrollBehavior(context, scrollbars: showScrollbar),
        child: child,
      ),
    );
  }
}

/// Carries the [ScrollConfiguration] that was above the outermost
/// [ScrollFrame] down to the frames nested inside it.
class _ScrollFrameScope extends InheritedWidget {
  const new({required this.base, required super.child});

  final ScrollBehavior base;

  static ScrollBehavior? maybeBaseOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_ScrollFrameScope>()
        ?.base;
  }

  @override
  bool updateShouldNotify(_ScrollFrameScope oldWidget) =>
      base != oldWidget.base;
}

/// Whether a scroll view takes keyboard focus when its `focusable` is null:
/// on web, mobile web included, and on desktop. Every scroller is then a
/// Tab stop, as in Firefox.
bool defaultScrollFocusable({
  required bool isWeb,
  required TargetPlatform platform,
}) {
  return isWeb ||
      const {
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
      }.contains(platform);
}

/// The screen direction of the arrow [key] when it points along [axis];
/// null for any other key, an arrow across [axis] included.
AxisDirection? arrowAlong(LogicalKeyboardKey key, Axis axis) {
  final direction = switch (key) {
    LogicalKeyboardKey.arrowUp => AxisDirection.up,
    LogicalKeyboardKey.arrowDown => AxisDirection.down,
    LogicalKeyboardKey.arrowLeft => AxisDirection.left,
    LogicalKeyboardKey.arrowRight => AxisDirection.right,
    _ => null,
  };
  if (direction == null || axisDirectionToAxis(direction) != axis) {
    return null;
  }
  return direction;
}

/// Jumps [position] to its end. A lazy list only estimates its extent, so
/// it jumps again after each frame until the extent stops changing, at
/// most three more times, while [attached] holds.
void jumpToEnd(ScrollPosition position, {required ValueGetter<bool> attached}) {
  void jump(int retries) {
    final extent = position.maxScrollExtent;
    position.jumpTo(extent);
    if (retries == 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (attached() && position.maxScrollExtent != extent) jump(retries - 1);
    });
  }

  jump(3);
}

/// How the keys of a [ScrollFocus] move its view.
enum ScrollFocusMode {
  /// Arrows scroll 50 px, Page Up and Page Down 0.8 of the viewport, and
  /// Home and End jump to the first and last item (K4).
  lines,

  /// The view is a [PageView]: arrows along the axis go to the page on that
  /// side of the screen, Page Up and Page Down to the previous and next
  /// page, and Home and End to the first and last page.
  pages,
}

/// Keyboard scrolling for one scroll view (K4): the focus node, the keys,
/// and the focus ring.
///
/// Sits outside the box's clip, so the ring, which paints outside the box,
/// stays visible: around the box of a scroll view, and in `boxBuilder` for
/// a box layout with `scroll`. When the ring around the box would not lie
/// wholly inside the window, as around a box that fills it, the ring
/// paints inside the box edge, over the content, instead. The box decides
/// after layout, when its own node gains focus and when the window size
/// changes.
///
/// A focusable scroll view makes its content, inside the box, one
/// traversal group through [contentGroup], so Tab order puts the box's Tab
/// stop before every item inside. Reading order sorts by unclipped rects;
/// without the group an item scrolled above the viewport sorts before the
/// Tab stop, and Tab from that item lands on the stop instead of the next
/// item. The group leaves arrow keys and their history to the group around
/// the box, so desktop arrows move as if it were not there.
///
/// With [ownsFocus] false it wraps a tap
/// surface that takes focus, adds no Tab stop of its own, and acts on keys
/// that bubble up from the surface's node. Both modes build the same
/// widgets, so a flip of [ownsFocus] keeps [child]'s State and the scroll
/// offset. When [ownsFocus] flips while the box's Tab stop holds focus,
/// focus moves after the frame to the new Tab stop: the own node, or the
/// surface's. Focus outside the box, or on an item inside it, stays put.
///
/// While the viewport node holds focus, the arrows along [axis] scroll
/// 50 px, Page Up and Page Down scroll 0.8 of the viewport, and Home and
/// End jump to the first and last item. While an item inside holds focus,
/// the arrows keep Flutter's default, and Page Up, Page Down, Home, and
/// End still scroll. No key acts while focus is inside a text field.
///
/// The scroll view reads its controller through [controllerOf]: the
/// caller's [controller]; else none when it inherits the
/// [PrimaryScrollController], which the keys then use; else, when
/// [focusable], an internal one.
///
/// In [ScrollFocusMode.pages] the view is a [PageView]. The arrows along
/// [axis] go to the page on that side of the screen, Page Down and Page Up
/// to the next and the previous page, and Home and End to the first and
/// the last page; End needs [pageCount]. A page change slides over 300 ms
/// with [Curves.easeInOutSine], or jumps when the app or the platform asks
/// for less motion; Home and End always jump. A key during a slide counts
/// from the slide's target page, and a key that would go past the first or
/// last page is not handled. The page view never inherits the
/// [PrimaryScrollController]: [controller] must be a [PageController], and
/// without one a focusable view gets an internal one.
///
/// Each page sits in [page]. While a node inside a page holds focus, the
/// arrows keep Flutter's default, and when Page Up, Page Down, Home, or End
/// changes the page, focus moves after the change to the first node of the
/// new page in Tab order, else to the view's own node. When focus moves
/// into another page, as Tab does into a neighbor page that
/// `allowImplicitScrolling` built, the view shows that page whole by the
/// same slide or jump.
///
/// In the body of a [NestedScrollView], when the keys scroll through its
/// inner controller, which a vertical scroll view in the body inherits as
/// the [PrimaryScrollController], they move the header and the body as one
/// range: the header's collapse extent, then the body's extent. An arrow
/// or a page first collapses or expands the header and then scrolls the
/// body, and a press that crosses the header's extent moves both; Home
/// expands the header and returns the body to its start, and End scrolls
/// the body to its end and collapses the header. When the inner controller
/// holds several positions, as during a tab swipe, the keys move the one
/// of the scroll view below this widget.
class ScrollFocus extends StatefulWidget {
  const new({
    super.key,
    required this.focusable,
    required this.axis,
    this.mode = ScrollFocusMode.lines,
    this.controller,
    this.primary,
    this.pageCount,
    this.semanticsLabel,
    this.borderRadius,
    this.ownsFocus = true,
    required this.child,
  });

  /// Whether the viewport takes focus and handles keys; false passes
  /// [child] through.
  final bool focusable;

  /// The scroll axis the arrows act along.
  final Axis axis;

  /// How the keys move the view; it must not change between builds.
  final ScrollFocusMode mode;
  final ScrollController? controller;
  final bool? primary;

  /// The number of pages in [ScrollFocusMode.pages]; null when unknown,
  /// which makes End do nothing.
  final int? pageCount;

  /// Names the viewport node that a screen reader announces on focus.
  final String? semanticsLabel;

  /// Shape of the focus ring.
  final BorderRadiusGeometry? borderRadius;

  /// Whether this widget owns the viewport node, the Tab stop; false when
  /// it wraps a tap surface whose node takes focus instead. A surface that
  /// cannot take focus, such as a disabled or hover-only one, leaves it
  /// true.
  final bool ownsFocus;
  final Widget child;

  /// The controller that the scroll view below the nearest [ScrollFocus]
  /// passes on; null lets it inherit the [PrimaryScrollController] or make
  /// its own.
  static ScrollController? controllerOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_ScrollFocusScope>()
        ?.controller;
  }

  /// Wraps [child], the scroll view of a focusable scroller inside its box,
  /// in the traversal group that keeps the box's Tab stop ahead of the
  /// items inside.
  static Widget contentGroup(Widget child) {
    return FocusTraversalGroup(policy: _contentPolicy, child: child);
  }

  /// Wraps [child], the page at [index] of the page view below a
  /// [ScrollFocus] in [ScrollFocusMode.pages], in its own traversal group,
  /// so Tab finishes one page before the next, and in a node that marks
  /// the page's index. Without the group, reading order would interleave
  /// pages whose rows share one band.
  static Widget page({Key? key, required int index, required Widget child}) {
    return _PageMarker(key: key, index: index, child: child);
  }

  /// Shared by every content group; it keeps no state of its own.
  static final _contentPolicy = _ScrollContentPolicy();

  @override
  State<ScrollFocus> createState() => _ScrollFocusState();
}

class _ScrollFocusState extends State<ScrollFocus>
    with WidgetsBindingObserver {
  /// The width of [FocusSpread]'s ring.
  static const _ringWidth = 4.0;

  /// How long a key page change slides.
  static const _pageDuration = Duration(milliseconds: 300);

  /// How long an arrow or a page scroll in [ScrollFocusMode.lines] takes.
  static const _lineDuration = Duration(milliseconds: 100);

  // Created on first use and kept until dispose, as StratumInkWell keeps
  // its node.
  FocusNode? _node;
  FocusNode? _surfaceKeys;
  ScrollController? _internalController;

  /// Whether the ring paints inside the box edge, because the ring around
  /// the box would not lie wholly inside the window.
  var _ringInside = false;
  var _ringCheckPending = false;

  /// The page a running key slide goes to; null when no slide runs.
  int? _slideTarget;

  /// Counts page changes, so a slide that a later change interrupts leaves
  /// [_slideTarget] alone.
  var _pageChanges = 0;

  /// The node of each built page, by index.
  final _pageNodes = <int, FocusNode>{};

  bool get _pages => widget.mode == ScrollFocusMode.pages;

  FocusNode get _focusNode =>
      _node ??= FocusNode(debugLabel: 'ScrollFocus')
        ..addListener(_handleFocusChange);

  /// The node the [Focus] holds without [ScrollFocus.ownsFocus]: it takes
  /// no focus and only hears keys bubbling up from the tap surface.
  FocusNode get _surfaceKeysNode => _surfaceKeys ??= FocusNode(
    debugLabel: 'ScrollFocus surface keys',
    canRequestFocus: false,
    skipTraversal: true,
  );

  /// Whether the scroll view attaches to the [PrimaryScrollController], by
  /// the rule of `ScrollView` and `SingleChildScrollView`; a [PageView]
  /// never does.
  bool get _inheritsPrimary =>
      !_pages &&
      (widget.primary ??
          (widget.controller == null &&
              PrimaryScrollController.shouldInherit(context, widget.axis)));

  /// The controller handed to the scroll view.
  ScrollController? get _viewController {
    final controller = widget.controller;
    if (controller != null) return controller;
    if (!widget.focusable || _inheritsPrimary) return null;
    return _internalController ??= _pages
        ? PageController()
        : ScrollController();
  }

  /// The controller the keys scroll through.
  ScrollController? get _keyController {
    final view = _viewController;
    if (view != null) return view;
    return _inheritsPrimary ? PrimaryScrollController.maybeOf(context) : null;
  }

  bool get _ringVisible =>
      widget.ownsFocus &&
      _focusNode.hasPrimaryFocus &&
      FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(_handleHighlightMode);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(ScrollFocus oldWidget) {
    super.didUpdateWidget(oldWidget);
    assert(oldWidget.mode == widget.mode, 'ScrollFocus.mode cannot change');
    final owned = oldWidget.ownsFocus;
    final owns = widget.ownsFocus;
    if (!oldWidget.focusable || !widget.focusable || owned == owns) return;
    // The Focus below still holds the old node here, so this reads the Tab
    // stop as it was before the flip.
    final handler = owned ? _node : _surfaceKeys;
    if (handler == null || !_viewportFocused(handler, owns: owned)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _handOver(owns));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FocusManager.instance.removeHighlightModeListener(_handleHighlightMode);
    _node?.dispose();
    _surfaceKeys?.dispose();
    _internalController?.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (_node?.hasPrimaryFocus ?? false) _placeRingAfterLayout();
  }

  void _handleFocusChange() {
    if (_focusNode.hasPrimaryFocus) _placeRingAfterLayout();
    setState(() {});
  }

  void _handleHighlightMode(FocusHighlightMode mode) {
    if (_node?.hasPrimaryFocus ?? false) setState(() {});
  }

  /// Sets [_ringInside] after the next frame's layout.
  void _placeRingAfterLayout() {
    if (_ringCheckPending) return;
    _ringCheckPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ringCheckPending = false;
      if (!mounted) return;
      final inside = !_outerRingFits();
      if (inside != _ringInside) setState(() => _ringInside = inside);
    });
  }

  /// Whether the ring around the box, [_ringWidth] wide, lies wholly inside
  /// the window.
  bool _outerRingFits() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return true;
    final ring = MatrixUtils.transformRect(
      box.getTransformTo(null),
      Offset.zero & box.size,
    ).inflate(_ringWidth);
    final view = View.of(context);
    final window = view.physicalSize / view.devicePixelRatio;
    return ring.left >= 0 &&
        ring.top >= 0 &&
        ring.right <= window.width &&
        ring.bottom <= window.height;
  }

  /// Moves focus to the Tab stop of the box after [ScrollFocus.ownsFocus]
  /// flipped to [owns] while the old Tab stop held focus: the own node, or
  /// the nearest focusable node below, the tap surface's. The flip leaves
  /// focus on a surface that can no longer take it, or drops it from the
  /// own node, which leaves the tree. Focus that has meanwhile settled
  /// outside the box stays there.
  void _handOver(bool owns) {
    if (!mounted || !widget.focusable || widget.ownsFocus != owns) return;
    final handler = owns ? _focusNode : _surfaceKeysNode;
    final primary = FocusManager.instance.primaryFocus;
    if (primary != null && !handler.hasFocus) return;
    final target = owns ? handler : _nearestFocusable(handler);
    target?.requestFocus();
  }

  /// The focusable, traversable node nearest below [node], breadth first.
  static FocusNode? _nearestFocusable(FocusNode node) {
    var level = node.children.toList();
    while (level.isNotEmpty) {
      for (final child in level) {
        if (child.canRequestFocus && !child.skipTraversal) return child;
      }
      level = [for (final child in level) ...child.children];
    }
    return null;
  }

  /// Whether the viewport itself holds focus: [handler], or, when the box
  /// does not [owns] its Tab stop, the tap surface's node, which no
  /// focusable node separates from [handler].
  static bool _viewportFocused(FocusNode handler, {required bool owns}) {
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null) return false;
    if (primary == handler) return true;
    if (owns) return false;
    for (final ancestor in primary.ancestors) {
      if (ancestor == handler) return true;
      if (ancestor.canRequestFocus && !ancestor.skipTraversal) return false;
    }
    return false;
  }

  KeyEventResult _handleKey(FocusNode handler, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isShiftPressed ||
        keyboard.isControlPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed ||
        primaryFocusInEditableText()) {
      return KeyEventResult.ignored;
    }
    final controller = _keyController;
    if (controller == null) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (_pages) {
      if (controller is! PageController || controller.positions.length != 1) {
        return KeyEventResult.ignored;
      }
      return _handlePageKey(handler, controller, key);
    }
    final nested = _nestedScrollView(controller);
    final position = nested == null
        ? (controller.positions.length == 1 ? controller.position : null)
        : _ownPosition(controller);
    if (position == null) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.home) {
      // In a nested scroll view the header expands, and the coordinator
      // returns the body to its start.
      final start = nested?.outerController.position ?? position;
      start.jumpTo(start.minScrollExtent);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end) {
      jumpToEnd(
        position,
        attached: () => mounted && controller.positions.contains(position),
      );
      return KeyEventResult.handled;
    }
    final vertical = position.axis == Axis.vertical;
    final page =
        key == LogicalKeyboardKey.pageUp || key == LogicalKeyboardKey.pageDown;
    final AxisDirection? direction;
    if (key == LogicalKeyboardKey.pageUp) {
      direction = vertical ? AxisDirection.up : AxisDirection.left;
    } else if (key == LogicalKeyboardKey.pageDown) {
      direction = vertical ? AxisDirection.down : AxisDirection.right;
    } else if (!_viewportFocused(handler, owns: widget.ownsFocus)) {
      direction = null;
    } else {
      direction = arrowAlong(key, position.axis);
    }
    if (direction == null) return KeyEventResult.ignored;
    // The amounts of Flutter's ScrollAction: a line is 50 px and a page is
    // 0.8 of the viewport.
    final amount = page ? 0.8 * position.viewportDimension : 50.0;
    final delta = direction == position.axisDirection ? amount : -amount;
    if (nested != null) {
      _moveNested(nested.outerController.position, position, delta);
    } else {
      position.moveTo(
        position.pixels + delta,
        duration: _lineDuration,
        curve: Curves.easeInOut,
      );
    }
    return KeyEventResult.handled;
  }

  /// The [NestedScrollView] whose body this widget's view scrolls with: the
  /// one above, when [controller] is its inner controller; else null.
  NestedScrollViewState? _nestedScrollView(ScrollController controller) {
    final nested = context.findAncestorStateOfType<NestedScrollViewState>();
    if (nested == null || nested.innerController != controller) return null;
    return nested;
  }

  /// The position of the scroll view below this widget, among the several
  /// that a nested scroll view's inner controller may hold.
  ScrollPosition? _ownPosition(ScrollController controller) {
    for (final position in controller.positions) {
      final scrollable = position.context.storageContext;
      if (scrollable.findAncestorStateOfType<_ScrollFocusState>() == this) {
        return position;
      }
    }
    return null;
  }

  /// Moves a nested scroll view by [delta] along one range: [outer]'s
  /// extent, over which the header collapses, then [inner]'s, the body's.
  ///
  /// Moving [inner] by its own offset would collapse the header at once,
  /// because the coordinator maps every inner offset to a collapsed header.
  /// A target within the header's extent moves [outer], and the coordinator
  /// returns the body to its start; a target past it moves [inner], and the
  /// coordinator holds the header collapsed.
  static void _moveNested(
    ScrollPosition outer,
    ScrollPosition inner,
    double delta,
  ) {
    final header = outer.maxScrollExtent - outer.minScrollExtent;
    final scrolled = inner.pixels - inner.minScrollExtent;
    final offset =
        outer.pixels - outer.minScrollExtent + (scrolled > 0 ? scrolled : 0);
    final end = header + inner.maxScrollExtent - inner.minScrollExtent;
    final target = clampDouble(offset + delta, 0, end);
    if (target <= header) {
      outer.moveTo(
        outer.minScrollExtent + target,
        duration: _lineDuration,
        curve: Curves.easeInOut,
      );
    } else {
      inner.moveTo(
        inner.minScrollExtent + target - header,
        duration: _lineDuration,
        curve: Curves.easeInOut,
      );
    }
  }

  /// The keys of [ScrollFocusMode.pages]: each goes to one page, counted
  /// from a running slide's target.
  KeyEventResult _handlePageKey(
    FocusNode handler,
    PageController controller,
    LogicalKeyboardKey key,
  ) {
    final count = widget.pageCount;
    final current = _slideTarget ?? (controller.page ?? 0).round();
    final viewportFocused = _viewportFocused(handler, owns: widget.ownsFocus);
    final int target;
    var jump = false;
    if (key == LogicalKeyboardKey.home) {
      target = 0;
      jump = true;
    } else if (key == LogicalKeyboardKey.end) {
      if (count == null) return KeyEventResult.ignored;
      target = count - 1;
      jump = true;
    } else if (key == LogicalKeyboardKey.pageDown) {
      target = current + 1;
    } else if (key == LogicalKeyboardKey.pageUp) {
      target = current - 1;
    } else {
      if (!viewportFocused) return KeyEventResult.ignored;
      final position = controller.position;
      final direction = arrowAlong(key, position.axis);
      if (direction == null) return KeyEventResult.ignored;
      // The page on that side of the screen.
      target = direction == position.axisDirection ? current + 1 : current - 1;
    }
    if (target < 0 || (count != null && target >= count)) {
      return KeyEventResult.ignored;
    }
    _goToPage(controller, target, jump: jump, focusPage: !viewportFocused);
    return KeyEventResult.handled;
  }

  /// Slides to [page] over [_pageDuration], or jumps there for [jump] or
  /// when the app or the platform asks for less motion. With [focusPage],
  /// focus then moves into the page, by [_focusPage].
  void _goToPage(
    PageController controller,
    int page, {
    required bool jump,
    bool focusPage = false,
  }) {
    final change = ++_pageChanges;
    void settle() {
      if (!mounted || change != _pageChanges) return;
      _slideTarget = null;
      // A drag that interrupted the slide leaves focus where it is.
      final shown = controller.positions.length == 1
          ? controller.page?.round()
          : null;
      if (focusPage && shown == page) _focusPage(page);
    }

    if (jump || reducesMotion(context)) {
      _slideTarget = null;
      controller.jumpToPage(page);
      if (focusPage) {
        WidgetsBinding.instance.addPostFrameCallback((_) => settle());
      }
      return;
    }
    _slideTarget = page;
    unawaited(
      controller
          .animateToPage(
            page,
            duration: _pageDuration,
            curve: Curves.easeInOutSine,
          )
          .whenComplete(settle),
    );
  }

  /// Focuses the first node of [page] in Tab order, else the view's own
  /// node.
  void _focusPage(int page) {
    final node = _pageNodes[page];
    final first = node == null ? null : firstTabStopIn(node);
    (first ?? _focusNode).requestFocus();
  }

  /// Shows [page] whole after focus moved into it, unless the view already
  /// shows it or slides to it.
  void _showPage(int page) {
    final controller = _keyController;
    if (controller is! PageController || controller.positions.length != 1) {
      return;
    }
    if (_slideTarget == page) return;
    if (_slideTarget == null && controller.page == page.toDouble()) return;
    _goToPage(controller, page, jump: false);
  }

  void _registerPage(int index, FocusNode node) => _pageNodes[index] = node;

  void _unregisterPage(int index, FocusNode node) {
    if (_pageNodes[index] == node) _pageNodes.remove(index);
  }

  @override
  Widget build(BuildContext context) {
    Widget result = _ScrollFocusScope(
      controller: _viewController,
      pages: _pages ? this : null,
      child: widget.child,
    );
    if (!widget.focusable) return result;
    // One structure for both modes, so a flip of ownsFocus never remounts
    // the child. Without ownership the Focus holds the surface keys node.
    final owns = widget.ownsFocus;
    result = Focus(
      focusNode: owns ? _focusNode : _surfaceKeysNode,
      canRequestFocus: owns,
      skipTraversal: !owns,
      // The Semantics below reports focus for the own node only; Focus's
      // own semantics would also mark the internal node as not focusable
      // and so change the surface's semantics tree.
      includeSemantics: false,
      onKeyEvent: _handleKey,
      child: result,
    );
    // FocusSpread reads the theme; without one the viewport has no ring.
    if (StratumThemeApplication.maybeOf(context) != null) {
      result = FocusSpread(
        focus: _ringVisible,
        inside: _ringInside,
        borderRadius: widget.borderRadius,
        child: result,
      );
    }
    // What Focus's semantics report for the own node; without ownership
    // nothing, so the surface's node speaks alone.
    final focusable = owns && _focusNode.canRequestFocus;
    return Semantics(
      container: owns,
      label: owns ? widget.semanticsLabel : null,
      focusable: owns ? focusable : null,
      focused: focusable ? _focusNode.hasPrimaryFocus : null,
      onFocus: focusable && defaultTargetPlatform != TargetPlatform.iOS
          ? _focusNode.requestFocus
          : null,
      child: result,
    );
  }
}

/// The policy of [ScrollFocus.contentGroup]: reading order among the
/// items, while the arrows and their history stay with the policy of the
/// nearest group around the scroller.
///
/// Flutter keeps directional history per policy and clears it only in the
/// policy that handles a Tab. A content group with its own history would
/// replay stale entries across the scroller edge: an arrow press could
/// refocus the node it leaves, or jump back over the box.
class _ScrollContentPolicy extends ReadingOrderTraversalPolicy {
  @override
  bool inDirection(FocusNode currentNode, TraversalDirection direction) {
    final enclosing = _enclosing(currentNode);
    if (enclosing == null) return super.inDirection(currentNode, direction);
    return enclosing.inDirection(currentNode, direction);
  }

  @override
  bool next(FocusNode currentNode) {
    _clearEnclosingHistory(currentNode);
    return super.next(currentNode);
  }

  @override
  bool previous(FocusNode currentNode) {
    _clearEnclosingHistory(currentNode);
    return super.previous(currentNode);
  }

  /// Clears the arrow history that a Tab from [node] clears without the
  /// content group.
  static void _clearEnclosingHistory(FocusNode node) {
    final scope = node.nearestScope;
    if (scope != null) _enclosing(node)?.invalidateScopeData(scope);
  }

  /// The policy of the nearest group above [node] that is no scroller's
  /// content group.
  static FocusTraversalPolicy? _enclosing(FocusNode node) {
    for (final ancestor in node.ancestors) {
      final policy = FocusTraversalGroup.maybeOfNode(ancestor);
      if (policy is! _ScrollContentPolicy) return policy;
    }
    return null;
  }
}

/// Hands [ScrollFocus]'s controller to the scroll view below it, and, in
/// [ScrollFocusMode.pages], its state to the page markers.
class _ScrollFocusScope extends InheritedWidget {
  const new({
    required this.controller,
    required this.pages,
    required super.child,
  });

  final ScrollController? controller;
  final _ScrollFocusState? pages;

  @override
  bool updateShouldNotify(_ScrollFocusScope oldWidget) =>
      controller != oldWidget.controller || pages != oldWidget.pages;
}

/// The page at [index] of a page view: its own traversal group on the
/// content group's policy, and a node that marks it for the [ScrollFocus]
/// above.
class _PageMarker extends StatefulWidget {
  const new({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_PageMarker> createState() => _PageMarkerState();
}

class _PageMarkerState extends State<_PageMarker> {
  final _node = FocusNode(
    debugLabel: 'ScrollFocus page',
    canRequestFocus: false,
    skipTraversal: true,
  );
  _ScrollFocusState? _pages;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final pages = context
        .dependOnInheritedWidgetOfExactType<_ScrollFocusScope>()
        ?.pages;
    if (pages == _pages) return;
    _pages?._unregisterPage(widget.index, _node);
    _pages = pages?.._registerPage(widget.index, _node);
  }

  @override
  void didUpdateWidget(_PageMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index == widget.index) return;
    _pages
      ?.._unregisterPage(oldWidget.index, _node)
      .._registerPage(widget.index, _node);
  }

  @override
  void dispose() {
    _pages?._unregisterPage(widget.index, _node);
    _node.dispose();
    super.dispose();
  }

  void _handleFocusChange(bool focused) {
    if (focused) _pages?._showPage(widget.index);
  }

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      policy: ScrollFocus._contentPolicy,
      child: Focus(
        focusNode: _node,
        includeSemantics: false,
        onFocusChange: _handleFocusChange,
        child: widget.child,
      ),
    );
  }
}

/// Builds the scroll view of a layout scroll view: [controller] comes from
/// [ScrollFocus.controllerOf], and [padding] is `style.padding` when the
/// padding scrolls, else null.
typedef ScrollViewBuilder =
    Widget Function(
      BuildContext context,
      ScrollController? controller,
      EdgeInsetsGeometry? padding,
    );

/// The box, keyboard focus, and frame of a layout scroll view.
///
/// Builds [ScrollFocus] around the [ContainerLayout] of [style], when set,
/// then [ScrollFocus.contentGroup] when [focusable], then [ScrollFrame],
/// then the view that [builder] makes. Not exported: the six layout scroll
/// views build through it, [ListViewLayout], [GridViewLayout],
/// [CustomScrollViewLayout], [PageViewLayout], [ReorderableListViewLayout],
/// and [NestedScrollViewLayout].
class ScrollViewBox extends StatelessWidget {
  const new({
    super.key,
    this.style,
    required this.focusable,
    required this.axis,
    this.mode = ScrollFocusMode.lines,
    this.controller,
    this.primary,
    this.pageCount,
    this.semanticsLabel,
    this.showScrollbar,
    this.scrollsPadding = true,
    required this.builder,
  });

  final WidgetStyle? style;

  /// Whether the view is a Tab stop that scrolls by keyboard; null resolves
  /// through [defaultScrollFocusable].
  final bool? focusable;
  final Axis axis;

  /// How the keys move the view; see [ScrollFocus].
  final ScrollFocusMode mode;
  final ScrollController? controller;
  final bool? primary;

  /// The number of pages in [ScrollFocusMode.pages]; null when unknown.
  final int? pageCount;
  final String? semanticsLabel;

  /// Null keeps the scroll behavior's choice: a scrollbar on desktop.
  final bool? showScrollbar;

  /// Whether `style.padding` scrolls with the content, handed to [builder];
  /// false keeps it on the box, where it insets the viewport.
  final bool scrollsPadding;
  final ScrollViewBuilder builder;

  @override
  Widget build(BuildContext context) {
    final style = this.style;
    final focusable =
        this.focusable ??
        defaultScrollFocusable(isWeb: kIsWeb, platform: defaultTargetPlatform);
    Widget view = ScrollFrame(
      showScrollbar: showScrollbar,
      child: Builder(
        builder: (context) => builder(
          context,
          ScrollFocus.controllerOf(context),
          scrollsPadding ? style?.padding : null,
        ),
      ),
    );
    if (focusable) view = ScrollFocus.contentGroup(view);
    if (style != null) {
      view = ContainerLayout(
        style: ScrollFrame.boxStyle(style, scrollsPadding: scrollsPadding),
        child: view,
      );
    }
    return ScrollFocus(
      focusable: focusable,
      axis: axis,
      mode: mode,
      controller: controller,
      primary: primary,
      pageCount: pageCount,
      semanticsLabel: semanticsLabel,
      borderRadius: style?.borderRadius,
      child: view,
    );
  }
}
