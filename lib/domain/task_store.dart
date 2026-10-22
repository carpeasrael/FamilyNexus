import 'tasks.dart';

/// Port: lokale, verschlüsselte Ablage der Aufgabenlisten und ihres Protokolls (E-51).
abstract class TaskStore {
  Future<TaskList?> getList(String id);

  /// Aktuelle Fassungen aller Listen (auch Löschmarken).
  Future<List<TaskList>> lists();

  Future<({int active, int total})> listCounts();

  /// Speichert die aktuelle Fassung. [publishedVersion]: dem Server bereits bekannte Version
  /// (eingehend: die eigene; lokal geändert: 0 – wird noch gesendet).
  Future<void> putList(TaskList list, {int? publishedVersion});

  Future<List<TaskList>> pendingLists();

  Future<void> markListPublished(String id, int version);

  /// Entfernt die ältesten **veröffentlichten** Löschmarken, sodass höchstens [keep] bleiben.
  Future<void> pruneListTombstones({required int keep});

  Future<bool> hasLog(String id);

  /// Fügt einen Protokolleintrag an (ändert nie einen vorhandenen). [published]: bereits dem Server bekannt.
  Future<void> addLog(TaskLogEntry entry, {required bool published});

  /// Protokoll, optional nur einer Liste.
  Future<List<TaskLogEntry>> log({String? listId});

  Future<int> logCount(String listId);

  Future<int> logTotal();

  /// Entfernt die ältesten **veröffentlichten** Einträge einer Liste, sodass höchstens [keep] bleiben.
  Future<void> pruneLog(String listId, {required int keep});

  Future<List<TaskLogEntry>> pendingLog();

  Future<void> markLogPublished(String id);

  /// Merkt alle eigenen Listen- und Protokolleinträge erneut zum Senden vor (Resync für neue Mitglieder).
  Future<void> requeueLastEditedBy(String userId);

  /// Entfernt endgültig alle Daten.
  Future<void> wipe();
}
