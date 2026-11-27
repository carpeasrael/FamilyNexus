import 'dart:convert';

import 'server.dart';
import 'text_sanitizer.dart';

/// Technische Sperre der Kontakte außerhalb der Familie (#119, E-114). Bis zur Freigabe `false`: Es entstehen weder
/// Dienst noch Synchronisation, der Kontaktspeicher bleibt in der Produktion leer (nur die Wipe-Pfade greifen auf ihn zu).
class ContactFlags {
  const ContactFlags._();
  static const bool enabled = false;
}

/// Grenzen der Kontakte außerhalb der Familie (#119, E-114). Alle Werte stützen die Annahme im Codec und im Dienst.
class ContactLimits {
  const ContactLimits._();

  /// Aktive Kontakte (angefragt, bestätigt oder blockiert, ohne Löschmarken).
  static const int maxContacts = 500;
  static const int maxGroups = 50;

  /// Alle Zeilen der Ablage **einschließlich** Löschmarken (Schutz vor beliebig vielen verschiedenen Kennungen).
  static const int maxRecords = 2000;

  /// Mitglieder einer Gruppe (Konzept §5; wirksam ab K4).
  static const int maxGroupMembers = 50;

  /// Zeichen des Spitznamens.
  static const int maxNick = 40;

  static const int maxVersion = 0x7fffffff;

  /// Größter Versionssprung eines empfangenen Datensatzes über der gespeicherten Fassung desselben Schlüssels. Bei einem
  /// unbekannten Schlüssel gilt jede gültige Version (ein neues Gerät lädt die Liste vollständig).
  static const int maxVersionStep = 1000;

  /// Höchste Abweichung von `ts` gegenüber der Serverzeit des Ereignisses (Empfänger verwerfen darüber hinaus).
  static const Duration maxSkew = Duration(days: 2);

  /// Gesamtgröße des Ereignisinhalts (UTF-8 als JSON), geprüft **vor** dem Zerlegen.
  static const int maxContentBytes = 2048;

  /// Zahl der jüngsten **veröffentlichten** Löschmarken, die beim Aufräumen bleiben.
  static const int keepTombstones = 200;
}

/// Zustand eines Kontakts. `outgoing`: ich habe angefragt, die Gegenseite hat noch nicht beigetreten; `accepted`:
/// bestätigt; `blocked`: blockiert (bleibt unbeantwortet, der Absender erfährt nichts).
enum ContactState { outgoing, accepted, blocked }

/// Art des Datensatzes (`rec` im Ereignis).
enum ContactKind { contact, group, prefs }

/// Gemeinsame Felder der drei Datensatzarten. Der Schlüssel ist `(kind, id)`.
abstract class ContactRecord {
  const ContactRecord({required this.id, required this.version, required this.updatedAt, this.deleted = false});

  final String id;
  final int version;

  /// UTC, Millisekunden.
  final DateTime updatedAt;
  final bool deleted;

  ContactKind get kind;

  /// Leer = gültig. Nicht leer: Kürzel der verletzten Regeln.
  List<String> validate();

  /// Nur die Felder des Ereignisses (ohne `v`), zur Kodierung.
  Map<String, Object?> get fields;

  List<String> _common() {
    final p = <String>[];
    if (version < 1 || version > ContactLimits.maxVersion) p.add('version');
    if (updatedAt.millisecondsSinceEpoch.abs() > 8640000000000000) p.add('ts');
    return p;
  }

  @override
  String toString() => '$runtimeType($id, v$version${deleted ? ', gelöscht' : ''})';
}

class Contact extends ContactRecord {
  const Contact({
    required super.id,
    required this.state,
    required super.version,
    required super.updatedAt,
    this.nick = '',
    this.room,
    super.deleted,
  });

  final ContactState state;
  final String nick;

  /// Raum des Einzelchats (bekannt, sobald angelegt oder angenommen).
  final String? room;

  @override
  ContactKind get kind => ContactKind.contact;

  @override
  List<String> validate() {
    final p = _common();
    if (ContactId.parse(id) != id) p.add('id');
    if (!_nickOk(nick)) p.add('nick');
    final r = room;
    if (r != null && !MatrixIds.isRoomId(r)) p.add('room');
    return p;
  }

  Contact copyWith({ContactState? state, String? nick, Object? room = _keep, int? version, DateTime? updatedAt, bool? deleted}) => Contact(
        id: id,
        state: state ?? this.state,
        nick: nick ?? this.nick,
        room: identical(room, _keep) ? this.room : room as String?,
        version: version ?? this.version,
        updatedAt: updatedAt ?? this.updatedAt,
        deleted: deleted ?? this.deleted,
      );

  @override
  Map<String, Object?> get fields => <String, Object?>{
        'rec': 'contact',
        'id': id,
        'state': state.name,
        'nick': nick,
        if (room != null) 'room': room,
        'ver': version,
        'ts': updatedAt.millisecondsSinceEpoch,
        'del': deleted,
      };

  @override
  bool operator ==(Object other) =>
      other is Contact &&
      other.id == id &&
      other.state == state &&
      other.nick == nick &&
      other.room == room &&
      other.version == version &&
      other.updatedAt == updatedAt &&
      other.deleted == deleted;

  @override
  int get hashCode => Object.hash(id, state, nick, room, version, updatedAt, deleted);
}

const Object _keep = Object();

/// Eine Gruppe (Raum), die ich als Kontaktgruppe führe (wirksam ab K4).
class GroupRecord extends ContactRecord {
  const GroupRecord({required super.id, required super.version, required super.updatedAt, super.deleted});

  @override
  ContactKind get kind => ContactKind.group;

  @override
  List<String> validate() {
    final p = _common();
    if (!MatrixIds.isRoomId(id)) p.add('id');
    return p;
  }

  GroupRecord copyWith({int? version, DateTime? updatedAt, bool? deleted}) => GroupRecord(
        id: id,
        version: version ?? this.version,
        updatedAt: updatedAt ?? this.updatedAt,
        deleted: deleted ?? this.deleted,
      );

  @override
  Map<String, Object?> get fields => <String, Object?>{'rec': 'group', 'id': id, 'ver': version, 'ts': updatedAt.millisecondsSinceEpoch, 'del': deleted};

  @override
  bool operator ==(Object other) =>
      other is GroupRecord && other.id == id && other.version == version && other.updatedAt == updatedAt && other.deleted == deleted;

  @override
  int get hashCode => Object.hash(id, version, updatedAt, deleted);
}

/// Einstellung „Kontakte und Gruppen einschalten“ (Standard aus). Die Kennung ist immer [prefsId].
class ContactPrefs extends ContactRecord {
  const ContactPrefs({required this.enabled, required super.version, required super.updatedAt}) : super(id: prefsId);

  static const String prefsId = 'prefs';

  final bool enabled;

  @override
  ContactKind get kind => ContactKind.prefs;

  @override
  List<String> validate() => _common();

  ContactPrefs copyWith({bool? enabled, int? version, DateTime? updatedAt}) =>
      ContactPrefs(enabled: enabled ?? this.enabled, version: version ?? this.version, updatedAt: updatedAt ?? this.updatedAt);

  @override
  Map<String, Object?> get fields => <String, Object?>{
        'rec': 'prefs',
        'id': prefsId,
        'enabled': enabled,
        'ver': version,
        'ts': updatedAt.millisecondsSinceEpoch,
        'del': false,
      };

  @override
  bool operator ==(Object other) => other is ContactPrefs && other.enabled == enabled && other.version == version && other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(enabled, version, updatedAt);
}

/// Steuer-, Bidi- und Nullbreiten-Zeichen, die in Namen und Kennungen nie vorkommen dürfen.
final RegExp _forbidden = RegExp(r'[\u0000-\u001f\u007f-\u009f\u200b-\u200f\u2028\u2029\u202a-\u202e\u2066-\u2069\ufeff]');

/// Spitzname: nicht leer nach dem Bereinigen ist nicht verlangt (leer ist erlaubt), aber unverändert durch
/// [TextSanitizer], höchstens [ContactLimits.maxNick] Zeichen, ohne verbotene Zeichen.
bool _nickOk(String nick) {
  if (nick.runes.length > ContactLimits.maxNick) return false;
  if (_forbidden.hasMatch(nick)) return false;
  return TextSanitizer.clean(nick, max: 1000) == nick;
}

/// Eingabe einer Kontakt-Kennung: `@name:server` oder ein `matrix.to`-Link auf eine Nutzer-ID.
class ContactId {
  const ContactId._();

  /// Kanonische Nutzer-ID oder `null`. Der Servername wird kleingeschrieben, der lokale Teil bleibt unverändert.
  /// Links: nur `https://matrix.to/#/<id>` (Host genau `matrix.to`, kein Port, keine Zugangsdaten), die ID darf **einfach**
  /// prozent-kodiert sein; Parameter nach `?` (z. B. `via`) werden verworfen; Raum-IDs und Aliasse liefern `null`.
  static String? parse(String raw) {
    final input = raw.trim();
    if (input.isEmpty || input.length > 600 || _forbidden.hasMatch(input) || input.contains(RegExp(r'\s'))) return null;
    String candidate;
    if (input.startsWith('@')) {
      candidate = input;
    } else {
      final uri = Uri.tryParse(input);
      if (uri == null || uri.scheme != 'https' || uri.host != 'matrix.to' || uri.hasPort || uri.userInfo.isNotEmpty) return null;
      if (uri.path.isNotEmpty && uri.path != '/') return null;
      final fragment = uri.fragment;
      if (!fragment.startsWith('/')) return null;
      var target = fragment.substring(1);
      final q = target.indexOf('?');
      if (q >= 0) target = target.substring(0, q);
      if (target.contains('/')) return null;
      try {
        target = Uri.decodeComponent(target);
      } on FormatException {
        return null; // ungültige Prozent-Folge oder Byte-Folge
      } on ArgumentError {
        return null;
      }
      if (target.contains('%')) return null; // doppelt kodiert
      candidate = target;
    }
    if (_forbidden.hasMatch(candidate)) return null;
    final colon = candidate.indexOf(':');
    if (colon < 0) return null;
    final id = '${candidate.substring(0, colon)}:${candidate.substring(colon + 1).toLowerCase()}';
    return MatrixIds.isUserId(id) ? id : null;
  }
}

/// Ereignisformat (`de.inneso.familynexus.contact`, Schema 1), nur im privaten Raum und nur vom eigenen Konto.
class ContactCodec {
  const ContactCodec._();

  static const String type = 'de.inneso.familynexus.contact';
  static const int schema = 1;

  static Map<String, Object?> encode(ContactRecord r) {
    final problems = r.validate();
    if (problems.isNotEmpty) throw StateError('Ungültiger Kontaktdatensatz: ${problems.join(',')}');
    return <String, Object?>{'v': schema, ...r.fields};
  }

  /// Ereignis: `null` bei ungültigem Inhalt, fremdem Absender (nur das eigene Konto [me]; leer oder ungleich = ablehnen),
  /// übergroßem Inhalt oder `ts` mehr als [ContactLimits.maxSkew] neben [serverTime].
  static ContactRecord? decode(Map<String, Object?> c, {required String sender, required String me, required DateTime serverTime}) {
    if (me.isEmpty || sender != me || !MatrixIds.isUserId(sender)) return null;
    final r = _decode(c);
    if (r == null) return null;
    if (r.updatedAt.difference(serverTime.toUtc()).abs() > ContactLimits.maxSkew) return null;
    return r;
  }

  /// Lokale Ablage: dasselbe Format, ohne Absender- und Zeitprüfung.
  static ContactRecord? decodeStored(Map<String, Object?> c) => _decode(c);

  static ContactRecord? _decode(Map<String, Object?> c) {
    try {
      if (utf8.encode(json.encode(c)).length > ContactLimits.maxContentBytes) return null;
    } on JsonUnsupportedObjectError {
      return null; // nicht als JSON darstellbarer Inhalt
    }
    if (c['v'] != schema) return null;
    final rec = c['rec'];
    final id = c['id'];
    final ver = c['ver'];
    final ts = c['ts'];
    final del = c['del'];
    if (rec is! String || id is! String || ver is! int || ts is! int || del is! bool) return null;
    if (ts.abs() > 8640000000000000) return null;
    final at = DateTime.fromMillisecondsSinceEpoch(ts, isUtc: true);
    final ContactRecord r;
    switch (rec) {
      case 'contact':
        final state = c['state'];
        final nick = c['nick'];
        final room = c['room'];
        if (state is! String || nick is! String) return null;
        if (c.containsKey('room') && room is! String) return null;
        final s = ContactState.values.where((e) => e.name == state);
        if (s.isEmpty) return null;
        r = Contact(id: id, state: s.first, nick: nick, room: room as String?, version: ver, updatedAt: at, deleted: del);
      case 'group':
        r = GroupRecord(id: id, version: ver, updatedAt: at, deleted: del);
      case 'prefs':
        final enabled = c['enabled'];
        if (enabled is! bool || id != ContactPrefs.prefsId || del) return null;
        r = ContactPrefs(enabled: enabled, version: ver, updatedAt: at);
      default:
        return null;
    }
    return r.validate().isEmpty ? r : null;
  }
}

/// Konfliktregel für zwei Fassungen **desselben** Schlüssels `(kind, id)`: Totalordnung `(ver, ts, kanonische
/// Darstellung)`, die größere gewinnt (E-40, E-113). Alle Geräte konvergieren damit auf dieselbe Fassung.
class Contacts {
  const Contacts._();

  static String _canonical(ContactRecord r) {
    final m = r.fields;
    final keys = m.keys.toList()..sort();
    return json.encode(<String, Object?>{for (final k in keys) k: m[k]});
  }

  /// Positiv, wenn [a] gewinnt, negativ, wenn [b] gewinnt, 0 nur bei Gleichheit.
  static int compare(ContactRecord a, ContactRecord b) {
    final v = a.version.compareTo(b.version);
    if (v != 0) return v;
    final t = a.updatedAt.millisecondsSinceEpoch.compareTo(b.updatedAt.millisecondsSinceEpoch);
    if (t != 0) return t;
    return _canonical(a).compareTo(_canonical(b));
  }

  static bool supersedes(ContactRecord a, ContactRecord b) => compare(a, b) > 0;
}

/// Was das Gateway über die Kontakte wissen darf (#119, K3a-1, E-114): ein reiner Wert, aus den Datensätzen gebaut
/// ([ContactPolicy.of]) und vom [ContactSync] ins Gateway geschoben. Das Gateway liest ihn nur. Standard und Rückfall:
/// [off] (Bereich ausgeschaltet, nichts bekannt).
class ContactPolicy {
  const ContactPolicy({
    this.enabled = false,
    this.contacts = const <String, ContactState>{},
    this.blocked = const <String>{},
    this.groups = const <String>{},
  });

  static const ContactPolicy off = ContactPolicy();

  /// Der Bereich ist für dieses Konto eingeschaltet (`ContactPrefs.enabled`).
  final bool enabled;

  /// Aktive Kontakte mit Zustand; Löschmarken fehlen.
  final Map<String, ContactState> contacts;

  /// Blockierte Kennungen: aktive `blocked`-Datensätze und die lokale Blockierliste (E-48).
  final Set<String> blocked;

  /// Raum-IDs der Gruppen mit aktivem Datensatz (K4-1, #119): nur diese Räume stuft die Einstufung als Gruppe ein (D1/D4,
  /// nie ohne eigenen Datensatz). Löschmarken fehlen.
  final Set<String> groups;

  /// Baut den Wert aus allen Datensätzen. [localBlocked]: die lokale Blockierliste.
  factory ContactPolicy.of(Iterable<ContactRecord> records, {Iterable<String> localBlocked = const <String>[]}) {
    var enabled = false;
    final contacts = <String, ContactState>{};
    final blocked = <String>{...localBlocked};
    final groups = <String>{};
    for (final r in records) {
      if (r.deleted) continue;
      switch (r) {
        case final ContactPrefs p:
          enabled = p.enabled;
        case final Contact c:
          contacts[c.id] = c.state;
          if (c.state == ContactState.blocked) blocked.add(c.id);
        case final GroupRecord g:
          groups.add(g.id);
        default:
          break;
      }
    }
    return ContactPolicy(
      enabled: enabled,
      contacts: Map<String, ContactState>.unmodifiable(contacts),
      blocked: Set<String>.unmodifiable(blocked),
      groups: Set<String>.unmodifiable(groups),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ContactPolicy &&
      other.enabled == enabled &&
      _sameMap(other.contacts, contacts) &&
      _sameSet(other.blocked, blocked) &&
      _sameSet(other.groups, groups);

  @override
  int get hashCode => Object.hash(enabled, contacts.length, blocked.length, groups.length);

  static bool _sameMap(Map<String, ContactState> a, Map<String, ContactState> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }

  static bool _sameSet(Set<String> a, Set<String> b) => a.length == b.length && a.containsAll(b);
}

/// Anzeigename eines Gegenübers außerhalb der Familie (#119, K3a-2, §8.6). Der Name stammt von einem Fremden und ist
/// nicht vertrauenswürdig: Steuer-, Format- und Bidi-Zeichen und das Trennzeichen „·“ entfallen, Leerraum wird
/// zusammengezogen, höchstens [maxName] Zeichen. Der Server stammt **immer aus der Matrix-ID**, nie aus dem Namen.
class ContactNames {
  const ContactNames._();

  static const int maxName = 40;

  /// Höchstlänge eines Gruppennamens (K4-1, §8.5; gleich `ContactGroupSpec.nameMax`).
  static const int maxGroupName = 60;

  /// Bereinigter Name; leer, wenn nichts übrig bleibt.
  static String cleanName(String? name) =>
      TextSanitizer.clean((name ?? '').replaceAll(RegExp('[\\u00B7\\u2022\\u2219\\u22C5\\u30FB]'), ' '), max: maxName);

  /// Bereinigter Gruppenname (höchstens [maxGroupName] Zeichen, ohne das Trennzeichen „·“, Steuer-, Format- und
  /// Bidi-Zeichen); leer, wenn nichts übrig bleibt. Der Name kann von einem Fremden stammen (Gruppenanfrage).
  static String groupTitle(String? name) =>
      TextSanitizer.clean((name ?? '').replaceAll(RegExp('[\\u00B7\\u2022\\u2219\\u22C5\\u30FB]'), ' '), max: maxGroupName);

  /// „Name · server“; bei leerem Namen der lokale Teil der ID.
  static String title(String? name, String userId) {
    final n = cleanName(name);
    final server = MatrixIds.serverName(userId) ?? '';
    final shown = n.isEmpty ? MatrixIds.localpart(userId) : n;
    return server.isEmpty ? shown : '$shown · $server';
  }

  /// Gleicht der Name eines Fremden einem Familienmitglied (§9.1, Schutz vor Namensgleichheit)? Vergleich über ein
  /// „Skelett“ (Kleinschreibung, ohne Diakritika, häufige Homoglyphen abgebildet, nur Buchstaben und Ziffern); Treffer bei
  /// **Gleichheit** oder wenn ein **ganzes Wort** (mindestens 3 Zeichen) des einen dem anderen entspricht („Mama Anna“ und
  /// „Mama“). Bewusst vorsichtig: lieber eine Warnung zu viel. **Grenze:** kein vollständiger Unicode-Vergleich (UTS 39).
  static bool collides(String? name, Iterable<String> familyNames) {
    final mine = _skeleton(name ?? '');
    if (mine.isEmpty) return false;
    final myWords = _words(name ?? '');
    for (final other in familyNames) {
      final theirs = _skeleton(other);
      if (theirs.isEmpty) continue;
      if (mine == theirs) return true;
      final theirWords = _words(other);
      if (theirWords.any((w) => w.length >= 3 && (mine == w || myWords.contains(w)))) return true;
      if (myWords.any((w) => w.length >= 3 && theirs == w)) return true;
    }
    return false;
  }

  static const Map<String, String> _fold = <String, String>{
    'ä': 'a', 'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'å': 'a', 'ā': 'a',
    'ö': 'o', 'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ø': 'o', 'ō': 'o',
    'ü': 'u', 'ù': 'u', 'ú': 'u', 'û': 'u', 'ū': 'u',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i',
    'ñ': 'n', 'ç': 'c', 'ß': 'ss', 'ý': 'y', 'ÿ': 'y', 'ž': 'z', 'š': 's', 'č': 'c',
    // Homoglyphen (kyrillisch, griechisch) → lateinisch
    'а': 'a', 'е': 'e', 'о': 'o', 'р': 'p', 'с': 'c', 'х': 'x', 'у': 'y', 'і': 'i', 'ј': 'j', 'ѕ': 's', 'м': 'm', 'н': 'h', 'к': 'k', 'т': 't', 'в': 'b',
    'α': 'a', 'ε': 'e', 'ο': 'o', 'ν': 'v', 'ι': 'i', 'κ': 'k', 'τ': 't', 'ρ': 'p', 'υ': 'u', 'χ': 'x', 'μ': 'm', 'η': 'n', 'β': 'b',
  };

  /// Vollbreite und mathematische Buchstaben/Ziffern (NFKC-Ersatz): Codepoint-Bereiche auf ASCII abbilden.
  static String _ascii(int r) {
    if (r >= 0xFF21 && r <= 0xFF3A) return String.fromCharCode(r - 0xFF21 + 0x61); // Ａ–Ｚ
    if (r >= 0xFF41 && r <= 0xFF5A) return String.fromCharCode(r - 0xFF41 + 0x61); // ａ–ｚ
    if (r >= 0xFF10 && r <= 0xFF19) return String.fromCharCode(r - 0xFF10 + 0x30); // ０–９
    // mathematische Alphanumerika (fett, kursiv, …): Blöcke zu je 26 Buchstaben ab 0x1D400 (A–Z, a–z im Wechsel)
    if (r >= 0x1D400 && r <= 0x1D6A3) {
      final i = (r - 0x1D400) % 52;
      return String.fromCharCode(i < 26 ? 0x61 + i : 0x61 + i - 26);
    }
    return String.fromCharCode(r);
  }

  static List<String> _words(String s) {
    final cleaned = cleanName(s);
    return <String>[
      for (final w in cleaned.split(RegExp(r'\s+')))
        if (_skeleton(w).isNotEmpty) _skeleton(w),
    ];
  }

  static String _skeleton(String s) {
    final b = StringBuffer();
    for (final rune in cleanName(s).runes) {
      var ch = _ascii(rune).toLowerCase();
      ch = _fold[ch] ?? ch;
      for (final c in ch.runes) {
        final u = String.fromCharCode(c);
        if (RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(u)) b.write(u);
      }
    }
    return b.toString();
  }
}

/// Gibt es das Konto? [unknown]: Der Server konnte nicht oder nicht verlässlich antworten (Netz, Zeitablauf,
/// `M_FORBIDDEN` bei Servern, die Profile nur bei gemeinsamen Räumen herausgeben); das blockiert das Hinzufügen nie.
enum ContactExistence { yes, no, unknown }

/// Kann die Person Nachrichten entschlüsseln? [unknown]: Die Schlüsselabfrage ist gescheitert oder veraltet (nie als
/// „nicht erreichbar“ melden). [notReachable]: Schlüssel liegen vor, aber kein Gerät hat eine gültige Signaturkette des
/// eigenen Cross-Signing der Person (die App teilt Raumschlüssel nur mit solchen Geräten).
enum ContactReachability { reachable, notReachable, unknown, identityChanged }

/// Ergebnis von `probeContact` (#119, K3a-2b): nur Anzeige, nie Entscheidungsgrundlage für Zugriffe.
class ContactProbe {
  const ContactProbe({
    required this.userId,
    required this.existence,
    required this.displayName,
    required this.reachability,
    this.isFamilyMember = false,
  });

  final String userId;
  final ContactExistence existence;

  /// Bereinigter Anzeigename (leer, wenn keiner bekannt ist).
  final String displayName;
  final ContactReachability reachability;

  /// Familienmitglied (jeder Status): ohne Netzabfrage beantwortet; der Weg ist „Nachricht schreiben“.
  final bool isFamilyMember;
}

/// Erreichbarkeit aus den Geräten der Person (reine Funktion, #119 K3a-2b, §8.3).
class ContactReach {
  const ContactReach._();

  /// [keysKnown]: aktuelle Schlüssel der Person liegen vor (sonst [ContactReachability.unknown]); [encryptable] je Gerät, ob
  /// das SDK Raumschlüssel dorthin teilt.
  static ContactReachability of({required bool keysKnown, required List<bool> encryptable}) {
    if (!keysKnown) return ContactReachability.unknown;
    return encryptable.any((e) => e) ? ContactReachability.reachable : ContactReachability.notReachable;
  }
}
