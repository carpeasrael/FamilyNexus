import 'invite_link.dart';

/// Vermerk eines ausgegebenen Einladungslinks im (verschlüsselten) Familienraum (E-49).
///
/// Damit kann **jeder** Moderator eine Beitrittsanfrage mit einem Link prüfen, den ein anderer Moderator
/// ausgegeben hat – bisher kannte nur der Aussteller die Link-ID. Der Vermerk enthält nur die Link-ID und
/// den Ablauf, nie Namen oder Inhalte. Empfänger akzeptieren ihn nur, wenn der Absender Moderator ist.
class InviteTicket {
  const InviteTicket({required this.nonce, required this.expires, this.used = false, this.auto = false});

  static const String type = 'de.inneso.familynexus.invite';
  static const int version = 1;

  /// Link-ID (32 Hex-Zeichen), siehe [InviteLink.nonce].
  final String nonce;

  /// Ablauf in Unix-Sekunden.
  final int expires;

  /// Der Link wurde durch eine bestätigte Anfrage verbraucht.
  final bool used;

  /// Eine Anfrage mit diesem Link wird von der App eines Moderators ohne Rückfrage bestätigt (Einladung ohne
  /// weitere Verifizierung). Fehlt das Feld (ältere Vermerke), bleibt die Bestätigung manuell.
  final bool auto;

  Map<String, Object?> encode() => <String, Object?>{'v': version, 'n': nonce, 'exp': expires, if (used) 'used': true, if (auto) 'auto': true};

  /// Liest einen Vermerk streng; `null` bei fehlenden, zusätzlichen oder ungültigen Feldern.
  static InviteTicket? decode(Map<String, Object?> content, {required int nowSeconds}) {
    const allowed = <String>{'v', 'n', 'exp', 'used', 'auto'};
    if (content.keys.any((k) => !allowed.contains(k))) return null;
    if (content['v'] != version) return null;
    final n = content['n'];
    final exp = content['exp'];
    final used = content['used'];
    final auto = content['auto'];
    if (n is! String || !InviteLink.isNonce(n) || exp is! int) return null;
    if (used != null && used is! bool) return null;
    if (auto != null && auto is! bool) return null;
    // Unplausible Ablaufzeiten (zu weit in der Zukunft) sind manipuliert.
    if (exp <= 0 || exp > nowSeconds + InviteLink.maxValidity.inSeconds + 300) return null;
    return InviteTicket(nonce: n, expires: exp, used: used == true, auto: auto == true);
  }
}
