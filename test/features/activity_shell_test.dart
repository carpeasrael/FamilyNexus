import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/data/sync/activity_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

class _Platform implements ActivityPlatform {
  final List<ActivityKind> shown = <ActivityKind>[];
  final List<ActivityKind> cancelled = <ActivityKind>[];

  @override
  Future<void> show(ActivityKind kind, {required bool alert, int count = 0}) async => shown.add(kind);

  @override
  Future<void> cancel(ActivityKind kind) async => cancelled.add(kind);
}

/// #254: Der Tab „Einkauf“ räumt die Einkaufsmeldung ab, andere Tabs nicht.
void main() {
  testWidgets('Wechsel auf „Einkauf“ entfernt die Einkaufsmeldung', (tester) async {
    final platform = _Platform();
    final app = await buildTestApp(activity: platform);
    await tester.pumpWidget(FamilyNexusApp(services: app.services));
    await tester.pumpAndSettle();
    final activity = app.services.activity!;
    activity.shoppingArrived();
    expect(platform.shown, <ActivityKind>[ActivityKind.shopping]);

    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Chat')));
    await tester.pumpAndSettle();
    expect(platform.cancelled, isEmpty);

    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Einkauf')));
    await tester.pumpAndSettle();
    expect(platform.cancelled, <ActivityKind>[ActivityKind.shopping]);
  });
}
