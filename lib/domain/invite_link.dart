import 'dart:convert';

import 'server.dart';
import 'text_sanitizer.dart';

/// Einladungslink/QR-Inhalt (E-14, E-56, E-63, E-79):
/// `familynexus://join?v=4&d=<base64url ohne Padding>`, darin als UTF-8 die Felder
/// `room=<roomId>&via=<server>&srv=<server>&inv=<mxid>&exp=<unix-sekunden>[&by=<name>]&n=<id>`
/// (die Reihenfolge der Felder ist beim Lesen beliebig; `n` steht beim Erzeugen am Ende)
///
/// `d` ist eine Kodierung, keine Verschlüsselung: Sie verhindert beiläufiges Lesen und einfache
/// Stichwortsuche, wer den Link hat, kann ihn aber in Sekunden dekodieren (E-79).
///
/// Der Link ist nicht vertrauenswürdig: strikte Prüfung aller Felder. Die
/// Gültigkeitsdauer wird in der App durchgesetzt; die eigentliche Sperre ist
/// die Bestätigung durch einen Moderator.
///
/// `via` ist der Server des Raums, `srv` der Server, auf dem Neulinge ihr Konto anlegen bzw. sich anmelden
/// (standardmäßig der Heimserver des Einladenden). Weiterhin gelesen werden Version 3 (Felder im Klartext,
/// zusätzlich `f=<familie>`), Version 2 (ohne `srv`; dann gilt der Server des Einladenden) und Version 1
/// (ohne `f`/`by`). Familien- und Einladendenname sind reine Anzeigehilfen für Neulinge, die vor der
/// Anmeldung noch nichts vom Server abfragen können; sie werden bereinigt und nur als „laut Einladung“
/// gezeigt. Version 4 enthält keinen Familiennamen mehr.
class InviteLink {
  const InviteLink({
    required this.roomId,
    required this.via,
    required this.inviter,
    required this.expires,
    required this.nonce,
    this.familyName,
    this.inviterName,
    this.onLocalServer = false,
    this._accountServer,
  });

  static const String scheme = 'familynexus';
  static const String host = 'join';
  static const int version = 4;
  static const int maxLength = 1024;
  static const int maxNameLength = 40;
  /// Standard und Auswahl beim Einladen (Issue #6): Einladungen werden oft erst am nächsten Tag geöffnet.
  static const Duration defaultValidity = Duration(days: 3);
  static const List<Duration> validityChoices = <Duration>[Duration(days: 1), Duration(days: 3), Duration(days: 7)];
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

  /// Familienname laut Einladung (bereinigt, nicht vertrauenswürdig), `null` bei Version 1 und 4.
  final String? familyName;

  /// Anzeigename des Einladenden laut Einladung (bereinigt, nicht vertrauenswürdig).
  final String? inviterName;

  /// Die Familie liegt auf einem Server im Heimnetz (IP, `localhost`, Name ohne Punkt), der vor der
  /// Anmeldung nicht als eigener Server bekannt ist. Nur über [check] möglich; die Oberfläche warnt
  /// deutlich (Issue #6).
  final bool onLocalServer;

  final String? _accountServer;

  /// Server für Konto und Anmeldung laut Einladung (Feld `srv`); bei älteren Links der Server des
  /// Einladenden. Wird in der Einrichtung vorgewählt: `matrix.org` als Standard, jeder andere Server
  /// im Feld „Anderer Anbieter“ (E-63).
  String get accountServer => _accountServer ?? inviterServer;

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
    if (!_viaIsRoomServer(roomId, via)) return false;
    if (ownHost != null && ownHost == via) return true;
    return !isLocalServer(via);
  }

  static bool _viaIsRoomServer(String roomId, String via) {
    final i = roomId.indexOf(':');
    return i >= 0 && roomId.substring(i + 1) == via;
  }

  /// Server im Heimnetz: `localhost`, IP-Adresse, Name ohne Punkt (z. B. `nas`) oder eine nur lokal
  /// übliche Endung (`fritz.box`, `nas.local`, `*.lan`, `*.home.arpa`, `*.internal`, `*.localdomain`).
  static bool isLocalServer(String via) {
    final host = (via.contains(':') ? via.substring(0, via.lastIndexOf(':')) : via).toLowerCase();
    if (host == 'localhost' || host.endsWith('.localhost')) return true;
    if (RegExp(r'^[0-9.]+$').hasMatch(host)) return true;
    if (_localSuffixes.any(host.endsWith)) return true;
    return !host.contains('.');
  }

  static const List<String> _localSuffixes = <String>['.local', '.lan', '.home.arpa', '.internal', '.box', '.localdomain'];

  static final RegExp _viaRe = RegExp(r'^[A-Za-z0-9.\-]{1,253}(:\d{1,5})?$');

  /// Bereinigter Anzeigename oder `null`, wenn danach nichts übrig bleibt.
  static String? _name(String? raw) {
    if (raw == null) return null;
    final c = TextSanitizer.clean(raw, max: maxNameLength);
    return c.isEmpty ? null : c;
  }

  /// Landingpage für Einladungen als https-Link (E-68): Mail-Programme machen `familynexus://` oft nicht
  /// anklickbar. Die Angaben stehen im Fragment und gehen damit nie an den Server der Seite.
  static const String landingPage = 'https://carpeasrael.github.io/FamilyNexus/join/';

  /// Anklickbare Form eines App-Links ([create]); `null`, wenn [appLink] kein Einladungslink ist.
  static String? toWebLink(String appLink) {
    const prefix = '$scheme://$host?';
    if (!appLink.startsWith(prefix)) return null;
    return '$landingPage#${appLink.substring(prefix.length)}';
  }

  static final RegExp _webLink = RegExp('${RegExp.escape(landingPage)}?#', caseSensitive: false);

  /// App-Link mit `#` statt `?` (so steht er hinter der Landingpage; beim Kopieren aus der Adresszeile
  /// entsteht `familynexus://join#…`). Die Angaben sind dieselben (#59).
  static final RegExp _appLinkFragment = RegExp('$scheme://$host/?#', caseSensitive: false);

  /// Erzeugt den Link-Text. Wirft [ArgumentError] bei ungültigen Angaben und wenn der Link auch ohne
  /// Namen länger als [maxLength] wäre (extrem lange Servernamen).
  static String create({
    required String roomId,
    required String via,
    required String inviter,
    required DateTime now,
    required String nonce,
    Duration validity = defaultValidity,
    String? ownHost,
    String? inviterName,
    String? accountServer,
  }) {
    if (!MatrixIds.isRoomId(roomId) || !_viaRe.hasMatch(via) || !MatrixIds.isUserId(inviter) || !isNonce(nonce)) {
      throw ArgumentError('ungültige Einladungsdaten');
    }
    final srv = accountServer ?? inviter.substring(inviter.indexOf(':') + 1);
    if (!_viaRe.hasMatch(srv)) throw ArgumentError('ungültiger Konto-Server');
    if (isLocalServer(srv) && srv != ownHost) throw ArgumentError('Konto-Server im Heimnetz ist nicht der eigene');
    if (validity <= Duration.zero || validity > maxValidity) throw ArgumentError('ungültige Gültigkeitsdauer');
    if (!viaMatchesRoom(roomId, via, ownHost: ownHost)) throw ArgumentError('Server passt nicht zum Raum');
    final exp = now.toUtc().add(validity).millisecondsSinceEpoch ~/ 1000;
    String build(String? by) {
      final inner = Uri(
        queryParameters: <String, String>{
          'room': roomId,
          'via': via,
          'srv': srv,
          'inv': inviter,
          'exp': '$exp',
          'by': ?by,
          // Zuletzt: Wird der Link beim Weitergeben abgeschnitten, trifft es die Zufalls-ID fester
          // Länge, und der Link gilt als beschädigt statt mit gekürztem Namen angenommen zu werden (#26).
          'n': nonce,
        },
      ).query;
      final payload = base64Url.encode(utf8.encode(inner)).replaceAll('=', '');
      return '$scheme://$host?v=$version&d=$payload';
    }
    var by = _name(inviterName);
    // Der Name ist nur eine Anzeigehilfe: lieber kürzen bzw. weglassen, als einen zu langen Link zu
    // erzeugen (z. B. viele Emoji, die prozentkodiert je 12 Zeichen belegen).
    var link = build(by);
    while (link.length > maxLength && by != null) {
      by = _shorten(by);
      link = build(by);
    }
    if (link.length > maxLength) throw ArgumentError('Einladungslink zu lang');
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
  static const Set<String> _v3Keys = <String>{..._v2Keys, 'srv'};
  static const Set<String> _v4Keys = <String>{'v', 'd'};

  /// Felder in `d`: ohne `f` und ohne `v`, damit das Innere nicht auf Version 1/2 ohne `srv`-Pflicht zurückfällt.
  static const Set<String> _v4InnerKeys = <String>{'room', 'via', 'srv', 'inv', 'exp', 'by', 'n'};
  static final RegExp _payloadRe = RegExp(r'^[A-Za-z0-9_-]+$');

  /// Liest einen Link. Liefert `null` bei jeder Abweichung (falsches Schema,
  /// fehlende/doppelte/zusätzliche Felder, ungültige Werte). Ob der Link
  /// abgelaufen ist, prüft [isValidAt].
  static InviteLink? tryParse(String input, {required DateTime now, String? ownHost}) =>
      _parse(input, now: now, ownHost: ownHost, allowLocal: false);

  static InviteLink? _parse(String input, {required DateTime now, String? ownHost, required bool allowLocal}) {
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
    var q = <String, String>{for (final e in all.entries) e.key: e.value.single};
    final linkVersion = q['v'];
    final allowed = switch (linkVersion) {
      '1' => _v1Keys,
      '2' => _v2Keys,
      '3' => _v3Keys,
      '4' => _v4Keys,
      _ => null,
    };
    if (allowed == null || q.keys.toSet().difference(allowed).isNotEmpty) return null;
    if (linkVersion == '4') {
      final inner = _decodePayload(q['d']);
      if (inner == null) return null;
      q = inner;
    }
    final room = q['room'];
    final via = q['via'];
    final inv = q['inv'];
    final exp = int.tryParse(q['exp'] ?? '');
    final nonce = q['n'];
    if (room == null || via == null || inv == null || exp == null || nonce == null) return null;
    if (!isNonce(nonce)) return null;
    // Ab Version 3 steht der Server für Konto und Anmeldung ausdrücklich im Link (E-63); er muss gültig sein
    // und darf nur über [check] oder als eigener Server im Heimnetz liegen.
    final srv = q['srv'];
    if (linkVersion == '3' || linkVersion == '4') {
      if (srv == null || !_viaRe.hasMatch(srv)) return null;
      if (isLocalServer(srv) && srv != ownHost && !allowLocal) return null;
    }
    var local = false;
    if (!viaMatchesRoom(room, via, ownHost: ownHost)) {
      // Heimnetz-Server nur über [check] und nur, wenn er wirklich der Server des Raums ist.
      if (!allowLocal || !_viaIsRoomServer(room, via) || !isLocalServer(via)) return null;
      local = true;
    }
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
      onLocalServer: local,
      accountServer: srv,
    );
  }

  /// Felder aus `d` (Version 4) oder `null` bei jeder Abweichung: streng dekodiert, nur [_v4InnerKeys],
  /// keine doppelten. Gelesen über `Uri(query:)`, damit ein `#` im Inneren nichts abschneidet.
  static Map<String, String>? _decodePayload(String? d) {
    if (d == null || !_payloadRe.hasMatch(d) || d.length % 4 == 1) return null;
    final Map<String, List<String>> all;
    try {
      final inner = utf8.decode(base64Url.decode(base64Url.normalize(d)));
      all = Uri(query: inner).queryParametersAll;
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    }
    if (all.values.any((v) => v.length != 1)) return null;
    if (all.keys.toSet().difference(_v4InnerKeys).isNotEmpty) return null;
    return <String, String>{for (final e in all.entries) e.key: e.value.single};
  }

  bool isValidAt(DateTime now) => now.toUtc().isBefore(expires);

  /// Prüft eingefügten oder geöffneten Text und nennt bei Ablehnung den Grund (Issue #6). Anders als
  /// [tryParse] löst sie den Link aus umgebendem Text und repariert typische Schäden beim Weitergeben;
  /// der Inhalt selbst wird genauso streng geprüft. Links auf Server im Heimnetz werden angenommen und
  /// mit [onLocalServer] markiert.
  static InviteLinkCheck check(String input, {required DateTime now, String? ownHost}) {
    final candidates = _candidates(input);
    if (candidates.isEmpty) return const InviteLinkCheck._(problem: InviteLinkProblem.notALink);
    // Mehrere Fundstellen (z. B. alter und neuer Link in einer Mail): der erste gültige gewinnt; sonst der
    // aussagekräftigste Grund (neuere Version vor abgelaufen vor beschädigt).
    InviteLinkCheck? best;
    for (final c in candidates) {
      final result = _checkOne(c, now: now, ownHost: ownHost);
      if (result.ok) return result;
      if (best == null || result.problem!.index > best.problem!.index) best = result;
    }
    return best!;
  }

  static InviteLinkCheck _checkOne(String candidate, {required DateTime now, String? ownHost}) {
    final v = _versionOf(candidate);
    if (v != null && v > version) return const InviteLinkCheck._(problem: InviteLinkProblem.newerVersion);
    final link = _parse(candidate, now: now, ownHost: ownHost, allowLocal: true);
    if (link == null) return const InviteLinkCheck._(problem: InviteLinkProblem.damaged);
    if (!link.isValidAt(now)) return InviteLinkCheck._(link: link, problem: InviteLinkProblem.expired);
    return InviteLinkCheck._(link: link, raw: normalized(candidate));
  }

  static int? _versionOf(String candidate) {
    try {
      return int.tryParse(Uri.parse(candidate).queryParameters['v'] ?? '');
    } on FormatException {
      return null;
    }
  }

  static final RegExp _start = RegExp('$scheme://$host', caseSensitive: false);
  static final RegExp _qpHex = RegExp('=([0-9A-F]{2})');
  static final RegExp _trailing = RegExp('[>"\'\u201C\u201D\u201E\u00AB\u00BB)\\].,;:!?]+\$');
  static final RegExp _v4Start = RegExp('^$scheme://$host\\?v=4&d=', caseSensitive: false);

  /// Höchstens so viele Stücke werden an einen umbrochenen Payload angehängt.
  static const int _maxPayloadPieces = 32;

  /// Längste Eingabe, die durchsucht wird (weitergeleitete Mails mit Zitat und Signatur passen hinein).
  static const int maxInput = 65536;

  /// Erster Kandidat aus [_candidates] (für Anzeige und Tests); `null`, wenn kein Link enthalten ist.
  static String? extract(String input) {
    final c = _candidates(input);
    return c.isEmpty ? null : c.first;
  }

  /// Mögliche Links in einem Text (Mail, Messenger, Notiz), in der Reihenfolge, in der sie versucht werden.
  /// Repariert, was beim Weitergeben typischerweise passiert: HTML-`&amp;`, Zeilenumbrüche mitten im Link,
  /// Klammern, Anführungszeichen und Satzzeichen am Ende. Ein umbrochener Payload (Version 4) hat keine
  /// Trennzeichen; dort werden die folgenden Stücke schrittweise als weitere Kandidaten versucht. Fremdtext
  /// macht den Link dabei ungültig, weil `n` am Ende feste Länge hat. Quoted-Printable (`=3D`, `=` am Zeilenende)
  /// wird **nur zusätzlich** versucht – ein unveränderter Link geht immer vor, damit Namen wie „3D-Club“
  /// nie verfälscht werden (Review R1). Ein Satzzeichen am Ende eines Namens kann dabei wegfallen.
  static List<String> _candidates(String input) {
    // Der https-Link der Landingpage trägt dieselben Angaben im Fragment; er wird wie der App-Link geprüft.
    final text = (input.length > maxInput ? input.substring(0, maxInput) : input)
        .replaceAll('&amp;', '&')
        .replaceAll(_webLink, '$scheme://$host?')
        .replaceAll(_appLinkFragment, '$scheme://$host?');
    final variants = <String>[text];
    if (text.contains('=3D') || RegExp(r'=\r?\n').hasMatch(text)) {
      variants.add(text
          .replaceAll(RegExp(r'=\r?\n'), '')
          .replaceAllMapped(_qpHex, (m) => String.fromCharCode(int.parse(m[1]!, radix: 16))));
    }
    final out = <String>[];
    for (final t in variants) {
      for (final m in _start.allMatches(t).take(5)) {
        final end = m.start + maxLength * 3 < t.length ? m.start + maxLength * 3 : t.length;
        final parts = t.substring(m.start, end).split(RegExp(r'\s+'));
        final buf = StringBuffer(parts.first);
        // Ein Umbruch mitten im Link: weiter, solange das Stück davor mit `=`/`&` endet oder das nächste mit `&` beginnt.
        var next = 1;
        for (; next < parts.length; next++) {
          final p = parts[next];
          final prev = buf.toString();
          if (p.isEmpty || !(prev.endsWith('=') || prev.endsWith('&') || p.startsWith('&'))) break;
          buf.write(p);
        }
        final raw = buf.toString();
        if (raw.length > maxLength * 2) continue;
        for (final c in <String>[raw.replaceFirst(_trailing, ''), raw]) {
          if (c.isNotEmpty && c.length <= maxLength && !out.contains(c)) out.add(c);
        }
        if (!_v4Start.hasMatch(raw) || _trailing.hasMatch(raw)) continue;
        var joined = raw;
        for (final p in parts.skip(next).take(_maxPayloadPieces)) {
          final piece = p.replaceFirst(_trailing, '');
          if (!_payloadRe.hasMatch(piece)) break;
          joined += piece;
          if (joined.length > maxLength) break;
          if (!out.contains(joined)) out.add(joined);
          // Ein Schlusszeichen beendet den Link.
          if (piece.length != p.length) break;
        }
      }
    }
    return out;
  }

  /// Einheitliche Schreibweise eines (bereits geprüften) Links zum Vormerken, z. B. Schema in
  /// Kleinbuchstaben; ein Neustart liest ihn mit [check] erneut (auch Links auf Heimnetz-Servern).
  static String normalized(String raw) {
    try {
      return Uri.parse(raw.trim()).toString();
    } on FormatException {
      return raw.trim();
    }
  }
}

/// Grund, warum ein Text nicht als Einladung angenommen wird (Issue #6).
enum InviteLinkProblem {
  /// Kein Einladungslink im Text.
  notALink,

  /// Link unvollständig oder beschädigt (oder manipuliert).
  damaged,

  /// Gültigkeit abgelaufen.
  expired,

  /// Link aus einer neueren App-Version.
  newerVersion,
}

/// Ergebnis von [InviteLink.check]: gültiger Link oder Grund der Ablehnung (bei `expired` mit Link).
class InviteLinkCheck {
  const InviteLinkCheck._({this.link, this.problem, this.raw});

  final InviteLink? link;
  final InviteLinkProblem? problem;

  /// Der herausgelöste, einheitlich geschriebene Link (zum Vormerken), nur bei gültigem Ergebnis.
  final String? raw;

  bool get ok => problem == null && link != null;
}
