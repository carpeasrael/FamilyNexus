import 'package:family_nexus/data/platform/activity_notifications.dart';
import 'package:family_nexus/data/platform/reminder_scheduler.dart';
import 'package:family_nexus/data/sync/activity_notifier.dart';
import 'package:family_nexus/domain/reminder_planner.dart';
import 'package:family_nexus/l10n/gen/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

/// Nachgebautes Plugin: zeichnet Anzeigen, Entfernen und Initialisierung auf.
class _Plugin implements FlutterLocalNotificationsPlugin {
  final List<({int id, String? title, String? body, NotificationDetails? details, String? payload})> shown =
      <({int id, String? title, String? body, NotificationDetails? details, String? payload})>[];
  final List<int> cancelled = <int>[];
  int initialized = 0;
  int cancelledAll = 0;
  int cancelledPending = 0;

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback? onDidReceiveBackgroundNotificationResponse,
  }) async {
    initialized++;
    return true;
  }

  @override
  Future<void> show({required int id, String? title, String? body, NotificationDetails? notificationDetails, String? payload}) async =>
      shown.add((id: id, title: title, body: body, details: notificationDetails, payload: payload));

  @override
  Future<void> cancel({required int id, String? tag}) async => cancelled.add(id);

  @override
  Future<void> cancelAll() async => cancelledAll++;

  @override
  Future<void> cancelAllPendingNotifications() async => cancelledPending++;

  @override
  T? resolvePlatformSpecificImplementation<T extends FlutterLocalNotificationsPlatform>() => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ActivityTexts _texts(String lang) {
  final l = lookupAppLocalizations(Locale(lang));
  return (
    title: 'FamilyNexus',
    chatBody: l.activityChatBody,
    shoppingBody: l.activityShoppingBody,
    channelName: l.activityChannelName,
    channelDescription: l.activityChannelDescription,
  );
}

void main() {
  group('#254: Meldungen über das gemeinsame Plugin', () {
    test('vor der Initialisierung nichts; danach feste Texte, feste IDs, eigener Kanal, privat, keine Nutzlast', () async {
      final plugin = _Plugin();
      final scheduler = LocalReminderScheduler(plugin, false);
      final a = LocalActivityNotifications(scheduler, () => _texts('de'));
      await a.show(ActivityKind.chat, alert: true, count: 3);
      expect(plugin.shown, isEmpty);

      await scheduler.initialize(channelName: 'Erinnerungen', channelDescription: '');
      await a.show(ActivityKind.chat, alert: true, count: 3);
      await a.show(ActivityKind.shopping, alert: false);
      expect(plugin.initialized, 1, reason: 'der Adapter initialisiert nicht selbst');
      expect(plugin.shown.map((s) => s.id), <int>[1, 2]);
      expect(plugin.shown.map((s) => s.title), <String>['FamilyNexus', 'FamilyNexus']);
      expect(plugin.shown.map((s) => s.body), <String>['Neue Nachrichten', 'Neue Einträge auf dem Einkaufszettel']);
      expect(plugin.shown.every((s) => s.payload == null), isTrue);
      final android = plugin.shown.first.details!.android!;
      expect(android.channelId, LocalActivityNotifications.channelId);
      expect(android.visibility, NotificationVisibility.private);
      expect(android.number, 3);
      expect(android.onlyAlertOnce, isFalse);
      expect(plugin.shown.last.details!.android!.onlyAlertOnce, isTrue, reason: 'still ersetzt');
      expect(plugin.shown.last.details!.android!.number, isNull);

      await a.cancel(ActivityKind.shopping);
      expect(plugin.cancelled, <int>[2]);
    });

    test('englische Texte', () async {
      final plugin = _Plugin();
      final scheduler = LocalReminderScheduler(plugin, false);
      await scheduler.initialize(channelName: 'Reminders', channelDescription: '');
      await LocalActivityNotifications(scheduler, () => _texts('en')).show(ActivityKind.shopping, alert: true);
      expect(plugin.shown.single.body, 'New items on the shopping list');
    });

    test('Meldungstexte enthalten keine Platzhalter (nie Absender, Gespräch oder Inhalt)', () {
      for (final lang in <String>['de', 'en']) {
        final t = _texts(lang);
        for (final text in <String>[t.title, t.chatBody, t.shoppingBody, t.channelName, t.channelDescription]) {
          expect(text, isNot(matches(RegExp(r'[{}@!$:]'))), reason: '$lang: $text');
        }
      }
    });

    test('Neuplanen der Erinnerungen lässt angezeigte Meldungen stehen, cancelAll entfernt alles', () async {
      final plugin = _Plugin();
      final scheduler = LocalReminderScheduler(plugin, false);
      await scheduler.initialize(channelName: 'Erinnerungen', channelDescription: '');
      final a = LocalActivityNotifications(scheduler, () => _texts('de'));
      await a.show(ActivityKind.chat, alert: true);
      await scheduler.replaceAll(const <PlannedReminder>[], title: 'Erinnerung', bodyFor: (_) => '');
      expect(plugin.cancelled, isNot(contains(ActivityKind.chat.id)));
      expect(plugin.cancelledAll, 0, reason: 'replaceAll entfernt nur Geplantes');
      await scheduler.dismiss(ReminderPlanner.stableId('e1', DateTime.utc(2026, 11, 3), 10));
      expect(plugin.cancelled, isNot(contains(ActivityKind.chat.id)));
      await scheduler.cancelAll();
      expect(plugin.cancelledAll, 1);
    });

    test('feste IDs liegen im reservierten Bereich', () {
      for (final k in ActivityKind.values) {
        expect(k.id, lessThan(ReminderPlanner.reservedIds));
      }
    });

    test('requestNotifications ohne Plattform-Implementierung: erlaubt', () async {
      final scheduler = LocalReminderScheduler(_Plugin(), false);
      expect(await scheduler.requestNotifications(), ReminderPermission.granted);
    });
  });
}
