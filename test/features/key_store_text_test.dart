import 'package:family_nexus/domain/data_inventory.dart';
import 'package:family_nexus/features/settings/data_report.dart';
import 'package:family_nexus/l10n/gen/app_localizations_de.dart';
import 'package:family_nexus/l10n/gen/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

/// #169: Im Flatpak nennt die App nicht den Schlüsselbund des Systems.
void main() {
  test('Flatpak-Ablage wird als Sandbox-Ablage benannt, nicht als Schlüsselbund des Systems', () {
    final de = DataReport.keyStoreText(AppLocalizationsDe(), KeyStoreKind.linuxFlatpakPortal);
    final en = DataReport.keyStoreText(AppLocalizationsEn(), KeyStoreKind.linuxFlatpakPortal);
    expect(de, contains('Flatpak'));
    expect(en, contains('Flatpak'));
    for (final t in <String>[de, en]) {
      expect(t, isNot(contains('Secret Service')));
      expect(t.toLowerCase(), isNot(contains('system')));
    }
    expect(DataReport.keyStoreText(AppLocalizationsDe(), KeyStoreKind.linuxSecretService), contains('Secret Service'));
  });
}
