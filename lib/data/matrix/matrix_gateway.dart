import 'package:flutter/foundation.dart';

import '../../domain/calendar_event.dart';
import '../../domain/calendar_signal.dart';
import '../../domain/chat.dart';
import '../../domain/data_inventory.dart';
import '../../domain/family.dart';
import '../../domain/invite_link.dart';
import '../../domain/moderation.dart';
import '../../domain/presence.dart';
import '../../domain/registration.dart';
import '../../domain/security.dart';
import '../../domain/server.dart';
import '../../domain/shopping.dart';
import '../../domain/tasks.dart';

enum SessionState { loggedOut, ready }

/// Fehlerarten, die die UI lokalisiert darstellt. Enthalten nie Inhalte.
enum GatewayError {
  invalidCredentials,
  serverUnreachable,
  serverUnsupported,
  notAllowed,
  attachmentRejected,
  invalidInput,
  notFound,
  encryptionUnavailable,

  /// Der Server verlangt eine erneute Passwortbestätigung.
  reauthRequired,
  alreadyExists,
  rateLimited,

  // Kontoanlage (E-55)
  usernameTaken,
  usernameInvalid,
  weakPassword,
  registrationDisabled,
  emailInUse,

  /// Die Anmeldung im Browser wurde abgebrochen oder ist abgelaufen.
  oauthCancelled,

  /// Rücksprung gehört nicht zur laufenden Anmeldung (fremder `state`); sie läuft weiter.
  oauthStateMismatch,
  unknown,
}

class GatewayException implements Exception {
  const GatewayException(this.error);
  final GatewayError error;

  @override
  String toString() => 'GatewayException(${error.name})';
}

/// Einzige Schnittstelle zwischen App und Matrix (E-04).
///
/// Zusicherungen aller Implementierungen:
/// * Räume der App sind immer Ende-zu-Ende-verschlüsselt (kein Abschalten).
/// * Rechte (Moderator) werden hier erneut geprüft, nicht nur in der UI.
/// * Fehler enthalten keine Nachrichteninhalte.
abstract class MatrixGateway implements Listenable {
  SessionState get session;
  String? get userId;

  /// Server, an dem die Sitzung läuft (nur wenn angemeldet).
  ServerUrl? get server;

  /// Die Familie des Nutzers oder `null`, solange keine gegründet/beigetreten ist.
  Family? get family;

  /// Nachrichten des Familienchats, älteste zuerst (Kurzform für `messagesIn(ChatThread.familyId)`).
  List<ChatMessage> get messages;

  /// Alle Gespräche: Familienchat zuerst, danach die Einzelchats mit aktuellen Familienmitgliedern
  /// (nach Anzeigename). Einzelchats mit Entfernten oder nicht verschlüsselte Räume fehlen (E-39).
  List<ChatThread> get threads;

  /// Nachrichten eines Gesprächs, älteste zuerst; leer für unbekannte Gespräche.
  List<ChatMessage> messagesIn(String threadId);

  /// `true`, sobald der erste Abgleich mit dem Server stattgefunden hat (oder
  /// lokale Daten einer früheren Sitzung vorliegen). Davor ist „keine Familie“
  /// nicht aussagekräftig.
  bool get initialSyncDone;

  /// Anzahl ungelesener Chatnachrichten aller Gespräche (ohne eigene).
  int get unreadCount;

  /// Ungelesene Nachrichten eines Gesprächs.
  int unreadIn(String threadId);

  /// Markiert ein Gespräch bis zur letzten Nachricht als gelesen (private Lesebestätigung).
  Future<void> markChatRead({String threadId = ChatThread.familyId});

  /// Lädt ältere Nachrichten eines Gesprächs nach (Paginierung).
  Future<void> loadOlderMessages({String threadId = ChatThread.familyId});

  /// Eröffnet einen Einzelchat mit einem beigetretenen Familienmitglied (oder liefert den
  /// vorhandenen) und gibt die Gesprächskennung zurück. Der Raum ist immer verschlüsselt (E-39).
  Future<String> startDirectChat(String userId);

  /// Stellt eine gespeicherte Sitzung wieder her (falls vorhanden).
  Future<void> restore();

  /// Prüft Erreichbarkeit/Protokollversion und ermittelt den Betreiber.
  Future<ServerInfo> probeServer(ServerUrl url);

  Future<void> login({
    required ServerUrl server,
    required String username,
    required String password,
  });

  Future<void> logout();

  // ------------------------------------------------------ Kontoanlage (E-55)

  /// Wie bei [server] ein Konto angelegt wird (klassisch in der App, im Browser oder gar nicht).
  Future<RegistrationOptions> registrationOptions(ServerUrl server);

  /// Ist der Benutzername frei? Netzfehler ergeben `unknown` statt einer Ausnahme.
  Future<UsernameCheck> checkUsername(ServerUrl server, String username);

  /// Startet die klassische Registrierung. Liefert den nächsten Zusatzschritt oder `null`, wenn das
  /// Konto angelegt und die Sitzung bereit ist. Das Passwort bleibt nur im Arbeitsspeicher, bis die
  /// Registrierung endet oder abgebrochen wird.
  Future<RegistrationStage?> register({
    required ServerUrl server,
    required String username,
    required String password,
    required String displayName,

    /// Bevorzugte Sprache für die Bedingungen des Anbieters.
    String language = 'de',
  });

  /// Setzt die laufende Registrierung mit der Antwort der Person fort (wie [register]).
  Future<RegistrationStage?> continueRegistration(RegistrationInput input);

  /// Bricht eine laufende Registrierung ab und vergisst das Passwort.
  void cancelRegistration();

  /// Bereitet die Anmeldung bzw. Kontoanlage ([create]) beim Anbieter im Browser vor (OAuth) und
  /// liefert die zu öffnende Adresse. [redirectUri] ist die Rücksprungadresse der App.
  Future<Uri> startOAuth({required ServerUrl server, required Uri redirectUri, required bool create});

  /// Schließt die Anmeldung mit der Rücksprungadresse ab, die der Browser geöffnet hat.
  /// Fremder `state`: `oauthStateMismatch` (die Anmeldung bleibt offen); Abbruch beim Anbieter oder
  /// fehlender Code: `oauthCancelled`.
  Future<void> completeOAuth(Uri callback);

  /// Setzt den eigenen Anzeigenamen.
  Future<void> setDisplayName(String name);

  /// Gibt alle Ressourcen frei (Datenbank schließen), z. B. vor der vollständigen Löschung.
  Future<void> close();

  /// Gründet die Familie: privater, verschlüsselter Raum (E-12).
  Future<void> createFamily(String name);

  Future<void> sendMessage(String text, {String? replyToId, String threadId = ChatThread.familyId});
  Future<void> sendReaction(String messageId, String emoji, {String threadId = ChatThread.familyId});

  /// Prüft gegen die [AttachmentPolicy] und sendet.
  Future<void> sendAttachment({
    required String fileName,
    required Uint8List bytes,
    String? replyToId,
    String threadId = ChatThread.familyId,
  });

  /// Meldet eine **fremde** Nachricht beim Betreiber des Homeservers (Matrix `report`, E-48). Eigene Nachrichten
  /// und unbekannte Ereignisse werden abgelehnt (`notAllowed`/`notFound`). Übertragen werden nur Raum,
  /// Ereignis-ID und der Grundtext aus [ReportRequest.reason], nie der Nachrichteninhalt.
  Future<void> reportMessage(ReportRequest request);

  /// Wiederholt das Senden einer fehlgeschlagenen Nachricht.
  Future<void> retryMessage(String messageId, {String threadId = ChatThread.familyId});

  // --------------------------------------------- Sicherheit und Verifizierung

  SecurityState get securityState;

  /// Aktualisiert Geräteliste und Schlüsselstatus vom Server.
  Future<void> refreshSecurity();

  /// Alle Geräte des eigenen Kontos.
  List<DeviceEntry> get devices;

  /// Laufende Geräte-/Personenverifizierung (oder `null`).
  VerificationInfo? get verification;

  /// Richtet beim ersten Gerät Schlüssel-Backup und Cross-Signing ein. Verlangt der Server eine
  /// Passwortbestätigung und ist [password] nicht gesetzt, wird `reauthRequired` gemeldet
  /// (das Passwort wird nie gespeichert). Liefert den Wiederherstellungsschlüssel, der
  /// **einmalig** angezeigt werden muss.
  Future<String> setUpSecurity({String? password});

  /// Stellt mit dem Wiederherstellungsschlüssel das Backup wieder her und verifiziert dieses Gerät.
  Future<void> restoreSecurity(String recoveryKey);

  /// Ersetzt den Wiederherstellungsschlüssel durch einen neuen (#11), z. B. wenn der alte verloren ist.
  /// Nur auf einem verifizierten Gerät (sonst `notAllowed`); die Identität bleibt, andere Geräte und
  /// die Familie merken nichts. Der alte Schlüssel schaltet danach keine Geräte mehr frei. Liefert
  /// den neuen Schlüssel, der **einmalig** angezeigt werden muss.
  Future<String> resetRecoveryKey();

  /// Startet eine Emoji-Verifizierung mit einem eigenen Gerät ([deviceId]) oder, ohne
  /// [deviceId], mit einer anderen Person.
  Future<void> startVerification({required String userId, String? deviceId});

  Future<void> acceptVerification();

  /// Antwort auf den Emoji-Vergleich.
  Future<void> confirmEmojiMatch(bool matches);

  Future<void> cancelVerification();

  /// Akzeptiert den geänderten Cross-Signing-Schlüssel eines Mitglieds und hebt die Sperre
  /// seiner Geräte auf. Erst nach persönlicher Prüfung (z. B. Emoji-Vergleich) aufrufen.
  Future<void> acceptIdentityChange(String userId);

  // ------------------------------------------------- Einladungen und Rollen

  /// Offene Einladungen in Räume (noch nicht angenommen).
  List<PendingInvitation> get invitations;

  /// `true`, solange eine eigene Beitrittsanfrage (Knock) auf Bestätigung wartet.
  bool get joinRequestPending;

  /// Die letzte Beitrittsanfrage wurde von einem Moderator abgelehnt (bis [cancelJoinRequest] oder eine neue Anfrage).
  bool get joinRequestRejected;

  /// Zieht die eigene wartende Beitrittsanfrage zurück.
  Future<void> cancelJoinRequest();

  /// Moderator: erzeugt einen zeitlich begrenzten, einmaligen Einladungslink/QR-Inhalt.
  Future<String> createInviteLink({Duration validity = InviteLink.defaultValidity, bool autoApprove = true, String? accountServer});

  /// Sendet eine Beitrittsanfrage für den (geprüften, nicht abgelaufenen) Link.
  Future<void> requestToJoin(InviteLink link);

  /// Beitrittsanfrage über den Familien-Code (Raum-ID) ohne Einladungslink; ein Moderator muss bestätigen (E-65).
  Future<void> requestToJoinByCode(String code);

  /// Moderator: lädt eine Matrix-ID direkt ein.
  Future<void> inviteUser(String userId);

  /// Moderator: bestätigt eine Beitrittsanfrage (→ Einladung); nur mit gültigem eigenem Link.
  Future<void> approveRequest(String userId);

  /// Moderator: lehnt eine Beitrittsanfrage ab oder zieht eine Einladung zurück.
  Future<void> rejectRequest(String userId);

  /// Moderator: ernennt ein Mitglied zum Moderator (Power-Level 50).
  Future<void> promote(String userId);

  /// Moderator: entfernt ein Mitglied; die Raumschlüssel werden rotiert.
  Future<void> removeMember(String userId);

  Future<void> renameFamily(String name);

  /// Nimmt eine Einladung an; ab dann ist der Raum die Familie dieses Kontos.
  Future<void> acceptInvitation(String roomId);

  Future<void> declineInvitation(String roomId);

  // ------------------------------------------------------------ Kalender

  /// Empfangene Kalender-Ereignisse (auch Wiederholungen bereits bekannter und
  /// eigene Echos; der Empfänger muss idempotent sein).
  Stream<CalendarSignal> get calendarSignals;

  /// Sendet einen **geteilten** Termin verschlüsselt in den Familienraum.
  /// Wirft [GatewayException] (`invalidInput`) für nicht geteilte Termine.
  Future<void> publishSharedEvent(CalendarEvent event);

  /// Sendet einen **privaten** Termin ausschließlich in den privaten Raum des
  /// eigenen Kontos (Geräte-Sync). Nie in den Familienraum.
  Future<void> publishPrivateEvent(CalendarEvent event);

  Future<void> publishRsvp(String eventId, RsvpStatus status, DateTime timestamp);

  /// Teilt einen geteilten Termin als Karte im Chat.
  Future<void> shareEventInChat(CalendarEvent event);

  /// Lädt (und entschlüsselt) einen Anhang. Wird nie automatisch geöffnet.
  Future<Uint8List> loadAttachment(String messageId, {String threadId = ChatThread.familyId});

  // ------------------------------------------------------- Online-Status

  /// Letzte bekannte Meldungen der anderen beigetretenen Familienmitglieder (nur Arbeitsspeicher).
  /// Mit [PresenceBoard.evaluate] zum Anzeigezeitpunkt auswerten.
  Map<String, PresenceStamp> get presence;

  /// Meldet den eigenen Zustand als Ende-zu-Ende-verschlüsselte Gerätenachricht an die Geräte der
  /// beigetretenen Familienmitglieder (alle oder nur [onlyTo]). [ask] bittet online befindliche
  /// Geräte um eine Antwort (nur zusammen mit [online]). Es gibt nie einen Klartext-Weg (E-38).
  Future<void> announcePresence({required bool online, bool ask = false, String? onlyTo});

  /// Mitglieder, die um eine Statusantwort gebeten haben.
  Stream<String> get presenceAsks;

  // -------------------------------------------------------- Einkaufszettel

  /// Sendet einen Eintrag der Einkaufsliste verschlüsselt in den Familienraum (E-40).
  Future<void> publishShoppingItem(ShoppingItem item);

  // ----------------------------------------------------------- Aufgabenlisten

  /// Sendet eine Aufgabenliste (Definition) verschlüsselt in den Familienraum (E-51).
  Future<void> publishTaskList(TaskList list);

  /// Sendet einen Protokolleintrag einer Aufgabenliste verschlüsselt in den Familienraum (E-51).
  Future<void> publishTaskLog(TaskLogEntry entry);

  // ------------------------------------------------------------ Datenprotokoll

  /// Bestandsaufnahme der beim Anbieter gespeicherten Daten des Kontos: Profil, Geräte,
  /// Kontodaten-Arten und Räume samt der auf diesem Gerät zwischengespeicherten Ereignisse.
  /// Schlüssel und verschlüsselte Inhalte werden nie ausgegeben. [refresh]: Profil und Geräteliste
  /// vorher beim Anbieter abfragen (sonst nur lokale Daten). Wirft `notAllowed`, wenn abgemeldet.
  Future<OnlineInventory> dataInventory({bool refresh = true});
}
