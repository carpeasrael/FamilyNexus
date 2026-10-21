import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../data/platform/reminder_scheduler.dart';
import '../../domain/reminder_planner.dart';
import '../../l10n/gen/app_localizations.dart';
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
    Locale Function()? deviceLocale,
    DateTime Function()? clock,
  })  : _deviceLocale = deviceLocale ?? (() => WidgetsBinding.instance.platformDispatcher.locale),
        _clock = clock ?? DateTime.now;

  final CalendarController calendar;
  final ReminderScheduler scheduler;
  final SettingsController settings;
  final Locale Function() _deviceLocale;
  final DateTime Function() _clock;

  Timer? _debounce;
  ReminderPermission _permission = ReminderPermission.granted;
  int _plannedCount = 0;

  ReminderPermission get permission => _permission;
  int get plannedCount => _plannedCount;

  void start() {
    calendar.addListener(_schedule);
    settings.addListener(_schedule);
    _schedule();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    calendar.removeListener(_schedule);
    settings.removeListener(_schedule);
    super.dispose();
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
    notifyListeners();
    await reschedule();
    return _permission;
  }

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
