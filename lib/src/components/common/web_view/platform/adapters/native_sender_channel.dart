import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/shared/native_bridge_session.dart';
import 'package:webview_flutter/webview_flutter.dart' as wf;
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

/// Receives one page-to-app bridge message and the sender the platform
/// names for it.
typedef NativeSenderListener = void Function(
  String data,
  BridgeMessageSender sender,
);

/// Replaces the native sender channel of new Android, iOS, and macOS
/// adapters in tests.
@visibleForTesting
NativeSenderChannel? debugNativeSenderChannel;

/// Carries page-to-app bridge messages on Android, iOS, and macOS through
/// the package's own native code, which names each message's sender
/// (US-03 FR-01, `s01_architecture.md` Native sender channel).
abstract interface class NativeSenderChannel {
  /// The channel new adapters use: [debugNativeSenderChannel] when a test
  /// set one, else the channel backed by the package's Kotlin and Swift
  /// code, created on first use.
  static NativeSenderChannel get current =>
      debugNativeSenderChannel ?? _platform;

  static final NativeSenderChannel _platform =
      MethodChannelNativeSenderChannel();

  /// Installs the page-side `StratumBridge` object on the platform view of
  /// [controller] and sends every message it receives to [onMessage].
  ///
  /// Call it before the first load. Returns `false` when the platform cannot
  /// carry the bridge (an Android WebView without `WEB_MESSAGE_LISTENER` or
  /// `JS_INJECTION_IN_FRAME_AND_WORLD`); then no page gets the object. A
  /// second `attach()` for the same view's id before the first resolves
  /// replaces its listener; the first then also returns `false`, even on a
  /// `true` platform answer, because [onMessage] is no longer the one
  /// installed.
  /// Throws a [PlatformException] when the platform finds no web view for
  /// [controller], which means the view was used before the platform
  /// created it.
  Future<bool> attach(
    wf.WebViewController controller,
    NativeSenderListener onMessage,
  );

  /// Stops delivering messages of the platform view of [controller].
  Future<void> detach(wf.WebViewController controller);

  /// Runs [script] through [replyProxy] on the platform view of
  /// [controller] (Android), which runs it only in the document that sent
  /// the message [replyProxy] came with, and returns whether the script
  /// returned `true` (US-03 FR-02 E13).
  ///
  /// Throws a [PlatformException] when that document is gone
  /// (`FRAME_DESTROYED`), the script fails, or another main-frame document
  /// has posted since; may never complete for a document that is unloading.
  Future<bool> runThroughReplyProxy(
    wf.WebViewController controller,
    BridgeReplyProxy replyProxy,
    String script,
  );
}

/// [NativeSenderChannel] over the `stratum_ui/web_view_bridge` method
/// channel.
///
/// Dart calls `attach` and `detach` with `{webViewId}`, and
/// `runThroughReplyProxy` with `{webViewId, replyProxy, script}`; the
/// platform calls `message` with
/// `{webViewId, data, origin, isMainFrame, replyProxy}`, where `origin` is
/// the sender's origin, or `null` for an opaque origin, and `replyProxy` is
/// the id Android gives the reply proxy of a main-frame sender, absent on
/// iOS and macOS.
final class MethodChannelNativeSenderChannel implements NativeSenderChannel {
  /// [webViewId] reads the platform view id of a controller; tests pass
  /// their own, because a fake platform controller has none.
  new({
    MethodChannel? channel,
    int Function(wf.WebViewController controller)? webViewId,
  }) : _channel = channel ?? const MethodChannel('stratum_ui/web_view_bridge'),
       _webViewId = webViewId ?? platformWebViewId {
    _channel.setMethodCallHandler(_handle);
  }

  final MethodChannel _channel;
  final int Function(wf.WebViewController controller) _webViewId;
  final Map<int, NativeSenderListener> _listeners = {};

  @override
  Future<bool> attach(
    wf.WebViewController controller,
    NativeSenderListener onMessage,
  ) async {
    final id = _webViewId(controller);
    // Registered before the answer, so a message the platform sends while
    // attach is pending still reaches the listener.
    _listeners[id] = onMessage;
    var attached = false;
    try {
      attached =
          await _channel.invokeMethod<bool>('attach', <String, Object?>{
            'webViewId': id,
          }) ??
          false;
    } finally {
      // A failed attach leaves no listener behind; a later attach of the
      // same view may already have replaced this one.
      if (!attached && identical(_listeners[id], onMessage)) {
        _listeners.remove(id);
      }
    }
    // An overlapped later attach for the same id may have replaced
    // [onMessage] before the platform answered; only the call whose
    // listener is still installed may report itself attached.
    return attached && identical(_listeners[id], onMessage);
  }

  @override
  Future<void> detach(wf.WebViewController controller) async {
    final id = _webViewId(controller);
    _listeners.remove(id);
    await _channel.invokeMethod<void>('detach', <String, Object?>{
      'webViewId': id,
    });
  }

  @override
  Future<bool> runThroughReplyProxy(
    wf.WebViewController controller,
    BridgeReplyProxy replyProxy,
    String script,
  ) async {
    final delivered = await _channel.invokeMethod<bool>(
      'runThroughReplyProxy',
      <String, Object?>{
        'webViewId': _webViewId(controller),
        'replyProxy': replyProxy.id,
        'script': script,
      },
    );
    return delivered ?? false;
  }

  /// Delivers a `message` call; a call with a missing or mistyped argument
  /// is dropped.
  ///
  /// An opaque origin crosses as `null`, also in the `"null"` form a
  /// serialized opaque origin takes.
  Future<void> _handle(MethodCall call) async {
    if (call.method != 'message') return;
    final arguments = call.arguments;
    if (arguments is! Map) return;
    final id = arguments['webViewId'];
    final data = arguments['data'];
    final origin = arguments['origin'];
    final isMainFrame = arguments['isMainFrame'];
    final replyProxy = arguments['replyProxy'];
    if (id is! int || data is! String || isMainFrame is! bool) return;
    if (origin != null && origin is! String) return;
    if (replyProxy != null && replyProxy is! int) return;
    _listeners[id]?.call(
      data,
      BridgeMessageSender(
        origin: origin == null || origin == 'null'
            ? null
            : Uri.tryParse(origin as String),
        isMainFrame: isMainFrame,
        replyProxy: replyProxy == null
            ? null
            : BridgeReplyProxy(replyProxy as int),
      ),
    );
  }

  /// The id the external API of `webview_flutter_android` or
  /// `webview_flutter_wkwebview` finds the platform view by; throws an
  /// [UnsupportedError] for any other platform controller.
  static int platformWebViewId(wf.WebViewController controller) =>
      switch (controller.platform) {
        final AndroidWebViewController android => android.webViewIdentifier,
        final WebKitWebViewController webKit => webKit.webViewIdentifier,
        final other => throw UnsupportedError(
          'StratumWebView has no native sender channel for '
          '${other.runtimeType}.',
        ),
      };
}
