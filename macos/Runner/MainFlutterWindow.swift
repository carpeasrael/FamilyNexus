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

    // Bildschirmschutz: Das Fenster wird von Screenshots und Bildschirmaufnahmen ausgenommen.
    let window = FlutterMethodChannel(name: "de.inneso.familynexus/window", binaryMessenger: messenger)
    self.sharingType = .none // sichere Voreinstellung bis Dart etwas anderes wählt
    window.setMethodCallHandler { [weak self] call, result in
      if call.method == "setSecure" {
        let secure = (call.arguments as? Bool) ?? true
        self?.sharingType = secure ? .none : .readOnly
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }
}
