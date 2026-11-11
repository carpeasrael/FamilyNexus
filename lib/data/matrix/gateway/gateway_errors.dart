part of '../sdk_matrix_gateway.dart';

/// Abbildung von SDK- und Netzfehlern auf [GatewayException] (AP-5). Keine Abhängigkeiten.
mixin _GatewayErrorsModule on ChangeNotifier {
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
}
