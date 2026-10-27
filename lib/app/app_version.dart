/// App-Version und Build-Nummer; zusammen müssen sie `version:` in pubspec.yaml ergeben
/// (`1.2.1+17`, geprüft in test/app/app_version_test.dart).
const String appVersion = '1.2.1';
const String appBuild = '17';

/// Anzeige wie in App Store Connect und TestFlight: „1.2.1 (17)“.
const String appVersionWithBuild = '$appVersion ($appBuild)';
