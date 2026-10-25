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
      'Kalender und Chat für deine Familie – privat und verschlüsselt. Keine Werbung, keine Datensammelei.';

  @override
  String get onbPoint1 => 'Keine Telemetrie, keine Werbung, keine Analyse.';

  @override
  String get onbPoint2 =>
      'Chat und geteilte Termine sind Ende-zu-Ende-verschlüsselt.';

  @override
  String get onbPoint3 => 'Private Termine verlassen nie deine eigenen Geräte.';

  @override
  String get serverUrlInvalid => 'Bitte eine gültige https-Adresse eingeben.';

  @override
  String serverOperator(String name) {
    return 'Betreiber: $name';
  }

  @override
  String get serverNoPassword =>
      'Bei diesem Anbieter ist keine Anmeldung mit Passwort möglich.';

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
  String get errServerUnsupported =>
      'Dieser Anbieter wird von FamilyNexus nicht unterstützt. Bitte wähle unter „Erweitert“ einen anderen.';

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
  String get securityTitle => 'Notfall-Schlüssel und Geräte';

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
  String get familyInviteLinkTitle => 'Jemanden einladen';

  @override
  String familyInviteLinkHint(String validity) {
    return 'Der Link ist $validity gültig und nur einmal verwendbar. Wer ihn öffnet, wird automatisch aufgenommen, sobald die App eines Moderators online ist.';
  }

  @override
  String get familyInviteShowQr => 'QR-Code anzeigen';

  @override
  String get familyInviteCopyLink => 'Link kopieren';

  @override
  String get familyInviteCopied => 'Link kopiert.';

  @override
  String get familyInviteById => 'Per Benutzer-ID einladen';

  @override
  String get familyInviteByIdHint => '@name:server';

  @override
  String get familyInviteSend => 'Einladen';

  @override
  String get familyInviteInvalidId =>
      'Bitte eine gültige Benutzer-ID eingeben, z. B. @anna:beispiel.de.';

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
      'Füge den Einladungslink ein oder öffne den Link bzw. QR-Code mit der Kamera-App.';

  @override
  String get joinLinkLabel => 'Einladungslink';

  @override
  String get joinSend => 'Beitritt anfragen';

  @override
  String get joinPending =>
      'Fast geschafft! Deine Anfrage ist unterwegs. Sobald sie bestätigt ist, bist du dabei.';

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
  String get onbChangeAccount => 'Anderes Konto verwenden';

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
      'FamilyNexus ist freie Software (AGPL-3.0). Die App sendet keine Daten an die Entwickler und enthält keine Telemetrie, Werbung oder Analyse. Verantwortlich für die Verarbeitung auf dem Server ist der Betreiber des von dir gewählten Anbieters (Matrix-Server); er steht bei der Einrichtung unter „Erweitert“. Legst du in der App ein Konto an, gehen Name, Benutzername, Passwort und – falls der Anbieter sie verlangt – deine E-Mail-Adresse nur an diesen Anbieter. Bei Anbietern mit Anmeldung im Browser (z. B. matrix.org) gibst du diese Angaben direkt auf dessen Seite ein.';

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
      'Android-Backups sind ausgeschaltet. Speicherst du einen Anhang bewusst über „Speichern“, liegt die entschlüsselte Datei außerhalb der App in dem von dir gewählten Ordner. Mit „Alle lokalen Daten löschen“ entfernst du alle Daten, Schlüssel und Erinnerungen von diesem Gerät. Nachrichten auf Geräten anderer Mitglieder lassen sich technisch nicht erzwungen löschen. Dein Notfall-Schlüssel ist das einzige Mittel, Nachrichten nach Verlust aller Geräte zu retten – bewahre ihn sicher auf. Kopierst du ihn, wird die Zwischenablage nach einer Minute geleert; speicherst du ihn als Datei, liegt er unverschlüsselt an dem von dir gewählten Ort.';

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
  String menuVersion(String version) {
    return 'Version $version';
  }

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
  String inviteMailBody(String family, String link, String validity) {
    return 'Hallo,\n\nich lade dich in unsere Familie „$family“ bei FamilyNexus ein – Familienkalender und Chat, privat und verschlüsselt.\n\nSo geht’s (ca. 2 Minuten):\n1. Installiere die App FamilyNexus.\n2. Tippe auf diesen Link – oder öffne die App, wähle „Ich wurde eingeladen“ und füge den Link ein:\n\n$link\n\n3. Lege dein Konto an.\n4. Sobald die App eines Moderators online ist, wirst du automatisch aufgenommen.\n\nDer Link ist $validity gültig.';
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

  @override
  String get tasksTitle => 'Aufgaben';

  @override
  String get tasksNote =>
      'Nur Moderatoren legen Listen an. Abhaken kann nur die zugewiesene Person.';

  @override
  String get tasksEmpty => 'Noch keine Aufgabenlisten.';

  @override
  String get tasksSectionMine => 'Mir zugewiesen';

  @override
  String get tasksSectionOthers => 'Weitere Listen';

  @override
  String get tasksNew => 'Neue Aufgabenliste';

  @override
  String get tasksEditTitle => 'Aufgabenliste bearbeiten';

  @override
  String get tasksFieldTitle => 'Titel';

  @override
  String get tasksFieldAssignee => 'Zugewiesen an';

  @override
  String get tasksFieldInterval => 'Wiederholung';

  @override
  String get tasksFieldItems => 'Punkte (einer pro Zeile)';

  @override
  String get tasksIntervalDaily => 'Täglich';

  @override
  String get tasksIntervalWeekly => 'Wöchentlich';

  @override
  String get tasksIntervalMonthly => 'Monatlich';

  @override
  String get tasksResetDaily => 'Startet jeden Tag um Mitternacht neu';

  @override
  String tasksAssignedTo(String name) {
    return 'Zugewiesen an $name';
  }

  @override
  String tasksProgress(int done, int total) {
    return '$done von $total erledigt';
  }

  @override
  String get tasksDelete => 'Liste löschen';

  @override
  String tasksDeleteConfirm(String title) {
    return 'Liste „$title“ löschen?';
  }

  @override
  String tasksMarkDone(String item) {
    return '$item als erledigt markieren';
  }

  @override
  String tasksMarkUndone(String item) {
    return 'Erledigung von $item zurücknehmen';
  }

  @override
  String get tasksCommentTitle => 'Erledigt';

  @override
  String get tasksCommentHint => 'Kommentar (optional)';

  @override
  String get tasksConfirmDone => 'Erledigt';

  @override
  String tasksDoneOn(String date, String time) {
    return 'Erledigt am $date um $time';
  }

  @override
  String get tasksHistory => 'Verlauf';

  @override
  String get tasksHistoryEmpty => 'Noch keine Einträge.';

  @override
  String tasksHistoryDone(String item) {
    return '$item erledigt';
  }

  @override
  String tasksHistoryUndone(String item) {
    return '$item zurückgenommen';
  }

  @override
  String tasksHistoryLine(String name, String date, String time) {
    return '$name · $date $time';
  }

  @override
  String get tasksInvalid =>
      'Bitte Titel, Person und mindestens einen Punkt angeben.';

  @override
  String get tasksLimit =>
      'Grenze erreicht: zu viele Aufgabenlisten, Punkte oder Einträge.';

  @override
  String todayTasksOpen(int count) {
    return 'Aufgaben für dich: $count offen';
  }

  @override
  String get privacy12Title => 'Aufgabenlisten';

  @override
  String get privacy12Body =>
      'Aufgabenlisten und ihr Verlauf (wer wann welchen Punkt erledigt hat, inkl. optionalem Kommentar) werden wie geteilte Termine Ende-zu-Ende-verschlüsselt im Familienraum übertragen und liegen verschlüsselt auf deinem Gerät. Alle Familienmitglieder können sie lesen. Der Server sieht nur Metadaten wie Zeitpunkte und Größe.';

  @override
  String get webUnlockTitleCreate => 'Browser-Tresor einrichten';

  @override
  String get webUnlockBodyCreate =>
      'Dieser Browser speichert deine Daten verschlüsselt. Wähle dafür ein Passwort. Es wird nirgends gespeichert und kann nicht wiederhergestellt werden; wer es vergisst, kann nur alle lokalen Daten löschen und sich neu anmelden.';

  @override
  String get webUnlockTitle => 'FamilyNexus entsperren';

  @override
  String get webUnlockBody => 'Gib das Passwort für diesen Browser ein.';

  @override
  String get webPassword => 'Passwort';

  @override
  String get webPasswordRepeat => 'Passwort wiederholen';

  @override
  String get webPasswordTooShort => 'Mindestens 10 Zeichen.';

  @override
  String get webPasswordMismatch => 'Die Passwörter stimmen nicht überein.';

  @override
  String get webPasswordWrong => 'Falsches Passwort.';

  @override
  String get webUnlockAction => 'Entsperren';

  @override
  String get webCreateAction => 'Tresor anlegen';

  @override
  String get webUnlockBusy => 'Wird entsperrt …';

  @override
  String get webForgotPassword =>
      'Passwort vergessen? Alle lokalen Daten löschen';

  @override
  String get webTabBusyTitle => 'FamilyNexus ist schon geöffnet';

  @override
  String get webTabBusyBody =>
      'Die App läuft bereits in einem anderen Tab oder Fenster dieses Browsers. Zwei Tabs gleichzeitig würden die lokalen Daten beschädigen. Schließe den anderen Tab und versuche es erneut.';

  @override
  String get privacy13Title => 'Browser-Version';

  @override
  String get privacy13Body =>
      'In der Web-Version liegen deine Daten verschlüsselt im Speicher dieses Browsers (IndexedDB, SQLite3MultipleCiphers). Der Schlüssel dafür ist mit deinem Browser-Passwort geschützt, das nirgends gespeichert wird. Es gibt keinen Bildschirmschutz und keine Erinnerungen bei geschlossener Seite. Auf einem fremden oder gemeinsam genutzten Rechner solltest du die Web-Version nicht verwenden. Die Seite lädt nichts von Drittanbietern nach.';

  @override
  String get startCreateTitle => 'Neue Familie gründen';

  @override
  String get startCreateBody =>
      'Du richtest alles ein und lädst deine Familie danach ein.';

  @override
  String get startInvitedTitle => 'Ich wurde eingeladen';

  @override
  String get startInvitedBody => 'Du hast einen Link oder QR-Code bekommen.';

  @override
  String get startLoginTitle => 'Ich habe schon ein Konto';

  @override
  String get startLoginBody =>
      'Du nutzt FamilyNexus schon, z. B. auf einem anderen Gerät.';

  @override
  String get startHaveAccount => 'Ich habe schon ein Konto';

  @override
  String get regTitle => 'Konto erstellen';

  @override
  String get regNameLabel => 'Wie heißt du?';

  @override
  String get regNameHint => 'z. B. Anna Müller';

  @override
  String get regUsernameLabel => 'Dein Benutzername';

  @override
  String get regUsernameHint =>
      'Damit meldest du dich an. 3 bis 32 Zeichen: Kleinbuchstaben, Ziffern, Punkt, Unterstrich oder Bindestrich.';

  @override
  String get regUsernameFree => 'Der Benutzername ist frei.';

  @override
  String get regUsernameTaken => 'Dieser Benutzername ist schon vergeben.';

  @override
  String regUsernameTakenSuggest(String suggestion) {
    return 'Schon vergeben – wie wäre es mit „$suggestion“?';
  }

  @override
  String regUseSuggestion(String suggestion) {
    return '„$suggestion“ verwenden';
  }

  @override
  String get regUsernameInvalid =>
      'Bitte 3 bis 32 Zeichen: Kleinbuchstaben, Ziffern, Punkt, Unterstrich oder Bindestrich.';

  @override
  String get regPasswordHint =>
      'Mindestens 8 Zeichen. Mit Benutzername und Passwort meldest du dich später auch auf einem neuen Gerät an.';

  @override
  String get passwordShow => 'Passwort anzeigen';

  @override
  String get passwordHide => 'Passwort verbergen';

  @override
  String get regCreate => 'Konto erstellen';

  @override
  String get regCreating => 'Erstelle Konto …';

  @override
  String get regExtraTitle => 'Noch ein kurzer Schritt';

  @override
  String get regTermsBody =>
      'Der Anbieter möchte, dass du seinen Bedingungen zustimmst.';

  @override
  String get regTermsAgree => 'Ich habe die Bedingungen gelesen und stimme zu.';

  @override
  String get regEmailBody =>
      'Gib deine E-Mail-Adresse ein. Der Anbieter schickt dir einen Bestätigungslink. Die Adresse geht nur an den Anbieter, nicht an uns.';

  @override
  String get regEmailLabel => 'E-Mail-Adresse';

  @override
  String get regEmailInvalid => 'Bitte eine gültige E-Mail-Adresse eingeben.';

  @override
  String get regEmailSend => 'Bestätigung senden';

  @override
  String regEmailSent(String email) {
    return 'Der Anbieter hat eine E-Mail an $email geschickt. Öffne sie und tippe auf den Link. Komm danach hierher zurück.';
  }

  @override
  String get regEmailConfirmed => 'Ich habe bestätigt';

  @override
  String get regEmailResend => 'E-Mail erneut senden';

  @override
  String get regEmailNotYet =>
      'Noch nicht bestätigt. Bitte öffne den Link in der E-Mail (auch im Spam-Ordner nachsehen).';

  @override
  String get regTokenBody =>
      'Dieser Anbieter gibt Konten nur mit einem Zugangscode frei. Du bekommst ihn vom Anbieter (nicht der Einladungslink der Familie).';

  @override
  String get regTokenLabel => 'Zugangscode des Anbieters';

  @override
  String get regTokenWrong => 'Der Code passt nicht. Bitte prüfe ihn.';

  @override
  String get regCaptchaBody =>
      'Bitte bestätige im Browser kurz, dass du kein Roboter bist. Danach geht es hier automatisch weiter.';

  @override
  String get regCaptchaOpen => 'Im Browser öffnen';

  @override
  String get regCaptchaDone => 'Ich bin fertig';

  @override
  String get regCaptchaNotYet =>
      'Noch nicht abgeschlossen. Bitte beende die Bestätigung im Browser.';

  @override
  String regOAuthIntro(String host) {
    return 'Bei $host legst du dein Konto auf der Seite des Anbieters an. Danach kommst du automatisch hierher zurück.';
  }

  @override
  String regOAuthCreate(String host) {
    return 'Konto bei $host erstellen';
  }

  @override
  String regExternalBody(String host) {
    return 'Bei $host kann die App kein Konto anlegen. Erstelle es auf der Webseite des Anbieters und melde dich danach hier an.';
  }

  @override
  String get regExternalOpen => 'Webseite öffnen';

  @override
  String get regExternalLogin => 'Ich habe ein Konto – anmelden';

  @override
  String get regElementOpen => 'Element starten';

  @override
  String regElementMissing(String host) {
    return 'Element ist nicht installiert. Du kannst es hier laden und dort ein Konto beim Server $host anlegen. Danach hier „Ich habe ein Konto – anmelden“ wählen.';
  }

  @override
  String get regElementDownload => 'Element laden';

  @override
  String familyRequestCheckCode(String id) {
    return 'Anfrage über den Familien-Code (ohne Link) – nur bestätigen, wenn du $id kennst und erwartest';
  }

  @override
  String get familyCodeTitle => 'Familien-Code';

  @override
  String get familyCodeHint =>
      'Wer dir ohne Link beitreten will, gibt diesen Code ein. Du musst die Anfrage danach ausdrücklich bestätigen.';

  @override
  String get familyCodeCopy => 'Code kopieren';

  @override
  String get familyCodeCopied => 'Code kopiert';

  @override
  String get joinCodeTitle => 'Ohne Link beitreten (Familien-Code)';

  @override
  String get joinCodeHint =>
      'Frag einen Moderator nach dem Familien-Code. Er muss deine Anfrage bestätigen.';

  @override
  String get joinCodeLabel => 'Familien-Code';

  @override
  String get joinCodeInvalid =>
      'Das ist kein gültiger Familien-Code. Er beginnt mit „!“ und enthält einen Server, z. B. !abc:matrix.org.';

  @override
  String get joinRejected =>
      'Deine Anfrage wurde abgelehnt. Frag bei der Familie nach, ob sie dich einladen möchte, und versuche es dann mit einem neuen Link.';

  @override
  String get joinRejectedOk => 'Verstanden';

  @override
  String tabFamilyRequests(int count) {
    return 'Familie – $count offene Anfragen';
  }

  @override
  String get familyInviteServerLabel => 'Konto-Server für Neue';

  @override
  String get familyInviteServerHint =>
      'Auf diesem Server legen Neulinge ihr Konto an und melden sich an. Leer lassen = dein Server. Der Familienraum bleibt, wo er ist.';

  @override
  String get familyInviteServerApply => 'Neuen Link erzeugen';

  @override
  String get familyInviteServerInvalid =>
      'Das ist keine gültige Server-Adresse.';

  @override
  String oauthWaiting(String host) {
    return 'Bitte im Browser bei $host fortfahren … Danach geht es hier automatisch weiter.';
  }

  @override
  String loginOAuthIntro(String host) {
    return 'Bei $host meldest du dich auf der Seite des Anbieters an. Danach kommst du automatisch hierher zurück.';
  }

  @override
  String loginOAuth(String host) {
    return 'Bei $host anmelden';
  }

  @override
  String get loginNoAccount => 'Noch kein Konto? Jetzt erstellen';

  @override
  String get advTitle => 'Erweitert';

  @override
  String advServerInfo(String host) {
    return 'Dein Konto liegt bei $host.';
  }

  @override
  String advChecking(String host) {
    return 'Verbinde mit $host …';
  }

  @override
  String get advEnterProvider => 'Bitte gib die Adresse des Anbieters ein.';

  @override
  String advUnreachable(String host) {
    return '$host ist gerade nicht erreichbar. Prüfe deine Internetverbindung.';
  }

  @override
  String get advExplain =>
      'FamilyNexus nutzt das offene Matrix-Netz. Dein Konto liegt bei einem Anbieter deiner Wahl – oder auf einem eigenen Server.';

  @override
  String advStandardProvider(String host) {
    return '$host (empfohlen)';
  }

  @override
  String get advOtherProvider => 'Anderen Anbieter verwenden';

  @override
  String get advProviderLabel => 'Adresse des Anbieters';

  @override
  String get advProviderHint => 'z. B. matrix.beispiel.de';

  @override
  String get keyTitle => 'Dein Notfall-Schlüssel';

  @override
  String get keyIntro =>
      'Deine Nachrichten und Termine sind verschlüsselt. Damit du sie auch auf einem neuen Handy wieder öffnen kannst, bekommst du jetzt einen Notfall-Schlüssel – wie einen Ersatzschlüssel für die Haustür.';

  @override
  String get keyCreate => 'Notfall-Schlüssel erstellen';

  @override
  String get keyCreating => 'Erstelle …';

  @override
  String get keyShownIntro =>
      'Wenn du dein Handy verlierst, brauchst du diesen Schlüssel, um deine Nachrichten wiederzubekommen. Niemand sonst – auch wir nicht – kann ihn wiederherstellen. Er wird nur jetzt angezeigt.';

  @override
  String get keyCopy => 'Kopieren';

  @override
  String get keyCopied =>
      'Kopiert. Füge ihn z. B. in deinen Passwort-Manager ein. Die Zwischenablage wird nach einer Minute geleert.';

  @override
  String get keySave => 'Als Datei speichern';

  @override
  String get keySavedFile =>
      'Gespeichert. Bewahre die Datei sicher auf – am besten ausgedruckt.';

  @override
  String get keyPrintHint =>
      'Tipp: Speichere die Datei und drucke sie aus – oder schreibe den Schlüssel auf Papier ab.';

  @override
  String get keySavedCheck =>
      'Ich habe den Notfall-Schlüssel sicher aufbewahrt.';

  @override
  String get keyFileName => 'FamilyNexus-Notfall-Schluessel.txt';

  @override
  String keyFileBody(String user, String provider, String key, String date) {
    return 'FamilyNexus – Notfall-Schlüssel\n\nKonto: $user\nAnbieter: $provider\nErstellt am: $date\n\nNotfall-Schlüssel:\n$key\n\nSo nutzt du ihn: Installiere FamilyNexus auf dem neuen Gerät, wähle „Ich habe schon ein Konto“, melde dich an und gib bei „Dieses Gerät freischalten“ den Notfall-Schlüssel ein.\n\nBewahre dieses Blatt sicher auf und gib es niemandem.';
  }

  @override
  String get keyRestoreTitle => 'Dieses Gerät freischalten';

  @override
  String get keyRestoreIntro =>
      'Dein Konto ist schon abgesichert. Schalte dieses Gerät frei – mit einem anderen Gerät, auf dem du angemeldet bist, oder mit deinem Notfall-Schlüssel.';

  @override
  String keyVerifyWithDevice(String device) {
    return 'Mit „$device“ bestätigen';
  }

  @override
  String get keyNoOtherDevice =>
      'Kein anderes Gerät gefunden. Nutze deinen Notfall-Schlüssel.';

  @override
  String get keyRestoreLabel => 'Notfall-Schlüssel';

  @override
  String get keyRestoreButton => 'Freischalten';

  @override
  String get keyRestoring => 'Schalte frei …';

  @override
  String get keyRestoreFailed =>
      'Der Notfall-Schlüssel passt nicht. Bitte prüfe ihn noch einmal.';

  @override
  String get inviteStepTitle => 'Einladung';

  @override
  String get inviteStepBody =>
      'Füge den Einladungslink ein, den du bekommen hast. Hast du einen QR-Code? Scanne ihn mit der Kamera-App – FamilyNexus öffnet sich dann von selbst.';

  @override
  String get inviteStepNoLink =>
      'Kein Link? Bitte die Person, die dich einlädt, dir einen zu schicken.';

  @override
  String joinCardBody(String family, String inviter, String server) {
    return 'Du trittst der Familie „$family“ bei. Eingeladen hat dich $inviter (Konto bei $server).';
  }

  @override
  String joinCardBodyNoName(String inviter, String server) {
    return 'Du trittst einer Familie bei. Eingeladen hat dich $inviter (Konto bei $server).';
  }

  @override
  String joinCardNote(String inviter) {
    return 'Angaben laut Einladung. Die App eines Moderators nimmt dich automatisch auf, sobald sie online ist.';
  }

  @override
  String get joinCardDetails => 'Details';

  @override
  String get joinCardDetailsInviter => 'Benutzer-ID der einladenden Person';

  @override
  String get joinCardDetailsServer => 'Server der Familie';

  @override
  String get joinDiscard => 'Verwerfen';

  @override
  String get joinSending => 'Sende …';

  @override
  String joinWaiting(String inviter) {
    return 'Fast geschafft! $inviter muss dich noch bestätigen. Sag kurz Bescheid – du kannst die App so lange schließen.';
  }

  @override
  String get joinAlreadyInFamily => 'Du bist bereits in einer Familie.';

  @override
  String get familyNameHint => 'z. B. Familie Müller';

  @override
  String familyCreatedTitle(String name) {
    return 'Fertig! „$name“ ist eingerichtet.';
  }

  @override
  String get familyCreatedBody =>
      'Lade jetzt deine Familie ein – per QR-Code, E-Mail oder Link. Du kannst das auch später unter „Familie“ tun.';

  @override
  String get familyInviteNow => 'Jetzt einladen';

  @override
  String get later => 'Später';

  @override
  String get familySwitchToJoin => 'Ich wurde doch eingeladen';

  @override
  String get familySwitchToCreate => 'Stattdessen eine neue Familie gründen';

  @override
  String get familyInviteIntro =>
      'Lade Familienmitglieder ein. Sie bekommen einen Link oder QR-Code und schicken dir eine Anfrage, die du bestätigst.';

  @override
  String get familyInviteSomeone => 'Jemanden einladen';

  @override
  String get familyInviteScanHint =>
      'Lass die Person diesen Code mit der Kamera ihres Handys scannen – oder schick ihr den Link.';

  @override
  String familyRequestFrom(String name) {
    return '$name möchte beitreten';
  }

  @override
  String get errUsernameTaken => 'Dieser Benutzername ist schon vergeben.';

  @override
  String get errUsernameInvalid =>
      'Dieser Benutzername ist nicht erlaubt. Bitte wähle einen anderen.';

  @override
  String get errWeakPassword =>
      'Das Passwort ist zu schwach. Bitte nimm ein längeres Passwort.';

  @override
  String get errRegistrationDisabled =>
      'Bei diesem Anbieter kann die App kein Konto anlegen. Erstelle es auf seiner Webseite.';

  @override
  String get errEmailInUse =>
      'Diese E-Mail-Adresse wird schon für ein anderes Konto verwendet.';

  @override
  String get errOAuthCancelled =>
      'Die Anmeldung im Browser wurde nicht abgeschlossen. Bitte versuche es noch einmal.';

  @override
  String joinCardServerMismatch(String family, String inviter) {
    return 'Achtung: Die Familie liegt bei $family, die einladende Person aber bei $inviter. Tritt nur bei, wenn du diese Einladung wirklich erwartet hast.';
  }

  @override
  String get weekdayLongMon => 'Montag';

  @override
  String get weekdayLongTue => 'Dienstag';

  @override
  String get weekdayLongWed => 'Mittwoch';

  @override
  String get weekdayLongThu => 'Donnerstag';

  @override
  String get weekdayLongFri => 'Freitag';

  @override
  String get weekdayLongSat => 'Samstag';

  @override
  String get weekdayLongSun => 'Sonntag';

  @override
  String get tasksBadgeWeekdays => 'Mo–Fr';

  @override
  String get tasksFieldDescription => 'Erklärung (optional)';

  @override
  String get tasksDescriptionHint => 'z. B. was genau zu tun ist';

  @override
  String get tasksRepeatMonthlyWeekday => 'Monatlich nach Wochentag';

  @override
  String get tasksRepeatMonthlyDate => 'Monatlich nach Datum';

  @override
  String get tasksDailyAllDays => 'Alle Wochentage (auch Samstag und Sonntag)';

  @override
  String get tasksDailyWeekdays => 'Montag bis Freitag (ohne Wochenende)';

  @override
  String get tasksFieldWeekday => 'Wochentag';

  @override
  String get tasksFieldOrdinal => 'Welcher';

  @override
  String get tasksFieldDay => 'Tag des Monats';

  @override
  String get tasksOrdinal1 => 'Erster';

  @override
  String get tasksOrdinal2 => 'Zweiter';

  @override
  String get tasksOrdinal3 => 'Dritter';

  @override
  String get tasksOrdinal4 => 'Vierter';

  @override
  String get tasksOrdinalLast => 'Letzter';

  @override
  String get tasksOrdinalInText1 => 'ersten';

  @override
  String get tasksOrdinalInText2 => 'zweiten';

  @override
  String get tasksOrdinalInText3 => 'dritten';

  @override
  String get tasksOrdinalInText4 => 'vierten';

  @override
  String get tasksOrdinalInTextLast => 'letzten';

  @override
  String get tasksRuleWeekdays => 'Montag bis Freitag';

  @override
  String tasksRuleWeekly(String weekday) {
    return 'Wöchentlich am $weekday';
  }

  @override
  String tasksRuleMonthlyWeekday(String ordinal, String weekday) {
    return 'Monatlich am $ordinal $weekday';
  }

  @override
  String tasksRuleMonthlyDate(int day) {
    return 'Monatlich am $day.';
  }

  @override
  String get tasksResetWeekdays =>
      'Startet montags bis freitags neu, nicht am Wochenende';

  @override
  String tasksResetWeeklyOn(String weekday) {
    return 'Startet jeden $weekday neu';
  }

  @override
  String tasksResetMonthlyWeekday(String ordinal, String weekday) {
    return 'Startet jeden Monat am $ordinal $weekday neu';
  }

  @override
  String tasksResetMonthlyDate(int day) {
    return 'Startet jeden Monat am $day. neu';
  }

  @override
  String tasksResetMonthlyDateShort(int day) {
    return 'Startet jeden Monat am $day. neu – in Monaten ohne diesen Tag am letzten Tag des Monats';
  }

  @override
  String tasksNextReset(String date) {
    return 'Nächster Neustart: $date';
  }

  @override
  String get tasksDescriptionTooLong =>
      'Die Erklärung ist zu lang. Bitte kürze sie etwas.';

  @override
  String get joinLinkNotALink =>
      'Das ist kein Einladungslink. Ein Einladungslink beginnt mit „familynexus://join“.';

  @override
  String get joinLinkDamaged =>
      'Der Link ist unvollständig oder beschädigt – oft passiert das beim Weiterleiten. Bitte kopiere ihn noch einmal vollständig oder scanne den QR-Code.';

  @override
  String get joinLinkExpired =>
      'Dieser Einladungslink ist abgelaufen. Bitte die Person, die dich einlädt, um einen neuen Link.';

  @override
  String get joinLinkNewerVersion =>
      'Dieser Link stammt aus einer neueren Version von FamilyNexus. Bitte aktualisiere die App und versuche es noch einmal.';

  @override
  String joinCardLocalServer(String server) {
    return 'Achtung: Diese Familie liegt auf einem Server im Heimnetz ($server). Er ist nur erreichbar, wenn dein Gerät im selben Netz ist (z. B. im WLAN der Familie). Fahre nur fort, wenn du diese Einladung erwartet hast.';
  }

  @override
  String inviteValidityDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days Tage',
      one: '1 Tag',
    );
    return '$_temp0';
  }

  @override
  String get familyInviteValidityLabel => 'Gültig für';

  @override
  String inviteValidityInSentence(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days Tage',
      one: 'einen Tag',
    );
    return '$_temp0';
  }

  @override
  String joinCardLocalOtherAccount(String family, String own) {
    return 'Diese Familie liegt auf einem Server im Heimnetz ($family). Mit deinem Konto bei $own kannst du ihr nicht beitreten. Lege stattdessen ein Konto bei $family an (dazu abmelden und „Ich wurde eingeladen“ wählen).';
  }

  @override
  String advLocalConsent(String host) {
    return 'Die Einladung verweist auf einen Server im Heimnetz ($host). Verbinde dich nur, wenn du die Einladung erwartet hast und im selben Netz bist (z. B. im WLAN der Familie).';
  }

  @override
  String advLocalConnect(String host) {
    return 'Mit $host verbinden';
  }

  @override
  String get settingsStorageTitle => 'Speicherorte';

  @override
  String get settingsStorageDbDir => 'Datenbank-Ordner';

  @override
  String get settingsStorageBrowser =>
      'Browser-Speicher (IndexedDB) dieser Webadresse';

  @override
  String get settingsStorageAppDb =>
      'App-Daten: Termine, Listen, Einstellungen (verschlüsselt)';

  @override
  String get settingsStorageMatrixDb =>
      'Chat- und Abgleichsdaten: Matrix (verschlüsselt)';

  @override
  String get settingsStorageKeys => 'Datenbankschlüssel';

  @override
  String get settingsStorageOnline => 'Online beim Matrix-Anbieter';

  @override
  String get keyStoreAndroid => 'Android Keystore (an dieses Gerät gebunden)';

  @override
  String get keyStoreApple => 'Schlüsselbund des Geräts (nicht in iCloud)';

  @override
  String get keyStoreLinux => 'Schlüsselbund des Systems (Secret Service)';

  @override
  String get keyStoreWindows => 'Windows-Anmeldeinformationsverwaltung';

  @override
  String get keyStoreBrowser =>
      'Passwortgeschützter Tresor im Browser-Speicher (localStorage)';

  @override
  String get settingsReportLocal =>
      'Protokoll: alle lokal gespeicherten Daten zeigen';

  @override
  String get settingsReportOnline =>
      'Protokoll: alle online gespeicherten Daten zeigen';

  @override
  String get reportLocalTitle => 'Lokal gespeicherte Daten';

  @override
  String get reportOnlineTitle => 'Online gespeicherte Daten';

  @override
  String get reportWarning =>
      'Das Protokoll zeigt deine Daten im Klartext. Beim Kopieren oder Speichern verlassen sie den verschlüsselten Speicher der App.';

  @override
  String get reportCopy => 'Kopieren';

  @override
  String get reportCopied => 'Protokoll kopiert.';

  @override
  String get reportSave => 'Als Datei speichern';

  @override
  String get reportSaved => 'Protokoll gespeichert.';

  @override
  String reportGenerated(String time, String version) {
    return 'Erstellt: $time · App-Version $version';
  }

  @override
  String get reportSectionKeys => 'Schlüsselspeicher';

  @override
  String get reportKeyPresent => 'vorhanden (Wert wird nicht angezeigt)';

  @override
  String get reportKeyMissing => 'nicht vorhanden';

  @override
  String get reportSectionAppDb => 'App-Datenbank';

  @override
  String reportFileSize(String size) {
    return 'Dateigröße: $size';
  }

  @override
  String reportRows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Einträge',
      one: '1 Eintrag',
      zero: 'keine Einträge',
    );
    return '$_temp0';
  }

  @override
  String get reportSectionMatrixDb => 'Matrix-Datenbank (Zwischenspeicher)';

  @override
  String get reportMatrixSecrets =>
      'Außerdem gespeichert, aber aus Sicherheitsgründen nicht angezeigt: Zugangstoken der Sitzung, Geräteschlüssel und Schlüssel der verschlüsselten Gespräche.';

  @override
  String get reportMatrixUnavailable =>
      'Nicht verfügbar (nicht angemeldet oder Fehler beim Lesen).';

  @override
  String get reportMemoryOnly =>
      'Nie gespeichert, nur im Arbeitsspeicher: Online-Status der Familienmitglieder.';

  @override
  String get reportOsReminders =>
      'Geplante Erinnerungen liegen zusätzlich beim Betriebssystem.';

  @override
  String get reportSectionAccount => 'Konto';

  @override
  String get reportDisplayName => 'Anzeigename';

  @override
  String get reportAvatar => 'Profilbild';

  @override
  String get reportYes => 'ja';

  @override
  String get reportNo => 'nein';

  @override
  String get reportNotSet => 'nicht gesetzt';

  @override
  String get reportSectionSecurity => 'Verschlüsselung';

  @override
  String get reportCrossSigning => 'Cross-Signing-Schlüssel';

  @override
  String get reportKeyBackup =>
      'Schlüssel-Backup (mit deinem Wiederherstellungsschlüssel verschlüsselt)';

  @override
  String get reportSetUp => 'eingerichtet';

  @override
  String get reportNotSetUp => 'nicht eingerichtet';

  @override
  String get reportSectionAccountData =>
      'Kontodaten (nur Arten, Inhalte werden nicht angezeigt)';

  @override
  String get reportSectionRooms => 'Räume';

  @override
  String get reportNone => 'keine';

  @override
  String get roomKindFamily => 'Familie';

  @override
  String get roomKindPrivate => 'Privater Raum (Abgleich privater Termine)';

  @override
  String get roomKindDirect => 'Einzelchat';

  @override
  String get roomKindOther => 'Sonstiger Raum';

  @override
  String get reportRoomEncrypted => 'Ende-zu-Ende-verschlüsselt';

  @override
  String get reportRoomMembership => 'Eigene Mitgliedschaft';

  @override
  String reportRoomMembers(int joined, int invited) {
    return 'Mitglieder: $joined beigetreten, $invited eingeladen';
  }

  @override
  String reportRoomEvents(int count) {
    return 'Ereignisse auf diesem Gerät: $count';
  }

  @override
  String reportRoomAttachments(int count) {
    return 'Anhänge: $count';
  }

  @override
  String get reportFamilyMembers => 'Mitglieder der Familie';

  @override
  String get reportOnlineNote =>
      'Inhalte von Nachrichten, Terminen, Listen und Anhängen liegen beim Anbieter nur Ende-zu-Ende-verschlüsselt vor. Lesbar für den Anbieter sind Metadaten: Konto, Geräte, Raummitglieder, Zeitpunkte und Größe der Ereignisse sowie die Arten der Kontodaten. Die Ereigniszahlen beruhen auf dem Abgleich dieses Geräts; beim Anbieter können ältere Ereignisse zusätzlich liegen.';

  @override
  String get eventTypeMessage => 'Nachrichten';

  @override
  String get eventTypeReaction => 'Reaktionen';

  @override
  String get eventTypeSharedEvent => 'Termine (geteilt)';

  @override
  String get eventTypePrivateEvent => 'Termine (privat)';

  @override
  String get eventTypeRsvp => 'Zu- und Absagen';

  @override
  String get eventTypeShopping => 'Einkaufszettel';

  @override
  String get eventTypeTaskList => 'Aufgabenlisten';

  @override
  String get eventTypeTaskDone => 'Erledigte Aufgaben';

  @override
  String get eventTypeEncrypted => 'Nicht entschlüsselbar';

  @override
  String reportFile(String path) {
    return 'Datei: $path';
  }

  @override
  String get reportMembershipJoined => 'beigetreten';

  @override
  String get reportMembershipInvited => 'eingeladen';

  @override
  String get reportMembershipRequested => 'Beitritt angefragt';

  @override
  String get reportMembershipLeft => 'verlassen';

  @override
  String get reportMembershipBanned => 'ausgeschlossen';
}
