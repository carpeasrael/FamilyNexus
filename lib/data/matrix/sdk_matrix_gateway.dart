import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;
import 'dart:math' show Random;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:matrix/encryption.dart';
import 'package:matrix/matrix.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart' as sql;

import '../../core/app_log.dart';
import '../../domain/attachment_policy.dart';
import '../../domain/calendar_event.dart';
import '../../domain/calendar_signal.dart';
import '../../domain/event_codec.dart';
import '../../domain/invite_link.dart';
import '../../domain/invite_ticket.dart';
import '../../domain/moderation.dart';
import '../../domain/permissions.dart';
import '../../domain/presence.dart';
import '../../domain/security.dart';
import '../../domain/chat.dart';
import '../../domain/family.dart';
import '../../domain/server.dart';
import '../../domain/shopping.dart';
import '../../domain/tasks.dart';
import '../../domain/text_sanitizer.dart';
import '../db/app_database.dart';
import '../db/encrypted_db.dart';
import '../platform/key_store.dart';
import 'matrix_gateway.dart';
import 'chat_mapper.dart';
import 'family_room_spec.dart';
import 'https_only_client.dart';
import 'server_probe.dart';

/// Produktive Implementierung auf Basis des Matrix-Dart-SDK (E-01).
///
/// Sicherheitsrelevante Entscheidungen:
/// * SDK-Datenbank: SQLCipher, eigener Schlüssel im Keystore (Linux: Secret Service).
/// * SDK-Logs werden auf AppLog umgeleitet (nur Typ des Fehlers) und nicht gesammelt.
/// * Nachrichten werden ohne Markdown-Parsing und ohne Slash-Befehle gesendet.
/// * Lesebestätigungen sind privat (`receiptsPublicByDefault: false`).
/// * Gesendet wird nur in Räumen mit aktivierter Verschlüsselung.
class SdkMatrixGateway extends ChangeNotifier implements MatrixGateway {
  /// [databaseOpener] und [httpClient] sind nur für Tests gedacht (Host ohne
  /// SQLCipher-Plugin bzw. selbstsigniertes Testzertifikat).
  SdkMatrixGateway({
    required this._keyStore,
    ServerProbe? probe,
    this._dbDirectory,
    @visibleForTesting this._databaseOpener,
    @visibleForTesting http.Client? httpClient,
  })  : _probe = probe ?? ServerProbe(),
        _http = HttpsOnlyClient(httpClient);

  final Future<sql.Database> Function(String path, String key)? _databaseOpener;

  /// Nur für Tests: der zugrunde liegende SDK-Client.
  @visibleForTesting
  Client? get sdkClient => _client;

  static const String matrixDbKeyName = 'db.matrix';
  static const String matrixDbFileName = 'familynexus_matrix.db';

  /// Kontodaten-Schlüssel, der den Familienraum für alle eigenen Geräte benennt.
  static const String familyAccountData = 'de.inneso.familynexus.family';

  /// Kontodaten-Schlüssel des privaten Raums (Geräte-Sync privater Termine, E-09).
  static const String privateAccountData = 'de.inneso.familynexus.private_room';

  /// Zusatzfeld in einer Chatnachricht, die einen geteilten Termin als Karte referenziert.
  static const String eventRefKey = 'de.inneso.familynexus.event_ref';

  static const int backfillPages = 20;
  static const int dmBackfillPages = 3;
  static const int maxMessageLength = 8000;
  static const int maxFamilyNameLength = 60;
  static const int maxRetriesPerEvent = 5;
  static const Duration roomSyncTimeout = Duration(seconds: 30);

  final KeyStore _keyStore;
  final ServerProbe _probe;
  final String? _dbDirectory;

  /// Alle Verbindungen des SDK laufen über diesen Client: nur https, keine Weiterleitungen.
  final HttpsOnlyClient _http;

  Client? _client;
  StreamSubscription<Object?>? _syncSub;
  StreamSubscription<Object?>? _loginSub;
  StreamSubscription<Object?>? _verificationSub;
  KeyVerification? _verification;
  Timer? _debounce;
  Timeline? _timeline;
  String? _timelineRoomId;
  Timeline? _privateTimeline;
  String? _privateTimelineRoomId;

  /// Einzelchats (E-39): Raum-ID → Zeitleiste, Gegenüber, Nachrichten.
  final Map<String, Timeline> _dmTimelines = <String, Timeline>{};
  final Map<String, String> _dmPeers = <String, String>{};
  final Map<String, List<ChatMessage>> _dmMessages = <String, List<ChatMessage>>{};
  final Set<String> _dmJoining = <String>{};
  List<ChatThread> _threads = const <ChatThread>[];

  /// Online-Status der anderen Mitglieder (E-38), nur im Arbeitsspeicher.
  final PresenceBoard _presence = PresenceBoard();
  String? _presenceRoomId;
  final StreamController<String> _presenceAsks = StreamController<String>.broadcast();
  StreamSubscription<Object?>? _toDeviceSub;
  final StreamController<CalendarSignal> _signals = StreamController<CalendarSignal>.broadcast();
  final Set<String> _signaled = <String>{};
  Set<String>? _knownJoined;
  Future<void>? _creatingPrivateRoom;
  bool _participantsRequested = false;
  bool _participantsLoaded = false;
  bool _syncedOnce = false;
  Family? _family;
  List<ChatMessage> _messages = const <ChatMessage>[];
  final Map<String, int> _retries = <String, int>{};
  final Set<String> _retryInFlight = <String>{};

  /// Bei der Serverprüfung bestätigte Basisadresse je Eingabe: Der Login nutzt
  /// genau diese und löst nicht erneut auf (kein Wechsel zwischen Prüfung und Anmeldung).
  final Map<ServerUrl, ServerUrl> _confirmedBase = <ServerUrl, ServerUrl>{};

  @override
  SessionState get session =>
      (_client?.isLogged() ?? false) ? SessionState.ready : SessionState.loggedOut;

  @override
  String? get userId => _client?.userID;

  @override
  ServerUrl? get server {
    final hs = _client?.homeserver;
    return hs == null ? null : ServerUrl.tryParse(hs.toString());
  }

  @override
  Family? get family => _family;

  @override
  List<ChatMessage> get messages => _messages;

  @override
  List<ChatThread> get threads => _threads;

  @override
  List<ChatMessage> messagesIn(String threadId) =>
      threadId == ChatThread.familyId ? _messages : (_dmMessages[threadId] ?? const <ChatMessage>[]);

  @override
  bool get initialSyncDone => _syncedOnce;

  /// Bisher eingegangene Kalendersignale (begrenzt). Neue Zuhörer erhalten sie zuerst,
  /// denn der Kalender startet erst, nachdem die Familie bekannt ist; sonst gingen
  /// Ereignisse aus der Zeit davor verloren. Verarbeitung ist idempotent.
  final List<CalendarSignal> _signalHistory = <CalendarSignal>[];
  static const int maxSignalHistory = 5000;

  void _emit(CalendarSignal s) {
    if (_signalHistory.length >= maxSignalHistory) _signalHistory.removeAt(0);
    _signalHistory.add(s);
    _signals.add(s);
  }

  @override
  Stream<CalendarSignal> get calendarSignals => Stream<CalendarSignal>.multi((controller) {
        for (final s in List<CalendarSignal>.of(_signalHistory)) {
          controller.add(s);
        }
        final sub = _signals.stream.listen(controller.add);
        controller.onCancel = sub.cancel;
      });

  @override
  int get unreadCount => (_familyRoom()?.notificationCount ?? 0) + _dmRooms().fold<int>(0, (a, r) => a + r.notificationCount);

  @override
  int unreadIn(String threadId) => _roomForThread(threadId)?.notificationCount ?? 0;

  @override
  Future<void> markChatRead({String threadId = ChatThread.familyId}) async {
    final room = _roomForThread(threadId);
    final last = _timelineFor(threadId)?.events.where((e) => e.status.isSent).firstOrNull;
    if (room == null || last == null || room.notificationCount == 0) return;
    try {
      await room.setReadMarker(last.eventId, mRead: last.eventId);
    } catch (e) {
      AppLog.e('gateway', 'Gelesen-Markierung fehlgeschlagen', e);
    }
  }

  // ---------------------------------------------------------------- Aufbau

  /// SDK-Logs: nur Fehler-/wtf-Ereignisse und nur der Typ der Ausnahme, nie Titel
  /// oder Text (können Schlüssel, Nachrichten oder IDs enthalten). Die
  /// `print`-Ausgabe des SDK für `wtf` wird in `main()` per Zone verschluckt.
  @visibleForTesting
  static void hardenSdkLogging() => _hardenSdkLogging();

  static void _hardenSdkLogging() {
    final logs = Logs();
    logs.level = Level.wtf;
    logs.onLog = (e) {
      if (e.level.index <= Level.error.index) {
        AppLog.e('sdk', 'SDK-Fehler', e.exception);
      }
      logs.outputEvents.clear();
    };
  }

  Future<Client> _ensureClient() async {
    final existing = _client;
    if (existing != null) return existing;
    _hardenSdkLogging();
    final dir = _dbDirectory ?? await EncryptedDb.databasesPath();
    final path = p.join(dir, matrixDbFileName);
    final key = await AppDatabase.resolveKey(
      keyStore: _keyStore,
      keyName: matrixDbKeyName,
      path: path,
    );
    final opener = _databaseOpener;
    final db = opener != null ? await opener(path, key) : await EncryptedDb.open(path, password: key, version: 1);
    final database = await MatrixSdkDatabase.init('familynexus', database: db);
    final client = Client(
      'FamilyNexus',
      database: database,
      httpClient: _http,
      supportedLoginTypes: <String>{LoginType.mLoginPassword},
      // Nur Emoji-Vergleich (SAS); kein QR-Austausch in dieser Phase.
      verificationMethods: <KeyVerificationMethod>{KeyVerificationMethod.emoji},
      receiptsPublicByDefault: false,
      // Strikt: Nur durch das jeweilige Konto cross-signierte Geräte erhalten Raumschlüssel
      // (Schlüsselsicherung ist in der Einrichtung Pflicht, SA-1 geschlossen).
      shareKeysWith: ShareKeysWith.crossVerified,
      logLevel: Level.wtf,
      // Lücken nach längerer Offline-Zeit werden nachgeladen (sonst gingen Termine verloren).
      requestHistoryOnLimitedTimeline: true,
    );
    _client = client;
    _syncSub = client.onSync.stream.listen((_) {
      if (!_syncedOnce) {
        // „Abgeglichen“ gilt erst, wenn Familie und Sicherheitsstatus aus den ersten Daten berechnet
        // sind; sonst sähe ein bestehendes Mitglied kurz „keine Familie“ und könnte eine zweite gründen.
        _refresh().catchError((Object e) {
          AppLog.e('gateway', 'Erster Abgleich fehlgeschlagen', e);
        }).whenComplete(() {
          _syncedOnce = true;
          notifyListeners();
          _scheduleRefresh();
        });
      }
      _retryFailedSends();
      _scheduleRefresh();
    });
    _loginSub = client.onLoginStateChanged.stream.listen((_) => _scheduleRefresh());
    _verificationSub = client.onKeyVerificationRequest.stream.listen(_onIncomingVerification);
    _toDeviceSub = client.onToDeviceEvent.stream.listen(_onToDevice);
    return client;
  }

  @override
  Future<void> restore() async {
    try {
      final client = await _ensureClient();
      if (!client.isLogged()) {
        await client.init(waitForFirstSync: false);
      }
      // Lokale Daten einer früheren Sitzung gelten als „bereits abgeglichen“.
      if (client.isLogged() && client.prevBatch != null) _syncedOnce = true;
      await _refresh();
    } on KeyLostException {
      rethrow;
    } catch (e) {
      AppLog.e('gateway', 'Sitzung konnte nicht wiederhergestellt werden', e);
      throw _map(e);
    }
  }

  // ------------------------------------------------------------ Verbindung

  @override
  Future<ServerInfo> probeServer(ServerUrl url) async {
    try {
      final info = await _probe.probe(url);
      _confirmedBase[url] = info.url;
      return info;
    } on GatewayException {
      rethrow;
    } catch (e) {
      AppLog.e('gateway', 'Serverprüfung fehlgeschlagen', e);
      throw _map(e);
    }
  }

  static final RegExp _usernameRe = RegExp(r'^[A-Za-z0-9._=\-/+@:]{1,255}$');

  @override
  Future<void> login({
    required ServerUrl server,
    required String username,
    required String password,
  }) async {
    final user = username.trim();
    if (!_usernameRe.hasMatch(user) || password.isEmpty || password.length > 1024) {
      throw const GatewayException(GatewayError.invalidInput);
    }
    try {
      final client = await _ensureClient();
      final base = _confirmedBase[server] ?? await _probe.resolveBase(server);
      // Eigene, geprüfte Auflösung: das SDK darf keine eigene .well-known-Abfrage
      // machen (ungeprüfte Ziele, Weiterleitungen, Zwischenspeicherung).
      await client.checkHomeserver(base.uri, checkWellKnown: false);
      if (client.homeserver?.scheme != 'https') {
        client.homeserver = null;
        throw const GatewayException(GatewayError.serverUnsupported);
      }
      await client.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationUserIdentifier(user: user),
        password: password,
        initialDeviceDisplayName: 'FamilyNexus Android',
      );
      await _refresh();
    } on GatewayException {
      rethrow;
    } catch (e) {
      AppLog.e('gateway', 'Anmeldung fehlgeschlagen', e);
      throw _map(e, forLogin: true);
    }
  }

  @override
  Future<void> close() async {
    _debounce?.cancel();
    _timeline?.cancelSubscriptions();
    _privateTimeline?.cancelSubscriptions();
    await _syncSub?.cancel();
    await _loginSub?.cancel();
    await _verificationSub?.cancel();
    await _toDeviceSub?.cancel();
    _syncSub = null;
    _loginSub = null;
    _verificationSub = null;
    _toDeviceSub = null;
    for (final t in _dmTimelines.values) {
      t.cancelSubscriptions();
    }
    _dmTimelines.clear();
    final c = _client;
    _client = null;
    _timeline = null;
    _privateTimeline = null;
    await c?.dispose();
  }

  @override
  Future<void> logout() async {
    final client = _client;
    if (client == null) return;
    try {
      await client.logout();
    } catch (e) {
      AppLog.w('gateway', 'Serverseitiges Abmelden fehlgeschlagen; lokal bereinigt');
      try {
        await client.clear();
      } catch (e2) {
        AppLog.e('gateway', 'Lokales Bereinigen fehlgeschlagen', e2);
      }
    }
    _resetLocal();
    notifyListeners();
  }

  /// Gemeinsamer Rücksetzpfad für Abmelden und erzwungene Abmeldung
  /// (ungültiges Token): sonst blieben Timeline-Abonnements und Zustände hängen.
  void _resetLocal() {
    _timeline?.cancelSubscriptions();
    _timeline = null;
    _timelineRoomId = null;
    _privateTimeline?.cancelSubscriptions();
    _privateTimeline = null;
    _privateTimelineRoomId = null;
    _resetDirectChats();
    _presence.clear();
    _presenceRoomId = null;
    _signaled.clear();
    _signalHistory.clear();
    _roomTickets.clear();
    _usedTickets.clear();
    _privateRoomIdCache = null;
    _privateVerified = null;
    _joinRequestCache = null;
    _joinRequestCleared = false;
    _knownJoined = null;
    _verification = null;
    _identityChanged.clear();
    _participantsLoaded = false;
    _participantsRequested = false;
    _syncedOnce = false;
    _family = null;
    _messages = const <ChatMessage>[];
    _retries.clear();
    _retryInFlight.clear();
    _confirmedBase.clear();
  }

  // ------------------------------------------------------------- Familie

  /// Familienraum laut Kontodaten, unabhängig vom Beitrittsstatus.
  Room? _familyRoomAnyState() {
    final client = _client;
    if (client == null || !client.isLogged()) return null;
    final id = client.accountData[familyAccountData]?.content['room_id'];
    if (id is! String || !MatrixIds.isRoomId(id)) return null;
    return client.getRoomById(id);
  }

  Room? _familyRoom() {
    final room = _familyRoomAnyState();
    return (room != null && room.membership == Membership.join) ? room : null;
  }

  @override
  Future<void> createFamily(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > maxFamilyNameLength) {
      throw const GatewayException(GatewayError.invalidInput);
    }
    final client = _client;
    if (client == null || !client.isLogged()) throw const GatewayException(GatewayError.notAllowed);
    if (!client.encryptionEnabled) throw const GatewayException(GatewayError.encryptionUnavailable);
    // Eine bestehende (oder angefragte) Familie darf nie überschrieben werden.
    final existing = _familyRoomAnyState();
    if (existing != null && existing.membership != Membership.leave && existing.membership != Membership.ban) {
      throw const GatewayException(GatewayError.alreadyExists);
    }
    try {
      final me = client.userID!;
      final roomId = await client.createRoom(
        name: trimmed,
        roomVersion: FamilyRoomSpec.roomVersion,
        preset: CreateRoomPreset.privateChat,
        visibility: Visibility.private,
        initialState: <StateEvent>[
          for (final s in FamilyRoomSpec.initialState())
            StateEvent(type: s.type, stateKey: '', content: s.content),
        ],
        powerLevelContentOverride: FamilyRoomSpec.powerLevels(me),
      );
      // Verweis sofort schreiben (idempotent, 2 Versuche); sonst bliebe ein verwaister Raum.
      for (var attempt = 0;; attempt++) {
        try {
          await client.setAccountData(me, familyAccountData, <String, Object?>{'room_id': roomId});
          break;
        } catch (e) {
          if (attempt >= 1) rethrow;
        }
      }
      try {
        await client.waitForRoomInSync(roomId, join: true).timeout(roomSyncTimeout);
      } on TimeoutException {
        AppLog.w('gateway', 'Raum noch nicht im Sync; Anzeige folgt beim nächsten Abgleich');
      }
      await _refresh();
    } catch (e) {
      AppLog.e('gateway', 'Familie konnte nicht angelegt werden', e);
      throw _map(e);
    }
  }

  // --------------------------------------------- Sicherheit und Verifizierung

  @override
  SecurityState get securityState {
    final c = _client;
    if (c == null || !c.isLogged() || !c.encryptionEnabled || !_syncedOnce) return SecurityState.unknown;
    final me = c.userID!;
    final hasServerSecurity = c.accountData.containsKey(EventTypes.SecretStorageDefaultKey) ||
        c.userDeviceKeys[me]?.masterKey != null;
    if (!hasServerSecurity) return SecurityState.needsSetup;
    return c.isUnknownSession ? SecurityState.needsRestore : SecurityState.ready;
  }

  @override
  List<DeviceEntry> get devices {
    final c = _client;
    if (c == null || !c.isLogged()) return const <DeviceEntry>[];
    final me = c.userID!;
    final list = c.userDeviceKeys[me]?.deviceKeys.values ?? const Iterable<DeviceKeys>.empty();
    return <DeviceEntry>[
      for (final d in list)
        DeviceEntry(
          userId: me,
          deviceId: TextSanitizer.clean(d.deviceId ?? '', max: 40),
          name: TextSanitizer.clean(d.deviceDisplayName ?? d.deviceId ?? '', max: 40),
          verified: d.deviceId == c.deviceID ? !c.isUnknownSession : d.verified,
          isCurrent: d.deviceId == c.deviceID,
        ),
    ];
  }

  @override
  Future<void> refreshSecurity() async {
    final c = _client;
    if (c == null || !c.isLogged()) return;
    try {
      await c.updateUserDeviceKeys(additionalUsers: <String>{c.userID!});
    } catch (e) {
      AppLog.e('gateway', 'Geräteliste konnte nicht aktualisiert werden', e);
    }
    notifyListeners();
  }

  @visibleForTesting
  KeyVerification? get sdkVerification => _verification;

  @override
  VerificationInfo? get verification {
    final v = _verification;
    if (v == null) return null;
    final peer = TextSanitizer.clean(v.userId, max: 80);
    final dev = v.deviceId == null ? null : TextSanitizer.clean(v.deviceId!, max: 40);
    VerificationPhase phase;
    var emojis = const <VerificationEmoji>[];
    switch (v.state) {
      case KeyVerificationState.askAccept:
        phase = VerificationPhase.incomingRequest;
      case KeyVerificationState.askSas:
        phase = VerificationPhase.comparing;
        emojis = <VerificationEmoji>[for (final e in v.sasEmojis) VerificationEmoji(emoji: e.emoji, name: e.name)];
      case KeyVerificationState.waitingSas:
        phase = VerificationPhase.waitingForPeerConfirmation;
      case KeyVerificationState.done:
        phase = VerificationPhase.done;
      case KeyVerificationState.error:
        phase = VerificationPhase.cancelled;
      default:
        phase = VerificationPhase.waiting;
    }
    return VerificationInfo(
      phase: phase,
      peerUserId: peer,
      peerDeviceId: dev,
      emojis: emojis,
      incoming: !v.startedVerification,
    );
  }

  /// Eingehende Anfragen: nur vom eigenen Konto oder von Mitgliedern der Familie, und nur eine
  /// zur Zeit (S4). Alles andere wird still abgebrochen (`m.user`), ohne Dialog.
  void _onIncomingVerification(KeyVerification v) {
    final f = _family;
    final known = v.userId == _client?.userID || (f != null && f.member(v.userId)?.status == MemberStatus.joined);
    final busy = _verification != null && !_verification!.isDone && _verification!.state != KeyVerificationState.error;
    if (!known || busy) {
      v.cancel('m.user').catchError((Object e) {
        AppLog.w('gateway', 'Verifizierungsanfrage konnte nicht abgelehnt werden');
      }).ignore();
      return;
    }
    _setVerification(v);
  }

  void _setVerification(KeyVerification v) {
    _verification = v;
    v.onUpdate = () {
      // Wir unterstützen nur den Emoji-Vergleich: Auswahl und Schlüsselabfrage automatisch.
      // Nur die Seite, die die Anfrage gestellt hat, sendet den Start (sonst Start-Kollision
      // mit abweichenden Emoji auf beiden Seiten).
      if (v.state == KeyVerificationState.askChoice && v.startedVerification) {
        v.continueVerification(EventTypes.Sas).catchError((Object e) {
          AppLog.e('gateway', 'Verifizierung konnte nicht fortgesetzt werden', e);
        }).ignore();
      } else if (v.state == KeyVerificationState.askSSSS) {
        v.openSSSS(skip: true).catchError((Object e) {
          AppLog.e('gateway', 'Verifizierung konnte nicht abgeschlossen werden', e);
        }).ignore();
      } else if (v.state == KeyVerificationState.done) {
        refreshSecurity().ignore();
      }
      notifyListeners();
    };
    notifyListeners();
  }

  @override
  Future<void> startVerification({required String userId, String? deviceId}) async {
    final c = _client;
    if (c == null || !c.isLogged() || c.encryption == null) throw const GatewayException(GatewayError.encryptionUnavailable);
    if (!MatrixIds.isUserId(userId)) throw const GatewayException(GatewayError.invalidInput);
    if (_verification != null && !_verification!.isDone) throw const GatewayException(GatewayError.alreadyExists);
    try {
      await c.updateUserDeviceKeys(additionalUsers: <String>{userId});
      final KeyVerification v;
      if (deviceId != null) {
        final dev = c.userDeviceKeys[userId]?.deviceKeys[deviceId];
        if (dev == null || dev.deviceId == c.deviceID) throw const GatewayException(GatewayError.notFound);
        v = await dev.startVerification();
      } else {
        final list = c.userDeviceKeys[userId];
        if (list == null) throw const GatewayException(GatewayError.notFound);
        v = await list.startVerification();
      }
      _setVerification(v);
    } on GatewayException {
      rethrow;
    } catch (e) {
      AppLog.e('gateway', 'Verifizierung konnte nicht gestartet werden', e);
      throw _map(e);
    }
  }

  KeyVerification _requireVerification() {
    final v = _verification;
    if (v == null) throw const GatewayException(GatewayError.notFound);
    return v;
  }

  @override
  Future<void> acceptVerification() async {
    final v = _requireVerification();
    try {
      await v.acceptVerification();
    } catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<void> confirmEmojiMatch(bool matches) async {
    final v = _requireVerification();
    try {
      if (matches) {
        await v.acceptSas();
      } else {
        await v.rejectSas();
      }
    } catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<void> cancelVerification() async {
    final v = _verification;
    if (v == null) return;
    try {
      if (!v.isDone) await v.cancel();
    } catch (e) {
      AppLog.e('gateway', 'Abbrechen der Verifizierung fehlgeschlagen', e);
    }
    _verification = null;
    notifyListeners();
  }

  /// Beantwortet die Passwortabfrage des Servers (UIA) beim Hochladen der Cross-Signing-Schlüssel.
  /// Ohne [password] wird die Abfrage abgebrochen und über [onReauthNeeded] gemeldet.
  StreamSubscription<UiaRequest<dynamic>> _answerUiaWithPassword(Client client, String? password, void Function() onReauthNeeded) {
    void answer(UiaRequest<dynamic> uia) {
      if (uia.state != UiaRequestState.waitForUser) return;
      if (!uia.nextStages.contains(AuthenticationTypes.password)) {
        uia.cancel(Exception('Passwort-Stufe nicht angeboten'));
        return;
      }
      if (password == null) {
        onReauthNeeded();
        uia.cancel(Exception('Passwort erforderlich'));
        return;
      }
      uia
          .completeStage(AuthenticationPassword(
            session: uia.session,
            password: password,
            identifier: AuthenticationUserIdentifier(user: client.userID!),
          ))
          .catchError((Object e) {
        AppLog.e('gateway', 'Passwortbestätigung fehlgeschlagen', e);
        return null;
      }).ignore();
    }

    return client.onUiaRequest.stream.listen((uia) {
      uia.onUpdate = (_) => answer(uia);
      answer(uia);
    });
  }

  /// Führt den Bootstrap-Zustandsautomaten des SDK automatisch durch.
  /// [recoveryKey] != null → Wiederherstellung; sonst Ersteinrichtung (liefert den neuen Schlüssel).
  Future<String?> _driveBootstrap(Client client, {String? recoveryKey}) {
    final enc = client.encryption;
    if (enc == null) throw const GatewayException(GatewayError.encryptionUnavailable);
    final done = Completer<String?>();
    String? created;
    var busy = false;
    BootstrapState? lastHandled;
    Bootstrap? current;

    void fail(Object e) {
      if (!done.isCompleted) done.completeError(e);
    }

    Future<void> step() async {
      final bs = current;
      if (bs == null || busy || done.isCompleted) return;
      final state = bs.state;
      if (state == lastHandled && state != BootstrapState.loading) return;
      lastHandled = state;
      busy = true;
      try {
        switch (state) {
          case BootstrapState.loading:
            break;
          case BootstrapState.askWipeSsss:
            // Ersteinrichtung darf bestehende Sicherungen nie überschreiben.
            if (recoveryKey == null) {
              fail(const GatewayException(GatewayError.alreadyExists));
            } else {
              bs.wipeSsss(false);
            }
          case BootstrapState.askUseExistingSsss:
            bs.useExistingSsss(true);
          case BootstrapState.askBadSsss:
            bs.ignoreBadSecrets(true);
          case BootstrapState.askUnlockSsss:
            bs.unlockedSsss();
          case BootstrapState.askNewSsss:
            if (recoveryKey != null) {
              fail(const GatewayException(GatewayError.notFound));
            } else {
              await bs.newSsss();
              created = bs.newSsssKey?.recoveryKey;
            }
          case BootstrapState.openExistingSsss:
            await bs.newSsssKey!.unlock(keyOrPassphrase: recoveryKey);
            await bs.openExistingSsss();
          case BootstrapState.askWipeCrossSigning:
            await bs.wipeCrossSigning(false);
          case BootstrapState.askSetupCrossSigning:
            // Wiederherstellung darf nie eine neue Identität anlegen (würde die alte ersetzen).
            if (recoveryKey != null) {
              fail(const GatewayException(GatewayError.notFound));
              break;
            }
            await bs.askSetupCrossSigning(setupMasterKey: true, setupSelfSigningKey: true, setupUserSigningKey: true);
          case BootstrapState.askWipeOnlineKeyBackup:
            bs.wipeOnlineKeyBackup(false);
          case BootstrapState.askSetupOnlineKeyBackup:
            await bs.askSetupOnlineKeyBackup(true);
          case BootstrapState.error:
            fail(bs.errorResult?.error ?? const GatewayException(GatewayError.unknown));
          case BootstrapState.done:
            if (!done.isCompleted) done.complete(created);
        }
      } catch (e) {
        fail(e);
      } finally {
        busy = false;
      }
      // Weiter, falls sich der Zustand während der Arbeit geändert hat.
      if (!done.isCompleted && bs.state != lastHandled) unawaited(step());
    }

    // Der Konstruktor meldet den Anfangszustand bereits während der Erzeugung.
    current = enc.bootstrap(onUpdate: (b) {
      current = b;
      unawaited(step());
    });
    unawaited(step());
    return done.future;
  }

  @override
  Future<String> setUpSecurity({String? password}) async {
    final c = _client;
    if (c == null || !c.isLogged()) throw const GatewayException(GatewayError.notAllowed);
    if (!c.encryptionEnabled) throw const GatewayException(GatewayError.encryptionUnavailable);
    if (password != null && (password.isEmpty || password.length > 1024)) throw const GatewayException(GatewayError.invalidInput);
    if (securityState != SecurityState.needsSetup) throw const GatewayException(GatewayError.alreadyExists);
    var reauth = false;
    final sub = _answerUiaWithPassword(c, password, () => reauth = true);
    try {
      final key = await _driveBootstrap(c).timeout(const Duration(minutes: 2));
      if (key == null || key.isEmpty) throw const GatewayException(GatewayError.unknown);
      await refreshSecurity();
      return key;
    } on GatewayException {
      rethrow;
    } catch (e) {
      AppLog.e('gateway', 'Einrichtung der Schlüsselsicherung fehlgeschlagen', e);
      if (reauth) throw const GatewayException(GatewayError.reauthRequired);
      if (e is MatrixException && (e.errcode == 'M_FORBIDDEN' || e.errcode == 'M_UNAUTHORIZED')) {
        throw const GatewayException(GatewayError.invalidCredentials);
      }
      throw _map(e);
    } finally {
      await sub.cancel();
    }
  }

  @override
  Future<void> restoreSecurity(String recoveryKey) async {
    final c = _client;
    if (c == null || !c.isLogged()) throw const GatewayException(GatewayError.notAllowed);
    final key = recoveryKey.trim();
    if (key.isEmpty || key.length > 200) throw const GatewayException(GatewayError.invalidInput);
    try {
      await _driveBootstrap(c, recoveryKey: key).timeout(const Duration(minutes: 2));
      await c.encryption!.crossSigning.selfSign(recoveryKey: key);
      try {
        await c.encryption!.keyManager.loadAllKeys();
      } catch (e) {
        AppLog.w('gateway', 'Schlüsselsicherung konnte nicht geladen werden');
      }
      await refreshSecurity();
    } on GatewayException {
      rethrow;
    } catch (e) {
      AppLog.e('gateway', 'Wiederherstellung fehlgeschlagen', e);
      // Falscher Schlüssel: die SDK-Prüfung wirft beim Entsperren (kein Netzwerkfehler).
      if (e is! MatrixException && e is! TimeoutException && e is! StateError && e is! SocketException && e is! http.ClientException) {
        throw const GatewayException(GatewayError.invalidInput);
      }
      throw _map(e);
    }
  }

  // ------------------------------------------------- Einladungen und Rollen

  static const Duration roomOpTimeout = Duration(seconds: 45);

  @override
  List<PendingInvitation> get invitations {
    final client = _client;
    if (client == null || !client.isLogged()) return const <PendingInvitation>[];
    final me = client.userID!;
    return <PendingInvitation>[
      for (final r in client.rooms)
        // Einladungen in Einzelchats (is_direct) sind keine Familieneinladungen (E-39).
        if (r.membership == Membership.invite && r.getState(EventTypes.RoomMember, me)?.content['is_direct'] != true)
          PendingInvitation(
            roomId: r.id,
            roomName: TextSanitizer.clean(r.getLocalizedDisplayname(), max: FamilyRoomSpec.nameMax),
            inviterId: TextSanitizer.clean(r.getState(EventTypes.RoomMember, me)?.senderId ?? '', max: 80),
            requested: _joinRequest()?['room_id'] == r.id,
          ),
    ];
  }

  /// Kontodaten-Schlüssel der eigenen wartenden Beitrittsanfrage. Das SDK liefert den
  /// `knock`-Abschnitt des Syncs nicht aus; deshalb wird die Anfrage hier vermerkt.
  static const String joinRequestAccountData = 'de.inneso.familynexus.join_request';
  static const Duration joinRequestMaxAge = Duration(days: 7);

  String? _joinRequestCache;

  /// Lokal als beendet vermerkt, bis die geänderten Kontodaten per Sync eintreffen.
  bool _joinRequestCleared = false;

  Map<String, Object?>? _joinRequest() {
    final c = _client;
    if (c == null || !c.isLogged() || _joinRequestCleared) return null;
    final raw = c.accountData[joinRequestAccountData]?.content;
    if (raw != null && raw['room_id'] is String && raw['ts'] is int) {
      final age = DateTime.now().toUtc().difference(DateTime.fromMillisecondsSinceEpoch(raw['ts']! as int, isUtc: true));
      if (age < joinRequestMaxAge && !age.isNegative) return raw;
      return null;
    }
    final cached = _joinRequestCache;
    return cached == null ? null : <String, Object?>{'room_id': cached, 'ts': DateTime.now().toUtc().millisecondsSinceEpoch};
  }

  @override
  bool get joinRequestPending => _family == null && _joinRequest() != null;

  Future<void> _clearJoinRequest() async {
    _joinRequestCache = null;
    _joinRequestCleared = true;
    final c = _client;
    if (c == null || !c.isLogged() || c.accountData[joinRequestAccountData]?.content.isEmpty != false) return;
    try {
      await c.setAccountData(c.userID!, joinRequestAccountData, <String, Object?>{});
    } catch (e) {
      AppLog.e('gateway', 'Anfrage-Vermerk nicht entfernt', e);
    }
  }

  @override
  Future<void> cancelJoinRequest() async {
    final client = _client;
    final req = _joinRequest();
    if (client == null || req == null) return;
    try {
      await client.leaveRoom(req['room_id']! as String).timeout(roomOpTimeout);
    } catch (e) {
      AppLog.w('gateway', 'Zurückziehen der Anfrage serverseitig nicht bestätigt');
    }
    await _clearJoinRequest();
    notifyListeners();
  }

  /// Familie und eigene Rolle; Moderatorrechte werden hier erneut geprüft.
  Family _requireFamily() {
    final f = _family;
    if (f == null) throw const GatewayException(GatewayError.notFound);
    return f;
  }

  FamilyMember _requireMember(Family f, String userId) {
    if (!MatrixIds.isUserId(userId)) throw const GatewayException(GatewayError.invalidInput);
    final m = f.member(userId);
    if (m == null) throw const GatewayException(GatewayError.notFound);
    return m;
  }

  /// Vom Moderator ausgegebene Link-IDs (`{id: Ablauf in Unix-Sekunden}`) in den Kontodaten,
  /// damit nur Anfragen mit eigenem, gültigem, einmaligem Link bestätigt werden (S2).
  static const String invitesAccountData = 'de.inneso.familynexus.invites';

  static String _ownHostOf(String userId) => userId.substring(userId.indexOf(':') + 1);

  Map<String, int> _issuedInvites() {
    final raw = _client?.accountData[invitesAccountData]?.content;
    final out = <String, int>{};
    if (raw == null) return out;
    for (final e in raw.entries) {
      final v = e.value;
      if (InviteLink.isNonce(e.key) && v is int) out[e.key] = v;
    }
    return out;
  }

  Future<void> _storeInvites(Map<String, int> invites) async {
    final c = _client;
    if (c == null || !c.isLogged()) return;
    await c.setAccountData(c.userID!, invitesAccountData, <String, Object?>{...invites});
  }

  static String _randomNonce() {
    final r = Random.secure();
    return List<String>.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  @override
  Future<String> createInviteLink({Duration validity = InviteLink.defaultValidity}) async {
    final f = _requireFamily();
    if (!Permissions.canInvite(f)) throw const GatewayException(GatewayError.notAllowed);
    final via = f.roomId.substring(f.roomId.indexOf(':') + 1);
    final now = DateTime.now();
    final nonce = _randomNonce();
    final String link;
    try {
      link = InviteLink.create(
        roomId: f.roomId,
        via: via,
        inviter: f.myUserId,
        now: now,
        validity: validity,
        nonce: nonce,
        ownHost: _ownHostOf(f.myUserId),
      );
    } on ArgumentError {
      throw const GatewayException(GatewayError.invalidInput);
    }
    final nowSec = now.toUtc().millisecondsSinceEpoch ~/ 1000;
    final invites = _issuedInvites()..removeWhere((_, exp) => exp < nowSec - 86400);
    invites[nonce] = now.toUtc().add(validity).millisecondsSinceEpoch ~/ 1000;
    try {
      await _storeInvites(invites);
    } catch (e) {
      AppLog.e('gateway', 'Einladung konnte nicht vermerkt werden', e);
      throw _map(e);
    }
    _roomTickets[nonce] = invites[nonce]!;
    await _publishTicket(InviteTicket(nonce: nonce, expires: invites[nonce]!));
    return link;
  }

  /// Link-IDs, die Moderatoren im Familienraum vermerkt haben (`{id: Ablauf in Unix-Sekunden}`), und
  /// verbrauchte IDs. Ergänzt die eigenen Kontodaten, damit jeder Moderator Anfragen prüfen kann (E-49).
  final Map<String, int> _roomTickets = <String, int>{};
  final Set<String> _usedTickets = <String>{};

  /// Meldet einen Link-Vermerk an die anderen Moderatoren. Scheitert das, bleibt der Link für den
  /// Aussteller selbst gültig; deshalb nur eine Warnung statt eines Fehlers.
  Future<void> _publishTicket(InviteTicket ticket) async {
    final room = _familyRoom();
    if (room == null) return;
    try {
      await _sendCalendar(room, InviteTicket.type, ticket.encode());
    } catch (e) {
      AppLog.w('gateway', 'Link-Vermerk konnte nicht an andere Moderatoren gesendet werden');
    }
  }

  /// Liest die Link-Vermerke aus dem Verlauf des Familienraums. Nur Vermerke von Moderatoren zählen.
  void _readTickets(Room room, Timeline timeline) {
    final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    for (final e in timeline.events) {
      if (e.type != InviteTicket.type || e.redacted || e.status.isError) continue;
      if (room.getPowerLevelByUserId(e.senderId).level < PowerLevels.moderator) continue;
      final t = InviteTicket.decode(e.content, nowSeconds: nowSec);
      if (t == null) continue;
      if (t.used) {
        _usedTickets.add(t.nonce);
      } else {
        _roomTickets[t.nonce] = t.expires;
      }
    }
  }

  /// Beitrittsanfragen: Der Grund enthält die Link-ID (`FamilyNexus:<id>`).
  static const String knockReasonPrefix = 'FamilyNexus:';

  RequestCheck _checkRequest(String? reason) {
    if (reason == null || !reason.startsWith(knockReasonPrefix)) return RequestCheck.unknown;
    final nonce = reason.substring(knockReasonPrefix.length);
    if (!InviteLink.isNonce(nonce)) return RequestCheck.unknown;
    if (_usedTickets.contains(nonce)) return RequestCheck.unknown;
    final exp = _issuedInvites()[nonce] ?? _roomTickets[nonce];
    if (exp == null) return RequestCheck.unknown;
    return DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000 < exp ? RequestCheck.valid : RequestCheck.expired;
  }

  @override
  Future<void> requestToJoin(InviteLink link) async {
    final client = _client;
    if (client == null || !client.isLogged()) throw const GatewayException(GatewayError.notAllowed);
    if (!link.isValidAt(DateTime.now())) throw const GatewayException(GatewayError.invalidInput);
    final existing = _familyRoomAnyState();
    if (existing != null && existing.membership != Membership.leave && existing.membership != Membership.ban) {
      throw const GatewayException(GatewayError.alreadyExists);
    }
    if (ServerUrl.tryParse(link.via) == null) throw const GatewayException(GatewayError.invalidInput);
    if (!InviteLink.viaMatchesRoom(link.roomId, link.via, ownHost: _ownHostOf(client.userID!))) {
      throw const GatewayException(GatewayError.invalidInput);
    }
    try {
      // Das SDK bietet keinen Knock-Aufruf; schmaler Rohaufruf gemäß Matrix-Spezifikation.
      final base = client.homeserver;
      if (base == null || base.scheme != 'https') throw const GatewayException(GatewayError.serverUnsupported);
      final uri = base.replace(
        path: '/_matrix/client/v3/knock/${Uri.encodeComponent(link.roomId)}',
        queryParameters: <String, String>{'server_name': link.via},
      );
      final req = http.Request('POST', uri)
        ..headers['authorization'] = 'Bearer ${client.accessToken}'
        ..headers['content-type'] = 'application/json'
        ..body = json.encode(<String, Object?>{'reason': '$knockReasonPrefix${link.nonce}'});
      final res = await _http.send(req).timeout(roomOpTimeout);
      await res.stream.drain<void>();
      if (res.statusCode == 429) throw const GatewayException(GatewayError.rateLimited);
      if (res.statusCode == 403) throw const GatewayException(GatewayError.notAllowed);
      if (res.statusCode == 404) throw const GatewayException(GatewayError.notFound);
      if (res.statusCode != 200) throw const GatewayException(GatewayError.unknown);
      _joinRequestCache = link.roomId;
      _joinRequestCleared = false;
      await client.setAccountData(client.userID!, joinRequestAccountData, <String, Object?>{
        'room_id': link.roomId,
        'ts': DateTime.now().toUtc().millisecondsSinceEpoch,
      });
      notifyListeners();
      _scheduleRefresh();
    } on GatewayException {
      rethrow;
    } catch (e) {
      AppLog.e('gateway', 'Beitrittsanfrage fehlgeschlagen', e);
      throw _map(e);
    }
  }

  Future<void> _roomOp(Future<void> Function(Room room) op) async {
    final room = _familyRoom();
    if (room == null) throw const GatewayException(GatewayError.notFound);
    try {
      await op(room).timeout(roomOpTimeout);
      _scheduleRefresh();
    } catch (e) {
      AppLog.e('gateway', 'Raumaktion fehlgeschlagen', e);
      throw _map(e);
    }
  }

  @override
  Future<void> inviteUser(String userId) async {
    final f = _requireFamily();
    if (!MatrixIds.isUserId(userId)) throw const GatewayException(GatewayError.invalidInput);
    if (!Permissions.canInvite(f)) throw const GatewayException(GatewayError.notAllowed);
    await _roomOp((room) => room.invite(userId));
  }

  @override
  Future<void> approveRequest(String userId) async {
    final f = _requireFamily();
    final m = _requireMember(f, userId);
    if (!Permissions.canDecideRequest(f, m)) throw const GatewayException(GatewayError.notAllowed);
    // Nur Anfragen mit eigenem, gültigem Link; der Link wird dabei verbraucht (S2).
    if (m.request != RequestCheck.valid) throw const GatewayException(GatewayError.notAllowed);
    await _roomOp((room) => room.invite(userId));
    final nonce = _knockNonces[userId];
    if (nonce != null) {
      _usedTickets.add(nonce);
      await _publishTicket(InviteTicket(nonce: nonce, expires: _roomTickets[nonce] ?? _issuedInvites()[nonce] ?? DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000 + 60, used: true));
      final invites = _issuedInvites()..remove(nonce);
      try {
        await _storeInvites(invites);
      } catch (e) {
        AppLog.w('gateway', 'Verbrauchter Link nicht entfernt');
      }
    }
  }

  @override
  Future<void> rejectRequest(String userId) async {
    final f = _requireFamily();
    final m = _requireMember(f, userId);
    if (!Permissions.canDecideRequest(f, m) && !Permissions.canRemove(f, m)) {
      throw const GatewayException(GatewayError.notAllowed);
    }
    await _roomOp((room) => room.kick(userId));
  }

  @override
  Future<void> promote(String userId) async {
    final f = _requireFamily();
    final m = _requireMember(f, userId);
    if (!Permissions.canPromote(f, m)) throw const GatewayException(GatewayError.notAllowed);
    await _roomOp((room) => room.setPower(userId, PowerLevels.moderator));
  }

  @override
  Future<void> removeMember(String userId) async {
    final f = _requireFamily();
    final m = _requireMember(f, userId);
    if (!Permissions.canRemove(f, m)) throw const GatewayException(GatewayError.notAllowed);
    // Das SDK verwirft beim Weggang eines Mitglieds die ausgehende Megolm-Sitzung;
    // die nächste Nachricht nutzt eine neue Sitzung (Schlüsselrotation).
    await _roomOp((room) => room.kick(userId));
  }

  @override
  Future<void> renameFamily(String name) async {
    final f = _requireFamily();
    final n = name.trim();
    if (n.isEmpty || n.length > FamilyRoomSpec.nameMax) throw const GatewayException(GatewayError.invalidInput);
    if (!Permissions.canConfigure(f)) throw const GatewayException(GatewayError.notAllowed);
    await _roomOp((room) => room.setName(n));
  }

  @override
  Future<void> acceptInvitation(String roomId) async {
    final client = _client;
    if (client == null || !client.isLogged()) throw const GatewayException(GatewayError.notAllowed);
    if (!MatrixIds.isRoomId(roomId)) throw const GatewayException(GatewayError.invalidInput);
    final room = client.getRoomById(roomId);
    if (room == null || room.membership != Membership.invite) throw const GatewayException(GatewayError.notFound);
    final existing = _familyRoomAnyState();
    if (existing != null && existing.membership != Membership.leave && existing.membership != Membership.ban) {
      throw const GatewayException(GatewayError.alreadyExists);
    }
    final previous = client.accountData[familyAccountData]?.content;
    var joined = false;
    try {
      // Zuerst der Vermerk, dann der Beitritt: scheitert der Beitritt, wird der Vermerk zurückgenommen
      // (kein halber Beitritt, K2).
      await client.setAccountData(client.userID!, familyAccountData, <String, Object?>{'room_id': roomId});
      await client.joinRoomById(roomId).timeout(roomOpTimeout);
      joined = true;
      try {
        await client.waitForRoomInSync(roomId, join: true).timeout(roomSyncTimeout);
      } on TimeoutException {
        AppLog.w('gateway', 'Beitritt noch nicht im Sync');
      }
      // Ein fremder Raum ohne Ende-zu-Ende-Verschlüsselung wird nie zur Familie (S5).
      final joinedRoom = client.getRoomById(roomId);
      if (joinedRoom == null || !joinedRoom.encrypted || joinedRoom.getState(EventTypes.Encryption)?.content['algorithm'] != 'm.megolm.v1.aes-sha2') {
        await joinedRoom?.leave();
        throw const GatewayException(GatewayError.encryptionUnavailable);
      }
      await _clearJoinRequest();
      await _refresh();
    } catch (e) {
      AppLog.e('gateway', 'Einladung konnte nicht angenommen werden', e);
      if (!joined || e is GatewayException) {
        try {
          await client.setAccountData(client.userID!, familyAccountData, previous ?? <String, Object?>{});
        } catch (_) {
          AppLog.w('gateway', 'Familienvermerk nicht zurückgesetzt');
        }
      }
      throw _map(e);
    }
  }

  @override
  Future<void> declineInvitation(String roomId) async {
    final client = _client;
    if (client == null || !client.isLogged()) throw const GatewayException(GatewayError.notAllowed);
    if (!MatrixIds.isRoomId(roomId)) throw const GatewayException(GatewayError.invalidInput);
    final room = client.getRoomById(roomId);
    if (room == null || room.membership != Membership.invite) throw const GatewayException(GatewayError.notFound);
    try {
      await room.leave().timeout(roomOpTimeout);
      _scheduleRefresh();
    } catch (e) {
      throw _map(e);
    }
  }

  // --------------------------------------------------------------- Chat

  /// Raum eines Gesprächs: Familienraum oder ein bekannter Einzelchat-Raum.
  Room? _roomForThread(String threadId) {
    if (threadId == ChatThread.familyId) return _familyRoom();
    if (!_dmTimelines.containsKey(threadId)) return null;
    final room = _client?.getRoomById(threadId);
    return (room != null && room.membership == Membership.join) ? room : null;
  }

  Timeline? _timelineFor(String threadId) => threadId == ChatThread.familyId ? _timeline : _dmTimelines[threadId];

  /// Senden nur, wenn der Client Verschlüsselung kann UND der Raum Megolm nutzt.
  /// Das SDK würde sonst stillschweigend im Klartext senden. Einzelchats nur mit aktuellen
  /// Familienmitgliedern (E-39).
  Room _requireEncryptedRoom([String threadId = ChatThread.familyId]) {
    final room = _roomForThread(threadId);
    if (room == null) throw const GatewayException(GatewayError.notFound);
    final client = _client;
    if (client == null || !client.encryptionEnabled || room.encryptionAlgorithm != FamilyRoomSpec.megolm) {
      throw const GatewayException(GatewayError.encryptionUnavailable);
    }
    if (threadId != ChatThread.familyId) {
      final peer = _dmPeers[threadId];
      if (peer == null || _family?.member(peer)?.status != MemberStatus.joined) {
        throw const GatewayException(GatewayError.notAllowed);
      }
    }
    return room;
  }

  bool _canEncryptIn(Room? room) =>
      room != null && (_client?.encryptionEnabled ?? false) && room.encryptionAlgorithm == FamilyRoomSpec.megolm;

  Event? _findEvent(String id, [String threadId = ChatThread.familyId]) {
    final t = _timelineFor(threadId);
    if (t == null) return null;
    for (final e in t.events) {
      if (e.eventId == id) return e;
    }
    return null;
  }

  Event? _replyTarget(String? replyToId, String threadId) {
    if (replyToId == null) return null;
    final e = _findEvent(replyToId, threadId);
    // Nicht stillschweigend ohne Antwortbezug senden.
    if (e == null) throw const GatewayException(GatewayError.notFound);
    return e;
  }

  @override
  Future<void> sendMessage(String text, {String? replyToId, String threadId = ChatThread.familyId}) async {
    if (text.trim().isEmpty || text.length > maxMessageLength) {
      throw const GatewayException(GatewayError.invalidInput);
    }
    final room = _requireEncryptedRoom(threadId);
    final target = _replyTarget(replyToId, threadId);
    try {
      await room.sendTextEvent(
        text,
        inReplyTo: target,
        parseMarkdown: false,
        parseCommands: false,
      );
    } catch (e) {
      AppLog.e('gateway', 'Nachricht konnte nicht gesendet werden', e);
      throw _map(e);
    }
  }

  @override
  Future<void> sendReaction(String messageId, String emoji, {String threadId = ChatThread.familyId}) async {
    if (!TextSanitizer.isReactionKey(emoji)) throw const GatewayException(GatewayError.invalidInput);
    final room = _requireEncryptedRoom(threadId);
    try {
      await room.sendReaction(messageId, emoji);
    } catch (e) {
      // Doppelte Reaktion: der Server lehnt sie ab; das ist kein Fehler für den Nutzer.
      if (e is MatrixException && e.errcode == 'M_DUPLICATE_ANNOTATION') return;
      AppLog.e('gateway', 'Reaktion konnte nicht gesendet werden', e);
      throw _map(e);
    }
  }

  @override
  Future<void> reportMessage(ReportRequest request) async {
    final room = _roomForThread(request.threadId);
    if (room == null) throw const GatewayException(GatewayError.notFound);
    final event = _findEvent(request.messageId, request.threadId);
    if (event == null) throw const GatewayException(GatewayError.notFound);
    if (event.senderId == _client?.userID) throw const GatewayException(GatewayError.notAllowed);
    try {
      await _client!.reportEvent(room.id, event.eventId, reason: request.reason);
    } catch (e) {
      AppLog.e('gateway', 'Meldung konnte nicht gesendet werden', e);
      throw _map(e);
    }
  }

  @override
  Future<void> sendAttachment({
    required String fileName,
    required Uint8List bytes,
    String? replyToId,
    String threadId = ChatThread.familyId,
  }) async {
    final name = AttachmentPolicy.sanitizeFileName(fileName);
    if (AttachmentPolicy.check(fileName: name, bytes: bytes) != null) {
      throw const GatewayException(GatewayError.attachmentRejected);
    }
    final room = _requireEncryptedRoom(threadId);
    final target = _replyTarget(replyToId, threadId);
    try {
      final file = MatrixFile.fromMimeType(
        bytes: bytes,
        name: name,
        mimeType: AttachmentPolicy.mimeForName(name),
      );
      await room.sendFileEvent(file, inReplyTo: target);
    } catch (e) {
      AppLog.e('gateway', 'Anhang konnte nicht gesendet werden', e);
      throw _map(e);
    }
  }

  @override
  Future<void> retryMessage(String messageId, {String threadId = ChatThread.familyId}) async {
    final e = _findEvent(messageId, threadId);
    if (e == null || !e.status.isError) throw const GatewayException(GatewayError.notFound);
    if (!_canEncryptIn(_roomForThread(threadId))) throw const GatewayException(GatewayError.encryptionUnavailable);
    if (!_retryInFlight.add(messageId)) return;
    try {
      await e.sendAgain();
    } catch (err) {
      AppLog.e('gateway', 'Wiederholen fehlgeschlagen', err);
      throw _map(err);
    } finally {
      _retryInFlight.remove(messageId);
    }
  }

  /// Begrenzter Download: bricht ab, sobald mehr als das Limit ankommt (der im
  /// Ereignis behauptete Wert ist nicht vertrauenswürdig).
  Future<Uint8List> _boundedDownload(Uri uri) async {
    final client = _client!;
    final req = http.Request('GET', uri)
      ..headers['authorization'] = 'Bearer ${client.accessToken}';
    final res = await _http.send(req).timeout(const Duration(seconds: 60));
    if (res.statusCode != 200) {
      await res.stream.drain<void>();
      throw const GatewayException(GatewayError.notFound);
    }
    final declared = res.contentLength;
    if (declared != null && declared > AttachmentPolicy.maxBytes + 1024) {
      throw const GatewayException(GatewayError.attachmentRejected);
    }
    final buf = BytesBuilder(copy: false);
    await for (final chunk in res.stream) {
      buf.add(chunk);
      if (buf.length > AttachmentPolicy.maxBytes + 1024) {
        throw const GatewayException(GatewayError.attachmentRejected);
      }
    }
    return buf.takeBytes();
  }

  @override
  Future<Uint8List> loadAttachment(String messageId, {String threadId = ChatThread.familyId}) async {
    final e = _findEvent(messageId, threadId);
    if (e == null) throw const GatewayException(GatewayError.notFound);
    final size = e.content.tryGetMap<String, Object?>('info')?.tryGet<int>('size');
    final mime = e.attachmentMimetype.toLowerCase();
    if (size == null || !AttachmentPolicy.incomingAllowed(mimeType: mime, size: size)) {
      throw const GatewayException(GatewayError.attachmentRejected);
    }
    try {
      final file = await e.downloadAndDecryptAttachment(downloadCallback: _boundedDownload);
      if (file.bytes.length > AttachmentPolicy.maxBytes ||
          !AttachmentPolicy.contentMatches(mime, file.bytes)) {
        throw const GatewayException(GatewayError.attachmentRejected);
      }
      return file.bytes;
    } on GatewayException {
      rethrow;
    } catch (err) {
      AppLog.e('gateway', 'Anhang konnte nicht geladen werden', err);
      throw _map(err);
    }
  }

  @override
  Future<void> loadOlderMessages({String threadId = ChatThread.familyId}) async {
    final t = _timelineFor(threadId);
    if (t == null || !t.canRequestHistory) return;
    try {
      await t.requestHistory();
    } catch (e) {
      AppLog.e('gateway', 'Ältere Nachrichten konnten nicht geladen werden', e);
    }
  }

  // ------------------------------------------------------------ Zustand

  void _scheduleRefresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () {
      _refresh().ignore();
    });
  }

  /// Automatisches Wiederholen nach einem Sync: höchstens [maxRetriesPerEvent]-mal,
  /// nie parallel für dasselbe Ereignis und nur, wenn Verschlüsselung gesichert ist.
  void _retryFailedSends() {
    final me = _client?.userID;
    if (me == null) return;
    final lines = <(Timeline, Room?)>[
      if (_timeline != null) (_timeline!, _familyRoom()),
      for (final e in _dmTimelines.entries) (e.value, _roomForThread(e.key)),
    ];
    for (final (t, room) in lines) {
      if (!_canEncryptIn(room)) continue;
      for (final e in t.events) {
        if (e.senderId != me || !e.status.isError) {
          _retries.remove(e.eventId);
          continue;
        }
        final tries = _retries[e.eventId] ?? 0;
        if (tries >= maxRetriesPerEvent || !_retryInFlight.add(e.eventId)) continue;
        _retries[e.eventId] = tries + 1;
        e.sendAgain().catchError((Object err) {
          AppLog.e('gateway', 'Automatisches Wiederholen fehlgeschlagen', err);
          return null;
        }).whenComplete(() => _retryInFlight.remove(e.eventId)).ignore();
      }
    }
  }

  Future<void>? _refreshRun;
  bool _refreshAgain = false;

  /// Zustandsabgleich, nie parallel: Ein Aufruf während eines laufenden Abgleichs löst genau
  /// einen weiteren Durchlauf aus und wartet auf dessen Ende.
  Future<void> _refresh() {
    final running = _refreshRun;
    if (running != null) {
      _refreshAgain = true;
      return running;
    }
    final done = Completer<void>();
    _refreshRun = done.future;
    () async {
      try {
        do {
          _refreshAgain = false;
          await _refreshOnce();
        } while (_refreshAgain);
        done.complete();
      } catch (e) {
        done.completeError(e);
      } finally {
        _refreshRun = null;
      }
    }();
    // Ohne Zuhörer (z. B. entprellter Abgleich) darf ein Fehler nicht unbehandelt bleiben.
    done.future.ignore();
    return done.future;
  }

  Future<void> _refreshOnce() async {
    final client = _client;
    if (client == null || !client.isLogged()) {
      _resetLocal();
      notifyListeners();
      return;
    }
    final room = _familyRoom();
    if (room == null) {
      _timeline?.cancelSubscriptions();
      _timeline = null;
      _timelineRoomId = null;
      _participantsRequested = false;
      _family = null;
      _messages = const <ChatMessage>[];
      _resetDirectChats();
      _presence.clear();
      _presenceRoomId = null;
      notifyListeners();
      return;
    }
    if (!_participantsRequested) {
      _participantsRequested = true;
      room.requestParticipants().then((_) {
        _participantsLoaded = true;
        _scheduleRefresh();
      }).catchError((Object e) {
        AppLog.e('gateway', 'Mitglieder konnten nicht geladen werden', e);
      }).ignore();
    }
    if (_timelineRoomId != room.id) {
      _timeline?.cancelSubscriptions();
      _timeline = await room.getTimeline(
        onUpdate: _scheduleRefresh,
        onInsert: (_) => _scheduleRefresh(),
        onChange: (_) => _scheduleRefresh(),
        onRemove: (_) => _scheduleRefresh(),
        onNewEvent: _scheduleRefresh,
      );
      _timelineRoomId = room.id;
      _backfill(_timeline!).ignore();
    }
    _readTickets(room, _timeline!);
    _family = _buildFamily(room, client.userID!);
    _messages = ChatMapper.messages(_timeline!);
    if (_presenceRoomId != room.id) {
      // Andere Familie: der Status der alten gilt nicht weiter.
      _presence.clear();
      _presenceRoomId = room.id;
    }
    if (_participantsLoaded) {
      _presence.retainOnly(<String>{for (final m in _family!.joined) m.userId});
    }
    await _syncDirectChats(client, _family!, room);
    _acceptDirectInvites(client, _family!);
    // Erst nach vollständig geladener Mitgliederliste als Basis (Lazy Loading liefert anfangs nur Teile).
    if (_participantsLoaded) _emitMemberJoins(_family!);
    await _ensurePrivateTimeline(client);
    _scanForSignals(_timeline, shared: true);
    _scanForSignals(_privateTimeline, shared: false);
    notifyListeners();
  }

  // ----------------------------------------------------------- Kalender

  /// Erster Stand der Mitglieder ist die Basis; nur spätere Beitritte lösen den
  /// Resync aus.
  void _emitMemberJoins(Family f) {
    final now = f.joined.map((m) => m.userId).toSet();
    final before = _knownJoined;
    _knownJoined = now;
    if (before == null) return;
    for (final id in now.difference(before)) {
      if (id != f.myUserId) _emit(MemberJoinedSignal(id, DateTime.now().toUtc()));
    }
  }

  Room? _privateRoom() {
    final client = _client;
    if (client == null || !client.isLogged()) return null;
    // Kontodaten treffen lokal erst mit dem nächsten Sync ein; bis dahin gilt die gemerkte ID.
    final fromAccount = client.accountData[privateAccountData]?.content['room_id'];
    final id = fromAccount is String ? fromAccount : _privateRoomIdCache;
    if (id == null || !MatrixIds.isRoomId(id)) return null;
    final room = client.getRoomById(id);
    return (room != null && room.membership == Membership.join) ? room : null;
  }

  String? _privateRoomIdCache;

  Future<void> _ensurePrivateTimeline(Client client) async {
    final room = _privateRoom();
    if (room == null) {
      _privateTimeline?.cancelSubscriptions();
      _privateTimeline = null;
      _privateTimelineRoomId = null;
      return;
    }
    if (_privateTimelineRoomId == room.id) return;
    _privateTimeline?.cancelSubscriptions();
    _privateTimeline = await room.getTimeline(
      onUpdate: _scheduleRefresh,
      onInsert: (_) => _scheduleRefresh(),
      onChange: (_) => _scheduleRefresh(),
      onNewEvent: _scheduleRefresh,
    );
    _privateTimelineRoomId = room.id;
    _backfill(_privateTimeline!).ignore();
  }

  /// Lädt ältere Ereignisse nach, damit ein neues Gerät den bisherigen Bestand
  /// erhält (begrenzt auf [backfillPages] Seiten).
  Future<void> _backfill(Timeline t, {int pages = backfillPages}) async {
    try {
      for (var i = 0; i < pages && t.canRequestHistory; i++) {
        await t.requestHistory();
      }
      _scheduleRefresh();
    } catch (e) {
      AppLog.e('gateway', 'Nachladen des Verlaufs fehlgeschlagen', e);
    }
  }

  void _scanForSignals(Timeline? t, {required bool shared}) {
    if (t == null) return;
    for (final e in t.events.reversed) {
      if (e.redacted || e.status.isError || !_signaled.add(e.eventId)) continue;
      final c = e.content;
      if (shared && e.type == EventCodec.sharedType) {
        _emit(SharedEventSignal(e.senderId, e.originServerTs, c));
      } else if (shared && e.type == EventCodec.rsvpType) {
        _emit(RsvpSignal(e.senderId, e.originServerTs, c));
      } else if (shared && e.type == ShoppingCodec.type) {
        _emit(ShoppingSignal(e.senderId, e.originServerTs, c));
      } else if (shared && e.type == TaskCodec.listType) {
        _emit(TaskListSignal(e.senderId, e.originServerTs, c));
      } else if (shared && e.type == TaskCodec.logType) {
        _emit(TaskLogSignal(e.senderId, e.originServerTs, c));
      } else if (!shared && e.type == EventCodec.privateType) {
        _emit(PrivateEventSignal(e.senderId, e.originServerTs, c));
      } else if (e.type == EventTypes.Encrypted) {
        // Noch nicht entschlüsselt: später erneut betrachten.
        _signaled.remove(e.eventId);
      }
    }
  }

  Future<void> _ensurePrivateRoom() async {
    if (_privateRoom() != null) return;
    final client = _client;
    if (client == null || !client.isLogged()) throw const GatewayException(GatewayError.notAllowed);
    if (!client.encryptionEnabled) throw const GatewayException(GatewayError.encryptionUnavailable);
    if (!_syncedOnce) throw const GatewayException(GatewayError.serverUnreachable);
    // Nur ein gleichzeitiger Anlegevorgang pro Gerät.
    return _creatingPrivateRoom ??= () async {
      try {
        final me = client.userID!;
        final roomId = await client.createRoom(
          name: 'FamilyNexus',
          roomVersion: FamilyRoomSpec.roomVersion,
          preset: CreateRoomPreset.privateChat,
          visibility: Visibility.private,
          initialState: <StateEvent>[
            StateEvent(
              type: 'm.room.encryption',
              stateKey: '',
              content: <String, Object?>{'algorithm': FamilyRoomSpec.megolm},
            ),
            StateEvent(
              type: 'm.room.history_visibility',
              stateKey: '',
              content: <String, Object?>{'history_visibility': 'shared'},
            ),
          ],
        );
        await client.setAccountData(me, privateAccountData, <String, Object?>{'room_id': roomId});
        _privateRoomIdCache = roomId;
        try {
          await client.waitForRoomInSync(roomId, join: true).timeout(roomSyncTimeout);
        } on TimeoutException {
          AppLog.w('gateway', 'Privater Raum noch nicht im Sync');
        }
      } finally {
        _creatingPrivateRoom = null;
      }
    }();
  }

  String? _privateVerified;

  /// „Privat nie senden“ hängt nicht allein am Kontodaten-Zeiger: Der Raum darf nicht
  /// der Familienraum sein und außer dem eigenen Konto kein weiteres Mitglied haben.
  Future<void> _verifyPrivateRoom(Room room) async {
    final me = _client!.userID!;
    if (room.id == _familyRoom()?.id) throw const GatewayException(GatewayError.notAllowed);
    if (_privateVerified != room.id) {
      await room.requestParticipants();
      _privateVerified = room.id;
    }
    final others = room.getParticipants().where((u) =>
        u.id != me &&
        (u.membership == Membership.join || u.membership == Membership.invite || u.membership == Membership.knock));
    if (others.isNotEmpty) {
      AppLog.e('gateway', 'Privater Raum hat weitere Mitglieder – Senden verweigert');
      throw const GatewayException(GatewayError.notAllowed);
    }
  }

  Future<String?> _sendCalendar(Room room, String type, Map<String, Object?> content) async {
    if (!(_client?.encryptionEnabled ?? false) || room.encryptionAlgorithm != FamilyRoomSpec.megolm) {
      throw const GatewayException(GatewayError.encryptionUnavailable);
    }
    final id = await room.sendEvent(content, type: type);
    // `null` = das SDK hat nach Wiederholungen aufgegeben.
    if (id == null) throw const GatewayException(GatewayError.serverUnreachable);
    return id;
  }

  @override
  Future<void> publishSharedEvent(CalendarEvent event) async {
    final room = _requireEncryptedRoom();
    final Map<String, Object?> content;
    try {
      content = EventCodec.encodeShared(event);
    } on StateError {
      throw const GatewayException(GatewayError.invalidInput);
    }
    try {
      await _sendCalendar(room, EventCodec.sharedType, content);
    } on GatewayException {
      rethrow;
    } catch (e) {
      AppLog.e('gateway', 'Geteilter Termin konnte nicht gesendet werden', e);
      throw _map(e);
    }
  }

  @override
  Future<void> publishPrivateEvent(CalendarEvent event) async {
    final Map<String, Object?> content;
    try {
      content = EventCodec.encodePrivate(event);
    } on StateError {
      throw const GatewayException(GatewayError.invalidInput);
    }
    try {
      await _ensurePrivateRoom();
      final room = _privateRoom();
      if (room == null) throw const GatewayException(GatewayError.serverUnreachable);
      await _verifyPrivateRoom(room);
      await _sendCalendar(room, EventCodec.privateType, content);
    } on GatewayException {
      rethrow;
    } catch (e) {
      AppLog.e('gateway', 'Privater Termin konnte nicht gesendet werden', e);
      throw _map(e);
    }
  }

  @override
  Future<void> publishRsvp(String eventId, RsvpStatus status, DateTime timestamp) async {
    final room = _requireEncryptedRoom();
    try {
      await _sendCalendar(room, EventCodec.rsvpType, EventCodec.encodeRsvp(eventId, status, timestamp));
    } on GatewayException {
      rethrow;
    } on StateError {
      throw const GatewayException(GatewayError.invalidInput);
    } catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<void> shareEventInChat(CalendarEvent event) async {
    if (!event.isShared || event.deleted) throw const GatewayException(GatewayError.invalidInput);
    final room = _requireEncryptedRoom();
    try {
      await _sendCalendar(room, EventTypes.Message, <String, Object?>{
        'msgtype': MessageTypes.Text,
        'body': TextSanitizer.clean(event.title, max: 120),
        eventRefKey: event.id,
      });
    } on GatewayException {
      rethrow;
    } catch (e) {
      throw _map(e);
    }
  }

  // ------------------------------------------------------ Einzelchats (E-39)

  Iterable<Room> _dmRooms() => _dmTimelines.keys.map(_roomForThread).whereType<Room>();

  void _resetDirectChats() {
    for (final t in _dmTimelines.values) {
      t.cancelSubscriptions();
    }
    _dmTimelines.clear();
    _dmPeers.clear();
    _dmMessages.clear();
    _dmJoining.clear();
    _dmFailed.clear();
    _dmRetryAfter.clear();
    _dmCreating.clear();
    _dmEpoch++;
    _threads = const <ChatThread>[];
  }

  final Set<String> _dmCreating = <String>{};

  /// Dauerhaft ungeeignete Räume (z. B. unverschlüsselt, mit Dritten) und Räume mit vorläufigem
  /// Fehler (erneuter Versuch frühestens zur genannten Zeit).
  final Set<String> _dmFailed = <String>{};
  final Map<String, DateTime> _dmRetryAfter = <String, DateTime>{};

  /// Wird bei jedem Zurücksetzen erhöht: Abläufe, die über ein `await` hinweg laufen, verwerfen
  /// ihr Ergebnis, wenn sich die Epoche geändert hat (Abmelden, Familienwechsel).
  int _dmEpoch = 0;

  /// Ein Einzelchat-Raum hat genau zwei Mitglieder (beigetreten oder eingeladen).
  static bool _isPairRoom(Room r) {
    final joined = r.summary.mJoinedMemberCount;
    final invited = r.summary.mInvitedMemberCount ?? 0;
    return joined != null && joined + invited <= 2;
  }

  /// Verschlüsselte Einzelchat-Räume mit aktuellen, beigetretenen Familienmitgliedern
  /// (Raum-ID → Gegenüber). Bei mehreren Räumen für dasselbe Gegenüber gilt der mit der
  /// kleinsten Raum-ID, damit beide Seiten denselben Raum wählen.
  Map<String, String> _eligibleDirectRooms(Client client, Family f, Room familyRoom) {
    final byPeer = <String, String>{};
    final privateId = _privateRoom()?.id;
    for (final r in client.rooms) {
      if (r.membership != Membership.join || r.id == familyRoom.id || r.id == privateId) continue;
      final peer = r.directChatMatrixID;
      if (peer == null || peer == f.myUserId || f.member(peer)?.status != MemberStatus.joined) continue;
      if (!_canEncryptIn(r) || !_isPairRoom(r)) continue;
      final cur = byPeer[peer];
      if (cur == null || r.id.compareTo(cur) < 0) byPeer[peer] = r.id;
    }
    return <String, String>{for (final e in byPeer.entries) e.value: e.key};
  }

  Future<void> _syncDirectChats(Client client, Family f, Room familyRoom) async {
    // Erst nach vollständig geladener Mitgliederliste (Lazy Loading liefert anfangs nur Teile),
    // sonst würden Einzelchats kurz verschwinden.
    if (_participantsLoaded) {
      final eligible = _eligibleDirectRooms(client, f, familyRoom);
      for (final id in _dmTimelines.keys.toList()) {
        if (!eligible.containsKey(id)) {
          _dmTimelines.remove(id)?.cancelSubscriptions();
          _dmPeers.remove(id);
          _dmMessages.remove(id);
        }
      }
      for (final e in eligible.entries) {
        _dmPeers[e.key] = e.value;
        if (_dmTimelines.containsKey(e.key) || !_dmCreating.add(e.key)) continue;
        final room = client.getRoomById(e.key);
        if (room == null) {
          _dmCreating.remove(e.key);
          continue;
        }
        final epoch = _dmEpoch;
        try {
          final t = await room.getTimeline(
            onUpdate: _scheduleRefresh,
            onInsert: (_) => _scheduleRefresh(),
            onChange: (_) => _scheduleRefresh(),
            onRemove: (_) => _scheduleRefresh(),
            onNewEvent: _scheduleRefresh,
          );
          if (epoch != _dmEpoch || _client != client) {
            // Zwischenzeitlich abgemeldet oder Familie gewechselt: Ergebnis verwerfen.
            t.cancelSubscriptions();
            return;
          }
          _dmTimelines[e.key] = t;
          _backfill(t, pages: dmBackfillPages).ignore();
        } catch (err) {
          // Ein defekter Einzelchat darf Kalender- und Einkaufsabgleich nicht blockieren.
          AppLog.e('gateway', 'Einzelchat konnte nicht geladen werden', err);
        } finally {
          _dmCreating.remove(e.key);
        }
      }
      for (final e in _dmTimelines.entries) {
        _dmMessages[e.key] = ChatMapper.messages(e.value);
      }
    }
    final dms = <ChatThread>[
      for (final e in _dmPeers.entries)
        if (_dmTimelines.containsKey(e.key))
          ChatThread(
            id: e.key,
            kind: ThreadKind.direct,
            title: f.member(e.value)?.displayName ?? e.value,
            peerId: e.value,
            unread: client.getRoomById(e.key)?.notificationCount ?? 0,
          ),
    ]..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    _threads = <ChatThread>[
      ChatThread(id: ChatThread.familyId, kind: ThreadKind.family, title: f.name, unread: familyRoom.notificationCount),
      ...dms,
    ];
  }

  /// Einladungen in Einzelchats werden nur angenommen, wenn der Einladende ein beigetretenes
  /// Familienmitglied ist. Alle anderen werden ignoriert (nie angenommen, nie angezeigt).
  void _acceptDirectInvites(Client client, Family f) {
    if (!_participantsLoaded) return;
    final me = f.myUserId;
    for (final r in client.rooms) {
      if (r.membership != Membership.invite || _dmFailed.contains(r.id)) continue;
      final retry = _dmRetryAfter[r.id];
      if (retry != null && DateTime.now().isBefore(retry)) continue;
      final inv = r.getState(EventTypes.RoomMember, me);
      if (inv == null || inv.content['is_direct'] != true) continue;
      final from = inv.senderId;
      if (from == me || f.member(from)?.status != MemberStatus.joined || _identityChanged.contains(from)) continue;
      // Höchstens ein Einzelchat je anderem Mitglied und wenige gleichzeitige Beitritte.
      if (_dmTimelines.length + _dmJoining.length >= f.joined.length || _dmJoining.length >= 4) continue;
      // Pro Mitglied nur ein Einzelchat: weitere Einladungen desselben Einladenden werden ignoriert.
      if (_dmPeers.values.contains(from)) continue;
      if (!_dmJoining.add(r.id)) continue;
      _joinDirect(r).whenComplete(() => _dmJoining.remove(r.id)).ignore();
    }
  }

  Future<void> _joinDirect(Room r) async {
    try {
      await r.join(waitForSync: true).timeout(roomOpTimeout);
      final joined = _client?.getRoomById(r.id);
      // Ein nicht verschlüsselter Raum oder einer mit weiteren Mitgliedern wird nie genutzt:
      // sofort wieder verlassen.
      if (joined == null || !_canEncryptIn(joined) || !_isPairRoom(joined)) {
        _dmFailed.add(r.id);
        await joined?.removeFromDirectChat();
        await joined?.leave();
        return;
      }
      _scheduleRefresh();
    } catch (e) {
      // Vorläufiger Fehler (Netz, Zeitüberschreitung): später erneut versuchen.
      _dmRetryAfter[r.id] = DateTime.now().add(const Duration(minutes: 1));
      AppLog.e('gateway', 'Einzelchat konnte nicht angenommen werden', e);
    }
  }

  @override
  Future<String> startDirectChat(String userId) async {
    final f = _requireFamily();
    final client = _client;
    if (client == null || !client.isLogged()) throw const GatewayException(GatewayError.notAllowed);
    final m = _requireMember(f, userId);
    if (userId == f.myUserId || m.status != MemberStatus.joined) throw const GatewayException(GatewayError.notAllowed);
    for (final e in _dmPeers.entries) {
      if (e.value == userId && _dmTimelines.containsKey(e.key)) return e.key;
    }
    if (!client.encryptionEnabled) throw const GatewayException(GatewayError.encryptionUnavailable);
    try {
      // Nie einen vorhandenen, womöglich unverschlüsselten Raum wiederverwenden.
      // Ohne eigene Zeitschranke: ein Abbruch zwischen Anlegen und Eintrag in `m.direct` würde einen
      // Raum hinterlassen, den nur die Gegenseite sieht.
      final roomId = await client.startDirectChat(
        userId,
        enableEncryption: true,
        skipExistingChat: true,
        preset: CreateRoomPreset.privateChat,
        initialState: <StateEvent>[
          StateEvent(type: 'm.room.history_visibility', stateKey: '', content: <String, Object?>{'history_visibility': 'shared'}),
        ],
      );
      await _refresh();
      for (final e in _dmPeers.entries) {
        if (e.value == userId && _dmTimelines.containsKey(e.key)) return e.key;
      }
      return roomId;
    } catch (e) {
      AppLog.e('gateway', 'Einzelchat konnte nicht eröffnet werden', e);
      throw _map(e);
    }
  }

  // ------------------------------------------------------ Online-Status (E-38)

  @override
  Map<String, PresenceStamp> get presence => _presence.snapshot();

  @override
  Stream<String> get presenceAsks => _presenceAsks.stream;

  @override
  Future<void> announcePresence({required bool online, bool ask = false, String? onlyTo}) async {
    final client = _client;
    final f = _family;
    if (client == null || !client.isLogged() || f == null || !client.encryptionEnabled) {
      throw const GatewayException(GatewayError.notAllowed);
    }
    if (onlyTo != null && !MatrixIds.isUserId(onlyTo)) throw const GatewayException(GatewayError.invalidInput);
    // Nur an Geräte, die auch Raumschlüssel erhielten (cross-signiert, nicht gesperrt) und nur an
    // beigetretene Mitglieder – nie an Eingeladene, Anfragende oder Entfernte.
    final devices = <DeviceKeys>[];
    for (final m in f.joined) {
      if (m.userId == f.myUserId || (onlyTo != null && m.userId != onlyTo)) continue;
      final list = client.userDeviceKeys[m.userId]?.deviceKeys.values;
      if (list == null) continue;
      for (final d in list) {
        if (d.encryptToDevice) devices.add(d);
      }
    }
    if (devices.isEmpty) return;
    try {
      await client.sendToDeviceEncryptedChunked(
        devices,
        PresenceCodec.type,
        PresenceCodec.encode(online: online, now: DateTime.now().toUtc(), ask: ask),
      );
    } catch (e) {
      AppLog.e('gateway', 'Online-Status konnte nicht gesendet werden', e);
      throw _map(e);
    }
  }

  void _onToDevice(ToDeviceEvent e) {
    if (e.type != PresenceCodec.type) return;
    // Nur Ende-zu-Ende-verschlüsselt Angekommenes zählt: ein unverschlüsseltes Ereignis könnte
    // der Server im Namen eines Mitglieds erzeugen.
    if (e.encryptedContent == null) return;
    final f = _family;
    if (f == null || e.sender == f.myUserId || f.member(e.sender)?.status != MemberStatus.joined) return;
    final d = PresenceCodec.decode(Map<String, Object?>.from(e.content), now: DateTime.now().toUtc());
    if (d == null) return;
    // Je Gerät führen (Schlüssel des sendenden Geräts): ein Mitglied gilt als online, solange
    // irgendein Gerät online meldet.
    final key = e.encryptedContent?['sender_key'];
    final now = DateTime.now().toUtc();
    final before = _presence.stampOf(e.sender, now);
    if (_presence.apply(e.sender, deviceId: key is String ? key : '', online: d.online, at: d.at)) {
      final after = _presence.stampOf(e.sender, now);
      if (before == null || after == null || before.online != after.online) notifyListeners();
    }
    if (d.ask && !_presenceAsks.isClosed) _presenceAsks.add(e.sender);
  }

  // -------------------------------------------------------- Einkaufszettel

  @override
  Future<void> publishShoppingItem(ShoppingItem item) async {
    final room = _requireEncryptedRoom();
    // Gesendet werden nur eigene Änderungen; Empfänger verwerfen fremde `by`-Angaben.
    if (item.by != _client?.userID) throw const GatewayException(GatewayError.invalidInput);
    final Map<String, Object?> content;
    try {
      content = ShoppingCodec.encode(item);
    } on StateError {
      throw const GatewayException(GatewayError.invalidInput);
    }
    try {
      await _sendCalendar(room, ShoppingCodec.type, content);
    } on GatewayException {
      rethrow;
    } catch (e) {
      AppLog.e('gateway', 'Einkaufseintrag konnte nicht gesendet werden', e);
      throw _map(e);
    }
  }

  // ----------------------------------------------------------- Aufgabenlisten

  @override
  Future<void> publishTaskList(TaskList list) async {
    final room = _requireEncryptedRoom();
    if (list.by != _client?.userID) throw const GatewayException(GatewayError.invalidInput);
    final Map<String, Object?> content;
    try {
      content = TaskCodec.encodeList(list);
    } on StateError {
      throw const GatewayException(GatewayError.invalidInput);
    }
    try {
      await _sendCalendar(room, TaskCodec.listType, content);
    } on GatewayException {
      rethrow;
    } catch (e) {
      AppLog.e('gateway', 'Aufgabenliste konnte nicht gesendet werden', e);
      throw _map(e);
    }
  }

  @override
  Future<void> publishTaskLog(TaskLogEntry entry) async {
    final room = _requireEncryptedRoom();
    if (entry.by != _client?.userID) throw const GatewayException(GatewayError.invalidInput);
    final Map<String, Object?> content;
    try {
      content = TaskCodec.encodeLog(entry);
    } on StateError {
      throw const GatewayException(GatewayError.invalidInput);
    }
    try {
      await _sendCalendar(room, TaskCodec.logType, content);
    } on GatewayException {
      rethrow;
    } catch (e) {
      AppLog.e('gateway', 'Protokolleintrag konnte nicht gesendet werden', e);
      throw _map(e);
    }
  }

  // ------------------------------------------- Identitäten der Mitglieder (S1)

  /// Vermerkte Cross-Signing-Hauptschlüssel der Mitglieder (`{mxid: öffentlicher Schlüssel}`),
  /// geräteübergreifend in den Kontodaten. Ändert sich ein Schlüssel, werden die Geräte des
  /// Mitglieds gesperrt, bis die Änderung ausdrücklich akzeptiert wird.
  static const String pinsAccountData = 'de.inneso.familynexus.identity_pins';

  final Set<String> _identityChanged = <String>{};
  final Map<String, String> _pendingPins = <String, String>{};
  final Map<String, String> _knockNonces = <String, String>{};
  bool _pinsPersisting = false;

  Map<String, String> _pins() {
    final raw = _client?.accountData[pinsAccountData]?.content;
    return <String, String>{
      if (raw != null)
        for (final e in raw.entries)
          if (e.value is String && MatrixIds.isUserId(e.key)) e.key: e.value! as String,
    };
  }

  void _setBlocked(String userId, bool blocked) {
    final list = _client?.userDeviceKeys[userId];
    if (list == null) return;
    for (final d in list.deviceKeys.values) {
      if (d.blocked != blocked) {
        d.setBlocked(blocked).catchError((Object e) {
          AppLog.w('gateway', 'Gerät konnte nicht (ent)sperrt werden');
        }).ignore();
      }
    }
  }

  IdentityStatus _identityOf(String uid, String me) {
    final c = _client;
    if (c == null) return IdentityStatus.unknown;
    if (uid == me) return IdentityStatus.verified;
    final master = c.userDeviceKeys[uid]?.masterKey;
    final pub = master?.publicKey;
    if (master == null || pub == null) return IdentityStatus.unknown;
    final pinned = _pins()[uid] ?? _pendingPins[uid];
    if (pinned == null) {
      _pendingPins[uid] = pub;
      _persistPins().ignore();
      return master.verified ? IdentityStatus.verified : IdentityStatus.pinned;
    }
    if (pinned != pub) {
      _identityChanged.add(uid);
      _setBlocked(uid, true);
      return IdentityStatus.changed;
    }
    _identityChanged.remove(uid);
    return master.verified ? IdentityStatus.verified : IdentityStatus.pinned;
  }

  Future<void> _persistPins() async {
    final c = _client;
    if (_pinsPersisting || c == null || !c.isLogged() || _pendingPins.isEmpty) return;
    _pinsPersisting = true;
    try {
      final merged = <String, String>{..._pins(), ..._pendingPins};
      await c.setAccountData(c.userID!, pinsAccountData, <String, Object?>{...merged});
      _pendingPins.removeWhere((k, v) => merged[k] == v);
    } catch (e) {
      AppLog.w('gateway', 'Identitätsvermerke nicht gespeichert');
    } finally {
      _pinsPersisting = false;
    }
  }

  @override
  Future<void> acceptIdentityChange(String userId) async {
    final f = _requireFamily();
    _requireMember(f, userId);
    final c = _client;
    final pub = c?.userDeviceKeys[userId]?.masterKey?.publicKey;
    if (c == null || pub == null || !_identityChanged.contains(userId)) throw const GatewayException(GatewayError.notFound);
    try {
      await c.setAccountData(c.userID!, pinsAccountData, <String, Object?>{..._pins(), userId: pub});
    } catch (e) {
      throw _map(e);
    }
    _pendingPins.remove(userId);
    _identityChanged.remove(userId);
    _setBlocked(userId, false);
    _scheduleRefresh();
  }

  Family _buildFamily(Room room, String me) {
    final members = <FamilyMember>[];
    for (final u in room.getParticipants()) {
      final MemberStatus? status = switch (u.membership) {
        Membership.join => MemberStatus.joined,
        Membership.invite => MemberStatus.invited,
        Membership.knock => MemberStatus.requested,
        _ => null,
      };
      if (status == null) continue;
      RequestCheck? request;
      if (status == MemberStatus.requested) {
        final reason = u.content['reason'];
        request = _checkRequest(reason is String ? reason : null);
        if (reason is String && reason.startsWith(knockReasonPrefix)) _knockNonces[u.id] = reason.substring(knockReasonPrefix.length);
      }
      members.add(FamilyMember(
        userId: u.id,
        displayName: TextSanitizer.displayName(u.displayName, u.id),
        role: PowerLevels.roleFor(room.getPowerLevelByUserId(u.id).level),
        status: status,
        identity: status == MemberStatus.joined ? _identityOf(u.id, me) : IdentityStatus.unknown,
        request: request,
      ));
    }
    return Family(
      roomId: room.id,
      name: TextSanitizer.clean(room.name, max: FamilyRoomSpec.nameMax),
      members: members,
      myUserId: me,
    );
  }

  // ------------------------------------------------------------- Fehler

  GatewayException _map(Object e, {bool forLogin = false}) {
    if (e is GatewayException) return e;
    if (e is MatrixException) {
      switch (e.errcode) {
        case 'M_FORBIDDEN':
        case 'M_USER_DEACTIVATED':
        case 'M_UNKNOWN_TOKEN':
          return GatewayException(forLogin ? GatewayError.invalidCredentials : GatewayError.notAllowed);
        case 'M_LIMIT_EXCEEDED':
          return const GatewayException(GatewayError.rateLimited);
        case 'M_NOT_FOUND':
          return const GatewayException(GatewayError.notFound);
        // Serverseitige Ablehnung ist kein lokaler Eingabefehler: nicht als `invalidInput`
        // melden (sonst würde die Warteschlange den Eintrag verwerfen).
        case 'M_TOO_LARGE':
        case 'M_BAD_JSON':
          return const GatewayException(GatewayError.unknown);
        case 'M_UNSUPPORTED_ROOM_VERSION':
        case 'M_INCOMPATIBLE_ROOM_VERSION':
          return const GatewayException(GatewayError.serverUnsupported);
        default:
          return const GatewayException(GatewayError.unknown);
      }
    }
    if (e is BadServerLoginTypesException) {
      return const GatewayException(GatewayError.serverUnsupported);
    }
    if (e is TimeoutException) return const GatewayException(GatewayError.serverUnreachable);
    final s = e.runtimeType.toString();
    if (s.contains('Socket') || s.contains('Handshake') || s.contains('ClientException') || s.contains('Tls')) {
      return const GatewayException(GatewayError.serverUnreachable);
    }
    return const GatewayException(GatewayError.unknown);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _syncSub?.cancel().ignore();
    _loginSub?.cancel().ignore();
    _timeline?.cancelSubscriptions();
    _privateTimeline?.cancelSubscriptions();
    _verificationSub?.cancel().ignore();
    _toDeviceSub?.cancel().ignore();
    for (final t in _dmTimelines.values) {
      t.cancelSubscriptions();
    }
    _signals.close().ignore();
    _presenceAsks.close().ignore();
    _client?.dispose().ignore();
    _http.close();
    super.dispose();
  }
}
