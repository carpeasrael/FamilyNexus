import 'dart:async';

import 'package:flutter/services.dart';

import '../../core/app_log.dart';

/// Eingehende Einladungslinks (`familynexus://join?…`), z. B. nach dem Scannen eines
/// QR-Codes mit der System-Kamera. Android-Brücke hinter Schnittstelle; Inhalte sind
/// nicht vertrauenswürdig und werden erst in `InviteLink.tryParse` geprüft.
abstract class LinkSource {
  /// Link, mit dem die App gestartet wurde (einmalig).
  Future<String?> initialLink();

  /// Links, die bei laufender App eintreffen.
  Stream<String> get links;
}

class PlatformLinkSource implements LinkSource {
  PlatformLinkSource() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onLink' && call.arguments is String) {
        _controller.add(call.arguments as String);
      }
    });
  }

  static const MethodChannel _channel = MethodChannel('de.inneso.familynexus/links');
  // ignore: close_sinks
  final StreamController<String> _controller = StreamController<String>.broadcast();

  @override
  Future<String?> initialLink() async {
    try {
      return await _channel.invokeMethod<String>('getInitialLink');
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      AppLog.e('links', 'Startlink nicht lesbar', e);
      return null;
    }
  }

  @override
  Stream<String> get links => _controller.stream;
}
