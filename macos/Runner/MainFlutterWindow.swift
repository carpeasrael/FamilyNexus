import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let messenger = flutterViewController.engine.binaryMessenger

    // Einladungslinks (`familynexus://join?…`); Inhalte sind nicht vertrauenswürdig und werden in Dart geprüft.
    let links = FlutterMethodChannel(name: "de.inneso.familynexus/links", binaryMessenger: messenger)
    links.setMethodCallHandler { call, result in
      if call.method == "getInitialLink" {
        result(AppDelegate.initialLink)
        AppDelegate.initialLink = nil
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    AppDelegate.linkChannel = links

    // Kein Bildschirmschutz unter macOS: Screenshots und Bildschirmaufnahmen (z. B. `screencapture`) sind erlaubt.
    let window = FlutterMethodChannel(name: "de.inneso.familynexus/window", binaryMessenger: messenger)
    self.sharingType = .readOnly
    window.setMethodCallHandler { call, result in
      if call.method == "setSecure" {
        result(nil) // bewusst ohne Wirkung: das Fenster bleibt aufnehmbar
      } else if call.method == "copySecret" || call.method == "copySensitive" {
        // Notfall-Schlüssel (512 Zeichen) und Datenprotokoll (#157, 100 000 Zeichen): nur auf diesem Mac
        // (kein Universal Clipboard) und für Verlaufs-Werkzeuge als vertraulich markiert (nspasteboard.org).
        // Das Leeren nach 60 s übernimmt Dart.
        let limit = call.method == "copySecret" ? 512 : 100_000
        guard let text = call.arguments as? String, text.count <= limit else {
          result(FlutterError(code: "invalid", message: nil, details: nil))
          return
        }
        let pb = NSPasteboard.general
        pb.prepareForNewContents(with: .currentHostOnly)
        let concealed = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
        pb.declareTypes([.string, concealed], owner: nil)
        pb.setString(text, forType: .string)
        pb.setString("", forType: concealed)
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }
}
