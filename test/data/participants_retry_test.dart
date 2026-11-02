import 'package:family_nexus/data/matrix/sdk_matrix_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

/// #135: Wartezeit vor einem neuen Abruf der Mitgliederliste.
void main() {
  Duration after(int n) => SdkMatrixGateway.participantsRetryAfter(n);

  test('1, 2, 4 Minuten, dann gedeckelt bei 15', () {
    expect(after(1), const Duration(minutes: 1));
    expect(after(2), const Duration(minutes: 2));
    expect(after(3), const Duration(minutes: 4));
    expect(after(4), const Duration(minutes: 8));
    expect(after(5), const Duration(minutes: 15));
  });

  test('kein Überlauf nach beliebig vielen Fehlversuchen, nie null oder negativ', () {
    for (final n in <int>[11, 38, 63, 64, 65, 1000, 1 << 40]) {
      expect(after(n), const Duration(minutes: 15), reason: '$n Fehlversuche');
    }
  });

  test('0 oder negativ: Grundwartezeit', () {
    expect(after(0), const Duration(minutes: 1));
    expect(after(-3), const Duration(minutes: 1));
  });

  test('Testwartezeit', () {
    expect(SdkMatrixGateway.participantsRetryAfter(3, base: const Duration(seconds: 1)), const Duration(seconds: 4));
  });
}
