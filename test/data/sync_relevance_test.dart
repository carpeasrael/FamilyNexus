import 'package:family_nexus/data/matrix/sync_relevance.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart' show SyncUpdate;

SyncUpdate _u(Map<String, Object?> j) => SyncUpdate.fromJson(<String, Object?>{'next_batch': 'x', ...j});

/// #150: Leere Long-Poll-Antworten lösen keinen vollen Abgleich aus; alles andere schon.
void main() {
  test('leere Antworten sind nicht relevant', () {
    expect(syncNeedsRefresh(_u(<String, Object?>{})), isFalse);
    expect(syncNeedsRefresh(_u(<String, Object?>{'device_one_time_keys_count': <String, Object?>{'signed_curve25519': 50}})), isFalse);
    expect(
      syncNeedsRefresh(_u(<String, Object?>{
        'rooms': <String, Object?>{},
        'account_data': <String, Object?>{'events': <Object?>[]},
        'to_device': <String, Object?>{'events': <Object?>[]},
        'presence': <String, Object?>{'events': <Object?>[]},
        'device_lists': <String, Object?>{'changed': <Object?>[], 'left': <Object?>[]},
      })),
      isFalse,
    );
  });

  final room = <String, Object?>{'!r:hs.example': <String, Object?>{}};
  final relevant = <String, Map<String, Object?>>{
    'rooms.join': {'rooms': {'join': room}},
    'rooms.invite': {'rooms': {'invite': room}},
    'rooms.leave': {'rooms': {'leave': room}},
    'rooms.knock': {'rooms': {'knock': room}},
    'account_data': {
      'account_data': {
        'events': [
          {'type': 'm.direct', 'content': <String, Object?>{}},
        ],
      },
    },
    'to_device': {
      'to_device': {
        'events': [
          {'type': 'm.dummy', 'sender': '@a:hs.example', 'content': <String, Object?>{}},
        ],
      },
    },
    'presence': {
      'presence': {
        'events': [
          {'type': 'm.presence', 'sender': '@a:hs.example', 'content': {'presence': 'online'}},
        ],
      },
    },
    'device_lists.changed': {'device_lists': {'changed': ['@a:hs.example']}},
    'device_lists.left': {'device_lists': {'left': ['@a:hs.example']}},
  };
  for (final e in relevant.entries) {
    test('relevant: ${e.key}', () => expect(syncNeedsRefresh(_u(e.value)), isTrue));
  }
}
