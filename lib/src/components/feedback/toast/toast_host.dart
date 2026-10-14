import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart' show SemanticsService;
import 'package:flutter/services.dart' show KeyDownEvent, LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:stratum_ui/src/components/common/l10n/built_in_labels.dart';
import 'package:stratum_ui/src/components/common/layout/page_areas.dart';
import 'package:stratum_ui/src/components/common/model/widget_style.dart';
import 'package:stratum_ui/src/components/feedback/toast/toast_notice.dart';
import 'package:stratum_ui/src/components/feedback/toast/toast_placement.dart';
import 'package:stratum_ui/src/components/feedback/toast/toast_plain_look.dart';
import 'package:stratum_ui/src/extensions/context_extension.dart';
import 'package:stratum_ui/src/themes/constant/feedback_state.dart';
import 'package:stratum_ui/src/themes/constant/window_size.dart';
import 'package:toastification/toastification.dart'
    show
        ToastificationCallbacks,
        ToastificationConfig,
        ToastificationConfigProvider,
        ToastificationItem,
        ToastificationWrapper,
        toastification;

/// [kind]'s accessible name: [kindLabels]'s entry for [kind] when it holds
/// one, else FO-09's built-in name — the same name the host's announcement
/// and the plain look's icon both show (FO-09 FR-01 E08; s03 invariant 11).
String _kindLabel(
  BuildContext context,
  FeedbackState kind,
  Map<FeedbackState, String>? kindLabels,
) {
  final override = kindLabels?[kind];
  if (override != null) return override;
  final labels = builtInLabelsOf(context);
  return switch (kind) {
    FeedbackState.positive => labels.noticePositiveLabel,
    FeedbackState.negative => labels.noticeNegativeLabel,
    FeedbackState.warning => labels.noticeWarningLabel,
    FeedbackState.info => labels.noticeInfoLabel,
  };
}

/// Whether [defaultTargetPlatform] is one of Apple's, where F8 is a media
/// key, so the host shortcut's default order puts Option+T first (US-01
/// FR-05 statement; s03 invariant 18).
bool get _appleTargetPlatform =>
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.iOS;

/// `focusShortcuts`'s default order: Option+T then F8 on macOS and iOS,
/// F8 then Alt+T on every other platform (US-01 FR-05 statement; s03
/// invariant 18).
List<SingleActivator> _defaultFocusShortcuts() {
  const optionT = SingleActivator(LogicalKeyboardKey.keyT, alt: true);
  const f8 = SingleActivator(LogicalKeyboardKey.f8);
  return _appleTargetPlatform ? [optionT, f8] : [f8, optionT];
}

/// [activator]'s name for the built-in hint: its modifiers then its key,
/// joined by `+`, Alt written Option on macOS and iOS (s03 invariant 11).
String _shortcutKeyName(SingleActivator activator) {
  final parts = [
    if (activator.control) 'Ctrl',
    if (activator.alt && _appleTargetPlatform) 'Option',
    if (activator.alt && !_appleTargetPlatform) 'Alt',
    if (activator.meta) 'Meta',
    if (activator.shift) 'Shift',
    activator.trigger.keyLabel,
  ];
  return parts.join('+');
}

/// The host shortcut's intent: move focus into the newest notice on
/// screen (US-01 FR-05; s03 invariant 18).
class _FocusNewestNoticeIntent extends Intent {
  const new();
}

/// [notice]'s first descendant a [FocusTraversalPolicy] would reach, or
/// null when it holds none: generic over whatever look rendered it, plain
/// or an app `builder` (US-01 FR-05; FR-06 E04; s03 invariants 13, 18).
FocusNode? _firstTraversableDescendant(FocusNode notice) {
  for (final node in notice.traversalDescendants) {
    return node;
  }
  return null;
}

/// The newest entry of [showOrder] that [tracking] holds a node for, or
/// null while none of them do: [showOrder] is
/// [StratumToastHostState._present]'s own call order, never the order a
/// notice's widget happened to mount, since
/// `toastification`'s `AnimatedList` always inserts the newest at index 0
/// and builds children in ascending index order, so a mount-order list
/// picks the oldest, not the newest, once two notices show inside the
/// same frame (R27 fix: correctness finding 2, edge finding D).
FocusNode? _newestTrackedNotice(
  Iterable<ToastificationItem> showOrder,
  Map<ToastificationItem, FocusNode> tracking,
) {
  for (final item in showOrder.toList().reversed) {
    final node = tracking[item];
    if (node != null) return node;
  }
  return null;
}

/// Invokes [_FocusNewestNoticeIntent]: requests focus on the newest open
/// notice's first traversable descendant, whatever look built it; disabled
/// while none is open, so the shortcut manager passes the key on, and left
/// unhandled when that notice holds no focusable descendant, so the key
/// still reaches an outer handler (US-01 FR-05; s03 invariant 18).
class _FocusNewestNoticeAction extends Action<_FocusNewestNoticeIntent> {
  new(this._host);

  final StratumToastHostState _host;

  @override
  bool get isActionEnabled => _host._noticeTrackingNodes.isNotEmpty;

  @override
  bool invoke(_FocusNewestNoticeIntent intent) {
    final notice = _newestTrackedNotice(
      _host._open.keys,
      _host._noticeTrackingNodes,
    );
    final target = notice == null ? null : _firstTraversableDescendant(notice);
    target?.requestFocus();
    return target != null;
  }

  @override
  KeyEventResult toKeyEventResult(
    _FocusNewestNoticeIntent intent,
    covariant Object? invokeResult,
  ) => invokeResult == true ? KeyEventResult.handled : KeyEventResult.ignored;
}

/// The one notice a `showToast` call hands the host.
///
/// Public for the call extension and the plain look, but no barrel exports
/// it; it stays inside the toast folder.
class StratumToastRequest {
  const new({
    required this.message,
    required this.kind,
    this.placement,
    this.action,
    this.customStyle,
  });

  final String message;
  final FeedbackState kind;

  /// Where the notice shows; null takes the host's default for the window
  /// size, read from the host's own context (US-01 FR-01 E04).
  final StratumToastPlacement? placement;
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
/// Mount ONE root host per process: `toastification` keeps one wrapper
/// `GlobalKey` and one manager per alignment for the whole process, so a
/// second root host, in another view or window, draws its notices into
/// the first one's navigator; a debug build throws on it. A host nested
/// under another reuses the outer one's wrapper. An app that already
/// wraps its root in a `ToastificationWrapper` keeps it, and the host adds
/// none.
class StratumToastHost extends StatefulWidget {
  const new({
    super.key,
    required this.child,
    this.builder,
    this.closeButtonLabel,
    this.kindLabels,
    this.focusShortcuts,
    this.focusShortcutHint,
  });

  final Widget child;

  /// The app's own look for every notice, replacing the plain look only:
  /// placement, queue, timers, close paths, and the announcement stay the
  /// host's (US-01 FR-06 E04; s03 invariant 13).
  final StratumToastBuilder? builder;

  /// Replaces FO-09's close button label in the announcement and the
  /// close button's accessible name; null keeps the built-in label
  /// (`architecture/localization.md` rule 2; s03 invariant 11).
  final String? closeButtonLabel;

  /// Replaces FO-09's kind name per [FeedbackState] in the announcement
  /// and the icon's accessible name; a kind missing from the map, or a
  /// null [kindLabels], keeps that kind's built-in name
  /// (`architecture/localization.md` rule 2; s03 invariant 11).
  final Map<FeedbackState, String>? kindLabels;

  /// The keys that move focus into the newest notice on screen, null
  /// keeping the platform-ordered default (Option+T then F8 on macOS and
  /// iOS, F8 then Alt+T elsewhere); an empty list turns the shortcut off
  /// and drops the hint from the announcement (US-01 FR-05 E09 to E11,
  /// E13; s03 invariant 18).
  final List<SingleActivator>? focusShortcuts;

  /// Replaces FO-09's shortcut hint in the announcement, which otherwise
  /// names the first `focusShortcuts` entry; null keeps the built-in hint
  /// (US-01 FR-05 E12; FR-06 E06; s03 invariant 11).
  final String? focusShortcutHint;

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

  /// Solid notices waiting for the one on screen to close, in call order,
  /// each with its resolved edge (US-01 FR-03, s03 invariant 2).
  final List<(StratumToastRequest, StratumToastSolid)> _solidQueue = [];

  /// Whether a solid notice holds the solid slot: from its show until it
  /// closes with no solid notice queued behind it, the slot passing
  /// straight to the next queued one otherwise (US-01 FR-03).
  bool _solidShowing = false;

  /// Every open notice, shown and not yet closed, in true show order: the
  /// order [_present] ran, never a queued one, and never the order its
  /// widget happened to mount (s03 invariants 2, 3, 7; R27 fix:
  /// correctness finding 2, edge finding D).
  ///
  /// [_closed] is the one transition out of it.
  final Map<ToastificationItem, _OpenNotice> _open = {};

  /// A float corner holds at most this many notices (s03 invariant 3).
  static const int _floatCap = 3;

  bool _disposed = false;

  /// Every mounted host in this process: a dispose clears the shared
  /// managers only once none is left (edge finding 3), and a debug build
  /// throws on a second root host (security S1).
  static final Set<StratumToastHostState> _liveHosts = {};

  /// Every mounted notice's own focus-tracking node, so [_trackFocus] can
  /// tell focus inside a notice from focus outside every notice (probe-tab
  /// findings, "second defect").
  final Set<FocusNode> _noticeFocusNodes = {};

  /// Each currently-mounted notice's own focus-tracking node, by its
  /// `ToastificationItem`: the host shortcut requests focus on the first
  /// traversable descendant of the newest [_open] entry that has one,
  /// whatever look built it, and [_closed] returns focus when the closing
  /// notice's node holds it (US-01 FR-04, FR-05 E05, E09; FR-06 E04; s03
  /// invariants 13, 18, 19).
  final Map<ToastificationItem, FocusNode> _noticeTrackingNodes = {};

  /// The shortcut's bound action, created once so its enabled check reads
  /// live state from this host.
  late final _FocusNewestNoticeAction _focusNewestNoticeAction =
      _FocusNewestNoticeAction(this);

  /// The most recent focus that sat outside every open notice, so a close
  /// can return focus there instead of wherever the route scope's own
  /// traversal history parks it, which drops the node Tab's `parentScope`
  /// edge unfocused on the way in (probe-tab findings, "second defect
  /// found").
  FocusNode? _lastFocusOutsideNotices;

  @override
  void initState() {
    super.initState();
    final othersLive = _liveHosts.isNotEmpty;
    _liveHosts.add(this);
    FocusManager.instance.addListener(_trackFocus);
    assert(() {
      // Checked once the frame ends: a host that replaces another in one
      // frame meets it here, before the old one's dispose.
      if (othersLive) {
        SchedulerBinding.instance.addPostFrameCallback(
          (_) => _debugCheckOneRootHost(),
        );
      }
      return true;
    }(), 'schedules the debug-only one-root-host check');
  }

  /// Throws while a second host with no host above it is mounted
  /// (security S1).
  void _debugCheckOneRootHost() {
    if (_disposed) return;
    final roots = _liveHosts.where(
      (host) =>
          !host._disposed &&
          host.context.findAncestorStateOfType<StratumToastHostState>() == null,
    );
    if (roots.length <= 1) return;
    throw FlutterError(
      'More than one root StratumToastHost is mounted.\n'
      'toastification keeps one wrapper GlobalKey and one manager per '
      'alignment for the whole process, so a second root host draws its '
      "notices into the first one's navigator. Keep one root "
      'StratumToastHost per process, in MaterialApp.builder.',
    );
  }

  /// Remembers [FocusManager.instance]'s primary focus whenever it sits
  /// outside every open notice, so a later manual close knows where to
  /// return it.
  void _trackFocus() {
    final current = FocusManager.instance.primaryFocus;
    if (current != null && !_insideANotice(current)) {
      _lastFocusOutsideNotices = current;
    }
  }

  void _registerNoticeFocus(ToastificationItem item, FocusNode node) {
    _noticeFocusNodes.add(node);
    _noticeTrackingNodes[item] = node;
  }

  /// Drops [node] for [item] only while it is still the one registered, so
  /// a stale state never clears a live registration.
  void _unregisterNoticeFocus(ToastificationItem item, FocusNode node) {
    _noticeFocusNodes.remove(node);
    if (identical(_noticeTrackingNodes[item], node)) {
      _noticeTrackingNodes.remove(item);
    }
  }

  /// Whether [node] sits inside any open notice's own focus-tracking node.
  bool _insideANotice(FocusNode node) =>
      _noticeFocusNodes.contains(node) ||
      node.ancestors.any(_noticeFocusNodes.contains);

  @override
  void dispose() {
    FocusManager.instance.removeListener(_trackFocus);
    _liveHosts.remove(this);
    if (_liveHosts.isEmpty) {
      // WORKAROUND: toastification keeps process-wide managers keyed by
      // alignment, each holding its overlay entry and the running close
      // timers, so they outlive any host and fail the test teardown; remove
      // when a toastification release owns its managers' lifecycle.
      // ignore: invalid_use_of_visible_for_testing_member, reads the process-wide managers of toastification 3.2.0
      for (final manager in toastification.managers.values) {
        // ignore: invalid_use_of_visible_for_testing_member, see above.
        for (final item in manager.notifications) {
          if (item.isRunning) item.stop();
        }
      }
      // ignore: invalid_use_of_visible_for_testing_member, see above.
      toastification.managers.clear();
    }
    _disposed = true;
    super.dispose();
  }

  /// Shows [request] now, or queues it when it is a solid notice and one
  /// shows already (US-01 FR-03).
  ///
  /// A request with no placement takes the default for the window size,
  /// read here from the host's own context, so the caller registers no
  /// rebuild tie to the window size (US-01 FR-01 E04).
  void show(StratumToastRequest request) {
    if (_disposed) return;
    final placement =
        request.placement ?? defaultToastPlacement(context.windowSize);
    _whenOverlayIsFree(() => _show(request, placement));
  }

  /// Runs [work] now while the scheduler is idle or running post-frame
  /// callbacks, where an overlay insert is legal, else once this frame
  /// ends, with a frame requested so it never waits for an unrelated one
  /// (edge findings 4, I3; correctness finding 1).
  void _whenOverlayIsFree(VoidCallback work) {
    final scheduler = SchedulerBinding.instance;
    switch (scheduler.schedulerPhase) {
      case SchedulerPhase.idle || SchedulerPhase.postFrameCallbacks:
        work();
      case SchedulerPhase.transientCallbacks ||
          SchedulerPhase.midFrameMicrotasks ||
          SchedulerPhase.persistentCallbacks:
        scheduler
          ..addPostFrameCallback((_) {
            if (!_disposed) work();
          })
          ..ensureVisualUpdate();
    }
  }

  /// [show]'s own work, once the overlay takes an insert.
  void _show(StratumToastRequest request, StratumToastPlacement placement) {
    switch (placement) {
      case final StratumToastSolid solid:
        if (_solidShowing) {
          _solidQueue.add((request, solid));
          return;
        }
        _solidShowing = true;
        _present(request, solid);
      case StratumToastFloat(:final corner):
        _present(request, placement);
        _evictOverCap(corner);
    }
  }

  /// Hands [request] to `toastification` at [placement]'s manager key
  /// under the direction of the show context, so solid notices reach the
  /// solid config and float notices the float one (s03 invariant 4), opens
  /// it in [_open], and announces it on show, never while queued (US-01
  /// FR-05 E03).
  void _present(StratumToastRequest request, StratumToastPlacement placement) {
    final context = switch (placement) {
      StratumToastSolid() => _solidKey.currentContext,
      StratumToastFloat() => _floatKey.currentContext,
    };
    assert(context != null, 'the host is not mounted');
    final direction = Directionality.of(context!);
    final alignment = toastManagerKey(placement, direction);
    _announce(context, request);
    final item = toastification.showCustom(
      context: context,
      alignment: alignment,
      autoCloseDuration: toastCloseTime(
        hasAction: request.action != null,
        screenReader: MediaQuery.accessibleNavigationOf(context),
      ),
      animationDuration: _animationDuration(context),
      animationBuilder: _animate,
      // The global key keeps the notice's element, and every state under
      // it, across toastification's unkeyed list slots, which shift by one
      // each time a notice lands or leaves at the same corner (edge
      // finding I1).
      builder: (buildContext, item) => _ToastView(
        key: GlobalObjectKey(item),
        request: request,
        placement: placement,
        host: this,
        item: item,
      ),
      callbacks: ToastificationCallbacks(onAutoCompleteCompleted: _closed),
    );
    _open[item] = _OpenNotice(item, placement);
    // WORKAROUND: toastification queues the insert in a post-frame callback
    // without scheduling a frame; remove when it schedules one itself.
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  /// Announces [request] as its kind name, then its message, then, on
  /// desktop and web only, the shortcut hint, in the app's text
  /// direction, taking no focus (US-01 FR-05 E13, E14).
  void _announce(BuildContext context, StratumToastRequest request) {
    final kindName = _kindLabel(context, request.kind, widget.kindLabels);
    final hint = _shortcutHint(context);
    final announcement = hint == null
        ? '$kindName, ${request.message}'
        : '$kindName, ${request.message}, $hint';
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        announcement,
        Directionality.of(context),
      ),
    );
  }

  /// Whether [_announce] speaks the shortcut hint: desktop or the web
  /// only (US-01 FR-05 E13, E14; s03 invariant 10).
  bool get _hearsShortcutHint =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;

  /// The announcement's shortcut hint, or null to speak none: off the
  /// desktop-and-web set, or with `focusShortcuts` empty (US-01 FR-05
  /// E11, E13, E14; FR-06 E06; s03 invariant 10, 11).
  String? _shortcutHint(BuildContext context) {
    if (!_hearsShortcutHint) return null;
    final shortcuts = widget.focusShortcuts ?? _defaultFocusShortcuts();
    if (shortcuts.isEmpty) return null;
    final override = widget.focusShortcutHint;
    if (override != null) return override;
    final keyName = _shortcutKeyName(shortcuts.first);
    return builtInLabelsOf(context).noticeShortcutHint(keyName);
  }

  /// The theme's `normal` animation level, the show and hide duration
  /// (NFR-U03; s01 Effects).
  static Duration _normalDuration(BuildContext context) =>
      context.theme.animation.normal.duration ??
      const Duration(milliseconds: 300);

  /// toastification's show and hide duration: the theme's `normal` level,
  /// zero under reduced motion, where `_ToastView` fades the look in on
  /// its own (NFR-U03; s03 invariant 14).
  Duration _animationDuration(BuildContext context) {
    // WORKAROUND: toastification animates each item's heightFactor from 0
    // to 1 over the first 60% of the show whatever the animationBuilder
    // returns, so a nonzero duration still resizes and slides the notice
    // under reduced motion; remove when a toastification release skips its
    // size animation under disabled animations.
    return context.reducesMotion ? Duration.zero : _normalDuration(context);
  }

  /// Fades [child] on [animation]; toastification pre-curves the intervals
  /// it hands (easeInOut), and the size curve stays theirs (s01 Effects;
  /// s03 invariant 14).
  Widget _animate(
    BuildContext context,
    Animation<double> animation,
    Alignment alignment,
    Widget child,
  ) {
    // WORKAROUND: toastification hard-codes Curves.easeInOut intervals, so
    // the theme's easeInOutSine cannot drive the show and hide through the
    // package's builder; remove when a toastification release takes a
    // curve per phase. No widget test can assert the curve's shape (the
    // animated rect under full motion only proves the show is not
    // vacuous, s01/s18); removing this line early would compile and pass
    // every test while silently reverting to easeInOut.
    return FadeTransition(opacity: animation, child: child);
  }

  /// Closes that corner's oldest notice when the corner holds more than the
  /// cap, through [_closed] as any close, then dismisses it after this
  /// frame's add: `toastification` adds each item in a post-frame
  /// callback, and this one registers after that add, so it dismisses a
  /// live item (s03 invariants 3, 19).
  void _evictOverCap(StratumToastCorner corner) {
    final atCorner = [
      for (final MapEntry(key: item, value: notice) in _open.entries)
        if (notice.placement case StratumToastFloat(corner: final at)
            when at == corner)
          item,
    ];
    if (atCorner.length <= _floatCap) return;
    final oldest = atCorner.first;
    _closed(oldest);
    // WORKAROUND: toastification adds each item in a post-frame callback
    // and dismisses only an item already in the list, so the eviction of
    // a same-frame add must run after it; remove when toastification adds
    // items synchronously (upstream issue #193).
    SchedulerBinding.instance.addPostFrameCallback((_) {
      toastification.dismiss(oldest);
    });
  }

  /// The one transition out of [_open], run once per notice whatever
  /// closed it: its own timer, any close path of its look, or an eviction
  /// (US-01 FR-03, FR-04; s03 invariants 2, 3, 19).
  ///
  /// A later call for the same notice does nothing, so a second close
  /// never shows a second queued solid notice. It returns focus when the
  /// notice held it, frees the notice's manager once its alignment holds
  /// no open notice, and hands the solid slot to the next queued notice.
  void _closed(ToastificationItem item) {
    final notice = _open.remove(item);
    if (notice == null) return;
    _returnFocusIfInside(item);
    _retireManagerOf(item);
    if (notice.placement is StratumToastSolid) _passSolidSlot();
  }

  /// Hands the solid slot to the next queued solid notice, or frees it
  /// with none queued (US-01 FR-03; s03 invariant 2).
  void _passSolidSlot() {
    if (_solidQueue.isEmpty) {
      _solidShowing = false;
      return;
    }
    _whenOverlayIsFree(() {
      final (request, placement) = _solidQueue.removeAt(0);
      _present(request, placement);
    });
  }

  /// Returns focus from a closing notice that holds it: to the last focus
  /// outside every notice while that node is still in the focus tree and
  /// can take focus, else to the focus its scope held before, which is the
  /// current route's (s03 invariant 19; US-01 FR-04 E06 to E09).
  void _returnFocusIfInside(ToastificationItem item) {
    final notice = _noticeTrackingNodes[item];
    if (notice == null || !notice.hasFocus) return;
    final target = _lastFocusOutsideNotices;
    // A detached node keeps its context, and a focus request on it waits
    // for its return, so only its parent tells it is still in the tree.
    if (target != null && target.parent != null && target.canRequestFocus) {
      target.requestFocus();
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus(
      disposition: UnfocusDisposition.previouslyFocusedChild,
    );
  }

  /// Drops [item]'s `toastification` manager from the process-wide map
  /// once its alignment holds no open notice, so the next show there
  /// builds a fresh manager and overlay entry.
  // WORKAROUND: toastification removes an emptied manager's overlay entry
  // on a wall-clock timer, 50 ms after a close without animation or the
  // exit animation plus 50 ms after one with it, while it adds an item to
  // that entry only in a post-frame callback, so a show landing between
  // the two goes into an entry the timer then removes, and never draws;
  // remove when toastification keeps an emptied entry for an item added
  // after the close, or adds items synchronously.
  void _retireManagerOf(ToastificationItem item) {
    final alignment = item.alignment;
    if (_open.keys.any((open) => open.alignment == alignment)) return;
    // ignore: invalid_use_of_visible_for_testing_member, reads the process-wide managers of toastification 3.2.0
    final manager = toastification.managers[alignment];
    // ignore: invalid_use_of_visible_for_testing_member, see above.
    if (manager == null || manager.notifications.isNotEmpty) return;
    // ignore: invalid_use_of_visible_for_testing_member, see above.
    toastification.managers.remove(alignment);
  }

  /// Pauses [item]'s close timer for [reason] while it is open (s03
  /// invariant 7).
  void _pause(ToastificationItem item, _PauseReason reason) =>
      _open[item]?.pause(reason);

  /// Ends [reason]'s pause of [item]'s close timer while it is open (s03
  /// invariant 7).
  void _resume(ToastificationItem item, _PauseReason reason) =>
      _open[item]?.resume(reason);

  /// The edge inset of a solid notice at [placement], read from the host's
  /// own context outside `toastification`'s list, whose
  /// `MediaQuery.removePadding` zeroes it, so the fill runs under the bar
  /// while the content pads by it (s03 invariant 4).
  ///
  /// Reads the `viewPadding` aspect alone, so a keyboard or resize frame
  /// rebuilds no host builder (performance finding 4).
  EdgeInsets _edgeInset(StratumToastPlacement placement) {
    if (placement is! StratumToastSolid) return EdgeInsets.zero;
    final context = _solidKey.currentContext;
    if (context == null) return EdgeInsets.zero;
    final viewPadding = MediaQuery.viewPaddingOf(context);
    return switch (placement.edge) {
      StratumToastEdge.top => EdgeInsets.only(top: viewPadding.top),
      StratumToastEdge.bottom => EdgeInsets.only(bottom: viewPadding.bottom),
    };
  }

  /// Closes [item] with no removal animation: every close path of a look
  /// (close button, Esc, swipe, and an action tap) ends here, so a
  /// dismissed `Dismissible` never remounts (s03 invariant 9), then runs
  /// [_closed] as a timer close does (US-01 FR-03, FR-04).
  void _closeItem(ToastificationItem item) {
    toastification.dismiss(item, showRemoveAnimation: false);
    _closed(item);
  }

  @override
  Widget build(BuildContext context) {
    // The Shortcuts and Actions pair wraps the host's child, above the
    // Navigator, so a key press from any focused route, a dialog
    // included, bubbles to it (US-01 FR-05; s03 invariant 18).
    return Shortcuts(
      shortcuts: {
        for (final activator
            in widget.focusShortcuts ?? _defaultFocusShortcuts())
          activator: const _FocusNewestNoticeIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _FocusNewestNoticeIntent: _focusNewestNoticeAction,
        },
        child: PageAreasRegistry(
          child: ToastificationConfigProvider(
            config: _floatConfig,
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
          ),
        ),
      ),
    );
  }

  /// The host's own wrapper, only when no `ToastificationWrapper` sits
  /// above, since its global key allows one per tree (s01, O1).
  // WORKAROUND: toastification's `ToastificationWrapper` holds a single
  // `GlobalKey<OverlayState>`, so a second instance under the same app
  // throws on the duplicate key; remove when the wrapper supports more
  // than one per tree or drops the global key.
  Widget _wrapWhenNoWrapperAbove(BuildContext context, Widget child) {
    if (context.findAncestorWidgetOfExactType<ToastificationWrapper>() !=
        null) {
      return child;
    }
    return ToastificationWrapper(child: child);
  }

  /// The float config: no width of its own — the plain look clamps its
  /// own surface to the notice width token capped by the window at build
  /// time instead, so a resize while a float shows is not frozen (s03
  /// invariants 5, 12).
  // WORKAROUND: toastification creates one `ToastificationManager` per
  // alignment on the first show (`managers.putIfAbsent` in
  // `lib/src/core/toastification.dart`) and that manager's config, read
  // once at creation (`toastification_manager.dart`, `config.itemWidth`),
  // outlives every later build of this `ToastificationConfigProvider`; an
  // `itemWidth` here would freeze at the window size of the first show;
  // remove when a toastification release re-reads the config per item,
  // not per manager.
  static const ToastificationConfig _floatConfig = ToastificationConfig(
    itemWidth: double.infinity,
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
  ///
  /// The manager freezes this margin with its overlay entry for its whole
  /// lifetime (toastification builds the entry once per alignment), so
  /// the page-area offsets a placement owes — a footer to clear, a `left`
  /// pane to stay beside — live in `_ToastView`'s own padding, which
  /// rebuilds on every areas write (N12, N13).
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

  /// The solid margin of the edge: on top, the negative `viewPadding` that
  /// cancels the `viewPadding` `toastification` adds on top, so the fill
  /// reaches the screen edge; on bottom, the keyboard height less that
  /// same `viewPadding`, so the net margin is zero with the keyboard
  /// closed and the keyboard's own height with it open (s03 invariant 5,
  /// FR-02 E06); a pure function of the overlay entry's own context (s03
  /// invariants 4, 16).
  ///
  /// The footer and `bottom` offsets a solid bottom notice owes the page
  /// live in `_ToastView`'s own padding, as the float margin's do.
  static EdgeInsets _solidMargin(
    BuildContext context,
    AlignmentGeometry alignment,
  ) {
    final y = alignment.resolve(Directionality.of(context)).y;
    final viewPadding = MediaQuery.viewPaddingOf(context);
    if (y < 0) return EdgeInsets.only(top: -viewPadding.top);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return EdgeInsets.only(bottom: keyboard - viewPadding.bottom);
  }

  /// The padding a notice at [placement] owes the current page's areas:
  /// a solid bottom notice rises above the page's `footer` or `bottom`
  /// beyond the keyboard the manager margin already covers; a bottom
  /// float does the same on mobile and tablet (R26); a desktop float
  /// shifts inside the body, clearing a `left` pane or an end-side gap
  /// (FR-02 E05, E07, E10; s03 invariants 5, 16; N12 to N15).
  ///
  /// Read from `_ToastView`'s own context, so every areas write on the
  /// registered handle rebuilds this padding, unlike the manager's
  /// frozen margin (N13).
  static EdgeInsets _pagePadding(
    BuildContext context,
    StratumToastPlacement placement,
  ) {
    final areas = _currentAreasOf(context);
    if (areas == null) return EdgeInsets.zero;
    final size = MediaQuery.sizeOf(context);
    final window = WindowSize.fromSize(size);
    switch (placement) {
      case StratumToastSolid(edge: StratumToastEdge.top):
        return EdgeInsets.zero;
      case StratumToastSolid(edge: StratumToastEdge.bottom):
        final bar = _barBeyond(areas, size, context);
        return EdgeInsets.only(bottom: bar);
      case StratumToastFloat(:final corner):
        final bottom = corner.name.startsWith('bottom');
        if (!bottom) return EdgeInsets.zero;
        if (window >= WindowSize.desktop) {
          // A desktop bottom float stays beside the pane, not above any
          // page bar; the start side clears `left`, the end side the gap
          // right of `right` (E07); `bottomCenter` clears both sides at
          // once, so it centers inside the body rather than drifting
          // over whichever pane is open.
          final body = areas.body;
          if (body == null) return EdgeInsets.zero;
          if (corner == StratumToastCorner.bottomCenter) {
            return EdgeInsets.only(
              left: body.left,
              right: size.width - body.right,
            );
          }
          final start = corner == StratumToastCorner.bottomStart;
          final rtl = Directionality.of(context) == TextDirection.rtl;
          final ltrStart = start != rtl;
          final gap = ltrStart ? body.left : size.width - body.right;
          return EdgeInsets.only(
            left: ltrStart ? gap : 0,
            right: ltrStart ? 0 : gap,
          );
        }
        // R26: mobile and tablet bottom floats rise above the page's
        // `footer` or `bottom` beyond the keyboard, as solid ones do.
        final bar = _barBeyond(areas, size, context);
        return EdgeInsets.only(bottom: bar);
    }
  }

  /// How far the higher of the page's `footer` and `bottom` tops sits
  /// above the keyboard top the margin already reached: the keyboard
  /// covers the footer's screen-bottom distance whenever it is taller
  /// (N15), so the extra is the bar distance less the keyboard, floored
  /// at 0.
  static double _barBeyond(PageAreas areas, Size size, BuildContext context) {
    var bar = 0.0;
    final footer = areas.footerTop;
    final bottom = areas.bottomTop;
    if (footer != null) bar = size.height - footer;
    if (bottom != null && size.height - bottom > bar) {
      bar = size.height - bottom;
    }
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return (bar - keyboard).clamp(0.0, double.infinity);
  }

  /// The areas of the innermost registered page on the current route;
  /// null with no page registered (s03 invariant 16).
  ///
  /// Reads the registry from [context] itself, so every registration
  /// and areas write rebuilds the overlay entry's margin (N13); a handle
  /// whose route a push has covered loses to an inner current one rather
  /// than placing a notice against a covered page (N14).
  static PageAreas? _currentAreasOf(BuildContext context) =>
      PageAreasRegistry.maybeOf(context)?.current()?.value;
}

/// Publishes the host state to `context.showToast` callers.
class _StratumToastHostScope extends InheritedWidget {
  const new({required this.host, required super.child});

  final StratumToastHostState host;

  @override
  bool updateShouldNotify(_StratumToastHostScope oldWidget) => false;
}

/// One open notice of the host: its placement, and why its close timer is
/// paused right now, so the timer resumes only once every reason has
/// ended (s03 invariant 7).
///
/// Lives in the host, never in the notice's widget state, so it outlasts
/// any rebuild of `toastification`'s list (edge finding I1).
final class _OpenNotice {
  new(this.item, this.placement);

  final ToastificationItem item;
  final StratumToastPlacement placement;
  final Set<_PauseReason> _pauses = {};

  /// Pauses the close timer when [reason] is the first one to hold it.
  void pause(_PauseReason reason) {
    if (_pauses.add(reason) && _pauses.length == 1) item.pause();
  }

  /// Resumes the close timer when [reason] was the last one holding it.
  void resume(_PauseReason reason) {
    if (_pauses.remove(reason) && _pauses.isEmpty) item.start();
  }
}

/// One notice as its look reads it, wrapped in its pause, key, and swipe
/// close paths: hover, focus inside, and touch each pause the close
/// timer, and the timer resumes only once all three have ended, a
/// cancelled touch counting as ended; Esc while focus is inside, the
/// close button, and a horizontal swipe close it (US-01 FR-04; s03
/// invariants 7, 9).
class _ToastView extends StatefulWidget {
  const new({
    super.key,
    required this.request,
    required this.placement,
    required this.host,
    required this.item,
  });

  final StratumToastRequest request;

  /// [request]'s placement, its default resolved by the host.
  final StratumToastPlacement placement;
  final StratumToastHostState host;
  final ToastificationItem item;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView>
    with SingleTickerProviderStateMixin {
  /// `Dismissible`'s own settle and resize durations, kept under full
  /// motion.
  static const Duration _swipeSettle = Duration(milliseconds: 200);
  static const Duration _swipeResize = Duration(milliseconds: 300);

  /// The look's own fade-in under reduced motion, where `toastification`
  /// shows in zero time; it rests at full opacity otherwise (s03
  /// invariant 14).
  late final AnimationController _reducedMotionFade = AnimationController(
    vsync: this,
    value: 1,
  );

  late final Animation<double> _opacity = CurvedAnimation(
    parent: _reducedMotionFade,
    curve: Curves.easeInOutSine,
  );

  bool _faded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_faded) return;
    _faded = true;
    if (!context.reducesMotion) return;
    _reducedMotionFade
      ..duration = StratumToastHostState._normalDuration(context)
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _reducedMotionFade.dispose();
    super.dispose();
  }

  void _pause(_PauseReason reason) => widget.host._pause(widget.item, reason);

  void _resume(_PauseReason reason) => widget.host._resume(widget.item, reason);

  /// Closes the notice through the host's single close path
  /// ([StratumToastHostState._closeItem] then
  /// [StratumToastHostState._closed]), the one a timer close takes too.
  void _close() => widget.host._closeItem(widget.item);

  /// The notice as its look reads it (s03 invariant 4, 16), with [context]
  /// resolving the close button and kind labels, a passed prop winning
  /// over FO-09's built-in one (s03 invariant 11).
  StratumToastNotice _notice(BuildContext context) => StratumToastNotice(
    message: widget.request.message,
    kind: widget.request.kind,
    placement: widget.placement,
    insets: widget.host._edgeInset(widget.placement),
    pageSnack: StratumToastHostState._currentAreasOf(context)?.snack,
    customStyle: widget.request.customStyle,
    close: _close,
    action: widget.request.action,
    closeLabel:
        widget.host.widget.closeButtonLabel ??
        builtInLabelsOf(context).closeButtonLabel,
    kindLabel: _kindLabel(
      context,
      widget.request.kind,
      widget.host.widget.kindLabels,
    ),
  );

  /// The look: the app `builder`'s when set, else the plain look; both
  /// read the same notice (US-01 FR-06 E04; s03 invariant 13).
  Widget _look(BuildContext context) {
    final builder = widget.host.widget.builder;
    final notice = _notice(context);
    return builder != null
        ? builder(context, notice)
        : StratumToastPlainLook(notice: notice);
  }

  @override
  Widget build(BuildContext context) {
    // The page-area offset, read here rather than in the manager's frozen
    // margin, so every areas write moves a showing notice (N12, N13).
    final pagePadding = StratumToastHostState._pagePadding(
      context,
      widget.placement,
    );
    final reducesMotion = context.reducesMotion;
    return Dismissible(
      key: ValueKey(widget.item.id),
      direction: DismissDirection.horizontal,
      // Under reduced motion the finger's own drag is the only motion: no
      // settle after release, and no resize of the notices beside it
      // (s03 invariant 14; edge finding I9).
      movementDuration: reducesMotion ? Duration.zero : _swipeSettle,
      resizeDuration: reducesMotion ? null : _swipeResize,
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
            child: Padding(
              padding: pagePadding,
              child: _PauseOnFocus(
                host: widget.host,
                item: widget.item,
                onFocusInside: (inside) => inside
                    ? _pause(_PauseReason.focus)
                    : _resume(_PauseReason.focus),
                child: FadeTransition(opacity: _opacity, child: _look(context)),
              ),
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
  const new({
    required this.host,
    required this.item,
    required this.onFocusInside,
    required this.child,
  });

  /// Registers this notice's own focus-tracking node with the host while
  /// mounted, so the host can tell this notice's focus from focus outside
  /// every notice, return focus when it closes holding it, and find it by
  /// true show order for the host shortcut (R27 fix: correctness finding
  /// 2, edge finding D).
  final StratumToastHostState host;

  /// This notice's own item, the key [StratumToastHostState._open]
  /// resolves by.
  final ToastificationItem item;

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
    widget.host._registerNoticeFocus(widget.item, _node);
  }

  @override
  void dispose() {
    widget.host._unregisterNoticeFocus(widget.item, _node);
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
