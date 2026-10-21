/// Nicht vertrauenswürdige Rohdaten eines empfangenen Ereignisses des Familienraums (Kalender, Einkaufsliste).
/// [sender] ist die vom Server/der Verschlüsselung gelieferte Absenderkennung;
/// [content] wird erst vom `EventCodec` geprüft.
sealed class CalendarSignal {
  const CalendarSignal(this.sender, this.timestamp);
  final String sender;
  final DateTime timestamp;
}

/// Geteilter Termin aus dem Familienraum.
class SharedEventSignal extends CalendarSignal {
  const SharedEventSignal(super.sender, super.timestamp, this.content);
  final Map<String, Object?> content;
}

/// Privater Termin aus dem privaten Raum des eigenen Kontos.
class PrivateEventSignal extends CalendarSignal {
  const PrivateEventSignal(super.sender, super.timestamp, this.content);
  final Map<String, Object?> content;
}

class RsvpSignal extends CalendarSignal {
  const RsvpSignal(super.sender, super.timestamp, this.content);
  final Map<String, Object?> content;
}

/// Ein Mitglied ist der Familie beigetreten (Auslöser für den Resync, E-13).
class MemberJoinedSignal extends CalendarSignal {
  const MemberJoinedSignal(super.sender, super.timestamp);
}

/// Eintrag der gemeinsamen Einkaufsliste aus dem Familienraum (E-40).
class ShoppingSignal extends CalendarSignal {
  const ShoppingSignal(super.sender, super.timestamp, this.content);
  final Map<String, Object?> content;
}
