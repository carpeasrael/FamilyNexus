import 'package:family_nexus/data/matrix/family_room_spec.dart';
import 'package:family_nexus/domain/avatar_photo.dart';
import 'package:flutter_test/flutter_test.dart';

/// #434, E-111: Die Foto-Ereignisse sind Nachrichtenereignisse. Mitglieder dürfen sie über `events_default` (0)
/// senden; die Power-Levels der Familienräume (E-12, schwer rückholbar) bleiben unverändert.
void main() {
  final pl = FamilyRoomSpec.powerLevels('@anna:x.org');

  test('die neuen Ereignistypen stehen nicht in den Power-Levels', () {
    final events = pl['events']! as Map<String, int>;
    expect(events.containsKey(AvatarPhotoCodec.type), isFalse);
    expect(events.containsKey(AvatarResetCodec.type), isFalse);
  });

  test('Nachrichtenereignisse bleiben für Mitglieder offen, Zurückziehen für Moderatoren (redact 50)', () {
    expect(pl['events_default'], 0);
    expect(pl['redact'], 50);
  });

  test('die Aufzählung der Zustandsereignisse ist unverändert (kein neuer Eintrag durch #434)', () {
    expect((pl['events']! as Map<String, int>).keys.toSet(), <String>{
      'm.room.power_levels',
      'm.room.name',
      'm.room.encryption',
      'm.room.history_visibility',
      'm.room.join_rules',
      'de.inneso.familynexus.avatar',
      'm.room.tombstone',
      'm.room.server_acl',
    });
  });
}
