import 'package:family_nexus/data/matrix/matrix_gateway.dart';
import 'package:family_nexus/features/common/error_text.dart';
import 'package:family_nexus/l10n/gen/app_localizations_de.dart';
import 'package:family_nexus/l10n/gen/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

/// Abbruch beim Anbieter ist ein Hinweis, kein Fehler (#430); echte Fehler bleiben Fehler.
void main() {
  final de = AppLocalizationsDe();
  final en = AppLocalizationsEn();

  test('oauthAborted: Hinweis mit eigenem Text (de, en)', () {
    const e = GatewayException(GatewayError.oauthAborted);
    expect(isNotice(e), isTrue);
    expect(errorText(de, e), 'Die Anmeldung beim Anbieter wurde nicht abgeschlossen. Du kannst es jederzeit noch einmal versuchen.');
    expect(errorText(en, e), 'The sign-in at the provider was not completed. You can try again at any time.');
  });

  test('echte Fehler sind kein Hinweis und behalten ihren Text', () {
    for (final error in GatewayError.values.where((v) => v != GatewayError.oauthAborted)) {
      expect(isNotice(GatewayException(error)), isFalse, reason: '$error');
    }
    expect(isNotice(StateError('x')), isFalse);
    for (final error in <GatewayError>[GatewayError.oauthCancelled, GatewayError.oauthStateMismatch]) {
      expect(errorText(de, GatewayException(error)), 'Die Anmeldung beim Anbieter wurde nicht abgeschlossen. Bitte versuche es noch einmal.');
      expect(errorText(en, GatewayException(error)), 'The sign-in at the provider was not completed. Please try again.');
    }
  });
}
