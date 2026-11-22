/// Kennzeichnung der Buch-Räume (Kassenbuch, #311, E-113). Ein Buch ist ein eigener verschlüsselter Raum; sein
/// `m.room.create`-Inhalt trägt das Buch-Kennzeichen und die Familienraum-ID. Beides ist von Dritten fälschbar und
/// dient **nur** der Zuordnung und dem Ausblenden aus der Familienlogik, nie einer Sicherheitsentscheidung für das Buch.
class BookRoomMarker {
  const BookRoomMarker._();

  /// Schlüssel im `creation_content`: Art des Buchs (`cash`).
  static const String bookKey = 'de.inneso.familynexus.book';

  /// Schlüssel im `creation_content`: Raum-ID der Familie, zu der das Buch gehört (nur Zuordnung).
  static const String familyKey = 'de.inneso.familynexus.family';

  static const String cashKind = 'cash';

  /// Ist der Raum ein Buch-Raum? Schon das Vorhandensein des Schlüssels genügt (mit jedem Wert): Ein Raum, der sich so
  /// kennzeichnet, darf nie von der Familienlogik behandelt werden (Annahme als Familie, Einladungsliste).
  static bool isBook(Map<String, Object?>? createContent) => createContent != null && createContent.containsKey(bookKey);

  /// `creation_content` für ein neues Kassenbuch der Familie [familyRoomId].
  static Map<String, Object?> cashCreationContent(String familyRoomId) =>
      <String, Object?>{bookKey: cashKind, familyKey: familyRoomId};
}
