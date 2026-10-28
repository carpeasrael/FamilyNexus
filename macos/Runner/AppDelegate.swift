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
    // Nur unser Schema und der https-Link der Landingpage werden weitergereicht; gehandelt wird nie
    // automatisch (Dart prüft den Link und verlangt Bestätigung).
    guard let url = urls.first(where: AppDelegate.isInviteLink) else { return }
    if let channel = AppDelegate.linkChannel {
      channel.invokeMethod("onLink", arguments: url.absoluteString)
    } else {
      AppDelegate.initialLink = url.absoluteString
    }
  }

  /// `familynexus://…` oder `https://carpeasrael.github.io/FamilyNexus/join/#…` (z. B. `open -a FamilyNexus <Link>`, #59).
  private static func isInviteLink(_ url: URL) -> Bool {
    if url.scheme == scheme { return true }
    return url.scheme == "https" && url.host == "carpeasrael.github.io" && url.path.hasPrefix("/FamilyNexus/join")
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
