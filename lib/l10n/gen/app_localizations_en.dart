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
      'Calendar and chat for your family – private and encrypted. No ads, no data collection.';

  @override
  String get onbPoint1 => 'No telemetry, no ads, no analytics.';

  @override
  String get onbPoint2 => 'Chat and shared events are end-to-end encrypted.';

  @override
  String get onbPoint3 => 'Private events never leave your own devices.';

  @override
  String get serverUrlInvalid => 'Please enter a valid https address.';

  @override
  String serverOperator(String name) {
    return 'Operator: $name';
  }

  @override
  String get serverNoPassword =>
      'This provider does not allow signing in with a password.';

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
  String get errServerUnsupported =>
      'FamilyNexus does not support this provider. Please choose another one under “Advanced”.';

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
  String get securityTitle => 'Emergency key and devices';

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
  String get familyInviteLinkTitle => 'Invite someone';

  @override
  String familyInviteLinkHint(String validity) {
    return 'The link is valid for $validity and can be used once. Whoever opens it sends you a request – you confirm it.';
  }

  @override
  String get familyInviteShowQr => 'Show QR code';

  @override
  String get familyInviteCopyLink => 'Copy link';

  @override
  String get familyInviteCopied => 'Link copied.';

  @override
  String get familyInviteById => 'Invite by user ID';

  @override
  String get familyInviteByIdHint => '@name:server';

  @override
  String get familyInviteSend => 'Invite';

  @override
  String get familyInviteInvalidId =>
      'Please enter a valid user ID, e.g. @anna:example.org.';

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
      'Paste the invitation link or open the link or QR code with the camera app.';

  @override
  String get joinLinkLabel => 'Invitation link';

  @override
  String get joinSend => 'Request to join';

  @override
  String get joinPending =>
      'Almost done! Your request is on its way. As soon as it is confirmed, you are in.';

  @override
  String get joinCancel => 'Withdraw request';

  @override
  String get invitationsTitle => 'Invitations';

  @override
  String invitationFrom(String inviter) {
    return 'Invitation from $inviter';
  }

  @override
  String get onbCreateOrJoin => 'Start a new family or join an existing one.';

  @override
  String get onbCreateTab => 'Create';

  @override
  String get onbJoinTab => 'Join';

  @override
  String get onbChangeAccount => 'Use a different account';

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
      'FamilyNexus is free software (AGPL-3.0). The app sends no data to the developers and contains no telemetry, ads or analytics. Responsible for processing on the server is the operator of the provider you chose (Matrix server); it is shown during setup under “Advanced”. If you create an account in the app, your name, username, password and – if the provider requires it – your email address go only to this provider. With providers that sign you in via the browser (e.g. matrix.org) you enter these details directly on their page.';

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
      'Android backups are disabled. If you deliberately save an attachment via “Save”, the decrypted file is stored outside the app in the folder you chose. “Delete all local data” removes all data, keys and reminders from this device. Messages on other members’ devices cannot be forcibly deleted. Your emergency key is the only way to recover messages after losing all devices – keep it safe. If you copy it, the clipboard is cleared after one minute; if you save it as a file, it is stored unencrypted in the location you chose.';

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
  String get familyRequestCheckUnknown =>
      'Unknown link – not issued by a moderator';

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
  String menuVersion(String version) {
    return 'Version $version';
  }

  @override
  String get menuTitle => 'Menu';

  @override
  String get chatReport => 'Report message';

  @override
  String chatBlockSender(String name) {
    return 'Block $name';
  }

  @override
  String get reportTitle => 'Report message';

  @override
  String reportIntro(String server) {
    return 'The report goes to the operator of your server ($server). They cannot read the encrypted content. What is sent is the message ID, the chosen reason and your optional text – the operator can read that text.';
  }

  @override
  String get reportCategorySpam => 'Spam or advertising';

  @override
  String get reportCategoryHarassment => 'Harassment or abuse';

  @override
  String get reportCategoryInappropriate => 'Inappropriate content';

  @override
  String get reportCategoryOther => 'Other reason';

  @override
  String get reportDetailsHint => 'Optional: What happened?';

  @override
  String get reportSend => 'Report';

  @override
  String get reportDone => 'Report sent.';

  @override
  String get reportBlockOffer => 'Block sender';

  @override
  String blockConfirmTitle(String name) {
    return 'Block $name?';
  }

  @override
  String blockConfirmBody(String name) {
    return 'Messages and the direct chat of $name are hidden on this device. $name is not told and stays a member of the family. You can undo the block at any time in the settings.';
  }

  @override
  String get blockConfirmAction => 'Block';

  @override
  String blockDone(String name) {
    return '$name is blocked.';
  }

  @override
  String get unblockAction => 'Unblock';

  @override
  String unblockDone(String name) {
    return '$name is unblocked.';
  }

  @override
  String get memberBlockedBadge => 'Blocked';

  @override
  String get settingsBlockedUsers => 'Blocked members';

  @override
  String get settingsBlockedUsersHint =>
      'Messages from blocked members are hidden.';

  @override
  String get blockedUsersEmpty => 'You have not blocked anyone.';

  @override
  String get privacy11Title => 'Reporting and blocking';

  @override
  String get privacy11Body =>
      'The app remembers blocked members only on this device (encrypted database); the list is not transmitted. If you report a message, the operator of your server receives the message ID, the chosen reason and your optional text. They cannot read the encrypted content.';

  @override
  String get familyInviteMail => 'Send by email';

  @override
  String get inviteMailSubject => 'Invitation to FamilyNexus';

  @override
  String inviteMailBody(String family, String link, String validity) {
    return 'Hello,\n\nI am inviting you to our family “$family” on FamilyNexus – family calendar and chat, private and encrypted.\n\nHow it works (about 2 minutes):\n1. Install the FamilyNexus app.\n2. Tap this link – or open the app, choose “I was invited” and paste the link:\n\n$link\n\n3. Create your account.\n4. I confirm you, and you are in.\n\nThe link is valid for $validity.';
  }

  @override
  String get familyInviteMailFailed =>
      'No mail app found. The link was copied instead.';

  @override
  String get onbInvitedTitle => 'You have been invited';

  @override
  String onbInvitedJoin(String family) {
    return 'Join \"$family\"';
  }

  @override
  String get onbInvitedOther => 'Create or join a different family instead';

  @override
  String get tasksTitle => 'Tasks';

  @override
  String get tasksNote =>
      'Only moderators create lists. Only the assigned person can tick items off.';

  @override
  String get tasksEmpty => 'No task lists yet.';

  @override
  String get tasksSectionMine => 'Assigned to me';

  @override
  String get tasksSectionOthers => 'Other lists';

  @override
  String get tasksNew => 'New task list';

  @override
  String get tasksEditTitle => 'Edit task list';

  @override
  String get tasksFieldTitle => 'Title';

  @override
  String get tasksFieldAssignee => 'Assigned to';

  @override
  String get tasksFieldInterval => 'Repeats';

  @override
  String get tasksFieldItems => 'Items (one per line)';

  @override
  String get tasksIntervalDaily => 'Daily';

  @override
  String get tasksIntervalWeekly => 'Weekly';

  @override
  String get tasksIntervalMonthly => 'Monthly';

  @override
  String get tasksResetDaily => 'Restarts every day at midnight';

  @override
  String tasksAssignedTo(String name) {
    return 'Assigned to $name';
  }

  @override
  String tasksProgress(int done, int total) {
    return '$done of $total done';
  }

  @override
  String get tasksDelete => 'Delete list';

  @override
  String tasksDeleteConfirm(String title) {
    return 'Delete list “$title”?';
  }

  @override
  String tasksMarkDone(String item) {
    return 'Mark $item as done';
  }

  @override
  String tasksMarkUndone(String item) {
    return 'Undo completion of $item';
  }

  @override
  String get tasksCommentTitle => 'Done';

  @override
  String get tasksCommentHint => 'Comment (optional)';

  @override
  String get tasksConfirmDone => 'Done';

  @override
  String tasksDoneOn(String date, String time) {
    return 'Done on $date at $time';
  }

  @override
  String get tasksHistory => 'History';

  @override
  String get tasksHistoryEmpty => 'No entries yet.';

  @override
  String tasksHistoryDone(String item) {
    return '$item done';
  }

  @override
  String tasksHistoryUndone(String item) {
    return '$item undone';
  }

  @override
  String tasksHistoryLine(String name, String date, String time) {
    return '$name · $date $time';
  }

  @override
  String get tasksInvalid =>
      'Please enter a title, a person and at least one item.';

  @override
  String get tasksLimit =>
      'Limit reached: too many task lists, items or entries.';

  @override
  String todayTasksOpen(int count) {
    return 'Tasks for you: $count open';
  }

  @override
  String get privacy12Title => 'Task lists';

  @override
  String get privacy12Body =>
      'Task lists and their history (who completed which item and when, including an optional comment) are sent end-to-end encrypted in the family room like shared events and are stored encrypted on your device. All family members can read them. The server only sees metadata such as times and size.';

  @override
  String get webUnlockTitleCreate => 'Set up the browser vault';

  @override
  String get webUnlockBodyCreate =>
      'This browser stores your data encrypted. Choose a password for it. It is not stored anywhere and cannot be recovered; if you forget it, the only way out is to delete all local data and sign in again.';

  @override
  String get webUnlockTitle => 'Unlock FamilyNexus';

  @override
  String get webUnlockBody => 'Enter the password for this browser.';

  @override
  String get webPassword => 'Password';

  @override
  String get webPasswordRepeat => 'Repeat password';

  @override
  String get webPasswordTooShort => 'At least 10 characters.';

  @override
  String get webPasswordMismatch => 'The passwords do not match.';

  @override
  String get webPasswordWrong => 'Wrong password.';

  @override
  String get webUnlockAction => 'Unlock';

  @override
  String get webCreateAction => 'Create vault';

  @override
  String get webUnlockBusy => 'Unlocking …';

  @override
  String get webForgotPassword => 'Forgot the password? Delete all local data';

  @override
  String get webTabBusyTitle => 'FamilyNexus is already open';

  @override
  String get webTabBusyBody =>
      'The app is already running in another tab or window of this browser. Two tabs at the same time would corrupt the local data. Close the other tab and try again.';

  @override
  String get privacy13Title => 'Browser version';

  @override
  String get privacy13Body =>
      'In the web version your data is stored encrypted in this browser (IndexedDB, SQLite3MultipleCiphers). The key is protected by your browser password, which is stored nowhere. There is no screen protection and no reminders while the page is closed. Do not use the web version on a foreign or shared computer. The page loads nothing from third parties.';

  @override
  String get startCreateTitle => 'Start a new family';

  @override
  String get startCreateBody =>
      'You set everything up and then invite your family.';

  @override
  String get startInvitedTitle => 'I was invited';

  @override
  String get startInvitedBody => 'You received a link or QR code.';

  @override
  String get startLoginTitle => 'I already have an account';

  @override
  String get startLoginBody =>
      'You already use FamilyNexus, e.g. on another device.';

  @override
  String get startHaveAccount => 'I already have an account';

  @override
  String get regTitle => 'Create account';

  @override
  String get regNameLabel => 'What is your name?';

  @override
  String get regNameHint => 'e.g. Anna Miller';

  @override
  String get regUsernameLabel => 'Your username';

  @override
  String get regUsernameHint =>
      'You sign in with it. 3 to 32 characters: lowercase letters, digits, dot, underscore or hyphen.';

  @override
  String get regUsernameFree => 'This username is available.';

  @override
  String get regUsernameTaken => 'This username is already taken.';

  @override
  String regUsernameTakenSuggest(String suggestion) {
    return 'Already taken – how about “$suggestion”?';
  }

  @override
  String regUseSuggestion(String suggestion) {
    return 'Use “$suggestion”';
  }

  @override
  String get regUsernameInvalid =>
      'Please use 3 to 32 characters: lowercase letters, digits, dot, underscore or hyphen.';

  @override
  String get regPasswordHint =>
      'At least 8 characters. You will also use your username and password to sign in on a new device.';

  @override
  String get passwordShow => 'Show password';

  @override
  String get passwordHide => 'Hide password';

  @override
  String get regCreate => 'Create account';

  @override
  String get regCreating => 'Creating account …';

  @override
  String get regExtraTitle => 'One more quick step';

  @override
  String get regTermsBody => 'The provider asks you to accept its terms.';

  @override
  String get regTermsAgree => 'I have read and accept the terms.';

  @override
  String get regEmailBody =>
      'Enter your email address. The provider will send you a confirmation link. The address goes only to the provider, not to us.';

  @override
  String get regEmailLabel => 'Email address';

  @override
  String get regEmailInvalid => 'Please enter a valid email address.';

  @override
  String get regEmailSend => 'Send confirmation';

  @override
  String regEmailSent(String email) {
    return 'The provider sent an email to $email. Open it and tap the link. Then come back here.';
  }

  @override
  String get regEmailConfirmed => 'I have confirmed';

  @override
  String get regEmailResend => 'Send email again';

  @override
  String get regEmailNotYet =>
      'Not confirmed yet. Please open the link in the email (also check your spam folder).';

  @override
  String get regTokenBody =>
      'This provider only activates accounts with an access code. You get it from the provider (it is not the family’s invitation link).';

  @override
  String get regTokenLabel => 'Provider access code';

  @override
  String get regTokenWrong => 'The code does not match. Please check it.';

  @override
  String get regCaptchaBody =>
      'Please confirm briefly in the browser that you are not a robot. Afterwards you continue here automatically.';

  @override
  String get regCaptchaOpen => 'Open in browser';

  @override
  String get regCaptchaDone => 'I am done';

  @override
  String get regCaptchaNotYet =>
      'Not finished yet. Please complete the check in the browser.';

  @override
  String regOAuthIntro(String host) {
    return 'At $host you create your account on the provider’s page. Afterwards you return here automatically.';
  }

  @override
  String regOAuthCreate(String host) {
    return 'Create account at $host';
  }

  @override
  String regExternalBody(String host) {
    return 'The app cannot create an account at $host. Create it on the provider’s website and then sign in here.';
  }

  @override
  String get regExternalOpen => 'Open website';

  @override
  String get regExternalLogin => 'I have an account – sign in';

  @override
  String oauthWaiting(String host) {
    return 'Please continue in the browser at $host … Afterwards you continue here automatically.';
  }

  @override
  String loginOAuthIntro(String host) {
    return 'At $host you sign in on the provider’s page. Afterwards you return here automatically.';
  }

  @override
  String loginOAuth(String host) {
    return 'Sign in at $host';
  }

  @override
  String get loginNoAccount => 'No account yet? Create one';

  @override
  String get advTitle => 'Advanced';

  @override
  String advServerInfo(String host) {
    return 'Your account is hosted at $host.';
  }

  @override
  String advChecking(String host) {
    return 'Connecting to $host …';
  }

  @override
  String get advEnterProvider => 'Please enter the provider’s address.';

  @override
  String advUnreachable(String host) {
    return '$host cannot be reached right now. Check your internet connection.';
  }

  @override
  String get advExplain =>
      'FamilyNexus uses the open Matrix network. Your account is hosted by a provider of your choice – or on your own server.';

  @override
  String advStandardProvider(String host) {
    return '$host (recommended)';
  }

  @override
  String get advOtherProvider => 'Use another provider';

  @override
  String get advProviderLabel => 'Provider address';

  @override
  String get advProviderHint => 'e.g. matrix.example.org';

  @override
  String get keyTitle => 'Your emergency key';

  @override
  String get keyIntro =>
      'Your messages and events are encrypted. So that you can open them on a new phone too, you now get an emergency key – like a spare key for your front door.';

  @override
  String get keyCreate => 'Create emergency key';

  @override
  String get keyCreating => 'Creating …';

  @override
  String get keyShownIntro =>
      'If you lose your phone, you need this key to get your messages back. Nobody else – not even we – can restore it. It is shown only now.';

  @override
  String get keyCopy => 'Copy';

  @override
  String get keyCopied =>
      'Copied. Paste it e.g. into your password manager. The clipboard is cleared after one minute.';

  @override
  String get keySave => 'Save as file';

  @override
  String get keySavedFile => 'Saved. Keep the file safe – ideally printed.';

  @override
  String get keyPrintHint =>
      'Tip: save the file and print it – or copy the key onto paper.';

  @override
  String get keySavedCheck => 'I have stored the emergency key safely.';

  @override
  String get keyFileName => 'FamilyNexus-emergency-key.txt';

  @override
  String keyFileBody(String user, String provider, String key, String date) {
    return 'FamilyNexus – emergency key\n\nAccount: $user\nProvider: $provider\nCreated on: $date\n\nEmergency key:\n$key\n\nHow to use it: install FamilyNexus on the new device, choose “I already have an account”, sign in and enter the emergency key under “Unlock this device”.\n\nKeep this sheet safe and do not give it to anyone.';
  }

  @override
  String get keyRestoreTitle => 'Unlock this device';

  @override
  String get keyRestoreIntro =>
      'Your account is already protected. Unlock this device – with another device where you are signed in, or with your emergency key.';

  @override
  String keyVerifyWithDevice(String device) {
    return 'Confirm with “$device”';
  }

  @override
  String get keyNoOtherDevice =>
      'No other device found. Use your emergency key.';

  @override
  String get keyRestoreLabel => 'Emergency key';

  @override
  String get keyRestoreButton => 'Unlock';

  @override
  String get keyRestoring => 'Unlocking …';

  @override
  String get keyRestoreFailed =>
      'The emergency key does not match. Please check it again.';

  @override
  String get inviteStepTitle => 'Invitation';

  @override
  String get inviteStepBody =>
      'Paste the invitation link you received. Got a QR code? Scan it with the camera app – FamilyNexus then opens by itself.';

  @override
  String get inviteStepNoLink =>
      'No link? Ask the person inviting you to send you one.';

  @override
  String joinCardBody(String family, String inviter, String server) {
    return 'You are joining the family “$family”. You were invited by $inviter (account at $server).';
  }

  @override
  String joinCardBodyNoName(String inviter, String server) {
    return 'You are joining a family. You were invited by $inviter (account at $server).';
  }

  @override
  String joinCardNote(String inviter) {
    return 'Details according to the invitation. $inviter confirms your request, then you are in.';
  }

  @override
  String get joinCardDetails => 'Details';

  @override
  String get joinCardDetailsInviter => 'User ID of the inviting person';

  @override
  String get joinCardDetailsServer => 'Family server';

  @override
  String get joinDiscard => 'Discard';

  @override
  String get joinSending => 'Sending …';

  @override
  String joinWaiting(String inviter) {
    return 'Almost done! $inviter still needs to confirm you. Let them know – you can close the app in the meantime.';
  }

  @override
  String get joinAlreadyInFamily => 'You are already in a family.';

  @override
  String get familyNameHint => 'e.g. The Millers';

  @override
  String familyCreatedTitle(String name) {
    return 'Done! “$name” is set up.';
  }

  @override
  String get familyCreatedBody =>
      'Now invite your family – by QR code, email or link. You can also do this later under “Family”.';

  @override
  String get familyInviteNow => 'Invite now';

  @override
  String get later => 'Later';

  @override
  String get familySwitchToJoin => 'I was invited after all';

  @override
  String get familySwitchToCreate => 'Start a new family instead';

  @override
  String get familyInviteIntro =>
      'Invite family members. They get a link or QR code and send you a request that you confirm.';

  @override
  String get familyInviteSomeone => 'Invite someone';

  @override
  String get familyInviteScanHint =>
      'Let the person scan this code with their phone camera – or send them the link.';

  @override
  String familyRequestFrom(String name) {
    return '$name wants to join';
  }

  @override
  String get errUsernameTaken => 'This username is already taken.';

  @override
  String get errUsernameInvalid =>
      'This username is not allowed. Please choose another one.';

  @override
  String get errWeakPassword =>
      'The password is too weak. Please use a longer one.';

  @override
  String get errRegistrationDisabled =>
      'The app cannot create an account with this provider. Create it on their website.';

  @override
  String get errEmailInUse =>
      'This email address is already used by another account.';

  @override
  String get errOAuthCancelled =>
      'The sign-in in the browser was not completed. Please try again.';

  @override
  String joinCardServerMismatch(String family, String inviter) {
    return 'Caution: the family is hosted at $family, but the inviting person at $inviter. Only join if you really expected this invitation.';
  }

  @override
  String get weekdayLongMon => 'Monday';

  @override
  String get weekdayLongTue => 'Tuesday';

  @override
  String get weekdayLongWed => 'Wednesday';

  @override
  String get weekdayLongThu => 'Thursday';

  @override
  String get weekdayLongFri => 'Friday';

  @override
  String get weekdayLongSat => 'Saturday';

  @override
  String get weekdayLongSun => 'Sunday';

  @override
  String get tasksBadgeWeekdays => 'Mon–Fri';

  @override
  String get tasksFieldDescription => 'Description (optional)';

  @override
  String get tasksDescriptionHint => 'e.g. what exactly needs to be done';

  @override
  String get tasksRepeatMonthlyWeekday => 'Monthly by weekday';

  @override
  String get tasksRepeatMonthlyDate => 'Monthly by date';

  @override
  String get tasksDailyAllDays => 'Every day (including Saturday and Sunday)';

  @override
  String get tasksDailyWeekdays => 'Monday to Friday (no weekend)';

  @override
  String get tasksFieldWeekday => 'Weekday';

  @override
  String get tasksFieldOrdinal => 'Which';

  @override
  String get tasksFieldDay => 'Day of the month';

  @override
  String get tasksOrdinal1 => 'First';

  @override
  String get tasksOrdinal2 => 'Second';

  @override
  String get tasksOrdinal3 => 'Third';

  @override
  String get tasksOrdinal4 => 'Fourth';

  @override
  String get tasksOrdinalLast => 'Last';

  @override
  String get tasksOrdinalInText1 => 'first';

  @override
  String get tasksOrdinalInText2 => 'second';

  @override
  String get tasksOrdinalInText3 => 'third';

  @override
  String get tasksOrdinalInText4 => 'fourth';

  @override
  String get tasksOrdinalInTextLast => 'last';

  @override
  String get tasksRuleWeekdays => 'Monday to Friday';

  @override
  String tasksRuleWeekly(String weekday) {
    return 'Weekly on $weekday';
  }

  @override
  String tasksRuleMonthlyWeekday(String ordinal, String weekday) {
    return 'Monthly on the $ordinal $weekday';
  }

  @override
  String tasksRuleMonthlyDate(int day) {
    return 'Monthly on day $day';
  }

  @override
  String get tasksResetWeekdays =>
      'Restarts Monday to Friday, not at the weekend';

  @override
  String tasksResetWeeklyOn(String weekday) {
    return 'Restarts every $weekday';
  }

  @override
  String tasksResetMonthlyWeekday(String ordinal, String weekday) {
    return 'Restarts every month on the $ordinal $weekday';
  }

  @override
  String tasksResetMonthlyDate(int day) {
    return 'Restarts every month on day $day';
  }

  @override
  String tasksResetMonthlyDateShort(int day) {
    return 'Restarts every month on day $day – in months without that day on the last day of the month';
  }

  @override
  String tasksNextReset(String date) {
    return 'Next restart: $date';
  }

  @override
  String get tasksDescriptionTooLong =>
      'The description is too long. Please shorten it a little.';

  @override
  String get joinLinkNotALink =>
      'This is not an invitation link. An invitation link starts with “familynexus://join”.';

  @override
  String get joinLinkDamaged =>
      'The link is incomplete or damaged – this often happens when forwarding it. Please copy it again completely or scan the QR code.';

  @override
  String get joinLinkExpired =>
      'This invitation link has expired. Please ask the person inviting you for a new link.';

  @override
  String get joinLinkNewerVersion =>
      'This link comes from a newer version of FamilyNexus. Please update the app and try again.';

  @override
  String joinCardLocalServer(String server) {
    return 'Caution: this family is hosted on a server in a home network ($server). It can only be reached when your device is on the same network (e.g. the family’s Wi-Fi). Only continue if you expected this invitation.';
  }

  @override
  String inviteValidityDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get familyInviteValidityLabel => 'Valid for';

  @override
  String inviteValidityInSentence(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: 'one day',
    );
    return '$_temp0';
  }

  @override
  String joinCardLocalOtherAccount(String family, String own) {
    return 'This family is hosted on a server in a home network ($family). With your account at $own you cannot join it. Create an account at $family instead (sign out and choose “I was invited”).';
  }

  @override
  String advLocalConsent(String host) {
    return 'The invitation points to a server in a home network ($host). Only connect if you expected the invitation and are on the same network (e.g. the family’s Wi-Fi).';
  }

  @override
  String advLocalConnect(String host) {
    return 'Connect to $host';
  }
}
