import 'package:url_launcher/url_launcher.dart';

import '../../core/app_log.dart';

/// Öffnet das Mailprogramm mit einem vorbereiteten Entwurf (Einladungslink versenden, E-48).
///
/// Es wird nichts gesendet und kein Empfänger vorgegeben: Betreff und Text landen im Entwurf, den die
/// Person selbst abschickt. Gibt `false` zurück, wenn kein Mailprogramm antwortet.
abstract class MailLauncher {
  Future<bool> compose({required String subject, required String body});
}

class SystemMailLauncher implements MailLauncher {
  const SystemMailLauncher();

  /// Obergrenze für den Entwurf; längere Texte werden von Mailprogrammen uneinheitlich behandelt.
  static const int maxBodyLength = 1800;

  @override
  Future<bool> compose({required String subject, required String body}) async {
    if (body.length > maxBodyLength) return false;
    // `Uri(queryParameters:)` würde Leerzeichen als „+“ schreiben, was manche Mailprogramme wörtlich zeigen.
    final uri = Uri.parse('mailto:?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}');
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      AppLog.e('mail', 'Mailprogramm konnte nicht geöffnet werden', e);
      return false;
    }
  }
}
