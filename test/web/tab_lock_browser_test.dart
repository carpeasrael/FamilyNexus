@TestOn('browser')
library;

import 'package:family_nexus/data/platform/tab_lock.dart';
import 'package:flutter_test/flutter_test.dart';

/// #137 gegen die echte Web Locks API. Nur im Browser:
/// `CHROME_EXECUTABLE=/usr/bin/chromium flutter test --platform chrome test/web/tab_lock_browser_test.dart`.
/// Die CI (`dart.yml`) führt ihn nicht aus.
void main() {
  test('dieselbe Seite fordert die Sperre zweimal an (neue Passwortabfrage nach dem Löschen)', () async {
    expect(await acquireTabLock(), isTrue);
    expect(await acquireTabLock(), isTrue, reason: 'eigene Sperre darf nicht als „schon geöffnet“ gelten');
  });
}
