import 'dart:ui';

import 'package:family_nexus/domain/presence.dart';
import 'package:family_nexus/features/presence/presence_view.dart';
import 'package:family_nexus/l10n/gen/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// #326 D9: „Zuletzt online gerade eben“ widersprach sich; unter einer Minute heißt es „Eben noch online“.
void main() {
  final now = DateTime.utc(2026, 11, 8, 12);
  PresenceInfo seenAgo(Duration d) => PresenceInfo(PresenceStatus.offline, now.subtract(d));

  test('de: unter einer Minute „Eben noch online“, danach „Zuletzt online vor …“', () async {
    final l = await AppLocalizations.delegate.load(const Locale('de'));
    expect(presenceLabel(l, seenAgo(Duration.zero), now), 'Eben noch online');
    expect(presenceLabel(l, seenAgo(const Duration(seconds: 59)), now), 'Eben noch online');
    expect(presenceLabel(l, seenAgo(const Duration(seconds: 60)), now), 'Zuletzt online vor 1 Min.');
    expect(presenceLabel(l, seenAgo(const Duration(minutes: 5)), now), 'Zuletzt online vor 5 Min.');
  });

  test('en: „Last online just now“ unter einer Minute', () async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    expect(presenceLabel(l, seenAgo(const Duration(seconds: 59)), now), 'Last online just now');
    expect(presenceLabel(l, seenAgo(const Duration(minutes: 5)), now), startsWith('Last online '));
  });
}
