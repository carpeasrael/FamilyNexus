// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'FamilyNexus';

  @override
  String get tabToday => 'Today';

  @override
  String get tabCalendar => 'Calendar';

  @override
  String get tabChat => 'Chat';

  @override
  String get tabFamily => 'Family';

  @override
  String get tabSettings => 'Settings';

  @override
  String get emptyToday => 'No events yet. Upcoming events will show up here.';

  @override
  String get emptyCalendar => 'The calendar is still empty.';

  @override
  String get emptyChat => 'No messages yet.';

  @override
  String get emptyFamily => 'No family has been set up yet.';

  @override
  String get settingsSectionDisplay => 'Appearance';

  @override
  String get settingsSectionPrivacy => 'Privacy';

  @override
  String get settingsSectionAbout => 'About';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get languageSystem => 'Device language';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get languageEnglish => 'English';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get themeSystem => 'Follow device';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeLight => 'Light';

  @override
  String get settingsReduceEffects => 'Reduce effects';

  @override
  String get settingsReduceEffectsHint =>
      'Less blur and glow, more opaque surfaces.';

  @override
  String get settingsSecureScreen => 'Screen protection';

  @override
  String get settingsSecureScreenHint =>
      'Blocks screenshots and hides the app in the app switcher.';

  @override
  String get settingsLicense => 'License: AGPL-3.0-or-later';

  @override
  String get settingsNoTelemetry => 'No telemetry, no ads, no analytics.';

  @override
  String get loading => 'Loading …';

  @override
  String get errorGeneric => 'Something went wrong.';

  @override
  String get retry => 'Try again';

  @override
  String get startupFailedTitle => 'Local data unreadable';

  @override
  String get startupFailedBody =>
      'The encrypted database could not be opened, for example because the device key is no longer available. For safety nothing was changed. You can reset the local data and set up again; data on the server and on other devices is kept.';

  @override
  String get startupRetry => 'Try again';

  @override
  String get startupReset => 'Reset local data';

  @override
  String get startupResetConfirmTitle => 'Really delete local data?';

  @override
  String get startupResetConfirmBody =>
      'All data of this app on this device will be deleted permanently.';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get next => 'Next';

  @override
  String get back => 'Back';

  @override
  String get done => 'Done';

  @override
  String get save => 'Save';

  @override
  String get close => 'Close';

  @override
  String onbStep(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get onbTitleLanguage => 'Welcome to FamilyNexus';

  @override
  String get onbIntro =>
      'Family calendar and messenger in one app. Your data stays on your devices and travels only end-to-end encrypted over Matrix.';

  @override
  String get onbPoint1 => 'No telemetry, no ads, no analytics.';

  @override
  String get onbPoint2 => 'Chat and shared events are end-to-end encrypted.';

  @override
  String get onbPoint3 => 'Private events never leave your own devices.';

  @override
  String get onbTitleServer => 'Choose a server';

  @override
  String serverDefault(String host) {
    return 'Default server ($host)';
  }

  @override
  String get serverCustom => 'Own server';

  @override
  String get serverUrlLabel => 'Server address (https)';

  @override
  String get serverUrlInvalid => 'Please enter a valid https address.';

  @override
  String get serverCheck => 'Check server';

  @override
  String get serverChecking => 'Checking …';

  @override
  String serverOk(String version) {
    return 'Server reachable (Matrix $version)';
  }

  @override
  String serverOperator(String name) {
    return 'Operator: $name';
  }

  @override
  String get serverNoPassword => 'This server does not allow password sign-in.';

  @override
  String get serverMetadataNote =>
      'The server cannot see content, but it does see metadata such as who writes to whom and when. Use your own server to avoid that.';

  @override
  String get onbTitleAccount => 'Sign in';

  @override
  String get accountUsername => 'Username';

  @override
  String get accountPassword => 'Password';

  @override
  String get accountLogin => 'Sign in';

  @override
  String get accountLoggingIn => 'Signing in …';

  @override
  String get accountHint =>
      'You need an existing Matrix account on the chosen server. Create new accounts with the operator.';

  @override
  String get onbTitleFamily => 'Family';

  @override
  String get familyName => 'Family name';

  @override
  String get familyCreate => 'Create family';

  @override
  String get familyCreating => 'Creating …';

  @override
  String get familyCreateHint =>
      'You become a moderator. Later, invite a second moderator so the family can still act if a device is lost.';

  @override
  String get familyMinorsNote =>
      'Children can be members. Please obtain the consent of their legal guardians.';

  @override
  String get familyRoleModerator => 'Moderator';

  @override
  String get familyRoleMember => 'Member';

  @override
  String get familyMembers => 'Members';

  @override
  String get familySecondModerator =>
      'Recommendation: appoint a second moderator.';

  @override
  String get statusInvited => 'Invited';

  @override
  String get statusRequested => 'Request';

  @override
  String get errInvalidCredentials => 'Username or password is wrong.';

  @override
  String get errServerUnreachable =>
      'Server not reachable. Check your connection.';

  @override
  String get errServerUnsupported => 'This server is not supported.';

  @override
  String get errNotAllowed => 'You do not have permission for this.';

  @override
  String get errAttachmentRejected =>
      'This attachment is not allowed (type or size).';

  @override
  String get errInvalidInput => 'Please check your input.';

  @override
  String get errNotFound => 'Not found.';

  @override
  String get errEncryption => 'Encryption unavailable. Nothing will be sent.';

  @override
  String get errUnknown => 'Unknown error.';

  @override
  String get chatHint => 'Write a message';

  @override
  String get chatSend => 'Send';

  @override
  String get chatAttach => 'Attach file';

  @override
  String get chatReply => 'Reply';

  @override
  String chatReplyingTo(String name) {
    return 'Replying to $name';
  }

  @override
  String get chatCancelReply => 'Cancel reply';

  @override
  String get chatReact => 'React';

  @override
  String get chatRetry => 'Sending failed – tap to retry';

  @override
  String get chatSending => 'Sending …';

  @override
  String get chatEncryptedNote => 'End-to-end encrypted';

  @override
  String get chatAttachmentBlocked =>
      'Attachment blocked (type or size not allowed)';

  @override
  String get chatLoadAttachment => 'Load attachment';

  @override
  String get chatSaveAttachment => 'Save';

  @override
  String chatMessageFrom(String name) {
    return 'Message from $name';
  }

  @override
  String get chatYou => 'You';

  @override
  String get logout => 'Sign out';

  @override
  String get settingsAccount => 'Account';

  @override
  String get settingsServer => 'Server';

  @override
  String get serverContactUnknown => 'Contact: not specified';

  @override
  String serverContact(String contact) {
    return 'Contact: $contact';
  }

  @override
  String get errAlreadyExists => 'This account already has a family.';

  @override
  String get errRateLimited => 'Too many requests. Please try again later.';

  @override
  String get chatUndecryptable => 'Message cannot be decrypted';

  @override
  String get syncing => 'Syncing …';

  @override
  String get reminderTitle => 'Reminder';

  @override
  String reminderBody(String duration) {
    return 'Event in $duration';
  }

  @override
  String get reminderChannelName => 'Reminders';

  @override
  String get reminderChannelDescription =>
      'Reminders for events. They never show any content.';

  @override
  String get durationNow => '0 minutes';

  @override
  String durationMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes',
      one: '1 minute',
    );
    return '$_temp0';
  }

  @override
  String durationHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours',
      one: '1 hour',
    );
    return '$_temp0';
  }

  @override
  String durationDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String reminderBefore(String duration) {
    return '$duration before';
  }

  @override
  String get reminderAtStart => 'At start time';

  @override
  String get remindersTitle => 'Reminders';

  @override
  String get remindersHint =>
      'Reminders are local notifications on this device. They never show title or location.';

  @override
  String get remindersPermissionNotifications =>
      'Notifications are blocked. Without them no reminders appear.';

  @override
  String get remindersPermissionExact =>
      'Exact alarms are not allowed. Reminders may be late.';

  @override
  String get remindersAllow => 'Allow';

  @override
  String remindersPlanned(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reminders scheduled',
      one: '1 reminder scheduled',
      zero: 'No reminders scheduled',
    );
    return '$_temp0';
  }

  @override
  String get remindersDefault => 'Default reminder';

  @override
  String get remindersNone => 'None';

  @override
  String get viewDay => 'Day';

  @override
  String get viewWeek => 'Week';

  @override
  String get viewMonth => 'Month';

  @override
  String get viewAgenda => 'Agenda';

  @override
  String get calendarToday => 'Today';

  @override
  String get calendarPrevious => 'Previous';

  @override
  String get calendarNext => 'Next';

  @override
  String get calendarAll => 'Everyone';

  @override
  String get calendarFilterPerson => 'Filter by person';

  @override
  String get calendarNoEvents => 'No events';

  @override
  String get calendarAllDay => 'All day';

  @override
  String get calendarNewEvent => 'New event';

  @override
  String calendarEventsOnDay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count events',
      one: '1 event',
      zero: 'No events',
    );
    return '$_temp0';
  }

  @override
  String get todayNext => 'Upcoming events';

  @override
  String get todayUnread => 'Unread messages';

  @override
  String todayUnreadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unread messages',
      one: '1 unread message',
      zero: 'No unread messages',
    );
    return '$_temp0';
  }

  @override
  String get todayNoUpcoming => 'No events in the next 30 days.';

  @override
  String get todayOpenChat => 'Open chat';

  @override
  String get visibilityPrivate => 'Private';

  @override
  String get visibilityShared => 'Shared';

  @override
  String get visibilityPrivateHint =>
      'Only on your own devices. Never sent to the family.';

  @override
  String get visibilitySharedHint =>
      'Sent encrypted to the family. Members see the event and can accept or decline.';

  @override
  String get visibilityChangeNote =>
      'Content already sent to the family stays on their devices, even if you make the event private later.';

  @override
  String get eventNew => 'New event';

  @override
  String get eventEdit => 'Edit event';

  @override
  String get eventTitle => 'Title';

  @override
  String get eventTitleRequired => 'Please enter a title.';

  @override
  String get eventAllDay => 'All day';

  @override
  String get eventStart => 'Start';

  @override
  String get eventEnd => 'End';

  @override
  String get eventEndBeforeStart => 'The end is before the start.';

  @override
  String get eventLocation => 'Location';

  @override
  String get eventNote => 'Note';

  @override
  String get eventColor => 'Color';

  @override
  String eventColorName(int number) {
    return 'Color $number';
  }

  @override
  String get eventAttendees => 'Attendees';

  @override
  String get eventVisibility => 'Visibility';

  @override
  String eventTimeZone(String zone) {
    return 'Time zone: $zone';
  }

  @override
  String get eventSaveError => 'The event could not be saved.';

  @override
  String get eventRepeat => 'Repeat';

  @override
  String get repeatNone => 'None';

  @override
  String get repeatDaily => 'Daily';

  @override
  String get repeatWeekly => 'Weekly';

  @override
  String get repeatMonthly => 'Monthly';

  @override
  String get repeatYearly => 'Yearly';

  @override
  String get repeatEvery => 'Every';

  @override
  String get repeatUnitDays => 'days';

  @override
  String get repeatUnitWeeks => 'weeks';

  @override
  String get repeatUnitMonths => 'months';

  @override
  String get repeatUnitYears => 'years';

  @override
  String get repeatEnds => 'Ends';

  @override
  String get repeatEndsNever => 'Never';

  @override
  String get repeatEndsOn => 'On date';

  @override
  String get repeatEndsAfter => 'After count';

  @override
  String get repeatCount => 'Count';

  @override
  String get repeatUntil => 'Last day';

  @override
  String repeatSummaryDaily(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count days',
      one: 'Daily',
    );
    return '$_temp0';
  }

  @override
  String repeatSummaryWeekly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count weeks',
      one: 'Weekly',
    );
    return '$_temp0';
  }

  @override
  String repeatSummaryMonthly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count months',
      one: 'Monthly',
    );
    return '$_temp0';
  }

  @override
  String repeatSummaryYearly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count years',
      one: 'Yearly',
    );
    return '$_temp0';
  }

  @override
  String get weekdayMon => 'Mon';

  @override
  String get weekdayTue => 'Tue';

  @override
  String get weekdayWed => 'Wed';

  @override
  String get weekdayThu => 'Thu';

  @override
  String get weekdayFri => 'Fri';

  @override
  String get weekdaySat => 'Sat';

  @override
  String get weekdaySun => 'Sun';

  @override
  String get eventDelete => 'Delete event';

  @override
  String get eventDeleteConfirm => 'Really delete this event?';

  @override
  String get eventDeleteSeriesConfirm =>
      'Delete all occurrences or just this one?';

  @override
  String get eventDeleteThis => 'Only this one';

  @override
  String get eventDeleteAll => 'All';

  @override
  String get eventShareInChat => 'Share in chat';

  @override
  String get eventShared => 'Shared in chat';

  @override
  String eventOwner(String name) {
    return 'By $name';
  }

  @override
  String get eventOwnerYou => 'By you';

  @override
  String get eventRsvp => 'Response';

  @override
  String get rsvpAccept => 'Accept';

  @override
  String get rsvpDecline => 'Decline';

  @override
  String get rsvpMaybe => 'Maybe';

  @override
  String get rsvpAccepted => 'Accepted';

  @override
  String get rsvpDeclined => 'Declined';

  @override
  String get rsvpMaybeStatus => 'Maybe';

  @override
  String get rsvpNone => 'No response';

  @override
  String get eventHistory => 'History';

  @override
  String eventVersion(int version) {
    return 'Version $version';
  }

  @override
  String get eventRecurring => 'Repeats';

  @override
  String get eventCancelled => 'Deleted';

  @override
  String get eventReadOnly => 'Only the creator can change this event.';

  @override
  String get eventYourReminders => 'Your reminders';

  @override
  String get eventResetReminders => 'Use default';

  @override
  String get chatEventCard => 'Event';

  @override
  String get chatEventMissing => 'Event not available';

  @override
  String get settingsReminders => 'Reminders';

  @override
  String get repeatUntilInvalid =>
      'The last repeat date is before the first event.';

  @override
  String get errReauth => 'Please confirm your password.';

  @override
  String get securityTitle => 'Key backup';

  @override
  String get securityIntro =>
      'So that only your own devices can read your encrypted messages and events, you now set up a key backup.';

  @override
  String get securitySetupButton => 'Set up key backup';

  @override
  String get securitySettingUp => 'Setting up …';

  @override
  String get securityKeyTitle => 'Your recovery key';

  @override
  String get securityKeyHint =>
      'Write it down on paper and keep it safe. It is shown only now. Without it and without a verified device, your messages are lost if you lose all devices.';

  @override
  String get securityKeySaved => 'I have written the key down safely.';

  @override
  String get securityRestoreTitle => 'Verify this device';

  @override
  String get securityRestoreIntro =>
      'Your account is already protected. Verify this device with another one of your devices or with your recovery key.';

  @override
  String get securityVerifyWithDevice => 'Verify with another device';

  @override
  String get securityNoOtherDevice =>
      'No other device found. Use the recovery key.';

  @override
  String get securityRestoreKeyLabel => 'Recovery key';

  @override
  String get securityRestoreButton => 'Restore with key';

  @override
  String get securityRestoring => 'Restoring …';

  @override
  String get securityRestoreFailed => 'The key does not match.';

  @override
  String get securityPasswordTitle => 'Confirm password';

  @override
  String get securityPasswordHint =>
      'The server asks for your password. It is not stored.';

  @override
  String get securityStatusReady => 'This device is verified.';

  @override
  String get securityStatusNeeds => 'This device is not verified yet.';

  @override
  String get securityDevices => 'Devices of your account';

  @override
  String get securityDeviceThis => 'This device';

  @override
  String get securityDeviceVerified => 'Verified';

  @override
  String get securityDeviceUnverified => 'Not verified';

  @override
  String get securityVerifyDevice => 'Verify';

  @override
  String get securityVerifyPerson => 'Verify';

  @override
  String get verifyTitle => 'Verification';

  @override
  String verifyIncoming(String peer) {
    return '$peer wants to start a verification.';
  }

  @override
  String get verifyWaiting => 'Waiting for the other side …';

  @override
  String get verifyCompare =>
      'Compare these symbols with the ones on the other device. They must match in the same order.';

  @override
  String get verifyMatch => 'They match';

  @override
  String get verifyNoMatch => 'They do not match';

  @override
  String get verifyWaitingConfirm => 'Waiting for the other side to confirm …';

  @override
  String get verifyDone => 'Verified.';

  @override
  String get verifyCancelled => 'The verification was cancelled.';

  @override
  String get accept => 'Accept';

  @override
  String get decline => 'Decline';

  @override
  String get familyManage => 'Management';

  @override
  String get familyInvite => 'Invite a member';

  @override
  String get familyInviteLinkTitle => 'Invitation link';

  @override
  String get familyInviteLinkHint =>
      'Valid for 24 hours. Whoever opens the link only sends a request – you confirm it.';

  @override
  String get familyInviteShowQr => 'Show QR code';

  @override
  String get familyInviteCopyLink => 'Copy link';

  @override
  String get familyInviteCopied => 'Link copied.';

  @override
  String get familyInviteById => 'Invite Matrix ID';

  @override
  String get familyInviteByIdHint => '@name:server';

  @override
  String get familyInviteSend => 'Invite';

  @override
  String get familyInviteInvalidId => 'Please enter a valid Matrix ID.';

  @override
  String get familyInviteSent => 'Invitation sent.';

  @override
  String get familyRequests => 'Join requests';

  @override
  String get familyRequestApprove => 'Approve';

  @override
  String get familyRequestReject => 'Reject';

  @override
  String get familyMemberPromote => 'Make moderator';

  @override
  String get familyMemberRemove => 'Remove';

  @override
  String familyMemberRemoveConfirm(String name) {
    return 'Really remove $name from the family? Room keys are renewed; $name can no longer read new content.';
  }

  @override
  String familyMemberPromoteConfirm(String name) {
    return 'Make $name a moderator? Moderators can invite, promote and remove.';
  }

  @override
  String get familyRename => 'Change family name';

  @override
  String get familyRenamed => 'Name changed.';

  @override
  String get familyDone => 'Done.';

  @override
  String get familyOnlyModerators => 'Only moderators manage the family.';

  @override
  String get joinTitle => 'Join a family';

  @override
  String get joinHint =>
      'Paste an invitation link or open the link or QR code with the camera app.';

  @override
  String get joinLinkLabel => 'Invitation link';

  @override
  String get joinLinkInvalid => 'This link is invalid or expired.';

  @override
  String get joinSend => 'Send join request';

  @override
  String get joinConfirmTitle => 'Request to join?';

  @override
  String joinConfirmBody(String server, String inviter) {
    return 'You ask to join the family on server $server. Invited by $inviter. A moderator must confirm.';
  }

  @override
  String get joinPending => 'Request sent. Waiting for a moderator to confirm.';

  @override
  String get joinCancel => 'Withdraw request';

  @override
  String get invitationsTitle => 'Invitations';

  @override
  String invitationFrom(String inviter) {
    return 'Invitation from $inviter';
  }

  @override
  String get onbCreateOrJoin => 'Create a new family or join an existing one.';

  @override
  String get onbCreateTab => 'Create';

  @override
  String get onbJoinTab => 'Join';

  @override
  String get onbChangeAccount => 'Sign out';

  @override
  String get lockTitle => 'FamilyNexus is locked';

  @override
  String get lockHint =>
      'Confirm with your device credentials (PIN, pattern, password or biometrics).';

  @override
  String get lockUnlock => 'Unlock';

  @override
  String get lockReason => 'Unlock FamilyNexus';

  @override
  String get settingsLock => 'App lock';

  @override
  String get settingsLockHint =>
      'Locks the app after inactivity. Confirmation uses your device lock; the app stores no PIN of its own.';

  @override
  String get settingsLockUnavailable =>
      'No secure screen lock is set up on this device.';

  @override
  String get settingsLockFailed => 'The confirmation was not successful.';

  @override
  String get settingsLockTimeout => 'Lock after';

  @override
  String get lockImmediately => 'Immediately';

  @override
  String get lock1min => '1 minute';

  @override
  String get lock5min => '5 minutes';

  @override
  String get lock15min => '15 minutes';

  @override
  String get settingsPrivacyPolicy => 'Privacy policy';

  @override
  String get settingsDeleteData => 'Delete all local data';

  @override
  String get settingsDeleteDataHint =>
      'Signs you out and deletes the database, keys and reminders on this device.';

  @override
  String get deleteDataTitle => 'Delete all local data?';

  @override
  String get deleteDataBody =>
      'All data of this app on this device will be deleted permanently and you will be signed out. Messages and shared events on other family members\' devices cannot technically be deleted. Your account on the server remains; ask the server operator to delete it.';

  @override
  String get deleteDataConfirm => 'Delete permanently';

  @override
  String get privacyTitle => 'Privacy policy';

  @override
  String get privacy1Title => 'Who processes your data?';

  @override
  String get privacy1Body =>
      'FamilyNexus is free software (AGPL-3.0). The app sends no data to its developers and contains no telemetry, advertising or analytics. The operator of the Matrix server you choose is responsible for processing on the server; it is shown during setup.';

  @override
  String get privacy2Title => 'What data exists?';

  @override
  String get privacy2Body =>
      'Chat messages, files, shared and private events, responses, the shopping list, family members and your settings. Events and messages are stored encrypted (SQLCipher) on your device. The key is held in the Android keystore and never in a file.';

  @override
  String get privacy3Title => 'What does the server see?';

  @override
  String get privacy3Body =>
      'Messages, files and shared events are end-to-end encrypted (Matrix, Olm/Megolm). The server only sees encrypted events. Metadata such as account ID, timestamps, room size and devices remains visible to the operator. Use your own server to avoid that.';

  @override
  String get privacy4Title => 'Private events';

  @override
  String get privacy4Body =>
      'Private events are never sent to the family. Between your own devices they are synchronised through a private, encrypted room that only your account belongs to.';

  @override
  String get privacy5Title => 'Reminders and notifications';

  @override
  String get privacy5Body =>
      'Reminders are local notifications. They never show title, location or note, only “Event in …”. There is no third-party push service.';

  @override
  String get privacy6Title => 'Permissions';

  @override
  String get privacy6Body =>
      'Internet (connection to the server), notifications and exact alarms (reminders), boot notification (re-schedule reminders) and device credentials (app lock). No contacts, location, camera or microphone are needed.';

  @override
  String get privacy7Title => 'Backup and deletion';

  @override
  String get privacy7Body =>
      'Android backups are switched off. If you deliberately save an attachment with “Save”, the decrypted file lies outside the app in the folder you chose. “Delete all local data” removes all data, keys and reminders from this device. Messages on other members\' devices cannot technically be force-deleted. Your recovery key is the only way to rescue messages after losing all devices – keep it safe.';

  @override
  String get privacy8Title => 'Children';

  @override
  String get privacy8Body =>
      'Children can be family members. This requires the consent of their legal guardians; accounts of minors go through invitation and confirmation by a moderator.';

  @override
  String get privacy9Title => 'Your rights';

  @override
  String get privacy9Body =>
      'You can request access, correction and deletion at any time. You manage local data in this app; server data with your server\'s operator.';

  @override
  String get familyRequestCheckValid => 'Valid invitation link';

  @override
  String get familyRequestCheckExpired => 'Link expired';

  @override
  String get familyRequestCheckUnknown => 'Unknown link – not issued by you';

  @override
  String familyRequestApproveConfirm(String user) {
    return 'Add $user to the family? The invitation link is used up.';
  }

  @override
  String get identityVerified => 'Verified';

  @override
  String get identityPinned => 'Not checked in person';

  @override
  String get identityUnknown => 'No keys known';

  @override
  String get identityChanged => 'Identity changed';

  @override
  String identityChangedWarning(String name) {
    return '$name\'s security key has changed. Their devices are blocked until you have checked each other in person using the emoji comparison.';
  }

  @override
  String get identityAccept => 'Accept change';

  @override
  String get identityAcceptConfirm =>
      'Only accept after you have checked in person (e.g. via emoji comparison). Continue?';

  @override
  String invitationUnexpectedWarning(String inviter) {
    return 'This invitation does not belong to a join request of yours. Only accept it if you know $inviter and expected the invitation.';
  }

  @override
  String memberActionsTooltip(String name) {
    return 'Actions for $name';
  }

  @override
  String familyInviteConfirm(String user) {
    return 'Invite $user? Invitees receive the family\'s message keys even before accepting – only invite people you know for certain.';
  }

  @override
  String get attachmentSaveWarning =>
      'The file is decrypted and saved unencrypted in the folder you choose. It stays there after logging out or deleting app data. Continue?';

  @override
  String get tabShopping => 'Shopping';

  @override
  String get settingsShareOnlineStatus => 'Share online status';

  @override
  String get settingsShareOnlineStatusHint =>
      'Shows your family when you are using the app. It is sent end-to-end encrypted to family members\' devices only. When off, you appear offline to others.';

  @override
  String get presenceOnline => 'Online';

  @override
  String get presenceOffline => 'Offline';

  @override
  String get presenceUnknown => 'Status unknown';

  @override
  String presenceLastSeen(String ago) {
    return 'Last online $ago';
  }

  @override
  String get presenceAgoNow => 'just now';

  @override
  String presenceAgoMinutes(int count) {
    return '$count min ago';
  }

  @override
  String presenceAgoHours(int count) {
    return '$count h ago';
  }

  @override
  String presenceAgoDays(int count) {
    return '$count d ago';
  }

  @override
  String get presenceSelfHidden => 'Your status is not shared';

  @override
  String get presenceSelf => 'You are online';

  @override
  String presenceOf(String name, String status) {
    return '$name: $status';
  }

  @override
  String get chatThreads => 'Conversations';

  @override
  String chatThreadFamily(String name) {
    return 'Family chat $name';
  }

  @override
  String chatThreadDirect(String name) {
    return 'Direct chat with $name';
  }

  @override
  String chatUnreadCount(int count) {
    return '$count unread';
  }

  @override
  String chatDirectNote(String name) {
    return 'Only between you and $name, end-to-end encrypted';
  }

  @override
  String get chatDirectNotAvailable =>
      'This conversation is no longer available.';

  @override
  String get familyWriteMessage => 'Send message';

  @override
  String get shoppingTitle => 'Shopping list';

  @override
  String get shoppingNote => 'Shared with your family, end-to-end encrypted';

  @override
  String get shoppingHintItem => 'What do you need?';

  @override
  String get shoppingHintQuantity => 'Quantity (optional)';

  @override
  String get shoppingAdd => 'Add';

  @override
  String get shoppingEmpty =>
      'The shopping list is empty. Add something above.';

  @override
  String shoppingOpenHeader(int count) {
    return 'To buy ($count)';
  }

  @override
  String shoppingDoneHeader(int count) {
    return 'Done ($count)';
  }

  @override
  String get shoppingClearDone => 'Remove done items';

  @override
  String shoppingClearConfirm(int count) {
    return 'Remove $count done items for the whole family?';
  }

  @override
  String shoppingCleared(int count) {
    return '$count items removed';
  }

  @override
  String get shoppingEditTitle => 'Edit item';

  @override
  String get shoppingEdit => 'Edit';

  @override
  String get shoppingDelete => 'Delete';

  @override
  String shoppingMarkDone(String name) {
    return 'Mark $name as done';
  }

  @override
  String shoppingMarkOpen(String name) {
    return 'Put $name back on the list';
  }

  @override
  String shoppingLastBy(String name) {
    return 'last changed by $name';
  }

  @override
  String get shoppingLimit =>
      'The shopping list is full (at most 300 items). Remove done items.';

  @override
  String get shoppingInvalid =>
      'This item is invalid (empty, too long or with forbidden characters).';

  @override
  String get todayOnlineHeader => 'Who is online';

  @override
  String get todayNobodyOnline => 'Nobody else is online right now.';

  @override
  String todayShoppingOpen(int count) {
    return 'Shopping list: $count open';
  }

  @override
  String get privacy10Title => 'Online status, direct chats, shopping list';

  @override
  String get privacy10Body =>
      'The online status (\"online\" or \"offline\" with a time) is only sent as an end-to-end encrypted device message to devices of joined family members and is never stored; you can switch it off in the settings. Direct chats are encrypted rooms between two family members. The shopping list is transferred encrypted in the family room like shared events and is stored encrypted on your device; all family members can change it. The server only sees metadata such as timing and size.';

  @override
  String onbFamilyFound(String name) {
    return 'Found family “$name” – you are already a member. Finishing setup.';
  }

  @override
  String get settingsAccent => 'Accent colour';

  @override
  String get settingsAccentHint =>
      'Neon colour for buttons, selection and highlights. Applies to the light and the dark design.';

  @override
  String get accentTeal => 'Teal';

  @override
  String get accentMagenta => 'Magenta';

  @override
  String get accentViolet => 'Violet';

  @override
  String get accentSky => 'Sky blue';

  @override
  String get accentLime => 'Lime';

  @override
  String get accentOrange => 'Orange';

  @override
  String get accentRose => 'Rose';

  @override
  String get accentGreen => 'Green';

  @override
  String get menuOpen => 'Open menu';

  @override
  String get menuTitle => 'Menu';
}
