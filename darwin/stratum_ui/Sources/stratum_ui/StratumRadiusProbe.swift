#if os(iOS)
  import Flutter
  import UIKit
#elseif os(macOS)
  import AppKit
  import FlutterMacOS
#endif

// WORKAROUND: Flutter fills MediaQueryData.displayCornerRadii only on
// Android API 31+ (flutter/packages/flutter/lib/src/widgets/media_query.dart:816-817
// at 3.47.7). Flutter PR #189963 fills it on iOS 26; remove the iOS branch
// then; remove the scope and probe once macOS is covered too (Deferral
// queue 4).
/// Reads the screen corner radii through public APIs only and streams them
/// on `stratum_ui/screen_radius` (FO-07 US-04 FR-03).
final class StratumRadiusProbe: NSObject, FlutterStreamHandler {
  static let channelName = "stratum_ui/screen_radius"

  private let registrar: FlutterPluginRegistrar
  private var sink: FlutterEventSink?
  private var observer: NSObjectProtocol?

  private init(registrar: FlutterPluginRegistrar) {
    self.registrar = registrar
  }

  static func register(
    with messenger: FlutterBinaryMessenger, registrar: FlutterPluginRegistrar
  ) -> StratumRadiusProbe {
    let probe = StratumRadiusProbe(registrar: registrar)
    FlutterEventChannel(name: channelName, binaryMessenger: messenger).setStreamHandler(probe)
    return probe
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    send()
    #if os(iOS)
      observer = NotificationCenter.default.addObserver(
        forName: UIScreen.modeDidChangeNotification, object: nil, queue: .main
      ) { [weak self] _ in self?.send() }
    #elseif os(macOS)
      // F19: the registrar's own view window, never every window (`object: nil`).
      observer = NotificationCenter.default.addObserver(
        forName: NSWindow.didResizeNotification, object: registrar.view?.window, queue: .main
      ) { [weak self] _ in self?.send() }
    #endif
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    if let observer { NotificationCenter.default.removeObserver(observer) }
    observer = nil
    sink = nil
    return nil
  }

  private func send() {
    sink?(radii())
  }

  /// The four radii in points, or nil where no public API reports them.
  private func radii() -> [String: Double]? {
    #if os(iOS)
      if #available(iOS 26.0, *) {
        guard
          let view = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows).first(where: \.isKeyWindow)
        else { return nil }
        return [
          "topLeft": Double(view.effectiveRadius(corner: .topLeft)),
          "topRight": Double(view.effectiveRadius(corner: .topRight)),
          "bottomLeft": Double(view.effectiveRadius(corner: .bottomLeft)),
          "bottomRight": Double(view.effectiveRadius(corner: .bottomRight)),
        ]
      }
      return nil
    #elseif os(macOS)
      if #available(macOS 27.0, *) {
        // F19: the registrar's own view window, never `NSApplication.shared.keyWindow`,
        // which is nil while the app is inactive.
        // F3: `effectiveCornerRadii` is nullable; a nil configuration sends null.
        guard
          let view = registrar.view?.window?.contentView,
          let r = view.effectiveCornerRadii
        else { return nil }
        return [
          "topLeft": Double(r.topLeft),
          "topRight": Double(r.topRight),
          "bottomLeft": Double(r.bottomLeft),
          "bottomRight": Double(r.bottomRight),
        ]
      }
      return nil
    #endif
  }
}
