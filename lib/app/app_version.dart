/// App-Version und Build-Nummer; zusammen müssen sie `version:` in pubspec.yaml ergeben
/// (`1.2.2+23`, geprüft in test/app/app_version_test.dart).
const String appVersion = '1.2.2';
const String appBuild = '23';

/// Anzeige wie in App Store Connect und TestFlight: „1.2.2 (23)“.
const String appVersionWithBuild = '$appVersion ($appBuild)';
