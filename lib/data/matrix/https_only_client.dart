import 'package:http/http.dart' as http;

/// HTTP-Client, der ausschließlich `https` zulässt und Weiterleitungen nicht
/// folgt. Die Android-Netzwerkkonfiguration gilt nur für den Java-Stack, nicht
/// für `dart:io`; diese Klasse erzwingt die TLS-Pflicht deshalb in Dart.
class HttpsOnlyClient extends http.BaseClient {
  /// [inner] nur für Tests (z. B. selbstsigniertes Testzertifikat); die https-Pflicht bleibt.
  HttpsOnlyClient([http.Client? inner]) : _inner = inner ?? http.Client();

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (request.url.scheme != 'https') {
      throw http.ClientException('Nur https erlaubt', request.url);
    }
    request.followRedirects = false;
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
