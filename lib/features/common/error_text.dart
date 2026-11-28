import '../../data/matrix/matrix_gateway.dart';
import '../../data/platform/file_access.dart';
import '../../domain/anniversaries.dart';
import '../../domain/anniversary_service.dart';
import '../../domain/avatar_photo_processing.dart';
import '../../domain/avatar_photo_service.dart';
import '../../domain/cash_book_service.dart';
import '../../domain/contact_service.dart';
import '../../domain/event_theme_service.dart';
import '../../domain/event_themes.dart';
import '../../domain/receipt_photo_processing.dart';
import '../../domain/shopping.dart';
import '../../domain/tasks.dart';
import '../../l10n/gen/app_localizations.dart';

/// Ob [error] nur ein Hinweis ist, kein Fehler: Die Anmeldung beim Anbieter wurde nicht abgeschlossen (#430).
bool isNotice(Object error) => error is GatewayException && error.error == GatewayError.oauthAborted;

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
      GatewayError.usernameTaken => l.errUsernameTaken,
      GatewayError.usernameInvalid => l.errUsernameInvalid,
      GatewayError.weakPassword => l.errWeakPassword,
      GatewayError.registrationDisabled => l.errRegistrationDisabled,
      GatewayError.emailInUse => l.errEmailInUse,
      GatewayError.oauthCancelled || GatewayError.oauthStateMismatch => l.errOAuthCancelled,
      GatewayError.oauthAborted => l.errOAuthAborted,
      GatewayError.passwordChangeUnavailable => l.passwordChangeUnavailable,
      GatewayError.peerNotReachable => l.errPeerNotReachable,
      GatewayError.groupNoOtherMembers => l.errGroupNoOtherMembers,
      GatewayError.groupBusy => l.errGroupBusy,
      GatewayError.groupFull => l.errGroupFull,
      GatewayError.unknown => l.errUnknown,
    };
  }
  if (error is ContactException) {
    return switch (error.error) {
      ContactError.invalid => l.contactErrInvalid,
      ContactError.notAllowed => l.contactErrNotAllowed,
      ContactError.notFound => l.contactErrNotFound,
      ContactError.limit => l.contactErrLimit,
      ContactError.duplicate => l.contactErrDuplicate,
    };
  }
  if (error is AvatarPhotoProcessingException) {
    return switch (error.error) {
      AvatarPhotoProcessingError.unsupportedFormat => l.avatarPhotoErrFormat,
      AvatarPhotoProcessingError.tooLarge => l.avatarPhotoErrTooLarge,
      AvatarPhotoProcessingError.tooManyPixels => l.avatarPhotoErrPixels,
      AvatarPhotoProcessingError.notDecodable => l.avatarPhotoErrDecode,
      AvatarPhotoProcessingError.cannotShrink => l.avatarPhotoErrShrink,
    };
  }
  if (error is AvatarPhotoException) {
    return switch (error.error) {
      AvatarPhotoError.invalid => l.errInvalidInput,
      AvatarPhotoError.notAllowed => l.errNotAllowed,
      AvatarPhotoError.clock => l.avatarPhotoErrClock,
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
  if (error is EventThemeException) {
    return switch (error.error) {
      EventThemeError.invalid => l.themeInvalid(EventTheme.maxName),
      EventThemeError.notFound => l.errNotFound,
      EventThemeError.limit => l.themeLimit(EventTheme.maxActive),
      EventThemeError.notAllowed => l.errNotAllowed,
    };
  }
  if (error is AnniversaryException) {
    return switch (error.error) {
      AnniversaryError.invalid => l.anniversaryInvalid(AnniversaryPerson.maxName),
      AnniversaryError.notFound => l.errNotFound,
      AnniversaryError.limit => l.anniversaryLimit(AnniversaryPerson.maxActive),
    };
  }
  if (error is CashBookException) {
    return switch (error.error) {
      CashBookError.invalid => l.cashErrInvalid,
      CashBookError.notAllowed => l.errNotAllowed,
      CashBookError.notFound => l.errNotFound,
      CashBookError.limit => l.cashErrLimit,
    };
  }
  if (error is ReceiptPhotoProcessingException) {
    return switch (error.error) {
      ReceiptPhotoProcessingError.unsupportedFormat => l.cashPhotoErrFormat,
      ReceiptPhotoProcessingError.tooLarge => l.cashPhotoErrTooLarge,
      ReceiptPhotoProcessingError.tooManyPixels => l.cashPhotoErrPixels,
      ReceiptPhotoProcessingError.notDecodable => l.cashPhotoErrDecode,
      ReceiptPhotoProcessingError.cannotShrink => l.cashPhotoErrShrink,
    };
  }
  if (error is FileTooLargeException) return l.cashPhotoErrTooLarge;
  return l.errUnknown;
}
