import '../../domain/family.dart';

/// Reine Beschreibung des Familienraums (E-12), getrennt vom SDK, damit sie
/// testbar ist. Das Gateway reicht diese Werte an `createRoom` weiter.
class FamilyRoomSpec {
  const FamilyRoomSpec._();

  static const String roomVersion = '10';
  static const int nameMax = 60;
  static const String megolm = 'm.megolm.v1.aes-sha2';

  /// Anfangszustand: Verschlüsselung, Verlauf für Mitglieder sichtbar, anklopfbar.
  static List<({String type, Map<String, Object?> content})> initialState() =>
      <({String type, Map<String, Object?> content})>[
        (type: 'm.room.encryption', content: <String, Object?>{'algorithm': megolm}),
        (type: 'm.room.history_visibility', content: <String, Object?>{'history_visibility': 'shared'}),
        (type: 'm.room.join_rules', content: <String, Object?>{'join_rule': 'knock'}),
      ];

  /// Power-Levels: Ersteller = Administrator (100, in der App ein Moderator), alle anderen 0;
  /// ernannte Moderatoren haben 50. Alle Schwellen liegen bei 50, damit Moderatoren und Ersteller
  /// dasselbe dürfen. Zustandsereignisse, die niemand ändern soll, liegen auf 101 (unerreichbar).
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
          'm.room.encryption': PowerLevels.moderator,
          'm.room.history_visibility': PowerLevels.moderator,
          'm.room.join_rules': PowerLevels.moderator,
          'm.room.tombstone': PowerLevels.unreachable,
          'm.room.server_acl': PowerLevels.unreachable,
        },
      };
}
