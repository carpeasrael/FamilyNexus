import '../../domain/chat.dart';
import '../../domain/family.dart';
import '../../l10n/gen/app_localizations.dart';

/// Fallback-Name für ein Konto, das es nicht mehr gibt. Allein stehend „Ehemaliges Mitglied“; als `{name}` in einem
/// Satz („Von …“, „Nachricht von …“, „… blockieren?“) in Anführungszeichen, damit Kasus und Großschreibung
/// in beiden Sprachen stimmen (#326).
String formerMemberLabel(AppLocalizations l, {bool inSentence = false}) =>
    inSentence ? l.chatFormerMemberQuoted : l.chatFormerMember;

/// Anzeigename des Absenders; leer bedeutet: Konto gelöscht, Name nicht mehr bekannt (#60).
/// [inSentence]: der Name wird in einen Satz eingesetzt (#326).
extension ChatSenderName on ChatMessage {
  String senderLabel(AppLocalizations l, {bool inSentence = false}) =>
      senderName.isEmpty ? formerMemberLabel(l, inSentence: inSentence) : senderName;
}

/// Anzeigename eines Mitglieds in Listen (Aufgaben, Einkauf, Termine). Ist die Person nicht (mehr) in der Familie
/// oder ihr Name unbekannt, steht „Ehemaliges Mitglied“, nie die Matrix-ID (#60, #98).
/// [inSentence]: der Name wird in einen Satz eingesetzt, dann steht der Fallback in Anführungszeichen (#326).
String memberLabel(AppLocalizations l, Family? family, String id, {required String me, bool inSentence = false}) {
  if (id == me) return l.chatYou;
  final name = family?.member(id)?.displayName;
  return name == null || name.isEmpty ? formerMemberLabel(l, inSentence: inSentence) : name;
}
