import 'package:stratum_ui/src/components/common/web_view/platform/adapters/native_sender_channel.dart';
import 'package:stratum_ui/src/components/common/web_view/platform/shared/native_bridge_session.dart';
import 'package:webview_flutter/webview_flutter.dart' as wf;

/// Stands in for the package's Kotlin and Swift sender channel.
final class FakeNativeSenderChannel implements NativeSenderChannel {
  /// What [attach] answers: `false` acts as an Android WebView without
  /// `WEB_MESSAGE_LISTENER` or `JS_INJECTION_IN_FRAME_AND_WORLD`.
  bool supported = true;

  final List<wf.WebViewController> attached = [];
  final List<wf.WebViewController> detached = [];

  /// Every [runThroughReplyProxy] call, in order.
  final List<({BridgeReplyProxy replyProxy, String script})> proxyRuns = [];

  /// What [runThroughReplyProxy] answers: a late answer or a platform error
  /// such as `FRAME_DESTROYED`.
  Future<bool> Function() proxyAnswer = () async => true;

  NativeSenderListener? _listener;

  @override
  Future<bool> attach(
    wf.WebViewController controller,
    NativeSenderListener onMessage,
  ) async {
    attached.add(controller);
    _listener = onMessage;
    return supported;
  }

  @override
  Future<void> detach(wf.WebViewController controller) async {
    detached.add(controller);
    _listener = null;
  }

  @override
  Future<bool> runThroughReplyProxy(
    wf.WebViewController controller,
    BridgeReplyProxy replyProxy,
    String script,
  ) {
    proxyRuns.add((replyProxy: replyProxy, script: script));
    return proxyAnswer();
  }

  /// Sends [data] as the document at [senderUrl] would, in the main frame
  /// unless [isMainFrame] is `false`, with the [replyProxy] Android names;
  /// nothing arrives after [detach].
  void send(
    String data, {
    required String senderUrl,
    bool isMainFrame = true,
    BridgeReplyProxy? replyProxy,
  }) => _listener?.call(
    data,
    BridgeMessageSender(
      origin: Uri.tryParse(senderUrl),
      isMainFrame: isMainFrame,
      replyProxy: replyProxy,
    ),
  );
}
