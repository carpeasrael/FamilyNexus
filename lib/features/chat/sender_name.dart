import '../../domain/chat.dart';
import '../../domain/family.dart';
import '../../l10n/gen/app_localizations.dart';

/// Anzeigename des Absenders; leer bedeutet: Konto gelöscht, Name nicht mehr bekannt (#60).
extension ChatSenderName on ChatMessage {
  String senderLabel(AppLocalizations l) => senderName.isEmpty ? l.chatFormerMember : senderName;
}

/// Anzeigename eines Mitglieds in Listen (Aufgaben, Einkauf, Termine). Ist die Person nicht (mehr) in der Familie
/// oder ihr Name unbekannt, steht „Ehemaliges Mitglied“, nie die Matrix-ID (#60, #98).
String memberLabel(AppLocalizations l, Family? family, String id, {required String me}) {
  if (id == me) return l.chatYou;
  final name = family?.member(id)?.displayName;
  return name == null || name.isEmpty ? l.chatFormerMember : name;
}
