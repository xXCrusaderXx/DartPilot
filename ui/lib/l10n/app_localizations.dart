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
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('de'), Locale('en')];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'DartPilot'**
  String get appTitle;

  /// No description provided for @chooseGame.
  ///
  /// In en, this message translates to:
  /// **'Choose a game'**
  String get chooseGame;

  /// No description provided for @modeX01.
  ///
  /// In en, this message translates to:
  /// **'X01'**
  String get modeX01;

  /// No description provided for @modeX01Description.
  ///
  /// In en, this message translates to:
  /// **'501 or 301, double out'**
  String get modeX01Description;

  /// No description provided for @modeCricket.
  ///
  /// In en, this message translates to:
  /// **'Cricket'**
  String get modeCricket;

  /// No description provided for @modeCricketDescription.
  ///
  /// In en, this message translates to:
  /// **'Close 15 to 20 and bull'**
  String get modeCricketDescription;

  /// No description provided for @modeAroundTheClock.
  ///
  /// In en, this message translates to:
  /// **'Around the Clock'**
  String get modeAroundTheClock;

  /// No description provided for @modeAroundTheClockDescription.
  ///
  /// In en, this message translates to:
  /// **'Hit 1 to 20 in order'**
  String get modeAroundTheClockDescription;

  /// No description provided for @modeTraining.
  ///
  /// In en, this message translates to:
  /// **'Free throwing'**
  String get modeTraining;

  /// No description provided for @modeTrainingDescription.
  ///
  /// In en, this message translates to:
  /// **'Every dart is shown and counted'**
  String get modeTrainingDescription;

  /// No description provided for @inputBoard.
  ///
  /// In en, this message translates to:
  /// **'Board'**
  String get inputBoard;

  /// No description provided for @inputKeypad.
  ///
  /// In en, this message translates to:
  /// **'Keypad'**
  String get inputKeypad;

  /// No description provided for @single.
  ///
  /// In en, this message translates to:
  /// **'Single'**
  String get single;

  /// No description provided for @double.
  ///
  /// In en, this message translates to:
  /// **'Double'**
  String get double;

  /// No description provided for @triple.
  ///
  /// In en, this message translates to:
  /// **'Triple'**
  String get triple;

  /// No description provided for @miss.
  ///
  /// In en, this message translates to:
  /// **'Miss'**
  String get miss;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @visit.
  ///
  /// In en, this message translates to:
  /// **'Visit'**
  String get visit;

  /// No description provided for @darts.
  ///
  /// In en, this message translates to:
  /// **'Darts'**
  String get darts;

  /// No description provided for @points.
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get points;

  /// No description provided for @average.
  ///
  /// In en, this message translates to:
  /// **'3-dart average'**
  String get average;

  /// No description provided for @newVisit.
  ///
  /// In en, this message translates to:
  /// **'Next visit'**
  String get newVisit;

  /// No description provided for @noThrowsYet.
  ///
  /// In en, this message translates to:
  /// **'Tap the board or use the keypad'**
  String get noThrowsYet;

  /// No description provided for @x01Setup.
  ///
  /// In en, this message translates to:
  /// **'New X01 game'**
  String get x01Setup;

  /// No description provided for @players.
  ///
  /// In en, this message translates to:
  /// **'Players'**
  String get players;

  /// No description provided for @addPlayer.
  ///
  /// In en, this message translates to:
  /// **'Add player'**
  String get addPlayer;

  /// No description provided for @playerName.
  ///
  /// In en, this message translates to:
  /// **'Player {number}'**
  String playerName(int number);

  /// No description provided for @startScore.
  ///
  /// In en, this message translates to:
  /// **'Start score'**
  String get startScore;

  /// No description provided for @doubleIn.
  ///
  /// In en, this message translates to:
  /// **'Double in'**
  String get doubleIn;

  /// No description provided for @doubleOut.
  ///
  /// In en, this message translates to:
  /// **'Double out'**
  String get doubleOut;

  /// No description provided for @legsToWin.
  ///
  /// In en, this message translates to:
  /// **'Legs to win'**
  String get legsToWin;

  /// No description provided for @startGame.
  ///
  /// In en, this message translates to:
  /// **'Start game'**
  String get startGame;

  /// No description provided for @leg.
  ///
  /// In en, this message translates to:
  /// **'Leg {number}'**
  String leg(int number);

  /// No description provided for @legs.
  ///
  /// In en, this message translates to:
  /// **'Legs'**
  String get legs;

  /// No description provided for @checkout.
  ///
  /// In en, this message translates to:
  /// **'Checkout'**
  String get checkout;

  /// No description provided for @bust.
  ///
  /// In en, this message translates to:
  /// **'Bust'**
  String get bust;

  /// No description provided for @notIn.
  ///
  /// In en, this message translates to:
  /// **'not in'**
  String get notIn;

  /// No description provided for @legWonBy.
  ///
  /// In en, this message translates to:
  /// **'{name} wins the leg'**
  String legWonBy(String name);

  /// No description provided for @matchWonBy.
  ///
  /// In en, this message translates to:
  /// **'{name} wins!'**
  String matchWonBy(String name);

  /// No description provided for @newGame.
  ///
  /// In en, this message translates to:
  /// **'New game'**
  String get newGame;

  /// No description provided for @backToMenu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get backToMenu;

  /// No description provided for @removePlayer.
  ///
  /// In en, this message translates to:
  /// **'Remove player'**
  String get removePlayer;

  /// No description provided for @cricketSetup.
  ///
  /// In en, this message translates to:
  /// **'New Cricket game'**
  String get cricketSetup;

  /// No description provided for @aroundTheClockSetup.
  ///
  /// In en, this message translates to:
  /// **'New Around the Clock game'**
  String get aroundTheClockSetup;

  /// No description provided for @endWithBull.
  ///
  /// In en, this message translates to:
  /// **'Finish with the bull'**
  String get endWithBull;

  /// No description provided for @target.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get target;

  /// No description provided for @marksPerRound.
  ///
  /// In en, this message translates to:
  /// **'Marks per round'**
  String get marksPerRound;

  /// No description provided for @hitRate.
  ///
  /// In en, this message translates to:
  /// **'Hit rate'**
  String get hitRate;

  /// No description provided for @bull.
  ///
  /// In en, this message translates to:
  /// **'Bull'**
  String get bull;

  /// No description provided for @engine.
  ///
  /// In en, this message translates to:
  /// **'Engine'**
  String get engine;

  /// No description provided for @engineAddress.
  ///
  /// In en, this message translates to:
  /// **'Engine address'**
  String get engineAddress;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// No description provided for @engineConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get engineConnected;

  /// No description provided for @engineConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get engineConnecting;

  /// No description provided for @engineDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get engineDisconnected;

  /// No description provided for @engineFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get engineFailed;

  /// No description provided for @engineSimulated.
  ///
  /// In en, this message translates to:
  /// **'simulated'**
  String get engineSimulated;

  /// No description provided for @uncertainDart.
  ///
  /// In en, this message translates to:
  /// **'Uncertain: {label} ({percent} %)'**
  String uncertainDart(String label, int percent);

  /// No description provided for @uncertainNoPoint.
  ///
  /// In en, this message translates to:
  /// **'A dart was detected, but not where'**
  String get uncertainNoPoint;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @tapToCorrect.
  ///
  /// In en, this message translates to:
  /// **'Tap the board where the dart is'**
  String get tapToCorrect;

  /// No description provided for @recentDarts.
  ///
  /// In en, this message translates to:
  /// **'Last darts'**
  String get recentDarts;

  /// No description provided for @correctingDart.
  ///
  /// In en, this message translates to:
  /// **'Correcting {label} – tap the board'**
  String correctingDart(String label);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @missingDarts.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 dart is missing} other{{count} darts are missing}}'**
  String missingDarts(int count);

  /// No description provided for @countAsMiss.
  ///
  /// In en, this message translates to:
  /// **'Count as miss'**
  String get countAsMiss;

  /// No description provided for @enterManually.
  ///
  /// In en, this message translates to:
  /// **'Enter them'**
  String get enterManually;

  /// No description provided for @cameras.
  ///
  /// In en, this message translates to:
  /// **'Cameras'**
  String get cameras;

  /// No description provided for @waitingForImage.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the first image…'**
  String get waitingForImage;

  /// No description provided for @cameraOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get cameraOk;

  /// No description provided for @cameraDegraded.
  ///
  /// In en, this message translates to:
  /// **'Degraded'**
  String get cameraDegraded;

  /// No description provided for @cameraLost.
  ///
  /// In en, this message translates to:
  /// **'Lost'**
  String get cameraLost;

  /// No description provided for @noCameras.
  ///
  /// In en, this message translates to:
  /// **'The engine has no cameras'**
  String get noCameras;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['de', 'en'].contains(locale.languageCode);

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
