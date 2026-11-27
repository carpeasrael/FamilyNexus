import '../../domain/contacts.dart' show ContactLimits;
import '../../domain/family.dart';

/// Reine Beschreibung eines Gruppenraums mit Personen außerhalb der Familie (#119, K4-1, KONTAKTE §5), getrennt vom SDK
/// wie [FamilyRoomSpec]. Das Gateway reicht die Werte ab K4-2 an `createRoom` weiter (privat, nicht im Verzeichnis).
///
/// Unterschiede zur Familie: Beitritt nur auf Einladung (`invite`, nie `knock`), Verlauf `invited` (Neue lesen nichts
/// Früheres) und die Schwelle für Regel, Verlauf und Verschlüsselung liegt bei 100, damit ein ernannter Admin (50) die
/// Gruppe weder öffnen noch entschlüsseln kann. Es gibt keinen Avatar-Eintrag.
class ContactGroupSpec {
  const ContactGroupSpec._();

  static const String roomVersion = '10';
  static const int nameMax = 60;
  static const String megolm = 'm.megolm.v1.aes-sha2';

  /// Höchstzahl der Mitglieder (beigetreten und eingeladen, Maß G, §3.6).
  static const int maxMembers = ContactLimits.maxGroupMembers;

  /// Anfangszustand: Verschlüsselung, Verlauf `invited`, Beitritt nur auf Einladung.
  static List<({String type, Map<String, Object?> content})> initialState() =>
      <({String type, Map<String, Object?> content})>[
        (type: 'm.room.encryption', content: <String, Object?>{'algorithm': megolm}),
        (type: 'm.room.history_visibility', content: <String, Object?>{'history_visibility': 'invited'}),
        (type: 'm.room.join_rules', content: <String, Object?>{'join_rule': 'invite'}),
      ];

  /// Power-Levels: Ersteller 100, alle anderen 0; ernannte Admins 50. Schwellen 50 (Einladen, Entfernen, Umbenennen,
  /// Stufen ändern); `m.room.join_rules`, `m.room.history_visibility` und `m.room.encryption` bei 100; Tombstone und
  /// Server-ACL bei 101 (unerreichbar).
  static Map<String, Object?> powerLevels(String creatorId) => <String, Object?>{
        'users': <String, int>{creatorId: PowerLevels.admin},
        'users_default': PowerLevels.member,
        'events_default': PowerLevels.member,
        'state_default': PowerLevels.moderator,
        'invite': PowerLevels.moderator,
        'kick': PowerLevels.moderator,
        'ban': PowerLevels.moderator,
        'redact': PowerLevels.moderator,
        'events': <String, int>{
          'm.room.power_levels': PowerLevels.moderator,
          'm.room.name': PowerLevels.moderator,
          'm.room.encryption': PowerLevels.admin,
          'm.room.history_visibility': PowerLevels.admin,
          'm.room.join_rules': PowerLevels.admin,
          'm.room.tombstone': PowerLevels.unreachable,
          'm.room.server_acl': PowerLevels.unreachable,
        },
      };

  /// Nachprüfung im **Beitrittsmoment** (reine Funktion): `true` = die Gruppe bleibt, `false` = Raum sofort verlassen.
  /// Verlassen bei: Algorithmus ≠ Megolm, Regel ≠ `invite` (auch `null`), Verlauf ≠ `invited` (auch `null`) oder
  /// **G > 50** mit bekannter Beitrittszahl (G = [joined] + ([invited] ?? 0), Eingeladene lesen ab Einladung mit).
  /// Eine unbekannte Beitrittszahl verlässt **nicht**: die Gruppe bleibt sichtbar und sendegesperrt (Nutzerentscheidung 7).
  /// Weicht von KONTAKTE §8.4 ab, dort stand „prüft Megolm und Größe; sonst verlässt sie den Raum sofort“ ohne den
  /// Unbekannt-Fall. Die Power-Levels fremder Gruppen werden nicht geprüft (die laufende Prüfung ist `GroupHealth`).
  static bool verifyJoined({
    required String? encryptionAlgorithm,
    required String? joinRule,
    required String? historyVisibility,
    required int? joined,
    required int? invited,
  }) {
    if (encryptionAlgorithm != megolm) return false;
    if (joinRule != 'invite') return false;
    if (historyVisibility != 'invited') return false;
    if (joined == null) return true;
    return joined + (invited ?? 0) <= maxMembers;
  }
}
