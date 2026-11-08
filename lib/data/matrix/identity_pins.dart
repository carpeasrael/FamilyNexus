/// Ergebnis von [decide] für die Identität eines Mitglieds (#133).
enum IdentityDecision {
  /// Noch kein Pin und nichts gesperrt: den Schlüssel merken (TOFU).
  firstSeen,

  /// Pin passt, nichts gesperrt.
  ok,

  /// Anderer Schlüssel als gemerkt, oder Geräte sind (noch) gesperrt: Die Aktion „Akzeptieren“ steht an.
  changed,
}

/// Entscheidung zur Identität eines Mitglieds. Entsperrt wird nie hier, sondern nur durch das ausdrückliche
/// Akzeptieren (E-37): Kontodaten, die der Server liefert, können also keine Sperre aufheben.
///
/// * anderer Pin als der Schlüssel ⇒ [IdentityDecision.changed];
/// * ein gesperrtes Gerät ⇒ [IdentityDecision.changed], auch bei passendem oder fehlendem Pin (sonst
///   verschwände die Aktion „Akzeptieren“, obwohl Geräte gesperrt bleiben);
/// * sonst: kein Pin ⇒ [IdentityDecision.firstSeen], passender Pin ⇒ [IdentityDecision.ok].
IdentityDecision decide({required String? pinned, required String pub, required bool anyBlocked}) {
  if (pinned != null && pinned != pub) return IdentityDecision.changed;
  if (anyBlocked) return IdentityDecision.changed;
  return pinned == null ? IdentityDecision.firstSeen : IdentityDecision.ok;
}

/// Ergebnis von [resolvePin].
typedef PinResolution = ({IdentityDecision decision, String? pinned, bool adopt});

/// Bestimmt Pin, Entscheidung und lokale Übernahme (#142). Vorrang: ausdrücklich akzeptiert, lokale Kopie dieses
/// Geräts, Kontodaten (vom Server änderbar), noch nicht gespeicherter erster Pin. Übernommen wird nur, wenn es lokal
/// noch keinen Vermerk gibt und die Identität nicht als geändert gilt.
PinResolution resolvePin({
  String? accepted,
  String? local,
  String? account,
  String? pending,
  required String pub,
  required bool anyBlocked,
}) {
  final pinned = accepted ?? local ?? account ?? pending;
  final decision = decide(pinned: pinned, pub: pub, anyBlocked: anyBlocked);
  final adopt = local == null && decision != IdentityDecision.changed;
  return (decision: decision, pinned: pinned, adopt: adopt);
}

/// Ob ein Gerät gesperrt ist, weil die App es gesperrt hat. Das SDK meldet ein Gerät auch dann als gesperrt,
/// wenn seine Selbstsignatur ungültig ist (`DeviceKeys.blocked = gesperrt || !selfSigned`); das hebt kein
/// Akzeptieren auf und würde einen Dauer-Fehlalarm erzeugen. Deshalb zählen nur Geräte mit gültiger Selbstsignatur.
bool anyBlocked(Iterable<({bool blocked, bool selfSigned})> devices) => devices.any((d) => d.blocked && d.selfSigned);

/// „Akzeptieren“ ist möglich, wenn die Identität in dieser Sitzung als geändert erkannt wurde oder Geräte noch
/// gesperrt sind (die Sperre überlebt Neustarts in der SDK-Datenbank).
bool canAccept({required bool identityChanged, required bool anyBlocked}) => identityChanged || anyBlocked;

/// Gemerkte Identitätsschlüssel der Mitglieder (TOFU, E-37) mit lokalem Vorrang vor noch nicht synchronisierten
/// Kontodaten. Das SDK aktualisiert `accountData` erst mit dem nächsten Sync, `setAccountData` überschreibt es
/// nicht: Ohne diesen Vorrang läse ein Abgleich direkt nach dem Akzeptieren noch den alten Pin und sperrte neu.
class IdentityPinBook {
  final Map<String, ({String pub, String? base})> _accepted = <String, ({String pub, String? base})>{};
  final Map<String, String> _pending = <String, String>{};

  /// Ausdrücklich akzeptierter Pin, solange die Kontodaten ihn noch nicht zeigen.
  String? accepted(String uid) => _accepted[uid]?.pub;

  /// Noch nicht gespeicherter erster Pin.
  String? pending(String uid) => _pending[uid];

  /// Maßgeblicher Pin: lokal akzeptiert, sonst die lokale Kopie dieses Geräts (#142), sonst die Kontodaten, sonst
  /// ein noch nicht gespeicherter erster Pin.
  String? pinned(String uid, Map<String, String> accountPins, {Map<String, String> local = const <String, String>{}}) =>
      _accepted[uid]?.pub ?? local[uid] ?? accountPins[uid] ?? _pending[uid];

  /// Der Nutzer hat [pub] akzeptiert. [base] ist der Kontodaten-Pin zu diesem Zeitpunkt. Erst nach erfolgreichem
  /// Schreiben der Kontodaten aufrufen.
  void accept(String uid, String pub, {required String? base}) {
    _accepted[uid] = (pub: pub, base: base);
    _pending.remove(uid);
  }

  /// Räumt akzeptierte Pins auf, sobald die Kontodaten sie zeigen oder inzwischen anders lauten (ein anderes
  /// eigenes Gerät hat anders entschieden). Bei fehlendem Ausgangswert genügt das Erscheinen eines Pins.
  void synced(Map<String, String> accountPins) {
    _accepted.removeWhere((uid, a) {
      final cur = accountPins[uid];
      return cur != null && (cur == a.pub || cur != a.base);
    });
  }

  /// Merkt den ersten Pin eines Mitglieds, bis er in den Kontodaten steht.
  void remember(String uid, String pub) => _pending[uid] = pub;

  /// Zu schreibende Kontodaten (der Spiegel): akzeptierte Pins vor den lokalen, diese vor den Kontodaten (#142: ein
  /// vom Server geänderter Wert wird beim nächsten Schreiben überschrieben), ungespeicherte erste Pins nur ohne anderen.
  Map<String, String> merged(Map<String, String> accountPins, {Map<String, String> local = const <String, String>{}}) =>
      <String, String>{
        ..._pending,
        ...accountPins,
        ...local,
        for (final e in _accepted.entries) e.key: e.value.pub,
      };

  /// Nach erfolgreichem Schreiben: Einträge, die jetzt in [written] stehen, sind nicht mehr „ungespeichert“.
  void persisted(Map<String, String> written) => _pending.removeWhere((k, v) => written[k] == v);

  bool get hasPending => _pending.isNotEmpty;

  /// Abmelden.
  void clear() {
    _accepted.clear();
    _pending.clear();
  }
}
