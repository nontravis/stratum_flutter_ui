import 'package:stratum_ui/src/components/common/web_view/platform/platform_web_view_interface.dart';
import 'package:stratum_ui/src/components/common/web_view/stratum_web_view_types.dart';

/// Records every event that a platform web view reports.
final class RecordingListener implements PlatformStratumWebViewListener {
  new({this.allowedOrigins = const <Uri>{}});

  @override
  Set<Uri> allowedOrigins;

  StratumNavigationDecision decision = StratumNavigationDecision.navigate;
  void Function(StratumWebViewMessage message)? onMessageCallback;

  final List<StratumWebViewMessage> messages = [];
  final List<Uri> navigationRequests = [];
  final List<Uri?> pagesStarted = [];
  final List<Uri?> pagesFinished = [];
  final List<StratumWebViewError> errors = [];

  @override
  void onMessage(StratumWebViewMessage message) {
    messages.add(message);
    onMessageCallback?.call(message);
  }

  @override
  StratumNavigationDecision onNavigationRequest(Uri url) {
    navigationRequests.add(url);
    return decision;
  }

  @override
  void onPageStarted(Uri? url) => pagesStarted.add(url);

  @override
  void onPageFinished(Uri? url) => pagesFinished.add(url);

  @override
  void onError(StratumWebViewError error) => errors.add(error);
}
