import ObjectiveC
import WebKit

#if os(iOS)
  import Flutter
#elseif os(macOS)
  import FlutterMacOS
#else
  #error("Unsupported platform.")
#endif

/// The iOS and macOS half of the native sender channel of `StratumWebView`.
///
/// `attach` adds a script message handler named `StratumBridge` and a
/// document-start alias `window.StratumBridge` to the `WKWebView` that
/// `webview_flutter_wkwebview` created for `webViewId`, and forwards every
/// string message with the frame `WKScriptMessage.frameInfo` names.
///
/// `reset` is the first call of every Dart isolate. A hot restart starts a new
/// isolate while this plugin lives on, and the ids `webview_flutter_wkwebview`
/// issues start over, so `reset` removes the handler from every web view it
/// is still installed on before an id can be reused.
public final class StratumUiPlugin: NSObject, FlutterPlugin {
  private static let channelName = "stratum_ui/web_view_bridge"
  private static let bridgeName = "StratumBridge"
  static let aliasSource =
    "window.StratumBridge = webkit.messageHandlers.StratumBridge;"

  private let channel: FlutterMethodChannel
  private let registrar: FlutterPluginRegistrar
  private var handlers: [Int64: InstalledHandler] = [:]
  private var radiusProbe: StratumRadiusProbe?

  init(channel: FlutterMethodChannel, registrar: FlutterPluginRegistrar) {
    self.channel = channel
    self.registrar = registrar
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    #if os(iOS)
      let messenger = registrar.messenger()
    #else
      let messenger = registrar.messenger
    #endif
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    let instance = StratumUiPlugin(channel: channel, registrar: registrar)
    registrar.addMethodCallDelegate(instance, channel: channel)
    instance.radiusProbe = StratumRadiusProbe.register(with: messenger, registrar: registrar)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "reset" {
      reset()
      result(nil)
      return
    }
    guard
      let arguments = call.arguments as? [String: Any],
      let id = (arguments["webViewId"] as? NSNumber)?.int64Value
    else {
      result(FlutterError(code: "bad-arguments", message: "webViewId is missing.", details: nil))
      return
    }
    switch call.method {
    case "attach":
      guard let webView = webView(forIdentifier: id) else {
        result(FlutterError(code: "no-web-view", message: "No WKWebView has id \(id).", details: nil))
        return
      }
      attach(webView, id: id)
      result(true)
    case "detach":
      // Prefer the controller `attach` saved over a fresh lookup; a web view
      // that is already gone, either way, has nothing to detach.
      let controller =
        handlers.removeValue(forKey: id)?.controller
        ?? webView(forIdentifier: id)?.configuration.userContentController
      controller?.removeScriptMessageHandler(forName: Self.bridgeName)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func attach(_ webView: WKWebView, id: Int64) {
    let controller = webView.configuration.userContentController
    controller.removeScriptMessageHandler(forName: Self.bridgeName)
    let handler = BridgeMessageHandler(id: id, channel: channel)
    controller.add(handler, name: Self.bridgeName)
    Self.installAlias(on: controller)
    handlers[id] = InstalledHandler(controller: controller)
  }

  /// Removes the handler from every content controller it is still installed
  /// on and forgets all of them. The document-start alias stays, as after
  /// `detach`.
  private func reset() {
    for installed in handlers.values {
      installed.controller?.removeScriptMessageHandler(forName: Self.bridgeName)
    }
    handlers.removeAll()
  }

  /// Adds the document-start alias `window.StratumBridge` for every frame to
  /// `controller`, once: the alias outlives detach, so a second attach adds
  /// no duplicate.
  static func installAlias(on controller: WKUserContentController) {
    guard !controller.userScripts.contains(where: { $0.source == aliasSource }) else { return }
    controller.addUserScript(
      WKUserScript(source: aliasSource, injectionTime: .atDocumentStart, forMainFrameOnly: false))
  }

  /// Finds the `WKWebView` that `webview_flutter_wkwebview` created for
  /// `id` through its external API, `FWFWebViewFlutterWKWebViewExternalAPI`,
  /// called by its Objective-C name.
  ///
  /// WORKAROUND: Flutter's Swift Package Manager integration copies a plugin
  /// whose manifest names another plugin as a dependency into the app's
  /// build folder (`_copyPluginAndUpdateManifest` in flutter_tools
  /// `swift_package_manager.dart`, Flutter 3.47.3); this package holds its
  /// example app, so that copy never ends. Import the module again once the
  /// tool no longer copies a plugin that contains its app.
  private func webView(forIdentifier id: Int64) -> WKWebView? {
    guard let api = NSClassFromString("FWFWebViewFlutterWKWebViewExternalAPI") else {
      return nil
    }
    #if os(iOS)
      let selector = NSSelectorFromString("webViewForIdentifier:withPluginRegistrar:")
      let source: AnyObject = registrar
    #else
      let selector = NSSelectorFromString("webViewForIdentifier:withPluginRegistry:")
      guard let registry = pluginRegistry() else { return nil }
      let source: AnyObject = registry
    #endif
    guard let method = class_getClassMethod(api, selector), Self.matchesLookup(method) else {
      return nil
    }
    typealias Lookup =
      @convention(c) (AnyClass, Selector, Int64, AnyObject) -> Unmanaged<AnyObject>?
    let lookup = unsafeBitCast(method_getImplementation(method), to: Lookup.self)
    return lookup(api, selector, id, source)?.takeUnretainedValue() as? WKWebView
  }

  /// Whether `method` has the C shape `Lookup` casts it to: it returns an
  /// object and takes an `Int64` and an object after `self` and `_cmd`. A
  /// plugin release that changes the signature then fails closed as a
  /// missing web view instead of calling through a mismatched pointer.
  static func matchesLookup(_ method: Method) -> Bool {
    func encoding(_ copy: UnsafeMutablePointer<CChar>?) -> String? {
      guard let copy else { return nil }
      defer { free(copy) }
      return String(cString: copy)
    }
    return method_getNumberOfArguments(method) == 4
      && encoding(method_copyReturnType(method)) == "@"
      && encoding(method_copyArgumentType(method, 2)) == "q"
      && encoding(method_copyArgumentType(method, 3)) == "@"
  }

  #if os(macOS)
    /// The registry that the external API reads values from: the macOS
    /// registrar publishes none (flutter/flutter#186911), so it is the
    /// `FlutterViewController` up the responder chain of the Flutter view.
    private func pluginRegistry() -> FlutterPluginRegistry? {
      var responder: NSResponder? = registrar.view
      while let current = responder {
        if let controller = current as? FlutterViewController { return controller }
        responder = current.nextResponder
      }
      return nil
    }
  #endif
}

/// The content controller `attach` installed the handler on, held weakly so a
/// web view the app destroyed without a `detach` call does not live on here.
private struct InstalledHandler {
  weak var controller: WKUserContentController?
}

/// Forwards each string `StratumBridge` message of one web view.
final class BridgeMessageHandler: NSObject, WKScriptMessageHandler {
  private let id: Int64
  private weak var channel: FlutterMethodChannel?

  init(id: Int64, channel: FlutterMethodChannel) {
    self.id = id
    self.channel = channel
  }

  func userContentController(
    _ userContentController: WKUserContentController, didReceive message: WKScriptMessage
  ) {
    guard let data = message.body as? String else { return }
    let frame = message.frameInfo
    channel?.invokeMethod(
      "message",
      arguments: [
        "webViewId": id,
        "data": data,
        "origin": Self.origin(of: frame.securityOrigin) ?? NSNull(),
        "isMainFrame": frame.isMainFrame,
      ])
  }

  private static func origin(of origin: WKSecurityOrigin) -> String? {
    Self.origin(scheme: origin.protocol, host: origin.host, port: origin.port)
  }

  /// The serialized origin, as `location.origin` reads it, or `nil` for an
  /// opaque origin, which has no host. An IPv6 host gets its brackets only
  /// when it arrives without them.
  static func origin(scheme: String, host: String, port: Int) -> String? {
    guard !host.isEmpty else { return nil }
    let bracketed = host.contains(":") && !host.hasPrefix("[") ? "[\(host)]" : host
    return port == 0 ? "\(scheme)://\(bracketed)" : "\(scheme)://\(bracketed):\(port)"
  }
}
