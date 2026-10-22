import 'package:family_nexus/data/platform/mail_launcher.dart';

class FakeMailLauncher implements MailLauncher {
  /// `false` simuliert ein Gerät ohne Mailprogramm.
  bool available = true;
  final List<({String subject, String body})> drafts = <({String subject, String body})>[];

  @override
  Future<bool> compose({required String subject, required String body}) async {
    if (!available) return false;
    drafts.add((subject: subject, body: body));
    return true;
  }
}
