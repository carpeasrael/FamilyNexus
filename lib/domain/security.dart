/// Zustand der Geräte- und Schlüsselsicherheit eines Kontos.
enum SecurityState {
  /// Noch nicht ermittelt (nicht angemeldet / Krypto nicht verfügbar).
  unknown,

  /// Neues Konto: Schlüssel-Backup und Cross-Signing müssen eingerichtet werden.
  needsSetup,

  /// Konto ist bereits abgesichert, dieses Gerät aber nicht verifiziert: Verifizierung
  /// mit einem anderen Gerät oder Wiederherstellungsschlüssel nötig.
  needsRestore,

  /// Dieses Gerät ist verifiziert, Schlüssel-Backup besteht.
  ready,
}

class DeviceEntry {
  const DeviceEntry({
    required this.userId,
    required this.deviceId,
    required this.name,
    required this.verified,
    required this.isCurrent,
  });

  final String userId;
  final String deviceId;

  /// Vom Konto vergebener Name (nicht vertrauenswürdig, bereinigt).
  final String name;
  final bool verified;
  final bool isCurrent;
}

enum VerificationPhase {
  /// Eine Anfrage der Gegenseite wartet auf Annahme.
  incomingRequest,

  /// Wir warten auf die Gegenseite.
  waiting,

  /// Emoji vergleichen.
  comparing,

  /// Wir haben bestätigt; die Gegenseite muss noch bestätigen.
  waitingForPeerConfirmation,

  /// Gegenseite muss den Schlüssel/Wiederherstellungsschlüssel eingeben o. Ä. (übersprungen).
  done,
  cancelled,
}

class VerificationEmoji {
  const VerificationEmoji({required this.emoji, required this.name});
  final String emoji;

  /// Englischer Standardname der Matrix-Spezifikation (nur als Vorlesehilfe).
  final String name;
}

class VerificationInfo {
  const VerificationInfo({
    required this.phase,
    required this.peerUserId,
    this.peerDeviceId,
    this.emojis = const <VerificationEmoji>[],
    this.incoming = false,
  });

  final VerificationPhase phase;
  final String peerUserId;
  final String? peerDeviceId;
  final List<VerificationEmoji> emojis;
  final bool incoming;
}
