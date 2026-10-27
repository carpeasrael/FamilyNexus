import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
  ];

  /// No description provided for @appName.
  ///
  /// In de, this message translates to:
  /// **'FamilyNexus'**
  String get appName;

  /// No description provided for @tabToday.
  ///
  /// In de, this message translates to:
  /// **'Heute'**
  String get tabToday;

  /// No description provided for @tabCalendar.
  ///
  /// In de, this message translates to:
  /// **'Kalender'**
  String get tabCalendar;

  /// No description provided for @tabChat.
  ///
  /// In de, this message translates to:
  /// **'Chat'**
  String get tabChat;

  /// No description provided for @tabFamily.
  ///
  /// In de, this message translates to:
  /// **'Familie'**
  String get tabFamily;

  /// No description provided for @tabSettings.
  ///
  /// In de, this message translates to:
  /// **'Einstellungen'**
  String get tabSettings;

  /// No description provided for @emptyToday.
  ///
  /// In de, this message translates to:
  /// **'Noch keine Termine. Sobald Termine anstehen, erscheinen sie hier.'**
  String get emptyToday;

  /// No description provided for @emptyCalendar.
  ///
  /// In de, this message translates to:
  /// **'Der Kalender ist noch leer.'**
  String get emptyCalendar;

  /// No description provided for @emptyChat.
  ///
  /// In de, this message translates to:
  /// **'Noch keine Nachrichten.'**
  String get emptyChat;

  /// No description provided for @emptyFamily.
  ///
  /// In de, this message translates to:
  /// **'Es ist noch keine Familie eingerichtet.'**
  String get emptyFamily;

  /// No description provided for @settingsSectionDisplay.
  ///
  /// In de, this message translates to:
  /// **'Darstellung'**
  String get settingsSectionDisplay;

  /// No description provided for @settingsSectionPrivacy.
  ///
  /// In de, this message translates to:
  /// **'Datenschutz'**
  String get settingsSectionPrivacy;

  /// No description provided for @settingsSectionAbout.
  ///
  /// In de, this message translates to:
  /// **'Über die App'**
  String get settingsSectionAbout;

  /// No description provided for @settingsLanguage.
  ///
  /// In de, this message translates to:
  /// **'Sprache'**
  String get settingsLanguage;

  /// No description provided for @languageSystem.
  ///
  /// In de, this message translates to:
  /// **'Gerätesprache'**
  String get languageSystem;

  /// No description provided for @languageGerman.
  ///
  /// In de, this message translates to:
  /// **'Deutsch'**
  String get languageGerman;

  /// No description provided for @languageEnglish.
  ///
  /// In de, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @settingsTheme.
  ///
  /// In de, this message translates to:
  /// **'Design'**
  String get settingsTheme;

  /// No description provided for @themeSystem.
  ///
  /// In de, this message translates to:
  /// **'Wie Gerät'**
  String get themeSystem;

  /// No description provided for @themeDark.
  ///
  /// In de, this message translates to:
  /// **'Dunkel'**
  String get themeDark;

  /// No description provided for @themeLight.
  ///
  /// In de, this message translates to:
  /// **'Hell'**
  String get themeLight;

  /// No description provided for @settingsReduceEffects.
  ///
  /// In de, this message translates to:
  /// **'Effekte reduzieren'**
  String get settingsReduceEffects;

  /// No description provided for @settingsReduceEffectsHint.
  ///
  /// In de, this message translates to:
  /// **'Weniger Unschärfe und Leuchten, deckendere Flächen.'**
  String get settingsReduceEffectsHint;

  /// No description provided for @settingsSecureScreen.
  ///
  /// In de, this message translates to:
  /// **'Bildschirmschutz'**
  String get settingsSecureScreen;

  /// No description provided for @settingsSecureScreenHint.
  ///
  /// In de, this message translates to:
  /// **'Blockiert Screenshots und verbirgt die App in der Übersicht.'**
  String get settingsSecureScreenHint;

  /// No description provided for @settingsLicense.
  ///
  /// In de, this message translates to:
  /// **'Lizenz: AGPL-3.0-or-later'**
  String get settingsLicense;

  /// No description provided for @settingsNoTelemetry.
  ///
  /// In de, this message translates to:
  /// **'Keine Telemetrie, keine Werbung, keine Analyse.'**
  String get settingsNoTelemetry;

  /// No description provided for @loading.
  ///
  /// In de, this message translates to:
  /// **'Lädt …'**
  String get loading;

  /// No description provided for @errorGeneric.
  ///
  /// In de, this message translates to:
  /// **'Etwas ist schiefgelaufen.'**
  String get errorGeneric;

  /// No description provided for @retry.
  ///
  /// In de, this message translates to:
  /// **'Erneut versuchen'**
  String get retry;

  /// No description provided for @startupFailedTitle.
  ///
  /// In de, this message translates to:
  /// **'Lokale Daten nicht lesbar'**
  String get startupFailedTitle;

  /// No description provided for @startupFailedBody.
  ///
  /// In de, this message translates to:
  /// **'Die verschlüsselte Datenbank konnte nicht geöffnet werden, zum Beispiel weil der Schlüssel des Geräts nicht mehr verfügbar ist. Aus Sicherheitsgründen wurde nichts verändert. Du kannst die lokalen Daten zurücksetzen und neu einrichten; Daten auf dem Server und anderen Geräten bleiben erhalten.'**
  String get startupFailedBody;

  /// No description provided for @startupRetry.
  ///
  /// In de, this message translates to:
  /// **'Erneut versuchen'**
  String get startupRetry;

  /// No description provided for @startupReset.
  ///
  /// In de, this message translates to:
  /// **'Lokale Daten zurücksetzen'**
  String get startupReset;

  /// No description provided for @startupResetConfirmTitle.
  ///
  /// In de, this message translates to:
  /// **'Lokale Daten wirklich löschen?'**
  String get startupResetConfirmTitle;

  /// No description provided for @startupResetConfirmBody.
  ///
  /// In de, this message translates to:
  /// **'Alle Daten dieser App auf diesem Gerät werden unwiderruflich gelöscht.'**
  String get startupResetConfirmBody;

  /// No description provided for @cancel.
  ///
  /// In de, this message translates to:
  /// **'Abbrechen'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In de, this message translates to:
  /// **'Löschen'**
  String get delete;

  /// No description provided for @next.
  ///
  /// In de, this message translates to:
  /// **'Weiter'**
  String get next;

  /// No description provided for @back.
  ///
  /// In de, this message translates to:
  /// **'Zurück'**
  String get back;

  /// No description provided for @done.
  ///
  /// In de, this message translates to:
  /// **'Fertig'**
  String get done;

  /// No description provided for @save.
  ///
  /// In de, this message translates to:
  /// **'Speichern'**
  String get save;

  /// No description provided for @close.
  ///
  /// In de, this message translates to:
  /// **'Schließen'**
  String get close;

  /// No description provided for @onbStep.
  ///
  /// In de, this message translates to:
  /// **'Schritt {current} von {total}'**
  String onbStep(int current, int total);

  /// No description provided for @onbTitleLanguage.
  ///
  /// In de, this message translates to:
  /// **'Willkommen bei FamilyNexus'**
  String get onbTitleLanguage;

  /// No description provided for @onbIntro.
  ///
  /// In de, this message translates to:
  /// **'Kalender und Chat für deine Familie – privat und verschlüsselt. Keine Werbung, keine Datensammelei.'**
  String get onbIntro;

  /// No description provided for @onbPoint1.
  ///
  /// In de, this message translates to:
  /// **'Keine Telemetrie, keine Werbung, keine Analyse.'**
  String get onbPoint1;

  /// No description provided for @onbPoint2.
  ///
  /// In de, this message translates to:
  /// **'Chat und geteilte Termine sind Ende-zu-Ende-verschlüsselt.'**
  String get onbPoint2;

  /// No description provided for @onbPoint3.
  ///
  /// In de, this message translates to:
  /// **'Private Termine verlassen nie deine eigenen Geräte.'**
  String get onbPoint3;

  /// No description provided for @serverUrlInvalid.
  ///
  /// In de, this message translates to:
  /// **'Bitte eine gültige https-Adresse eingeben.'**
  String get serverUrlInvalid;

  /// No description provided for @serverOperator.
  ///
  /// In de, this message translates to:
  /// **'Betreiber: {name}'**
  String serverOperator(String name);

  /// No description provided for @serverNoPassword.
  ///
  /// In de, this message translates to:
  /// **'Bei diesem Anbieter ist keine Anmeldung mit Passwort möglich.'**
  String get serverNoPassword;

  /// No description provided for @serverMetadataNote.
  ///
  /// In de, this message translates to:
  /// **'Der Server sieht keine Inhalte, aber Metadaten wie wer wann mit wem schreibt. Wer das vermeiden möchte, nutzt einen eigenen Server.'**
  String get serverMetadataNote;

  /// No description provided for @onbTitleAccount.
  ///
  /// In de, this message translates to:
  /// **'Anmelden'**
  String get onbTitleAccount;

  /// No description provided for @accountUsername.
  ///
  /// In de, this message translates to:
  /// **'Benutzername'**
  String get accountUsername;

  /// No description provided for @accountPassword.
  ///
  /// In de, this message translates to:
  /// **'Passwort'**
  String get accountPassword;

  /// No description provided for @accountLogin.
  ///
  /// In de, this message translates to:
  /// **'Anmelden'**
  String get accountLogin;

  /// No description provided for @accountLoggingIn.
  ///
  /// In de, this message translates to:
  /// **'Melde an …'**
  String get accountLoggingIn;

  /// No description provided for @onbTitleFamily.
  ///
  /// In de, this message translates to:
  /// **'Familie'**
  String get onbTitleFamily;

  /// No description provided for @familyName.
  ///
  /// In de, this message translates to:
  /// **'Name der Familie'**
  String get familyName;

  /// No description provided for @familyCreate.
  ///
  /// In de, this message translates to:
  /// **'Familie gründen'**
  String get familyCreate;

  /// No description provided for @familyCreating.
  ///
  /// In de, this message translates to:
  /// **'Lege an …'**
  String get familyCreating;

  /// No description provided for @familyCreateHint.
  ///
  /// In de, this message translates to:
  /// **'Du wirst Moderator. Lade später einen zweiten Moderator ein, damit die Familie bei Geräteverlust handlungsfähig bleibt.'**
  String get familyCreateHint;

  /// No description provided for @familyMinorsNote.
  ///
  /// In de, this message translates to:
  /// **'Kinder können Mitglied werden. Bitte hole dafür die Einwilligung der Sorgeberechtigten ein.'**
  String get familyMinorsNote;

  /// No description provided for @familyRoleModerator.
  ///
  /// In de, this message translates to:
  /// **'Moderator'**
  String get familyRoleModerator;

  /// No description provided for @familyRoleMember.
  ///
  /// In de, this message translates to:
  /// **'Mitglied'**
  String get familyRoleMember;

  /// No description provided for @familyMembers.
  ///
  /// In de, this message translates to:
  /// **'Mitglieder'**
  String get familyMembers;

  /// No description provided for @familySecondModerator.
  ///
  /// In de, this message translates to:
  /// **'Empfehlung: Ernenne einen zweiten Moderator.'**
  String get familySecondModerator;

  /// No description provided for @statusInvited.
  ///
  /// In de, this message translates to:
  /// **'Eingeladen'**
  String get statusInvited;

  /// No description provided for @statusRequested.
  ///
  /// In de, this message translates to:
  /// **'Anfrage'**
  String get statusRequested;

  /// No description provided for @errInvalidCredentials.
  ///
  /// In de, this message translates to:
  /// **'Benutzername oder Passwort stimmen nicht.'**
  String get errInvalidCredentials;

  /// No description provided for @errServerUnreachable.
  ///
  /// In de, this message translates to:
  /// **'Server nicht erreichbar. Prüfe die Verbindung.'**
  String get errServerUnreachable;

  /// No description provided for @errServerUnsupported.
  ///
  /// In de, this message translates to:
  /// **'Dieser Anbieter wird von FamilyNexus nicht unterstützt. Bitte wähle unter „Erweitert“ einen anderen.'**
  String get errServerUnsupported;

  /// No description provided for @errNotAllowed.
  ///
  /// In de, this message translates to:
  /// **'Dafür fehlt die Berechtigung.'**
  String get errNotAllowed;

  /// No description provided for @errAttachmentRejected.
  ///
  /// In de, this message translates to:
  /// **'Dieser Anhang ist nicht erlaubt (Typ oder Größe).'**
  String get errAttachmentRejected;

  /// No description provided for @errInvalidInput.
  ///
  /// In de, this message translates to:
  /// **'Bitte Eingabe prüfen.'**
  String get errInvalidInput;

  /// No description provided for @errNotFound.
  ///
  /// In de, this message translates to:
  /// **'Nicht gefunden.'**
  String get errNotFound;

  /// No description provided for @errEncryption.
  ///
  /// In de, this message translates to:
  /// **'Verschlüsselung nicht verfügbar. Es wird nichts gesendet.'**
  String get errEncryption;

  /// No description provided for @errUnknown.
  ///
  /// In de, this message translates to:
  /// **'Unbekannter Fehler.'**
  String get errUnknown;

  /// No description provided for @chatHint.
  ///
  /// In de, this message translates to:
  /// **'Nachricht schreiben'**
  String get chatHint;

  /// No description provided for @chatSend.
  ///
  /// In de, this message translates to:
  /// **'Senden'**
  String get chatSend;

  /// No description provided for @chatAttach.
  ///
  /// In de, this message translates to:
  /// **'Datei anhängen'**
  String get chatAttach;

  /// No description provided for @chatReply.
  ///
  /// In de, this message translates to:
  /// **'Antworten'**
  String get chatReply;

  /// No description provided for @chatReplyingTo.
  ///
  /// In de, this message translates to:
  /// **'Antwort an {name}'**
  String chatReplyingTo(String name);

  /// No description provided for @chatCancelReply.
  ///
  /// In de, this message translates to:
  /// **'Antwort abbrechen'**
  String get chatCancelReply;

  /// No description provided for @chatReact.
  ///
  /// In de, this message translates to:
  /// **'Reagieren'**
  String get chatReact;

  /// No description provided for @chatRetry.
  ///
  /// In de, this message translates to:
  /// **'Senden fehlgeschlagen – tippen zum Wiederholen'**
  String get chatRetry;

  /// No description provided for @chatSending.
  ///
  /// In de, this message translates to:
  /// **'Wird gesendet …'**
  String get chatSending;

  /// No description provided for @chatEncryptedNote.
  ///
  /// In de, this message translates to:
  /// **'Ende-zu-Ende-verschlüsselt'**
  String get chatEncryptedNote;

  /// No description provided for @chatAttachmentBlocked.
  ///
  /// In de, this message translates to:
  /// **'Anhang blockiert (Typ oder Größe nicht erlaubt)'**
  String get chatAttachmentBlocked;

  /// No description provided for @chatLoadAttachment.
  ///
  /// In de, this message translates to:
  /// **'Anhang laden'**
  String get chatLoadAttachment;

  /// No description provided for @chatSaveAttachment.
  ///
  /// In de, this message translates to:
  /// **'Speichern'**
  String get chatSaveAttachment;

  /// No description provided for @chatMessageFrom.
  ///
  /// In de, this message translates to:
  /// **'Nachricht von {name}'**
  String chatMessageFrom(String name);

  /// No description provided for @chatYou.
  ///
  /// In de, this message translates to:
  /// **'Du'**
  String get chatYou;

  /// No description provided for @logout.
  ///
  /// In de, this message translates to:
  /// **'Abmelden'**
  String get logout;

  /// No description provided for @settingsAccount.
  ///
  /// In de, this message translates to:
  /// **'Konto'**
  String get settingsAccount;

  /// No description provided for @settingsServer.
  ///
  /// In de, this message translates to:
  /// **'Server'**
  String get settingsServer;

  /// No description provided for @serverContactUnknown.
  ///
  /// In de, this message translates to:
  /// **'Kontakt: nicht angegeben'**
  String get serverContactUnknown;

  /// No description provided for @serverContact.
  ///
  /// In de, this message translates to:
  /// **'Kontakt: {contact}'**
  String serverContact(String contact);

  /// No description provided for @errAlreadyExists.
  ///
  /// In de, this message translates to:
  /// **'Es gibt bereits eine Familie für dieses Konto.'**
  String get errAlreadyExists;

  /// No description provided for @errRateLimited.
  ///
  /// In de, this message translates to:
  /// **'Zu viele Anfragen. Bitte später erneut versuchen.'**
  String get errRateLimited;

  /// No description provided for @chatUndecryptable.
  ///
  /// In de, this message translates to:
  /// **'Nachricht kann nicht entschlüsselt werden'**
  String get chatUndecryptable;

  /// No description provided for @syncing.
  ///
  /// In de, this message translates to:
  /// **'Synchronisiere …'**
  String get syncing;

  /// No description provided for @reminderTitle.
  ///
  /// In de, this message translates to:
  /// **'Erinnerung'**
  String get reminderTitle;

  /// No description provided for @reminderBody.
  ///
  /// In de, this message translates to:
  /// **'Termin in {duration}'**
  String reminderBody(String duration);

  /// No description provided for @reminderChannelName.
  ///
  /// In de, this message translates to:
  /// **'Erinnerungen'**
  String get reminderChannelName;

  /// No description provided for @reminderChannelDescription.
  ///
  /// In de, this message translates to:
  /// **'Erinnerungen an Termine. Sie zeigen keine Inhalte an.'**
  String get reminderChannelDescription;

  /// No description provided for @durationNow.
  ///
  /// In de, this message translates to:
  /// **'0 Minuten'**
  String get durationNow;

  /// No description provided for @durationMinutes.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 Minute} other{{count} Minuten}}'**
  String durationMinutes(int count);

  /// No description provided for @durationHours.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 Stunde} other{{count} Stunden}}'**
  String durationHours(int count);

  /// No description provided for @durationDays.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 Tag} other{{count} Tage}}'**
  String durationDays(int count);

  /// No description provided for @reminderBefore.
  ///
  /// In de, this message translates to:
  /// **'{duration} vorher'**
  String reminderBefore(String duration);

  /// No description provided for @reminderAtStart.
  ///
  /// In de, this message translates to:
  /// **'Zur Startzeit'**
  String get reminderAtStart;

  /// No description provided for @remindersTitle.
  ///
  /// In de, this message translates to:
  /// **'Erinnerungen'**
  String get remindersTitle;

  /// No description provided for @remindersHint.
  ///
  /// In de, this message translates to:
  /// **'Erinnerungen sind lokale Benachrichtigungen dieses Geräts. Sie zeigen nie Titel oder Ort.'**
  String get remindersHint;

  /// No description provided for @remindersPermissionNotifications.
  ///
  /// In de, this message translates to:
  /// **'Benachrichtigungen sind blockiert. Ohne sie erscheinen keine Erinnerungen.'**
  String get remindersPermissionNotifications;

  /// No description provided for @remindersPermissionExact.
  ///
  /// In de, this message translates to:
  /// **'Genaue Alarme sind nicht erlaubt. Erinnerungen können sich verspäten.'**
  String get remindersPermissionExact;

  /// No description provided for @remindersAllow.
  ///
  /// In de, this message translates to:
  /// **'Erlauben'**
  String get remindersAllow;

  /// No description provided for @remindersPlanned.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =0{Keine Erinnerung geplant} =1{1 Erinnerung geplant} other{{count} Erinnerungen geplant}}'**
  String remindersPlanned(int count);

  /// No description provided for @remindersDefault.
  ///
  /// In de, this message translates to:
  /// **'Standard-Erinnerung'**
  String get remindersDefault;

  /// No description provided for @remindersNone.
  ///
  /// In de, this message translates to:
  /// **'Keine'**
  String get remindersNone;

  /// No description provided for @viewDay.
  ///
  /// In de, this message translates to:
  /// **'Tag'**
  String get viewDay;

  /// No description provided for @viewWeek.
  ///
  /// In de, this message translates to:
  /// **'Woche'**
  String get viewWeek;

  /// No description provided for @viewMonth.
  ///
  /// In de, this message translates to:
  /// **'Monat'**
  String get viewMonth;

  /// No description provided for @viewAgenda.
  ///
  /// In de, this message translates to:
  /// **'Agenda'**
  String get viewAgenda;

  /// No description provided for @calendarToday.
  ///
  /// In de, this message translates to:
  /// **'Heute'**
  String get calendarToday;

  /// No description provided for @calendarPrevious.
  ///
  /// In de, this message translates to:
  /// **'Zurück'**
  String get calendarPrevious;

  /// No description provided for @calendarNext.
  ///
  /// In de, this message translates to:
  /// **'Weiter'**
  String get calendarNext;

  /// No description provided for @calendarAll.
  ///
  /// In de, this message translates to:
  /// **'Alle'**
  String get calendarAll;

  /// No description provided for @calendarFilterPerson.
  ///
  /// In de, this message translates to:
  /// **'Nach Person filtern'**
  String get calendarFilterPerson;

  /// No description provided for @calendarNoEvents.
  ///
  /// In de, this message translates to:
  /// **'Keine Termine'**
  String get calendarNoEvents;

  /// No description provided for @calendarAllDay.
  ///
  /// In de, this message translates to:
  /// **'Ganztägig'**
  String get calendarAllDay;

  /// No description provided for @calendarNewEvent.
  ///
  /// In de, this message translates to:
  /// **'Neuer Termin'**
  String get calendarNewEvent;

  /// No description provided for @calendarEventsOnDay.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =0{Keine Termine} =1{1 Termin} other{{count} Termine}}'**
  String calendarEventsOnDay(int count);

  /// No description provided for @todayNext.
  ///
  /// In de, this message translates to:
  /// **'Nächste Termine'**
  String get todayNext;

  /// No description provided for @todayUnread.
  ///
  /// In de, this message translates to:
  /// **'Ungelesene Nachrichten'**
  String get todayUnread;

  /// No description provided for @todayUnreadCount.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =0{Keine ungelesenen Nachrichten} =1{1 ungelesene Nachricht} other{{count} ungelesene Nachrichten}}'**
  String todayUnreadCount(int count);

  /// No description provided for @todayNoUpcoming.
  ///
  /// In de, this message translates to:
  /// **'In den nächsten 30 Tagen stehen keine Termine an.'**
  String get todayNoUpcoming;

  /// No description provided for @todayOpenChat.
  ///
  /// In de, this message translates to:
  /// **'Chat öffnen'**
  String get todayOpenChat;

  /// No description provided for @visibilityPrivate.
  ///
  /// In de, this message translates to:
  /// **'Privat'**
  String get visibilityPrivate;

  /// No description provided for @visibilityShared.
  ///
  /// In de, this message translates to:
  /// **'Geteilt'**
  String get visibilityShared;

  /// No description provided for @visibilityPrivateHint.
  ///
  /// In de, this message translates to:
  /// **'Nur auf deinen eigenen Geräten. Wird nie an die Familie gesendet.'**
  String get visibilityPrivateHint;

  /// No description provided for @visibilitySharedHint.
  ///
  /// In de, this message translates to:
  /// **'Verschlüsselt an die Familie gesendet. Mitglieder sehen den Termin und können zu- oder absagen.'**
  String get visibilitySharedHint;

  /// No description provided for @visibilityChangeNote.
  ///
  /// In de, this message translates to:
  /// **'Bereits an die Familie gesendete Inhalte bleiben auf deren Geräten, auch wenn du den Termin später privat machst.'**
  String get visibilityChangeNote;

  /// No description provided for @eventNew.
  ///
  /// In de, this message translates to:
  /// **'Neuer Termin'**
  String get eventNew;

  /// No description provided for @eventEdit.
  ///
  /// In de, this message translates to:
  /// **'Termin bearbeiten'**
  String get eventEdit;

  /// No description provided for @eventTitle.
  ///
  /// In de, this message translates to:
  /// **'Titel'**
  String get eventTitle;

  /// No description provided for @eventTitleRequired.
  ///
  /// In de, this message translates to:
  /// **'Bitte einen Titel eingeben.'**
  String get eventTitleRequired;

  /// No description provided for @eventAllDay.
  ///
  /// In de, this message translates to:
  /// **'Ganztägig'**
  String get eventAllDay;

  /// No description provided for @eventStart.
  ///
  /// In de, this message translates to:
  /// **'Beginn'**
  String get eventStart;

  /// No description provided for @eventEnd.
  ///
  /// In de, this message translates to:
  /// **'Ende'**
  String get eventEnd;

  /// No description provided for @eventEndBeforeStart.
  ///
  /// In de, this message translates to:
  /// **'Das Ende liegt vor dem Beginn.'**
  String get eventEndBeforeStart;

  /// No description provided for @eventLocation.
  ///
  /// In de, this message translates to:
  /// **'Ort'**
  String get eventLocation;

  /// No description provided for @eventNote.
  ///
  /// In de, this message translates to:
  /// **'Notiz'**
  String get eventNote;

  /// No description provided for @eventColor.
  ///
  /// In de, this message translates to:
  /// **'Farbe'**
  String get eventColor;

  /// No description provided for @eventColorName.
  ///
  /// In de, this message translates to:
  /// **'Farbe {number}'**
  String eventColorName(int number);

  /// No description provided for @eventAttendees.
  ///
  /// In de, this message translates to:
  /// **'Teilnehmer'**
  String get eventAttendees;

  /// No description provided for @eventVisibility.
  ///
  /// In de, this message translates to:
  /// **'Sichtbarkeit'**
  String get eventVisibility;

  /// No description provided for @eventTimeZone.
  ///
  /// In de, this message translates to:
  /// **'Zeitzone: {zone}'**
  String eventTimeZone(String zone);

  /// No description provided for @eventSaveError.
  ///
  /// In de, this message translates to:
  /// **'Der Termin konnte nicht gespeichert werden.'**
  String get eventSaveError;

  /// No description provided for @eventRepeat.
  ///
  /// In de, this message translates to:
  /// **'Wiederholung'**
  String get eventRepeat;

  /// No description provided for @repeatNone.
  ///
  /// In de, this message translates to:
  /// **'Keine'**
  String get repeatNone;

  /// No description provided for @repeatDaily.
  ///
  /// In de, this message translates to:
  /// **'Täglich'**
  String get repeatDaily;

  /// No description provided for @repeatWeekly.
  ///
  /// In de, this message translates to:
  /// **'Wöchentlich'**
  String get repeatWeekly;

  /// No description provided for @repeatMonthly.
  ///
  /// In de, this message translates to:
  /// **'Monatlich'**
  String get repeatMonthly;

  /// No description provided for @repeatYearly.
  ///
  /// In de, this message translates to:
  /// **'Jährlich'**
  String get repeatYearly;

  /// No description provided for @repeatEvery.
  ///
  /// In de, this message translates to:
  /// **'Alle'**
  String get repeatEvery;

  /// No description provided for @repeatUnitDays.
  ///
  /// In de, this message translates to:
  /// **'Tage'**
  String get repeatUnitDays;

  /// No description provided for @repeatUnitWeeks.
  ///
  /// In de, this message translates to:
  /// **'Wochen'**
  String get repeatUnitWeeks;

  /// No description provided for @repeatUnitMonths.
  ///
  /// In de, this message translates to:
  /// **'Monate'**
  String get repeatUnitMonths;

  /// No description provided for @repeatUnitYears.
  ///
  /// In de, this message translates to:
  /// **'Jahre'**
  String get repeatUnitYears;

  /// No description provided for @repeatEnds.
  ///
  /// In de, this message translates to:
  /// **'Endet'**
  String get repeatEnds;

  /// No description provided for @repeatEndsNever.
  ///
  /// In de, this message translates to:
  /// **'Nie'**
  String get repeatEndsNever;

  /// No description provided for @repeatEndsOn.
  ///
  /// In de, this message translates to:
  /// **'Am Datum'**
  String get repeatEndsOn;

  /// No description provided for @repeatEndsAfter.
  ///
  /// In de, this message translates to:
  /// **'Nach Anzahl'**
  String get repeatEndsAfter;

  /// No description provided for @repeatCount.
  ///
  /// In de, this message translates to:
  /// **'Anzahl'**
  String get repeatCount;

  /// No description provided for @repeatUntil.
  ///
  /// In de, this message translates to:
  /// **'Letzter Tag'**
  String get repeatUntil;

  /// No description provided for @repeatSummaryDaily.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{Täglich} other{Alle {count} Tage}}'**
  String repeatSummaryDaily(int count);

  /// No description provided for @repeatSummaryWeekly.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{Wöchentlich} other{Alle {count} Wochen}}'**
  String repeatSummaryWeekly(int count);

  /// No description provided for @repeatSummaryMonthly.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{Monatlich} other{Alle {count} Monate}}'**
  String repeatSummaryMonthly(int count);

  /// No description provided for @repeatSummaryYearly.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{Jährlich} other{Alle {count} Jahre}}'**
  String repeatSummaryYearly(int count);

  /// No description provided for @weekdayMon.
  ///
  /// In de, this message translates to:
  /// **'Mo'**
  String get weekdayMon;

  /// No description provided for @weekdayTue.
  ///
  /// In de, this message translates to:
  /// **'Di'**
  String get weekdayTue;

  /// No description provided for @weekdayWed.
  ///
  /// In de, this message translates to:
  /// **'Mi'**
  String get weekdayWed;

  /// No description provided for @weekdayThu.
  ///
  /// In de, this message translates to:
  /// **'Do'**
  String get weekdayThu;

  /// No description provided for @weekdayFri.
  ///
  /// In de, this message translates to:
  /// **'Fr'**
  String get weekdayFri;

  /// No description provided for @weekdaySat.
  ///
  /// In de, this message translates to:
  /// **'Sa'**
  String get weekdaySat;

  /// No description provided for @weekdaySun.
  ///
  /// In de, this message translates to:
  /// **'So'**
  String get weekdaySun;

  /// No description provided for @eventDelete.
  ///
  /// In de, this message translates to:
  /// **'Termin löschen'**
  String get eventDelete;

  /// No description provided for @eventDeleteConfirm.
  ///
  /// In de, this message translates to:
  /// **'Diesen Termin wirklich löschen?'**
  String get eventDeleteConfirm;

  /// No description provided for @eventDeleteSeriesConfirm.
  ///
  /// In de, this message translates to:
  /// **'Alle Vorkommen oder nur dieses löschen?'**
  String get eventDeleteSeriesConfirm;

  /// No description provided for @eventDeleteThis.
  ///
  /// In de, this message translates to:
  /// **'Nur dieses'**
  String get eventDeleteThis;

  /// No description provided for @eventDeleteAll.
  ///
  /// In de, this message translates to:
  /// **'Alle'**
  String get eventDeleteAll;

  /// No description provided for @eventShareInChat.
  ///
  /// In de, this message translates to:
  /// **'Im Chat teilen'**
  String get eventShareInChat;

  /// No description provided for @eventShared.
  ///
  /// In de, this message translates to:
  /// **'Im Chat geteilt'**
  String get eventShared;

  /// No description provided for @eventOwner.
  ///
  /// In de, this message translates to:
  /// **'Von {name}'**
  String eventOwner(String name);

  /// No description provided for @eventOwnerYou.
  ///
  /// In de, this message translates to:
  /// **'Von dir'**
  String get eventOwnerYou;

  /// No description provided for @eventRsvp.
  ///
  /// In de, this message translates to:
  /// **'Antwort'**
  String get eventRsvp;

  /// No description provided for @rsvpAccept.
  ///
  /// In de, this message translates to:
  /// **'Zusagen'**
  String get rsvpAccept;

  /// No description provided for @rsvpDecline.
  ///
  /// In de, this message translates to:
  /// **'Absagen'**
  String get rsvpDecline;

  /// No description provided for @rsvpMaybe.
  ///
  /// In de, this message translates to:
  /// **'Vielleicht'**
  String get rsvpMaybe;

  /// No description provided for @rsvpAccepted.
  ///
  /// In de, this message translates to:
  /// **'Zugesagt'**
  String get rsvpAccepted;

  /// No description provided for @rsvpDeclined.
  ///
  /// In de, this message translates to:
  /// **'Abgesagt'**
  String get rsvpDeclined;

  /// No description provided for @rsvpMaybeStatus.
  ///
  /// In de, this message translates to:
  /// **'Vielleicht'**
  String get rsvpMaybeStatus;

  /// No description provided for @rsvpNone.
  ///
  /// In de, this message translates to:
  /// **'Keine Antwort'**
  String get rsvpNone;

  /// No description provided for @eventHistory.
  ///
  /// In de, this message translates to:
  /// **'Verlauf'**
  String get eventHistory;

  /// No description provided for @eventVersion.
  ///
  /// In de, this message translates to:
  /// **'Version {version}'**
  String eventVersion(int version);

  /// No description provided for @eventRecurring.
  ///
  /// In de, this message translates to:
  /// **'Wiederholt'**
  String get eventRecurring;

  /// No description provided for @eventCancelled.
  ///
  /// In de, this message translates to:
  /// **'Gelöscht'**
  String get eventCancelled;

  /// No description provided for @eventReadOnly.
  ///
  /// In de, this message translates to:
  /// **'Nur der Ersteller kann diesen Termin ändern.'**
  String get eventReadOnly;

  /// No description provided for @eventYourReminders.
  ///
  /// In de, this message translates to:
  /// **'Deine Erinnerungen'**
  String get eventYourReminders;

  /// No description provided for @eventResetReminders.
  ///
  /// In de, this message translates to:
  /// **'Standard verwenden'**
  String get eventResetReminders;

  /// No description provided for @chatEventCard.
  ///
  /// In de, this message translates to:
  /// **'Termin'**
  String get chatEventCard;

  /// No description provided for @chatEventMissing.
  ///
  /// In de, this message translates to:
  /// **'Termin nicht verfügbar'**
  String get chatEventMissing;

  /// No description provided for @settingsReminders.
  ///
  /// In de, this message translates to:
  /// **'Erinnerungen'**
  String get settingsReminders;

  /// No description provided for @repeatUntilInvalid.
  ///
  /// In de, this message translates to:
  /// **'Das letzte Datum der Wiederholung liegt vor dem ersten Termin.'**
  String get repeatUntilInvalid;

  /// No description provided for @errReauth.
  ///
  /// In de, this message translates to:
  /// **'Bitte bestätige dein Passwort.'**
  String get errReauth;

  /// No description provided for @securityTitle.
  ///
  /// In de, this message translates to:
  /// **'Notfall-Schlüssel und Geräte'**
  String get securityTitle;

  /// No description provided for @securityPasswordTitle.
  ///
  /// In de, this message translates to:
  /// **'Passwort bestätigen'**
  String get securityPasswordTitle;

  /// No description provided for @securityPasswordHint.
  ///
  /// In de, this message translates to:
  /// **'Der Server verlangt dein Passwort zur Bestätigung. Es wird nicht gespeichert.'**
  String get securityPasswordHint;

  /// No description provided for @securityStatusReady.
  ///
  /// In de, this message translates to:
  /// **'Dieses Gerät ist verifiziert.'**
  String get securityStatusReady;

  /// No description provided for @securityStatusNeeds.
  ///
  /// In de, this message translates to:
  /// **'Dieses Gerät ist noch nicht verifiziert.'**
  String get securityStatusNeeds;

  /// No description provided for @securityDevices.
  ///
  /// In de, this message translates to:
  /// **'Geräte deines Kontos'**
  String get securityDevices;

  /// No description provided for @securityDeviceThis.
  ///
  /// In de, this message translates to:
  /// **'Dieses Gerät'**
  String get securityDeviceThis;

  /// No description provided for @securityDeviceVerified.
  ///
  /// In de, this message translates to:
  /// **'Verifiziert'**
  String get securityDeviceVerified;

  /// No description provided for @securityDeviceUnverified.
  ///
  /// In de, this message translates to:
  /// **'Nicht verifiziert'**
  String get securityDeviceUnverified;

  /// No description provided for @securityVerifyDevice.
  ///
  /// In de, this message translates to:
  /// **'Verifizieren'**
  String get securityVerifyDevice;

  /// No description provided for @securityVerifyPerson.
  ///
  /// In de, this message translates to:
  /// **'Verifizieren'**
  String get securityVerifyPerson;

  /// No description provided for @verifyTitle.
  ///
  /// In de, this message translates to:
  /// **'Verifizierung'**
  String get verifyTitle;

  /// No description provided for @verifyIncoming.
  ///
  /// In de, this message translates to:
  /// **'{peer} möchte die Verifizierung starten.'**
  String verifyIncoming(String peer);

  /// No description provided for @verifyWaiting.
  ///
  /// In de, this message translates to:
  /// **'Warte auf die Gegenseite …'**
  String get verifyWaiting;

  /// No description provided for @verifyCompare.
  ///
  /// In de, this message translates to:
  /// **'Vergleiche diese Symbole mit denen auf dem anderen Gerät. Sie müssen in gleicher Reihenfolge übereinstimmen.'**
  String get verifyCompare;

  /// No description provided for @verifyMatch.
  ///
  /// In de, this message translates to:
  /// **'Sie stimmen überein'**
  String get verifyMatch;

  /// No description provided for @verifyNoMatch.
  ///
  /// In de, this message translates to:
  /// **'Sie stimmen nicht überein'**
  String get verifyNoMatch;

  /// No description provided for @verifyWaitingConfirm.
  ///
  /// In de, this message translates to:
  /// **'Warte auf Bestätigung der Gegenseite …'**
  String get verifyWaitingConfirm;

  /// No description provided for @verifyDone.
  ///
  /// In de, this message translates to:
  /// **'Verifiziert.'**
  String get verifyDone;

  /// No description provided for @verifyCancelled.
  ///
  /// In de, this message translates to:
  /// **'Die Verifizierung wurde abgebrochen.'**
  String get verifyCancelled;

  /// No description provided for @accept.
  ///
  /// In de, this message translates to:
  /// **'Annehmen'**
  String get accept;

  /// No description provided for @decline.
  ///
  /// In de, this message translates to:
  /// **'Ablehnen'**
  String get decline;

  /// No description provided for @familyManage.
  ///
  /// In de, this message translates to:
  /// **'Verwaltung'**
  String get familyManage;

  /// No description provided for @familyInvite.
  ///
  /// In de, this message translates to:
  /// **'Mitglied einladen'**
  String get familyInvite;

  /// No description provided for @familyInviteLinkTitle.
  ///
  /// In de, this message translates to:
  /// **'Jemanden einladen'**
  String get familyInviteLinkTitle;

  /// No description provided for @familyInviteLinkHint.
  ///
  /// In de, this message translates to:
  /// **'Der Link ist {validity} gültig und nur einmal verwendbar. Wer ihn öffnet, wird automatisch aufgenommen, sobald die App eines Moderators online ist.'**
  String familyInviteLinkHint(String validity);

  /// No description provided for @familyInviteShowQr.
  ///
  /// In de, this message translates to:
  /// **'QR-Code anzeigen'**
  String get familyInviteShowQr;

  /// No description provided for @familyInviteCopyLink.
  ///
  /// In de, this message translates to:
  /// **'Link kopieren'**
  String get familyInviteCopyLink;

  /// No description provided for @familyInviteCopied.
  ///
  /// In de, this message translates to:
  /// **'Link kopiert.'**
  String get familyInviteCopied;

  /// No description provided for @familyInviteById.
  ///
  /// In de, this message translates to:
  /// **'Per Benutzer-ID einladen'**
  String get familyInviteById;

  /// No description provided for @familyInviteByIdHint.
  ///
  /// In de, this message translates to:
  /// **'@name:server'**
  String get familyInviteByIdHint;

  /// No description provided for @familyInviteSend.
  ///
  /// In de, this message translates to:
  /// **'Einladen'**
  String get familyInviteSend;

  /// No description provided for @familyInviteInvalidId.
  ///
  /// In de, this message translates to:
  /// **'Bitte eine gültige Benutzer-ID eingeben, z. B. @anna:beispiel.de.'**
  String get familyInviteInvalidId;

  /// No description provided for @familyInviteSent.
  ///
  /// In de, this message translates to:
  /// **'Einladung gesendet.'**
  String get familyInviteSent;

  /// No description provided for @familyRequests.
  ///
  /// In de, this message translates to:
  /// **'Beitrittsanfragen'**
  String get familyRequests;

  /// No description provided for @familyRequestApprove.
  ///
  /// In de, this message translates to:
  /// **'Bestätigen'**
  String get familyRequestApprove;

  /// No description provided for @familyRequestReject.
  ///
  /// In de, this message translates to:
  /// **'Ablehnen'**
  String get familyRequestReject;

  /// No description provided for @familyMemberPromote.
  ///
  /// In de, this message translates to:
  /// **'Zum Moderator ernennen'**
  String get familyMemberPromote;

  /// No description provided for @familyMemberRemove.
  ///
  /// In de, this message translates to:
  /// **'Entfernen'**
  String get familyMemberRemove;

  /// No description provided for @familyMemberRemoveConfirm.
  ///
  /// In de, this message translates to:
  /// **'{name} wirklich aus der Familie entfernen? Die Raumschlüssel werden erneuert; neue Inhalte kann {name} nicht mehr lesen.'**
  String familyMemberRemoveConfirm(String name);

  /// No description provided for @familyMemberPromoteConfirm.
  ///
  /// In de, this message translates to:
  /// **'{name} zum Moderator ernennen? Moderatoren können einladen, ernennen und entfernen.'**
  String familyMemberPromoteConfirm(String name);

  /// No description provided for @familyRename.
  ///
  /// In de, this message translates to:
  /// **'Familienname ändern'**
  String get familyRename;

  /// No description provided for @familyRenamed.
  ///
  /// In de, this message translates to:
  /// **'Name geändert.'**
  String get familyRenamed;

  /// No description provided for @familyDone.
  ///
  /// In de, this message translates to:
  /// **'Erledigt.'**
  String get familyDone;

  /// No description provided for @familyOnlyModerators.
  ///
  /// In de, this message translates to:
  /// **'Nur Moderatoren verwalten die Familie.'**
  String get familyOnlyModerators;

  /// No description provided for @joinTitle.
  ///
  /// In de, this message translates to:
  /// **'Familie beitreten'**
  String get joinTitle;

  /// No description provided for @joinHint.
  ///
  /// In de, this message translates to:
  /// **'Füge den Einladungslink ein oder öffne den Link bzw. QR-Code mit der Kamera-App.'**
  String get joinHint;

  /// No description provided for @joinLinkLabel.
  ///
  /// In de, this message translates to:
  /// **'Einladungslink'**
  String get joinLinkLabel;

  /// No description provided for @joinSend.
  ///
  /// In de, this message translates to:
  /// **'Beitritt anfragen'**
  String get joinSend;

  /// No description provided for @joinPending.
  ///
  /// In de, this message translates to:
  /// **'Fast geschafft! Deine Anfrage ist unterwegs. Sobald sie bestätigt ist, bist du dabei.'**
  String get joinPending;

  /// No description provided for @joinCancel.
  ///
  /// In de, this message translates to:
  /// **'Anfrage zurückziehen'**
  String get joinCancel;

  /// No description provided for @invitationsTitle.
  ///
  /// In de, this message translates to:
  /// **'Einladungen'**
  String get invitationsTitle;

  /// No description provided for @invitationFrom.
  ///
  /// In de, this message translates to:
  /// **'Einladung von {inviter}'**
  String invitationFrom(String inviter);

  /// No description provided for @onbCreateOrJoin.
  ///
  /// In de, this message translates to:
  /// **'Gründe eine neue Familie oder tritt einer bestehenden bei.'**
  String get onbCreateOrJoin;

  /// No description provided for @onbCreateTab.
  ///
  /// In de, this message translates to:
  /// **'Gründen'**
  String get onbCreateTab;

  /// No description provided for @onbJoinTab.
  ///
  /// In de, this message translates to:
  /// **'Beitreten'**
  String get onbJoinTab;

  /// No description provided for @onbChangeAccount.
  ///
  /// In de, this message translates to:
  /// **'Anderes Konto verwenden'**
  String get onbChangeAccount;

  /// No description provided for @lockTitle.
  ///
  /// In de, this message translates to:
  /// **'FamilyNexus ist gesperrt'**
  String get lockTitle;

  /// No description provided for @lockHint.
  ///
  /// In de, this message translates to:
  /// **'Bestätige mit der Geräteanmeldung (PIN, Muster, Passwort oder Biometrie).'**
  String get lockHint;

  /// No description provided for @lockUnlock.
  ///
  /// In de, this message translates to:
  /// **'Entsperren'**
  String get lockUnlock;

  /// No description provided for @lockReason.
  ///
  /// In de, this message translates to:
  /// **'FamilyNexus entsperren'**
  String get lockReason;

  /// No description provided for @settingsLock.
  ///
  /// In de, this message translates to:
  /// **'App-Sperre'**
  String get settingsLock;

  /// No description provided for @settingsLockHint.
  ///
  /// In de, this message translates to:
  /// **'Sperrt die App nach Inaktivität. Die Bestätigung erfolgt mit der Sperre deines Geräts; die App speichert keine eigene PIN.'**
  String get settingsLockHint;

  /// No description provided for @settingsLockUnavailable.
  ///
  /// In de, this message translates to:
  /// **'Auf diesem Gerät ist keine gesicherte Bildschirmsperre eingerichtet.'**
  String get settingsLockUnavailable;

  /// No description provided for @settingsLockFailed.
  ///
  /// In de, this message translates to:
  /// **'Die Bestätigung war nicht erfolgreich.'**
  String get settingsLockFailed;

  /// No description provided for @settingsLockTimeout.
  ///
  /// In de, this message translates to:
  /// **'Sperren nach'**
  String get settingsLockTimeout;

  /// No description provided for @lockImmediately.
  ///
  /// In de, this message translates to:
  /// **'Sofort'**
  String get lockImmediately;

  /// No description provided for @lock1min.
  ///
  /// In de, this message translates to:
  /// **'1 Minute'**
  String get lock1min;

  /// No description provided for @lock5min.
  ///
  /// In de, this message translates to:
  /// **'5 Minuten'**
  String get lock5min;

  /// No description provided for @lock15min.
  ///
  /// In de, this message translates to:
  /// **'15 Minuten'**
  String get lock15min;

  /// No description provided for @settingsPrivacyPolicy.
  ///
  /// In de, this message translates to:
  /// **'Datenschutzerklärung'**
  String get settingsPrivacyPolicy;

  /// No description provided for @settingsDeleteData.
  ///
  /// In de, this message translates to:
  /// **'Alle lokalen Daten löschen'**
  String get settingsDeleteData;

  /// No description provided for @settingsDeleteDataHint.
  ///
  /// In de, this message translates to:
  /// **'Meldet dich ab und löscht Datenbank, Schlüssel und Erinnerungen auf diesem Gerät.'**
  String get settingsDeleteDataHint;

  /// No description provided for @deleteDataTitle.
  ///
  /// In de, this message translates to:
  /// **'Alle lokalen Daten löschen?'**
  String get deleteDataTitle;

  /// No description provided for @deleteDataBody.
  ///
  /// In de, this message translates to:
  /// **'Alle Daten dieser App auf diesem Gerät werden unwiderruflich gelöscht und du wirst abgemeldet. Nachrichten und geteilte Termine auf Geräten anderer Familienmitglieder lassen sich technisch nicht löschen. Dein Konto beim Server bleibt bestehen; löschen kannst du es unter Einstellungen → Konto → „Konto löschen“.'**
  String get deleteDataBody;

  /// No description provided for @deleteDataConfirm.
  ///
  /// In de, this message translates to:
  /// **'Endgültig löschen'**
  String get deleteDataConfirm;

  /// No description provided for @privacyTitle.
  ///
  /// In de, this message translates to:
  /// **'Datenschutzerklärung'**
  String get privacyTitle;

  /// No description provided for @privacy1Title.
  ///
  /// In de, this message translates to:
  /// **'Wer verarbeitet deine Daten?'**
  String get privacy1Title;

  /// No description provided for @privacy1Body.
  ///
  /// In de, this message translates to:
  /// **'FamilyNexus ist freie Software (AGPL-3.0). Die App sendet keine Daten an die Entwickler und enthält keine Telemetrie, Werbung oder Analyse. Verantwortlich für die Verarbeitung auf dem Server ist der Betreiber des von dir gewählten Anbieters (Matrix-Server); er steht bei der Einrichtung unter „Erweitert“. Legst du in der App ein Konto an, gehen Name, Benutzername, Passwort und – falls der Anbieter sie verlangt – deine E-Mail-Adresse nur an diesen Anbieter. Bei Anbietern mit Anmeldung im Browser (z. B. matrix.org) gibst du diese Angaben direkt auf dessen Seite ein.'**
  String get privacy1Body;

  /// No description provided for @privacy2Title.
  ///
  /// In de, this message translates to:
  /// **'Welche Daten gibt es?'**
  String get privacy2Title;

  /// No description provided for @privacy2Body.
  ///
  /// In de, this message translates to:
  /// **'Chatnachrichten, Dateien, geteilte und private Termine, Zusagen, Einkaufszettel, Familienmitglieder und deine Einstellungen. Termine und Nachrichten liegen verschlüsselt (SQLCipher) auf deinem Gerät. Der Schlüssel dafür liegt im Android-Schlüsselspeicher und nie in einer Datei.'**
  String get privacy2Body;

  /// No description provided for @privacy3Title.
  ///
  /// In de, this message translates to:
  /// **'Was sieht der Server?'**
  String get privacy3Title;

  /// No description provided for @privacy3Body.
  ///
  /// In de, this message translates to:
  /// **'Nachrichten, Dateien und geteilte Termine werden Ende-zu-Ende-verschlüsselt (Matrix, Olm/Megolm). Der Server sieht nur verschlüsselte Ereignisse. Metadaten wie Konto-ID, Zeitpunkte, Raumgröße und Geräte bleiben für den Betreiber sichtbar. Wer das vermeiden möchte, nutzt einen eigenen Server.'**
  String get privacy3Body;

  /// No description provided for @privacy4Title.
  ///
  /// In de, this message translates to:
  /// **'Private Termine'**
  String get privacy4Title;

  /// No description provided for @privacy4Body.
  ///
  /// In de, this message translates to:
  /// **'Private Termine werden nie an die Familie gesendet. Zwischen deinen eigenen Geräten werden sie über einen privaten, verschlüsselten Raum abgeglichen, dem nur dein Konto angehört.'**
  String get privacy4Body;

  /// No description provided for @privacy5Title.
  ///
  /// In de, this message translates to:
  /// **'Erinnerungen und Benachrichtigungen'**
  String get privacy5Title;

  /// No description provided for @privacy5Body.
  ///
  /// In de, this message translates to:
  /// **'Erinnerungen sind lokale Benachrichtigungen. Sie zeigen nie Titel, Ort oder Notiz, nur „Termin in …“. Es gibt keinen Push-Dienst eines Dritten.'**
  String get privacy5Body;

  /// No description provided for @privacy6Title.
  ///
  /// In de, this message translates to:
  /// **'Berechtigungen'**
  String get privacy6Title;

  /// No description provided for @privacy6Body.
  ///
  /// In de, this message translates to:
  /// **'Internet (Verbindung zum Server), Benachrichtigungen und genaue Alarme (Erinnerungen), Neustart-Meldung (Erinnerungen neu planen) und Geräteanmeldung (App-Sperre). Es werden keine Kontakte, kein Standort, keine Kamera und kein Mikrofon benötigt.'**
  String get privacy6Body;

  /// No description provided for @privacy7Title.
  ///
  /// In de, this message translates to:
  /// **'Sicherung und Löschung'**
  String get privacy7Title;

  /// No description provided for @privacy7Body.
  ///
  /// In de, this message translates to:
  /// **'Android-Backups sind ausgeschaltet. Speicherst du einen Anhang bewusst über „Speichern“, liegt die entschlüsselte Datei außerhalb der App in dem von dir gewählten Ordner. Mit „Alle lokalen Daten löschen“ entfernst du alle Daten, Schlüssel und Erinnerungen von diesem Gerät. Mit „Konto löschen“ (Einstellungen → Konto) löschst du dein Konto dauerhaft beim Anbieter und danach alle Daten auf diesem Gerät; bei Anbietern mit Anmeldung im Browser (z. B. matrix.org) bestätigst du die Löschung auf dessen Seite. Nachrichten auf Geräten anderer Mitglieder lassen sich technisch nicht erzwungen löschen. Dein Notfall-Schlüssel ist das einzige Mittel, Nachrichten nach Verlust aller Geräte zu retten – bewahre ihn sicher auf. Kopierst du ihn, wird die Zwischenablage nach einer Minute geleert; speicherst du ihn als Datei, liegt er unverschlüsselt an dem von dir gewählten Ort.'**
  String get privacy7Body;

  /// No description provided for @privacy8Title.
  ///
  /// In de, this message translates to:
  /// **'Kinder'**
  String get privacy8Title;

  /// No description provided for @privacy8Body.
  ///
  /// In de, this message translates to:
  /// **'Kinder können Familienmitglieder sein. Dafür ist die Einwilligung der Sorgeberechtigten nötig; Konten Minderjähriger laufen über die Einladung und Bestätigung eines Moderators.'**
  String get privacy8Body;

  /// No description provided for @privacy9Title.
  ///
  /// In de, this message translates to:
  /// **'Deine Rechte'**
  String get privacy9Title;

  /// No description provided for @privacy9Body.
  ///
  /// In de, this message translates to:
  /// **'Du kannst jederzeit Auskunft, Berichtigung und Löschung verlangen. Lokale Daten verwaltest du in dieser App, dein Konto löschst du unter Einstellungen → Konto → „Konto löschen“; weitere Serverdaten beim Betreiber deines Servers.'**
  String get privacy9Body;

  /// No description provided for @familyRequestCheckValid.
  ///
  /// In de, this message translates to:
  /// **'Gültiger Einladungslink'**
  String get familyRequestCheckValid;

  /// No description provided for @familyRequestCheckExpired.
  ///
  /// In de, this message translates to:
  /// **'Link abgelaufen'**
  String get familyRequestCheckExpired;

  /// No description provided for @familyRequestCheckUnknown.
  ///
  /// In de, this message translates to:
  /// **'Unbekannter Link – von keinem Moderator ausgegeben'**
  String get familyRequestCheckUnknown;

  /// No description provided for @familyRequestApproveConfirm.
  ///
  /// In de, this message translates to:
  /// **'{user} in die Familie aufnehmen? Der Einladungslink wird dabei verbraucht.'**
  String familyRequestApproveConfirm(String user);

  /// No description provided for @identityVerified.
  ///
  /// In de, this message translates to:
  /// **'Verifiziert'**
  String get identityVerified;

  /// No description provided for @identityPinned.
  ///
  /// In de, this message translates to:
  /// **'Nicht persönlich geprüft'**
  String get identityPinned;

  /// No description provided for @identityUnknown.
  ///
  /// In de, this message translates to:
  /// **'Keine Schlüssel bekannt'**
  String get identityUnknown;

  /// No description provided for @identityChanged.
  ///
  /// In de, this message translates to:
  /// **'Identität geändert'**
  String get identityChanged;

  /// No description provided for @identityChangedWarning.
  ///
  /// In de, this message translates to:
  /// **'Der Sicherheitsschlüssel von {name} hat sich geändert. Seine Geräte sind gesperrt, bis ihr euch persönlich per Emoji-Vergleich geprüft habt.'**
  String identityChangedWarning(String name);

  /// No description provided for @identityAccept.
  ///
  /// In de, this message translates to:
  /// **'Änderung akzeptieren'**
  String get identityAccept;

  /// No description provided for @identityAcceptConfirm.
  ///
  /// In de, this message translates to:
  /// **'Erst akzeptieren, wenn ihr euch persönlich (z. B. per Emoji-Vergleich) geprüft habt. Fortfahren?'**
  String get identityAcceptConfirm;

  /// No description provided for @invitationUnexpectedWarning.
  ///
  /// In de, this message translates to:
  /// **'Diese Einladung gehört zu keiner Beitrittsanfrage von dir. Nimm sie nur an, wenn du {inviter} kennst und die Einladung erwartet hast.'**
  String invitationUnexpectedWarning(String inviter);

  /// No description provided for @memberActionsTooltip.
  ///
  /// In de, this message translates to:
  /// **'Aktionen für {name}'**
  String memberActionsTooltip(String name);

  /// No description provided for @familyInviteConfirm.
  ///
  /// In de, this message translates to:
  /// **'{user} einladen? Eingeladene erhalten bereits vor der Annahme die Nachrichtenschlüssel der Familie – lade nur Personen ein, die du sicher kennst.'**
  String familyInviteConfirm(String user);

  /// No description provided for @attachmentSaveWarning.
  ///
  /// In de, this message translates to:
  /// **'Die Datei wird entschlüsselt und unverschlüsselt im gewählten Ordner gespeichert. Sie bleibt dort auch nach dem Abmelden oder Löschen der App-Daten erhalten. Fortfahren?'**
  String get attachmentSaveWarning;

  /// No description provided for @tabShopping.
  ///
  /// In de, this message translates to:
  /// **'Einkauf'**
  String get tabShopping;

  /// No description provided for @settingsShareOnlineStatus.
  ///
  /// In de, this message translates to:
  /// **'Online-Status teilen'**
  String get settingsShareOnlineStatus;

  /// No description provided for @settingsShareOnlineStatusHint.
  ///
  /// In de, this message translates to:
  /// **'Zeigt der Familie, wann du die App nutzt. Die Meldung geht nur Ende-zu-Ende-verschlüsselt an Geräte von Familienmitgliedern. Ausgeschaltet giltst du für andere als offline.'**
  String get settingsShareOnlineStatusHint;

  /// No description provided for @presenceOnline.
  ///
  /// In de, this message translates to:
  /// **'Online'**
  String get presenceOnline;

  /// No description provided for @presenceOffline.
  ///
  /// In de, this message translates to:
  /// **'Offline'**
  String get presenceOffline;

  /// No description provided for @presenceUnknown.
  ///
  /// In de, this message translates to:
  /// **'Status unbekannt'**
  String get presenceUnknown;

  /// No description provided for @presenceLastSeen.
  ///
  /// In de, this message translates to:
  /// **'Zuletzt online {ago}'**
  String presenceLastSeen(String ago);

  /// No description provided for @presenceAgoNow.
  ///
  /// In de, this message translates to:
  /// **'gerade eben'**
  String get presenceAgoNow;

  /// No description provided for @presenceAgoMinutes.
  ///
  /// In de, this message translates to:
  /// **'vor {count} Min.'**
  String presenceAgoMinutes(int count);

  /// No description provided for @presenceAgoHours.
  ///
  /// In de, this message translates to:
  /// **'vor {count} Std.'**
  String presenceAgoHours(int count);

  /// No description provided for @presenceAgoDays.
  ///
  /// In de, this message translates to:
  /// **'vor {count} Tg.'**
  String presenceAgoDays(int count);

  /// No description provided for @presenceSelfHidden.
  ///
  /// In de, this message translates to:
  /// **'Dein Status wird nicht geteilt'**
  String get presenceSelfHidden;

  /// No description provided for @presenceSelf.
  ///
  /// In de, this message translates to:
  /// **'Du bist online'**
  String get presenceSelf;

  /// No description provided for @presenceOf.
  ///
  /// In de, this message translates to:
  /// **'{name}: {status}'**
  String presenceOf(String name, String status);

  /// No description provided for @chatThreads.
  ///
  /// In de, this message translates to:
  /// **'Gespräche'**
  String get chatThreads;

  /// No description provided for @chatThreadFamily.
  ///
  /// In de, this message translates to:
  /// **'Familienchat {name}'**
  String chatThreadFamily(String name);

  /// No description provided for @chatThreadDirect.
  ///
  /// In de, this message translates to:
  /// **'Einzelchat mit {name}'**
  String chatThreadDirect(String name);

  /// No description provided for @chatUnreadCount.
  ///
  /// In de, this message translates to:
  /// **'{count} ungelesen'**
  String chatUnreadCount(int count);

  /// No description provided for @chatDirectNote.
  ///
  /// In de, this message translates to:
  /// **'Nur zwischen dir und {name}, Ende-zu-Ende-verschlüsselt'**
  String chatDirectNote(String name);

  /// No description provided for @chatDirectNotAvailable.
  ///
  /// In de, this message translates to:
  /// **'Dieses Gespräch ist nicht mehr verfügbar.'**
  String get chatDirectNotAvailable;

  /// No description provided for @familyWriteMessage.
  ///
  /// In de, this message translates to:
  /// **'Nachricht schreiben'**
  String get familyWriteMessage;

  /// No description provided for @shoppingTitle.
  ///
  /// In de, this message translates to:
  /// **'Einkaufszettel'**
  String get shoppingTitle;

  /// No description provided for @shoppingNote.
  ///
  /// In de, this message translates to:
  /// **'Gemeinsam mit der Familie, Ende-zu-Ende-verschlüsselt'**
  String get shoppingNote;

  /// No description provided for @shoppingHintItem.
  ///
  /// In de, this message translates to:
  /// **'Was wird gebraucht?'**
  String get shoppingHintItem;

  /// No description provided for @shoppingHintQuantity.
  ///
  /// In de, this message translates to:
  /// **'Menge (optional)'**
  String get shoppingHintQuantity;

  /// No description provided for @shoppingAdd.
  ///
  /// In de, this message translates to:
  /// **'Hinzufügen'**
  String get shoppingAdd;

  /// No description provided for @shoppingEmpty.
  ///
  /// In de, this message translates to:
  /// **'Der Einkaufszettel ist leer. Füge oben etwas hinzu.'**
  String get shoppingEmpty;

  /// No description provided for @shoppingOpenHeader.
  ///
  /// In de, this message translates to:
  /// **'Zu besorgen ({count})'**
  String shoppingOpenHeader(int count);

  /// No description provided for @shoppingDoneHeader.
  ///
  /// In de, this message translates to:
  /// **'Erledigt ({count})'**
  String shoppingDoneHeader(int count);

  /// No description provided for @shoppingClearDone.
  ///
  /// In de, this message translates to:
  /// **'Erledigte entfernen'**
  String get shoppingClearDone;

  /// No description provided for @shoppingClearConfirm.
  ///
  /// In de, this message translates to:
  /// **'{count} erledigte Einträge für die ganze Familie entfernen?'**
  String shoppingClearConfirm(int count);

  /// No description provided for @shoppingCleared.
  ///
  /// In de, this message translates to:
  /// **'{count} Einträge entfernt'**
  String shoppingCleared(int count);

  /// No description provided for @shoppingEditTitle.
  ///
  /// In de, this message translates to:
  /// **'Eintrag bearbeiten'**
  String get shoppingEditTitle;

  /// No description provided for @shoppingEdit.
  ///
  /// In de, this message translates to:
  /// **'Bearbeiten'**
  String get shoppingEdit;

  /// No description provided for @shoppingDelete.
  ///
  /// In de, this message translates to:
  /// **'Löschen'**
  String get shoppingDelete;

  /// No description provided for @shoppingMarkDone.
  ///
  /// In de, this message translates to:
  /// **'{name} als erledigt markieren'**
  String shoppingMarkDone(String name);

  /// No description provided for @shoppingMarkOpen.
  ///
  /// In de, this message translates to:
  /// **'{name} wieder auf die Liste setzen'**
  String shoppingMarkOpen(String name);

  /// No description provided for @shoppingLastBy.
  ///
  /// In de, this message translates to:
  /// **'zuletzt von {name}'**
  String shoppingLastBy(String name);

  /// No description provided for @shoppingLimit.
  ///
  /// In de, this message translates to:
  /// **'Der Einkaufszettel ist voll (höchstens 300 Einträge). Entferne erledigte Einträge.'**
  String get shoppingLimit;

  /// No description provided for @shoppingInvalid.
  ///
  /// In de, this message translates to:
  /// **'Dieser Eintrag ist ungültig (leer, zu lang oder mit unzulässigen Zeichen).'**
  String get shoppingInvalid;

  /// No description provided for @todayOnlineHeader.
  ///
  /// In de, this message translates to:
  /// **'Wer ist online'**
  String get todayOnlineHeader;

  /// No description provided for @todayNobodyOnline.
  ///
  /// In de, this message translates to:
  /// **'Gerade ist sonst niemand online.'**
  String get todayNobodyOnline;

  /// No description provided for @todayShoppingOpen.
  ///
  /// In de, this message translates to:
  /// **'Einkaufszettel: {count} offen'**
  String todayShoppingOpen(int count);

  /// No description provided for @privacy10Title.
  ///
  /// In de, this message translates to:
  /// **'Online-Status, Einzelchats, Einkaufszettel'**
  String get privacy10Title;

  /// No description provided for @privacy10Body.
  ///
  /// In de, this message translates to:
  /// **'Der Online-Status („online“ oder „offline“ mit Zeitpunkt) wird nur als Ende-zu-Ende-verschlüsselte Gerätenachricht an Geräte beigetretener Familienmitglieder gesendet und nie gespeichert; du kannst ihn in den Einstellungen ausschalten. Einzelchats sind verschlüsselte Räume zwischen zwei Familienmitgliedern. Der Einkaufszettel wird wie geteilte Termine verschlüsselt im Familienraum übertragen und liegt verschlüsselt auf deinem Gerät; alle Familienmitglieder können ihn ändern. Der Server sieht nur Metadaten wie Zeitpunkte und Größe.'**
  String get privacy10Body;

  /// No description provided for @onbFamilyFound.
  ///
  /// In de, this message translates to:
  /// **'Familie „{name}“ gefunden – du bist bereits Mitglied. Die Einrichtung wird abgeschlossen.'**
  String onbFamilyFound(String name);

  /// No description provided for @settingsAccent.
  ///
  /// In de, this message translates to:
  /// **'Akzentfarbe'**
  String get settingsAccent;

  /// No description provided for @settingsAccentHint.
  ///
  /// In de, this message translates to:
  /// **'Neonfarbe für Schaltflächen, Auswahl und Hervorhebungen. Gilt im hellen und im dunklen Design.'**
  String get settingsAccentHint;

  /// No description provided for @accentTeal.
  ///
  /// In de, this message translates to:
  /// **'Türkis'**
  String get accentTeal;

  /// No description provided for @accentMagenta.
  ///
  /// In de, this message translates to:
  /// **'Magenta'**
  String get accentMagenta;

  /// No description provided for @accentViolet.
  ///
  /// In de, this message translates to:
  /// **'Violett'**
  String get accentViolet;

  /// No description provided for @accentSky.
  ///
  /// In de, this message translates to:
  /// **'Himmelblau'**
  String get accentSky;

  /// No description provided for @accentLime.
  ///
  /// In de, this message translates to:
  /// **'Limette'**
  String get accentLime;

  /// No description provided for @accentOrange.
  ///
  /// In de, this message translates to:
  /// **'Orange'**
  String get accentOrange;

  /// No description provided for @accentRose.
  ///
  /// In de, this message translates to:
  /// **'Rosé'**
  String get accentRose;

  /// No description provided for @accentGreen.
  ///
  /// In de, this message translates to:
  /// **'Grün'**
  String get accentGreen;

  /// No description provided for @menuOpen.
  ///
  /// In de, this message translates to:
  /// **'Menü öffnen'**
  String get menuOpen;

  /// No description provided for @menuVersion.
  ///
  /// In de, this message translates to:
  /// **'Version {version}'**
  String menuVersion(String version);

  /// No description provided for @menuTitle.
  ///
  /// In de, this message translates to:
  /// **'Menü'**
  String get menuTitle;

  /// No description provided for @chatReport.
  ///
  /// In de, this message translates to:
  /// **'Nachricht melden'**
  String get chatReport;

  /// No description provided for @chatBlockSender.
  ///
  /// In de, this message translates to:
  /// **'{name} blockieren'**
  String chatBlockSender(String name);

  /// No description provided for @reportTitle.
  ///
  /// In de, this message translates to:
  /// **'Nachricht melden'**
  String get reportTitle;

  /// No description provided for @reportIntro.
  ///
  /// In de, this message translates to:
  /// **'Die Meldung geht an den Betreiber deines Servers ({server}). Er kann den verschlüsselten Inhalt nicht lesen. Übertragen werden die Kennung der Nachricht, der gewählte Grund und dein optionaler Text – dieser Text ist für den Betreiber lesbar.'**
  String reportIntro(String server);

  /// No description provided for @reportCategorySpam.
  ///
  /// In de, this message translates to:
  /// **'Spam oder Werbung'**
  String get reportCategorySpam;

  /// No description provided for @reportCategoryHarassment.
  ///
  /// In de, this message translates to:
  /// **'Belästigung oder Beleidigung'**
  String get reportCategoryHarassment;

  /// No description provided for @reportCategoryInappropriate.
  ///
  /// In de, this message translates to:
  /// **'Unangemessener Inhalt'**
  String get reportCategoryInappropriate;

  /// No description provided for @reportCategoryOther.
  ///
  /// In de, this message translates to:
  /// **'Anderer Grund'**
  String get reportCategoryOther;

  /// No description provided for @reportDetailsHint.
  ///
  /// In de, this message translates to:
  /// **'Optional: Was ist passiert?'**
  String get reportDetailsHint;

  /// No description provided for @reportSend.
  ///
  /// In de, this message translates to:
  /// **'Melden'**
  String get reportSend;

  /// No description provided for @reportDone.
  ///
  /// In de, this message translates to:
  /// **'Meldung gesendet.'**
  String get reportDone;

  /// No description provided for @reportBlockOffer.
  ///
  /// In de, this message translates to:
  /// **'Absender blockieren'**
  String get reportBlockOffer;

  /// No description provided for @blockConfirmTitle.
  ///
  /// In de, this message translates to:
  /// **'{name} blockieren?'**
  String blockConfirmTitle(String name);

  /// No description provided for @blockConfirmBody.
  ///
  /// In de, this message translates to:
  /// **'Nachrichten und der Einzelchat von {name} werden auf diesem Gerät ausgeblendet. {name} erfährt davon nichts und bleibt Mitglied der Familie. Du kannst die Blockierung jederzeit in den Einstellungen aufheben.'**
  String blockConfirmBody(String name);

  /// No description provided for @blockConfirmAction.
  ///
  /// In de, this message translates to:
  /// **'Blockieren'**
  String get blockConfirmAction;

  /// No description provided for @blockDone.
  ///
  /// In de, this message translates to:
  /// **'{name} ist blockiert.'**
  String blockDone(String name);

  /// No description provided for @unblockAction.
  ///
  /// In de, this message translates to:
  /// **'Blockierung aufheben'**
  String get unblockAction;

  /// No description provided for @unblockDone.
  ///
  /// In de, this message translates to:
  /// **'Blockierung von {name} aufgehoben.'**
  String unblockDone(String name);

  /// No description provided for @memberBlockedBadge.
  ///
  /// In de, this message translates to:
  /// **'Blockiert'**
  String get memberBlockedBadge;

  /// No description provided for @settingsBlockedUsers.
  ///
  /// In de, this message translates to:
  /// **'Blockierte Mitglieder'**
  String get settingsBlockedUsers;

  /// No description provided for @settingsBlockedUsersHint.
  ///
  /// In de, this message translates to:
  /// **'Nachrichten blockierter Mitglieder werden ausgeblendet.'**
  String get settingsBlockedUsersHint;

  /// No description provided for @blockedUsersEmpty.
  ///
  /// In de, this message translates to:
  /// **'Du hast niemanden blockiert.'**
  String get blockedUsersEmpty;

  /// No description provided for @privacy11Title.
  ///
  /// In de, this message translates to:
  /// **'Melden und Blockieren'**
  String get privacy11Title;

  /// No description provided for @privacy11Body.
  ///
  /// In de, this message translates to:
  /// **'Blockierte Mitglieder merkt sich die App nur auf diesem Gerät (verschlüsselte Datenbank); sie werden nicht übertragen. Meldest du eine Nachricht, erhält der Betreiber deines Servers die Kennung der Nachricht, den gewählten Grund und deinen optionalen Text. Den verschlüsselten Inhalt kann er nicht lesen.'**
  String get privacy11Body;

  /// No description provided for @familyInviteMail.
  ///
  /// In de, this message translates to:
  /// **'Per E-Mail senden'**
  String get familyInviteMail;

  /// No description provided for @inviteMailSubject.
  ///
  /// In de, this message translates to:
  /// **'Einladung zu FamilyNexus'**
  String get inviteMailSubject;

  /// No description provided for @inviteMailBody.
  ///
  /// In de, this message translates to:
  /// **'Hallo,\n\nich lade dich in unsere Familie „{family}“ bei FamilyNexus ein – Familienkalender und Chat, privat und verschlüsselt.\n\nSo geht’s (ca. 2 Minuten):\n1. Installiere die App FamilyNexus.\n2. Tippe auf diesen Link – oder öffne die App, wähle „Ich wurde eingeladen“ und füge den Link ein:\n\n{link}\n\n3. Lege dein Konto an.\n4. Sobald die App eines Moderators online ist, wirst du automatisch aufgenommen.\n\nDer Link ist {validity} gültig.'**
  String inviteMailBody(String family, String link, String validity);

  /// No description provided for @familyInviteMailFailed.
  ///
  /// In de, this message translates to:
  /// **'Kein Mailprogramm gefunden. Der Link wurde stattdessen kopiert.'**
  String get familyInviteMailFailed;

  /// No description provided for @onbInvitedTitle.
  ///
  /// In de, this message translates to:
  /// **'Du wurdest eingeladen'**
  String get onbInvitedTitle;

  /// No description provided for @onbInvitedJoin.
  ///
  /// In de, this message translates to:
  /// **'„{family}“ beitreten'**
  String onbInvitedJoin(String family);

  /// No description provided for @onbInvitedOther.
  ///
  /// In de, this message translates to:
  /// **'Stattdessen eine andere Familie gründen oder beitreten'**
  String get onbInvitedOther;

  /// No description provided for @tasksTitle.
  ///
  /// In de, this message translates to:
  /// **'Aufgaben'**
  String get tasksTitle;

  /// No description provided for @tasksNote.
  ///
  /// In de, this message translates to:
  /// **'Nur Moderatoren legen Listen an. Abhaken kann nur die zugewiesene Person.'**
  String get tasksNote;

  /// No description provided for @tasksEmpty.
  ///
  /// In de, this message translates to:
  /// **'Noch keine Aufgabenlisten.'**
  String get tasksEmpty;

  /// No description provided for @tasksSectionMine.
  ///
  /// In de, this message translates to:
  /// **'Mir zugewiesen'**
  String get tasksSectionMine;

  /// No description provided for @tasksSectionOthers.
  ///
  /// In de, this message translates to:
  /// **'Weitere Listen'**
  String get tasksSectionOthers;

  /// No description provided for @tasksNew.
  ///
  /// In de, this message translates to:
  /// **'Neue Aufgabenliste'**
  String get tasksNew;

  /// No description provided for @tasksEditTitle.
  ///
  /// In de, this message translates to:
  /// **'Aufgabenliste bearbeiten'**
  String get tasksEditTitle;

  /// No description provided for @tasksFieldTitle.
  ///
  /// In de, this message translates to:
  /// **'Titel'**
  String get tasksFieldTitle;

  /// No description provided for @tasksFieldAssignee.
  ///
  /// In de, this message translates to:
  /// **'Zugewiesen an'**
  String get tasksFieldAssignee;

  /// No description provided for @tasksFieldInterval.
  ///
  /// In de, this message translates to:
  /// **'Wiederholung'**
  String get tasksFieldInterval;

  /// No description provided for @tasksFieldItems.
  ///
  /// In de, this message translates to:
  /// **'Punkte (einer pro Zeile)'**
  String get tasksFieldItems;

  /// No description provided for @tasksIntervalDaily.
  ///
  /// In de, this message translates to:
  /// **'Täglich'**
  String get tasksIntervalDaily;

  /// No description provided for @tasksIntervalWeekly.
  ///
  /// In de, this message translates to:
  /// **'Wöchentlich'**
  String get tasksIntervalWeekly;

  /// No description provided for @tasksIntervalMonthly.
  ///
  /// In de, this message translates to:
  /// **'Monatlich'**
  String get tasksIntervalMonthly;

  /// No description provided for @tasksResetDaily.
  ///
  /// In de, this message translates to:
  /// **'Startet jeden Tag um Mitternacht neu'**
  String get tasksResetDaily;

  /// No description provided for @tasksAssignedTo.
  ///
  /// In de, this message translates to:
  /// **'Zugewiesen an {name}'**
  String tasksAssignedTo(String name);

  /// No description provided for @tasksProgress.
  ///
  /// In de, this message translates to:
  /// **'{done} von {total} erledigt'**
  String tasksProgress(int done, int total);

  /// No description provided for @tasksDelete.
  ///
  /// In de, this message translates to:
  /// **'Liste löschen'**
  String get tasksDelete;

  /// No description provided for @tasksDeleteConfirm.
  ///
  /// In de, this message translates to:
  /// **'Liste „{title}“ löschen?'**
  String tasksDeleteConfirm(String title);

  /// No description provided for @tasksMarkDone.
  ///
  /// In de, this message translates to:
  /// **'{item} als erledigt markieren'**
  String tasksMarkDone(String item);

  /// No description provided for @tasksMarkUndone.
  ///
  /// In de, this message translates to:
  /// **'Erledigung von {item} zurücknehmen'**
  String tasksMarkUndone(String item);

  /// No description provided for @tasksCommentTitle.
  ///
  /// In de, this message translates to:
  /// **'Erledigt'**
  String get tasksCommentTitle;

  /// No description provided for @tasksCommentHint.
  ///
  /// In de, this message translates to:
  /// **'Kommentar (optional)'**
  String get tasksCommentHint;

  /// No description provided for @tasksConfirmDone.
  ///
  /// In de, this message translates to:
  /// **'Erledigt'**
  String get tasksConfirmDone;

  /// No description provided for @tasksDoneOn.
  ///
  /// In de, this message translates to:
  /// **'Erledigt am {date} um {time}'**
  String tasksDoneOn(String date, String time);

  /// No description provided for @tasksHistory.
  ///
  /// In de, this message translates to:
  /// **'Verlauf'**
  String get tasksHistory;

  /// No description provided for @tasksHistoryEmpty.
  ///
  /// In de, this message translates to:
  /// **'Noch keine Einträge.'**
  String get tasksHistoryEmpty;

  /// No description provided for @tasksHistoryDone.
  ///
  /// In de, this message translates to:
  /// **'{item} erledigt'**
  String tasksHistoryDone(String item);

  /// No description provided for @tasksHistoryUndone.
  ///
  /// In de, this message translates to:
  /// **'{item} zurückgenommen'**
  String tasksHistoryUndone(String item);

  /// No description provided for @tasksHistoryLine.
  ///
  /// In de, this message translates to:
  /// **'{name} · {date}, {time}'**
  String tasksHistoryLine(String name, String date, String time);

  /// No description provided for @tasksInvalid.
  ///
  /// In de, this message translates to:
  /// **'Bitte Titel, Person und mindestens einen Punkt angeben.'**
  String get tasksInvalid;

  /// No description provided for @tasksLimit.
  ///
  /// In de, this message translates to:
  /// **'Grenze erreicht: zu viele Aufgabenlisten, Punkte oder Einträge.'**
  String get tasksLimit;

  /// No description provided for @todayTasksOpen.
  ///
  /// In de, this message translates to:
  /// **'Aufgaben für dich: {count} offen'**
  String todayTasksOpen(int count);

  /// No description provided for @privacy12Title.
  ///
  /// In de, this message translates to:
  /// **'Aufgabenlisten'**
  String get privacy12Title;

  /// No description provided for @privacy12Body.
  ///
  /// In de, this message translates to:
  /// **'Aufgabenlisten und ihr Verlauf (wer wann welchen Punkt erledigt hat, inkl. optionalem Kommentar) werden wie geteilte Termine Ende-zu-Ende-verschlüsselt im Familienraum übertragen und liegen verschlüsselt auf deinem Gerät. Alle Familienmitglieder können sie lesen. Der Server sieht nur Metadaten wie Zeitpunkte und Größe.'**
  String get privacy12Body;

  /// No description provided for @webUnlockTitleCreate.
  ///
  /// In de, this message translates to:
  /// **'Browser-Tresor einrichten'**
  String get webUnlockTitleCreate;

  /// No description provided for @webUnlockBodyCreate.
  ///
  /// In de, this message translates to:
  /// **'Dieser Browser speichert deine Daten verschlüsselt. Wähle dafür ein Passwort. Es wird nirgends gespeichert und kann nicht wiederhergestellt werden; wer es vergisst, kann nur alle lokalen Daten löschen und sich neu anmelden.'**
  String get webUnlockBodyCreate;

  /// No description provided for @webUnlockTitle.
  ///
  /// In de, this message translates to:
  /// **'FamilyNexus entsperren'**
  String get webUnlockTitle;

  /// No description provided for @webUnlockBody.
  ///
  /// In de, this message translates to:
  /// **'Gib das Passwort für diesen Browser ein.'**
  String get webUnlockBody;

  /// No description provided for @webPassword.
  ///
  /// In de, this message translates to:
  /// **'Passwort'**
  String get webPassword;

  /// No description provided for @webPasswordRepeat.
  ///
  /// In de, this message translates to:
  /// **'Passwort wiederholen'**
  String get webPasswordRepeat;

  /// No description provided for @webPasswordTooShort.
  ///
  /// In de, this message translates to:
  /// **'Mindestens 10 Zeichen.'**
  String get webPasswordTooShort;

  /// No description provided for @webPasswordMismatch.
  ///
  /// In de, this message translates to:
  /// **'Die Passwörter stimmen nicht überein.'**
  String get webPasswordMismatch;

  /// No description provided for @webPasswordWrong.
  ///
  /// In de, this message translates to:
  /// **'Falsches Passwort.'**
  String get webPasswordWrong;

  /// No description provided for @webUnlockAction.
  ///
  /// In de, this message translates to:
  /// **'Entsperren'**
  String get webUnlockAction;

  /// No description provided for @webCreateAction.
  ///
  /// In de, this message translates to:
  /// **'Tresor anlegen'**
  String get webCreateAction;

  /// No description provided for @webUnlockBusy.
  ///
  /// In de, this message translates to:
  /// **'Wird entsperrt …'**
  String get webUnlockBusy;

  /// No description provided for @webForgotPassword.
  ///
  /// In de, this message translates to:
  /// **'Passwort vergessen? Alle lokalen Daten löschen'**
  String get webForgotPassword;

  /// No description provided for @webTabBusyTitle.
  ///
  /// In de, this message translates to:
  /// **'FamilyNexus ist schon geöffnet'**
  String get webTabBusyTitle;

  /// No description provided for @webTabBusyBody.
  ///
  /// In de, this message translates to:
  /// **'Die App läuft bereits in einem anderen Tab oder Fenster dieses Browsers. Zwei Tabs gleichzeitig würden die lokalen Daten beschädigen. Schließe den anderen Tab und versuche es erneut.'**
  String get webTabBusyBody;

  /// No description provided for @privacy13Title.
  ///
  /// In de, this message translates to:
  /// **'Browser-Version'**
  String get privacy13Title;

  /// No description provided for @privacy13Body.
  ///
  /// In de, this message translates to:
  /// **'In der Web-Version liegen deine Daten verschlüsselt im Speicher dieses Browsers (IndexedDB, SQLite3MultipleCiphers). Der Schlüssel dafür ist mit deinem Browser-Passwort geschützt, das nirgends gespeichert wird. Es gibt keinen Bildschirmschutz und keine Erinnerungen bei geschlossener Seite. Auf einem fremden oder gemeinsam genutzten Rechner solltest du die Web-Version nicht verwenden. Die Seite lädt nichts von Drittanbietern nach.'**
  String get privacy13Body;

  /// No description provided for @startCreateTitle.
  ///
  /// In de, this message translates to:
  /// **'Neue Familie gründen'**
  String get startCreateTitle;

  /// No description provided for @startCreateBody.
  ///
  /// In de, this message translates to:
  /// **'Du richtest alles ein und lädst deine Familie danach ein.'**
  String get startCreateBody;

  /// No description provided for @startInvitedTitle.
  ///
  /// In de, this message translates to:
  /// **'Ich wurde eingeladen'**
  String get startInvitedTitle;

  /// No description provided for @startInvitedBody.
  ///
  /// In de, this message translates to:
  /// **'Du hast einen Link oder QR-Code bekommen.'**
  String get startInvitedBody;

  /// No description provided for @startLoginTitle.
  ///
  /// In de, this message translates to:
  /// **'Ich habe schon ein Konto'**
  String get startLoginTitle;

  /// No description provided for @startLoginBody.
  ///
  /// In de, this message translates to:
  /// **'Du nutzt FamilyNexus schon, z. B. auf einem anderen Gerät.'**
  String get startLoginBody;

  /// No description provided for @startHaveAccount.
  ///
  /// In de, this message translates to:
  /// **'Ich habe schon ein Konto'**
  String get startHaveAccount;

  /// No description provided for @regTitle.
  ///
  /// In de, this message translates to:
  /// **'Konto erstellen'**
  String get regTitle;

  /// No description provided for @regNameLabel.
  ///
  /// In de, this message translates to:
  /// **'Wie heißt du?'**
  String get regNameLabel;

  /// No description provided for @regNameHint.
  ///
  /// In de, this message translates to:
  /// **'z. B. Anna Müller'**
  String get regNameHint;

  /// No description provided for @regUsernameLabel.
  ///
  /// In de, this message translates to:
  /// **'Dein Benutzername'**
  String get regUsernameLabel;

  /// No description provided for @regUsernameHint.
  ///
  /// In de, this message translates to:
  /// **'Damit meldest du dich an. 3 bis 32 Zeichen: Kleinbuchstaben, Ziffern, Punkt, Unterstrich oder Bindestrich.'**
  String get regUsernameHint;

  /// No description provided for @regUsernameFree.
  ///
  /// In de, this message translates to:
  /// **'Der Benutzername ist frei.'**
  String get regUsernameFree;

  /// No description provided for @regUsernameTaken.
  ///
  /// In de, this message translates to:
  /// **'Dieser Benutzername ist schon vergeben.'**
  String get regUsernameTaken;

  /// No description provided for @regUsernameTakenSuggest.
  ///
  /// In de, this message translates to:
  /// **'Schon vergeben – wie wäre es mit „{suggestion}“?'**
  String regUsernameTakenSuggest(String suggestion);

  /// No description provided for @regUseSuggestion.
  ///
  /// In de, this message translates to:
  /// **'„{suggestion}“ verwenden'**
  String regUseSuggestion(String suggestion);

  /// No description provided for @regUsernameInvalid.
  ///
  /// In de, this message translates to:
  /// **'Bitte 3 bis 32 Zeichen: Kleinbuchstaben, Ziffern, Punkt, Unterstrich oder Bindestrich.'**
  String get regUsernameInvalid;

  /// No description provided for @regPasswordHint.
  ///
  /// In de, this message translates to:
  /// **'Mindestens 8 Zeichen. Mit Benutzername und Passwort meldest du dich später auch auf einem neuen Gerät an.'**
  String get regPasswordHint;

  /// No description provided for @passwordShow.
  ///
  /// In de, this message translates to:
  /// **'Passwort anzeigen'**
  String get passwordShow;

  /// No description provided for @passwordHide.
  ///
  /// In de, this message translates to:
  /// **'Passwort verbergen'**
  String get passwordHide;

  /// No description provided for @regCreate.
  ///
  /// In de, this message translates to:
  /// **'Konto erstellen'**
  String get regCreate;

  /// No description provided for @regCreating.
  ///
  /// In de, this message translates to:
  /// **'Erstelle Konto …'**
  String get regCreating;

  /// No description provided for @regExtraTitle.
  ///
  /// In de, this message translates to:
  /// **'Noch ein kurzer Schritt'**
  String get regExtraTitle;

  /// No description provided for @regTermsBody.
  ///
  /// In de, this message translates to:
  /// **'Der Anbieter möchte, dass du seinen Bedingungen zustimmst.'**
  String get regTermsBody;

  /// No description provided for @regTermsAgree.
  ///
  /// In de, this message translates to:
  /// **'Ich habe die Bedingungen gelesen und stimme zu.'**
  String get regTermsAgree;

  /// No description provided for @regEmailBody.
  ///
  /// In de, this message translates to:
  /// **'Gib deine E-Mail-Adresse ein. Der Anbieter schickt dir einen Bestätigungslink. Die Adresse geht nur an den Anbieter, nicht an uns.'**
  String get regEmailBody;

  /// No description provided for @regEmailLabel.
  ///
  /// In de, this message translates to:
  /// **'E-Mail-Adresse'**
  String get regEmailLabel;

  /// No description provided for @regEmailInvalid.
  ///
  /// In de, this message translates to:
  /// **'Bitte eine gültige E-Mail-Adresse eingeben.'**
  String get regEmailInvalid;

  /// No description provided for @regEmailSend.
  ///
  /// In de, this message translates to:
  /// **'Bestätigung senden'**
  String get regEmailSend;

  /// No description provided for @regEmailSent.
  ///
  /// In de, this message translates to:
  /// **'Der Anbieter hat eine E-Mail an {email} geschickt. Öffne sie und tippe auf den Link. Komm danach hierher zurück.'**
  String regEmailSent(String email);

  /// No description provided for @regEmailConfirmed.
  ///
  /// In de, this message translates to:
  /// **'Ich habe bestätigt'**
  String get regEmailConfirmed;

  /// No description provided for @regEmailResend.
  ///
  /// In de, this message translates to:
  /// **'E-Mail erneut senden'**
  String get regEmailResend;

  /// No description provided for @regEmailNotYet.
  ///
  /// In de, this message translates to:
  /// **'Noch nicht bestätigt. Bitte öffne den Link in der E-Mail (auch im Spam-Ordner nachsehen).'**
  String get regEmailNotYet;

  /// No description provided for @regTokenBody.
  ///
  /// In de, this message translates to:
  /// **'Dieser Anbieter gibt Konten nur mit einem Zugangscode frei. Du bekommst ihn vom Anbieter (nicht der Einladungslink der Familie).'**
  String get regTokenBody;

  /// No description provided for @regTokenLabel.
  ///
  /// In de, this message translates to:
  /// **'Zugangscode des Anbieters'**
  String get regTokenLabel;

  /// No description provided for @regTokenWrong.
  ///
  /// In de, this message translates to:
  /// **'Der Code passt nicht. Bitte prüfe ihn.'**
  String get regTokenWrong;

  /// No description provided for @regCaptchaBody.
  ///
  /// In de, this message translates to:
  /// **'Bitte bestätige im Browser kurz, dass du kein Roboter bist. Danach geht es hier automatisch weiter.'**
  String get regCaptchaBody;

  /// No description provided for @regCaptchaOpen.
  ///
  /// In de, this message translates to:
  /// **'Im Browser öffnen'**
  String get regCaptchaOpen;

  /// No description provided for @regCaptchaDone.
  ///
  /// In de, this message translates to:
  /// **'Ich bin fertig'**
  String get regCaptchaDone;

  /// No description provided for @regCaptchaNotYet.
  ///
  /// In de, this message translates to:
  /// **'Noch nicht abgeschlossen. Bitte beende die Bestätigung im Browser.'**
  String get regCaptchaNotYet;

  /// No description provided for @regOAuthIntro.
  ///
  /// In de, this message translates to:
  /// **'Bei {host} legst du dein Konto auf der Seite des Anbieters an. Danach kommst du automatisch hierher zurück.'**
  String regOAuthIntro(String host);

  /// No description provided for @regOAuthCreate.
  ///
  /// In de, this message translates to:
  /// **'Konto bei {host} erstellen'**
  String regOAuthCreate(String host);

  /// No description provided for @regExternalBody.
  ///
  /// In de, this message translates to:
  /// **'Bei {host} kann die App kein Konto anlegen. Erstelle es auf der Webseite des Anbieters und melde dich danach hier an.'**
  String regExternalBody(String host);

  /// No description provided for @regExternalOpen.
  ///
  /// In de, this message translates to:
  /// **'Webseite öffnen'**
  String get regExternalOpen;

  /// No description provided for @regExternalLogin.
  ///
  /// In de, this message translates to:
  /// **'Ich habe ein Konto – anmelden'**
  String get regExternalLogin;

  /// No description provided for @regElementOpen.
  ///
  /// In de, this message translates to:
  /// **'Element starten'**
  String get regElementOpen;

  /// No description provided for @regElementMissing.
  ///
  /// In de, this message translates to:
  /// **'Element ist nicht installiert. Du kannst es hier laden und dort ein Konto beim Server {host} anlegen. Danach hier „Ich habe ein Konto – anmelden“ wählen.'**
  String regElementMissing(String host);

  /// No description provided for @regElementDownload.
  ///
  /// In de, this message translates to:
  /// **'Element laden'**
  String get regElementDownload;

  /// No description provided for @familyRequestCheckCode.
  ///
  /// In de, this message translates to:
  /// **'Anfrage über den Familien-Code (ohne Link) – nur bestätigen, wenn du {id} kennst und erwartest'**
  String familyRequestCheckCode(String id);

  /// No description provided for @familyCodeTitle.
  ///
  /// In de, this message translates to:
  /// **'Familien-Code'**
  String get familyCodeTitle;

  /// No description provided for @familyCodeHint.
  ///
  /// In de, this message translates to:
  /// **'Wer dir ohne Link beitreten will, gibt diesen Code ein. Du musst die Anfrage danach ausdrücklich bestätigen.'**
  String get familyCodeHint;

  /// No description provided for @familyCodeCopy.
  ///
  /// In de, this message translates to:
  /// **'Code kopieren'**
  String get familyCodeCopy;

  /// No description provided for @familyCodeCopied.
  ///
  /// In de, this message translates to:
  /// **'Code kopiert'**
  String get familyCodeCopied;

  /// No description provided for @joinCodeTitle.
  ///
  /// In de, this message translates to:
  /// **'Ohne Link beitreten (Familien-Code)'**
  String get joinCodeTitle;

  /// No description provided for @joinCodeHint.
  ///
  /// In de, this message translates to:
  /// **'Frag einen Moderator nach dem Familien-Code. Er muss deine Anfrage bestätigen.'**
  String get joinCodeHint;

  /// No description provided for @joinCodeLabel.
  ///
  /// In de, this message translates to:
  /// **'Familien-Code'**
  String get joinCodeLabel;

  /// No description provided for @joinCodeInvalid.
  ///
  /// In de, this message translates to:
  /// **'Das ist kein gültiger Familien-Code. Er beginnt mit „!“ und enthält einen Server, z. B. !abc:matrix.org.'**
  String get joinCodeInvalid;

  /// No description provided for @joinRejected.
  ///
  /// In de, this message translates to:
  /// **'Deine Anfrage wurde abgelehnt. Frag bei der Familie nach, ob sie dich einladen möchte, und versuche es dann mit einem neuen Link.'**
  String get joinRejected;

  /// No description provided for @joinRejectedOk.
  ///
  /// In de, this message translates to:
  /// **'Verstanden'**
  String get joinRejectedOk;

  /// No description provided for @tabFamilyRequests.
  ///
  /// In de, this message translates to:
  /// **'Familie – {count} offene Anfragen'**
  String tabFamilyRequests(int count);

  /// No description provided for @familyInviteServerLabel.
  ///
  /// In de, this message translates to:
  /// **'Konto-Server für Neue'**
  String get familyInviteServerLabel;

  /// No description provided for @familyInviteServerHint.
  ///
  /// In de, this message translates to:
  /// **'Auf diesem Server legen Neulinge ihr Konto an und melden sich an. Leer lassen = dein Server. Der Familienraum bleibt, wo er ist.'**
  String get familyInviteServerHint;

  /// No description provided for @familyInviteServerApply.
  ///
  /// In de, this message translates to:
  /// **'Neuen Link erzeugen'**
  String get familyInviteServerApply;

  /// No description provided for @familyInviteServerInvalid.
  ///
  /// In de, this message translates to:
  /// **'Das ist keine gültige Server-Adresse.'**
  String get familyInviteServerInvalid;

  /// No description provided for @oauthWaiting.
  ///
  /// In de, this message translates to:
  /// **'Bitte im Browser bei {host} fortfahren … Danach geht es hier automatisch weiter.'**
  String oauthWaiting(String host);

  /// No description provided for @loginOAuthIntro.
  ///
  /// In de, this message translates to:
  /// **'Bei {host} meldest du dich auf der Seite des Anbieters an. Danach kommst du automatisch hierher zurück.'**
  String loginOAuthIntro(String host);

  /// No description provided for @loginOAuth.
  ///
  /// In de, this message translates to:
  /// **'Bei {host} anmelden'**
  String loginOAuth(String host);

  /// No description provided for @loginNoAccount.
  ///
  /// In de, this message translates to:
  /// **'Noch kein Konto? Jetzt erstellen'**
  String get loginNoAccount;

  /// No description provided for @advTitle.
  ///
  /// In de, this message translates to:
  /// **'Erweitert'**
  String get advTitle;

  /// No description provided for @advServerInfo.
  ///
  /// In de, this message translates to:
  /// **'Dein Konto liegt bei {host}.'**
  String advServerInfo(String host);

  /// No description provided for @advChecking.
  ///
  /// In de, this message translates to:
  /// **'Verbinde mit {host} …'**
  String advChecking(String host);

  /// No description provided for @advEnterProvider.
  ///
  /// In de, this message translates to:
  /// **'Bitte gib die Adresse des Anbieters ein.'**
  String get advEnterProvider;

  /// No description provided for @advUnreachable.
  ///
  /// In de, this message translates to:
  /// **'{host} ist gerade nicht erreichbar. Prüfe deine Internetverbindung.'**
  String advUnreachable(String host);

  /// No description provided for @advExplain.
  ///
  /// In de, this message translates to:
  /// **'FamilyNexus nutzt das offene Matrix-Netz. Dein Konto liegt bei einem Anbieter deiner Wahl – oder auf einem eigenen Server.'**
  String get advExplain;

  /// No description provided for @advStandardProvider.
  ///
  /// In de, this message translates to:
  /// **'{host} (empfohlen)'**
  String advStandardProvider(String host);

  /// No description provided for @advOtherProvider.
  ///
  /// In de, this message translates to:
  /// **'Anderen Anbieter verwenden'**
  String get advOtherProvider;

  /// No description provided for @advProviderLabel.
  ///
  /// In de, this message translates to:
  /// **'Adresse des Anbieters'**
  String get advProviderLabel;

  /// No description provided for @advProviderHint.
  ///
  /// In de, this message translates to:
  /// **'z. B. matrix.beispiel.de'**
  String get advProviderHint;

  /// No description provided for @keyTitle.
  ///
  /// In de, this message translates to:
  /// **'Dein Notfall-Schlüssel'**
  String get keyTitle;

  /// No description provided for @keyIntro.
  ///
  /// In de, this message translates to:
  /// **'Deine Nachrichten und Termine sind verschlüsselt. Damit du sie auch auf einem neuen Handy wieder öffnen kannst, bekommst du jetzt einen Notfall-Schlüssel – wie einen Ersatzschlüssel für die Haustür.'**
  String get keyIntro;

  /// No description provided for @keyCreate.
  ///
  /// In de, this message translates to:
  /// **'Notfall-Schlüssel erstellen'**
  String get keyCreate;

  /// No description provided for @keyCreating.
  ///
  /// In de, this message translates to:
  /// **'Erstelle …'**
  String get keyCreating;

  /// No description provided for @keyShownIntro.
  ///
  /// In de, this message translates to:
  /// **'Wenn du dein Handy verlierst, brauchst du diesen Schlüssel, um deine Nachrichten wiederzubekommen. Niemand sonst – auch wir nicht – kann ihn wiederherstellen. Er wird nur jetzt angezeigt.'**
  String get keyShownIntro;

  /// No description provided for @keyCopy.
  ///
  /// In de, this message translates to:
  /// **'Kopieren'**
  String get keyCopy;

  /// No description provided for @keyCopied.
  ///
  /// In de, this message translates to:
  /// **'Kopiert. Füge ihn z. B. in deinen Passwort-Manager ein. Die Zwischenablage wird nach einer Minute geleert.'**
  String get keyCopied;

  /// No description provided for @keySave.
  ///
  /// In de, this message translates to:
  /// **'Als Datei speichern'**
  String get keySave;

  /// No description provided for @keySavedFile.
  ///
  /// In de, this message translates to:
  /// **'Gespeichert. Bewahre die Datei sicher auf – am besten ausgedruckt.'**
  String get keySavedFile;

  /// No description provided for @keyPrintHint.
  ///
  /// In de, this message translates to:
  /// **'Tipp: Speichere die Datei und drucke sie aus – oder schreibe den Schlüssel auf Papier ab.'**
  String get keyPrintHint;

  /// No description provided for @keySavedCheck.
  ///
  /// In de, this message translates to:
  /// **'Ich habe den Notfall-Schlüssel sicher aufbewahrt.'**
  String get keySavedCheck;

  /// No description provided for @keyFileName.
  ///
  /// In de, this message translates to:
  /// **'FamilyNexus-Notfall-Schluessel.txt'**
  String get keyFileName;

  /// No description provided for @keyFileBody.
  ///
  /// In de, this message translates to:
  /// **'FamilyNexus – Notfall-Schlüssel\n\nKonto: {user}\nAnbieter: {provider}\nErstellt am: {date}\n\nNotfall-Schlüssel:\n{key}\n\nSo nutzt du ihn: Installiere FamilyNexus auf dem neuen Gerät, wähle „Ich habe schon ein Konto“, melde dich an und gib bei „Dieses Gerät freischalten“ den Notfall-Schlüssel ein.\n\nBewahre dieses Blatt sicher auf und gib es niemandem.'**
  String keyFileBody(String user, String provider, String key, String date);

  /// No description provided for @keyRestoreTitle.
  ///
  /// In de, this message translates to:
  /// **'Dieses Gerät freischalten'**
  String get keyRestoreTitle;

  /// No description provided for @keyRestoreIntro.
  ///
  /// In de, this message translates to:
  /// **'Dein Konto ist schon abgesichert. Schalte dieses Gerät frei – mit einem anderen Gerät, auf dem du angemeldet bist, oder mit deinem Notfall-Schlüssel.'**
  String get keyRestoreIntro;

  /// No description provided for @keyVerifyWithDevice.
  ///
  /// In de, this message translates to:
  /// **'Mit „{device}“ bestätigen'**
  String keyVerifyWithDevice(String device);

  /// No description provided for @keyNoOtherDevice.
  ///
  /// In de, this message translates to:
  /// **'Kein anderes Gerät gefunden. Nutze deinen Notfall-Schlüssel.'**
  String get keyNoOtherDevice;

  /// No description provided for @keyRestoreLabel.
  ///
  /// In de, this message translates to:
  /// **'Notfall-Schlüssel'**
  String get keyRestoreLabel;

  /// No description provided for @keyRestoreButton.
  ///
  /// In de, this message translates to:
  /// **'Freischalten'**
  String get keyRestoreButton;

  /// No description provided for @keyRestoring.
  ///
  /// In de, this message translates to:
  /// **'Schalte frei …'**
  String get keyRestoring;

  /// No description provided for @keyRestoreFailed.
  ///
  /// In de, this message translates to:
  /// **'Der Notfall-Schlüssel passt nicht. Bitte prüfe ihn noch einmal.'**
  String get keyRestoreFailed;

  /// No description provided for @keyRenewTitle.
  ///
  /// In de, this message translates to:
  /// **'Neuer Notfall-Schlüssel'**
  String get keyRenewTitle;

  /// No description provided for @keyRenewIntro.
  ///
  /// In de, this message translates to:
  /// **'Du hast deinen Notfall-Schlüssel verloren oder willst ihn ersetzen? Dann erstelle hier einen neuen. Der alte funktioniert danach nicht mehr – bewahre nur den neuen auf. Deine Nachrichten, Termine und Geräte bleiben, wie sie sind.'**
  String get keyRenewIntro;

  /// No description provided for @keyRenew.
  ///
  /// In de, this message translates to:
  /// **'Neuen Notfall-Schlüssel erstellen'**
  String get keyRenew;

  /// No description provided for @securityKeyRenewHint.
  ///
  /// In de, this message translates to:
  /// **'Falls du ihn verloren hast. Der alte gilt danach nicht mehr.'**
  String get securityKeyRenewHint;

  /// No description provided for @inviteStepTitle.
  ///
  /// In de, this message translates to:
  /// **'Einladung'**
  String get inviteStepTitle;

  /// No description provided for @inviteStepBody.
  ///
  /// In de, this message translates to:
  /// **'Füge den Einladungslink ein, den du bekommen hast. Hast du einen QR-Code? Scanne ihn mit der Kamera-App – FamilyNexus öffnet sich dann von selbst.'**
  String get inviteStepBody;

  /// No description provided for @inviteStepNoLink.
  ///
  /// In de, this message translates to:
  /// **'Kein Link? Bitte die Person, die dich einlädt, dir einen zu schicken.'**
  String get inviteStepNoLink;

  /// No description provided for @joinCardBody.
  ///
  /// In de, this message translates to:
  /// **'Du trittst der Familie „{family}“ bei. Eingeladen hat dich {inviter} (Konto bei {server}).'**
  String joinCardBody(String family, String inviter, String server);

  /// No description provided for @joinCardBodyNoName.
  ///
  /// In de, this message translates to:
  /// **'Du trittst einer Familie bei. Eingeladen hat dich {inviter} (Konto bei {server}).'**
  String joinCardBodyNoName(String inviter, String server);

  /// No description provided for @joinCardNote.
  ///
  /// In de, this message translates to:
  /// **'Angaben laut Einladung. Die App eines Moderators nimmt dich automatisch auf, sobald sie online ist.'**
  String joinCardNote(String inviter);

  /// No description provided for @joinCardDetails.
  ///
  /// In de, this message translates to:
  /// **'Details'**
  String get joinCardDetails;

  /// No description provided for @joinCardDetailsInviter.
  ///
  /// In de, this message translates to:
  /// **'Benutzer-ID der einladenden Person'**
  String get joinCardDetailsInviter;

  /// No description provided for @joinCardDetailsServer.
  ///
  /// In de, this message translates to:
  /// **'Server der Familie'**
  String get joinCardDetailsServer;

  /// No description provided for @joinDiscard.
  ///
  /// In de, this message translates to:
  /// **'Verwerfen'**
  String get joinDiscard;

  /// No description provided for @joinSending.
  ///
  /// In de, this message translates to:
  /// **'Sende …'**
  String get joinSending;

  /// No description provided for @joinWaiting.
  ///
  /// In de, this message translates to:
  /// **'Fast geschafft! {inviter} muss dich noch bestätigen. Sag kurz Bescheid – du kannst die App so lange schließen.'**
  String joinWaiting(String inviter);

  /// No description provided for @joinAlreadyInFamily.
  ///
  /// In de, this message translates to:
  /// **'Du bist bereits in einer Familie.'**
  String get joinAlreadyInFamily;

  /// No description provided for @familyNameHint.
  ///
  /// In de, this message translates to:
  /// **'z. B. Familie Müller'**
  String get familyNameHint;

  /// No description provided for @familyCreatedTitle.
  ///
  /// In de, this message translates to:
  /// **'Fertig! „{name}“ ist eingerichtet.'**
  String familyCreatedTitle(String name);

  /// No description provided for @familyCreatedBody.
  ///
  /// In de, this message translates to:
  /// **'Lade jetzt deine Familie ein – per QR-Code, E-Mail oder Link. Du kannst das auch später unter „Familie“ tun.'**
  String get familyCreatedBody;

  /// No description provided for @familyInviteNow.
  ///
  /// In de, this message translates to:
  /// **'Jetzt einladen'**
  String get familyInviteNow;

  /// No description provided for @later.
  ///
  /// In de, this message translates to:
  /// **'Später'**
  String get later;

  /// No description provided for @familySwitchToJoin.
  ///
  /// In de, this message translates to:
  /// **'Ich wurde doch eingeladen'**
  String get familySwitchToJoin;

  /// No description provided for @familySwitchToCreate.
  ///
  /// In de, this message translates to:
  /// **'Stattdessen eine neue Familie gründen'**
  String get familySwitchToCreate;

  /// No description provided for @familyInviteIntro.
  ///
  /// In de, this message translates to:
  /// **'Lade Familienmitglieder ein. Sie bekommen einen Link oder QR-Code und schicken dir eine Anfrage, die du bestätigst.'**
  String get familyInviteIntro;

  /// No description provided for @familyInviteSomeone.
  ///
  /// In de, this message translates to:
  /// **'Jemanden einladen'**
  String get familyInviteSomeone;

  /// No description provided for @familyInviteScanHint.
  ///
  /// In de, this message translates to:
  /// **'Lass die Person diesen Code mit der Kamera ihres Handys scannen – oder schick ihr den Link.'**
  String get familyInviteScanHint;

  /// No description provided for @familyRequestFrom.
  ///
  /// In de, this message translates to:
  /// **'{name} möchte beitreten'**
  String familyRequestFrom(String name);

  /// No description provided for @errUsernameTaken.
  ///
  /// In de, this message translates to:
  /// **'Dieser Benutzername ist schon vergeben.'**
  String get errUsernameTaken;

  /// No description provided for @errUsernameInvalid.
  ///
  /// In de, this message translates to:
  /// **'Dieser Benutzername ist nicht erlaubt. Bitte wähle einen anderen.'**
  String get errUsernameInvalid;

  /// No description provided for @errWeakPassword.
  ///
  /// In de, this message translates to:
  /// **'Das Passwort ist zu schwach. Bitte nimm ein längeres Passwort.'**
  String get errWeakPassword;

  /// No description provided for @errRegistrationDisabled.
  ///
  /// In de, this message translates to:
  /// **'Bei diesem Anbieter kann die App kein Konto anlegen. Erstelle es auf seiner Webseite.'**
  String get errRegistrationDisabled;

  /// No description provided for @errEmailInUse.
  ///
  /// In de, this message translates to:
  /// **'Diese E-Mail-Adresse wird schon für ein anderes Konto verwendet.'**
  String get errEmailInUse;

  /// No description provided for @errOAuthCancelled.
  ///
  /// In de, this message translates to:
  /// **'Die Anmeldung im Browser wurde nicht abgeschlossen. Bitte versuche es noch einmal.'**
  String get errOAuthCancelled;

  /// No description provided for @joinCardServerMismatch.
  ///
  /// In de, this message translates to:
  /// **'Achtung: Die Familie liegt bei {family}, die einladende Person aber bei {inviter}. Tritt nur bei, wenn du diese Einladung wirklich erwartet hast.'**
  String joinCardServerMismatch(String family, String inviter);

  /// No description provided for @weekdayLongMon.
  ///
  /// In de, this message translates to:
  /// **'Montag'**
  String get weekdayLongMon;

  /// No description provided for @weekdayLongTue.
  ///
  /// In de, this message translates to:
  /// **'Dienstag'**
  String get weekdayLongTue;

  /// No description provided for @weekdayLongWed.
  ///
  /// In de, this message translates to:
  /// **'Mittwoch'**
  String get weekdayLongWed;

  /// No description provided for @weekdayLongThu.
  ///
  /// In de, this message translates to:
  /// **'Donnerstag'**
  String get weekdayLongThu;

  /// No description provided for @weekdayLongFri.
  ///
  /// In de, this message translates to:
  /// **'Freitag'**
  String get weekdayLongFri;

  /// No description provided for @weekdayLongSat.
  ///
  /// In de, this message translates to:
  /// **'Samstag'**
  String get weekdayLongSat;

  /// No description provided for @weekdayLongSun.
  ///
  /// In de, this message translates to:
  /// **'Sonntag'**
  String get weekdayLongSun;

  /// No description provided for @tasksBadgeWeekdays.
  ///
  /// In de, this message translates to:
  /// **'Mo–Fr'**
  String get tasksBadgeWeekdays;

  /// No description provided for @tasksFieldDescription.
  ///
  /// In de, this message translates to:
  /// **'Erklärung (optional)'**
  String get tasksFieldDescription;

  /// No description provided for @tasksDescriptionHint.
  ///
  /// In de, this message translates to:
  /// **'z. B. was genau zu tun ist'**
  String get tasksDescriptionHint;

  /// No description provided for @tasksRepeatMonthlyWeekday.
  ///
  /// In de, this message translates to:
  /// **'Monatlich nach Wochentag'**
  String get tasksRepeatMonthlyWeekday;

  /// No description provided for @tasksRepeatMonthlyDate.
  ///
  /// In de, this message translates to:
  /// **'Monatlich nach Datum'**
  String get tasksRepeatMonthlyDate;

  /// No description provided for @tasksDailyAllDays.
  ///
  /// In de, this message translates to:
  /// **'Alle Wochentage (auch Samstag und Sonntag)'**
  String get tasksDailyAllDays;

  /// No description provided for @tasksDailyWeekdays.
  ///
  /// In de, this message translates to:
  /// **'Montag bis Freitag (ohne Wochenende)'**
  String get tasksDailyWeekdays;

  /// No description provided for @tasksFieldWeekday.
  ///
  /// In de, this message translates to:
  /// **'Wochentag'**
  String get tasksFieldWeekday;

  /// No description provided for @tasksFieldOrdinal.
  ///
  /// In de, this message translates to:
  /// **'Welcher'**
  String get tasksFieldOrdinal;

  /// No description provided for @tasksFieldDay.
  ///
  /// In de, this message translates to:
  /// **'Tag des Monats'**
  String get tasksFieldDay;

  /// No description provided for @tasksOrdinal1.
  ///
  /// In de, this message translates to:
  /// **'Erster'**
  String get tasksOrdinal1;

  /// No description provided for @tasksOrdinal2.
  ///
  /// In de, this message translates to:
  /// **'Zweiter'**
  String get tasksOrdinal2;

  /// No description provided for @tasksOrdinal3.
  ///
  /// In de, this message translates to:
  /// **'Dritter'**
  String get tasksOrdinal3;

  /// No description provided for @tasksOrdinal4.
  ///
  /// In de, this message translates to:
  /// **'Vierter'**
  String get tasksOrdinal4;

  /// No description provided for @tasksOrdinalLast.
  ///
  /// In de, this message translates to:
  /// **'Letzter'**
  String get tasksOrdinalLast;

  /// No description provided for @tasksOrdinalInText1.
  ///
  /// In de, this message translates to:
  /// **'ersten'**
  String get tasksOrdinalInText1;

  /// No description provided for @tasksOrdinalInText2.
  ///
  /// In de, this message translates to:
  /// **'zweiten'**
  String get tasksOrdinalInText2;

  /// No description provided for @tasksOrdinalInText3.
  ///
  /// In de, this message translates to:
  /// **'dritten'**
  String get tasksOrdinalInText3;

  /// No description provided for @tasksOrdinalInText4.
  ///
  /// In de, this message translates to:
  /// **'vierten'**
  String get tasksOrdinalInText4;

  /// No description provided for @tasksOrdinalInTextLast.
  ///
  /// In de, this message translates to:
  /// **'letzten'**
  String get tasksOrdinalInTextLast;

  /// No description provided for @tasksRuleWeekdays.
  ///
  /// In de, this message translates to:
  /// **'Montag bis Freitag'**
  String get tasksRuleWeekdays;

  /// No description provided for @tasksRuleWeekly.
  ///
  /// In de, this message translates to:
  /// **'Wöchentlich am {weekday}'**
  String tasksRuleWeekly(String weekday);

  /// No description provided for @tasksRuleMonthlyWeekday.
  ///
  /// In de, this message translates to:
  /// **'Monatlich am {ordinal} {weekday}'**
  String tasksRuleMonthlyWeekday(String ordinal, String weekday);

  /// No description provided for @tasksRuleMonthlyDate.
  ///
  /// In de, this message translates to:
  /// **'Monatlich am {day}.'**
  String tasksRuleMonthlyDate(int day);

  /// No description provided for @tasksResetWeekdays.
  ///
  /// In de, this message translates to:
  /// **'Startet montags bis freitags neu, nicht am Wochenende'**
  String get tasksResetWeekdays;

  /// No description provided for @tasksResetWeeklyOn.
  ///
  /// In de, this message translates to:
  /// **'Startet jeden {weekday} neu'**
  String tasksResetWeeklyOn(String weekday);

  /// No description provided for @tasksResetMonthlyWeekday.
  ///
  /// In de, this message translates to:
  /// **'Startet jeden Monat am {ordinal} {weekday} neu'**
  String tasksResetMonthlyWeekday(String ordinal, String weekday);

  /// No description provided for @tasksResetMonthlyDate.
  ///
  /// In de, this message translates to:
  /// **'Startet jeden Monat am {day}. neu'**
  String tasksResetMonthlyDate(int day);

  /// No description provided for @tasksResetMonthlyDateShort.
  ///
  /// In de, this message translates to:
  /// **'Startet jeden Monat am {day}. neu – in Monaten ohne diesen Tag am letzten Tag des Monats'**
  String tasksResetMonthlyDateShort(int day);

  /// No description provided for @tasksNextReset.
  ///
  /// In de, this message translates to:
  /// **'Nächster Neustart: {date}'**
  String tasksNextReset(String date);

  /// No description provided for @tasksDescriptionTooLong.
  ///
  /// In de, this message translates to:
  /// **'Die Erklärung ist zu lang. Bitte kürze sie etwas.'**
  String get tasksDescriptionTooLong;

  /// No description provided for @joinLinkNotALink.
  ///
  /// In de, this message translates to:
  /// **'Das ist kein Einladungslink. Ein Einladungslink beginnt mit „https://carpeasrael.github.io/FamilyNexus/join/“ oder „familynexus://join“.'**
  String get joinLinkNotALink;

  /// No description provided for @joinLinkDamaged.
  ///
  /// In de, this message translates to:
  /// **'Der Link ist unvollständig oder beschädigt – oft passiert das beim Weiterleiten. Bitte kopiere ihn noch einmal vollständig oder scanne den QR-Code.'**
  String get joinLinkDamaged;

  /// No description provided for @joinLinkExpired.
  ///
  /// In de, this message translates to:
  /// **'Dieser Einladungslink ist abgelaufen. Bitte die Person, die dich einlädt, um einen neuen Link.'**
  String get joinLinkExpired;

  /// No description provided for @joinLinkNewerVersion.
  ///
  /// In de, this message translates to:
  /// **'Dieser Link stammt aus einer neueren Version von FamilyNexus. Bitte aktualisiere die App und versuche es noch einmal.'**
  String get joinLinkNewerVersion;

  /// No description provided for @joinCardLocalServer.
  ///
  /// In de, this message translates to:
  /// **'Achtung: Diese Familie liegt auf einem Server im Heimnetz ({server}). Er ist nur erreichbar, wenn dein Gerät im selben Netz ist (z. B. im WLAN der Familie). Fahre nur fort, wenn du diese Einladung erwartet hast.'**
  String joinCardLocalServer(String server);

  /// No description provided for @inviteValidityDays.
  ///
  /// In de, this message translates to:
  /// **'{days, plural, =1{1 Tag} other{{days} Tage}}'**
  String inviteValidityDays(int days);

  /// No description provided for @familyInviteValidityLabel.
  ///
  /// In de, this message translates to:
  /// **'Gültig für'**
  String get familyInviteValidityLabel;

  /// No description provided for @inviteValidityInSentence.
  ///
  /// In de, this message translates to:
  /// **'{days, plural, =1{einen Tag} other{{days} Tage}}'**
  String inviteValidityInSentence(int days);

  /// No description provided for @joinCardLocalOtherAccount.
  ///
  /// In de, this message translates to:
  /// **'Diese Familie liegt auf einem Server im Heimnetz ({family}). Mit deinem Konto bei {own} kannst du ihr nicht beitreten. Lege stattdessen ein Konto bei {family} an (dazu abmelden und „Ich wurde eingeladen“ wählen).'**
  String joinCardLocalOtherAccount(String family, String own);

  /// No description provided for @advLocalConsent.
  ///
  /// In de, this message translates to:
  /// **'Die Einladung verweist auf einen Server im Heimnetz ({host}). Verbinde dich nur, wenn du die Einladung erwartet hast und im selben Netz bist (z. B. im WLAN der Familie).'**
  String advLocalConsent(String host);

  /// No description provided for @advLocalConnect.
  ///
  /// In de, this message translates to:
  /// **'Mit {host} verbinden'**
  String advLocalConnect(String host);

  /// No description provided for @settingsStorageTitle.
  ///
  /// In de, this message translates to:
  /// **'Speicherorte'**
  String get settingsStorageTitle;

  /// No description provided for @settingsStorageDbDir.
  ///
  /// In de, this message translates to:
  /// **'Datenbank-Ordner'**
  String get settingsStorageDbDir;

  /// No description provided for @settingsStorageBrowser.
  ///
  /// In de, this message translates to:
  /// **'Browser-Speicher (IndexedDB) dieser Webadresse'**
  String get settingsStorageBrowser;

  /// No description provided for @settingsStorageAppDb.
  ///
  /// In de, this message translates to:
  /// **'App-Daten: Termine, Listen, Einstellungen (verschlüsselt)'**
  String get settingsStorageAppDb;

  /// No description provided for @settingsStorageMatrixDb.
  ///
  /// In de, this message translates to:
  /// **'Chat- und Abgleichsdaten: Matrix (verschlüsselt)'**
  String get settingsStorageMatrixDb;

  /// No description provided for @settingsStorageKeys.
  ///
  /// In de, this message translates to:
  /// **'Datenbankschlüssel'**
  String get settingsStorageKeys;

  /// No description provided for @settingsStorageOnline.
  ///
  /// In de, this message translates to:
  /// **'Online beim Matrix-Anbieter'**
  String get settingsStorageOnline;

  /// No description provided for @keyStoreAndroid.
  ///
  /// In de, this message translates to:
  /// **'Android Keystore (an dieses Gerät gebunden)'**
  String get keyStoreAndroid;

  /// No description provided for @keyStoreApple.
  ///
  /// In de, this message translates to:
  /// **'Schlüsselbund des Geräts (nicht in iCloud)'**
  String get keyStoreApple;

  /// No description provided for @keyStoreLinux.
  ///
  /// In de, this message translates to:
  /// **'Schlüsselbund des Systems (Secret Service)'**
  String get keyStoreLinux;

  /// No description provided for @keyStoreWindows.
  ///
  /// In de, this message translates to:
  /// **'Windows-Anmeldeinformationsverwaltung'**
  String get keyStoreWindows;

  /// No description provided for @keyStoreBrowser.
  ///
  /// In de, this message translates to:
  /// **'Passwortgeschützter Tresor im Browser-Speicher (localStorage)'**
  String get keyStoreBrowser;

  /// No description provided for @settingsReportLocal.
  ///
  /// In de, this message translates to:
  /// **'Protokoll: alle lokal gespeicherten Daten zeigen'**
  String get settingsReportLocal;

  /// No description provided for @settingsReportOnline.
  ///
  /// In de, this message translates to:
  /// **'Protokoll: alle online gespeicherten Daten zeigen'**
  String get settingsReportOnline;

  /// No description provided for @reportLocalTitle.
  ///
  /// In de, this message translates to:
  /// **'Lokal gespeicherte Daten'**
  String get reportLocalTitle;

  /// No description provided for @reportOnlineTitle.
  ///
  /// In de, this message translates to:
  /// **'Online gespeicherte Daten'**
  String get reportOnlineTitle;

  /// No description provided for @reportWarning.
  ///
  /// In de, this message translates to:
  /// **'Das Protokoll zeigt deine Daten im Klartext. Beim Kopieren oder Speichern verlassen sie den verschlüsselten Speicher der App.'**
  String get reportWarning;

  /// No description provided for @reportCopy.
  ///
  /// In de, this message translates to:
  /// **'Kopieren'**
  String get reportCopy;

  /// No description provided for @reportCopied.
  ///
  /// In de, this message translates to:
  /// **'Protokoll kopiert.'**
  String get reportCopied;

  /// No description provided for @reportSave.
  ///
  /// In de, this message translates to:
  /// **'Als Datei speichern'**
  String get reportSave;

  /// No description provided for @reportSaved.
  ///
  /// In de, this message translates to:
  /// **'Protokoll gespeichert.'**
  String get reportSaved;

  /// No description provided for @reportGenerated.
  ///
  /// In de, this message translates to:
  /// **'Erstellt: {time} · App-Version {version}'**
  String reportGenerated(String time, String version);

  /// No description provided for @reportSectionKeys.
  ///
  /// In de, this message translates to:
  /// **'Schlüsselspeicher'**
  String get reportSectionKeys;

  /// No description provided for @reportKeyPresent.
  ///
  /// In de, this message translates to:
  /// **'vorhanden (Wert wird nicht angezeigt)'**
  String get reportKeyPresent;

  /// No description provided for @reportKeyMissing.
  ///
  /// In de, this message translates to:
  /// **'nicht vorhanden'**
  String get reportKeyMissing;

  /// No description provided for @reportSectionAppDb.
  ///
  /// In de, this message translates to:
  /// **'App-Datenbank'**
  String get reportSectionAppDb;

  /// No description provided for @reportFileSize.
  ///
  /// In de, this message translates to:
  /// **'Dateigröße: {size}'**
  String reportFileSize(String size);

  /// No description provided for @reportRows.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =0{keine Einträge} =1{1 Eintrag} other{{count} Einträge}}'**
  String reportRows(int count);

  /// No description provided for @reportSectionMatrixDb.
  ///
  /// In de, this message translates to:
  /// **'Matrix-Datenbank (Zwischenspeicher)'**
  String get reportSectionMatrixDb;

  /// No description provided for @reportMatrixSecrets.
  ///
  /// In de, this message translates to:
  /// **'Außerdem gespeichert, aber aus Sicherheitsgründen nicht angezeigt: Zugangstoken der Sitzung, Geräteschlüssel und Schlüssel der verschlüsselten Gespräche.'**
  String get reportMatrixSecrets;

  /// No description provided for @reportMatrixUnavailable.
  ///
  /// In de, this message translates to:
  /// **'Nicht verfügbar (nicht angemeldet oder Fehler beim Lesen).'**
  String get reportMatrixUnavailable;

  /// No description provided for @reportMemoryOnly.
  ///
  /// In de, this message translates to:
  /// **'Nie gespeichert, nur im Arbeitsspeicher: Online-Status der Familienmitglieder.'**
  String get reportMemoryOnly;

  /// No description provided for @reportOsReminders.
  ///
  /// In de, this message translates to:
  /// **'Geplante Erinnerungen liegen zusätzlich beim Betriebssystem.'**
  String get reportOsReminders;

  /// No description provided for @reportSectionAccount.
  ///
  /// In de, this message translates to:
  /// **'Konto'**
  String get reportSectionAccount;

  /// No description provided for @reportDisplayName.
  ///
  /// In de, this message translates to:
  /// **'Anzeigename'**
  String get reportDisplayName;

  /// No description provided for @reportAvatar.
  ///
  /// In de, this message translates to:
  /// **'Profilbild'**
  String get reportAvatar;

  /// No description provided for @reportYes.
  ///
  /// In de, this message translates to:
  /// **'ja'**
  String get reportYes;

  /// No description provided for @reportNo.
  ///
  /// In de, this message translates to:
  /// **'nein'**
  String get reportNo;

  /// No description provided for @reportNotSet.
  ///
  /// In de, this message translates to:
  /// **'nicht gesetzt'**
  String get reportNotSet;

  /// No description provided for @reportSectionSecurity.
  ///
  /// In de, this message translates to:
  /// **'Verschlüsselung'**
  String get reportSectionSecurity;

  /// No description provided for @reportCrossSigning.
  ///
  /// In de, this message translates to:
  /// **'Cross-Signing-Schlüssel'**
  String get reportCrossSigning;

  /// No description provided for @reportKeyBackup.
  ///
  /// In de, this message translates to:
  /// **'Schlüssel-Backup (mit deinem Wiederherstellungsschlüssel verschlüsselt)'**
  String get reportKeyBackup;

  /// No description provided for @reportSetUp.
  ///
  /// In de, this message translates to:
  /// **'eingerichtet'**
  String get reportSetUp;

  /// No description provided for @reportNotSetUp.
  ///
  /// In de, this message translates to:
  /// **'nicht eingerichtet'**
  String get reportNotSetUp;

  /// No description provided for @reportSectionAccountData.
  ///
  /// In de, this message translates to:
  /// **'Kontodaten (nur Arten, Inhalte werden nicht angezeigt)'**
  String get reportSectionAccountData;

  /// No description provided for @reportSectionRooms.
  ///
  /// In de, this message translates to:
  /// **'Räume'**
  String get reportSectionRooms;

  /// No description provided for @reportNone.
  ///
  /// In de, this message translates to:
  /// **'keine'**
  String get reportNone;

  /// No description provided for @roomKindFamily.
  ///
  /// In de, this message translates to:
  /// **'Familie'**
  String get roomKindFamily;

  /// No description provided for @roomKindPrivate.
  ///
  /// In de, this message translates to:
  /// **'Privater Raum (Abgleich privater Termine)'**
  String get roomKindPrivate;

  /// No description provided for @roomKindDirect.
  ///
  /// In de, this message translates to:
  /// **'Einzelchat'**
  String get roomKindDirect;

  /// No description provided for @roomKindOther.
  ///
  /// In de, this message translates to:
  /// **'Sonstiger Raum'**
  String get roomKindOther;

  /// No description provided for @reportRoomEncrypted.
  ///
  /// In de, this message translates to:
  /// **'Ende-zu-Ende-verschlüsselt'**
  String get reportRoomEncrypted;

  /// No description provided for @reportRoomMembership.
  ///
  /// In de, this message translates to:
  /// **'Eigene Mitgliedschaft'**
  String get reportRoomMembership;

  /// No description provided for @reportRoomMembers.
  ///
  /// In de, this message translates to:
  /// **'Mitglieder: {joined} beigetreten, {invited} eingeladen'**
  String reportRoomMembers(int joined, int invited);

  /// No description provided for @reportRoomEvents.
  ///
  /// In de, this message translates to:
  /// **'Ereignisse auf diesem Gerät: {count}'**
  String reportRoomEvents(int count);

  /// No description provided for @reportRoomAttachments.
  ///
  /// In de, this message translates to:
  /// **'Anhänge: {count}'**
  String reportRoomAttachments(int count);

  /// No description provided for @reportFamilyMembers.
  ///
  /// In de, this message translates to:
  /// **'Mitglieder der Familie'**
  String get reportFamilyMembers;

  /// No description provided for @reportOnlineNote.
  ///
  /// In de, this message translates to:
  /// **'Inhalte von Nachrichten, Terminen, Listen und Anhängen liegen beim Anbieter nur Ende-zu-Ende-verschlüsselt vor. Lesbar für den Anbieter sind Metadaten: Konto, Geräte, Raummitglieder, Zeitpunkte und Größe der Ereignisse sowie die Arten der Kontodaten. Die Ereigniszahlen beruhen auf dem Abgleich dieses Geräts; beim Anbieter können ältere Ereignisse zusätzlich liegen.'**
  String get reportOnlineNote;

  /// No description provided for @eventTypeMessage.
  ///
  /// In de, this message translates to:
  /// **'Nachrichten'**
  String get eventTypeMessage;

  /// No description provided for @eventTypeReaction.
  ///
  /// In de, this message translates to:
  /// **'Reaktionen'**
  String get eventTypeReaction;

  /// No description provided for @eventTypeSharedEvent.
  ///
  /// In de, this message translates to:
  /// **'Termine (geteilt)'**
  String get eventTypeSharedEvent;

  /// No description provided for @eventTypePrivateEvent.
  ///
  /// In de, this message translates to:
  /// **'Termine (privat)'**
  String get eventTypePrivateEvent;

  /// No description provided for @eventTypeRsvp.
  ///
  /// In de, this message translates to:
  /// **'Zu- und Absagen'**
  String get eventTypeRsvp;

  /// No description provided for @eventTypeShopping.
  ///
  /// In de, this message translates to:
  /// **'Einkaufszettel'**
  String get eventTypeShopping;

  /// No description provided for @eventTypeTaskList.
  ///
  /// In de, this message translates to:
  /// **'Aufgabenlisten'**
  String get eventTypeTaskList;

  /// No description provided for @eventTypeTaskDone.
  ///
  /// In de, this message translates to:
  /// **'Erledigte Aufgaben'**
  String get eventTypeTaskDone;

  /// No description provided for @eventTypeEncrypted.
  ///
  /// In de, this message translates to:
  /// **'Nicht entschlüsselbar'**
  String get eventTypeEncrypted;

  /// No description provided for @reportFile.
  ///
  /// In de, this message translates to:
  /// **'Datei: {path}'**
  String reportFile(String path);

  /// No description provided for @reportMembershipJoined.
  ///
  /// In de, this message translates to:
  /// **'beigetreten'**
  String get reportMembershipJoined;

  /// No description provided for @reportMembershipInvited.
  ///
  /// In de, this message translates to:
  /// **'eingeladen'**
  String get reportMembershipInvited;

  /// No description provided for @reportMembershipRequested.
  ///
  /// In de, this message translates to:
  /// **'Beitritt angefragt'**
  String get reportMembershipRequested;

  /// No description provided for @reportMembershipLeft.
  ///
  /// In de, this message translates to:
  /// **'verlassen'**
  String get reportMembershipLeft;

  /// No description provided for @reportMembershipBanned.
  ///
  /// In de, this message translates to:
  /// **'ausgeschlossen'**
  String get reportMembershipBanned;

  /// No description provided for @accountDelete.
  ///
  /// In de, this message translates to:
  /// **'Konto löschen'**
  String get accountDelete;

  /// No description provided for @accountDeleteHint.
  ///
  /// In de, this message translates to:
  /// **'Matrix-Konto beim Anbieter dauerhaft löschen'**
  String get accountDeleteHint;

  /// No description provided for @accountDeleteTitle.
  ///
  /// In de, this message translates to:
  /// **'Konto löschen?'**
  String get accountDeleteTitle;

  /// No description provided for @accountDeleteBody.
  ///
  /// In de, this message translates to:
  /// **'Dein Konto {userId} wird bei {server} dauerhaft gelöscht. Die Matrix-ID kann danach nicht wieder verwendet werden. Nachrichten, die du gesendet hast, bleiben für die anderen Familienmitglieder sichtbar. Anschließend werden alle Daten auf diesem Gerät gelöscht.'**
  String accountDeleteBody(String userId, String server);

  /// No description provided for @accountDeleteSoleModerator.
  ///
  /// In de, this message translates to:
  /// **'Du bist der einzige Moderator der Familie. Ernenne vorher ein anderes Mitglied zum Moderator, sonst kann niemand mehr die Familie verwalten.'**
  String get accountDeleteSoleModerator;

  /// No description provided for @accountDeletePassword.
  ///
  /// In de, this message translates to:
  /// **'Passwort zur Bestätigung'**
  String get accountDeletePassword;

  /// No description provided for @accountDeleteConfirm.
  ///
  /// In de, this message translates to:
  /// **'Konto endgültig löschen'**
  String get accountDeleteConfirm;

  /// No description provided for @accountDeleteBrowserIntro.
  ///
  /// In de, this message translates to:
  /// **'Die Löschung bestätigst du auf der Kontoseite deines Anbieters im Browser.'**
  String get accountDeleteBrowserIntro;

  /// No description provided for @accountDeleteBrowserWait.
  ///
  /// In de, this message translates to:
  /// **'Bestätige die Löschung auf der Seite des Anbieters und kehre dann hierher zurück.'**
  String get accountDeleteBrowserWait;

  /// No description provided for @accountDeleteOpen.
  ///
  /// In de, this message translates to:
  /// **'Zur Löschseite'**
  String get accountDeleteOpen;

  /// No description provided for @accountDeleteOpenAgain.
  ///
  /// In de, this message translates to:
  /// **'Seite erneut öffnen'**
  String get accountDeleteOpenAgain;

  /// No description provided for @accountDeleteCheck.
  ///
  /// In de, this message translates to:
  /// **'Löschung prüfen'**
  String get accountDeleteCheck;

  /// No description provided for @accountDeleteStillActive.
  ///
  /// In de, this message translates to:
  /// **'Das Konto besteht noch. Schließe die Löschung auf der Seite des Anbieters ab.'**
  String get accountDeleteStillActive;

  /// No description provided for @accountDeleteNoBrowser.
  ///
  /// In de, this message translates to:
  /// **'Der Browser konnte nicht geöffnet werden.'**
  String get accountDeleteNoBrowser;

  /// No description provided for @chatOpening.
  ///
  /// In de, this message translates to:
  /// **'Einzelchat wird geöffnet …'**
  String get chatOpening;

  /// No description provided for @chatOpenFailed.
  ///
  /// In de, this message translates to:
  /// **'Der Einzelchat konnte nicht geöffnet werden. Bitte versuche es erneut.'**
  String get chatOpenFailed;

  /// No description provided for @chatBeforeJoin.
  ///
  /// In de, this message translates to:
  /// **'Ältere Nachrichten aus der Zeit vor deinem Beitritt sind nicht lesbar.'**
  String get chatBeforeJoin;

  /// No description provided for @errWrongPassword.
  ///
  /// In de, this message translates to:
  /// **'Das Passwort stimmt nicht.'**
  String get errWrongPassword;

  /// No description provided for @syncSlow.
  ///
  /// In de, this message translates to:
  /// **'Das dauert länger als üblich. Prüfe die Internetverbindung oder versuche es erneut.'**
  String get syncSlow;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
