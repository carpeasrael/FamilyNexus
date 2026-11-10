part of '../sdk_matrix_gateway.dart';

/// SDK-Client, der während einer Browser-Anmeldung die beim Start geprüften OAuth-Metadaten festhält
/// (#222). Die OAuth-Erweiterungen des SDK rufen `getAuthMetadata` am Objekt und laden ohne Anmeldung
/// sonst jedes Mal neu; der Server könnte dann nach der Prüfung andere Endpunkte nennen.
class _AppClient extends Client {
  _AppClient(
    super.clientName, {
    required super.database,
    super.httpClient,
    super.supportedLoginTypes,
    super.verificationMethods,
    super.receiptsPublicByDefault,
    super.shareKeysWith,
    super.logLevel,
    super.requestHistoryOnLimitedTimeline,
    super.customImageResizer,
  });

  /// Gesetzt nur zwischen geprüftem Start und Abschluss/Abbruch der Browser-Anmeldung.
  GetAuthMetadataResponse? pinnedAuthMetadata;

  @override
  Future<GetAuthMetadataResponse> getAuthMetadata({
    Duration cacheLifetime = const Duration(days: 3),
    bool throwOnUpdateFailure = false,
  }) {
    final pinned = pinnedAuthMetadata;
    if (pinned != null) return Future<GetAuthMetadataResponse>.value(pinned);
    return super.getAuthMetadata(cacheLifetime: cacheLifetime, throwOnUpdateFailure: throwOnUpdateFailure);
  }
}
