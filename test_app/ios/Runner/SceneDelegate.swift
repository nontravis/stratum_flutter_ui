import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  private static let routeArgumentPrefix = "--route="

  // iOS passes no process argument to Dart, so the engine starts here with the
  // `--route=` ones only, before the view controller launches it with none.
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    let routeArguments = ProcessInfo.processInfo.arguments.filter {
      $0.hasPrefix(SceneDelegate.routeArgumentPrefix)
    }
    guard !routeArguments.isEmpty,
      let controller = window?.rootViewController as? FlutterViewController
    else {
      return
    }

    controller.engine.run(
      withEntrypoint: nil,
      libraryURI: nil,
      initialRoute: nil,
      entrypointArgs: routeArguments
    )
  }
}
