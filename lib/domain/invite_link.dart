import 'server.dart';
import 'text_sanitizer.dart';

/// Einladungslink/QR-Inhalt (E-14, E-56):
/// `familynexus://join?v=2&room=<roomId>&via=<server>&inv=<mxid>&exp=<unix-sekunden>&n=<id>[&f=<familie>][&by=<name>]`
///
/// Der Link ist nicht vertrauenswürdig: strikte Prüfung aller Felder. Die
/// Gültigkeitsdauer wird in der App durchgesetzt; die eigentliche Sperre ist
/// die Bestätigung durch einen Moderator.
///
/// Version 1 (ohne `f`/`by`) wird weiterhin gelesen. Familien- und Einladendenname sind reine
/// Anzeigehilfen für Neulinge, die vor der Anmeldung noch nichts vom Server abfragen können; sie
/// werden bereinigt und nur als „laut Einladung“ gezeigt.
class InviteLink {
  const InviteLink({
    required this.roomId,
    required this.via,
    required this.inviter,
    required this.expires,
    required this.nonce,
    this.familyName,
    this.inviterName,
  });

  static const String scheme = 'familynexus';
  static const String host = 'join';
  static const int version = 2;
  static const int maxLength = 1024;
  static const int maxNameLength = 40;
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

  /// Familienname laut Einladung (bereinigt, nicht vertrauenswürdig), `null` bei Version 1.
  final String? familyName;

  /// Anzeigename des Einladenden laut Einladung (bereinigt, nicht vertrauenswürdig).
  final String? inviterName;

  /// Servername des Einladenden (`@anna:beispiel.de` → `beispiel.de`). Neulinge legen ihr Konto
  /// standardmäßig dort an; die Adresse wird wie jede Eingabe über `.well-known` aufgelöst.
  String get inviterServer => inviter.substring(inviter.indexOf(':') + 1);

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

  /// Bereinigter Anzeigename oder `null`, wenn danach nichts übrig bleibt.
  static String? _name(String? raw) {
    if (raw == null) return null;
    final c = TextSanitizer.clean(raw, max: maxNameLength);
    return c.isEmpty ? null : c;
  }

  /// Erzeugt den Link-Text.
  static String create({
    required String roomId,
    required String via,
    required String inviter,
    required DateTime now,
    required String nonce,
    Duration validity = defaultValidity,
    String? ownHost,
    String? familyName,
    String? inviterName,
  }) {
    if (!MatrixIds.isRoomId(roomId) || !_viaRe.hasMatch(via) || !MatrixIds.isUserId(inviter) || !isNonce(nonce)) {
      throw ArgumentError('ungültige Einladungsdaten');
    }
    if (validity <= Duration.zero || validity > maxValidity) throw ArgumentError('ungültige Gültigkeitsdauer');
    if (!viaMatchesRoom(roomId, via, ownHost: ownHost)) throw ArgumentError('Server passt nicht zum Raum');
    final exp = now.toUtc().add(validity).millisecondsSinceEpoch ~/ 1000;
    String build(String? f, String? by) => Uri(
          scheme: scheme,
          host: host,
          queryParameters: <String, String>{
            'v': '$version',
            'room': roomId,
            'via': via,
            'inv': inviter,
            'exp': '$exp',
            'n': nonce,
            'f': ?f,
            'by': ?by,
          },
        ).toString();
    var f = _name(familyName);
    var by = _name(inviterName);
    // Namen sind nur Anzeigehilfen: lieber kürzen bzw. weglassen, als einen zu langen Link zu erzeugen
    // (z. B. viele Emoji, die prozentkodiert je 12 Zeichen belegen).
    var link = build(f, by);
    while (link.length > maxLength && (f != null || by != null)) {
      if (by != null) {
        by = _shorten(by);
      } else {
        f = _shorten(f!);
      }
      link = build(f, by);
    }
    return link;
  }

  /// Halbiert einen Namen (in Zeichen); `null`, wenn nichts übrig bleibt.
  static String? _shorten(String s) {
    final runes = s.runes.toList();
    if (runes.length <= 1) return null;
    return _name(String.fromCharCodes(runes.take(runes.length ~/ 2)));
  }

  static const Set<String> _v1Keys = <String>{'v', 'room', 'via', 'inv', 'exp', 'n'};
  static const Set<String> _v2Keys = <String>{..._v1Keys, 'f', 'by'};

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
    final allowed = switch (q['v']) {
      '1' => _v1Keys,
      '2' => _v2Keys,
      _ => null,
    };
    if (allowed == null || q.keys.toSet().difference(allowed).isNotEmpty) return null;
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
    return InviteLink(
      roomId: room,
      via: via,
      inviter: inv,
      expires: expires,
      nonce: nonce,
      familyName: _name(q['f']),
      inviterName: _name(q['by']),
    );
  }

  bool isValidAt(DateTime now) => now.toUtc().isBefore(expires);

  /// Einheitliche Schreibweise eines (bereits geprüften) Links zum Vormerken, z. B. Schema in
  /// Kleinbuchstaben; ein Neustart liest ihn mit [tryParse] erneut.
  static String normalized(String raw) {
    try {
      return Uri.parse(raw.trim()).toString();
    } on FormatException {
      return raw.trim();
    }
  }
}
