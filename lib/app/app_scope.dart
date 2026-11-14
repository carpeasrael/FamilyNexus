import 'package:flutter/widgets.dart';

import 'app_services.dart';

/// Stellt die [AppServices] im Widget-Baum bereit.
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});

  final AppServices services;

  static AppServices of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope fehlt im Widget-Baum');
    return scope!.services;
  }

  /// Wie [of], aber ohne `assert`: `null`, wenn kein [AppScope] im Baum steht (z. B. Widget-Tests ohne Scope).
  static AppServices? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()?.services;

  /// Wie [of], aber ohne Abhängigkeit zu registrieren (z. B. in `initState`).
  static AppServices read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope fehlt im Widget-Baum');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => services != oldWidget.services;
}
