import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// Sperrt den Browser-Speicher für diesen Tab (Web Locks API). Zwei Tabs würden dieselbe IndexedDB-Datenbank
/// und die Matrix-Schlüssel gleichzeitig verändern. `false`, wenn ein anderer Tab die Sperre hält; die Sperre
/// bleibt bis zum Schließen des Tabs. Ohne Web Locks (sehr alte Browser) gilt sie als frei.
Future<bool> acquireWebTabLock() async {
  final locks = web.window.navigator.getProperty<JSAny?>('locks'.toJS);
  if (locks == null || !locks.isA<JSObject>()) return true;
  final result = Completer<bool>();
  final options = JSObject()..setProperty('ifAvailable'.toJS, true.toJS);
  JSAny? callback(JSAny? lock) {
    if (lock == null) {
      result.complete(false);
      return null;
    }
    result.complete(true);
    // Nie fertig werden: hält die Sperre, bis der Tab geschlossen wird.
    return Completer<void>().future.toJS;
  }

  (locks as JSObject).callMethod<JSAny?>('request'.toJS, 'familynexus-app'.toJS, options, callback.toJS);
  return result.future;
}
