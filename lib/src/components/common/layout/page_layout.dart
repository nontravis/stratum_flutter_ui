import 'dart:math' as math;

import 'package:stratum_ui/src/components/common/l10n/built_in_labels.dart';
import 'package:stratum_ui/src/components/common/layout/page_drawer.dart'
    show
        PageDrawerStage,
        inlinePaneWidth,
        overlayDrawerWidth,
        resolveDrawerType;
import 'package:stratum_ui/src/src.dart';

/// Which sides of a [PageLayout] pad their slots by the system insets
/// (US-18 FR-04): Figma's `safeStatusBar` is [top] and its `safeIndicator`
/// is [bottom].
///
/// A false flag drops that side's padding from every slot, and the slots'
/// children read no inset on that side either, while every slot fill still
/// runs to the screen edge. [left] and [right] name the sides the `left`
/// and `right` slots sit on, the start and end sides, so under
/// [TextDirection.rtl] [left] is the right edge.
@immutable
class PageSafeArea {
  const new({
    this.top = true,
    this.bottom = true,
    this.left = true,
    this.right = true,
  });

  /// Whether slots pad by the status bar.
  final bool top;

  /// Whether slots pad by the home indicator.
  final bool bottom;

  /// Whether slots pad by the start side's inset.
  final bool left;

  /// Whether slots pad by the end side's inset.
  final bool right;

  @override
  bool operator ==(Object other) =>
      other is PageSafeArea &&
      other.top == top &&
      other.bottom == bottom &&
      other.left == left &&
      other.right == right;

  @override
  int get hashCode => Object.hash(top, bottom, left, right);
}

/// One [WidgetStyle] per slot of a [PageLayout], plus [outer], the page's
/// own box, each merged field by field over the theme defaults (US-18
/// FR-03; NFR-E02).
///
/// Register one app-wide through `StratumThemeApplication(
/// componentPartDefaults: (theme) => {PageLayout: PageLayoutStyle(...)})`;
/// it has value equality, so an equal map from a new builder call rebuilds
/// no page layout (FO-03 US-06 FR-01).
@immutable
class PageLayoutStyle {
  const new({
    this.outer,
    this.header,
    this.top,
    this.tab,
    this.left,
    this.body,
    this.right,
    this.bottom,
    this.footer,
    this.snack,
  });

  /// The page's own box, behind every slot.
  final WidgetStyle? outer;

  /// The box around [PageLayout.header].
  final WidgetStyle? header;

  /// The box around [PageLayout.top].
  final WidgetStyle? top;

  /// The box around [PageLayout.tab].
  final WidgetStyle? tab;

  /// The box around [PageLayout.left].
  final WidgetStyle? left;

  /// The box around [PageLayout.body].
  final WidgetStyle? body;

  /// The box around [PageLayout.right].
  final WidgetStyle? right;

  /// The box around [PageLayout.bottom].
  final WidgetStyle? bottom;

  /// The box around [PageLayout.footer].
  final WidgetStyle? footer;

  /// The box around [PageLayout.snack].
  final WidgetStyle? snack;

  /// Returns a copy where each part merges [other]'s part over this one
  /// through [WidgetStyle.merge].
  PageLayoutStyle merge(PageLayoutStyle? other) {
    if (other == null) return this;
    return PageLayoutStyle(
      outer: _mergePart(outer, other.outer),
      header: _mergePart(header, other.header),
      top: _mergePart(top, other.top),
      tab: _mergePart(tab, other.tab),
      left: _mergePart(left, other.left),
      body: _mergePart(body, other.body),
      right: _mergePart(right, other.right),
      bottom: _mergePart(bottom, other.bottom),
      footer: _mergePart(footer, other.footer),
      snack: _mergePart(snack, other.snack),
    );
  }

  static WidgetStyle? _mergePart(WidgetStyle? base, WidgetStyle? other) =>
      base?.merge(other) ?? other;

  @override
  bool operator ==(Object other) =>
      other is PageLayoutStyle &&
      other.outer == outer &&
      other.header == header &&
      other.top == top &&
      other.tab == tab &&
      other.left == left &&
      other.body == body &&
      other.right == right &&
      other.bottom == bottom &&
      other.footer == footer &&
      other.snack == snack;

  @override
  int get hashCode => Object.hash(
    outer,
    header,
    top,
    tab,
    left,
    body,
    right,
    bottom,
    footer,
    snack,
  );
}

/// Opens and closes a [PageLayout]'s drawers and holds the chosen widths of
/// its inline side panes; [PageLayout.of] returns it (US-19 FR-03, FR-06;
/// layout s03 invariants 66 and 69).
///
/// [openLeft], [openRight], and [close] drive the drawers of the page it is
/// attached to; it owns the side the app asked open, while the page owns
/// the drawn, animated drawer, and each open and close reports through
/// `PageLayout.onDrawerChanged`. [leftWidth] and [rightWidth] hold the
/// EndUser's chosen widths, never the window-clamped widths the page draws;
/// null means none is chosen. Pass kept widths to the constructor to
/// restore them, and set them from code. It notifies only when a set
/// changes a width: from code, or once a pane resize settles; never per
/// drag frame, never when a window clamp changes only the drawn width, and
/// never for a drawer. A [PageLayout] given none makes its own, as a
/// [ScrollController], and disposes only that one.
class PageLayoutController extends ChangeNotifier {
  /// Starts with [leftWidth] and [rightWidth], such as ones the app kept,
  /// to restore them.
  new({double? leftWidth, double? rightWidth})
    : _leftWidth = _checked(leftWidth),
      _rightWidth = _checked(rightWidth);

  double? _leftWidth;
  double? _rightWidth;

  /// The page the drawer calls drive; null while no page holds this.
  _PageLayoutState? _layout;

  /// The side the app asked open; null while no drawer is open or opening.
  PageDrawerSide? _openSide;

  /// The chosen width of the inline `left` pane, in logical pixels.
  double? get leftWidth => _leftWidth;

  set leftWidth(double? value) {
    if (_checked(value) == _leftWidth) return;
    _leftWidth = value;
    notifyListeners();
  }

  /// The chosen width of the inline `right` pane, in logical pixels.
  double? get rightWidth => _rightWidth;

  set rightWidth(double? value) {
    if (_checked(value) == _rightWidth) return;
    _rightWidth = value;
    notifyListeners();
  }

  /// Opens the start drawer and reports it open. Does nothing while `left`
  /// is null or shows inline, at or above the drawer cut, or its drawer is
  /// already open (US-19 FR-03 E01; R21).
  void openLeft() => _layout?._open(PageDrawerSide.left);

  /// Opens the end drawer and reports it open, as [openLeft] does for the
  /// start drawer.
  void openRight() => _layout?._open(PageDrawerSide.right);

  /// Closes the open drawer and reports it closed once it is gone; does
  /// nothing and reports nothing while no drawer is open (US-19 FR-03 E02).
  void close() => _layout?._close();

  static double? _checked(double? width) {
    assert(
      width == null || (width.isFinite && width >= 0),
      'A pane width is a finite number of at least 0.',
    );
    return width;
  }
}

/// A page's slots in the geometry of the Figma page layout (US-18 FR-01):
/// [header] across the full width on top; below it [left], full height
/// between [header] and [footer], beside a main column of [top] over the
/// center column ([tab] over [body] over [bottom]) and [right], which starts
/// under [top]; [footer] across the full width at the end; and [snack]
/// floating at the bottom center over every slot, taking no layout space.
///
/// A null slot builds nothing and takes no space. [left] is the start side
/// and [right] the end side, so both mirror under [TextDirection.rtl].
/// Slots take plain widgets: the app picks what rebuilds by placing its own
/// state listener inside one slot or around the whole page (US-18 FR-02).
/// Each slot sits under its own repaint boundary and a transparent
/// [Material], so a slot hosts any SDK widget with no `Scaffold`.
///
/// Every slot that touches a screen edge fills under that edge's system
/// inset while its content pads by it, as [safeArea] allows; [body] instead
/// hands its top and bottom insets to its children, so a body list scrolls
/// under the home indicator with its last item able to scroll clear.
/// Children read the media insets with the page's share removed, so a
/// nested page pads nothing twice (US-18 FR-04). While the keyboard is open
/// and [resizeToAvoidKeyboard] holds, the page above [footer] ends at the
/// keyboard's top, so [bottom] rides above it, and [footer] stays docked at
/// the bottom edge under the keyboard (US-18 FR-05).
///
/// Below [drawerCut], [WindowSize.tablet] by default, [left] and [right]
/// are drawers that take no space: [PageLayoutController.openLeft] and
/// [PageLayoutController.openRight] open them, a swipe from their screen
/// edge opens them while [edgeSwipe] holds, and a tap on the scrim, a drag
/// toward their edge, Esc, or back closes them, back before the route pops.
/// [leftSide] and [rightSide] set each drawer's type, width bounds, page
/// scale, and label, and [onDrawerChanged] hears each open and close. An
/// open drawer keeps focus inside it, reads as its own named screen, and
/// hides the page behind from screen readers (US-19 FR-02 to FR-05).
///
/// At and above the cut both sides sit inline beside the center column, as
/// two nested [SplitLayout]s, with a divider the EndUser drags or moves by
/// the arrow, Home, and End keys, within the side's width bounds. A divider
/// paints only what [leftDividerBuilder] or [rightDividerBuilder] paints,
/// while it always takes the drag, the keys, and focus, and reads as a
/// slider. Each pane opens at the controller's chosen width, else at its
/// Figma width, and the controller hears each settled resize as the new
/// width (US-19 FR-06). With [rightAsOverlay], [right] opens there instead
/// as a front drawer over a scrim, with a close button (US-19 FR-01). A
/// drawer open as the window crosses into inline panes closes.
///
/// While [loading] holds, a layer over the whole page refuses every tap and
/// keyboard focus, reads as a live region with the built-in loading label,
/// and shows [loadingBuilder]'s widget, else a plain spinner; focus returns
/// to where it sat once [loading] turns false. The layer fades in and out
/// over the theme's `fast` level with no other movement (US-18 FR-06).
///
/// Each part's style layers the theme defaults, then the app-wide
/// [PageLayoutStyle] the application registers for [PageLayout], then
/// [customStyle] (FO-08 US-06 FR-01). Tab visits [header], [left] and its
/// divider, [top], [tab], [body], [bottom], the divider of [right] and
/// [right], [footer], then [snack] (NFR-U02).
///
/// The page needs bounded constraints, as a route's page has.
class PageLayout extends StatefulWidget {
  const new({
    super.key,
    this.header,
    this.left,
    this.top,
    this.tab,
    this.body,
    this.bottom,
    this.right,
    this.footer,
    this.snack,
    this.safeArea = const PageSafeArea(),
    this.resizeToAvoidKeyboard = true,
    this.loading = false,
    this.loadingBuilder,
    this.controller,
    this.leftSide = const PageSide(),
    this.rightSide = const PageSide(),
    this.drawerCut = WindowSize.tablet,
    this.rightAsOverlay = false,
    this.leftDividerBuilder,
    this.rightDividerBuilder,
    this.edgeSwipe = true,
    this.onDrawerChanged,
    this.customStyle,
  });

  /// The slot across the full width on top.
  final Widget? header;

  /// The start-side slot, full height between [header] and [footer].
  final Widget? left;

  /// The slot over the center column and [right].
  final Widget? top;

  /// The center column's slot above [body].
  final Widget? tab;

  /// The center column's slot that takes the room the others leave.
  final Widget? body;

  /// The center column's slot below [body], above the keyboard.
  final Widget? bottom;

  /// The end-side slot, under [top].
  final Widget? right;

  /// The slot across the full width at the end.
  final Widget? footer;

  /// The slot floating at the bottom center over every other slot.
  final Widget? snack;

  /// Which sides pad their slots by the system insets.
  final PageSafeArea safeArea;

  /// Whether the page above [footer] ends at the keyboard's top while the
  /// keyboard is open; false lets the keyboard cover the page's lower part.
  final bool resizeToAvoidKeyboard;

  /// Whether a layer blocks the page and reads as busy.
  final bool loading;

  /// Builds what the loading layer shows; null shows a plain spinner from
  /// theme tokens. The layer keeps the blocking, the announcement, and the
  /// fade whatever it builds.
  final WidgetBuilder? loadingBuilder;

  /// Opens and closes the drawers and holds the chosen side pane widths;
  /// null makes one of the page's own.
  final PageLayoutController? controller;

  /// How [left] behaves as a drawer, and the width bounds of its inline
  /// pane.
  final PageSide leftSide;

  /// How [right] behaves as a drawer, and the width bounds of its inline
  /// pane.
  final PageSide rightSide;

  /// The smallest window size that shows [left] and [right] as inline
  /// panes; below it both are drawers.
  final WindowSize drawerCut;

  /// Whether [right] opens at and above [drawerCut] as a front overlay
  /// drawer with a scrim and a close button, 450 px wide at
  /// [WindowSize.bigDesktop] and 400 px below it, instead of an inline
  /// pane.
  final bool rightAsOverlay;

  /// Paints the divider between the inline [left] pane and the page beside
  /// it; null paints none, while the divider still takes a drag, the keys,
  /// and focus.
  final SplitDividerBuilder? leftDividerBuilder;

  /// Paints the divider between the center column and the inline [right]
  /// pane, as [leftDividerBuilder] does for [left].
  final SplitDividerBuilder? rightDividerBuilder;

  /// Whether a swipe in from a drawer's screen edge opens it; turn it off on
  /// a page with sideways gestures of its own. On iOS the start edge of a
  /// page that can go back stays with the back swipe either way.
  final bool edgeSwipe;

  /// Hears the side whose drawer opens, and null once the open drawer has
  /// closed.
  final ValueChanged<PageDrawerSide?>? onDrawerChanged;

  /// The per-instance part styles, the highest layer (NFR-E02).
  final PageLayoutStyle? customStyle;

  /// The controller of the nearest [PageLayout] above [context].
  ///
  /// Throws a [FlutterError] when no [PageLayout] is above [context].
  static PageLayoutController of(BuildContext context) {
    final scope = _PageLayoutScope._of(context, _PageAspect.controller);
    if (scope == null) {
      throw FlutterError(
        'PageLayout.of() was called with a context that has no PageLayout '
        'above it.\n'
        'Call it from a widget inside one of the PageLayout slots.',
      );
    }
    return scope.controller;
  }

  @override
  State<PageLayout> createState() => _PageLayoutState();
}

/// The slots, in Tab order (NFR-U02).
enum _Slot { header, left, top, tab, body, bottom, right, footer, snack }

/// The screen edges one slot touches, by side from the start.
typedef _Edges = ({bool top, bool bottom, bool start, bool end});

/// What every slot box of one build shares: the system `insets` the page
/// pads by, from [_PageLayoutState._insets], and the slots' `textStyle`.
typedef _SlotLook = ({EdgeInsetsDirectional insets, TextStyle textStyle});

/// What the drawer stage draws: the `shown` side, opening, open, or
/// closing, and whether a drawer is `open` or opening.
typedef _DrawerView = ({PageDrawerSide? shown, bool open});

const _DrawerView _noDrawer = (shown: null, open: false);

/// The fields of [_PageLayoutScope], one dependency aspect each (layout s03
/// invariant 63).
enum _PageAspect { controller, drawer }

class _PageLayoutState extends State<PageLayout>
    with SingleTickerProviderStateMixin {
  /// The least release speed, in logical pixels per second toward a side,
  /// that a drag takes as a fling to that side, as Flutter's `Drawer`.
  static const double _flingVelocity = 365;

  /// The controller the page made, while the app passes none.
  PageLayoutController? _ownController;

  PageLayoutController get _controller =>
      widget.controller ?? (_ownController ??= PageLayoutController());

  /// The node over every slot, whose descendants take no focus while
  /// loading.
  final _slotsNode = FocusNode(
    debugLabel: 'PageLayout slots',
    canRequestFocus: false,
    skipTraversal: true,
  );

  /// The node that held focus in a slot when loading turned true.
  FocusNode? _focusBeforeLoading;

  /// The node loading's unfocus moved focus to, once it landed.
  FocusNode? _parkedFocus;

  /// The drawer's 0-to-1 animation, which a drag also drives (layout s03
  /// invariant 65).
  late final _drawer = AnimationController(vsync: this)
    ..addStatusListener(_onDrawerStatus);

  /// What the drawer stage draws, published to it with no rebuild of the
  /// page (layout s03 invariant 63).
  final _drawerView = ValueNotifier<_DrawerView>(_noDrawer);

  /// The scope the shown drawer panel keeps focus in.
  final _drawerFocus = FocusScopeNode(debugLabel: 'PageLayout drawer');

  /// The side whose drawer panel shows: opening, open, or closing.
  PageDrawerSide? _shown;

  /// The side `onDrawerChanged` last heard.
  PageDrawerSide? _reported;

  /// The side a drag moves, and the drawer progress the drag has reached.
  PageDrawerSide? _dragSide;
  double _dragValue = 0;

  /// The route a `page` drawer opened, while it shows.
  Route<void>? _pageRoute;

  /// The splits of `left` beside the main column and of the center column
  /// beside `right`: each hears its EndUser's settled moves, which the page
  /// hands to the controller as widths.
  final _leftSplit = SplitLayoutController();
  final _rightSplit = SplitLayoutController();

  /// The width of each split at its last layout, which turns a settled
  /// fraction into a width.
  double _leftExtent = 0;
  double _rightExtent = 0;

  Curve _curve = Curves.easeInOutSine;
  TargetPlatform _platform = defaultTargetPlatform;
  WindowSize _windowSize = WindowSize.mobile;

  @override
  void initState() {
    super.initState();
    _controller._layout = this;
    _leftSplit.addListener(() => _onSettled(PageDrawerSide.left));
    _rightSplit.addListener(() => _onSettled(PageDrawerSide.right));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final motion = context.theme.animation.normal;
    final duration = motion.duration ?? Duration.zero;
    _drawer
      ..duration = duration
      ..reverseDuration = motion.reverseDuration ?? duration;
    _curve = motion.curve ?? Curves.easeInOutSine;
    _platform = Theme.of(context).platform;
    _windowSize = context.deviceWindow.windowSize;
    _closeDrawerGoneInline();
  }

  @override
  void didUpdateWidget(PageLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    _swapController(oldWidget.controller);
    if (widget.loading != oldWidget.loading) _moveFocusForLoading();
    _closeDrawerGoneInline();
  }

  @override
  void dispose() {
    _detach(_controller);
    _ownController?.dispose();
    _drawer.dispose();
    _drawerView.dispose();
    _drawerFocus.dispose();
    _slotsNode.dispose();
    _leftSplit.dispose();
    _rightSplit.dispose();
    super.dispose();
  }

  /// Disposes the page's own controller once the app passes one, and makes
  /// a new own one from the app's widths once the app passes none; the
  /// controller in use takes over the side asked open.
  void _swapController(PageLayoutController? old) {
    final passed = widget.controller;
    if (passed == old) return;
    final previous = old ?? _ownController;
    final openSide = previous?._openSide;
    if (previous != null) _detach(previous);
    if (passed != null) {
      _ownController?.dispose();
      _ownController = null;
    } else if (old != null) {
      _ownController = PageLayoutController(
        leftWidth: old.leftWidth,
        rightWidth: old.rightWidth,
      );
    }
    _controller
      .._layout = this
      .._openSide = openSide;
  }

  /// Lets [controller] go of this page, while it holds this page.
  void _detach(PageLayoutController controller) {
    if (controller._layout != this) return;
    controller
      .._layout = null
      .._openSide = null;
  }

  /// Keeps the slot node that holds focus as loading turns true, and hands
  /// focus back as loading turns false (US-18 FR-06 E05): to that node, as
  /// long as focus still sits where loading parked it, and then into a
  /// drawer asked open meanwhile, which keeps focus inside (layout s03
  /// invariant 68). A route above the page keeps its focus.
  void _moveFocusForLoading() {
    final manager = FocusManager.instance;
    if (widget.loading) {
      final held = _slotsNode.hasFocus ? manager.primaryFocus : null;
      _focusBeforeLoading = held;
      _parkedFocus = null;
      if (held == null) return;
      // The unfocus lands after this frame's build; read where it went.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !widget.loading || _focusBeforeLoading != held) return;
        manager.applyFocusChangesIfNeeded();
        _parkedFocus = manager.primaryFocus;
      });
      return;
    }
    final node = _focusBeforeLoading;
    final parked = _parkedFocus;
    _focusBeforeLoading = null;
    _parkedFocus = null;
    if (!(ModalRoute.isCurrentOf(context) ?? true)) return;
    final restore =
        node != null &&
        (node.context?.mounted ?? false) &&
        manager.primaryFocus == parked;
    final drawerOpen = _shown != null && _controller._openSide == _shown;
    if (!restore && !drawerOpen) return;
    // The slots' Focus widget sets the same value as it rebuilds; setting
    // it first lets the requests below land in this frame.
    _slotsNode.descendantsAreFocusable = true;
    // Restoring first puts the node back in the focus history, so closing
    // the drawer returns focus to it.
    if (restore) node.requestFocus();
    if (drawerOpen && !(restore && node.ancestors.contains(_drawerFocus))) {
      _drawerFocus.requestFocus();
    }
  }

  // MARK: - Build

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final style = _style(context);
    final look = (insets: _insets(context), textStyle: _textStyle(context));
    final keyboard = widget.resizeToAvoidKeyboard
        ? MediaQuery.viewInsetsOf(context).bottom
        : 0.0;
    final page = StackLayout(
      fit: StackFit.expand,
      children: [
        _geometry(style, look, keyboard),
        ?_snack(style, look, keyboard),
      ],
    );
    return ValueListenableBuilder<_DrawerView>(
      valueListenable: _drawerView,
      builder: (context, drawer, child) => _PageLayoutScope(
        controller: _controller,
        drawer: drawer,
        child: child ?? const SizedBox.shrink(),
      ),
      child: ContainerLayout(
        style: style.outer ?? const WidgetStyle(),
        child: Material(
          type: MaterialType.transparency,
          textStyle: look.textStyle,
          child: IconTheme.merge(
            data: IconThemeData(color: theme.color.icon.defaults.primary),
            child: StackLayout(
              fit: StackFit.expand,
              children: [
                Focus(
                  focusNode: _slotsNode,
                  canRequestFocus: false,
                  skipTraversal: true,
                  includeSemantics: false,
                  descendantsAreFocusable: !widget.loading,
                  descendantsAreTraversable: !widget.loading,
                  child: FocusTraversalGroup(
                    policy: OrderedTraversalPolicy(),
                    child: _DrawerReader(
                      builder: (drawer) => PageDrawerStage(
                        progress: _drawer,
                        shown: drawer.shown,
                        open: drawer.open,
                        left: _drawerSide(PageDrawerSide.left),
                        right: _drawerSide(PageDrawerSide.right),
                        edgeSwipe: widget.edgeSwipe,
                        focusNode: _drawerFocus,
                        panel: (side, corners) =>
                            _drawerPanel(side, corners, style, look),
                        onClose: _close,
                        onDragStart: _dragStart,
                        onDragUpdate: _dragUpdate,
                        onDragEnd: _dragEnd,
                        child: page,
                      ),
                    ),
                  ),
                ),
                _LoadingLayer(
                  loading: widget.loading,
                  builder: widget.loadingBuilder,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Each part's style at [context]: the theme defaults, then the app-wide
  /// [PageLayoutStyle], then [PageLayout.customStyle] (FO-08 US-06 FR-01).
  PageLayoutStyle _style(BuildContext context) => _themeStyle(context.theme)
      .merge(
        StratumComponentDefaults.partsOf<PageLayoutStyle>(context, PageLayout),
      )
      .merge(widget.customStyle);

  /// The slots' text style at [context]: the body text in the theme's
  /// primary text color.
  TextStyle _textStyle(BuildContext context) {
    final text = TextStyle(color: context.theme.color.text.defaults.primary);
    return Theme.of(context).textTheme.bodyMedium?.merge(text) ?? text;
  }

  // MARK: - Drawers

  /// Whether the window sits below [PageLayout.drawerCut], where `left`
  /// and `right` are drawers (layout s03 invariant 69).
  bool get _belowCut => _windowSize < widget.drawerCut;

  /// Whether [side] is `right` shown as the front overlay drawer, at or
  /// above the drawer cut (US-19 FR-01 E04).
  bool _isOverlay(PageDrawerSide side) =>
      side == PageDrawerSide.right && widget.rightAsOverlay && !_belowCut;

  /// [side]'s slot while it sits inline; null where it is a drawer.
  Widget? _inlineOf(PageDrawerSide side) =>
      _belowCut || _isOverlay(side) ? null : _slotOf(side);

  /// [PageLayout.left] while it sits inline; null below the drawer cut.
  Widget? get _inlineLeft => _inlineOf(PageDrawerSide.left);

  /// [PageLayout.right] while it sits inline; null below the drawer cut or
  /// as the overlay drawer.
  Widget? get _inlineRight => _inlineOf(PageDrawerSide.right);

  Widget? _slotOf(PageDrawerSide side) => switch (side) {
    PageDrawerSide.left => widget.left,
    PageDrawerSide.right => widget.right,
  };

  PageSide _sideOf(PageDrawerSide side) => switch (side) {
    PageDrawerSide.left => widget.leftSide,
    PageDrawerSide.right => widget.rightSide,
  };

  PageDrawerType _typeOf(PageDrawerSide side) =>
      resolveDrawerType(_drawerSide(side) ?? _sideOf(side), _platform);

  /// Whether [side] opens as a drawer here: its slot is set, and the window
  /// sits below the drawer cut or [side] is the overlay drawer.
  bool _isDrawer(PageDrawerSide side) =>
      _slotOf(side) != null && (_belowCut || _isOverlay(side));

  /// Whether a drag moves [side]'s drawer frame by frame: every type but
  /// `permanent` and `page`, which open or close only on release.
  bool _followsDrag(PageDrawerSide side) => switch (_typeOf(side)) {
    PageDrawerType.front || PageDrawerType.back || PageDrawerType.slide => true,
    PageDrawerType.permanent || PageDrawerType.page => false,
  };

  /// Opens [side]'s drawer, unless it has no drawer here or is already
  /// open (US-19 FR-03 E01; R21).
  void _open(PageDrawerSide side) {
    if (!_isDrawer(side) || _controller._openSide == side) return;
    _show(side);
  }

  /// Asks [side] open, reports it, and shows it: a `page` drawer as a
  /// pushed page, a `permanent` one at once, and the others over the
  /// theme's `normal` level, with focus moved into the panel.
  void _show(PageDrawerSide side) {
    final type = _typeOf(side);
    final navigator = type == PageDrawerType.page
        ? Navigator.maybeOf(context)
        : null;
    if (type == PageDrawerType.page &&
        (navigator == null || _pageRoute != null)) {
      return;
    }
    _controller._openSide = side;
    if (_shown != side) {
      // Asked open first, so taking another side's panel away settles
      // nothing.
      _drawer.value = 0;
      _shown = navigator == null ? side : null;
    }
    _publish();
    _report(side);
    if (navigator != null) {
      _pushPage(navigator, side);
    } else if (type == PageDrawerType.permanent) {
      _focusDrawer(side);
      _drawer.value = 1;
    } else {
      _focusDrawer(side);
      _drawer.animateTo(1, curve: _curve);
    }
  }

  /// Moves focus into [side]'s panel once the frame that shows it lands:
  /// a focus scope node takes a request only while it is in the focus
  /// tree (US-19 FR-05).
  ///
  /// A page under another route, such as an open modal, takes no focus
  /// from it.
  void _focusDrawer(PageDrawerSide side) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _shown != side || _controller._openSide != side) return;
      if (!(ModalRoute.isCurrentOf(context) ?? true)) return;
      _drawerFocus.requestFocus();
    });
  }

  /// Pushes [side]'s content as a page through the app's page transitions;
  /// once it pops, the drawer reads closed (US-19 FR-02 E03).
  void _pushPage(NavigatorState navigator, PageDrawerSide side) {
    final route = MaterialPageRoute<void>(
      builder: (_) => Builder(builder: (context) => _drawerPage(context, side)),
    );
    _pageRoute = route;
    unawaited(
      navigator.push(route).whenComplete(() {
        if (!mounted || _pageRoute != route) return;
        _pageRoute = null;
        _controller._openSide = null;
        _publish();
        _report(null);
      }),
    );
  }

  /// Closes the open drawer; nothing happens while none is open (US-19
  /// FR-03 E02).
  void _close() {
    if (_controller._openSide == null) return;
    _controller._openSide = null;
    final route = _pageRoute;
    if (route == null) {
      _publish();
      _hide();
      return;
    }
    _pageRoute = null;
    if (route.isCurrent) {
      route.navigator?.pop();
    } else if (route.isActive) {
      route.navigator?.removeRoute(route);
    }
    _publish();
    _report(null);
  }

  /// Takes the shown panel away, at once for `permanent`, else over the
  /// theme's `normal` level; it settles closed once dismissed.
  void _hide() {
    final side = _shown;
    if (side == null || _drawer.isDismissed) {
      _settleClosed();
    } else if (_typeOf(side) == PageDrawerType.permanent) {
      _drawer.value = 0;
    } else {
      _drawer.animateBack(0, curve: _curve);
    }
  }

  void _onDrawerStatus(AnimationStatus status) {
    if (status.isDismissed && _dragSide == null) _settleClosed();
  }

  /// Drops the dismissed panel while no side is asked open, and reports
  /// the drawer closed.
  void _settleClosed() {
    if (_controller._openSide != null || !mounted) return;
    _shown = null;
    _publish();
    _report(null);
  }

  /// Closes the drawer of a side that no longer opens as one, since the
  /// window crossed into inline panes or the app moved the cut or the
  /// overlay choice (US-19 FR-01 E05; Q26).
  ///
  /// It closes at once and reports once the frame ends, so an app that sets
  /// its own state from `onDrawerChanged` never does so during a build.
  void _closeDrawerGoneInline() {
    bool gone() {
      final side = _controller._openSide ?? _shown;
      return side != null && !_isDrawer(side);
    }

    if (!gone()) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !gone()) return;
      if (_pageRoute != null) {
        _close();
        return;
      }
      _dragSide = null;
      _controller._openSide = null;
      // Dismissing settles the drawer closed; a drawer still at 0 settles
      // here.
      _drawer.value = 0;
      _settleClosed();
    });
  }

  void _publish() =>
      _drawerView.value = (shown: _shown, open: _controller._openSide != null);

  /// Tells `onDrawerChanged` about [side] once per change.
  void _report(PageDrawerSide? side) {
    if (_reported == side) return;
    _reported = side;
    widget.onDrawerChanged?.call(side);
  }

  /// Starts a drag of [side]'s drawer from an edge swipe or on its shown
  /// panel; a drag never starts on a side while another side shows.
  void _dragStart(PageDrawerSide side) {
    if (!_isDrawer(side) || _pageRoute != null) return;
    if (_shown != null && _shown != side) return;
    _dragSide = side;
    if (!_followsDrag(side)) {
      _dragValue = _controller._openSide == side ? 1 : 0;
      return;
    }
    _drawer.stop();
    _dragValue = _drawer.value;
    if (_shown == null) {
      _shown = side;
      _publish();
    }
  }

  /// Moves the dragged drawer by [delta], a share of its width.
  void _dragUpdate(double delta) {
    final side = _dragSide;
    if (side == null) return;
    _dragValue = (_dragValue + delta).clamp(0.0, 1.0);
    if (_followsDrag(side)) _drawer.value = _dragValue;
  }

  /// Opens the dragged drawer on a fling toward open or a release past
  /// half open, and closes it otherwise (US-19 FR-02 E06, FR-03).
  void _dragEnd(double velocity) {
    final side = _dragSide;
    if (side == null) return;
    _dragSide = null;
    final open = velocity.abs() >= _flingVelocity
        ? velocity > 0
        : _dragValue >= 0.5;
    if (open && _controller._openSide != side) {
      _show(side);
    } else if (open) {
      if (_followsDrag(side)) _drawer.animateTo(1, curve: _curve);
    } else if (_controller._openSide != null) {
      _close();
    } else {
      _hide();
    }
  }

  /// [side]'s drawer, or null where it has none: the overlay drawer is a
  /// `front` drawer exactly [overlayDrawerWidth] wide, with the side's
  /// label (US-19 FR-01 E04).
  PageSide? _drawerSide(PageDrawerSide side) {
    if (!_isDrawer(side)) return null;
    if (!_isOverlay(side)) return _sideOf(side);
    final width = overlayDrawerWidth(_windowSize);
    return PageSide(
      type: PageDrawerType.front,
      minWidth: width,
      maxWidth: width,
      semanticsLabel: _sideOf(side).semanticsLabel,
    );
  }

  /// [side]'s drawer panel: its slot in the side's resolved slot fill under
  /// the `shadow/4` effect, with [corners] on its screen corners, padded by
  /// the insets of the top, bottom, and its own screen edge, and the close
  /// button over it as the overlay drawer (US-19 FR-01 E04, FR-04; R18).
  Widget _drawerPanel(
    PageDrawerSide side,
    BorderRadius corners,
    PageLayoutStyle style,
    _SlotLook look,
  ) {
    final start = side == PageDrawerSide.left;
    final fill = WidgetStyle(
      dropShadow: context.theme.shadow.level4,
      borderRadius: corners,
    ).merge(start ? style.left : style.right);
    final slot = _slotOf(side) ?? const SizedBox.shrink();
    return _slotBox(
      start ? _Slot.left : _Slot.right,
      _isOverlay(side) ? _withClose(slot) : slot,
      fill,
      look,
      edges: (top: true, bottom: true, start: start, end: !start),
    );
  }

  /// [child] filling the overlay drawer, with a close button at its top end
  /// that Tab visits after [child], as `ModalLayout` shows its own (US-19
  /// FR-01 E04).
  Widget _withClose(Widget child) => FocusTraversalGroup(
    policy: OrderedTraversalPolicy(),
    child: StackLayout(
      fit: StackFit.expand,
      children: [
        FocusTraversalOrder(order: const NumericFocusOrder(1), child: child),
        PositionedDirectional(
          top: 0,
          end: 0,
          child: FocusTraversalOrder(
            order: const NumericFocusOrder(2),
            child: ContainerLayout(
              interaction: Interaction(onTap: _close),
              semantics: SemanticsProperties(
                label: builtInLabelsOf(context).closeButtonLabel,
              ),
              child: const Icon(Icons.close),
            ),
          ),
        ),
      ],
    ),
  );

  /// [side]'s content as the page a `page` drawer opens, read at the
  /// route's [context]: the side's slot fill over the whole screen and its
  /// content padded by every inset, read as a named screen that takes focus
  /// and closes by Esc (US-19 FR-02 E03, FR-03 E07, FR-05).
  Widget _drawerPage(BuildContext context, PageDrawerSide side) {
    final start = side == PageDrawerSide.left;
    final style = _style(context);
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label:
          _sideOf(side).semanticsLabel ?? builtInLabelsOf(context).drawerLabel,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              _closePage(context),
        },
        // The route's own scope holds focus after the push, above any key
        // binding inside the page; this scope takes it, so Esc reaches the
        // binding above.
        child: FocusScope(
          autofocus: true,
          child: IconTheme.merge(
            data: IconThemeData(
              color: context.theme.color.icon.defaults.primary,
            ),
            child: _slotBox(
              start ? _Slot.left : _Slot.right,
              _slotOf(side) ?? const SizedBox.shrink(),
              start ? style.left : style.right,
              (insets: _insets(context), textStyle: _textStyle(context)),
              edges: (top: true, bottom: true, start: true, end: true),
            ),
          ),
        ),
      ),
    );
  }

  /// Closes the `page` drawer shown at the route's [context] by the
  /// controller's close path, with one report; once the page that opened it
  /// is gone, the route pops itself.
  void _closePage(BuildContext context) {
    if (mounted) {
      _close();
    } else {
      Navigator.maybePop(context);
    }
  }

  // MARK: - Layout

  /// The slots in the geometry of layout s03 invariant 61, a null slot and
  /// a drawer side left out, above a footer room at least [keyboard] tall:
  /// the page above
  /// the footer then ends at the keyboard's top while the footer stays
  /// docked at the bottom edge (US-18 FR-05 E04, E05).
  Widget _geometry(PageLayoutStyle style, _SlotLook look, double keyboard) {
    final page = widget;
    Widget? slot(_Slot which, Widget? child, WidgetStyle? fill) =>
        child == null ? null : _slotBox(which, child, fill, look);
    final center = ColumnLayout(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ?slot(_Slot.tab, page.tab, style.tab),
        Expanded(
          child:
              slot(_Slot.body, page.body, style.body) ??
              const SizedBox.shrink(),
        ),
        ?slot(_Slot.bottom, page.bottom, style.bottom),
      ],
    );
    final main = ColumnLayout(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ?slot(_Slot.top, page.top, style.top),
        Expanded(
          child: _sideSplit(
            PageDrawerSide.right,
            column: center,
            pane: slot(_Slot.right, _inlineRight, style.right),
            order: _Slot.tab,
          ),
        ),
      ],
    );
    return ColumnLayout(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ?slot(_Slot.header, page.header, style.header),
        Expanded(
          child: _sideSplit(
            PageDrawerSide.left,
            column: main,
            pane: slot(_Slot.left, _inlineLeft, style.left),
            order: _Slot.left,
          ),
        ),
        ColumnLayout(
          style: WidgetStyle(minHeight: keyboard),
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [?slot(_Slot.footer, page.footer, style.footer)],
        ),
      ],
    );
  }

  /// [column] beside [side]'s inline [pane], or alone where [side] has
  /// none, as one [SplitLayout] at Tab [order], its divider painted by the
  /// side's divider builder (layout s03 invariants 61 and 69; R17).
  ///
  /// The pane opens at the controller's chosen width, so a width set from
  /// code moves it, with no rebuild of any slot. The split stays in the tree
  /// on both sides of the drawer cut, with the pane null below it, so
  /// crossing the cut remounts nothing in [column] (US-19 FR-01 E05).
  Widget _sideSplit(
    PageDrawerSide side, {
    required Widget column,
    required Widget? pane,
    required _Slot order,
  }) {
    final start = side == PageDrawerSide.left;
    final config = _sideOf(side);
    final columnPane = SplitPane(child: column);
    return FocusTraversalOrder(
      order: NumericFocusOrder(order.index + 1),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (start) {
            _leftExtent = constraints.maxWidth;
          } else {
            _rightExtent = constraints.maxWidth;
          }
          return ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              final sidePane = pane == null
                  ? null
                  : SplitPane(
                      size: _paneWidth(side),
                      min: _minWidthOf(config),
                      max: config.maxWidth,
                      child: pane,
                    );
              return SplitLayout(
                controller: start ? _leftSplit : _rightSplit,
                dividerBuilder: start
                    ? widget.leftDividerBuilder
                    : widget.rightDividerBuilder,
                panes: start ? [sidePane, columnPane] : [columnPane, sidePane],
              );
            },
          );
        },
      ),
    );
  }

  /// The width [side]'s inline pane opens at: the controller's chosen
  /// width, else the Figma width of [side] at the window size; the split
  /// bounds either by the side's width bounds and the window.
  double _paneWidth(PageDrawerSide side) {
    final chosen = switch (side) {
      PageDrawerSide.left => _controller.leftWidth,
      PageDrawerSide.right => _controller.rightWidth,
    };
    return chosen ?? inlinePaneWidth(side, _windowSize);
  }

  /// [config]'s least width, giving way to its greatest, as the drawer
  /// width does.
  static double? _minWidthOf(PageSide config) {
    final min = config.minWidth;
    final max = config.maxWidth;
    return min == null || max == null ? min : math.min(min, max);
  }

  /// Hands [side]'s settled move to the controller as the pane's width, and
  /// clears the split's own choice, so the pane keeps that width, not a
  /// share, as the window resizes (US-19 FR-06; R22).
  ///
  /// The split notifies only once an EndUser's move settles; the controller
  /// then notifies the app once.
  void _onSettled(PageDrawerSide side) {
    final start = side == PageDrawerSide.left;
    final split = start ? _leftSplit : _rightSplit;
    final share = split.fractions?[start ? 0 : 1];
    if (share == null) return;
    split.fractions = null;
    final width = share * (start ? _leftExtent : _rightExtent);
    if (start) {
      _controller.leftWidth = width;
    } else {
      _controller.rightWidth = width;
    }
  }

  /// [PageLayout.snack] at the bottom center, above the bottom inset and
  /// the keyboard the page makes room for and within the side insets;
  /// null when there is none.
  Widget? _snack(PageLayoutStyle style, _SlotLook look, double keyboard) {
    final snack = widget.snack;
    if (snack == null) return null;
    final insets = look.insets;
    return ContainerLayout(
      style: WidgetStyle(
        alignment: Alignment.bottomCenter,
        padding: EdgeInsetsDirectional.only(
          start: insets.start,
          end: insets.end,
          bottom: math.max(insets.bottom, keyboard),
        ),
      ),
      child: _slotBox(_Slot.snack, snack, style.snack, look),
    );
  }

  /// The theme layer of every part (US-18 FR-03; NFR-E01): the edge slots
  /// fill the surface token, the page and the body the normal token.
  PageLayoutStyle _themeStyle(StratumTheme theme) {
    final fills = theme.color.background.defaults;
    final edge = WidgetStyle(backgroundColor: fills.surface);
    final page = WidgetStyle(backgroundColor: fills.normal);
    return PageLayoutStyle(
      outer: page,
      header: edge,
      top: edge,
      tab: edge,
      left: edge,
      body: page,
      right: edge,
      bottom: edge,
      footer: edge,
      snack: const WidgetStyle(),
    );
  }

  /// The system insets the page pads by on each side from the start, 0 on
  /// a side whose [PageLayout.safeArea] flag is false.
  EdgeInsetsDirectional _insets(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final safe = widget.safeArea;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return EdgeInsetsDirectional.only(
      top: safe.top ? padding.top : 0,
      bottom: safe.bottom ? padding.bottom : 0,
      start: safe.left ? (rtl ? padding.right : padding.left) : 0,
      end: safe.right ? (rtl ? padding.left : padding.right) : 0,
    );
  }

  /// The screen edges [slot] touches in the geometry of the slots present
  /// (layout s03 invariant 64).
  _Edges _edgesOf(_Slot slot) {
    final page = widget;
    final noHeader = page.header == null;
    final noFooter = page.footer == null;
    final noLeft = _inlineLeft == null;
    final noRight = _inlineRight == null;
    // Nothing above the row of the center column and right.
    final openTop = noHeader && page.top == null;
    return switch (slot) {
      _Slot.header => (top: true, bottom: false, start: true, end: true),
      _Slot.footer => (top: false, bottom: true, start: true, end: true),
      _Slot.left => (top: noHeader, bottom: noFooter, start: true, end: false),
      _Slot.right => (top: openTop, bottom: noFooter, start: false, end: true),
      _Slot.top => (top: noHeader, bottom: false, start: noLeft, end: true),
      _Slot.tab => (top: openTop, bottom: false, start: noLeft, end: noRight),
      _Slot.body => (
        top: openTop && page.tab == null,
        bottom: noFooter && page.bottom == null,
        start: noLeft,
        end: noRight,
      ),
      // The body's room sits above bottom even when body is null.
      _Slot.bottom => (
        top: false,
        bottom: noFooter,
        start: noLeft,
        end: noRight,
      ),
      _Slot.snack => (top: false, bottom: false, start: false, end: false),
    };
  }

  /// [child] in its slot box: the slot's [fill], padded inside by the
  /// [look]'s insets on the screen edges it touches, [edges] when given,
  /// else those of its place in the geometry, under its own Tab order,
  /// repaint boundary, and a transparent [Material] in the [look]'s text
  /// style.
  ///
  /// [PageLayout.body] pads by none of its top and bottom insets: its
  /// children read them, so a scroll view pads by them as it scrolls. Every
  /// other inset is removed for the slot's children, and so is the
  /// keyboard while the page makes room for it.
  Widget _slotBox(
    _Slot slot,
    Widget child,
    WidgetStyle? fill,
    _SlotLook look, {
    _Edges? edges,
  }) {
    final touched = edges ?? _edgesOf(slot);
    final isBody = slot == _Slot.body;
    final pad = look.insets;
    final padding = EdgeInsetsDirectional.only(
      top: touched.top && !isBody ? pad.top : 0,
      bottom: touched.bottom && !isBody ? pad.bottom : 0,
      start: touched.start ? pad.start : 0,
      end: touched.end ? pad.end : 0,
    );
    final box = fill ?? const WidgetStyle();
    return FocusTraversalOrder(
      order: NumericFocusOrder(slot.index + 1),
      child: ContainerLayout(
        repaintBoundary: true,
        style: box.copyWith(
          padding: (box.padding ?? EdgeInsets.zero).add(padding),
        ),
        child: _SlotMedia(
          keepTop: isBody && touched.top && pad.top > 0,
          keepBottom: isBody && touched.bottom && pad.bottom > 0,
          removeKeyboard: widget.resizeToAvoidKeyboard,
          child: Material(
            type: MaterialType.transparency,
            textStyle: look.textStyle,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Publishes a [PageLayout]'s controller, for [PageLayout.of], and what its
/// drawer stage draws, one dependency aspect each, so a drawer change
/// rebuilds the stage and never a [PageLayout.of] reader (layout s03
/// invariant 63).
class _PageLayoutScope extends InheritedModel<_PageAspect> {
  const new({
    required this.controller,
    required this.drawer,
    required super.child,
  });

  final PageLayoutController controller;
  final _DrawerView drawer;

  /// The nearest scope above [context], depending on its [aspect] only.
  static _PageLayoutScope? _of(BuildContext context, _PageAspect aspect) =>
      InheritedModel.inheritFrom<_PageLayoutScope>(context, aspect: aspect);

  @override
  bool updateShouldNotify(_PageLayoutScope oldWidget) =>
      controller != oldWidget.controller || drawer != oldWidget.drawer;

  @override
  bool updateShouldNotifyDependent(
    _PageLayoutScope oldWidget,
    Set<_PageAspect> dependencies,
  ) => dependencies.any(
    (aspect) => switch (aspect) {
      _PageAspect.controller => controller != oldWidget.controller,
      _PageAspect.drawer => drawer != oldWidget.drawer,
    },
  );
}

/// Builds the drawer stage from the scope's drawer aspect alone.
class _DrawerReader extends StatelessWidget {
  const new({required this.builder});

  final Widget Function(_DrawerView drawer) builder;

  @override
  Widget build(BuildContext context) => builder(
    _PageLayoutScope._of(context, _PageAspect.drawer)?.drawer ?? _noDrawer,
  );
}

/// [child] under its context's media data with the padding of every side
/// removed but the top under [keepTop] and the bottom under [keepBottom],
/// and with the keyboard's bottom view inset removed under
/// [removeKeyboard], so a nested page pads and shrinks nothing twice
/// (US-18 FR-04 E04, FR-05 E03).
class _SlotMedia extends StatelessWidget {
  const new({
    required this.keepTop,
    required this.keepBottom,
    required this.removeKeyboard,
    required this.child,
  });

  final bool keepTop;
  final bool keepBottom;
  final bool removeKeyboard;
  final Widget child;

  @override
  Widget build(BuildContext context) => MediaQuery(
    data: MediaQuery.of(context)
        .removePadding(
          removeLeft: true,
          removeTop: !keepTop,
          removeRight: true,
          removeBottom: !keepBottom,
        )
        .removeViewInsets(removeBottom: removeKeyboard),
    child: child,
  );
}

/// The layer that blocks a [PageLayout] while [loading] (US-18 FR-06):
/// built only while [loading] holds or its fade-out runs, so its spinner
/// schedules no frame once hidden.
class _LoadingLayer extends StatefulWidget {
  const new({required this.loading, required this.builder});

  final bool loading;
  final WidgetBuilder? builder;

  @override
  State<_LoadingLayer> createState() => _LoadingLayerState();
}

class _LoadingLayerState extends State<_LoadingLayer>
    with SingleTickerProviderStateMixin {
  late final _fade = AnimationController(vsync: this)
    ..addStatusListener(_onStatus);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final motion = context.theme.animation.fast;
    final duration = motion.duration ?? Duration.zero;
    _fade
      ..duration = duration
      ..reverseDuration = motion.reverseDuration ?? duration;
    if (widget.loading && _fade.status == AnimationStatus.dismissed) {
      _fade.forward();
    }
  }

  @override
  void didUpdateWidget(_LoadingLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.loading == oldWidget.loading) return;
    if (widget.loading) {
      _fade.forward();
    } else {
      _fade.reverse();
    }
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  /// Rebuilds once the fade-out ends, to drop the layer.
  void _onStatus(AnimationStatus status) {
    if (status.isDismissed && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final loading = widget.loading;
    if (!loading && _fade.isDismissed) return const SizedBox.shrink();
    final theme = context.theme;
    final curve = theme.animation.normal.curve ?? Curves.easeInOutSine;
    return IgnorePointer(
      ignoring: !loading,
      child: ExcludeSemantics(
        excluding: !loading,
        child: FadeTransition(
          opacity: _fade.drive(CurveTween(curve: curve)),
          alwaysIncludeSemantics: true,
          child: AbsorbPointer(
            child: BlockSemantics(
              child: Semantics(
                container: true,
                liveRegion: true,
                label: builtInLabelsOf(context).loadingLabel,
                child: Center(
                  child:
                      widget.builder?.call(context) ??
                      CircularProgressIndicator(
                        color: theme.color.icon.defaults.primary,
                      ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
