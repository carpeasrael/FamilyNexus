import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// E-103: `tool/check_release_e2e.sh` lässt einen Plattform-Build nur zu, wenn für genau diesen Code-Stand ein
/// E2E-Lauf der Plattform mit Screenshots belegt ist. Die Tests laufen in einem eigenen Git-Repository.
void main() {
  final root = Directory.current.path;
  late Directory repo;

  ProcessResult sh(String cmd) => Process.runSync('bash', ['-c', cmd], workingDirectory: repo.path);

  setUp(() {
    repo = Directory.systemTemp.createTempSync('rel_e2e_');
    Directory('${repo.path}/tool').createSync();
    for (final f in ['check_release_review.sh', 'check_release_e2e.sh']) {
      File('$root/tool/$f').copySync('${repo.path}/tool/$f');
    }
    File('${repo.path}/pubspec.yaml').writeAsStringSync('name: x\nversion: 9.9.9+1\n');
    File('${repo.path}/pubspec.lock').writeAsStringSync('');
    Directory('${repo.path}/lib').createSync();
    File('${repo.path}/lib/a.dart').writeAsStringSync('void main() {}\n');
    final git = sh('git init -q && git add -A && git -c user.name=t -c user.email=t@t commit -qm init');
    expect(git.exitCode, 0, reason: '${git.stderr}');
  });
  tearDown(() => repo.deleteSync(recursive: true));

  String fingerprint() =>
      (sh('tool/check_release_review.sh --print').stdout as String).split('\n').firstWhere((l) => l.startsWith('Fingerabdruck:')).split(': ').last.trim();

  void report({String? fp, String result = 'bestanden', int shots = 3, bool createShots = true, String platform = 'android'}) {
    Directory('${repo.path}/docs/release-e2e').createSync(recursive: true);
    final run = Directory('${repo.path}/User E2E Test Report/lauf1')..createSync(recursive: true);
    File('${run.path}/Testreport.md').writeAsStringSync('# Lauf\n');
    Directory('${run.path}/screenshots').createSync();
    final lines = StringBuffer();
    for (var i = 0; i < shots; i++) {
      lines.writeln('- Screenshot: screenshots/s$i.png');
      if (createShots) File('${run.path}/screenshots/s$i.png').writeAsBytesSync([1, 2, 3]);
    }
    File('${repo.path}/docs/release-e2e/9.9.9+1.md').writeAsStringSync(
        '# Release-E2E 9.9.9+1\n\n- Version: 9.9.9+1\n- Fingerabdruck: ${fp ?? fingerprint()}\n\n## $platform\n- Testlauf: lauf1\n- Ergebnis: $result\n$lines');
  }

  ProcessResult check([String platform = 'android']) => sh('tool/check_release_e2e.sh $platform');

  test('ohne Bericht bricht die Prüfung ab', () {
    final r = check();
    expect(r.exitCode, 1);
    expect(r.stderr, contains('docs/release-e2e/9.9.9+1.md fehlt'));
  });

  test('vollständiger Beleg besteht', () {
    report();
    final r = check();
    expect(r.exitCode, 0, reason: '${r.stderr}');
    expect(r.stdout, contains('3 Screenshots'));
  });

  test('geänderter App-Code bei gleicher Version verlangt einen neuen Lauf', () {
    report();
    File('${repo.path}/lib/a.dart').writeAsStringSync('void main() { print(1); }\n');
    sh('git add -A && git -c user.name=t -c user.email=t@t commit -qm change');
    final r = check();
    expect(r.exitCode, 1);
    expect(r.stderr, contains('passt nicht zum Code'));
  });

  test('Ergebnis nicht "bestanden" sperrt die Plattform', () {
    report(result: 'fehlgeschlagen');
    final r = check();
    expect(r.exitCode, 1);
    expect(r.stderr, contains('verlangt ist "bestanden"'));
  });

  test('weniger als drei Screenshots genügen nicht', () {
    report(shots: 2);
    final r = check();
    expect(r.exitCode, 1);
    expect(r.stderr, contains('mindestens 3'));
  });

  test('genannter Screenshot, der nicht existiert, sperrt', () {
    report(createShots: false);
    final r = check();
    expect(r.exitCode, 1);
    expect(r.stderr, contains('Screenshot fehlt'));
  });

  test('Abschnitt einer anderen Plattform zählt nicht', () {
    report(platform: 'ios');
    final r = check();
    expect(r.exitCode, 1);
    expect(r.stderr, contains('Abschnitt "## android" fehlt'));
  });

  test('mehrere Plattformen: jede braucht ihren Abschnitt', () {
    report(platform: 'ios');
    final r = check('ios macos');
    expect(r.exitCode, 1);
    expect(r.stdout, contains('E2E ios'));
    expect(r.stderr, contains('Abschnitt "## macos" fehlt'));
  });

  test('Pfad aus dem Testlauf heraus wird abgelehnt', () {
    report();
    final f = File('${repo.path}/docs/release-e2e/9.9.9+1.md');
    f.writeAsStringSync(f.readAsStringSync().replaceFirst('screenshots/s0.png', '../../../etc/hosts.png'));
    final r = check();
    expect(r.exitCode, 1);
    expect(r.stderr, contains('Screenshot-Pfad nicht erlaubt'));
  });
}
