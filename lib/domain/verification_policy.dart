import 'contacts.dart';

/// Wer darf verifiziert werden und wer darf eine Verifizierung anstoßen (#119, K3b-2b, B8)? Reine Funktion ohne
/// Matrix-Typen, damit Gateway und Test dieselbe Regel nutzen.
///
/// * Eigenes Konto: erlaubt.
/// * Beigetretenes Familienmitglied: erlaubt (wie bisher).
/// * Kontakt außerhalb der Familie: nur bei Datensatz `outgoing` oder `accepted`, nicht blockiert, mit einem Kontakt-
///   Gespräch, dessen Gegenüber beigetreten ist ([contactRoomId] ist der gewählte Raum, sonst `null`), und nur im
///   To-Device-Weg ([roomId] `null`) oder im **gewählten** Kontakt-Raum. Eine Anfrage in einem anderen Raum (Gruppe,
///   verlassener oder zweiter Raum) wird verweigert.
/// * Alles andere: verweigert.
class VerificationPolicy {
  const VerificationPolicy._();

  /// [busy] gilt nur für **eingehende** Anfragen (eine zur Zeit); beim Start nicht übergeben.
  static bool allowed({
    required String userId,
    String? roomId,
    required String me,
    required bool familyJoined,
    ContactState? contactState,
    required bool blocked,
    String? contactRoomId,
    bool busy = false,
  }) {
    if (busy) return false;
    if (userId == me) return true;
    if (familyJoined) return true;
    return contactAllowed(
      contactState: contactState,
      blocked: blocked,
      contactRoomId: contactRoomId,
      roomId: roomId,
      checkRoom: true,
    );
  }

  /// Ob [userId] ein Kontakt ist, dessen Identität geprüft oder dessen Änderung akzeptiert werden darf (ohne Raumbindung,
  /// wenn [checkRoom] `false` ist: Akzeptieren braucht nur den Zustand, nicht den Raum der Anfrage).
  static bool contactAllowed({
    required ContactState? contactState,
    required bool blocked,
    required String? contactRoomId,
    String? roomId,
    bool checkRoom = false,
  }) {
    if (contactState != ContactState.outgoing && contactState != ContactState.accepted) return false;
    if (blocked || contactRoomId == null) return false;
    if (!checkRoom || roomId == null) return true;
    return roomId == contactRoomId;
  }
}
