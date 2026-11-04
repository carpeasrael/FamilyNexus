import AuthenticationServices
import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// Kanal für eingehende Einladungslinks (`familynexus://join?…`); Inhalte sind nicht vertrauenswürdig
  /// und werden erst in Dart streng geprüft.
  static var linkChannel: FlutterMethodChannel?
  static var initialLink: String?

  private var secure = true
  private var cover: UIView?

  /// Anmeldesitzung für Anbieterseiten (#268, E-91); nur auf dem Main-Thread gelesen und geschrieben.
  private var webAuthChannel: FlutterMethodChannel?
  private var current: (id: Int, session: ASWebAuthenticationSession)?
  private var maxStartedId = 0
  private var preCancelled = Set<Int>()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    excludeDataFromBackup()
    UNUserNotificationCenter.current().delegate = self
    // Sichere Voreinstellung: Der Sichtschutz gilt ab dem ersten Moment; Dart schaltet ihn nur ab,
    // wenn der Nutzer es in den Einstellungen so wählt.
    let center = NotificationCenter.default
    center.addObserver(self, selector: #selector(appWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
    center.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    center.addObserver(self, selector: #selector(captureChanged), name: UIScreen.capturedDidChangeNotification, object: nil)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()

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

    let window = FlutterMethodChannel(name: "de.inneso.familynexus/window", binaryMessenger: messenger)
    window.setMethodCallHandler { [weak self] call, result in
      if call.method == "setSecure" {
        self?.secure = (call.arguments as? Bool) ?? true
        if self?.secure == false { self?.hideCover() }
        result(nil)
      } else if call.method == "copySecret" || call.method == "copySensitive" {
        // Notfall-Schlüssel (512 Zeichen) und Datenprotokoll (#157, 100 000 Zeichen): nur auf diesem Gerät
        // (kein Universal Clipboard) und nach 60 s verfallen.
        let limit = call.method == "copySecret" ? 512 : 100_000
        guard let text = call.arguments as? String, text.count <= limit else {
          result(FlutterError(code: "invalid", message: nil, details: nil))
          return
        }
        UIPasteboard.general.setItems(
          [["public.utf8-plain-text": text]],
          options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(60)]
        )
        result(nil)
      } else if call.method == "setBadge" {
        // Zahl ungelesener Nachrichten am App-Symbol (#254); zeigt iOS nur mit Freigabe „Kennzeichen“.
        let count = max(0, (call.arguments as? Int) ?? 0)
        if #available(iOS 16.0, *) {
          UNUserNotificationCenter.current().setBadgeCount(count) { _ in }
        } else {
          UIApplication.shared.applicationIconBadgeNumber = count
        }
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
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
    if #available(iOS 17.4, *) {
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

  // MARK: Sichtschutz (App-Umschalter, Bildschirmaufnahme)

  private var keyWindow: UIWindow? {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow } ?? UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first
  }

  /// Nicht während einer Anmeldesitzung: Sie zeigt die Anbieterseite (keine Familiendaten), und der Schutz darf
  /// das Anmeldeblatt nicht überdecken (#268, E-91).
  private func showCover() {
    guard secure, cover == nil, current == nil, let window = keyWindow else { return }
    let v = UIView(frame: window.bounds)
    v.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    v.backgroundColor = UIColor(red: 0.043, green: 0.067, blue: 0.125, alpha: 1)
    let label = UILabel()
    label.text = "FamilyNexus"
    label.textColor = UIColor(red: 0.176, green: 0.831, blue: 0.749, alpha: 1)
    label.font = UIFont.systemFont(ofSize: 28, weight: .semibold)
    label.sizeToFit()
    label.center = CGPoint(x: v.bounds.midX, y: v.bounds.midY)
    label.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin]
    v.addSubview(label)
    window.addSubview(v)
    cover = v
  }

  private func hideCover() {
    cover?.removeFromSuperview()
    cover = nil
  }

  @objc private func appWillResignActive() { showCover() }

  @objc private func appDidBecomeActive() {
    if UIScreen.main.isCaptured && secure { showCover() } else { hideCover() }
  }

  @objc private func captureChanged() {
    if UIScreen.main.isCaptured { showCover() } else if UIApplication.shared.applicationState == .active { hideCover() }
  }

  // MARK: Keine Sicherung in iCloud/iTunes

  /// Datenbanken (SQLCipher) liegen im Dokumentenordner bzw. in „Application Support“. Beides wird von
  /// Sicherungen ausgenommen (Vorgabe: keine Inhalte in Backups).
  private func excludeDataFromBackup() {
    let fm = FileManager.default
    let dirs: [URL] = [
      fm.urls(for: .documentDirectory, in: .userDomainMask).first,
      fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
      fm.urls(for: .libraryDirectory, in: .userDomainMask).first,
    ].compactMap { $0 }
    for var url in dirs {
      try? fm.createDirectory(at: url, withIntermediateDirectories: true)
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      try? url.setResourceValues(values)
    }
  }
}

extension AppDelegate: ASWebAuthenticationPresentationContextProviding {
  func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
    return keyWindow ?? ASPresentationAnchor()
  }
}
