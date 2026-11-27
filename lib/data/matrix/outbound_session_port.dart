import 'package:matrix/matrix.dart';

/// Naht zur **Außensitzung** (Megolm) eines Raums, über die die App einen Schlüsselwisch nach einem Weggang auslöst und
/// belegt (#119, K4-2b, §3.3a). Das SDK 14.2.0 wischt nur eine **im Speicher liegende** Sitzung:
/// `clearOrUseOutboundGroupSession` gibt `true` zurück und tut nichts, wenn `getOutboundGroupSession(roomId) == null`
/// (`key_manager.dart:324-326`), und die Sitzung wird erst durch `loadOutboundGroupSession` aus der Datenbank in den
/// Speicher geholt (`:613-627`, einmal je Raum). Deshalb gilt der Ablauf **Laden, Wischen, Beleg** (`wipeOutbound` im
/// Gateway); der Rückgabewert des SDK ist **kein** Beleg.
abstract class OutboundSessionPort {
  /// Holt die persistierte Außensitzung des Raums in den Speicher (idempotent, wirft bei Fehlern).
  Future<void> load(String roomId);

  /// Nutzer, denen die Sitzung im **Speicher** Schlüssel gegeben hat (`null`: keine gültige Sitzung im Speicher). Nach einem
  /// Neustart ist das ohne [load] immer `null`.
  Set<String>? recipients(String roomId);

  /// Wischt die Sitzung im Speicher und in der Datenbank. Ein Rückgabewert existiert bewusst nicht: ob gewischt wurde,
  /// zeigt nur [recipients] danach.
  Future<void> wipe(String roomId);
}

/// Umsetzung über den Schlüsselverwalter des SDK. Die **einzige** Stelle in `lib/`, die `getOutboundGroupSession`,
/// `loadOutboundGroupSession` und `clearOrUseOutboundGroupSession` aufruft (Quelltextwächter in
/// `test/architecture_contacts_test.dart`).
///
/// Ohne Verschlüsselung im Client (`client.encryption == null`) gibt es in diesem Prozess keine Außensitzung; dann ist
/// [load] ohne Wirkung und [recipients] `null`. Ohne Konto oder ohne den Raum kann das SDK nicht laden
/// (`key_manager.dart:616-619`): das ist ein Fehler, kein „nichts zu wischen“.
class SdkOutboundSessionPort implements OutboundSessionPort {
  const SdkOutboundSessionPort(this._client);

  final Client _client;

  @override
  Future<void> load(String roomId) async {
    final km = _client.encryption?.keyManager;
    if (km == null) return;
    if (_client.userID == null || _client.getRoomById(roomId) == null) {
      throw StateError('Außensitzung kann nicht geladen werden');
    }
    await km.loadOutboundGroupSession(roomId);
  }

  @override
  Set<String>? recipients(String roomId) {
    final s = _client.encryption?.keyManager.getOutboundGroupSession(roomId);
    if (s == null || !s.isValid) return null;
    return s.devices.keys.toSet();
  }

  @override
  Future<void> wipe(String roomId) async {
    final km = _client.encryption?.keyManager;
    if (km == null) return;
    // Doppelt gesichert: das Laden steht vor dem Wisch im selben Funktionskörper (sonst wäre er ein stilles No-op).
    await km.loadOutboundGroupSession(roomId);
    await km.clearOrUseOutboundGroupSession(roomId, wipe: true);
  }
}
