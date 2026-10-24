/// Validierte Homeserver-URL: ausschließlich `https`, ohne Zugangsdaten,
/// Query oder Fragment (E-07).
class ServerUrl {
  const ServerUrl._(this.uri);

  final Uri uri;

  String get host => uri.host;
  @override
  String toString() => uri.toString();

  static final RegExp _hostRe = RegExp(
    r'^(?:[A-Za-z0-9](?:[A-Za-z0-9\-]{0,61}[A-Za-z0-9])?)(?:\.[A-Za-z0-9](?:[A-Za-z0-9\-]{0,61}[A-Za-z0-9])?)*$',
  );

  /// Liefert `null` bei ungültiger Eingabe. Ohne Schema wird `https://` ergänzt;
  /// ein explizites `http://` (oder anderes Schema) wird abgelehnt.
  static ServerUrl? tryParse(String input) {
    var s = input.trim();
    if (s.isEmpty || s.length > 255 || s.contains(RegExp(r'\s'))) return null;
    if (!s.contains('://')) {
      s = 'https://$s';
    }
    final Uri u;
    try {
      u = Uri.parse(s);
    } on FormatException {
      return null;
    }
    if (u.scheme != 'https') return null;
    if (u.userInfo.isNotEmpty || u.hasQuery || u.hasFragment) return null;
    if (u.host.isEmpty || u.host.length > 253) return null;
    final isIp = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(u.host) || u.host.contains(':');
    if (!isIp && !_hostRe.hasMatch(u.host)) return null;
    if (u.path.isNotEmpty && u.path != '/') return null;
    if (u.hasPort && (u.port < 1 || u.port > 65535)) return null;
    return ServerUrl._(Uri(scheme: 'https', host: u.host.toLowerCase(), port: u.hasPort ? u.port : null));
  }

  @override
  bool operator ==(Object other) => other is ServerUrl && other.uri == uri;

  @override
  int get hashCode => uri.hashCode;
}

/// Ergebnis der Server-Prüfung.
class ServerInfo {
  const ServerInfo({
    required this.url,
    required this.versions,
    required this.supportsPasswordLogin,
    this.contact,
    this.supportPage,
    this.usesOAuth = false,
  });

  final ServerUrl url;
  final List<String> versions;
  final bool supportsPasswordLogin;

  /// Betreiber ist der Server selbst ([url]); Kontakt aus `/.well-known/matrix/support`
  /// (bereinigt), `null` = nicht angegeben.
  final String? contact;
  final String? supportPage;

  /// Anmeldung und Kontoanlage laufen über die Seite des Anbieters im Browser (OAuth, E-55).
  final bool usesOAuth;
}

/// Validierung von Matrix-IDs (`@lokal:server`). Eingaben sind nicht vertrauenswürdig.
class MatrixIds {
  const MatrixIds._();

  static final RegExp _user = RegExp(r'^@[a-z0-9._=\-/+]{1,255}:[A-Za-z0-9.\-]{1,253}(:\d{1,5})?$');
  static final RegExp _room = RegExp(r'^![A-Za-z0-9._~\-]{1,255}:[A-Za-z0-9.\-]{1,253}(:\d{1,5})?$');

  static bool isUserId(String s) => s.length <= 255 && _user.hasMatch(s);
  static bool isRoomId(String s) => s.length <= 255 && _room.hasMatch(s);

  /// `@anna:beispiel.de` → `anna`; ungültige IDs bleiben unverändert.
  static String localpart(String userId) =>
      isUserId(userId) ? userId.substring(1, userId.indexOf(':')) : userId;

  /// `@anna:beispiel.de` → `beispiel.de`; `null` bei ungültiger ID.
  static String? serverName(String userId) => isUserId(userId) ? userId.substring(userId.indexOf(':') + 1) : null;
}
