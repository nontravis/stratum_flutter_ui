import 'package:flutter/widgets.dart';
import 'package:webview_platform_interface/webview_platform_interface.dart';

/// Records every platform object that the webview_all adapter creates.
final class FakeWebviewAllPlatform extends WebViewPlatform {
  final List<FakeWebviewAllController> controllers = [];
  final List<FakeWebviewAllNavigationDelegate> delegates = [];

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    final controller = FakeWebviewAllController(params);
    controllers.add(controller);
    return controller;
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) {
    final delegate = FakeWebviewAllNavigationDelegate(params);
    delegates.add(delegate);
    return delegate;
  }

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => FakeWebviewAllWidget(params);
}

final class FakeWebviewAllController extends PlatformWebViewController {
  new(super.params) : super.implementation();

  final List<Uri> loadedUrls = [];
  final List<String> loadedHtml = [];
  final List<String> scripts = [];
  final List<JavaScriptMode> javaScriptModes = [];
  final Map<String, void Function(JavaScriptMessage)> channels = {};
  int reloadCount = 0;
  String? currentUrlValue;

  @override
  Future<void> loadRequest(LoadRequestParams params) async =>
      loadedUrls.add(params.uri);

  @override
  Future<void> loadHtmlString(String html, {String? baseUrl}) async =>
      loadedHtml.add(html);

  @override
  Future<void> runJavaScript(String javaScript) async =>
      scripts.add(javaScript);

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async =>
      javaScriptModes.add(javaScriptMode);

  @override
  Future<void> addJavaScriptChannel(
    JavaScriptChannelParams javaScriptChannelParams,
  ) async {
    channels[javaScriptChannelParams.name] =
        javaScriptChannelParams.onMessageReceived;
  }

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {}

  @override
  Future<void> reload() async => reloadCount++;

  @override
  Future<void> goBack() async {}

  @override
  Future<void> goForward() async {}

  @override
  Future<bool> canGoBack() async => false;

  @override
  Future<bool> canGoForward() async => false;

  @override
  Future<String?> currentUrl() async => currentUrlValue;
}

final class FakeWebviewAllNavigationDelegate
    extends PlatformNavigationDelegate {
  new(super.params) : super.implementation();

  NavigationRequestCallback? navigationRequestCallback;
  PageEventCallback? pageStartedCallback;
  PageEventCallback? pageFinishedCallback;
  UrlChangeCallback? urlChangeCallback;
  WebResourceErrorCallback? webResourceErrorCallback;
  HttpResponseErrorCallback? httpErrorCallback;

  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback onNavigationRequest,
  ) async => navigationRequestCallback = onNavigationRequest;

  @override
  Future<void> setOnPageStarted(PageEventCallback onPageStarted) async =>
      pageStartedCallback = onPageStarted;

  @override
  Future<void> setOnPageFinished(PageEventCallback onPageFinished) async =>
      pageFinishedCallback = onPageFinished;

  @override
  Future<void> setOnUrlChange(UrlChangeCallback onUrlChange) async =>
      urlChangeCallback = onUrlChange;

  @override
  Future<void> setOnWebResourceError(
    WebResourceErrorCallback onWebResourceError,
  ) async => webResourceErrorCallback = onWebResourceError;

  @override
  Future<void> setOnHttpError(HttpResponseErrorCallback onHttpError) async =>
      httpErrorCallback = onHttpError;
}

final class FakeWebviewAllWidget extends PlatformWebViewWidget {
  new(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) =>
      const SizedBox(key: ValueKey<String>('fake-webview-all'));
}
