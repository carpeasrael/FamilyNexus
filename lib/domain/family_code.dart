import 'server.dart';

/// Familien-Code: die Raum-ID der Familie (`!kennung:server`), mit der man ohne Einladungslink anklopfen kann (E-65).
///
/// Der Code ist kein Geheimnis und gibt keinen Zutritt; ein Moderator muss die Anfrage ausdrücklich bestätigen.
class FamilyCode {
  const FamilyCode._();

  /// Liest eine eingegebene oder eingefügte Raum-ID; `null`, wenn sie nicht wie eine aussieht.
  static String? parse(String input) {
    final s = input.trim();
    if (!MatrixIds.isRoomId(s)) return null;
    return ServerUrl.tryParse(serverOf(s)) == null ? null : s;
  }

  /// Server-Teil der Raum-ID.
  static String serverOf(String roomId) => roomId.substring(roomId.indexOf(':') + 1);
}
