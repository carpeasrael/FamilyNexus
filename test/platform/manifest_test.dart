import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

  /// Berechtigungen, die tatsächlich angefordert werden (entfernte Einträge zählen nicht).
  Set<String> permissionsOf(String xml) => RegExp(r'<uses-permission[^>]*>')
      .allMatches(xml)
      .map((m) => m.group(0)!)
      .where((tag) => !tag.contains('tools:node="remove"'))
      .map((tag) => RegExp(r'android:name="([^"]+)"').firstMatch(tag)!.group(1)!)
      .toSet();

  test('Backups und Klartextverkehr sind ausgeschaltet', () {
    expect(manifest, contains('android:allowBackup="false"'));
    expect(manifest, contains('android:usesCleartextTraffic="false"'));
    expect(manifest, contains('android:dataExtractionRules'));
    expect(manifest, contains('android:networkSecurityConfig'));
    final nsc = File('android/app/src/main/res/xml/network_security_config.xml').readAsStringSync();
    expect(nsc, contains('cleartextTrafficPermitted="false"'));
    expect(nsc, isNot(contains('cleartextTrafficPermitted="true"')));
    expect(nsc, isNot(contains('src="user"')), reason: 'keine Nutzer-Zertifikate');
  });

  // Wird je Phase um genau die benötigten Berechtigungen erweitert.
  test('Berechtigungen entsprechen exakt der Freigabeliste', () {
    const allowed = <String>{
      'android.permission.INTERNET',
      'android.permission.POST_NOTIFICATIONS',
      'android.permission.RECEIVE_BOOT_COMPLETED',
      'android.permission.USE_EXACT_ALARM',
      'android.permission.SCHEDULE_EXACT_ALARM',
    };
    expect(permissionsOf(manifest), allowed);
  });

  test('Erinnerungs-Empfänger sind deklariert und nicht exportiert', () {
    for (final r in <String>['ScheduledNotificationReceiver', 'ScheduledNotificationBootReceiver']) {
      final m = RegExp('<receiver[^>]*$r[^>]*>', dotAll: true).firstMatch(manifest);
      expect(m, isNotNull, reason: r);
      expect(m!.group(0), contains('android:exported="false"'), reason: r);
    }
    expect(manifest, contains('android.intent.action.BOOT_COMPLETED'));
  });

  test('Links: nur familynexus://join und der OAuth-Rücksprung, kein http, App-Links nicht automatisch bestätigt', () {
    final filters = RegExp('<intent-filter>.*?</intent-filter>', dotAll: true).allMatches(manifest).map((m) => m.group(0)!).toList();
    final view = filters.where((f) => f.contains('android.intent.action.VIEW')).toList();
    expect(view, hasLength(2));
    final invite = view.singleWhere((f) => f.contains('android:scheme="familynexus"'));
    expect(invite, contains('android:host="join"'));
    final oauth = view.singleWhere((f) => f.contains('android:scheme="io.github.carpeasrael.familynexus"'));
    expect(oauth, contains('android:path="/oauth"'));
    for (final f in view) {
      expect(f, isNot(contains('http')));
      expect(f, isNot(contains('autoVerify')));
    }
    final kotlin = File('android/app/src/main/kotlin/de/inneso/familynexus/MainActivity.kt').readAsStringSync();
    expect(kotlin, contains('data.scheme == "familynexus" && data.host == "join"'));
    expect(kotlin, contains('data.scheme == "io.github.carpeasrael.familynexus" && data.path == "/oauth"'));
    expect(kotlin, contains('text.length <= 2048'));
  });

  test('Debug-/Profil-Manifeste fügen nur INTERNET hinzu (Entwicklung)', () {
    for (final v in <String>['debug', 'profile']) {
      final f = File('android/app/src/$v/AndroidManifest.xml');
      if (!f.existsSync()) continue;
      expect(permissionsOf(f.readAsStringSync()).difference(<String>{'android.permission.INTERNET'}), isEmpty, reason: v);
    }
  });

  test('Backup-Regeln schließen alle Domänen ausdrücklich aus (exclude, nicht include)', () {
    for (final f in <String>['data_extraction_rules.xml', 'backup_rules.xml']) {
      final x = File('android/app/src/main/res/xml/$f').readAsStringSync();
      expect(x, isNot(contains('<include')), reason: f);
      for (final d in <String>['root', 'file', 'database', 'sharedpref']) {
        expect(x, contains('<exclude domain="$d"'), reason: '$f $d');
      }
    }
  });

  test('Release: kein Debug-Signatur-Fallback, Minify, Dart-Obfuskierung im Build-Skript', () {
    final g = File('android/app/build.gradle.kts').readAsStringSync();
    expect(g, contains('isMinifyEnabled = true'));
    expect(g, isNot(contains('getByName("debug")')));
    final script = File('tool/build_release.sh').readAsStringSync();
    expect(script, contains('--obfuscate'));
    expect(script, contains('--split-debug-info'));
  });

  test('FLAG_SECURE wird nativ ab onCreate gesetzt (vor dem ersten Dart-Frame)', () {
    final k = File('android/app/src/main/kotlin/de/inneso/familynexus/MainActivity.kt').readAsStringSync();
    final onCreate = k.substring(k.indexOf('override fun onCreate'), k.indexOf('override fun configureFlutterEngine'));
    expect(onCreate, contains('FLAG_SECURE'));
  });

  test('Link-Kanalname ist in Dart und Kotlin identisch', () {
    final k = File('android/app/src/main/kotlin/de/inneso/familynexus/MainActivity.kt').readAsStringSync();
    final d = File('lib/data/platform/link_source.dart').readAsStringSync();
    expect(k, contains('"de.inneso.familynexus/links"'));
    expect(d, contains("'de.inneso.familynexus/links'"));
  });

  test('Kanalname ist in Dart und Kotlin identisch', () {
    final k = File('android/app/src/main/kotlin/de/inneso/familynexus/MainActivity.kt').readAsStringSync();
    final d = File('lib/data/platform/screen_protection.dart').readAsStringSync();
    const channel = 'de.inneso.familynexus/window';
    expect(k, contains('"$channel"'));
    expect(d, contains("'$channel'"));
  });
}
