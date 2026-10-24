import '../../app/app_services.dart';
import '../../data/matrix/matrix_gateway.dart';
import '../../domain/server.dart';

/// Anmeldung bzw. Kontoanlage ([create]) auf der Seite des Anbieters (OAuth, E-55): Rücksprung
/// vorbereiten, Seite im Browser öffnen, auf den Rücksprung warten, Anmeldung abschließen.
///
/// Wirft `oauthCancelled`, wenn kein Browser öffnet, die Person abbricht oder die Zeit abläuft.
Future<void> signInWithBrowser(AppServices s, ServerUrl server, {required bool create}) async {
  final redirect = s.oauthRedirect;
  if (redirect == null) throw const GatewayException(GatewayError.serverUnsupported);
  final target = await redirect.prepare();
  try {
    final uri = await s.gateway.startOAuth(server: server, redirectUri: target, create: create);
    if (!await s.browser.open(uri)) throw const GatewayException(GatewayError.oauthCancelled);
    final callback = await redirect.wait();
    if (callback == null) throw const GatewayException(GatewayError.oauthCancelled);
    await s.gateway.completeOAuth(callback);
  } finally {
    redirect.cancel();
  }
}
