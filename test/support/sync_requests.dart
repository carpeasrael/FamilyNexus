/// Trennt in den HTTP-Fakes der Gateway-Tests die Ablehnungsabfrage der Beitrittsanfrage (#43, #116) vom
/// Sync-Loop des SDK.
///
/// Die Ablehnungsabfrage übergibt ihren Filter inline als JSON und läuft mit `timeout=0`
/// (`SdkMatrixGateway.rejectionPollFilter`, `gateway/invitations.dart`). Der SDK-Sync sendet nur die Filter-ID
/// (`filter=1` aus der Antwort auf `/filter`); `timeout=0` allein trennt nicht, denn der erste SDK-Sync hat es auch.
/// `set_presence=offline` trennt seit #451 nicht mehr: Auch der SDK-Sync meldet das Konto als offline.
bool isRejectionPoll(Uri sync) {
  final filter = sync.queryParameters['filter'];
  return filter != null && filter.startsWith('{') && sync.queryParameters['timeout'] == '0';
}
