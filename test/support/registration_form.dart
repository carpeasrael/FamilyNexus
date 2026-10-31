import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Kontoanlage: Passwort und Kontrolleingabe (#117).
Future<void> enterNewPassword(WidgetTester tester, String password) async {
  await tester.enterText(find.widgetWithText(TextField, 'Passwort'), password);
  await tester.enterText(find.widgetWithText(TextField, 'Passwort wiederholen'), password);
  await tester.pumpAndSettle();
}
