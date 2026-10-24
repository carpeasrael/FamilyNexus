import '../../domain/invite_link.dart';
import '../../l10n/gen/app_localizations.dart';

/// Verständliche Meldung, warum ein Einladungslink nicht angenommen wird (Issue #6) – mit dem, was die
/// Person tun kann, statt eines allgemeinen „ungültig oder abgelaufen“.
String inviteLinkProblemText(AppLocalizations l, InviteLinkProblem p) => switch (p) {
      InviteLinkProblem.notALink => l.joinLinkNotALink,
      InviteLinkProblem.damaged => l.joinLinkDamaged,
      InviteLinkProblem.expired => l.joinLinkExpired,
      InviteLinkProblem.newerVersion => l.joinLinkNewerVersion,
    };

/// „1 Tag“, „3 Tage“, „7 Tage“.
String inviteValidityText(AppLocalizations l, Duration d) => l.inviteValidityDays(d.inDays);
