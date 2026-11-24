import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// #431, E-112: Der Kalender-Sync und alles unter `lib/features/calendar` nehmen empfangene Termine nur über
/// `applyFrom` (mit Absender und Serverzeit) an. `applyIncoming` ist die Hülle für Tests und darf in `lib/` nicht
/// für Kalendertermine aufgerufen werden (sie hielte jede Fassung für eine des Besitzers).
void main() {
  test('lib ruft CalendarService.applyIncoming nicht auf', () {
    final offenders = <String>[];
    for (final dir in <String>['lib/data/sync/calendar_sync.dart', 'lib/features/calendar', 'lib/app']) {
      final entity = FileSystemEntity.typeSync(dir) == FileSystemEntityType.directory
          ? Directory(dir).listSync(recursive: true).whereType<File>()
          : <File>[File(dir)];
      for (final f in entity.where((f) => f.path.endsWith('.dart'))) {
        if (f.readAsStringSync().contains('applyIncoming(')) offenders.add(f.path);
      }
    }
    expect(offenders, isEmpty);
  });
}
