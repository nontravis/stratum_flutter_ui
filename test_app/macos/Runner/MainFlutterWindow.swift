import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    enableFlutterSemantics()

    super.awakeFromNib()
  }

  // Puts the engine in the state a screen-reader user's app is in, so XCTest
  // and raw AX clients can read the semantics tree with VoiceOver off.
  //
  // WORKAROUND: Flutter's macOS engine enables semantics only on this private AppKit notification; remove when the
  // macOS embedder exposes a public semantics switch.
  private func enableFlutterSemantics() {
    NotificationCenter.default.post(
      name: Notification.Name(
        "NSApplicationDidChangeAccessibilityEnhancedUserInterfaceNotification"),
      object: NSApp,
      userInfo: ["AXEnhancedUserInterface": true])
  }
}
