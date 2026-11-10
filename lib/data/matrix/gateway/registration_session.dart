part of '../sdk_matrix_gateway.dart';

/// Laufende klassische Registrierung. Das Passwort liegt nur hier und nur bis zum Ende.
class _RegistrationSession {
  _RegistrationSession({
    required this.username,
    required this.password,
    required this.displayName,
    required this.language,
    this.provider,
  });

  final String username;

  /// Eingegebene Adresse und Basis dieser Registrierung (#259).
  final _Entered? provider;
  String? password;
  final String displayName;
  final String language;
  String? session;
  List<List<String>> flows = const <List<String>>[];
  Set<String> completed = const <String>{};
  Map<String, Object?>? params;
  String? clientSecret;
  int sendAttempt = 0;
  String? sid;
}
