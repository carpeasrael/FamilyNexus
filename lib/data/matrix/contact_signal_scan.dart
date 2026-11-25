import '../../domain/contacts.dart';

/// Reine Entscheidung, ob ein Ereignis ein `ContactSignal` auslösen darf (#119, K2c, E-114, I3/I4): nur der Typ des
/// Kontaktdatensatzes, nur im **privaten** Raum des eigenen Kontos ([shared] `false`) und nur vom **eigenen** Konto.
/// Der Familienraum erzeugt nie ein Kontaktsignal; fremde, leere oder unbekannte Absender ebenso wenig.
class ContactSignalScan {
  const ContactSignalScan._();

  static bool accepts(String type, String sender, String? me, {required bool shared}) {
    if (shared || type != ContactCodec.type) return false;
    if (me == null || me.isEmpty || sender.isEmpty) return false;
    return sender == me;
  }
}
