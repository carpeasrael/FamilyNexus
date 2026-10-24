import '../../app/app_services.dart';
import '../../data/matrix/matrix_gateway.dart';
import '../../domain/server.dart';

/// Anmeldung bzw. Kontoanlage ([create]) auf der Seite des Anbieters (OAuth, E-55): Rücksprung
/// vorbereiten, Seite im Browser öffnen, auf den passenden Rücksprung warten, Anmeldung abschließen.
///
/// Rücksprünge mit fremdem `state` werden verworfen; es wird weiter gewartet. Wirft `oauthCancelled`,
/// wenn kein Browser öffnet, die Person abbricht oder die Zeit abläuft.
Future<void> signInWithBrowser(
  AppServices s,
  ServerUrl server, {
  required bool create,
  Duration timeout = const Duration(minutes: 10),
}) async {
  final redirect = s.oauthRedirect;
  if (redirect == null) throw const GatewayException(GatewayError.serverUnsupported);
  final attempt = await redirect.prepare();
  try {
    final uri = await s.gateway.startOAuth(server: server, redirectUri: attempt.redirectUri, create: create);
    if (!await s.browser.open(uri)) throw const GatewayException(GatewayError.oauthCancelled);
    final deadline = DateTime.now().add(timeout);
    while (true) {
      final callback = await attempt.next(deadline: deadline);
      if (callback == null) throw const GatewayException(GatewayError.oauthCancelled);
      try {
        await s.gateway.completeOAuth(callback);
        return;
      } on GatewayException catch (e) {
        if (e.error != GatewayError.oauthStateMismatch) rethrow;
      }
    }
  } finally {
    attempt.cancel();
  }
}
