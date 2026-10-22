import 'server.dart';

/// Einladungslink/QR-Inhalt (E-14):
/// `familynexus://join?v=1&room=<roomId>&via=<server>&inv=<mxid>&exp=<unix-sekunden>`
///
/// Der Link ist nicht vertrauenswürdig: strikte Prüfung aller Felder. Die
/// Gültigkeitsdauer wird in der App durchgesetzt; die eigentliche Sperre ist
/// die Bestätigung durch einen Moderator.
class InviteLink {
  const InviteLink({
    required this.roomId,
    required this.via,
    required this.inviter,
    required this.expires,
    required this.nonce,
  });

  static const String scheme = 'familynexus';
  static const String host = 'join';
  static const int version = 1;
  static const int maxLength = 512;
  static const Duration defaultValidity = Duration(hours: 24);
  static const Duration maxValidity = Duration(days: 7);

  final String roomId;

  /// Server, über den der Raum erreichbar ist (Hostname, optional Port).
  final String via;

  /// Matrix-ID des einladenden Moderators.
  final String inviter;
  final DateTime expires;

  /// Zufalls-ID (hex), die der Moderator beim Erzeugen vermerkt; nur Anfragen mit
  /// bekannter, unverbrauchter ID werden bestätigt (S2).
  final String nonce;

  static final RegExp _nonceRe = RegExp(r'^[0-9a-f]{32}$');

  static bool isNonce(String s) => _nonceRe.hasMatch(s);

  /// Der Server muss zur Raum-ID passen und darf keine IP-Adresse/kein localhost sein (S8).
  ///
  /// [ownHost] ist der Server des eigenen Kontos; er ist von der Ortsprüfung ausgenommen
  /// (eigener Server im Heimnetz).
  static bool viaMatchesRoom(String roomId, String via, {String? ownHost}) {
    final i = roomId.indexOf(':');
    if (i < 0 || roomId.substring(i + 1) != via) return false;
    if (ownHost != null && ownHost == via) return true;
    final host = via.contains(':') ? via.substring(0, via.lastIndexOf(':')) : via;
    if (host == 'localhost' || host.endsWith('.localhost')) return false;
    if (RegExp(r'^[0-9.]+$').hasMatch(host)) return false;
    return host.contains('.');
  }

  static final RegExp _viaRe = RegExp(r'^[A-Za-z0-9.\-]{1,253}(:\d{1,5})?$');

  /// Erzeugt den Link-Text.
  static String create({
    required String roomId,
    required String via,
    required String inviter,
    required DateTime now,
    required String nonce,
    Duration validity = defaultValidity,
    String? ownHost,
  }) {
    if (!MatrixIds.isRoomId(roomId) || !_viaRe.hasMatch(via) || !MatrixIds.isUserId(inviter) || !isNonce(nonce)) {
      throw ArgumentError('ungültige Einladungsdaten');
    }
    if (validity <= Duration.zero || validity > maxValidity) throw ArgumentError('ungültige Gültigkeitsdauer');
    if (!viaMatchesRoom(roomId, via, ownHost: ownHost)) throw ArgumentError('Server passt nicht zum Raum');
    final exp = now.toUtc().add(validity).millisecondsSinceEpoch ~/ 1000;
    return Uri(
      scheme: scheme,
      host: host,
      queryParameters: <String, String>{
        'v': '$version',
        'room': roomId,
        'via': via,
        'inv': inviter,
        'exp': '$exp',
        'n': nonce,
      },
    ).toString();
  }

  /// Liest einen Link. Liefert `null` bei jeder Abweichung (falsches Schema,
  /// fehlende/doppelte/zusätzliche Felder, ungültige Werte). Ob der Link
  /// abgelaufen ist, prüft [isValidAt].
  static InviteLink? tryParse(String input, {required DateTime now, String? ownHost}) {
    final text = input.trim();
    if (text.isEmpty || text.length > maxLength) return null;
    final Uri u;
    try {
      u = Uri.parse(text);
    } on FormatException {
      return null;
    }
    if (u.scheme != scheme || u.host != host || u.userInfo.isNotEmpty || u.hasPort || u.hasFragment) return null;
    if (u.path.isNotEmpty && u.path != '/') return null;
    // Doppelte Parameter ablehnen (mehrdeutig).
    final Map<String, List<String>> all;
    try {
      all = u.queryParametersAll;
    } on FormatException {
      // Ungültige Prozentkodierung (z. B. "%A"): der Zugriff dekodiert erst hier und würde sonst werfen.
      return null;
    }
    if (all.values.any((v) => v.length != 1)) return null;
    final q = <String, String>{for (final e in all.entries) e.key: e.value.single};
    if (q.keys.toSet().difference(const <String>{'v', 'room', 'via', 'inv', 'exp', 'n'}).isNotEmpty) return null;
    if (q['v'] != '$version') return null;
    final room = q['room'];
    final via = q['via'];
    final inv = q['inv'];
    final exp = int.tryParse(q['exp'] ?? '');
    final nonce = q['n'];
    if (room == null || via == null || inv == null || exp == null || nonce == null) return null;
    if (!isNonce(nonce) || !viaMatchesRoom(room, via, ownHost: ownHost)) return null;
    // Grenzen vorab prüfen: zu große Werte würden sonst beim Umrechnen werfen (K1).
    final nowSec = now.toUtc().millisecondsSinceEpoch ~/ 1000;
    if (exp <= 0 || exp > nowSec + maxValidity.inSeconds + 300) return null;
    if (!MatrixIds.isRoomId(room) || !_viaRe.hasMatch(via) || !MatrixIds.isUserId(inv)) return null;
    final expires = DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
    // Unplausibel weit in der Zukunft = manipuliert.
    if (expires.isAfter(now.toUtc().add(maxValidity + const Duration(minutes: 5)))) return null;
    return InviteLink(roomId: room, via: via, inviter: inv, expires: expires, nonce: nonce);
  }

  bool isValidAt(DateTime now) => now.toUtc().isBefore(expires);
}
