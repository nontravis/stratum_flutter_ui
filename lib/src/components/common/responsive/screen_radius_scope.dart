import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

// WORKAROUND: Flutter fills MediaQueryData.displayCornerRadii only on
// Android API 31+ (flutter/packages/flutter/lib/src/widgets/media_query.dart:816-817
// at 3.47.7). Flutter PR #189963 fills it on iOS 26; remove the iOS branch
// then; remove the scope and probe once macOS is covered too (Deferral
// queue 4).
/// Publishes the native probe's screen corner radii into [MediaQuery] on
/// iOS and macOS, where Flutter reports none, so `DeviceWindow.radius`
/// stays one aspect read (FO-07 US-04 FR-03; responsive s03 invariant 9).
///
/// One per tree: `StratumThemeApplication` inserts it only when [hasScope]
/// is false, so a tree publishes one [MediaQuery]. Every scope alive in the
/// process shares one subscription to the probe.
///
/// On iOS and macOS, where the probe subscribes, the scope keeps one
/// pass-through [MediaQuery] present unconditionally from its first frame,
/// with no [GlobalKey]: every State below stays mounted across every probe
/// event, including the first one and any flip to or from null. Every
/// other platform inserts no [MediaQuery] (responsive s03 invariant 9).
class ScreenRadiusScope extends StatefulWidget {
  const new({super.key, required this.child});

  final Widget child;

  /// Whether a [ScreenRadiusScope] is above [context]; registers no
  /// dependency.
  static bool hasScope(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_ScreenRadiusMarker>() != null;

  /// Forgets every subscribed scope and the last radius, and clears the
  /// probe's handler: a failed test skips its unmount and leaves its scope
  /// subscribed, which would keep the next test's scope from sending
  /// `listen`.
  @visibleForTesting
  static void reset() => _RadiusProbeSubscription.reset();

  @override
  State<ScreenRadiusScope> createState() => _ScreenRadiusScopeState();
}

class _ScreenRadiusScopeState extends State<ScreenRadiusScope> {
  bool _subscribed = false;
  BorderRadius? _probe;

  static bool get _darwin =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  @override
  void initState() {
    super.initState();
    if (!_darwin) return;
    _subscribed = true;
    _probe = _RadiusProbeSubscription.add(this);
  }

  @override
  void dispose() {
    if (_subscribed) _RadiusProbeSubscription.remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_subscribed) return _ScreenRadiusMarker(child: widget.child);
    final base = MediaQuery.of(context);
    final probe = _probe;
    return _ScreenRadiusMarker(
      child: MediaQuery(
        data: probe == null || base.displayCornerRadii != null
            ? base
            : base.applyDisplayCornerRadii(probe),
        child: widget.child,
      ),
    );
  }

  void _take(BorderRadius? probe) => setState(() => _probe = probe);
}

/// The one subscription to the native probe per process, shared by every
/// live [ScreenRadiusScope].
///
/// The channel holds one handler and the native side one stream, so a
/// scope that owned them would freeze its siblings and, when it left,
/// cancel a stream a newer scope still reads. Here the first scope in sets
/// the handler and sends `listen`, each event reaches every scope and stays
/// as the last value a later scope starts from, and the last scope out
/// clears the handler and sends `cancel`.
abstract final class _RadiusProbeSubscription {
  /// The probe's event channel, opened here rather than through
  /// `EventChannel.receiveBroadcastStream`, which reports a missing plugin
  /// as an error: `listen` and `cancel` are method calls, and each event
  /// is an envelope on the same channel name.
  static const _channel = MethodChannel('stratum_ui/screen_radius');

  static final Set<_ScreenRadiusScopeState> _scopes = {};
  static BorderRadius? _last;

  /// Subscribes [scope] and returns the last radius the probe sent.
  static BorderRadius? add(_ScreenRadiusScopeState scope) {
    if (_scopes.isEmpty) {
      _channel.binaryMessenger.setMessageHandler(_channel.name, _onEvent);
      unawaited(_call('listen'));
    }
    _scopes.add(scope);
    return _last;
  }

  /// Unsubscribes [scope]; the last one out ends the native stream.
  static void remove(_ScreenRadiusScopeState scope) {
    _scopes.remove(scope);
    if (_scopes.isNotEmpty) return;
    _channel.binaryMessenger.setMessageHandler(_channel.name, null);
    _last = null;
    unawaited(_call('cancel'));
  }

  /// See [ScreenRadiusScope.reset].
  static void reset() {
    _scopes.clear();
    _last = null;
    _channel.binaryMessenger.setMessageHandler(_channel.name, null);
  }

  /// Takes one probe event; a null message ends the stream and keeps the
  /// last radius. An error event or a malformed one leaves the radius
  /// unreadable, so null, and reports the error (responsive s03
  /// invariant 9).
  static Future<ByteData?> _onEvent(ByteData? message) async {
    if (message == null) return null;
    BorderRadius? probe;
    try {
      probe = _decode(_channel.codec.decodeEnvelope(message));
    } on PlatformException catch (exception, stack) {
      _report(exception, stack, 'while reading the screen radius probe');
    } on FormatException catch (exception, stack) {
      _report(exception, stack, 'while reading the screen radius probe');
    }
    _publish(probe);
    return null;
  }

  static void _publish(BorderRadius? probe) {
    _last = probe;
    for (final scope in _scopes.toList()) {
      scope._take(probe);
    }
  }

  /// Calls the probe's [method]. With no native probe to answer (a widget
  /// test, a host built without the plugin) the radius stays unreadable,
  /// so null. A failed call reports its error; a failed `listen` leaves
  /// the radius unreadable too.
  static Future<void> _call(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } on MissingPluginException {
      // Unreadable reads null (FR-03), which _last already holds.
    } on PlatformException catch (exception, stack) {
      _report(exception, stack, 'while calling $method on the probe');
      if (method == 'listen') _publish(null);
    }
  }

  static void _report(Object exception, StackTrace stack, String context) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: exception,
        stack: stack,
        library: 'stratum_ui',
        context: ErrorDescription(context),
      ),
    );
  }

  /// The event's corner radii: null for a nil event, the probe's
  /// "unreadable"; a corner the event leaves out reads zero.
  ///
  /// Throws a [FormatException] for an event that is not a map, or for a
  /// corner that is not a finite number of zero or more.
  static BorderRadius? _decode(Object? event) {
    if (event == null) return null;
    if (event is! Map) {
      throw FormatException('The probe sent no corner map', event);
    }
    Radius corner(String key) => switch (event[key]) {
      null => Radius.zero,
      final num value when value.isFinite && value >= 0 => Radius.circular(
        value.toDouble(),
      ),
      final value => throw FormatException(
        'The probe sent no finite radius of 0 or more for $key',
        value,
      ),
    };
    return BorderRadius.only(
      topLeft: corner('topLeft'),
      topRight: corner('topRight'),
      bottomLeft: corner('bottomLeft'),
      bottomRight: corner('bottomRight'),
    );
  }
}

/// Marks a [ScreenRadiusScope] for [ScreenRadiusScope.hasScope]; it holds
/// no value, so it never notifies.
class _ScreenRadiusMarker extends InheritedWidget {
  const new({required super.child});

  @override
  bool updateShouldNotify(_ScreenRadiusMarker oldWidget) => false;
}
