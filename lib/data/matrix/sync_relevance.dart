import 'package:matrix/matrix.dart' show SyncUpdate;

/// Ob ein Sync etwas enthält, das den Zustandsabgleich des Gateways lohnt (#150).
///
/// Leere Long-Poll-Antworten (nur `next_batch` und Schlüsselzähler) ändern nichts am Zustand. Wie
/// `SyncUpdate.hasRoomUpdate` im SDK zählen Kontodaten, Gerätenachrichten und Räume in `join`, `invite` und
/// `leave`; dazu kommen `knock` (Anklopfen, vom SDK nicht berücksichtigt), `presence` und geänderte Geräte.
bool syncNeedsRefresh(SyncUpdate u) =>
    (u.accountData?.isNotEmpty ?? false) ||
    (u.toDevice?.isNotEmpty ?? false) ||
    (u.rooms?.join?.isNotEmpty ?? false) ||
    (u.rooms?.invite?.isNotEmpty ?? false) ||
    (u.rooms?.leave?.isNotEmpty ?? false) ||
    (u.rooms?.knock?.isNotEmpty ?? false) ||
    (u.presence?.isNotEmpty ?? false) ||
    (u.deviceLists?.changed?.isNotEmpty ?? false) ||
    (u.deviceLists?.left?.isNotEmpty ?? false);
