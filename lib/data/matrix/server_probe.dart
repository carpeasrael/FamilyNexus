import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/app_log.dart';
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
    try {
      final req = http.Request('GET', uri)
        ..followRedirects = false
        ..headers['accept'] = 'application/json';
      final res = await _client.send(req).timeout(timeout);
      if (res.statusCode != 200) {
        await res.stream.drain<void>();
        return null;
      }
      final bytes = <int>[];
      await for (final chunk in res.stream.timeout(timeout)) {
        bytes.addAll(chunk);
        if (bytes.length > _maxBytes) return null;
      }
      final decoded = json.decode(utf8.decode(bytes, allowMalformed: true));
      return decoded is Map<String, Object?> ? decoded : null;
    } on TimeoutException {
      throw const GatewayException(GatewayError.serverUnreachable);
    } on http.ClientException {
      throw const GatewayException(GatewayError.serverUnreachable);
    } on FormatException {
      return null;
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
    return ServerInfo(
      url: base,
      versions: versionStrings,
      supportsPasswordLogin: password,
      contact: contact,
      supportPage: supportPage,
    );
  }
}
