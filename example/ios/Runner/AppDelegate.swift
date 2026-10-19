import Flutter
import GameController
import UIKit

/// Channel name the keyboard-visibility device test (US-04 FR-02 E07) reads
/// through; the Dart side lives in
/// `example/integration_test/support/hardware_keyboard.dart`.
private let hardwareKeyboardChannelName = "dev.stratum.stratum_ui_example/hardware_keyboard"

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: hardwareKeyboardChannelName,
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "hasHardwareKeyboard":
        result(GCKeyboard.coalesced != nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
