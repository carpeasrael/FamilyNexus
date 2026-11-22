import '../../domain/family.dart';

/// Reine Beschreibung eines Buch-Raums (#311, E-113), getrennt vom SDK. Das Gateway reicht die Werte an `createRoom`.
class BookRoomSpec {
  const BookRoomSpec._();

  /// Neutraler Raumname: Der Buchtitel steht nur im verschlüsselten `bookmeta`, nie im Klartext.
  static const String name = 'FamilyNexus';
  static const String roomVersion = '10';
  static const String megolm = 'm.megolm.v1.aes-sha2';

  /// Anfangszustand: Verschlüsselung, Verlauf für Mitglieder sichtbar, Beitritt nur auf Einladung.
  static List<({String type, Map<String, Object?> content})> initialState() =>
      <({String type, Map<String, Object?> content})>[
        (type: 'm.room.encryption', content: <String, Object?>{'algorithm': megolm}),
        (type: 'm.room.history_visibility', content: <String, Object?>{'history_visibility': 'shared'}),
        (type: 'm.room.join_rules', content: <String, Object?>{'join_rule': 'invite'}),
      ];

  /// Power-Levels: Nur der Ersteller (100) lädt ein, entfernt und ändert Zustand; jedes Mitglied (0) sendet Einträge.
  static Map<String, Object?> powerLevels(String creatorId) => <String, Object?>{
        'users': <String, int>{creatorId: PowerLevels.admin},
        'users_default': PowerLevels.member,
        'events_default': PowerLevels.member,
        'state_default': PowerLevels.admin,
        'invite': PowerLevels.admin,
        'kick': PowerLevels.admin,
        'ban': PowerLevels.admin,
        'redact': PowerLevels.admin,
        'events': <String, int>{
          'm.room.power_levels': PowerLevels.admin,
          'm.room.name': PowerLevels.admin,
          'm.room.encryption': PowerLevels.admin,
          'm.room.history_visibility': PowerLevels.admin,
          'm.room.join_rules': PowerLevels.admin,
          'm.room.tombstone': PowerLevels.unreachable,
          'm.room.server_acl': PowerLevels.unreachable,
        },
      };

  /// Prüft den Zustand eines beigetretenen Buch-Raums nach dem Beitritt: Verschlüsselung, Verlauf, Beitrittsregel,
  /// Power-Levels und Ersteller. Eine Abweichung heißt: Raum verlassen. [powerLevels] ist der Inhalt von
  /// `m.room.power_levels`.
  static bool verifyJoined({
    required String? encryptionAlgorithm,
    required String? historyVisibility,
    required String? joinRule,
    required Map<String, Object?>? powerLevels,
    required String creatorId,
  }) {
    if (encryptionAlgorithm != megolm || historyVisibility != 'shared' || joinRule != 'invite') return false;
    final pl = powerLevels;
    if (pl == null) return false;
    int level(String key) => pl[key] is int ? pl[key]! as int : -1;
    if (level('invite') != PowerLevels.admin || level('kick') != PowerLevels.admin || level('state_default') != PowerLevels.admin) {
      return false;
    }
    final users = pl['users'];
    if (users is! Map<String, Object?> || users[creatorId] != PowerLevels.admin) return false;
    // Außer dem Ersteller darf niemand mehr als ein gewöhnliches Mitglied sein (kein heimlicher Zweitverwalter).
    for (final e in users.entries) {
      if (e.key != creatorId && (e.value is! int || (e.value! as int) > PowerLevels.member)) return false;
    }
    final eventsDefault = pl['events_default'];
    return eventsDefault is int && eventsDefault <= PowerLevels.member;
  }
}
