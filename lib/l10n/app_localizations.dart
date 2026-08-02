import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('en'),
    Locale('ru'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'TG Proxy'**
  String get appTitle;

  /// No description provided for @appSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Fast and secure connection for Telegram'**
  String get appSubtitle;

  /// No description provided for @openTelegram.
  ///
  /// In en, this message translates to:
  /// **'Open Telegram'**
  String get openTelegram;

  /// No description provided for @telegramOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open Telegram'**
  String get telegramOpenFailed;

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get connecting;

  /// No description provided for @portAlreadyInUse.
  ///
  /// In en, this message translates to:
  /// **'Port {port} is already used by another application'**
  String portAlreadyInUse(int port);

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @disconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get disconnected;

  /// No description provided for @proxyActive.
  ///
  /// In en, this message translates to:
  /// **'Proxy Active'**
  String get proxyActive;

  /// No description provided for @proxyInactive.
  ///
  /// In en, this message translates to:
  /// **'Proxy Inactive'**
  String get proxyInactive;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @themeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Change theme'**
  String get themeTooltip;

  /// No description provided for @settingsSavedRestarted.
  ///
  /// In en, this message translates to:
  /// **'Settings saved. Proxy restarted.'**
  String get settingsSavedRestarted;

  /// No description provided for @settingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Settings saved'**
  String get settingsSaved;

  /// No description provided for @logsExported.
  ///
  /// In en, this message translates to:
  /// **'Logs exported'**
  String get logsExported;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @exportLogs.
  ///
  /// In en, this message translates to:
  /// **'Export logs'**
  String get exportLogs;

  /// No description provided for @connectionLinkSection.
  ///
  /// In en, this message translates to:
  /// **'Connection link'**
  String get connectionLinkSection;

  /// No description provided for @copyConnectionLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get copyConnectionLink;

  /// No description provided for @connectionLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Connection link copied'**
  String get connectionLinkCopied;

  /// No description provided for @listenerSection.
  ///
  /// In en, this message translates to:
  /// **'Listener'**
  String get listenerSection;

  /// No description provided for @hostLabel.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get hostLabel;

  /// No description provided for @portLabel.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get portLabel;

  /// No description provided for @secretLabel.
  ///
  /// In en, this message translates to:
  /// **'Secret'**
  String get secretLabel;

  /// No description provided for @generateSecret.
  ///
  /// In en, this message translates to:
  /// **'Generate secret'**
  String get generateSecret;

  /// No description provided for @validationRequired.
  ///
  /// In en, this message translates to:
  /// **'Required field'**
  String get validationRequired;

  /// No description provided for @validationRange.
  ///
  /// In en, this message translates to:
  /// **'Enter a value from {min} to {max}'**
  String validationRange(int min, int max);

  /// No description provided for @validationSecret.
  ///
  /// In en, this message translates to:
  /// **'Secret must start with dd and contain 32 hex characters after it'**
  String get validationSecret;

  /// No description provided for @telegramDataCentersSection.
  ///
  /// In en, this message translates to:
  /// **'Telegram data centers'**
  String get telegramDataCentersSection;

  /// No description provided for @dcIpLabel.
  ///
  /// In en, this message translates to:
  /// **'DC IP'**
  String get dcIpLabel;

  /// No description provided for @websocketBridgeSection.
  ///
  /// In en, this message translates to:
  /// **'WebSocket bridge'**
  String get websocketBridgeSection;

  /// No description provided for @bufferKbLabel.
  ///
  /// In en, this message translates to:
  /// **'Buffer, KB'**
  String get bufferKbLabel;

  /// No description provided for @poolSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Pool size'**
  String get poolSizeLabel;

  /// No description provided for @keepaliveLabel.
  ///
  /// In en, this message translates to:
  /// **'Keepalive interval'**
  String get keepaliveLabel;

  /// No description provided for @cloudflareSection.
  ///
  /// In en, this message translates to:
  /// **'Cloudflare'**
  String get cloudflareSection;

  /// No description provided for @cloudflareFallback.
  ///
  /// In en, this message translates to:
  /// **'Cloudflare fallback'**
  String get cloudflareFallback;

  /// No description provided for @cloudflareDomainsLabel.
  ///
  /// In en, this message translates to:
  /// **'Cloudflare domains'**
  String get cloudflareDomainsLabel;

  /// No description provided for @workerDomainsLabel.
  ///
  /// In en, this message translates to:
  /// **'Worker domains'**
  String get workerDomainsLabel;

  /// No description provided for @forceTestDc.
  ///
  /// In en, this message translates to:
  /// **'Force test DC'**
  String get forceTestDc;

  /// No description provided for @saveSettings.
  ///
  /// In en, this message translates to:
  /// **'Save settings'**
  String get saveSettings;
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
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
