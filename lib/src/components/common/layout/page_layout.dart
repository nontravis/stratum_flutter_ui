import 'dart:math' as math;

import 'package:stratum_ui/src/components/common/l10n/built_in_labels.dart';
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

/// The chosen widths of a [PageLayout]'s inline side panes, which
/// [PageLayout.of] returns (US-19 FR-06; layout s03 invariants 66 and 69).
///
/// [leftWidth] and [rightWidth] hold the EndUser's chosen widths, never the
/// window-clamped widths the page draws; null means none is chosen. Pass
/// kept widths to the constructor to restore them, and set them from code.
/// It notifies only when a set changes a width: from code, or once a pane
/// resize settles; never per drag frame and never when a window clamp
/// changes only the drawn width. A [PageLayout] given none makes its own,
/// as a [ScrollController], and disposes only that one.
class PageLayoutController extends ChangeNotifier {
  /// Starts with [leftWidth] and [rightWidth], such as ones the app kept,
  /// to restore them.
  new({double? leftWidth, double? rightWidth})
    : _leftWidth = _checked(leftWidth),
      _rightWidth = _checked(rightWidth);

  double? _leftWidth;
  double? _rightWidth;

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
/// While [loading] holds, a layer over the whole page refuses every tap and
/// keyboard focus, reads as a live region with the built-in loading label,
/// and shows [loadingBuilder]'s widget, else a plain spinner; focus returns
/// to where it sat once [loading] turns false. The layer fades in and out
/// over the theme's `fast` level with no other movement (US-18 FR-06).
///
/// Each part's style layers the theme defaults, then the app-wide
/// [PageLayoutStyle] the application registers for [PageLayout], then
/// [customStyle] (FO-08 US-06 FR-01). Tab visits [header], [left], [top],
/// [tab], [body], [bottom], [right], [footer], then [snack] (NFR-U02).
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

  /// Holds the chosen side pane widths; null makes one of the page's own.
  final PageLayoutController? controller;

  /// The per-instance part styles, the highest layer (NFR-E02).
  final PageLayoutStyle? customStyle;

  /// The controller of the nearest [PageLayout] above [context].
  ///
  /// Throws a [FlutterError] when no [PageLayout] is above [context].
  static PageLayoutController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_PageLayoutScope>();
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

class _PageLayoutState extends State<PageLayout> {
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

  @override
  void didUpdateWidget(PageLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    _swapController(oldWidget.controller);
    if (widget.loading != oldWidget.loading) _moveFocusForLoading();
  }

  @override
  void dispose() {
    _ownController?.dispose();
    _slotsNode.dispose();
    super.dispose();
  }

  /// Disposes the page's own controller once the app passes one, and makes
  /// a new own one from the app's widths once the app passes none.
  void _swapController(PageLayoutController? old) {
    final passed = widget.controller;
    if (passed == old) return;
    if (passed != null) {
      _ownController?.dispose();
      _ownController = null;
    } else if (old != null) {
      _ownController = PageLayoutController(
        leftWidth: old.leftWidth,
        rightWidth: old.rightWidth,
      );
    }
  }

  /// Keeps the slot node that holds focus as loading turns true, and gives
  /// it focus back as loading turns false (US-18 FR-06 E05).
  void _moveFocusForLoading() {
    if (widget.loading) {
      _focusBeforeLoading = _slotsNode.hasFocus
          ? FocusManager.instance.primaryFocus
          : null;
      return;
    }
    final node = _focusBeforeLoading;
    _focusBeforeLoading = null;
    if (node == null || !(node.context?.mounted ?? false)) return;
    // The slots' Focus widget sets the same value as it rebuilds; setting
    // it first lets the request below land in this frame.
    _slotsNode.descendantsAreFocusable = true;
    node.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final style = _themeStyle(theme)
        .merge(
          StratumComponentDefaults.partsOf<PageLayoutStyle>(
            context,
            PageLayout,
          ),
        )
        .merge(widget.customStyle);
    final text = TextStyle(color: theme.color.text.defaults.primary);
    final look = (
      insets: _insets(context),
      textStyle: Theme.of(context).textTheme.bodyMedium?.merge(text) ?? text,
    );
    final keyboard = widget.resizeToAvoidKeyboard
        ? MediaQuery.viewInsetsOf(context).bottom
        : 0.0;
    return _PageLayoutScope(
      controller: _controller,
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
                    child: StackLayout(
                      fit: StackFit.expand,
                      children: [
                        _geometry(style, look, keyboard),
                        ?_snack(style, look, keyboard),
                      ],
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

  /// The slots in the geometry of layout s03 invariant 61, a null slot
  /// left out, above a footer room at least [keyboard] tall: the page above
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
          child: RowLayout(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: center),
              ?slot(_Slot.right, page.right, style.right),
            ],
          ),
        ),
      ],
    );
    return ColumnLayout(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ?slot(_Slot.header, page.header, style.header),
        Expanded(
          child: RowLayout(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ?slot(_Slot.left, page.left, style.left),
              Expanded(child: main),
            ],
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
    final noLeft = page.left == null;
    final noRight = page.right == null;
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
      _Slot.bottom => (
        top: openTop && page.tab == null && page.body == null,
        bottom: noFooter,
        start: noLeft,
        end: noRight,
      ),
      _Slot.snack => (top: false, bottom: false, start: false, end: false),
    };
  }

  /// [child] in its slot box: the slot's [fill], padded inside by the
  /// [look]'s insets on the screen edges it touches, under its own Tab
  /// order, repaint boundary, and a transparent [Material] in the [look]'s
  /// text style.
  ///
  /// [PageLayout.body] pads by none of its top and bottom insets: its
  /// children read them, so a scroll view pads by them as it scrolls. Every
  /// other inset is removed for the slot's children, and so is the
  /// keyboard while the page makes room for it.
  Widget _slotBox(_Slot slot, Widget child, WidgetStyle? fill, _SlotLook look) {
    final edges = _edgesOf(slot);
    final isBody = slot == _Slot.body;
    final pad = look.insets;
    final padding = EdgeInsetsDirectional.only(
      top: edges.top && !isBody ? pad.top : 0,
      bottom: edges.bottom && !isBody ? pad.bottom : 0,
      start: edges.start ? pad.start : 0,
      end: edges.end ? pad.end : 0,
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
          keepTop: isBody && edges.top && pad.top > 0,
          keepBottom: isBody && edges.bottom && pad.bottom > 0,
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

/// Publishes a [PageLayout]'s controller to its slots, for
/// [PageLayout.of].
class _PageLayoutScope extends InheritedWidget {
  const new({required this.controller, required super.child});

  final PageLayoutController controller;

  @override
  bool updateShouldNotify(_PageLayoutScope oldWidget) =>
      controller != oldWidget.controller;
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
