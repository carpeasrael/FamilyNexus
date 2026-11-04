import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  /// Einladungslinks und Rücksprünge auf das App-Schema außerhalb einer Anmeldesitzung (die Sitzung liefert
  /// ihren Rücksprung selbst, #268, E-91).
  private static let schemes: Set<String> = ["familynexus", "io.github.carpeasrael.familynexus"]

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    // Start über einen Einladungslink: nur unser Schema, nie automatisch handeln (Dart verlangt Bestätigung).
    if let url = connectionOptions.urlContexts.first?.url, SceneDelegate.schemes.contains(url.scheme ?? "") {
      AppDelegate.initialLink = url.absoluteString
    }
  }

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    super.scene(scene, openURLContexts: URLContexts)
    if let url = URLContexts.first?.url, SceneDelegate.schemes.contains(url.scheme ?? "") {
      AppDelegate.linkChannel?.invokeMethod("onLink", arguments: url.absoluteString)
    }
  }
}
