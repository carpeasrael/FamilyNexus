import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../../core/app_log.dart';
import '../../data/platform/reminder_scheduler.dart';
import '../../domain/key_value_store.dart';
import '../../domain/reminder_planner.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../domain/app_settings.dart';
import '../../domain/calendar_event.dart';
import '../calendar/calendar_controller.dart';
import '../settings/settings_controller.dart';

/// Plant die lokalen Erinnerungen neu, sobald sich Termine, persönliche
/// Erinnerungen oder Standardwerte ändern, sowie beim Start (nach Neustart des
/// Geräts oder der App). Texte kommen aus den ARB-Dateien und enthalten nie
/// Termininhalte (E-15).
class ReminderCoordinator extends ChangeNotifier {
  ReminderCoordinator({
    required this.calendar,
    required this.scheduler,
    required this.settings,
    this.store,
    Locale Function()? deviceLocale,
    DateTime Function()? clock,
  })  : _deviceLocale = deviceLocale ?? (() => WidgetsBinding.instance.platformDispatcher.locale),
        _clock = clock ?? DateTime.now;

  final CalendarController calendar;
  final ReminderScheduler scheduler;
  final SettingsController settings;

  /// Ablage der Bestätigungen; ohne sie nur im Speicher (Tests).
  final KeyValueStore? store;
  final Locale Function() _deviceLocale;
  final DateTime Function() _clock;

  Timer? _debounce;
  ReminderPermission _permission = ReminderPermission.granted;

  ReminderPermission get permission => _permission;

  /// `true`, wenn „Erlauben“ die Berechtigung nicht gebracht hat: Das System zeigt nach einer Ablehnung
  /// (oder bei manchen macOS-Builds) keinen Dialog mehr; dann führt nur der Weg über die Einstellungen
  /// weiter (#57). Nach der Rückkehr in die App liest [reschedule] die Berechtigung neu (HomeShell).
  bool get needsSystemSettings =>
      _askedWithoutSuccess && _permission == ReminderPermission.notificationsDenied && scheduler.canOpenSettings;
  bool _askedWithoutSuccess = false;

  /// Zahl der geplanten Erinnerungen, wie „Geplant (n)“ der Übersicht (#223, E-87).
  int get plannedCount => planned().length;

  /// Bestätigte Erinnerungen: ID → Ende des Vorkommens (ms). Nur IDs und Zeiten, kein Inhalt; zählt zu den
  /// Familiendaten und fällt mit Abmelden und Familienwechsel (E-87).
  static const String acknowledgedKey = 'reminders.acknowledged';
  static const int maxAcknowledged = 500;
  final Map<int, int> _acknowledged = <int, int>{};
  Future<void> _loading = Future<void>.value();
  Future<void> _writing = Future<void>.value();
  bool _disposed = false;

  void start() {
    _loading = _load();
    calendar.addListener(_schedule);
    settings.addListener(_schedule);
    calendar.addListener(_invalidate);
    settings.addListener(_invalidate);
    _schedule();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    calendar.removeListener(_schedule);
    settings.removeListener(_schedule);
    calendar.removeListener(_invalidate);
    settings.removeListener(_invalidate);
    _snapshot = null;
    super.dispose();
  }

  /// Führt Gespeichertes mit schon im Speicher Bestätigtem zusammen; Abgelaufenes fällt weg.
  Future<void> _load() async {
    final s = store;
    if (s == null) return;
    try {
      final raw = (await s.readAll())[acknowledgedKey];
      if (raw != null) {
        final data = json.decode(raw);
        if (data is Map<String, Object?>) {
          final now = _clock().toUtc().millisecondsSinceEpoch;
          for (final e in data.entries) {
            final id = int.tryParse(e.key);
            final end = e.value;
            if (id != null && end is int && end > now) _acknowledged.putIfAbsent(id, () => end);
          }
        }
      }
    } catch (e) {
      AppLog.e('reminders', 'Bestätigte Erinnerungen nicht lesbar', e);
    }
    _invalidate();
    if (!_disposed) notifyListeners();
  }

  /// Zwischenspeicher für Fällig und Geplant (#220): Die Seite „Heute“ fragt bei jedem Neuaufbau, gerechnet
  /// wird nur nach Datenänderung oder wenn die Zeit die Listen ändert (siehe [_Snapshot.validUntil]).
  _Snapshot? _snapshot;

  void _invalidate() => _snapshot = null;

  _Snapshot _current() {
    final now = _clock().toUtc();
    final events = calendar.events;
    final personal = calendar.reminders;
    final appSettings = settings.settings;
    final s = _snapshot;
    if (s != null &&
        identical(s.events, events) &&
        identical(s.personal, personal) &&
        identical(s.settings, appSettings) &&
        !now.isBefore(s.computedAt) &&
        now.isBefore(s.validUntil)) {
      return s;
    }
    final skip = calendar.declinedEventIds;
    final due = List<ReminderEntry>.unmodifiable(ReminderPlanner.due(
      events: events,
      personal: personal,
      defaults: appSettings.defaultReminderMinutes,
      now: now,
      acknowledged: _acknowledged.keys.toSet(),
      skip: skip,
      viewer: calendar.zone,
    ));
    final planned = List<ReminderEntry>.unmodifiable(ReminderPlanner.upcoming(
      events: events,
      personal: personal,
      defaults: appSettings.defaultReminderMinutes,
      now: now,
      skip: skip,
      viewer: calendar.zone,
    ));
    // Gültig bis zur nächsten vollen Minute (neue Einträge am Rand des Fensters), bis die nächste geplante
    // Erinnerung auslöst oder bis das erste fällige Vorkommen endet, je nachdem, was zuerst kommt.
    var validUntil = DateTime.utc(now.year, now.month, now.day, now.hour, now.minute).add(const Duration(minutes: 1));
    for (final e in planned) {
      final t = e.reminder.fireAt.toUtc();
      if (t.isBefore(validUntil)) validUntil = t;
    }
    for (final e in due) {
      final t = e.occurrence.end.toUtc();
      if (t.isBefore(validUntil)) validUntil = t;
    }
    return _snapshot = _Snapshot(
      events: events,
      personal: personal,
      settings: appSettings,
      computedAt: now,
      validUntil: validUntil,
      due: due,
      planned: planned,
    );
  }

  /// Ausgelöste, nicht bestätigte Erinnerungen, deren Termin noch nicht vorbei ist (#218). Unveränderlich.
  List<ReminderEntry> due() => _current().due;

  /// Geplante Erinnerungen mit ihrem Termin, wie sie [reschedule] plant. Unveränderlich.
  List<ReminderEntry> planned() => _current().planned;

  int get dueCount => due().length;

  /// Bestätigt [entries] auf diesem Gerät und entfernt ihre Benachrichtigungen.
  Future<void> acknowledge(Iterable<ReminderEntry> entries) async {
    if (_disposed) return;
    final list = entries.toList();
    if (list.isEmpty) return;
    for (final e in list) {
      _acknowledged[e.reminder.id] = e.occurrence.end.millisecondsSinceEpoch;
    }
    _prune();
    _invalidate();
    notifyListeners();
    for (final e in list) {
      await scheduler.dismiss(e.reminder.id);
    }
    await _loading;
    await _persist();
  }

  void _prune() {
    final now = _clock().toUtc().millisecondsSinceEpoch;
    final before = _acknowledged.length;
    _acknowledged.removeWhere((_, end) => end <= now);
    if (_acknowledged.length > maxAcknowledged) {
      final byEnd = _acknowledged.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
      for (final e in byEnd.take(_acknowledged.length - maxAcknowledged)) {
        _acknowledged.remove(e.key);
      }
    }
    if (_acknowledged.length != before) _invalidate();
  }

  Future<void> _persist() {
    final s = store;
    if (s == null) return Future<void>.value();
    _writing = _writing.then((_) async {
      if (_disposed) return;
      _prune();
      try {
        await s.write(acknowledgedKey, json.encode(<String, int>{for (final e in _acknowledged.entries) '${e.key}': e.value}));
      } catch (e) {
        AppLog.e('reminders', 'Bestätigte Erinnerungen nicht gespeichert', e);
      }
    });
    return _writing;
  }

  AppLocalizations _l10n() {
    final code = settings.settings.languageCode ?? _deviceLocale().languageCode;
    return lookupAppLocalizations(Locale(code == 'de' ? 'de' : 'en'));
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => reschedule().ignore());
  }

  Future<ReminderPermission> requestPermission() async {
    _permission = await scheduler.request();
    _askedWithoutSuccess = _permission == ReminderPermission.notificationsDenied;
    notifyListeners();
    await reschedule();
    return _permission;
  }

  /// Öffnet die Benachrichtigungs-Einstellungen des Systems; `false`, wenn das nicht geht.
  Future<bool> openSystemSettings() => scheduler.openSettings();

  bool _running = false;
  bool _again = false;

  /// Plant neu. Läufe überlappen nie: ein während der Planung eintreffender Auftrag
  /// löst danach genau einen weiteren Lauf aus (kein Löschen durch veraltete Läufe).
  Future<void> reschedule() async {
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    try {
      do {
        _again = false;
        await _scheduleOnce();
      } while (_again);
    } finally {
      _running = false;
    }
  }

  Future<void> _scheduleOnce() async {
    _permission = await scheduler.permission();
    final plan = ReminderPlanner.plan(
      events: calendar.events,
      personal: calendar.reminders,
      defaults: settings.settings.defaultReminderMinutes,
      now: _clock(),
      skip: calendar.declinedEventIds,
      viewer: calendar.zone,
    );
    final l = _l10n();
    await scheduler.replaceAll(
      plan,
      title: l.reminderTitle,
      bodyFor: (m) => l.reminderBody(durationText(l, m)),
    );
    notifyListeners();
  }

  /// „10 Minuten“, „1 Stunde“, „2 Tage“ – nur Dauer, nie Inhalt.
  static String durationText(AppLocalizations l, int minutes) {
    if (minutes == 0) return l.durationNow;
    if (minutes % 1440 == 0) return l.durationDays(minutes ~/ 1440);
    if (minutes % 60 == 0) return l.durationHours(minutes ~/ 60);
    return l.durationMinutes(minutes);
  }
}

/// Fällig und Geplant für bestimmte Eingaben, gültig bis [validUntil] (UTC, #220).
class _Snapshot {
  _Snapshot({
    required this.events,
    required this.personal,
    required this.settings,
    required this.computedAt,
    required this.validUntil,
    required this.due,
    required this.planned,
  });

  /// Eingaben, per `identical` verglichen: Kalender und Einstellungen ersetzen ihre Objekte bei Änderungen.
  final List<CalendarEvent> events;
  final Map<String, List<int>> personal;
  final AppSettings settings;
  final DateTime computedAt;
  final DateTime validUntil;
  final List<ReminderEntry> due;
  final List<ReminderEntry> planned;
}
