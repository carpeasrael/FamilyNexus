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

    let window = FlutterMethodChannel(name: "de.inneso.familynexus/window", binaryMessenger: messenger)
    window.setMethodCallHandler { [weak self] call, result in
      if call.method == "setSecure" {
        self?.secure = (call.arguments as? Bool) ?? true
        if self?.secure == false { self?.hideCover() }
        result(nil)
      } else if call.method == "copySecret" {
        // Notfall-Schlüssel: nur auf diesem Gerät (kein Universal Clipboard) und nach 60 s verfallen.
        guard let text = call.arguments as? String, text.count <= 512 else {
          result(FlutterError(code: "invalid", message: nil, details: nil))
          return
        }
        UIPasteboard.general.setItems(
          [["public.utf8-plain-text": text]],
          options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(60)]
        )
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
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

  private func showCover() {
    guard secure, cover == nil, let window = keyWindow else { return }
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
