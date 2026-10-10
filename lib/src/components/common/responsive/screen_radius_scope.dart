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
/// iOS and macOS while Flutter reports none, so `DeviceWindow.radius`
/// stays one aspect read (FO-07 US-04 FR-03; responsive s03 invariant 9).
///
/// One per tree: the probe's channel keeps one listener, so
/// `StratumThemeApplication` inserts it only when [hasScope] is false.
class ScreenRadiusScope extends StatefulWidget {
  const new({super.key, required this.child});

  final Widget child;

  /// Whether a [ScreenRadiusScope] is above [context]; registers no
  /// dependency.
  static bool hasScope(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_ScreenRadiusMarker>() != null;

  @override
  State<ScreenRadiusScope> createState() => _ScreenRadiusScopeState();
}

class _ScreenRadiusScopeState extends State<ScreenRadiusScope> {
  /// The probe's event channel, opened here rather than through
  /// `EventChannel.receiveBroadcastStream`, which reports a missing plugin
  /// as an error: `listen` and `cancel` are method calls, and each event
  /// is an envelope on the same channel name.
  static const _channel = MethodChannel('stratum_ui/screen_radius');

  /// Keeps every State below for this State's whole life, while the
  /// published [MediaQuery] comes and goes above the child.
  final GlobalKey _childKey = GlobalKey();

  bool _listening = false;
  BorderRadius? _probe;

  static bool get _darwin =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  @override
  void initState() {
    super.initState();
    if (!_darwin) return;
    _listening = true;
    _channel.binaryMessenger.setMessageHandler(_channel.name, _onEvent);
    unawaited(_call('listen'));
  }

  @override
  void dispose() {
    if (_listening) {
      _channel.binaryMessenger.setMessageHandler(_channel.name, null);
      unawaited(_call('cancel'));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = KeyedSubtree(key: _childKey, child: widget.child);
    final probe = _probe;
    return _ScreenRadiusMarker(
      child: probe == null || MediaQuery.displayCornerRadiiOf(context) != null
          ? child
          : MediaQuery(
              data: MediaQuery.of(context).applyDisplayCornerRadii(probe),
              child: child,
            ),
    );
  }

  /// Takes one probe event; a null message ends the stream and keeps the
  /// last radius. An error event leaves the radius unreadable, so null,
  /// and reports the error.
  Future<ByteData?> _onEvent(ByteData? message) async {
    if (message == null) return null;
    BorderRadius? probe;
    try {
      probe = _decode(_channel.codec.decodeEnvelope(message));
    } on PlatformException catch (exception, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: exception,
          stack: stack,
          library: 'stratum_ui',
          context: ErrorDescription('while reading the screen radius probe'),
        ),
      );
    }
    setState(() => _probe = probe);
    return null;
  }

  /// Calls the probe's [method]. With no native probe to answer (a widget
  /// test, a host built without the plugin) the radius stays unreadable,
  /// so null.
  static Future<void> _call(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } on MissingPluginException {
      // Unreadable reads null (FR-03), which _probe already holds.
    }
  }

  /// The event's corner radii: null for a nil event, the probe's
  /// "unreadable"; a corner the event leaves out reads zero.
  static BorderRadius? _decode(Object? event) {
    if (event is! Map) return null;
    Radius corner(String key) =>
        Radius.circular((event[key] as num?)?.toDouble() ?? 0);
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
