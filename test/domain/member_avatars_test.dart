import 'package:family_nexus/domain/member_avatars.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('zwölf Kennungen p01 bis p12, null ist gültig, Unbekanntes nicht', () {
    expect(AvatarPresets.all, hasLength(12));
    expect(AvatarPresets.all.toSet(), hasLength(12));
    expect(AvatarPresets.all.first, 'p01');
    expect(AvatarPresets.all.last, 'p12');
    expect(AvatarPresets.isValid(null), isTrue);
    for (final p in AvatarPresets.all) {
      expect(AvatarPresets.isValid(p), isTrue);
    }
    for (final bad in <String>['', 'p00', 'p13', 'P01', 'p1', 'foo', '../x']) {
      expect(AvatarPresets.isValid(bad), isFalse, reason: bad);
    }
  });

  test('Inhalt: null wird {} (Zustand lässt sich nicht löschen), sonst {preset}', () {
    expect(AvatarPresets.content(null), isEmpty);
    expect(AvatarPresets.content('p03'), <String, Object?>{'preset': 'p03'});
    expect(AvatarPresets.fromContent(<String, Object?>{}), isNull);
    expect(AvatarPresets.fromContent(<String, Object?>{'preset': 'p03', 'x': 'y'}), 'p03');
    expect(AvatarPresets.fromContent(<String, Object?>{'preset': 'zzz'}), isNull);
    expect(AvatarPresets.fromContent(<String, Object?>{'preset': 3}), isNull);
  });

  test('Freigabe ergänzt nur events[Typ] = 0 und lässt alles Übrige unverändert', () {
    final current = <String, Object?>{
      'users': <String, int>{'@a:x': 100},
      'state_default': 50,
      'unknown_future_field': <String, Object?>{'k': 1},
      'events': <String, int>{'m.room.name': 50},
    };
    final out = AvatarPresets.withPermission(current)!;
    expect(out['users'], current['users']);
    expect(out['state_default'], 50);
    expect(out['unknown_future_field'], current['unknown_future_field']);
    expect(out['events'], <String, int>{'m.room.name': 50, AvatarPresets.type: 0});
    expect((current['events']! as Map).containsKey(AvatarPresets.type), isFalse);
  });

  test('Freigabe ohne events-Feld legt es an; bestehende Freigabe ist idempotent (null)', () {
    final out = AvatarPresets.withPermission(<String, Object?>{'state_default': 50})!;
    expect(out['events'], <String, Object?>{AvatarPresets.type: 0});
    expect(AvatarPresets.withPermission(out), isNull);
    expect(AvatarPresets.isPermitted(out), isTrue);
    expect(AvatarPresets.isPermitted(<String, Object?>{'events': <String, int>{AvatarPresets.type: 50}}), isFalse);
    expect(AvatarPresets.isPermitted(null), isFalse);
    final raised = AvatarPresets.withPermission(<String, Object?>{'events': <String, int>{AvatarPresets.type: 50}})!;
    expect((raised['events']! as Map)[AvatarPresets.type], 0);
  });
}
