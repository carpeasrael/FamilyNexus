import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/app_log.dart';
import '../../domain/registration.dart';
import '../../domain/server.dart';
import 'matrix_gateway.dart';

/// Prüft einen Homeserver: Erreichbarkeit, Protokollversionen, Passwort-Login
/// und Betreiberangabe. Alle Antworten sind nicht vertrauenswürdig: begrenzte
/// Größe, defensives Parsen, nur https-Ziele.
class ServerProbe {
  ServerProbe({http.Client? client, this.timeout = const Duration(seconds: 10)})
      : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  static const int _maxBytes = 64 * 1024;

  Future<Map<String, Object?>?> _getJson(Uri uri) async {
    final (status, body) = await _send('GET', uri);
    return status == 200 ? body : null;
  }

  /// Begrenzte, weiterleitungsfreie Anfrage. Liefert Status und (falls lesbar) das JSON-Objekt.
  Future<(int, Map<String, Object?>?)> _send(String method, Uri uri, {Object? body}) async {
    try {
      final req = http.Request(method, uri)
        ..followRedirects = false
        ..headers['accept'] = 'application/json';
      if (body != null) {
        req.headers['content-type'] = 'application/json';
        req.body = json.encode(body);
      }
      final res = await _client.send(req).timeout(timeout);
      final bytes = <int>[];
      await for (final chunk in res.stream.timeout(timeout)) {
        bytes.addAll(chunk);
        if (bytes.length > _maxBytes) return (res.statusCode, null);
      }
      Object? decoded;
      try {
        decoded = json.decode(utf8.decode(bytes, allowMalformed: true));
      } on FormatException {
        decoded = null;
      }
      return (res.statusCode, decoded is Map<String, Object?> ? decoded : null);
    } on TimeoutException {
      throw const GatewayException(GatewayError.serverUnreachable);
    } on http.ClientException {
      throw const GatewayException(GatewayError.serverUnreachable);
    }
  }

  static String? _cleanText(Object? v, {int max = 80}) {
    if (v is! String) return null;
    final s = v.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), ' ').trim();
    if (s.isEmpty) return null;
    return s.length > max ? s.substring(0, max) : s;
  }

  static final RegExp _verRe = RegExp(r'^v(\d{1,3})\.(\d{1,3})$');

  static (int, int)? _parse(String v) {
    final m = _verRe.firstMatch(v);
    return m == null ? null : (int.parse(m.group(1)!), int.parse(m.group(2)!));
  }

  static bool _atLeast(String v, int major, int minor) {
    final p = _parse(v);
    return p != null && (p.$1 > major || (p.$1 == major && p.$2 >= minor));
  }

  /// Aufsteigend; nicht parsebare Einträge (z. B. `r0.6.1`) zuerst.
  static int _compareVersion(String a, String b) {
    final pa = _parse(a);
    final pb = _parse(b);
    if (pa == null || pb == null) return pa == null ? (pb == null ? a.compareTo(b) : -1) : 1;
    return pa.$1 != pb.$1 ? pa.$1.compareTo(pb.$1) : pa.$2.compareTo(pb.$2);
  }

  /// Ermittelt die eigentliche Basis-URL über `.well-known`; nur https erlaubt.
  Future<ServerUrl> resolveBase(ServerUrl url) async {
    final wk = await _getJson(url.uri.replace(path: '/.well-known/matrix/client'));
    final hs = wk?['m.homeserver'];
    final base = hs is Map<String, Object?> ? hs['base_url'] : null;
    if (base is String) {
      final parsed = ServerUrl.tryParse(base);
      if (parsed != null) return parsed;
      AppLog.w('probe', 'well-known verweist auf ungültige/unsichere Adresse – ignoriert');
    }
    return url;
  }

  Future<ServerInfo> probe(ServerUrl url) async {
    final base = await resolveBase(url);
    final versions = await _getJson(base.uri.replace(path: '/_matrix/client/versions'));
    final list = versions?['versions'];
    if (list is! List<Object?> || list.isEmpty) {
      throw const GatewayException(GatewayError.serverUnsupported);
    }
    final versionStrings = list.whereType<String>().where((s) => s.length <= 16).take(40).toList();
    // Mindestens Matrix v1.1 (Anklopfen/Raumversion 7+ wird für Beitrittsanfragen benötigt).
    if (versionStrings.isEmpty || !versionStrings.any((v) => _atLeast(v, 1, 1))) {
      throw const GatewayException(GatewayError.serverUnsupported);
    }
    versionStrings.sort(_compareVersion);

    final flows = await _getJson(base.uri.replace(path: '/_matrix/client/v3/login'));
    final flowList = flows?['flows'];
    final password = flowList is List<Object?> &&
        flowList.any((f) => f is Map<String, Object?> && f['type'] == 'm.login.password');

    final (contact, supportPage) = await _support(url);
    final issuer = await oauthIssuer(base);
    return ServerInfo(
      url: base,
      versions: versionStrings,
      supportsPasswordLogin: password,
      contact: contact,
      supportPage: supportPage,
      usesOAuth: issuer != null,
    );
  }

  /// Kontakt und Hilfeseite aus `/.well-known/matrix/support` (bereinigt; nur https-Seiten).
  Future<(String?, String?)> _support(ServerUrl url) async {
    String? contact;
    String? supportPage;
    final support = await _getJson(url.uri.replace(path: '/.well-known/matrix/support'));
    if (support != null) {
      final contacts = support['contacts'];
      if (contacts is List<Object?>) {
        // Admin-Kontakt bevorzugen, sonst erster verwertbarer Eintrag.
        final maps = contacts.whereType<Map<String, Object?>>().toList()
          ..sort((a, b) => (b['role'] == 'm.role.admin' ? 1 : 0) - (a['role'] == 'm.role.admin' ? 1 : 0));
        for (final c in maps) {
          contact = _cleanText(c['matrix_id']) ?? _cleanText(c['email_address']);
          if (contact != null) break;
        }
      }
      final page = _cleanText(support['support_page'], max: 200);
      final pageUri = page == null ? null : Uri.tryParse(page);
      if (pageUri != null && pageUri.scheme == 'https' && pageUri.host.isNotEmpty && pageUri.userInfo.isEmpty) {
        supportPage = page;
      }
    }
    return (contact, supportPage);
  }

  /// Nur https-Adressen ohne Zugangsdaten.
  static Uri? _httpsUri(Object? v) {
    if (v is! String || v.length > 500) return null;
    final u = Uri.tryParse(v);
    return (u != null && u.scheme == 'https' && u.host.isNotEmpty && u.userInfo.isEmpty) ? u : null;
  }

  /// Anmeldedienst des Anbieters (OAuth, MSC2965/Matrix 1.15), `null` bei klassischer Anmeldung.
  Future<Uri?> oauthIssuer(ServerUrl base) async {
    // Nur der stabile Pfad: das SDK (getAuthMetadata) nutzt ausschließlich diesen.
    final meta = await _getJson(base.uri.replace(path: '/_matrix/client/v1/auth_metadata'));
    if (meta == null) return null;
    final issuer = _httpsUri(meta['issuer']);
    const required = <String>['authorization_endpoint', 'registration_endpoint', 'token_endpoint', 'revocation_endpoint'];
    return issuer != null && required.every((k) => _httpsUri(meta[k]) != null) ? issuer : null;
  }

  /// Wie bei [url] ein Konto angelegt wird (E-55). Fragt erst den OAuth-Dienst ab, sonst die
  /// Registrierungsabläufe (`POST /register` ohne Anmeldedaten liefert nur die Abläufe, legt nichts an).
  Future<RegistrationOptions> registrationOptions(ServerUrl url) async {
    final base = await resolveBase(url);
    final (_, supportPage) = await _support(url);
    final page = supportPage == null ? null : Uri.parse(supportPage);
    final issuer = await oauthIssuer(base);
    if (issuer != null) return RegistrationOptions(mode: RegistrationMode.oauth, webPage: issuer);
    // Ohne Benutzername/Passwort und mit `inhibit_login`: selbst ein Server ohne Pflicht-UIA gäbe kein
    // Token aus; Spezifikation: die erste Anfrage liefert nur die Abläufe (401).
    final (status, body) = await _send(
      'POST',
      base.uri.replace(path: '/_matrix/client/v3/register', queryParameters: <String, String>{'kind': 'user'}),
      body: const <String, Object?>{'inhibit_login': true},
    );
    if (status == 401 && body != null) {
      final flows = flowsFrom(body);
      if (RegistrationFlows.anySupported(flows)) return RegistrationOptions(mode: RegistrationMode.inApp, webPage: page);
    }
    // Vorübergehende Fehler sind kein „keine Registrierung“: erneut versuchen lassen.
    if (status == 429) throw const GatewayException(GatewayError.rateLimited);
    if (status >= 500) throw const GatewayException(GatewayError.serverUnreachable);
    if (status == 200) AppLog.w('probe', 'Server legte ohne Anmeldeschritte ein Konto an – ignoriert');
    return RegistrationOptions(mode: RegistrationMode.disabled, webPage: page);
  }

  /// Abläufe aus einer UIA-Antwort (`{"flows":[{"stages":[…]}]}`), begrenzt und bereinigt.
  static List<List<String>> flowsFrom(Map<String, Object?> body) {
    final flows = body['flows'];
    if (flows is! List<Object?>) return const <List<String>>[];
    return <List<String>>[
      for (final f in flows.take(20))
        if (f is Map<String, Object?> && f['stages'] is List<Object?>)
          (f['stages']! as List<Object?>).whereType<String>().where((s) => s.length <= 64).take(10).toList(),
    ];
  }

  /// Ist der Benutzername bei [base] frei? Netz- und Serverfehler ergeben `unknown`.
  Future<UsernameCheck> checkUsername(ServerUrl base, String username) async {
    try {
      final (status, body) = await _send(
        'GET',
        base.uri.replace(path: '/_matrix/client/v3/register/available', queryParameters: <String, String>{'username': username}),
      );
      if (status == 200 && body?['available'] == true) return UsernameCheck.available;
      return switch (body?['errcode']) {
        'M_USER_IN_USE' => UsernameCheck.taken,
        'M_INVALID_USERNAME' || 'M_EXCLUSIVE' => UsernameCheck.invalid,
        _ => UsernameCheck.unknown,
      };
    } on GatewayException {
      return UsernameCheck.unknown;
    }
  }
}
