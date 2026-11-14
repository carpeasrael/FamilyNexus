import '../../app/app_services.dart';
import '../../data/matrix/matrix_gateway.dart';
import '../../domain/server.dart';

/// Anmeldung bzw. Kontoanlage ([create]) auf der Seite des Anbieters (OAuth, E-55, E-91): Rücksprung
/// vorbereiten, Anbieterseite öffnen (iOS/macOS in der Anmeldesitzung des Systems, Android im Custom Tab,
/// Linux/Windows im Browser), auf den passenden Rücksprung warten, Anmeldung abschließen.
///
/// Rücksprünge mit fremdem `state` werden verworfen; auf Android, Linux und Windows wird weiter gewartet,
/// auf iOS/macOS endet der Versuch (die Sitzung liefert nur eine Antwort). Wirft `oauthCancelled`, wenn keine
/// Seite öffnet, und `oauthAborted`, wenn die Person abbricht, die Zeit abläuft oder die Sitzung ohne Rücksprung
/// endet (ein Hinweis, kein Fehler, #430). Wurde zuvor ein Rücksprung mit fremdem `state` verworfen, ist das Ende
/// ohne Rücksprung `oauthStateMismatch`: ein gefälschter Rücksprung bleibt ein Fehler.
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
    if (!await attempt.open(uri)) throw const GatewayException(GatewayError.oauthCancelled);
    final deadline = DateTime.now().add(timeout);
    var sawMismatch = false;
    while (true) {
      final callback = await attempt.next(deadline: deadline);
      if (callback == null) {
        throw GatewayException(sawMismatch ? GatewayError.oauthStateMismatch : GatewayError.oauthAborted);
      }
      try {
        await s.gateway.completeOAuth(callback);
        return;
      } on GatewayException catch (e) {
        if (e.error != GatewayError.oauthStateMismatch) rethrow;
        sawMismatch = true;
      }
    }
  } finally {
    attempt.cancel();
  }
}
