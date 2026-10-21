import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  private static let scheme = "familynexus"

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    // Start über einen Einladungslink: nur unser Schema, nie automatisch handeln (Dart verlangt Bestätigung).
    if let url = connectionOptions.urlContexts.first?.url, url.scheme == SceneDelegate.scheme {
      AppDelegate.initialLink = url.absoluteString
    }
  }

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    super.scene(scene, openURLContexts: URLContexts)
    if let url = URLContexts.first?.url, url.scheme == SceneDelegate.scheme {
      AppDelegate.linkChannel?.invokeMethod("onLink", arguments: url.absoluteString)
    }
  }
}
