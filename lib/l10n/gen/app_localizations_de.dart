// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appName => 'FamilyNexus';

  @override
  String get tabToday => 'Heute';

  @override
  String get tabCalendar => 'Kalender';

  @override
  String get tabChat => 'Chat';

  @override
  String get tabFamily => 'Familie';

  @override
  String get tabSettings => 'Einstellungen';

  @override
  String get emptyToday =>
      'Noch keine Termine. Sobald Termine anstehen, erscheinen sie hier.';

  @override
  String get emptyCalendar => 'Der Kalender ist noch leer.';

  @override
  String get emptyChat => 'Noch keine Nachrichten.';

  @override
  String get emptyFamily => 'Es ist noch keine Familie eingerichtet.';

  @override
  String get settingsSectionDisplay => 'Darstellung';

  @override
  String get settingsSectionPrivacy => 'Datenschutz';

  @override
  String get settingsSectionAbout => 'Über die App';

  @override
  String get settingsLanguage => 'Sprache';

  @override
  String get languageSystem => 'Gerätesprache';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get languageEnglish => 'English';

  @override
  String get settingsTheme => 'Design';

  @override
  String get themeSystem => 'Wie Gerät';

  @override
  String get themeDark => 'Dunkel';

  @override
  String get themeLight => 'Hell';

  @override
  String get settingsReduceEffects => 'Effekte reduzieren';

  @override
  String get settingsReduceEffectsHint =>
      'Weniger Unschärfe und Leuchten, deckendere Flächen.';

  @override
  String get settingsSecureScreen => 'Bildschirmschutz';

  @override
  String get settingsSecureScreenHint =>
      'Blockiert Screenshots und verbirgt die App in der Übersicht.';

  @override
  String get settingsLicense => 'Lizenz: AGPL-3.0-or-later';

  @override
  String get settingsNoTelemetry =>
      'Keine Telemetrie, keine Werbung, keine Analyse.';

  @override
  String get loading => 'Lädt …';

  @override
  String get errorGeneric => 'Etwas ist schiefgelaufen.';

  @override
  String get retry => 'Erneut versuchen';

  @override
  String get startupFailedTitle => 'Lokale Daten nicht lesbar';

  @override
  String get startupFailedBody =>
      'Die verschlüsselte Datenbank konnte nicht geöffnet werden, zum Beispiel weil der Schlüssel des Geräts nicht mehr verfügbar ist. Aus Sicherheitsgründen wurde nichts verändert. Du kannst die lokalen Daten zurücksetzen und neu einrichten; Daten auf dem Server und anderen Geräten bleiben erhalten.';

  @override
  String get startupRetry => 'Erneut versuchen';

  @override
  String get startupReset => 'Lokale Daten zurücksetzen';

  @override
  String get startupResetConfirmTitle => 'Lokale Daten wirklich löschen?';

  @override
  String get startupResetConfirmBody =>
      'Alle Daten dieser App auf diesem Gerät werden unwiderruflich gelöscht.';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get delete => 'Löschen';

  @override
  String get next => 'Weiter';

  @override
  String get back => 'Zurück';

  @override
  String get done => 'Fertig';

  @override
  String get save => 'Speichern';

  @override
  String get close => 'Schließen';

  @override
  String onbStep(int current, int total) {
    return 'Schritt $current von $total';
  }

  @override
  String get onbTitleLanguage => 'Willkommen bei FamilyNexus';

  @override
  String get onbIntro =>
      'Familienkalender und Messenger in einer App. Deine Daten bleiben auf deinen Geräten und wandern nur Ende-zu-Ende-verschlüsselt über Matrix.';

  @override
  String get onbPoint1 => 'Keine Telemetrie, keine Werbung, keine Analyse.';

  @override
  String get onbPoint2 =>
      'Chat und geteilte Termine sind Ende-zu-Ende-verschlüsselt.';

  @override
  String get onbPoint3 => 'Private Termine verlassen nie deine eigenen Geräte.';

  @override
  String get onbTitleServer => 'Server wählen';

  @override
  String serverDefault(String host) {
    return 'Standardserver ($host)';
  }

  @override
  String get serverCustom => 'Eigener Server';

  @override
  String get serverUrlLabel => 'Server-Adresse (https)';

  @override
  String get serverUrlInvalid => 'Bitte eine gültige https-Adresse eingeben.';

  @override
  String get serverCheck => 'Server prüfen';

  @override
  String get serverChecking => 'Prüfe …';

  @override
  String serverOk(String version) {
    return 'Server erreichbar (Matrix $version)';
  }

  @override
  String serverOperator(String name) {
    return 'Betreiber: $name';
  }

  @override
  String get serverNoPassword =>
      'Dieser Server erlaubt keine Anmeldung mit Passwort.';

  @override
  String get serverMetadataNote =>
      'Der Server sieht keine Inhalte, aber Metadaten wie wer wann mit wem schreibt. Wer das vermeiden möchte, nutzt einen eigenen Server.';

  @override
  String get onbTitleAccount => 'Anmelden';

  @override
  String get accountUsername => 'Benutzername';

  @override
  String get accountPassword => 'Passwort';

  @override
  String get accountLogin => 'Anmelden';

  @override
  String get accountLoggingIn => 'Melde an …';

  @override
  String get accountHint =>
      'Du brauchst ein bestehendes Matrix-Konto auf dem gewählten Server. Neue Konten legst du beim Betreiber an.';

  @override
  String get onbTitleFamily => 'Familie';

  @override
  String get familyName => 'Name der Familie';

  @override
  String get familyCreate => 'Familie gründen';

  @override
  String get familyCreating => 'Lege an …';

  @override
  String get familyCreateHint =>
      'Du wirst Moderator. Lade später einen zweiten Moderator ein, damit die Familie bei Geräteverlust handlungsfähig bleibt.';

  @override
  String get familyMinorsNote =>
      'Kinder können Mitglied werden. Bitte hole dafür die Einwilligung der Sorgeberechtigten ein.';

  @override
  String get familyRoleModerator => 'Moderator';

  @override
  String get familyRoleMember => 'Mitglied';

  @override
  String get familyMembers => 'Mitglieder';

  @override
  String get familySecondModerator =>
      'Empfehlung: Ernenne einen zweiten Moderator.';

  @override
  String get statusInvited => 'Eingeladen';

  @override
  String get statusRequested => 'Anfrage';

  @override
  String get errInvalidCredentials =>
      'Benutzername oder Passwort stimmen nicht.';

  @override
  String get errServerUnreachable =>
      'Server nicht erreichbar. Prüfe die Verbindung.';

  @override
  String get errServerUnsupported => 'Dieser Server wird nicht unterstützt.';

  @override
  String get errNotAllowed => 'Dafür fehlt die Berechtigung.';

  @override
  String get errAttachmentRejected =>
      'Dieser Anhang ist nicht erlaubt (Typ oder Größe).';

  @override
  String get errInvalidInput => 'Bitte Eingabe prüfen.';

  @override
  String get errNotFound => 'Nicht gefunden.';

  @override
  String get errEncryption =>
      'Verschlüsselung nicht verfügbar. Es wird nichts gesendet.';

  @override
  String get errUnknown => 'Unbekannter Fehler.';

  @override
  String get chatHint => 'Nachricht schreiben';

  @override
  String get chatSend => 'Senden';

  @override
  String get chatAttach => 'Datei anhängen';

  @override
  String get chatReply => 'Antworten';

  @override
  String chatReplyingTo(String name) {
    return 'Antwort an $name';
  }

  @override
  String get chatCancelReply => 'Antwort abbrechen';

  @override
  String get chatReact => 'Reagieren';

  @override
  String get chatRetry => 'Senden fehlgeschlagen – tippen zum Wiederholen';

  @override
  String get chatSending => 'Wird gesendet …';

  @override
  String get chatEncryptedNote => 'Ende-zu-Ende-verschlüsselt';

  @override
  String get chatAttachmentBlocked =>
      'Anhang blockiert (Typ oder Größe nicht erlaubt)';

  @override
  String get chatLoadAttachment => 'Anhang laden';

  @override
  String get chatSaveAttachment => 'Speichern';

  @override
  String chatMessageFrom(String name) {
    return 'Nachricht von $name';
  }

  @override
  String get chatYou => 'Du';

  @override
  String get logout => 'Abmelden';

  @override
  String get settingsAccount => 'Konto';

  @override
  String get settingsServer => 'Server';

  @override
  String get serverContactUnknown => 'Kontakt: nicht angegeben';

  @override
  String serverContact(String contact) {
    return 'Kontakt: $contact';
  }

  @override
  String get errAlreadyExists =>
      'Es gibt bereits eine Familie für dieses Konto.';

  @override
  String get errRateLimited =>
      'Zu viele Anfragen. Bitte später erneut versuchen.';

  @override
  String get chatUndecryptable => 'Nachricht kann nicht entschlüsselt werden';

  @override
  String get syncing => 'Synchronisiere …';

  @override
  String get reminderTitle => 'Erinnerung';

  @override
  String reminderBody(String duration) {
    return 'Termin in $duration';
  }

  @override
  String get reminderChannelName => 'Erinnerungen';

  @override
  String get reminderChannelDescription =>
      'Erinnerungen an Termine. Sie zeigen keine Inhalte an.';

  @override
  String get durationNow => '0 Minuten';

  @override
  String durationMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Minuten',
      one: '1 Minute',
    );
    return '$_temp0';
  }

  @override
  String durationHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Stunden',
      one: '1 Stunde',
    );
    return '$_temp0';
  }

  @override
  String durationDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tage',
      one: '1 Tag',
    );
    return '$_temp0';
  }

  @override
  String reminderBefore(String duration) {
    return '$duration vorher';
  }

  @override
  String get reminderAtStart => 'Zur Startzeit';

  @override
  String get remindersTitle => 'Erinnerungen';

  @override
  String get remindersHint =>
      'Erinnerungen sind lokale Benachrichtigungen dieses Geräts. Sie zeigen nie Titel oder Ort.';

  @override
  String get remindersPermissionNotifications =>
      'Benachrichtigungen sind blockiert. Ohne sie erscheinen keine Erinnerungen.';

  @override
  String get remindersPermissionExact =>
      'Genaue Alarme sind nicht erlaubt. Erinnerungen können sich verspäten.';

  @override
  String get remindersAllow => 'Erlauben';

  @override
  String remindersPlanned(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Erinnerungen geplant',
      one: '1 Erinnerung geplant',
      zero: 'Keine Erinnerung geplant',
    );
    return '$_temp0';
  }

  @override
  String get remindersDefault => 'Standard-Erinnerung';

  @override
  String get remindersNone => 'Keine';

  @override
  String get viewDay => 'Tag';

  @override
  String get viewWeek => 'Woche';

  @override
  String get viewMonth => 'Monat';

  @override
  String get viewAgenda => 'Agenda';

  @override
  String get calendarToday => 'Heute';

  @override
  String get calendarPrevious => 'Zurück';

  @override
  String get calendarNext => 'Weiter';

  @override
  String get calendarAll => 'Alle';

  @override
  String get calendarFilterPerson => 'Nach Person filtern';

  @override
  String get calendarNoEvents => 'Keine Termine';

  @override
  String get calendarAllDay => 'Ganztägig';

  @override
  String get calendarNewEvent => 'Neuer Termin';

  @override
  String calendarEventsOnDay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Termine',
      one: '1 Termin',
      zero: 'Keine Termine',
    );
    return '$_temp0';
  }

  @override
  String get todayNext => 'Nächste Termine';

  @override
  String get todayUnread => 'Ungelesene Nachrichten';

  @override
  String todayUnreadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ungelesene Nachrichten',
      one: '1 ungelesene Nachricht',
      zero: 'Keine ungelesenen Nachrichten',
    );
    return '$_temp0';
  }

  @override
  String get todayNoUpcoming =>
      'In den nächsten 30 Tagen stehen keine Termine an.';

  @override
  String get todayOpenChat => 'Chat öffnen';

  @override
  String get visibilityPrivate => 'Privat';

  @override
  String get visibilityShared => 'Geteilt';

  @override
  String get visibilityPrivateHint =>
      'Nur auf deinen eigenen Geräten. Wird nie an die Familie gesendet.';

  @override
  String get visibilitySharedHint =>
      'Verschlüsselt an die Familie gesendet. Mitglieder sehen den Termin und können zu- oder absagen.';

  @override
  String get visibilityChangeNote =>
      'Bereits an die Familie gesendete Inhalte bleiben auf deren Geräten, auch wenn du den Termin später privat machst.';

  @override
  String get eventNew => 'Neuer Termin';

  @override
  String get eventEdit => 'Termin bearbeiten';

  @override
  String get eventTitle => 'Titel';

  @override
  String get eventTitleRequired => 'Bitte einen Titel eingeben.';

  @override
  String get eventAllDay => 'Ganztägig';

  @override
  String get eventStart => 'Beginn';

  @override
  String get eventEnd => 'Ende';

  @override
  String get eventEndBeforeStart => 'Das Ende liegt vor dem Beginn.';

  @override
  String get eventLocation => 'Ort';

  @override
  String get eventNote => 'Notiz';

  @override
  String get eventColor => 'Farbe';

  @override
  String eventColorName(int number) {
    return 'Farbe $number';
  }

  @override
  String get eventAttendees => 'Teilnehmer';

  @override
  String get eventVisibility => 'Sichtbarkeit';

  @override
  String eventTimeZone(String zone) {
    return 'Zeitzone: $zone';
  }

  @override
  String get eventSaveError => 'Der Termin konnte nicht gespeichert werden.';

  @override
  String get eventRepeat => 'Wiederholung';

  @override
  String get repeatNone => 'Keine';

  @override
  String get repeatDaily => 'Täglich';

  @override
  String get repeatWeekly => 'Wöchentlich';

  @override
  String get repeatMonthly => 'Monatlich';

  @override
  String get repeatYearly => 'Jährlich';

  @override
  String get repeatEvery => 'Alle';

  @override
  String get repeatUnitDays => 'Tage';

  @override
  String get repeatUnitWeeks => 'Wochen';

  @override
  String get repeatUnitMonths => 'Monate';

  @override
  String get repeatUnitYears => 'Jahre';

  @override
  String get repeatEnds => 'Endet';

  @override
  String get repeatEndsNever => 'Nie';

  @override
  String get repeatEndsOn => 'Am Datum';

  @override
  String get repeatEndsAfter => 'Nach Anzahl';

  @override
  String get repeatCount => 'Anzahl';

  @override
  String get repeatUntil => 'Letzter Tag';

  @override
  String repeatSummaryDaily(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Alle $count Tage',
      one: 'Täglich',
    );
    return '$_temp0';
  }

  @override
  String repeatSummaryWeekly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Alle $count Wochen',
      one: 'Wöchentlich',
    );
    return '$_temp0';
  }

  @override
  String repeatSummaryMonthly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Alle $count Monate',
      one: 'Monatlich',
    );
    return '$_temp0';
  }

  @override
  String repeatSummaryYearly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Alle $count Jahre',
      one: 'Jährlich',
    );
    return '$_temp0';
  }

  @override
  String get weekdayMon => 'Mo';

  @override
  String get weekdayTue => 'Di';

  @override
  String get weekdayWed => 'Mi';

  @override
  String get weekdayThu => 'Do';

  @override
  String get weekdayFri => 'Fr';

  @override
  String get weekdaySat => 'Sa';

  @override
  String get weekdaySun => 'So';

  @override
  String get eventDelete => 'Termin löschen';

  @override
  String get eventDeleteConfirm => 'Diesen Termin wirklich löschen?';

  @override
  String get eventDeleteSeriesConfirm =>
      'Alle Vorkommen oder nur dieses löschen?';

  @override
  String get eventDeleteThis => 'Nur dieses';

  @override
  String get eventDeleteAll => 'Alle';

  @override
  String get eventShareInChat => 'Im Chat teilen';

  @override
  String get eventShared => 'Im Chat geteilt';

  @override
  String eventOwner(String name) {
    return 'Von $name';
  }

  @override
  String get eventOwnerYou => 'Von dir';

  @override
  String get eventRsvp => 'Antwort';

  @override
  String get rsvpAccept => 'Zusagen';

  @override
  String get rsvpDecline => 'Absagen';

  @override
  String get rsvpMaybe => 'Vielleicht';

  @override
  String get rsvpAccepted => 'Zugesagt';

  @override
  String get rsvpDeclined => 'Abgesagt';

  @override
  String get rsvpMaybeStatus => 'Vielleicht';

  @override
  String get rsvpNone => 'Keine Antwort';

  @override
  String get eventHistory => 'Verlauf';

  @override
  String eventVersion(int version) {
    return 'Version $version';
  }

  @override
  String get eventRecurring => 'Wiederholt';

  @override
  String get eventCancelled => 'Gelöscht';

  @override
  String get eventReadOnly => 'Nur der Ersteller kann diesen Termin ändern.';

  @override
  String get eventYourReminders => 'Deine Erinnerungen';

  @override
  String get eventResetReminders => 'Standard verwenden';

  @override
  String get chatEventCard => 'Termin';

  @override
  String get chatEventMissing => 'Termin nicht verfügbar';

  @override
  String get settingsReminders => 'Erinnerungen';

  @override
  String get repeatUntilInvalid =>
      'Das letzte Datum der Wiederholung liegt vor dem ersten Termin.';

  @override
  String get errReauth => 'Bitte bestätige dein Passwort.';

  @override
  String get securityTitle => 'Schlüsselsicherung';

  @override
  String get securityIntro =>
      'Damit nur deine eigenen Geräte deine verschlüsselten Nachrichten und Termine lesen können, richtest du jetzt eine Schlüsselsicherung ein.';

  @override
  String get securitySetupButton => 'Schlüsselsicherung einrichten';

  @override
  String get securitySettingUp => 'Richte ein …';

  @override
  String get securityKeyTitle => 'Dein Wiederherstellungsschlüssel';

  @override
  String get securityKeyHint =>
      'Notiere ihn auf Papier und bewahre ihn sicher auf. Er wird nur jetzt angezeigt. Ohne ihn und ohne ein verifiziertes Gerät sind deine Nachrichten bei Verlust aller Geräte unwiederbringlich.';

  @override
  String get securityKeySaved => 'Ich habe den Schlüssel sicher notiert.';

  @override
  String get securityRestoreTitle => 'Dieses Gerät verifizieren';

  @override
  String get securityRestoreIntro =>
      'Dein Konto ist bereits abgesichert. Verifiziere dieses Gerät mit einem anderen deiner Geräte oder mit deinem Wiederherstellungsschlüssel.';

  @override
  String get securityVerifyWithDevice => 'Mit einem anderen Gerät verifizieren';

  @override
  String get securityNoOtherDevice =>
      'Kein anderes Gerät gefunden. Nutze den Wiederherstellungsschlüssel.';

  @override
  String get securityRestoreKeyLabel => 'Wiederherstellungsschlüssel';

  @override
  String get securityRestoreButton => 'Mit Schlüssel wiederherstellen';

  @override
  String get securityRestoring => 'Stelle wieder her …';

  @override
  String get securityRestoreFailed => 'Der Schlüssel passt nicht.';

  @override
  String get securityPasswordTitle => 'Passwort bestätigen';

  @override
  String get securityPasswordHint =>
      'Der Server verlangt dein Passwort zur Bestätigung. Es wird nicht gespeichert.';

  @override
  String get securityStatusReady => 'Dieses Gerät ist verifiziert.';

  @override
  String get securityStatusNeeds => 'Dieses Gerät ist noch nicht verifiziert.';

  @override
  String get securityDevices => 'Geräte deines Kontos';

  @override
  String get securityDeviceThis => 'Dieses Gerät';

  @override
  String get securityDeviceVerified => 'Verifiziert';

  @override
  String get securityDeviceUnverified => 'Nicht verifiziert';

  @override
  String get securityVerifyDevice => 'Verifizieren';

  @override
  String get securityVerifyPerson => 'Verifizieren';

  @override
  String get verifyTitle => 'Verifizierung';

  @override
  String verifyIncoming(String peer) {
    return '$peer möchte die Verifizierung starten.';
  }

  @override
  String get verifyWaiting => 'Warte auf die Gegenseite …';

  @override
  String get verifyCompare =>
      'Vergleiche diese Symbole mit denen auf dem anderen Gerät. Sie müssen in gleicher Reihenfolge übereinstimmen.';

  @override
  String get verifyMatch => 'Sie stimmen überein';

  @override
  String get verifyNoMatch => 'Sie stimmen nicht überein';

  @override
  String get verifyWaitingConfirm => 'Warte auf Bestätigung der Gegenseite …';

  @override
  String get verifyDone => 'Verifiziert.';

  @override
  String get verifyCancelled => 'Die Verifizierung wurde abgebrochen.';

  @override
  String get accept => 'Annehmen';

  @override
  String get decline => 'Ablehnen';

  @override
  String get familyManage => 'Verwaltung';

  @override
  String get familyInvite => 'Mitglied einladen';

  @override
  String get familyInviteLinkTitle => 'Einladungslink';

  @override
  String get familyInviteLinkHint =>
      'Gültig 24 Stunden. Wer den Link öffnet, stellt nur eine Anfrage – du bestätigst sie.';

  @override
  String get familyInviteShowQr => 'QR-Code anzeigen';

  @override
  String get familyInviteCopyLink => 'Link kopieren';

  @override
  String get familyInviteCopied => 'Link kopiert.';

  @override
  String get familyInviteById => 'Matrix-ID einladen';

  @override
  String get familyInviteByIdHint => '@name:server';

  @override
  String get familyInviteSend => 'Einladen';

  @override
  String get familyInviteInvalidId => 'Bitte eine gültige Matrix-ID eingeben.';

  @override
  String get familyInviteSent => 'Einladung gesendet.';

  @override
  String get familyRequests => 'Beitrittsanfragen';

  @override
  String get familyRequestApprove => 'Bestätigen';

  @override
  String get familyRequestReject => 'Ablehnen';

  @override
  String get familyMemberPromote => 'Zum Moderator ernennen';

  @override
  String get familyMemberRemove => 'Entfernen';

  @override
  String familyMemberRemoveConfirm(String name) {
    return '$name wirklich aus der Familie entfernen? Die Raumschlüssel werden erneuert; neue Inhalte kann $name nicht mehr lesen.';
  }

  @override
  String familyMemberPromoteConfirm(String name) {
    return '$name zum Moderator ernennen? Moderatoren können einladen, ernennen und entfernen.';
  }

  @override
  String get familyRename => 'Familienname ändern';

  @override
  String get familyRenamed => 'Name geändert.';

  @override
  String get familyDone => 'Erledigt.';

  @override
  String get familyOnlyModerators => 'Nur Moderatoren verwalten die Familie.';

  @override
  String get joinTitle => 'Familie beitreten';

  @override
  String get joinHint =>
      'Füge einen Einladungslink ein oder öffne den Link bzw. QR-Code mit der Kamera-App.';

  @override
  String get joinLinkLabel => 'Einladungslink';

  @override
  String get joinLinkInvalid => 'Dieser Link ist ungültig oder abgelaufen.';

  @override
  String get joinSend => 'Beitrittsanfrage senden';

  @override
  String get joinConfirmTitle => 'Beitritt anfragen?';

  @override
  String joinConfirmBody(String server, String inviter) {
    return 'Du fragst an, der Familie auf dem Server $server beizutreten. Eingeladen hat $inviter. Ein Moderator muss bestätigen.';
  }

  @override
  String get joinPending =>
      'Anfrage gesendet. Warte auf die Bestätigung eines Moderators.';

  @override
  String get joinCancel => 'Anfrage zurückziehen';

  @override
  String get invitationsTitle => 'Einladungen';

  @override
  String invitationFrom(String inviter) {
    return 'Einladung von $inviter';
  }

  @override
  String get onbCreateOrJoin =>
      'Gründe eine neue Familie oder tritt einer bestehenden bei.';

  @override
  String get onbCreateTab => 'Gründen';

  @override
  String get onbJoinTab => 'Beitreten';

  @override
  String get onbChangeAccount => 'Abmelden';

  @override
  String get lockTitle => 'FamilyNexus ist gesperrt';

  @override
  String get lockHint =>
      'Bestätige mit der Geräteanmeldung (PIN, Muster, Passwort oder Biometrie).';

  @override
  String get lockUnlock => 'Entsperren';

  @override
  String get lockReason => 'FamilyNexus entsperren';

  @override
  String get settingsLock => 'App-Sperre';

  @override
  String get settingsLockHint =>
      'Sperrt die App nach Inaktivität. Die Bestätigung erfolgt mit der Sperre deines Geräts; die App speichert keine eigene PIN.';

  @override
  String get settingsLockUnavailable =>
      'Auf diesem Gerät ist keine gesicherte Bildschirmsperre eingerichtet.';

  @override
  String get settingsLockFailed => 'Die Bestätigung war nicht erfolgreich.';

  @override
  String get settingsLockTimeout => 'Sperren nach';

  @override
  String get lockImmediately => 'Sofort';

  @override
  String get lock1min => '1 Minute';

  @override
  String get lock5min => '5 Minuten';

  @override
  String get lock15min => '15 Minuten';

  @override
  String get settingsPrivacyPolicy => 'Datenschutzerklärung';

  @override
  String get settingsDeleteData => 'Alle lokalen Daten löschen';

  @override
  String get settingsDeleteDataHint =>
      'Meldet dich ab und löscht Datenbank, Schlüssel und Erinnerungen auf diesem Gerät.';

  @override
  String get deleteDataTitle => 'Alle lokalen Daten löschen?';

  @override
  String get deleteDataBody =>
      'Alle Daten dieser App auf diesem Gerät werden unwiderruflich gelöscht und du wirst abgemeldet. Nachrichten und geteilte Termine auf Geräten anderer Familienmitglieder lassen sich technisch nicht löschen. Dein Konto beim Server bleibt bestehen; zum Löschen wende dich an dessen Betreiber.';

  @override
  String get deleteDataConfirm => 'Endgültig löschen';

  @override
  String get privacyTitle => 'Datenschutzerklärung';

  @override
  String get privacy1Title => 'Wer verarbeitet deine Daten?';

  @override
  String get privacy1Body =>
      'FamilyNexus ist freie Software (AGPL-3.0). Die App sendet keine Daten an die Entwickler und enthält keine Telemetrie, Werbung oder Analyse. Verantwortlich für die Verarbeitung auf dem Server ist der Betreiber des von dir gewählten Matrix-Servers; er wird bei der Einrichtung angezeigt.';

  @override
  String get privacy2Title => 'Welche Daten gibt es?';

  @override
  String get privacy2Body =>
      'Chatnachrichten, Dateien, geteilte und private Termine, Zusagen, Einkaufszettel, Familienmitglieder und deine Einstellungen. Termine und Nachrichten liegen verschlüsselt (SQLCipher) auf deinem Gerät. Der Schlüssel dafür liegt im Android-Schlüsselspeicher und nie in einer Datei.';

  @override
  String get privacy3Title => 'Was sieht der Server?';

  @override
  String get privacy3Body =>
      'Nachrichten, Dateien und geteilte Termine werden Ende-zu-Ende-verschlüsselt (Matrix, Olm/Megolm). Der Server sieht nur verschlüsselte Ereignisse. Metadaten wie Konto-ID, Zeitpunkte, Raumgröße und Geräte bleiben für den Betreiber sichtbar. Wer das vermeiden möchte, nutzt einen eigenen Server.';

  @override
  String get privacy4Title => 'Private Termine';

  @override
  String get privacy4Body =>
      'Private Termine werden nie an die Familie gesendet. Zwischen deinen eigenen Geräten werden sie über einen privaten, verschlüsselten Raum abgeglichen, dem nur dein Konto angehört.';

  @override
  String get privacy5Title => 'Erinnerungen und Benachrichtigungen';

  @override
  String get privacy5Body =>
      'Erinnerungen sind lokale Benachrichtigungen. Sie zeigen nie Titel, Ort oder Notiz, nur „Termin in …“. Es gibt keinen Push-Dienst eines Dritten.';

  @override
  String get privacy6Title => 'Berechtigungen';

  @override
  String get privacy6Body =>
      'Internet (Verbindung zum Server), Benachrichtigungen und genaue Alarme (Erinnerungen), Neustart-Meldung (Erinnerungen neu planen) und Geräteanmeldung (App-Sperre). Es werden keine Kontakte, kein Standort, keine Kamera und kein Mikrofon benötigt.';

  @override
  String get privacy7Title => 'Sicherung und Löschung';

  @override
  String get privacy7Body =>
      'Android-Backups sind ausgeschaltet. Speicherst du einen Anhang bewusst über „Speichern“, liegt die entschlüsselte Datei außerhalb der App in dem von dir gewählten Ordner. Mit „Alle lokalen Daten löschen“ entfernst du alle Daten, Schlüssel und Erinnerungen von diesem Gerät. Nachrichten auf Geräten anderer Mitglieder lassen sich technisch nicht erzwungen löschen. Dein Wiederherstellungsschlüssel ist das einzige Mittel, Nachrichten nach Verlust aller Geräte zu retten – bewahre ihn sicher auf.';

  @override
  String get privacy8Title => 'Kinder';

  @override
  String get privacy8Body =>
      'Kinder können Familienmitglieder sein. Dafür ist die Einwilligung der Sorgeberechtigten nötig; Konten Minderjähriger laufen über die Einladung und Bestätigung eines Moderators.';

  @override
  String get privacy9Title => 'Deine Rechte';

  @override
  String get privacy9Body =>
      'Du kannst jederzeit Auskunft, Berichtigung und Löschung verlangen. Lokale Daten verwaltest du in dieser App; Serverdaten beim Betreiber deines Servers.';

  @override
  String get familyRequestCheckValid => 'Gültiger Einladungslink';

  @override
  String get familyRequestCheckExpired => 'Link abgelaufen';

  @override
  String get familyRequestCheckUnknown =>
      'Unbekannter Link – von keinem Moderator ausgegeben';

  @override
  String familyRequestApproveConfirm(String user) {
    return '$user in die Familie aufnehmen? Der Einladungslink wird dabei verbraucht.';
  }

  @override
  String get identityVerified => 'Verifiziert';

  @override
  String get identityPinned => 'Nicht persönlich geprüft';

  @override
  String get identityUnknown => 'Keine Schlüssel bekannt';

  @override
  String get identityChanged => 'Identität geändert';

  @override
  String identityChangedWarning(String name) {
    return 'Der Sicherheitsschlüssel von $name hat sich geändert. Seine Geräte sind gesperrt, bis ihr euch persönlich per Emoji-Vergleich geprüft habt.';
  }

  @override
  String get identityAccept => 'Änderung akzeptieren';

  @override
  String get identityAcceptConfirm =>
      'Erst akzeptieren, wenn ihr euch persönlich (z. B. per Emoji-Vergleich) geprüft habt. Fortfahren?';

  @override
  String invitationUnexpectedWarning(String inviter) {
    return 'Diese Einladung gehört zu keiner Beitrittsanfrage von dir. Nimm sie nur an, wenn du $inviter kennst und die Einladung erwartet hast.';
  }

  @override
  String memberActionsTooltip(String name) {
    return 'Aktionen für $name';
  }

  @override
  String familyInviteConfirm(String user) {
    return '$user einladen? Eingeladene erhalten bereits vor der Annahme die Nachrichtenschlüssel der Familie – lade nur Personen ein, die du sicher kennst.';
  }

  @override
  String get attachmentSaveWarning =>
      'Die Datei wird entschlüsselt und unverschlüsselt im gewählten Ordner gespeichert. Sie bleibt dort auch nach dem Abmelden oder Löschen der App-Daten erhalten. Fortfahren?';

  @override
  String get tabShopping => 'Einkauf';

  @override
  String get settingsShareOnlineStatus => 'Online-Status teilen';

  @override
  String get settingsShareOnlineStatusHint =>
      'Zeigt der Familie, wann du die App nutzt. Die Meldung geht nur Ende-zu-Ende-verschlüsselt an Geräte von Familienmitgliedern. Ausgeschaltet giltst du für andere als offline.';

  @override
  String get presenceOnline => 'Online';

  @override
  String get presenceOffline => 'Offline';

  @override
  String get presenceUnknown => 'Status unbekannt';

  @override
  String presenceLastSeen(String ago) {
    return 'Zuletzt online $ago';
  }

  @override
  String get presenceAgoNow => 'gerade eben';

  @override
  String presenceAgoMinutes(int count) {
    return 'vor $count Min.';
  }

  @override
  String presenceAgoHours(int count) {
    return 'vor $count Std.';
  }

  @override
  String presenceAgoDays(int count) {
    return 'vor $count Tg.';
  }

  @override
  String get presenceSelfHidden => 'Dein Status wird nicht geteilt';

  @override
  String get presenceSelf => 'Du bist online';

  @override
  String presenceOf(String name, String status) {
    return '$name: $status';
  }

  @override
  String get chatThreads => 'Gespräche';

  @override
  String chatThreadFamily(String name) {
    return 'Familienchat $name';
  }

  @override
  String chatThreadDirect(String name) {
    return 'Einzelchat mit $name';
  }

  @override
  String chatUnreadCount(int count) {
    return '$count ungelesen';
  }

  @override
  String chatDirectNote(String name) {
    return 'Nur zwischen dir und $name, Ende-zu-Ende-verschlüsselt';
  }

  @override
  String get chatDirectNotAvailable =>
      'Dieses Gespräch ist nicht mehr verfügbar.';

  @override
  String get familyWriteMessage => 'Nachricht schreiben';

  @override
  String get shoppingTitle => 'Einkaufszettel';

  @override
  String get shoppingNote =>
      'Gemeinsam mit der Familie, Ende-zu-Ende-verschlüsselt';

  @override
  String get shoppingHintItem => 'Was wird gebraucht?';

  @override
  String get shoppingHintQuantity => 'Menge (optional)';

  @override
  String get shoppingAdd => 'Hinzufügen';

  @override
  String get shoppingEmpty =>
      'Der Einkaufszettel ist leer. Füge oben etwas hinzu.';

  @override
  String shoppingOpenHeader(int count) {
    return 'Zu besorgen ($count)';
  }

  @override
  String shoppingDoneHeader(int count) {
    return 'Erledigt ($count)';
  }

  @override
  String get shoppingClearDone => 'Erledigte entfernen';

  @override
  String shoppingClearConfirm(int count) {
    return '$count erledigte Einträge für die ganze Familie entfernen?';
  }

  @override
  String shoppingCleared(int count) {
    return '$count Einträge entfernt';
  }

  @override
  String get shoppingEditTitle => 'Eintrag bearbeiten';

  @override
  String get shoppingEdit => 'Bearbeiten';

  @override
  String get shoppingDelete => 'Löschen';

  @override
  String shoppingMarkDone(String name) {
    return '$name als erledigt markieren';
  }

  @override
  String shoppingMarkOpen(String name) {
    return '$name wieder auf die Liste setzen';
  }

  @override
  String shoppingLastBy(String name) {
    return 'zuletzt von $name';
  }

  @override
  String get shoppingLimit =>
      'Der Einkaufszettel ist voll (höchstens 300 Einträge). Entferne erledigte Einträge.';

  @override
  String get shoppingInvalid =>
      'Dieser Eintrag ist ungültig (leer, zu lang oder mit unzulässigen Zeichen).';

  @override
  String get todayOnlineHeader => 'Wer ist online';

  @override
  String get todayNobodyOnline => 'Gerade ist sonst niemand online.';

  @override
  String todayShoppingOpen(int count) {
    return 'Einkaufszettel: $count offen';
  }

  @override
  String get privacy10Title => 'Online-Status, Einzelchats, Einkaufszettel';

  @override
  String get privacy10Body =>
      'Der Online-Status („online“ oder „offline“ mit Zeitpunkt) wird nur als Ende-zu-Ende-verschlüsselte Gerätenachricht an Geräte beigetretener Familienmitglieder gesendet und nie gespeichert; du kannst ihn in den Einstellungen ausschalten. Einzelchats sind verschlüsselte Räume zwischen zwei Familienmitgliedern. Der Einkaufszettel wird wie geteilte Termine verschlüsselt im Familienraum übertragen und liegt verschlüsselt auf deinem Gerät; alle Familienmitglieder können ihn ändern. Der Server sieht nur Metadaten wie Zeitpunkte und Größe.';

  @override
  String onbFamilyFound(String name) {
    return 'Familie „$name“ gefunden – du bist bereits Mitglied. Die Einrichtung wird abgeschlossen.';
  }

  @override
  String get settingsAccent => 'Akzentfarbe';

  @override
  String get settingsAccentHint =>
      'Neonfarbe für Schaltflächen, Auswahl und Hervorhebungen. Gilt im hellen und im dunklen Design.';

  @override
  String get accentTeal => 'Türkis';

  @override
  String get accentMagenta => 'Magenta';

  @override
  String get accentViolet => 'Violett';

  @override
  String get accentSky => 'Himmelblau';

  @override
  String get accentLime => 'Limette';

  @override
  String get accentOrange => 'Orange';

  @override
  String get accentRose => 'Rosé';

  @override
  String get accentGreen => 'Grün';

  @override
  String get menuOpen => 'Menü öffnen';

  @override
  String get menuTitle => 'Menü';

  @override
  String get chatReport => 'Nachricht melden';

  @override
  String chatBlockSender(String name) {
    return '$name blockieren';
  }

  @override
  String get reportTitle => 'Nachricht melden';

  @override
  String reportIntro(String server) {
    return 'Die Meldung geht an den Betreiber deines Servers ($server). Er kann den verschlüsselten Inhalt nicht lesen. Übertragen werden die Kennung der Nachricht, der gewählte Grund und dein optionaler Text – dieser Text ist für den Betreiber lesbar.';
  }

  @override
  String get reportCategorySpam => 'Spam oder Werbung';

  @override
  String get reportCategoryHarassment => 'Belästigung oder Beleidigung';

  @override
  String get reportCategoryInappropriate => 'Unangemessener Inhalt';

  @override
  String get reportCategoryOther => 'Anderer Grund';

  @override
  String get reportDetailsHint => 'Optional: Was ist passiert?';

  @override
  String get reportSend => 'Melden';

  @override
  String get reportDone => 'Meldung gesendet.';

  @override
  String get reportBlockOffer => 'Absender blockieren';

  @override
  String blockConfirmTitle(String name) {
    return '$name blockieren?';
  }

  @override
  String blockConfirmBody(String name) {
    return 'Nachrichten und der Einzelchat von $name werden auf diesem Gerät ausgeblendet. $name erfährt davon nichts und bleibt Mitglied der Familie. Du kannst die Blockierung jederzeit in den Einstellungen aufheben.';
  }

  @override
  String get blockConfirmAction => 'Blockieren';

  @override
  String blockDone(String name) {
    return '$name ist blockiert.';
  }

  @override
  String get unblockAction => 'Blockierung aufheben';

  @override
  String unblockDone(String name) {
    return 'Blockierung von $name aufgehoben.';
  }

  @override
  String get memberBlockedBadge => 'Blockiert';

  @override
  String get settingsBlockedUsers => 'Blockierte Mitglieder';

  @override
  String get settingsBlockedUsersHint =>
      'Nachrichten blockierter Mitglieder werden ausgeblendet.';

  @override
  String get blockedUsersEmpty => 'Du hast niemanden blockiert.';

  @override
  String get privacy11Title => 'Melden und Blockieren';

  @override
  String get privacy11Body =>
      'Blockierte Mitglieder merkt sich die App nur auf diesem Gerät (verschlüsselte Datenbank); sie werden nicht übertragen. Meldest du eine Nachricht, erhält der Betreiber deines Servers die Kennung der Nachricht, den gewählten Grund und deinen optionalen Text. Den verschlüsselten Inhalt kann er nicht lesen.';

  @override
  String get familyInviteMail => 'Per E-Mail senden';

  @override
  String get inviteMailSubject => 'Einladung zu FamilyNexus';

  @override
  String inviteMailBody(String family, String link, String hours) {
    return 'Hallo,\n\nich lade dich in unsere Familie „$family“ bei FamilyNexus ein (Familienkalender und Messenger, Ende-zu-Ende-verschlüsselt).\n\n1. Installiere die App FamilyNexus.\n2. Wähle bei der Einrichtung „Beitreten“ und füge diesen Link ein – oder öffne den Link bzw. scanne den QR-Code mit der Kamera-App:\n\n$link\n\nDer Link ist $hours Stunden gültig. Danach bestätige ich deinen Beitritt.';
  }

  @override
  String get familyInviteMailFailed =>
      'Kein Mailprogramm gefunden. Der Link wurde stattdessen kopiert.';

  @override
  String get onbInvitedTitle => 'Du wurdest eingeladen';

  @override
  String onbInvitedJoin(String family) {
    return '„$family“ beitreten';
  }

  @override
  String get onbInvitedOther =>
      'Stattdessen eine andere Familie gründen oder beitreten';
}
