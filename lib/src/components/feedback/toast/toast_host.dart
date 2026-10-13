import 'dart:async' show unawaited;

import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart' show SemanticsService;
import 'package:flutter/services.dart' show KeyDownEvent, LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:stratum_ui/src/components/common/l10n/built_in_labels.dart';
import 'package:stratum_ui/src/components/common/model/widget_style.dart';
import 'package:stratum_ui/src/components/feedback/toast/toast_notice.dart';
import 'package:stratum_ui/src/components/feedback/toast/toast_placement.dart';
import 'package:stratum_ui/src/components/feedback/toast/toast_plain_look.dart';
import 'package:stratum_ui/src/extensions/context_extension.dart';
import 'package:stratum_ui/src/themes/constant/feedback_state.dart';
import 'package:toastification/toastification.dart'
    show
        ToastificationCallbacks,
        ToastificationConfig,
        ToastificationConfigProvider,
        ToastificationItem,
        ToastificationWrapper,
        toastification;

/// The one notice a `showToast` call hands the host.
///
/// Public for the call extension and the plain look, but no barrel exports
/// it; it stays inside the toast folder.
class StratumToastRequest {
  const new({
    required this.message,
    required this.kind,
    required this.placement,
    this.action,
    this.customStyle,
  });

  final String message;
  final FeedbackState kind;
  final StratumToastPlacement placement;
  final StratumToastAction? action;
  final WidgetStyle? customStyle;
}

/// Places one notice host above the app's navigator, in
/// `MaterialApp.builder`, and shows every notice of every
/// `context.showToast` call under it (US-01 FR-01).
///
/// One solid notice shows at a time, each further one queued in call
/// order; float notices stack up to 3 per corner, a fourth closing that
/// corner's oldest (US-01 FR-03). A solid notice spans the full screen
/// width, its fill under the status bar or home indicator and its content
/// padded by that inset (US-01 FR-02).
///
/// The host wraps `toastification`; an app that already wraps its root in
/// a `ToastificationWrapper` keeps it, and the host adds none.
class StratumToastHost extends StatefulWidget {
  const new({super.key, required this.child, this.builder});

  final Widget child;

  /// The app's own look for every notice, replacing the plain look only:
  /// placement, queue, timers, close paths, and the announcement stay the
  /// host's (US-01 FR-06 E04; s03 invariant 13).
  final StratumToastBuilder? builder;

  /// The host state above [context], or the `FlutterError` of a tree with
  /// none (US-01 FR-01 E05).
  ///
  /// Reads through `getInheritedWidgetOfExactType`, so a call from an
  /// event handler registers no rebuild tie to the host.
  static StratumToastHostState of(BuildContext context) {
    final host = context
        .getInheritedWidgetOfExactType<_StratumToastHostScope>()
        ?.host;
    if (host == null) {
      throw FlutterError(
        'No StratumToastHost found in context.\n'
        'Place one above the caller, e.g. '
        'MaterialApp(builder: (context, child) => '
        'StratumToastHost(child: child!)).',
      );
    }
    return host;
  }

  @override
  State<StratumToastHost> createState() => StratumToastHostState();
}

/// The host's state: the solid queue, the float stacks, and the show
/// call into `toastification` at the placement's manager key.
class StratumToastHostState extends State<StratumToastHost> {
  /// The show context below the float config; float notices read it.
  final GlobalKey _floatKey = GlobalKey(debugLabel: 'StratumToastHost.float');

  /// The show context below the solid config; solid notices read it.
  final GlobalKey _solidKey = GlobalKey(debugLabel: 'StratumToastHost.solid');

  /// Solid notices waiting for the one on screen to close, in call order
  /// (US-01 FR-03, s03 invariant 2).
  final List<StratumToastRequest> _solidQueue = [];

  /// Whether a solid notice is on screen (US-01 FR-03).
  bool _solidShowing = false;

  /// The live items of each float corner, oldest first (s03 invariant 3).
  final Map<StratumToastCorner, List<ToastificationItem>> _floats = {};

  /// A float corner holds at most this many notices (s03 invariant 3).
  static const int _floatCap = 3;

  bool _disposed = false;

  @override
  void dispose() {
    // WORKAROUND: toastification keeps process-wide managers keyed by
    // alignment, each holding its overlay entry and the running close
    // timers, so they outlive any host and fail the test teardown; remove
    // when a toastification release owns its managers' lifecycle
    // (upstream PR #247).
    // ignore: invalid_use_of_visible_for_testing_member, reads the process-wide managers of toastification 3.2.0
    for (final manager in toastification.managers.values) {
      // ignore: invalid_use_of_visible_for_testing_member, see above.
      for (final item in manager.notifications) {
        if (item.isRunning) item.stop();
      }
    }
    // ignore: invalid_use_of_visible_for_testing_member, see above.
    toastification.managers.clear();
    _disposed = true;
    super.dispose();
  }

  /// Shows [request] now, or queues it when it is a solid notice and one
  /// shows already (US-01 FR-03).
  void show(StratumToastRequest request) {
    if (_disposed) return;
    switch (request.placement) {
      case StratumToastSolid():
        if (_solidShowing) {
          _solidQueue.add(request);
          return;
        }
        _solidShowing = true;
        _present(request);
      case StratumToastFloat(:final corner):
        _floats.putIfAbsent(corner, () => []).add(_present(request));
        _evictOverCap(corner);
    }
  }

  /// Hands [request] to `toastification` at its manager key under the
  /// direction of the show context, so solid notices reach the solid
  /// config and float notices the float one (s03 invariant 4), and
  /// announces it on show, never while queued (US-01 FR-05 E03).
  ToastificationItem _present(StratumToastRequest request) {
    final context = switch (request.placement) {
      StratumToastSolid() => _solidKey.currentContext,
      StratumToastFloat() => _floatKey.currentContext,
    };
    assert(context != null, 'the host is not mounted');
    final direction = Directionality.of(context!);
    final alignment = toastManagerKey(request.placement, direction);
    _announce(context, request);
    return toastification.showCustom(
      context: context,
      alignment: alignment,
      autoCloseDuration: toastCloseTime(
        hasAction: request.action != null,
        screenReader: MediaQuery.accessibleNavigationOf(context),
      ),
      animationDuration: _animationDuration(context),
      animationBuilder: _animate,
      builder: (buildContext, item) =>
          _ToastView(request: request, host: this, item: item),
      callbacks: ToastificationCallbacks(
        onAutoCompleteCompleted: (item) => _closed(request.placement, item),
      ),
    );
  }

  /// Announces [request] as its FO-09 kind name, then its message, in the
  /// app's text direction, taking no focus (US-01 FR-05).
  void _announce(BuildContext context, StratumToastRequest request) {
    final labels = builtInLabelsOf(context);
    final kindName = switch (request.kind) {
      FeedbackState.positive => labels.noticePositiveLabel,
      FeedbackState.negative => labels.noticeNegativeLabel,
      FeedbackState.warning => labels.noticeWarningLabel,
      FeedbackState.info => labels.noticeInfoLabel,
    };
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        '$kindName, ${request.message}',
        Directionality.of(context),
      ),
    );
  }

  /// The show and hide duration: the theme's `normal` level, zero under
  /// reduced motion, where the look fades its own opacity only (NFR-U03;
  /// s03 invariant 14).
  Duration _animationDuration(BuildContext context) {
    // WORKAROUND: toastification animates each item's heightFactor from 0
    // to 1 over the first 60% of the show whatever the animationBuilder
    // returns, so a nonzero duration still resizes and slides the notice
    // under reduced motion; remove when a toastification release skips its
    // size animation under disabled animations.
    return context.reducesMotion
        ? Duration.zero
        : context.theme.animation.normal.duration ??
              const Duration(milliseconds: 300);
  }

  /// Fades [child] on [animation]; toastification pre-curves the intervals
  // it hands (easeInOut), and the size curve stays theirs (s01 Effects;
  // s03 invariant 14).
  Widget _animate(
    BuildContext context,
    Animation<double> animation,
    Alignment alignment,
    Widget child,
  ) {
    // WORKAROUND: toastification hard-codes Curves.easeInOut intervals, so
    // the theme's easeInOutSine cannot drive the show and hide through the
    // package's builder; remove when a toastification release takes a
    // curve per phase.
    return FadeTransition(opacity: animation, child: child);
  }

  /// Closes that corner's oldest notice when the corner holds the cap and
  /// the new one landed, both in this frame's order: `toastification`
  /// adds each item in a post-frame callback, and this eviction registers
  /// after that add, so it dismisses a live item (s03 invariant 3).
  void _evictOverCap(StratumToastCorner corner) {
    final items = _floats[corner]!;
    if (items.length <= _floatCap) return;
    final oldest = items.removeAt(0);
    // WORKAROUND: toastification adds each item in a post-frame callback
    // and dismisses only an item already in the list, so the eviction of
    // a same-frame add must run after it; remove when toastification adds
    // items synchronously (upstream issue #193).
    SchedulerBinding.instance.addPostFrameCallback((_) {
      toastification.dismiss(oldest);
    });
  }

  /// A notice closed by its timer: a float leaves its corner's list; the
  /// next queued solid notice shows (US-01 FR-03, s03 invariants 2, 3).
  void _closed(StratumToastPlacement placement, ToastificationItem item) {
    if (placement case StratumToastFloat(:final corner)) {
      _floats[corner]?.remove(item);
      return;
    }
    if (_solidQueue.isEmpty) {
      _solidShowing = false;
      return;
    }
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_disposed || _solidQueue.isEmpty) return;
      _present(_solidQueue.removeAt(0));
    });
  }

  /// The edge inset of a solid notice, read from the host's own context
  /// outside `toastification`'s list, whose `MediaQuery.removePadding`
  /// zeroes it, so the fill runs under the bar while the content pads by
  /// it (s03 invariant 4).
  EdgeInsets _edgeInset(StratumToastRequest request) {
    final context = _solidKey.currentContext;
    if (context == null) return EdgeInsets.zero;
    final viewPadding = MediaQuery.of(context).viewPadding;
    return switch (request.placement) {
      StratumToastSolid(edge: StratumToastEdge.top) => EdgeInsets.only(
        top: viewPadding.top,
      ),
      StratumToastSolid(edge: StratumToastEdge.bottom) => EdgeInsets.only(
        bottom: viewPadding.bottom,
      ),
      StratumToastFloat() => EdgeInsets.zero,
    };
  }

  /// Closes [item] with no removal animation: every close path of the
  /// host's own look ends here, so a dismissed `Dismissible` never
  /// remounts (s03 invariant 9).
  void _closeItem(ToastificationItem item) {
    toastification.dismiss(item, showRemoveAnimation: false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final floatWidth = _floatWidth(context, theme.layouts.maxWidthMobile);
    return ToastificationConfigProvider(
      config: _floatConfig(floatWidth),
      child: Builder(
        key: _floatKey,
        builder: (floatContext) => _StratumToastHostScope(
          host: this,
          child: ToastificationConfigProvider(
            config: _solidConfig,
            child: Builder(
              key: _solidKey,
              builder: (solidContext) =>
                  _wrapWhenNoWrapperAbove(solidContext, widget.child),
            ),
          ),
        ),
      ),
    );
  }

  /// The host's own wrapper, only when no `ToastificationWrapper` sits
  /// above, since its global key allows one per tree (s01, O1).
  Widget _wrapWhenNoWrapperAbove(BuildContext context, Widget child) {
    if (context.findAncestorWidgetOfExactType<ToastificationWrapper>() !=
        null) {
      return child;
    }
    return ToastificationWrapper(child: child);
  }

  /// The float config: the notice width token capped by the window less
  /// the margin on each side, and the keyboard owned by the margin itself
  /// (s03 invariants 5, 12).
  static ToastificationConfig _floatConfig(double width) =>
      ToastificationConfig(
        itemWidth: width,
        applyMediaQueryViewInsets: false,
        marginBuilder: _floatMargin,
      );

  /// The solid config: full width, the edge's negative `viewPadding` as
  /// the margin that cancels what `toastification` adds, and the keyboard
  /// owned by the margin itself (s03 invariants 4, 5).
  static const ToastificationConfig _solidConfig = ToastificationConfig(
    itemWidth: double.infinity,
    applyMediaQueryViewInsets: false,
    marginBuilder: _solidMargin,
  );

  /// The float margin: `space.lg` off the anchored edge and off each side
  /// a corner hugs, plus the keyboard height on a bottom edge, all read
  /// from the overlay entry's own context; a pure function of that
  /// context (s03 invariants 5, 16, and s01's `space.lg` margin on each
  /// side).
  static EdgeInsets _floatMargin(
    BuildContext context,
    AlignmentGeometry alignment,
  ) {
    final resolved = alignment.resolve(Directionality.of(context));
    final lg = context.theme.space.lg;
    return EdgeInsets.only(
      top: resolved.y < 0 ? lg : 0,
      bottom: resolved.y >= 0.5
          ? lg + MediaQuery.viewInsetsOf(context).bottom
          : 0,
      left: resolved.x < 0 ? lg : 0,
      right: resolved.x > 0 ? lg : 0,
    );
  }

  /// The solid margin of the edge: the negative `viewPadding` of that
  /// edge, cancelling the `viewPadding` `toastification` adds on top, so
  /// the fill reaches the screen edge; a pure function of the overlay
  /// entry's own context (s03 invariants 4, 16).
  static EdgeInsets _solidMargin(
    BuildContext context,
    AlignmentGeometry alignment,
  ) {
    final y = alignment.resolve(Directionality.of(context)).y;
    final viewPadding = MediaQuery.viewPaddingOf(context);
    if (y < 0) return EdgeInsets.only(top: -viewPadding.top);
    return EdgeInsets.only(bottom: -viewPadding.bottom);
  }

  /// The float width token `layouts.max-width-mobile`, capped by the
  /// window less `space.lg` on each side (s03 invariant 12).
  static double _floatWidth(BuildContext context, double token) {
    final lg = context.theme.space.lg;
    final cap = MediaQuery.sizeOf(context).width - 2 * lg;
    return token < cap ? token : cap;
  }
}

/// Publishes the host state to `context.showToast` callers.
class _StratumToastHostScope extends InheritedWidget {
  const new({required this.host, required super.child});

  final StratumToastHostState host;

  @override
  bool updateShouldNotify(_StratumToastHostScope oldWidget) => false;
}

/// One notice as its look reads it, wrapped in its pause, key, and swipe
/// close paths: hover, focus inside, and touch each pause the close
/// timer, and the timer resumes only once all three have ended, a
/// cancelled touch counting as ended; Esc while focus is inside, the
/// close button, and a horizontal swipe close it (US-01 FR-04; s03
/// invariants 7, 9).
class _ToastView extends StatefulWidget {
  const new({required this.request, required this.host, required this.item});

  final StratumToastRequest request;
  final StratumToastHostState host;
  final ToastificationItem item;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView> {
  /// Why the close timer is paused right now; it resumes only once every
  /// reason has ended (s03 invariant 7).
  final Set<_PauseReason> _pauses = {};

  void _pause(_PauseReason reason) {
    if (_pauses.add(reason) && _pauses.length == 1) {
      widget.item.pause();
    }
  }

  void _resume(_PauseReason reason) {
    if (_pauses.remove(reason) && _pauses.isEmpty) {
      widget.item.start();
    }
  }

  void _close() => widget.host._closeItem(widget.item);

  /// The notice as its look reads it (s03 invariant 4, 16).
  StratumToastNotice get _notice => StratumToastNotice(
    message: widget.request.message,
    kind: widget.request.kind,
    placement: widget.request.placement,
    insets: widget.host._edgeInset(widget.request),
    pageSnack: null,
    customStyle: widget.request.customStyle,
    close: _close,
    action: widget.request.action,
  );

  /// The look: the app `builder`'s when set, else the plain look; both
  /// read the same notice (US-01 FR-06 E04; s03 invariant 13).
  Widget _look(BuildContext context) {
    final builder = widget.host.widget.builder;
    return builder != null
        ? builder(context, _notice)
        : StratumToastPlainLook(notice: _notice);
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(widget.item.id),
      direction: DismissDirection.horizontal,
      onDismissed: (_) => _close(),
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        includeSemantics: false,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            _close();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: MouseRegion(
          onEnter: (_) => _pause(_PauseReason.hover),
          onExit: (_) => _resume(_PauseReason.hover),
          child: Listener(
            onPointerDown: (_) => _pause(_PauseReason.touch),
            onPointerUp: (_) => _resume(_PauseReason.touch),
            onPointerCancel: (_) => _resume(_PauseReason.touch),
            child: _PauseOnFocus(
              onFocusInside: (inside) => inside
                  ? _pause(_PauseReason.focus)
                  : _resume(_PauseReason.focus),
              child: _look(context),
            ),
          ),
        ),
      ),
    );
  }
}

/// Why a notice's close timer is paused (s03 invariant 7).
enum _PauseReason { hover, focus, touch }

/// Pauses the notice's timer while focus holds inside [child], however
/// many focusable children it holds, and resumes once focus leaves them
/// all (s03 invariant 7).
///
/// Owns a pass-through node, never a scope: a `FocusScopeNode` with
/// `canRequestFocus` false blocks Tab's descent into the notice's buttons,
/// while a plain unfocusable node reports `hasFocus` for every descendant
/// and stays out of traversal.
class _PauseOnFocus extends StatefulWidget {
  const new({required this.onFocusInside, required this.child});

  final ValueChanged<bool> onFocusInside;
  final Widget child;

  @override
  State<_PauseOnFocus> createState() => _PauseOnFocusState();
}

class _PauseOnFocusState extends State<_PauseOnFocus> {
  /// Whether focus is inside right now, from every focus change under the
  /// notice's subtree.
  bool _inside = false;

  late final FocusNode _node = FocusNode(
    debugLabel: 'StratumToast.notice',
    canRequestFocus: false,
    skipTraversal: true,
  );

  @override
  void initState() {
    super.initState();
    _node.addListener(_changed);
  }

  @override
  void dispose() {
    _node.removeListener(_changed);
    _node.dispose();
    super.dispose();
  }

  void _changed() {
    final inside = _node.hasFocus;
    if (inside != _inside) {
      _inside = inside;
      widget.onFocusInside(inside);
    }
  }

  @override
  Widget build(BuildContext context) =>
      Focus(focusNode: _node, child: widget.child);
}
