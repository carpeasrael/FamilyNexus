import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  static var linkChannel: FlutterMethodChannel?
  static var initialLink: String?
  private static let scheme = "familynexus"

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    excludeDataFromBackup()
    super.applicationDidFinishLaunching(notification)
  }

  override func application(_ application: NSApplication, open urls: [URL]) {
    // Nur unser Schema wird weitergereicht; gehandelt wird nie automatisch (Dart verlangt Bestätigung).
    guard let url = urls.first(where: { $0.scheme == AppDelegate.scheme }) else { return }
    if let channel = AppDelegate.linkChannel {
      channel.invokeMethod("onLink", arguments: url.absoluteString)
    } else {
      AppDelegate.initialLink = url.absoluteString
    }
  }

  /// Datenbanken liegen in „Application Support“ des App-Containers; sie werden von Time-Machine-
  /// Sicherungen ausgenommen (Vorgabe: keine Inhalte in Backups).
  private func excludeDataFromBackup() {
    let fm = FileManager.default
    let dirs: [URL] = [
      fm.urls(for: .documentDirectory, in: .userDomainMask).first,
      fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
    ].compactMap { $0 }
    for var url in dirs {
      try? fm.createDirectory(at: url, withIntermediateDirectories: true)
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      try? url.setResourceValues(values)
    }
  }
}
