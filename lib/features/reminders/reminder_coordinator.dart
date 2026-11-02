import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../../core/app_log.dart';
import '../../data/platform/reminder_scheduler.dart';
import '../../domain/key_value_store.dart';
import '../../domain/reminder_planner.dart';
import '../../l10n/gen/app_localizations.dart';
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
  int _plannedCount = 0;

  ReminderPermission get permission => _permission;

  /// `true`, wenn „Erlauben“ die Berechtigung nicht gebracht hat: Das System zeigt nach einer Ablehnung
  /// (oder bei manchen macOS-Builds) keinen Dialog mehr; dann führt nur der Weg über die Einstellungen
  /// weiter (#57). Nach der Rückkehr in die App liest [reschedule] die Berechtigung neu (HomeShell).
  bool get needsSystemSettings =>
      _askedWithoutSuccess && _permission == ReminderPermission.notificationsDenied && scheduler.canOpenSettings;
  bool _askedWithoutSuccess = false;
  int get plannedCount => _plannedCount;

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
    _schedule();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    calendar.removeListener(_schedule);
    settings.removeListener(_schedule);
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
    if (!_disposed) notifyListeners();
  }

  ({List<CalendarEvent> events, Map<String, List<int>> personal, List<int> defaults, Set<String> skip}) _input() => (
        events: calendar.events,
        personal: calendar.reminders,
        defaults: settings.settings.defaultReminderMinutes,
        skip: calendar.declinedEventIds,
      );

  /// Ausgelöste, nicht bestätigte Erinnerungen, deren Termin noch nicht vorbei ist (#218).
  List<ReminderEntry> due() {
    final i = _input();
    return ReminderPlanner.due(
      events: i.events,
      personal: i.personal,
      defaults: i.defaults,
      now: _clock(),
      acknowledged: _acknowledged.keys.toSet(),
      skip: i.skip,
      viewer: calendar.zone,
    );
  }

  /// Geplante Erinnerungen mit ihrem Termin, wie sie [reschedule] plant.
  List<ReminderEntry> planned() {
    final i = _input();
    return ReminderPlanner.upcoming(
      events: i.events,
      personal: i.personal,
      defaults: i.defaults,
      now: _clock(),
      skip: i.skip,
      viewer: calendar.zone,
    );
  }

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
    notifyListeners();
    for (final e in list) {
      await scheduler.dismiss(e.reminder.id);
    }
    await _loading;
    await _persist();
  }

  void _prune() {
    final now = _clock().toUtc().millisecondsSinceEpoch;
    _acknowledged.removeWhere((_, end) => end <= now);
    if (_acknowledged.length > maxAcknowledged) {
      final byEnd = _acknowledged.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
      for (final e in byEnd.take(_acknowledged.length - maxAcknowledged)) {
        _acknowledged.remove(e.key);
      }
    }
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
    _plannedCount = plan.length;
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
