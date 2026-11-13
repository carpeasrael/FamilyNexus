import 'calendar_event.dart';
import 'event_themes.dart';
import 'server.dart';

/// Ereignisformat der Kalender-Themen: ein verschlüsseltes Raumereignis je Thema im Familienraum (E-99).
///
/// Sicherheitsregeln: Alle Felder werden streng typgeprüft und über [EventTheme.validate] begrenzt; `by`
/// muss dem authentischen Absender des Matrix-Ereignisses entsprechen (kein Schreiben in fremdem Namen).
/// Ob der Absender Moderator ist, prüft `EventThemeService` beim Empfang.
class EventThemeCodec {
  const EventThemeCodec._();

  static const String type = 'de.inneso.familynexus.eventtheme';
  static const int schema = 1;

  static int get _minMs => CalendarEvent.minDate.millisecondsSinceEpoch;
  static int get _maxMs => CalendarEvent.maxDate.millisecondsSinceEpoch;

  static Map<String, Object?> encode(EventTheme t) {
    final problems = t.validate();
    if (problems.isNotEmpty) throw StateError('Ungültiges Thema: ${problems.join(',')}');
    return <String, Object?>{
      'v': schema,
      'id': t.id,
      'by': t.by,
      'version': t.version,
      'deleted': t.deleted,
      'name': t.name,
      'color': t.colorIndex,
      'ts': t.updatedAt.millisecondsSinceEpoch,
    };
  }

  /// `null` bei ungültigem Inhalt. `by` muss mit [sender] übereinstimmen.
  static EventTheme? decode(Map<String, Object?> c, {required String sender}) {
    if (!MatrixIds.isUserId(sender) || c['v'] != schema) return null;
    final id = c['id'];
    final by = c['by'];
    final version = c['version'];
    final deleted = c['deleted'];
    final name = c['name'];
    final color = c['color'];
    final ts = c['ts'];
    if (id is! String || by is! String || version is! int || deleted is! bool) return null;
    if (name is! String || color is! int || ts is! int || by != sender) return null;
    if (ts < _minMs || ts > _maxMs) return null;
    if (name.length > EventTheme.maxName * 2) return null;
    final theme = EventTheme(
      id: id,
      name: name,
      colorIndex: color,
      deleted: deleted,
      version: version,
      by: by,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(ts, isUtc: true),
    );
    return theme.validate().isEmpty ? theme : null;
  }
}
