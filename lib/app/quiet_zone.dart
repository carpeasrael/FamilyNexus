import 'dart:async';

/// Führt [body] in einer Zone aus, in der `print` nichts ausgibt.
///
/// Das Matrix-SDK schreibt schwere Fehler (`Logs().wtf`) per `print` samt
/// Ausnahmetext und Stacktrace nach stdout/logcat; das könnte Inhalte oder
/// Kennungen enthalten. Eigene Ausgaben laufen ausschließlich über `AppLog`.
void runInQuietZone(void Function() body) {
  runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        // bewusst verschluckt
      },
    ),
  );
}
