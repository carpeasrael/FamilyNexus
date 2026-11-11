import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException, TlsException;
import 'dart:math' show Random;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:matrix/encryption.dart';
import 'package:matrix/matrix.dart';
// ignore: implementation_imports
import 'package:matrix/src/utils/client_init_exception.dart' show ClientInitPreconditionError;
import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart' as sql;

import '../../core/app_log.dart';
import '../../core/platform_info.dart';
import '../../domain/account_deletion.dart';
import '../../domain/attachment_policy.dart';
import '../../domain/calendar_event.dart';
import '../../domain/calendar_signal.dart';
import '../../domain/chat.dart';
import '../../domain/data_inventory.dart';
import '../../domain/event_codec.dart';
import '../../domain/family.dart';
import '../../domain/family_code.dart';
import '../../domain/invite_link.dart';
import '../../domain/invite_ticket.dart';
import '../../domain/key_value_store.dart';
import '../../domain/moderation.dart';
import '../../domain/password_change.dart';
import '../../domain/permissions.dart';
import '../../domain/presence.dart';
import '../../domain/reaction_codec.dart';
import '../../domain/registration.dart';
import '../../domain/security.dart';
import '../../domain/server.dart';
import '../../domain/shopping.dart';
import '../../domain/tasks.dart';
import '../../domain/text_sanitizer.dart';
import '../../domain/username_suggestion.dart';
import '../db/app_database.dart';
import '../db/encrypted_db.dart';
import '../platform/key_store.dart';
import 'background_image_work.dart';
import 'chat_mapper.dart';
import 'event_trust.dart';
import 'family_room_spec.dart';
import 'family_scope.dart';
import 'https_only_client.dart';
import 'identity_pins.dart';
import 'local_identity_pins.dart';
import 'local_sends.dart';
import 'matrix_gateway.dart';
import 'server_probe.dart';
import 'sync_relevance.dart';

part 'gateway/account_deletion.dart';
part 'gateway/app_client.dart';
part 'gateway/calendar_data.dart';
part 'gateway/chat.dart';
part 'gateway/data_inventory.dart';
part 'gateway/direct_chats.dart';
part 'gateway/family.dart';
part 'gateway/gateway_errors.dart';
part 'gateway/identities.dart';
part 'gateway/password_change.dart';
part 'gateway/presence.dart';
part 'gateway/invitations.dart';
part 'gateway/join_diagnostic.dart';
part 'gateway/registration_session.dart';
part 'gateway/security_verification.dart';

/// Produktive Implementierung auf Basis des Matrix-Dart-SDK (E-01).
///
/// Sicherheitsrelevante Entscheidungen:
/// * SDK-Datenbank: SQLCipher, eigener Schlüssel im Keystore (Linux: Secret Service).
/// * SDK-Logs werden auf AppLog umgeleitet (nur Typ des Fehlers) und nicht gesammelt.
/// * Nachrichten werden ohne Markdown-Parsing und ohne Slash-Befehle gesendet.
/// * Lesebestätigungen sind privat (`receiptsPublicByDefault: false`).
/// * Gesendet wird nur in Räumen mit aktivierter Verschlüsselung.
/// * Reaktionen sind ein eigener verschlüsselter Ereignistyp (E-86); `m.reaction` ginge im Klartext hinaus.
class SdkMatrixGateway extends ChangeNotifier with _AccountDeletionModule, _SecurityVerificationModule, _InvitationsModule, _CalendarDataModule, _ChatModule, _PasswordChangeModule, _PresenceModule, _FamilyModule, _DirectChatsModule, _IdentitiesModule, _GatewayErrorsModule, _DataInventoryModule implements MatrixGateway {
  /// [databaseOpener] und [httpClient] sind nur für Tests gedacht (Host ohne
  /// SQLCipher-Plugin bzw. selbstsigniertes Testzertifikat), ebenso [joinOpTimeout]
  /// und [joinPollInterval] (kurze bzw. lange Zeiten für die Beitrittsanfrage).
  SdkMatrixGateway({
    required this._keyStore,
    ServerProbe? probe,
    this._dbDirectory,
    @visibleForTesting this._databaseOpener,
    @visibleForTesting http.Client? httpClient,
    @visibleForTesting this._joinOpTimeout = roomOpTimeout,
    @visibleForTesting this._joinPollInterval = rejectionPollInterval,
    @visibleForTesting this._participantsRetryBase = participantsRetryDelay,
    this._accountStore,
  })  : assert(_participantsRetryBase > Duration.zero),
        _probe = probe ?? ServerProbe(),
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
  static const int maxMessageLength = ChatMessage.maxBody;
  static const int maxFamilyNameLength = 60;
  static const int maxRetriesPerEvent = 5;
  static const int maxPlaintextWarnings = 2000;
  static const Duration roomSyncTimeout = Duration(seconds: 30);

  final KeyStore _keyStore;
  final ServerProbe _probe;

  /// Ablage der eingegebenen Anbieter-Adresse in der App-Datenbank (#259, E-90); ohne Ablage nur im Speicher.
  final KeyValueStore? _accountStore;
  final String? _dbDirectory;

  /// Alle Verbindungen des SDK laufen über diesen Client: nur https, keine Weiterleitungen.
  @override
  final HttpsOnlyClient _http;

  @override
  _AppClient? _client;
  StreamSubscription<Object?>? _syncSub;
  StreamSubscription<Object?>? _loginSub;
  StreamSubscription<Object?>? _verificationSub;
  @override
  KeyVerification? _verification;
  Timer? _debounce;
  @override
  Timeline? _timeline;
  String? _timelineRoomId;
  @override
  Timeline? _privateTimeline;
  @override
  String? _privateTimelineRoomId;

  /// Einzelchats (E-39): Raum-ID → Zeitleiste, Gegenüber, Nachrichten.
  @override
  final Map<String, Timeline> _dmTimelines = <String, Timeline>{};
  @override
  final Map<String, String> _dmPeers = <String, String>{};
  @override
  final Map<String, List<ChatMessage>> _dmMessages = <String, List<ChatMessage>>{};
  @override
  final Set<String> _dmJoining = <String>{};
  @override
  List<ChatThread> _threads = const <ChatThread>[];

  /// Online-Status der anderen Mitglieder (E-38), nur im Arbeitsspeicher.
  @override
  final PresenceBoard _presence = PresenceBoard();
  String? _presenceRoomId;
  @override
  final StreamController<String> _presenceAsks = StreamController<String>.broadcast();
  StreamSubscription<Object?>? _toDeviceSub;
  final StreamController<CalendarSignal> _signals = StreamController<CalendarSignal>.broadcast();
  @override
  final Set<String> _signaled = <String>{};
  @override
  Set<String>? _knownJoined;
  @override
  Future<void>? _creatingPrivateRoom;
  bool _participantsRequested = false;
  @override
  bool _participantsLoaded = false;

  /// Neuer Versuch, wenn der Abruf der Mitgliederliste gescheitert ist (#135). Leere Syncs lösen seit E-85 keinen
  /// Abgleich aus, der Neuversuch braucht deshalb einen eigenen Timer.
  final Duration _participantsRetryBase;
  Timer? _participantsRetry;
  int _participantsFailures = 0;
  bool _disposed = false;

  static const Duration participantsRetryDelay = Duration(minutes: 1);
  static const Duration participantsRetryMax = Duration(minutes: 15);

  /// Wartezeit vor dem [failures]-ten Neuversuch: [base], dann verdoppelt bis [max]. Der Exponent ist begrenzt,
  /// damit auch nach beliebig vielen Fehlversuchen nichts überläuft (#135).
  @visibleForTesting
  static Duration participantsRetryAfter(int failures,
      {Duration base = participantsRetryDelay, Duration max = participantsRetryMax}) {
    if (failures <= 1) return base < max ? base : max;
    final exponent = (failures - 1).clamp(0, 10);
    final micros = base.inMicroseconds * (1 << exponent);
    return micros >= max.inMicroseconds ? max : Duration(microseconds: micros);
  }

  /// Nur für Tests: Wartet gerade ein Neuversuch für die Mitgliederliste?
  @visibleForTesting
  bool get debugParticipantsRetryPending => _participantsRetry != null;

  void _cancelParticipantsRetry() {
    _participantsRetry?.cancel();
    _participantsRetry = null;
    _participantsFailures = 0;
  }
  @override
  bool _syncedOnce = false;
  @override
  Family? _family;

  // ------------------------------------------------- Grundlinie für Meldungen (#254, E-88)

  /// Server-Zeitstempel, ab dem Ereignisse als „neu“ gelten. `null` bis zum ersten echten Sync dieser Sitzung.
  DateTime? _liveSince;

  /// Höchster `originServerTs` aller Timeline-Ereignisse aus echten Syncs dieser Sitzung (jeder Typ).
  DateTime? _maxServerTs;

  /// Sitzung (`Nutzer|Gerät`), zu der [_liveSince] gehört; ein Wechsel beginnt neu.
  String? _liveKey;

  /// Zählt Sitzungswechsel: Eine verspätete Fortsetzung der alten Sitzung schreibt nichts mehr.
  int _liveGeneration = 0;

  /// Startwert aus der Datenbank (nur beim Wiederherstellen), bis zum ersten echten Sync abgeholt.
  Future<DateTime?>? _pendingSeed;

  /// Obergrenze: Eine vorgehende Server- oder Geräteuhr unterdrückt Meldungen höchstens so lange.
  static const Duration liveSkew = Duration(minutes: 5);

  @override
  DateTime? get liveSince => _liveSince;

  static DateTime? _later(DateTime? a, DateTime? b) => a == null ? b : (b == null || !b.isAfter(a) ? a : b);

  static DateTime _capLive(DateTime t) {
    final cap = DateTime.now().toUtc().add(liveSkew);
    return t.isAfter(cap) ? cap : t;
  }

  void _resetLive() {
    _liveGeneration++;
    _liveSince = null;
    _maxServerTs = null;
    _liveKey = null;
    _liveFirstPending = false;
  }

  /// Wertet einen Sync für [liveSince] aus. Künstliche Syncs des SDK (Verlauf, Sendezustände) haben ein leeres
  /// `nextBatch` und zählen nicht; `room.lastEvent` scheidet aus, weil es App-Ereignisse nicht kennt.
  void _trackLive(Client client, SyncUpdate update) {
    if (update.nextBatch.isEmpty) return;
    final key = '${client.userID}|${client.deviceID}';
    if (key != _liveKey) {
      _resetLive();
      _liveKey = key;
    }
    final seen = _liveSince != null || _liveFirstPending;
    for (final room in update.rooms?.join?.values ?? const <JoinedRoomUpdate>[]) {
      for (final e in room.timeline?.events ?? const <MatrixEvent>[]) {
        _maxServerTs = _later(_maxServerTs, e.originServerTs.toUtc());
      }
    }
    if (seen) return;
    _liveFirstPending = true;
    final generation = _liveGeneration;
    final seed = _pendingSeed ?? Future<DateTime?>.value();
    _pendingSeed = null;
    seed.catchError((Object _) => null).then((value) {
      if (generation != _liveGeneration) return;
      _liveFirstPending = false;
      _liveSince = _capLive(_later(value, _maxServerTs) ?? DateTime.now().toUtc());
      notifyListeners();
    });
  }

  bool _liveFirstPending = false;

  /// Jüngstes gespeichertes, vom Server bestätigtes Ereignis aller beigetretenen Räume (Startwert beim
  /// Wiederherstellen). SENDING-Einträge stehen in `getEventList` vorn und werden übersprungen.
  static Future<DateTime?> _readLiveSeed(Client client) async {
    final db = client.database;
    DateTime? best;
    for (final room in client.rooms.where((r) => r.membership == Membership.join)) {
      best = _later(best, latestSynced(await db.getEventList(room, limit: 1)));
    }
    return best;
  }

  /// Jüngster Server-Zeitstempel unter [events], nur vom Server bestätigte (SENDING/Fehler tragen Gerätezeit).
  @visibleForTesting
  static DateTime? latestSynced(Iterable<Event> events) {
    DateTime? best;
    for (final e in events.where((e) => e.status.isSynced)) {
      best = _later(best, e.originServerTs.toUtc());
    }
    return best;
  }

  /// Zu welchem Familienraum die Zustände dieses Gateways gehören (#140).
  final FamilyScope _scope = FamilyScope();

  /// Nur für Tests: läuft im Abgleich vor `room.getTimeline`. Dann zeigt `_familyRoom()` schon auf den neuen Raum,
  /// [family] noch auf den alten.
  @visibleForTesting
  Future<void> Function()? debugBeforeFamilyTimeline;

  /// Nur für Tests: läuft im Abgleich nach `room.getTimeline`. Dann zeigt die Zeitleiste schon den neuen Raum, [family]
  /// noch den alten; das Lesen für die Echo-Reparatur hält diesen Stand ebenso offen.
  @visibleForTesting
  Future<void> Function()? debugAfterFamilyTimeline;

  /// Nur für Tests: läuft, wenn die Mitgliederliste da ist, vor der Prüfung der Generation.
  @visibleForTesting
  Future<void> Function()? debugBeforeParticipantsLoaded;

  /// Nur für Tests: Ist die Mitgliederliste der aktuellen Familie vollständig geladen?
  @visibleForTesting
  bool get debugParticipantsLoaded => _participantsLoaded;
  /// Nur für Tests: die offenen Chat-Sendungen.
  @visibleForTesting
  LocalSends get debugLocalSends => _localSends;
  List<ChatMessage> _messages = const <ChatMessage>[];

  /// Offene Chat-Sendungen. Nur hier liegt, was wiederholt werden darf (#138).
  @override
  final LocalSends _localSends = LocalSends(maxRetries: maxRetriesPerEvent);
  final EchoRepair _echoRepair = EchoRepair();

  /// Laufende Reaktionen je Thread, Ziel und Emoji, gegen parallele Aufrufe.
  @override
  final Set<String> _reactionInFlight = <String>{};
  @override
  final BoundedIdSet _plaintextWarned = BoundedIdSet(maxPlaintextWarnings);

  /// Bei der Serverprüfung bestätigte Basisadresse je Eingabe: Der Login nutzt
  /// genau diese und löst nicht erneut auf (kein Wechsel zwischen Prüfung und Anmeldung).
  final Map<ServerUrl, ServerUrl> _confirmedBase = <ServerUrl, ServerUrl>{};

  @override
  SessionState get session =>
      (_client?.isLogged() ?? false) ? SessionState.ready : SessionState.loggedOut;

  @override
  String? get userId => _client?.userID;

  /// Die eingegebene Anbieter-Adresse, sofern sie zu Konto und aufgelöster Basis der Sitzung passt (#259, E-90);
  /// sonst (Altsitzung, fremder Eintrag) der aufgelöste Homeserver. Technisch genutzt wird immer die Basis.
  @override
  ServerUrl? get server {
    final c = _client;
    final base = _baseOf(c);
    final p = _provider;
    if (c == null || base == null || p == null) return base;
    return p.userId == c.userID && p.base == base ? p.entered : base;
  }

  // -------------------------------------------- Eingegebene Anbieter-Adresse (#259, E-90)

  /// Schlüssel in der App-Datenbank (Tabelle settings) für Konto, eingegebene Adresse und aufgelöste Basis.
  static const String accountProviderKey = 'accountProvider';

  /// Gilt für die laufende Sitzung, solange Konto und Basis übereinstimmen (siehe [server]).
  _Provider? _provider;

  /// Ein Eintrag kann in der Ablage stehen (gesetzt, gelesen oder nicht lesbar): Ein Sitzungsende löscht ihn dann.
  bool _providerMaybeStored = false;
  StreamSubscription<SessionClearReason>? _clearedSub;

  static ServerUrl? _baseOf(Client? c) {
    final hs = c?.homeserver;
    return hs == null ? null : ServerUrl.tryParse(hs.toString());
  }

  /// Übernimmt das an einen Anmeldevorgang gebundene Paar, wenn die Sitzung steht und ihre Basis passt.
  Future<void> _adoptProvider(Client client, _Entered? pair) async {
    final user = client.userID;
    if (pair == null || !client.isLogged() || user == null) return;
    final base = _baseOf(client);
    if (base == null || base != pair.base) return;
    _provider = (userId: user, entered: pair.entered, base: base);
    final store = _accountStore;
    if (store == null) return;
    _providerMaybeStored = true;
    try {
      await store.write(
        accountProviderKey,
        json.encode(<String, String>{'user_id': user, 'entered': pair.entered.toString(), 'base': base.toString()}),
      );
    } catch (e) {
      AppLog.e('gateway', 'Anbieter-Adresse nicht gespeichert', e);
    }
  }

  /// Liest den Eintrag beim Wiederherstellen; ein Lesefehler bricht den Start nicht ab (E-82).
  Future<void> _loadProvider() async {
    final store = _accountStore;
    if (store == null) return;
    try {
      final raw = (await store.readAll())[accountProviderKey];
      _providerMaybeStored = raw != null;
      _provider = raw == null ? null : _decodeProvider(raw);
    } catch (e) {
      AppLog.e('gateway', 'Anbieter-Adresse nicht lesbar', e);
      _providerMaybeStored = true;
    }
  }

  static _Provider? _decodeProvider(String raw) {
    try {
      final m = json.decode(raw);
      if (m is! Map<String, Object?>) return null;
      final user = m['user_id'];
      final entered = m['entered'];
      final base = m['base'];
      if (user is! String || entered is! String || base is! String) return null;
      final e = ServerUrl.tryParse(entered);
      final b = ServerUrl.tryParse(base);
      return e == null || b == null ? null : (userId: user, entered: e, base: b);
    } on FormatException {
      return null;
    }
  }

  /// Vergisst die Anbieter-Adresse (Sitzungsende): erst das Feld, dann die Ablage. Idempotent; Fehler nur im Log.
  @override
  Future<void> _forgetProvider() async {
    final had = _provider != null || _providerMaybeStored;
    _provider = null;
    if (!had) return;
    _providerMaybeStored = false;
    try {
      await _accountStore?.delete(accountProviderKey);
    } catch (e) {
      AppLog.e('gateway', 'Anbieter-Adresse nicht gelöscht', e);
    }
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

  @override
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
  int get unreadCount => unreadIn(ChatThread.familyId) + _dmTimelines.keys.fold<int>(0, (a, id) => a + unreadIn(id));

  /// Nur lesbare Nachrichten anderer; der Serverzähler zählt auch nicht entschlüsselbare Ereignisse und
  /// App-Daten mit (#65). Ohne geladene Zeitleiste gilt der Serverzähler.
  @override
  int unreadIn(String threadId) {
    final room = _roomForThread(threadId);
    if (room == null) return 0;
    final t = _timelineFor(threadId);
    return t == null ? room.notificationCount : ChatMapper.unreadReadable(t, serverCount: room.notificationCount);
  }

  /// Ohne geladene Zeitleiste gibt es keine Marke (der Serverzähler nennt keine Nachricht).
  @override
  String? firstUnreadIdIn(String threadId) {
    final room = _roomForThread(threadId);
    final t = _timelineFor(threadId);
    if (room == null || t == null) return null;
    return ChatMapper.firstUnreadReadable(t, serverCount: room.notificationCount);
  }

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

  Future<_AppClient> _ensureClient() async {
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
    final MatrixSdkDatabase database;
    try {
      database = await MatrixSdkDatabase.init('familynexus', database: db);
    } catch (_) {
      // Sonst bliebe die Verbindung für „Erneut versuchen“ offen.
      await db.close().catchError((Object _) {});
      rethrow;
    }
    final client = _AppClient(
      'FamilyNexus',
      database: database,
      httpClient: _http,
      // SSO/Token nur, damit Anbieter mit Browser-Anmeldung (OAuth, E-55) die Serverprüfung bestehen;
      // angemeldet wird ausschließlich mit Passwort oder über OAuth.
      supportedLoginTypes: <String>{LoginType.mLoginPassword, 'm.login.sso', LoginType.mLoginToken},
      // Nur Emoji-Vergleich (SAS); kein QR-Austausch in dieser Phase.
      verificationMethods: <KeyVerificationMethod>{KeyVerificationMethod.emoji},
      receiptsPublicByDefault: false,
      // Strikt: Nur durch das jeweilige Konto cross-signierte Geräte erhalten Raumschlüssel
      // (Schlüsselsicherung ist in der Einrichtung Pflicht, SA-1 geschlossen).
      shareKeysWith: ShareKeysWith.crossVerified,
      logLevel: Level.wtf,
      // Lücken nach längerer Offline-Zeit werden nachgeladen (sonst gingen Termine verloren).
      requestHistoryOnLimitedTimeline: true,
      // Vorschaubilder entstehen in reinem Dart; im UI-Isolate fröre die Oberfläche beim Senden ein (#129).
      customImageResizer: resizeImageInBackground,
    );
    _client = client;
    _syncSub = client.onSync.stream.listen((update) {
      _trackLive(client, update);
      if (!_syncedOnce) {
        // „Abgeglichen“ gilt erst, wenn Familie und Sicherheitsstatus aus den ersten Daten berechnet
        // sind; sonst sähe ein bestehendes Mitglied kurz „keine Familie“ und könnte eine zweite gründen.
        _firstRefresh();
      }
      _onSyncForJoinRequest(update);
      _retryFailedSends();
      // Leere Long-Poll-Antworten ändern nichts: kein voller Abgleich samt Neuaufbau aller Tabs (#150).
      if (!_syncedOnce || syncNeedsRefresh(update)) _scheduleRefresh();
    });
    _loginSub = client.onLoginStateChanged.stream.listen(
      (_) => _scheduleRefresh(),
      // `init` meldet seinen Fehler auch hier; behandelt wird er in `restore`.
      onError: (Object e) => AppLog.e('gateway', 'Anmeldestatus nicht verfügbar', e),
    );
    _verificationSub = client.onKeyVerificationRequest.stream.listen(_onIncomingVerification);
    _toDeviceSub = client.onToDeviceEvent.stream.listen(_onToDevice);
    // Jedes Sitzungsende im SDK (ungültiges Token, gescheitertes `init`, Abmelden …) endet in `clear()` (#259).
    _clearedSub = client.onSessionCleared.stream.listen((_) => _forgetProvider());
    return client;
  }

  /// Erster Abgleich nach dem ersten Sync. Bleibt er hängen (z. B. ein nie antwortender Request),
  /// begrenzt die Zeitschranke das „Synchronisiere …“ (#24); der laufende Abgleich meldet sich später.
  void _firstRefresh() {
    if (_firstRefreshRunning) return;
    _firstRefreshRunning = true;
    _refresh().timeout(firstRefreshTimeout).catchError((Object e) {
      AppLog.e('gateway', 'Erster Abgleich fehlgeschlagen', e);
    }).whenComplete(() {
      _firstRefreshRunning = false;
      _syncedOnce = true;
      notifyListeners();
      _scheduleRefresh();
    });
  }

  bool _firstRefreshRunning = false;

  /// Höchstdauer des ersten Abgleichs, bevor die Oberfläche weitermacht.
  static const Duration firstRefreshTimeout = Duration(seconds: 45);

  @override
  Future<void> retrySync() async {
    final c = _client;
    if (c == null || !c.isLogged()) return;
    AppLog.w('gateway', 'Abgleich wird neu gestartet');
    // Ein hängender Long-Poll wird verworfen und ein neuer gestartet.
    await c.abortSync();
    c.backgroundSync = true;
    _scheduleRefresh();
  }

  @override
  Future<void> restore() async {
    try {
      final Client client;
      try {
        client = await _ensureClient();
      } on KeyLostException {
        rethrow;
      } catch (e) {
        AppLog.e('gateway', 'Matrix-Datenbank nicht verfügbar', e);
        throw const SessionRestoreException(sessionLost: false);
      }
      // Vor `init`: Schon der erste Abgleich zeigt die eingegebene Adresse; die Bindung prüft [server] (#259).
      await _loadProvider();
      // Ebenfalls vor `init` und nur einmal: die lokale Kopie der Identitätsvermerke (#142).
      await _localPins.load();
      if (!client.isLogged()) {
        // Der Startwert wird erst nach `init` lesbar; der erste echte Sync wartet darauf (#254).
        final seed = Completer<DateTime?>();
        _pendingSeed = seed.future;
        try {
          await client.init(waitForFirstSync: false);
          seed.complete(_readLiveSeed(client).catchError((Object _) => null));
          // Keine gespeicherte Sitzung: Ein übrig gebliebener Eintrag gehört zu keinem Konto mehr.
          if (!client.isLogged()) await _forgetProvider();
        } on ClientInitPreconditionError catch (e) {
          if (!seed.isCompleted) seed.complete(null);
          AppLog.e('gateway', 'Sitzung konnte nicht geladen werden', e);
          throw const SessionRestoreException(sessionLost: false);
        } catch (e) {
          if (!seed.isCompleted) seed.complete(null);
          // Bei jedem anderen Fehler kann das SDK die Sitzung bereits gelöscht haben (`clear(initFailed)`).
          AppLog.e('gateway', 'Sitzung konnte nicht geladen werden', e);
          throw const SessionRestoreException(sessionLost: true);
        }
      }
      // Lokale Daten einer früheren Sitzung gelten als „bereits abgeglichen“.
      if (client.isLogged() && client.prevBatch != null) _syncedOnce = true;
      await _refresh();
    } on KeyLostException {
      rethrow;
    } on SessionRestoreException {
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

  /// Setzt den Homeserver des SDK auf die geprüfte Adresse. Das SDK darf keine eigene
  /// `.well-known`-Abfrage machen (ungeprüfte Ziele, Weiterleitungen, Zwischenspeicherung).
  /// Mit [oauth] liefert es die dabei abgerufenen OAuth-Metadaten (`null`, wenn keine abrufbar waren), dazu immer
  /// das Paar aus eingegebener Adresse und normalisierter Basis für den laufenden Vorgang (#259).
  Future<(GetAuthMetadataResponse?, _Entered?)> _useHomeserver(Client client, ServerUrl server, {bool oauth = false}) async {
    // Passwort-Anmeldung und Registrierung beenden eine offene Browser-Anmeldung samt festgehaltener
    // Metadaten (#222) – vor `checkHomeserver`, das ab Matrix v1.15 auch hier `getAuthMetadata` ruft.
    if (!oauth) _dropOAuth();
    final base = _confirmedBase[server] ?? await _probe.resolveBase(server);
    // Die OAuth-Metadaten nur für die Browser-Anmeldung abfragen: Fehlerseiten von Proxys würden
    // sonst auch die Passwort-Anmeldung verhindern.
    final (_, _, _, meta) = await client.checkHomeserver(base.uri, checkWellKnown: false, fetchAuthMetadata: oauth ? true : null);
    if (client.homeserver?.scheme != 'https') {
      client.homeserver = null;
      throw const GatewayException(GatewayError.serverUnsupported);
    }
    final resolved = _baseOf(client);
    final _Entered? pair = resolved == null ? null : (entered: server, base: resolved);
    return (oauth ? meta : null, pair);
  }

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
    cancelRegistration();
    try {
      final client = await _ensureClient();
      final (_, pair) = await _useHomeserver(client, server);
      try {
        await client.login(
          LoginType.mLoginPassword,
          identifier: AuthenticationUserIdentifier(user: user),
          password: password,
          initialDeviceDisplayName: PlatformInfo.deviceName,
        );
      } finally {
        // Auch wenn nach der Anmeldung ein Folgeschritt scheitert (#28): Die Sitzung steht.
        await _adoptProvider(client, pair);
      }
      await _refresh();
    } on GatewayException {
      rethrow;
    } catch (e) {
      // Angemeldet ist angemeldet: scheitert nur ein Folgeschritt (z. B. Schlüssel hochladen,
      // erster Abgleich), keine Fehlermeldung zeigen – der Abgleich holt ihn nach (#28).
      if (_client?.isLogged() ?? false) {
        AppLog.e('gateway', 'Nach der Anmeldung fehlgeschlagen (Anmeldung gilt)', e);
        _scheduleRefresh();
        notifyListeners();
        return;
      }
      AppLog.e('gateway', 'Anmeldung fehlgeschlagen', e);
      throw _map(e, forLogin: true);
    }
  }

  // ------------------------------------------------------ Kontoanlage (E-55)

  _RegistrationSession? _registration;
  OidcLoginSession? _oauth;

  /// Eingegebene Adresse und Basis der offenen Browser-Anmeldung; lebt und endet mit [_oauth] (#259).
  _Entered? _oauthPair;

  /// Beendet eine offene Browser-Anmeldung samt der dafür festgehaltenen Metadaten (#222): beide
  /// werden immer gemeinsam aufgehoben.
  @override
  void _dropOAuth() {
    _oauth = null;
    _oauthPair = null;
    _client?.pinnedAuthMetadata = null;
  }

  /// Öffentliche Projektseite; die Rücksprungadresse auf Mobilgeräten ist deren umgekehrter
  /// Domainname (MSC2966: eigenes Schema muss zur `client_uri` passen).
  static final Uri oauthClientUri = Uri.parse('https://carpeasrael.github.io/FamilyNexus/');
  static const String oauthScheme = 'io.github.carpeasrael.familynexus';
  static final Uri oauthMobileRedirect = Uri.parse('$oauthScheme:/oauth');

  static const int minPasswordLength = PasswordChange.minLength;

  @override
  Future<RegistrationOptions> registrationOptions(ServerUrl server) async {
    try {
      return await _probe.registrationOptions(server);
    } on GatewayException {
      rethrow;
    } catch (e) {
      AppLog.e('gateway', 'Registrierungswege nicht ermittelbar', e);
      throw _map(e);
    }
  }

  @override
  Future<UsernameCheck> checkUsername(ServerUrl server, String username) async {
    if (!UsernameSuggestion.isValid(username)) return UsernameCheck.invalid;
    try {
      final base = _confirmedBase[server] ?? await _probe.resolveBase(server);
      return await _probe.checkUsername(base, username);
    } catch (e) {
      return UsernameCheck.unknown;
    }
  }

  @override
  Future<RegistrationStage?> register({
    required ServerUrl server,
    required String username,
    required String password,
    required String displayName,
    String language = 'de',
  }) async {
    if (!UsernameSuggestion.isValid(username)) throw const GatewayException(GatewayError.usernameInvalid);
    if (password.length < minPasswordLength) throw const GatewayException(GatewayError.weakPassword);
    if (password.length > 1024) throw const GatewayException(GatewayError.invalidInput);
    if (_client?.isLogged() ?? false) throw const GatewayException(GatewayError.notAllowed);
    cancelRegistration();
    try {
      final client = await _ensureClient();
      final (_, pair) = await _useHomeserver(client, server);
      _registration = _RegistrationSession(
        username: username,
        password: password,
        displayName: TextSanitizer.clean(displayName, max: 64),
        language: language,
        provider: pair,
      );
      return await _registerAttempt(null);
    } on GatewayException {
      cancelRegistration();
      rethrow;
    } catch (e) {
      cancelRegistration();
      AppLog.e('gateway', 'Registrierung fehlgeschlagen', e);
      throw _map(e);
    }
  }

  @override
  Future<RegistrationStage?> continueRegistration(RegistrationInput input) async {
    final r = _registration;
    final client = _client;
    if (r == null || client == null) throw const GatewayException(GatewayError.notFound);
    try {
      switch (input) {
        case AcceptTerms():
          return await _registerAttempt(AuthenticationData(type: RegistrationFlows.terms, session: r.session));
        case SubmitToken(:final token):
          final t = token.trim();
          if (t.isEmpty || t.length > 256) throw const GatewayException(GatewayError.invalidInput);
          return await _registerAttempt(AuthenticationData(
            type: RegistrationFlows.token,
            session: r.session,
            additionalFields: <String, Object?>{'token': t},
          ));
        case CaptchaDone():
          // Nach der Bestätigung auf der Seite des Servers genügt die Sitzung (Spezifikation: Fallback).
          return await _registerAttempt(AuthenticationData(session: r.session), attempted: RegistrationFlows.recaptcha);
        case SubmitEmail(:final email):
          if (!isPlausibleEmail(email)) throw const GatewayException(GatewayError.invalidInput);
          r.clientSecret ??= _randomNonce();
          r.sendAttempt++;
          final res = await client.requestTokenToRegisterEmail(r.clientSecret!, email.trim(), r.sendAttempt);
          r.sid = res.sid;
          return const EmailStage(sent: true);
        case EmailConfirmed():
          final sid = r.sid;
          if (sid == null) return const EmailStage();
          return await _registerAttempt(AuthenticationThreePidCreds(
            type: RegistrationFlows.email,
            session: r.session,
            threepidCreds: ThreepidCreds(sid: sid, clientSecret: r.clientSecret!),
          ));
      }
    } on GatewayException catch (e) {
      const keep = <GatewayError>{
        GatewayError.invalidInput,
        GatewayError.rateLimited,
        GatewayError.emailInUse,
        GatewayError.serverUnreachable,
      };
      if (!keep.contains(e.error)) cancelRegistration();
      rethrow;
    } catch (e) {
      AppLog.e('gateway', 'Registrierungsschritt fehlgeschlagen', e);
      final mapped = _mapRegistration(e);
      if (mapped.error != GatewayError.emailInUse &&
          mapped.error != GatewayError.rateLimited &&
          mapped.error != GatewayError.serverUnreachable) {
        cancelRegistration();
      }
      throw mapped;
    }
  }

  @override
  void cancelRegistration() {
    _registration?.password = null;
    _registration = null;
  }

  /// Ein Durchlauf von `/register`. Verlangt der Server weitere Schritte, wird der nächste
  /// ermittelt; Platzhalterschritte (`m.login.dummy`) erledigt die App selbst.
  Future<RegistrationStage?> _registerAttempt(AuthenticationData? auth, {String? attempted, int depth = 0}) async {
    final r = _registration;
    final client = _client;
    if (r == null || r.password == null || client == null) throw const GatewayException(GatewayError.notFound);
    if (depth > 5) throw const GatewayException(GatewayError.unknown);
    final tried = attempted ?? auth?.type;
    try {
      try {
        await client.register(
          kind: AccountKind.user,
          username: r.username,
          password: r.password,
          auth: auth,
          initialDeviceDisplayName: PlatformInfo.deviceName,
        );
      } finally {
        // [r] ist lokal gehalten: Hat der Kontoanlage-Schritt die Registrierung inzwischen verworfen (er wechselt,
        // sobald das SDK „angemeldet“ meldet), gilt das Paar trotzdem. Ohne Sitzung (weitere Schritte) wirkungslos.
        await _adoptProvider(client, r.provider);
      }
    } on MatrixException catch (e) {
      final flows = e.authenticationFlows;
      if (!e.requireAdditionalAuthentication || flows == null) throw _mapRegistration(e);
      r.session = e.session ?? r.session;
      r.flows = <List<String>>[for (final f in flows) f.stages];
      r.completed = e.completedAuthenticationFlows.toSet();
      r.params = e.authenticationParams;
      final next = RegistrationFlows.next(r.flows, r.completed);
      if (RegistrationFlows.choose(r.flows, r.completed) == null) {
        throw const GatewayException(GatewayError.registrationDisabled);
      }
      switch (next) {
        case RegistrationFlows.dummy:
          if (tried == RegistrationFlows.dummy) throw const GatewayException(GatewayError.unknown);
          return _registerAttempt(AuthenticationData(type: RegistrationFlows.dummy, session: r.session), depth: depth + 1);
        case RegistrationFlows.terms:
          return TermsStage(RegistrationFlows.termsFrom(r.params?[RegistrationFlows.terms], language: r.language));
        case RegistrationFlows.token:
          return TokenStage(wrong: tried == RegistrationFlows.token);
        case RegistrationFlows.recaptcha:
          final base = client.homeserver!;
          return CaptchaStage(
            base.replace(
              path: '/_matrix/client/v3/auth/${RegistrationFlows.recaptcha}/fallback/web',
              queryParameters: <String, String>{'session': r.session ?? ''},
            ),
            notDoneYet: tried == RegistrationFlows.recaptcha,
          );
        case RegistrationFlows.email:
          return EmailStage(sent: r.sid != null, notConfirmedYet: tried == RegistrationFlows.email);
        default:
          throw const GatewayException(GatewayError.unknown);
      }
    }
    // Konto angelegt, Sitzung läuft (das SDK hat `init` bereits ausgeführt).
    final name = r.displayName;
    cancelRegistration();
    if (name.isNotEmpty) {
      try {
        await setDisplayName(name);
      } catch (e) {
        AppLog.w('gateway', 'Anzeigename nicht gesetzt');
      }
    }
    await _refresh();
    return null;
  }

  GatewayException _mapRegistration(Object e) {
    if (e is GatewayException) return e;
    if (e is MatrixException) {
      final code = e.errcode;
      if (code == 'M_USER_IN_USE') return const GatewayException(GatewayError.usernameTaken);
      if (code == 'M_INVALID_USERNAME' || code == 'M_EXCLUSIVE') return const GatewayException(GatewayError.usernameInvalid);
      if (code == 'M_WEAK_PASSWORD' || code.startsWith('M_PASSWORD')) return const GatewayException(GatewayError.weakPassword);
      if (code == 'M_THREEPID_IN_USE') return const GatewayException(GatewayError.emailInUse);
      if (code == 'M_THREEPID_DENIED' || code == 'M_SERVER_NOT_TRUSTED') return const GatewayException(GatewayError.invalidInput);
      if (code == 'M_FORBIDDEN' || code == 'M_UNRECOGNIZED') return const GatewayException(GatewayError.registrationDisabled);
    }
    return _map(e);
  }

  @override
  Future<Uri> startOAuth({required ServerUrl server, required Uri redirectUri, required bool create}) async {
    if (_client?.isLogged() ?? false) throw const GatewayException(GatewayError.notAllowed);
    final loopback = redirectUri.scheme == 'http' && redirectUri.host == '127.0.0.1';
    if (!loopback && redirectUri.scheme != oauthScheme) throw const GatewayException(GatewayError.invalidInput);
    cancelRegistration();
    // Eine ältere, nicht abgeschlossene Anmeldung ist damit verworfen; ihr Rücksprung ergibt `oauthCancelled`.
    _dropOAuth();
    try {
      final client = await _ensureClient();
      // Die Metadaten aus der Serverprüfung, ohne zweiten Abruf. Fehler beim Abruf fängt
      // `checkHomeserver` ab; ohne Metadaten gibt es keine Browser-Anmeldung (#222).
      final (meta, pair) = await _useHomeserver(client, server, oauth: true);
      if (meta == null) throw const GatewayException(GatewayError.serverUnsupported);
      // Alle Endpunkte, über die Code, Verifier und Tokens laufen: https, ohne Zugangsdaten und bei einem
      // öffentlichen Server nicht im Heimnetz (E-59). Danach festgehalten: Das SDK ruft `getAuthMetadata`
      // in `registerOidcClient`, `initOidcLoginSession` und `oidcLogin` selbst und erhält genau diese.
      final acceptable = ServerProbe.oauthEndpointsAcceptable(
        localServer: ServerUrl.isLocalHost(client.homeserver!.host.toLowerCase()),
        endpoints: <Uri>[
          meta.issuer,
          meta.authorizationEndpoint,
          meta.tokenEndpoint,
          meta.registrationEndpoint,
          meta.revocationEndpoint,
        ],
      );
      if (!acceptable) throw const GatewayException(GatewayError.serverUnsupported);
      client.pinnedAuthMetadata = meta;
      final data = await client.registerOidcClient(
        redirectUris: <Uri>[redirectUri],
        applicationType: OidcApplicationType.native,
        clientInformation: OidcClientInformation(
          clientName: 'FamilyNexus',
          clientUri: oauthClientUri,
          logoUri: null,
          tosUri: null,
          policyUri: null,
        ),
      );
      final session = await client.initOidcLoginSession(
        oidcClientData: data,
        redirectUri: redirectUri,
        prompt: create ? 'create' : null,
      );
      if (session.authenticationUri.scheme != 'https') throw const GatewayException(GatewayError.serverUnsupported);
      _oauth = session;
      _oauthPair = pair;
      return session.authenticationUri;
    } on GatewayException {
      _dropOAuth();
      rethrow;
    } catch (e) {
      _dropOAuth();
      AppLog.e('gateway', 'Anmeldung im Browser nicht vorbereitet', e);
      throw _map(e);
    }
  }

  @override
  Future<void> completeOAuth(Uri callback) async {
    final session = _oauth;
    final pair = _oauthPair;
    final client = _client;
    if (session == null || client == null) throw const GatewayException(GatewayError.oauthCancelled);
    // Rücksprung nur an die eigene, gerade verwendete Adresse.
    if (callback.scheme != session.redirectUri.scheme || callback.path != session.redirectUri.path) {
      throw const GatewayException(GatewayError.oauthStateMismatch);
    }
    final params = <String, String>{
      ...callback.queryParameters,
      if (callback.fragment.isNotEmpty) ...Uri.splitQueryString(callback.fragment),
    };
    final code = params['code'];
    final state = params['state'];
    // Fremder Rücksprung (anderer Prozess, alte Anmeldung): verwerfen, die eigene läuft weiter – samt
    // der festgehaltenen Metadaten (#222).
    if (state != session.state) throw const GatewayException(GatewayError.oauthStateMismatch);
    if (params.containsKey('error') || code == null) {
      _dropOAuth();
      throw const GatewayException(GatewayError.oauthCancelled);
    }
    _oauth = null;
    _oauthPair = null;
    // Code und Verifier gehen nur an den beim Start geprüften Token-Endpunkt (doppelte Sicherung).
    final pinned = client.pinnedAuthMetadata;
    if (pinned == null) throw const GatewayException(GatewayError.oauthCancelled);
    try {
      try {
        await client.oidcLogin(session: session, code: code, state: session.state);
      } finally {
        await _adoptProvider(client, pair);
      }
      await _refresh();
    } catch (e) {
      AppLog.e('gateway', 'Anmeldung im Browser fehlgeschlagen', e);
      if (e is OidcException) throw const GatewayException(GatewayError.oauthCancelled);
      throw _map(e, forLogin: true);
    } finally {
      // Token-Erneuerung und -Widerruf nutzen danach wieder die Metadaten des SDK (E-59, #222).
      if (identical(client.pinnedAuthMetadata, pinned)) client.pinnedAuthMetadata = null;
    }
  }

  @override
  Future<void> setDisplayName(String name) async {
    final client = _client;
    if (client == null || !client.isLogged()) throw const GatewayException(GatewayError.notAllowed);
    final n = TextSanitizer.clean(name, max: 64);
    if (n.isEmpty) throw const GatewayException(GatewayError.invalidInput);
    try {
      await client.setProfileField(client.userID!, 'displayname', <String, Object?>{'displayname': n});
    } catch (e) {
      throw _map(e);
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
    // Schließen ist kein Sitzungsende: Der Eintrag zur Anbieter-Adresse bleibt (#259).
    await _clearedSub?.cancel();
    _clearedSub = null;
    _syncSub = null;
    _loginSub = null;
    _verificationSub = null;
    _toDeviceSub = null;
    for (final t in _dmTimelines.values) {
      t.cancelSubscriptions();
    }
    _dmTimelines.clear();
    _dropOAuth();
    final c = _client;
    _client = null;
    _stopWatchingJoinRequest();
    _joinRequestGeneration++;
    _pollAgain = false;
    _timeline = null;
    _privateTimeline = null;
    await c?.dispose();
  }

  @override
  Future<void> logout() async {
    cancelRegistration();
    _dropOAuth();
    final client = _client;
    if (client == null) {
      await _localPins.forget();
      return;
    }
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
    await _forgetProvider();
    await _localPins.forget();
    _resetLocal();
    notifyListeners();
  }

  // ------------------------------------------------- Kontolöschung (#12)

  static const String _deactivateAction = 'org.matrix.account_deactivate';

  /// Wurde die Sitzung im Browser angemeldet (OAuth)? Dann darf der Client das Konto nicht selbst löschen.
  @override
  Future<bool> _signedInViaOAuth(Client c) async {
    final stored = await c.database.getClient(c.clientName);
    return stored?.tryGet<String>('oidc_client_id') != null;
  }

  /// Bestätigt der Server mit dem Passwort allein?
  static bool _offersPassword(List<AuthenticationFlow> flows) =>
      flows.any((f) => f.stages.length == 1 && f.stages.single == AuthenticationTypes.password);

  /// Kontoseite aus den OAuth-Metadaten (`account_management_uri`, MSC4191). `null` ohne gültige
  /// https-Adresse.
  @visibleForTesting
  static Uri? accountManagementPage(Map<String, Object?> metadata) {
    final raw = metadata['account_management_uri'];
    final page = raw is String ? Uri.tryParse(raw) : null;
    if (page == null || page.scheme != 'https' || page.host.isEmpty || page.userInfo.isNotEmpty) return null;
    return page;
  }

  /// Löschseite aus den OAuth-Metadaten: mit der Aktion „Konto löschen“, falls angeboten, sonst die
  /// Kontoseite selbst. `null` ohne gültige https-Adresse.
  @visibleForTesting
  static Uri? accountDeletionPage(Map<String, Object?> metadata) {
    final page = accountManagementPage(metadata);
    if (page == null) return null;
    final actions = metadata['account_management_actions_supported'];
    if (actions is! List || !actions.contains(_deactivateAction)) return page;
    return page.replace(queryParameters: <String, String>{...page.queryParameters, 'action': _deactivateAction});
  }

  /// Liest die OAuth-Metadaten selbst: Das SDK-Modell bricht bei unbekannten Kontoaktionen ab.
  @override
  Future<Uri?> _accountManagementPage(Client c, Uri? Function(Map<String, Object?> metadata) pick) async {
    final base = c.homeserver;
    if (base == null) return null;
    for (final path in const <String>['_matrix/client/v1/auth_metadata', '_matrix/client/unstable/org.matrix.msc2965/auth_metadata']) {
      final res = await _http.get(base.resolve(path)).timeout(const Duration(seconds: 20));
      if (res.statusCode == 404) continue;
      if (res.statusCode != 200) return null;
      final json = jsonDecode(utf8.decode(res.bodyBytes));
      return json is Map<String, Object?> ? pick(json) : null;
    }
    return null;
  }

  // ------------------------------------------------- Passwort ändern (#117)

  /// Fehler der Passwortänderung; `null` für [_map]. Wertet nur `flows`, `session` und das rohe
  /// `errcode` aus: Der Getter meldet bei UIA-Antworten ohne `errcode` selbst `M_FORBIDDEN`, und den
  /// HTTP-Status hat die Ausnahme hier nicht. Die Reihenfolge ist Teil der Zuordnung.
  @visibleForTesting
  static GatewayException? passwordChangeError(MatrixException e) {
    final raw = e.raw['errcode'];
    final code = raw is String ? raw : null;
    final flows = e.authenticationFlows;
    if (flows != null && (!_offersPassword(flows) || e.session == null)) {
      return const GatewayException(GatewayError.passwordChangeUnavailable);
    }
    if (flows != null && (code == 'M_FORBIDDEN' || code == 'M_UNAUTHORIZED')) {
      return const GatewayException(GatewayError.invalidCredentials);
    }
    if (code == 'M_USER_LOCKED' || code == 'M_USER_SUSPENDED' || code == 'M_USER_DEACTIVATED') {
      return const GatewayException(GatewayError.notAllowed);
    }
    if (code == 'M_FORBIDDEN' || code == 'M_UNRECOGNIZED') {
      return const GatewayException(GatewayError.passwordChangeUnavailable);
    }
    if (code == 'M_WEAK_PASSWORD' || (code != null && code.startsWith('M_PASSWORD'))) {
      return const GatewayException(GatewayError.weakPassword);
    }
    if (flows != null && code == null) return const GatewayException(GatewayError.unknown);
    return null;
  }

  /// Gemeinsamer Rücksetzpfad für Abmelden und erzwungene Abmeldung
  /// (ungültiges Token): sonst blieben Timeline-Abonnements und Zustände hängen.
  @override
  void _resetLocal() {
    _resetLive();
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
    _joinRequestCacheTs = null;
    _joinRequestCleared = false;
    _joinRejected = false;
    _joinRequestGeneration++;
    _pollAgain = false;
    _joinDiagnostic = _JoinDiagnostic();
    _stopWatchingJoinRequest();
    _knownJoined = null;
    _verification = null;
    _identityChanged.clear();
    _pinBook.clear();
    _participantsLoaded = false;
    _participantsRequested = false;
    _cancelParticipantsRetry();
    _scope.clear();
    _syncedOnce = false;
    _family = null;
    _messages = const <ChatMessage>[];
    _localSends.clear();
    _reactionInFlight.clear();
    _echoRepair.clear();
    _plaintextWarned.clear();
    _confirmedBase.clear();
  }

  /// Die Familie hat gewechselt (auch nach „keine Familie“ und direkt von A nach B): Was aus dem bisherigen Raum
  /// stammt, gilt nicht weiter (#140). Die Historie spielte es sonst den neuen Diensten vor, `_knownJoined` meldete
  /// die Mitglieder der neuen Familie als neu, und Link-Vermerke aus A machten Anfragen in B gültig. `_signaled`
  /// gehört dazu: `claimFamilyData` löscht auch private Termine, sie müssen beim nächsten Scan wiederkommen.
  void _leaveFamilyScope() {
    _signalHistory.clear();
    _signaled.clear();
    _roomTickets.clear();
    _usedTickets.clear();
    _knownJoined = null;
    _participantsLoaded = false;
    _participantsRequested = false;
    _cancelParticipantsRetry();
    _resetDirectChats();
  }

  /// Hat der Abgleich den Raum [room] als Familie übernommen? `_familyRoom()` zeigt nach einem Sync sofort auf einen
  /// neuen Raum, `_family` erst nach `getTimeline`. Bis dahin geht nichts dorthin: Der Abgleich der Dienste steht noch
  /// aus, und ihre Warteschlangen enthalten Daten des alten Raums (#140).
  @override
  bool _isCurrentFamily(Room room) => room.id == _family?.roomId;

  // ------------------------------------------------------------- Familie

  /// Familienraum laut Kontodaten, unabhängig vom Beitrittsstatus.
  @override
  Room? _familyRoomAnyState() {
    final client = _client;
    if (client == null || !client.isLogged()) return null;
    final id = client.accountData[familyAccountData]?.content['room_id'];
    if (id is! String || !MatrixIds.isRoomId(id)) return null;
    return client.getRoomById(id);
  }

  @override
  Room? _familyRoom() {
    final room = _familyRoomAnyState();
    return (room != null && room.membership == Membership.join) ? room : null;
  }

  // ------------------------------------------------- Einladungen und Rollen

  @override
  final Duration _joinOpTimeout;

  @override
  final Duration _joinPollInterval;

  static const Duration roomOpTimeout = Duration(seconds: 45);

  /// Anzeigename des Einladenden aus dem mitgelieferten Raumzustand (bereinigt), sonst `null`.
  static String? _inviterName(Room r, String? inviterId) {
    if (inviterId == null) return null;
    final raw = r.getState(EventTypes.RoomMember, inviterId)?.content['displayname'];
    if (raw is! String) return null;
    final n = TextSanitizer.clean(raw);
    return n.isEmpty ? null : n;
  }

  /// Kontodaten-Schlüssel der eigenen wartenden Beitrittsanfrage. Das SDK führt angeklopfte
  /// Räume nicht in seinem Zustand; deshalb wird die Anfrage hier vermerkt.
  static const String joinRequestAccountData = 'de.inneso.familynexus.join_request';

  static const Duration joinRequestMaxAge = Duration(days: 7);

  static const Duration rejectionPollInterval = Duration(seconds: 10);

  /// Abweichung zwischen Geräte- und Serveruhr, die beim Zeitvergleich hingenommen wird (#30).
  static const Duration rejectionClockSkew = Duration(minutes: 10);

  /// Ob [member] (letztes eigenes `m.room.member`-Ereignis des angefragten Raums) die Ablehnung der
  /// Anfrage ist: „leave“ durch jemand anderen. Stammt der Vorzustand „knock“ aus dem Ereignis selbst,
  /// ist es eindeutig die Antwort auf eine Anfrage; dann genügt ein grober Zeitvergleich, denn der
  /// Zeitpunkt der Anfrage stammt von der Uhr des Geräts, der des Ereignisses vom Server. Eine
  /// vorgehende Geräteuhr verhinderte sonst die Meldung ganz (#30).
  @visibleForTesting
  static bool isKnockRejection(Map<Object?, Object?> member, {required String me, required int requestedAt}) {
    final content = member['content'];
    if (content is! Map || content['membership'] != 'leave' || member['sender'] == me) return false;
    final ts = member['origin_server_ts'] as int? ?? 0;
    final unsigned = member['unsigned'];
    final prevContent = unsigned is Map ? unsigned['prev_content'] : null;
    final prev = prevContent is Map ? prevContent['membership'] : null;
    final tolerance = prev == 'knock' ? rejectionClockSkew.inMilliseconds : 0;
    return ts > requestedAt - tolerance;
  }

  /// Filter der Ablehnungs-Abfrage für genau einen Raum. Synapse beantwortet gleiche `/sync`-Anfragen bis zu
  /// zwei Minuten aus seinem Antwort-Zwischenspeicher (`sync_response_cache_duration`); mit immer gleichem
  /// Filter kam die Ablehnung deshalb erst nach ~2 Minuten an (#43, am Testserver gemessen: 122 s statt
  /// sofort). Ein Ereignistyp, den es nie gibt, in `not_types` macht jede Abfrage verschieden, ohne das
  /// Ergebnis zu ändern.
  @visibleForTesting
  static String rejectionPollFilter(String roomId, int poll) => json.encode(<String, Object?>{
        'presence': <String, Object?>{'types': <String>[]},
        'account_data': <String, Object?>{'types': <String>[]},
        'room': <String, Object?>{
          'rooms': <String>[roomId],
          'include_leave': true,
          'account_data': <String, Object?>{'types': <String>[]},
          'ephemeral': <String, Object?>{'types': <String>[]},
          'timeline': <String, Object?>{
            'limit': 10,
            'not_types': <String>['de.inneso.familynexus.poll.$poll'],
          },
        },
      });

  /// Mitgliedschaft für Diagnose und Log: nur die feste Liste, nie der Wert aus dem Ereignis.
  @visibleForTesting
  static String membershipLabel(Object? membership) {
    if (membership == null) return '-';
    return const <String>{'join', 'knock', 'invite', 'leave', 'ban'}.contains(membership) ? membership as String : 'other';
  }

  /// Fehlerklasse für die Diagnose: feste `is`-Prüfungen, nie `toString()` oder `runtimeType`, denn
  /// Release-Builds sind obfuskiert und Fehlertexte können Raum-IDs enthalten. `socket` steht vor
  /// `client`, weil Verbindungsfehler des http-Pakets beides sind.
  @visibleForTesting
  static String failureClass(Object e) {
    if (e is SocketException) return 'socket';
    if (e is TlsException) return 'tls';
    if (e is FormatException) return 'format';
    if (e is MatrixException) return 'matrix';
    if (e is http.ClientException) return 'client';
    return 'other';
  }

  /// Vom Moderator ausgegebene Link-IDs (`{id: Ablauf in Unix-Sekunden}`) in den Kontodaten,
  /// damit nur Anfragen mit eigenem, gültigem, einmaligem Link bestätigt werden (S2).
  static const String invitesAccountData = 'de.inneso.familynexus.invites';

  static String _ownHostOf(String userId) => userId.substring(userId.indexOf(':') + 1);

  static String _randomNonce() {
    final r = Random.secure();
    return List<String>.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  /// Beitrittsanfragen: Der Grund enthält die Link-ID (`FamilyNexus:<id>`).
  static const String knockReasonPrefix = 'FamilyNexus:';

  /// Anfrage über den Familien-Code (ohne Link): `FamilyNexus:code`.
  static const String knockCodeMarker = 'code';

  static String? _errcodeOf(String body) {
    try {
      final data = json.decode(body);
      final code = data is Map ? data['errcode'] : null;
      return code is String && RegExp(r'^[A-Z0-9_.]{1,64}$').hasMatch(code) ? code : null;
    } on FormatException {
      return null;
    }
  }

  /// Fehler einer abgelehnten Beitrittsanfrage nach Status und Matrix-Fehlercode (#25): Statt pauschal
  /// „Unbekannter Fehler.“ zu melden, werden Serverprobleme (z. B. Server der Familie nicht erreichbar,
  /// 5xx), fehlende Unterstützung und Sperren unterschieden.
  @visibleForTesting
  static GatewayException knockError(int status, String body) {
    final code = _errcodeOf(body);
    if (status == 429 || code == 'M_LIMIT_EXCEEDED') return const GatewayException(GatewayError.rateLimited);
    if (code == 'M_UNRECOGNIZED' || code == 'M_UNSUPPORTED_ROOM_VERSION' || code == 'M_INCOMPATIBLE_ROOM_VERSION') {
      return const GatewayException(GatewayError.serverUnsupported);
    }
    if (status == 403 || code == 'M_FORBIDDEN') return const GatewayException(GatewayError.notAllowed);
    if (status == 404 || code == 'M_NOT_FOUND') return const GatewayException(GatewayError.notFound);
    if (status == 400 && code == 'M_INVALID_PARAM') return const GatewayException(GatewayError.invalidInput);
    if (status >= 500) return const GatewayException(GatewayError.serverUnreachable);
    return const GatewayException(GatewayError.unknown);
  }

  // ------------------------------------------------------------ Zustand

  @override
  void _scheduleRefresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () {
      _refresh().ignore();
    });
  }

  /// Was beim automatischen Wiederholen mit einem Ereignis der Zeitleiste geschieht (#132): Nur eigene
  /// Chat-Nachrichten (`m.room.message`, auch Dateien) im Status „Fehler“ werden wiederholt, und nur, wenn zu ihnen
  /// eine offene Sendung in diesem Thread und Raum gehört ([LocalSends.canRetry], #138). Die Sync-Klassen für
  /// Kalender, Einkauf und Aufgaben halten ihre eigene Warteschlange. Die Obergrenze zählt [LocalSends.takeAutoRetry].
  @visibleForTesting
  static RetryDecision retryDecision({
    required String type,
    required String senderId,
    required String me,
    required bool isError,
    required bool canRetry,
  }) =>
      senderId == me && type == EventTypes.Message && isError && canRetry ? RetryDecision.retry : RetryDecision.skip;

  /// Automatisches Wiederholen nach einem Sync: höchstens [maxRetriesPerEvent]-mal, nie parallel für dieselbe Sendung und
  /// nur, wenn der Versuch auch laufen kann ([_roomForSend]). Ein Fall für den Zähler ist erst, was wirklich ansteht: Fehlt
  /// die Verschlüsselung nur vorübergehend oder steht der Abgleich nach einem Familienwechsel noch aus, bleiben die
  /// Versuche erhalten.
  void _retryFailedSends() {
    final me = _client?.userID;
    if (me == null) return;
    final timeline = _timeline;
    final lines = <(String, Timeline)>[
      // Ein Sync kann die Kontodaten schon umgestellt haben, während die Zeitleiste noch den alten Raum zeigt.
      if (timeline != null && timeline.room.id == _familyRoom()?.id) (ChatThread.familyId, timeline),
      for (final e in _dmTimelines.entries) (e.key, e.value),
    ];
    for (final (threadId, t) in lines) {
      final roomId = t.room.id;
      if (!_canSendTo(threadId, roomId)) continue;
      for (final e in List<Event>.of(t.events)) {
        final decision = retryDecision(
          type: e.type,
          senderId: e.senderId,
          me: me,
          isError: e.status.isError,
          canRetry: _localSends.canRetry(e.eventId, threadId, roomId),
        );
        if (decision != RetryDecision.retry || !_localSends.takeAutoRetry(e.eventId)) continue;
        _retryTracked(e.eventId, threadId, roomId).catchError((Object err) {
          AppLog.e('gateway', 'Automatisches Wiederholen fehlgeschlagen', err);
        }).ignore();
      }
    }
  }

  Future<void>? _refreshRun;
  bool _refreshAgain = false;

  /// Zustandsabgleich, nie parallel: Ein Aufruf während eines laufenden Abgleichs löst genau
  /// einen weiteren Durchlauf aus und wartet auf dessen Ende.
  @override
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
        // Der Abgleich hat Zeitleisten und Nachrichtenlisten womöglich schon aktualisiert, bevor ein
        // späterer Schritt scheiterte. Ohne Meldung blieben neue Nachrichten unsichtbar, bis ein
        // anderer Anlass die Oberfläche neu aufbaut (#77).
        AppLog.e('gateway', 'Abgleich fehlgeschlagen', e);
        notifyListeners();
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
    if (_scope.enter(room?.id)) {
      _leaveFamilyScope();
      // Verlauf der neuen Familie ist nicht neu (#254, E-88). Vor dem ersten echten Sync (Start: „keine → A“) nichts.
      final live = _liveSince;
      if (live != null) _liveSince = _capLive(_later(live, _maxServerTs)!);
    }
    if (room == null) {
      _timeline?.cancelSubscriptions();
      _timeline = null;
      _timelineRoomId = null;
      _participantsRequested = false;
      _cancelParticipantsRetry();
      _family = null;
      _messages = const <ChatMessage>[];
      _resetDirectChats();
      _presence.clear();
      _presenceRoomId = null;
      // Offene Anfrage nach einem Neustart: weiter auf eine Ablehnung achten, die erste Abfrage sofort.
      // Nicht aus `_knock` heraus: Dort läge noch der alte Vermerk vor.
      if (_joinRequest() != null && !_joinRejected && _rejectionTimer == null) {
        _watchJoinRequest();
        _pollRejection('start').ignore();
      }
      notifyListeners();
      return;
    }
    if (!_participantsRequested && _participantsRetry == null) {
      _participantsRequested = true;
      final generation = _scope.generation;
      room.requestParticipants().then((_) async {
        await debugBeforeParticipantsLoaded?.call();
        // Die Liste einer früheren Familie ist keine Basis für die jetzige.
        if (_disposed || generation != _scope.generation) return;
        _participantsLoaded = true;
        _participantsFailures = 0;
        _scheduleRefresh();
      }).catchError((Object e) {
        AppLog.e('gateway', 'Mitglieder konnten nicht geladen werden', e);
        // Neuer Versuch nur für die aktuelle Familie und ein lebendes Gateway (#135).
        if (_disposed || generation != _scope.generation) return;
        _participantsRequested = false;
        _participantsFailures++;
        _participantsRetry?.cancel();
        _participantsRetry = Timer(participantsRetryAfter(_participantsFailures, base: _participantsRetryBase), () {
          _participantsRetry = null;
          if (!_disposed) _scheduleRefresh();
        });
      }).ignore();
    }
    if (_timelineRoomId != room.id) {
      await debugBeforeFamilyTimeline?.call();
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
      await debugAfterFamilyTimeline?.call();
    }
    final timeline = _timeline!;
    bool stale() => _client != client || !identical(_timeline, timeline);
    if (!await _repairEchoes(client, timeline) || stale()) return;
    _readTickets(room, timeline);
    _family = _buildFamily(room, client.userID!);
    _messages = ChatMapper.messages(timeline, threadId: ChatThread.familyId, sends: _localSends);
    if (_presenceRoomId != room.id) {
      // Andere Familie: der Status der alten gilt nicht weiter.
      _presence.clear();
      _presenceRoomId = room.id;
    }
    if (_participantsLoaded) {
      _presence.retainOnly(<String>{for (final m in _family!.joined) m.userId});
    }
    await _syncDirectChats(client, _family!, room);
    if (stale()) return;
    _acceptDirectInvites(client, _family!);
    // Erst nach vollständig geladener Mitgliederliste als Basis (Lazy Loading liefert anfangs nur Teile).
    if (_participantsLoaded) _emitMemberJoins(_family!);
    await _ensurePrivateTimeline(client);
    final private = _privateTimeline;
    if (private != null && !await _repairEchoes(client, private)) return;
    _scanForSignals(_timeline, shared: true);
    _scanForSignals(_privateTimeline, shared: false);
    notifyListeners();
  }

  /// Stellt eigene Ereignisse wieder her, die das Sync-Echo verdrängt hat (#138), vor jeder Prüfung von [arrivedEncrypted].
  /// Liefert `false`, wenn der Client unterwegs gewechselt hat oder abgemeldet ist.
  @override
  Future<bool> _repairEchoes(Client client, Timeline t) async {
    final me = client.userID;
    if (me == null) return false;
    return _echoRepair.run(t, me: me, database: client.database, isCurrent: () => _client == client);
  }

  // ------------------------------------------------------ Einzelchats (E-39)

  @override
  final Set<String> _dmCreating = <String>{};

  /// Dauerhaft ungeeignete Räume (z. B. unverschlüsselt, mit Dritten) und Räume mit vorläufigem
  /// Fehler (erneuter Versuch frühestens zur genannten Zeit).
  @override
  final Set<String> _dmFailed = <String>{};
  @override
  final Map<String, DateTime> _dmRetryAfter = <String, DateTime>{};

  /// Wird bei jedem Zurücksetzen erhöht: Abläufe, die über ein `await` hinweg laufen, verwerfen
  /// ihr Ergebnis, wenn sich die Epoche geändert hat (Abmelden, Familienwechsel).
  @override
  int _dmEpoch = 0;

  /// Ein Einzelchat-Raum hat genau zwei Mitglieder (beigetreten oder eingeladen).
  static bool _isPairRoom(Room r) {
    final joined = r.summary.mJoinedMemberCount;
    final invited = r.summary.mInvitedMemberCount ?? 0;
    return joined != null && joined + invited <= 2;
  }

  // ------------------------------------------------------ Online-Status (E-38)

  // ------------------------------------------- Identitäten der Mitglieder (S1)

  /// Vermerkte Cross-Signing-Hauptschlüssel der Mitglieder (`{mxid: öffentlicher Schlüssel}`),
  /// geräteübergreifend in den Kontodaten. Ändert sich ein Schlüssel, werden die Geräte des
  /// Mitglieds gesperrt, bis die Änderung ausdrücklich akzeptiert wird.
  static const String pinsAccountData = 'de.inneso.familynexus.identity_pins';

  @override
  final Set<String> _identityChanged = <String>{};
  @override
  final IdentityPinBook _pinBook = IdentityPinBook();

  /// Lokale Kopie der Vermerke mit Vorrang vor den Kontodaten (#142); überlebt [_resetLocal].
  @override
  late final LocalIdentityPins _localPins = LocalIdentityPins(_accountStore);
  @override
  final Set<String> _pinConflictLogged = <String>{};

  @visibleForTesting
  Map<String, String> get localIdentityPins => _localPins.loadedPins;
  @override
  final Map<String, String> _knockNonces = <String, String>{};
  @override
  bool _pinsPersisting = false;

  Family _buildFamily(Room room, String me) {
    final members = <FamilyMember>[];
    final participants = room.getParticipants();
    // Einladungen mit Link-ID im Grund ([approveRequest]): Der Link gilt als verbraucht, auch wenn der Vermerk
    // eines anderen Moderator-Geräts noch nicht angekommen ist (Pen-Test F-01). Einladen dürfen nur Moderatoren.
    for (final u in participants) {
      final reason = u.content['reason'];
      if (u.membership != Membership.invite || reason is! String || !reason.startsWith(knockReasonPrefix)) continue;
      final nonce = reason.substring(knockReasonPrefix.length);
      if (InviteLink.isNonce(nonce)) _usedTickets.add(nonce);
    }
    for (final u in participants) {
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

  // ------------------------------------------------------------- Freigabe

  @override
  void dispose() {
    _disposed = true;
    _participantsRetry?.cancel();
    _participantsRetry = null;
    _debounce?.cancel();
    _stopWatchingJoinRequest();
    _joinRequestGeneration++;
    _pollAgain = false;
    _syncSub?.cancel().ignore();
    _loginSub?.cancel().ignore();
    _timeline?.cancelSubscriptions();
    _privateTimeline?.cancelSubscriptions();
    _verificationSub?.cancel().ignore();
    _toDeviceSub?.cancel().ignore();
    _clearedSub?.cancel().ignore();
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

/// Eingegebene Anbieter-Adresse und die dazu aufgelöste, normalisierte Basis eines Anmeldevorgangs (#259).
typedef _Entered = ({ServerUrl entered, ServerUrl base});

/// [_Entered], gebunden an das Konto der Sitzung (#259, E-90).
typedef _Provider = ({String userId, ServerUrl entered, ServerUrl base});

/// Ergebnis von [SdkMatrixGateway.retryDecision].
enum RetryDecision { skip, retry }
