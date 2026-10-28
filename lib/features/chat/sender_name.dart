import '../../domain/chat.dart';
import '../../l10n/gen/app_localizations.dart';

/// Anzeigename des Absenders; leer bedeutet: Konto gelöscht, Name nicht mehr bekannt (#60).
extension ChatSenderName on ChatMessage {
  String senderLabel(AppLocalizations l) => senderName.isEmpty ? l.chatFormerMember : senderName;
}
