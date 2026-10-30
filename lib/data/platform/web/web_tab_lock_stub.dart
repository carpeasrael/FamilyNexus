/// Außerhalb des Browsers gibt es keine zweite Instanz im selben Speicher.
Future<bool> acquireWebTabLock() async => true;

/// Außerhalb des Browsers gibt es keine fremde Seite, die die App einbetten könnte.
bool isWebEmbedded() => false;
