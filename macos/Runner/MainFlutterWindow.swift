import AuthenticationServices
import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  /// Anmeldesitzung für Anbieterseiten (#268, E-91); nur auf dem Main-Thread gelesen und geschrieben.
  private var webAuthChannel: FlutterMethodChannel?
  private var current: (id: Int, session: ASWebAuthenticationSession)?
  private var maxStartedId = 0
  private var preCancelled = Set<Int>()

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

    // Anbieterseiten (Anmeldung, Kontoanlage, Kontoseiten, Captcha) in ASWebAuthenticationSession (#268, E-91).
    let webAuth = FlutterMethodChannel(name: "de.inneso.familynexus/webauth", binaryMessenger: messenger)
    webAuth.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(false)
        return
      }
      let args = call.arguments as? [String: Any]
      switch call.method {
      case "start":
        guard let id = args?["id"] as? Int, let url = args?["url"] as? String else {
          result(false)
          return
        }
        result(self.webAuthStart(id: id, url: url, scheme: args?["scheme"] as? String))
      case "cancel":
        if let id = args?["id"] as? Int { self.webAuthCancel(id: id) }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    webAuthChannel = webAuth

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
      } else if call.method == "setBadge" {
        // Zahl ungelesener Nachrichten am Dock-Symbol (#254), ohne Berechtigung.
        let count = max(0, (call.arguments as? Int) ?? 0)
        NSApp.dockTile.badgeLabel = count == 0 ? nil : (count > 99 ? "99+" : String(count))
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }

  // MARK: Anmeldesitzung (ASWebAuthenticationSession, #268, E-91)

  /// Startet eine Sitzung für die Anbieterseite [url] (nur https). Die ID kommt immer von Dart; eine laufende
  /// Sitzung wird ersetzt und meldet einmal `ended(alteId, nil)`. `false`, wenn nichts gestartet wurde.
  private func webAuthStart(id: Int, url: String, scheme: String?) -> Bool {
    guard let target = URL(string: url), target.scheme?.lowercased() == "https" else { return false }
    if preCancelled.remove(id) != nil { return false }
    if let old = current {
      current = nil
      old.session.cancel()
      webAuthChannel?.invokeMethod("ended", arguments: ["id": old.id, "url": NSNull()] as [String: Any])
    }
    let callbackScheme = scheme ?? "io.github.carpeasrael.familynexus"
    let handler: (URL?, Error?) -> Void = { [weak self] callbackURL, error in
      // Beliebiger Thread: `current` und der Kanal nur auf dem Main-Thread.
      DispatchQueue.main.async {
        guard let self = self, let running = self.current, running.id == id else { return }
        self.current = nil
        // Abbruch (canceledLogin) und jeder Fehler: ohne Adresse.
        var value: Any = NSNull()
        if error == nil, let text = callbackURL?.absoluteString { value = text }
        self.webAuthChannel?.invokeMethod("ended", arguments: ["id": id, "url": value] as [String: Any])
      }
    }
    let session: ASWebAuthenticationSession
    if #available(macOS 14.4, *) {
      session = ASWebAuthenticationSession(url: target, callback: .customScheme(callbackScheme), completionHandler: handler)
    } else {
      session = ASWebAuthenticationSession(url: target, callbackURLScheme: callbackScheme, completionHandler: handler)
    }
    // Keine gemeinsamen Safari-Cookies und keine Zustimmungsabfrage.
    session.prefersEphemeralWebBrowserSession = true
    session.presentationContextProvider = self
    current = (id: id, session: session)
    maxStartedId = max(maxStartedId, id)
    if !session.start() {
      current = nil
      return false
    }
    return true
  }

  /// Beendet die Sitzung [id] und meldet einmal `ended(id, nil)`; eine noch nicht gestartete ID wird vorgemerkt.
  private func webAuthCancel(id: Int) {
    if let running = current, running.id == id {
      current = nil
      running.session.cancel()
      webAuthChannel?.invokeMethod("ended", arguments: ["id": id, "url": NSNull()] as [String: Any])
    } else if id > maxStartedId {
      preCancelled.insert(id)
    }
  }
}

extension MainFlutterWindow: ASWebAuthenticationPresentationContextProviding {
  func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
    return self
  }
}
