import '../../data/matrix/matrix_gateway.dart';
import '../../domain/shopping.dart';
import '../../domain/tasks.dart';
import '../../l10n/gen/app_localizations.dart';

/// Lokalisierter Text zu einem Fehler. Zeigt nie Rohtexte von Servern oder Ausnahmen.
String errorText(AppLocalizations l, Object error) {
  if (error is GatewayException) {
    return switch (error.error) {
      GatewayError.invalidCredentials => l.errInvalidCredentials,
      GatewayError.serverUnreachable => l.errServerUnreachable,
      GatewayError.serverUnsupported => l.errServerUnsupported,
      GatewayError.notAllowed => l.errNotAllowed,
      GatewayError.attachmentRejected => l.errAttachmentRejected,
      GatewayError.invalidInput => l.errInvalidInput,
      GatewayError.notFound => l.errNotFound,
      GatewayError.encryptionUnavailable => l.errEncryption,
      GatewayError.reauthRequired => l.errReauth,
      GatewayError.alreadyExists => l.errAlreadyExists,
      GatewayError.rateLimited => l.errRateLimited,
      GatewayError.unknown => l.errUnknown,
    };
  }
  if (error is ShoppingException) {
    return switch (error.error) {
      ShoppingError.invalid => l.shoppingInvalid,
      ShoppingError.notFound => l.errNotFound,
      ShoppingError.limit => l.shoppingLimit,
    };
  }
  if (error is TaskException) {
    return switch (error.error) {
      TaskError.invalid => l.tasksInvalid,
      TaskError.notFound => l.errNotFound,
      TaskError.limit => l.tasksLimit,
      TaskError.notAllowed => l.errNotAllowed,
    };
  }
  return l.errUnknown;
}
