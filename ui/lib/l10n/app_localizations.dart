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
  static const List<Locale> supportedLocales = <Locale>[Locale('en'), Locale('de')];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'DartPilot'**
  String get appTitle;

  /// No description provided for @chooseGame.
  ///
  /// In en, this message translates to:
  /// **'Play locally or solo'**
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

  /// No description provided for @leaveGameTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave the game?'**
  String get leaveGameTitle;

  /// No description provided for @leaveGameText.
  ///
  /// In en, this message translates to:
  /// **'It is kept in the statistics as unfinished.'**
  String get leaveGameText;

  /// No description provided for @leaveGame.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leaveGame;

  /// No description provided for @interruptedGameTitle.
  ///
  /// In en, this message translates to:
  /// **'Interrupted game: {game}'**
  String interruptedGameTitle(String game);

  /// No description provided for @resumeGame.
  ///
  /// In en, this message translates to:
  /// **'Play on'**
  String get resumeGame;

  /// No description provided for @endInterruptedGame.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get endInterruptedGame;

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

  /// No description provided for @fewerLegs.
  ///
  /// In en, this message translates to:
  /// **'One leg fewer'**
  String get fewerLegs;

  /// No description provided for @moreLegs.
  ///
  /// In en, this message translates to:
  /// **'One leg more'**
  String get moreLegs;

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

  /// No description provided for @x01LegOf.
  ///
  /// In en, this message translates to:
  /// **'Leg {number} · first to {total}'**
  String x01LegOf(int number, int total);

  /// No description provided for @x01PlayerFigures.
  ///
  /// In en, this message translates to:
  /// **'Ø {average}'**
  String x01PlayerFigures(String average);

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

  /// No description provided for @dartboardLabel.
  ///
  /// In en, this message translates to:
  /// **'Dartboard'**
  String get dartboardLabel;

  /// No description provided for @dartboardTapHint.
  ///
  /// In en, this message translates to:
  /// **'Tap where the dart is'**
  String get dartboardTapHint;

  /// No description provided for @calibLightNoneFound.
  ///
  /// In en, this message translates to:
  /// **'Board not found yet'**
  String get calibLightNoneFound;

  /// No description provided for @calibLightFoundRange.
  ///
  /// In en, this message translates to:
  /// **'Board found from {from} to {to} K'**
  String calibLightFoundRange(int from, int to);

  /// No description provided for @visitHit.
  ///
  /// In en, this message translates to:
  /// **'Hit'**
  String get visitHit;

  /// No description provided for @visitNoHit.
  ///
  /// In en, this message translates to:
  /// **'No hit'**
  String get visitNoHit;

  /// No description provided for @cricketMarksLabel.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No marks} =1{1 mark} =2{2 marks} other{Closed}}'**
  String cricketMarksLabel(int count);

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

  /// No description provided for @engineFailedRefused.
  ///
  /// In en, this message translates to:
  /// **'Nothing answers at this address. Is the engine running?'**
  String get engineFailedRefused;

  /// No description provided for @engineFailedTimeout.
  ///
  /// In en, this message translates to:
  /// **'The engine could not be reached in time. Check the address and the network.'**
  String get engineFailedTimeout;

  /// No description provided for @engineFailedHost.
  ///
  /// In en, this message translates to:
  /// **'This address was not found in the network.'**
  String get engineFailedHost;

  /// No description provided for @engineFailedAddress.
  ///
  /// In en, this message translates to:
  /// **'This is not an engine address; it looks like ws://192.168.1.20:8484/.'**
  String get engineFailedAddress;

  /// No description provided for @engineRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get engineRetry;

  /// No description provided for @engineErrorDisconnected.
  ///
  /// In en, this message translates to:
  /// **'The connection to the engine was lost.'**
  String get engineErrorDisconnected;

  /// No description provided for @engineErrorTimeout.
  ///
  /// In en, this message translates to:
  /// **'The engine did not answer.'**
  String get engineErrorTimeout;

  /// No description provided for @engineReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Connection to the engine lost – connecting again…'**
  String get engineReconnecting;

  /// No description provided for @engineSimulated.
  ///
  /// In en, this message translates to:
  /// **'simulated'**
  String get engineSimulated;

  /// No description provided for @engineConnectedSimulated.
  ///
  /// In en, this message translates to:
  /// **'Connected (simulated)'**
  String get engineConnectedSimulated;

  /// No description provided for @labelValue.
  ///
  /// In en, this message translates to:
  /// **'{label}: {value}'**
  String labelValue(String label, String value);

  /// No description provided for @mmValue.
  ///
  /// In en, this message translates to:
  /// **'{value} mm'**
  String mmValue(String value);

  /// No description provided for @msValue.
  ///
  /// In en, this message translates to:
  /// **'{value} ms'**
  String msValue(String value);

  /// No description provided for @secondsRange.
  ///
  /// In en, this message translates to:
  /// **'{from}–{to} s'**
  String secondsRange(int from, int to);

  /// No description provided for @countOf.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total}'**
  String countOf(int done, int total);

  /// No description provided for @uncertainDart.
  ///
  /// In en, this message translates to:
  /// **'Uncertain: {label} ({percent})'**
  String uncertainDart(String label, String percent);

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

  /// No description provided for @discardCameraOrderTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard the changed order and names?'**
  String get discardCameraOrderTitle;

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

  /// No description provided for @removeDarts.
  ///
  /// In en, this message translates to:
  /// **'Remove the darts'**
  String get removeDarts;

  /// No description provided for @removeDartsHint.
  ///
  /// In en, this message translates to:
  /// **'The next visit starts once the darts are out of the board.'**
  String get removeDartsHint;

  /// No description provided for @dartsRemoved.
  ///
  /// In en, this message translates to:
  /// **'Darts are out'**
  String get dartsRemoved;

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

  /// No description provided for @cameraUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get cameraUnknown;

  /// No description provided for @cameraNoFrameFor.
  ///
  /// In en, this message translates to:
  /// **'No image for {seconds} s'**
  String cameraNoFrameFor(int seconds);

  /// No description provided for @noCameras.
  ///
  /// In en, this message translates to:
  /// **'The engine has no cameras'**
  String get noCameras;

  /// No description provided for @fps.
  ///
  /// In en, this message translates to:
  /// **'{value} fps'**
  String fps(String value);

  /// No description provided for @lostFrames.
  ///
  /// In en, this message translates to:
  /// **'Lost'**
  String get lostFrames;

  /// No description provided for @droppedFrames.
  ///
  /// In en, this message translates to:
  /// **'Dropped'**
  String get droppedFrames;

  /// No description provided for @brightness.
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get brightness;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @expandAll.
  ///
  /// In en, this message translates to:
  /// **'Expand all'**
  String get expandAll;

  /// No description provided for @collapseAll.
  ///
  /// In en, this message translates to:
  /// **'Collapse all'**
  String get collapseAll;

  /// No description provided for @tapToEnlarge.
  ///
  /// In en, this message translates to:
  /// **'Tap the image to enlarge it'**
  String get tapToEnlarge;

  /// No description provided for @latency.
  ///
  /// In en, this message translates to:
  /// **'Latency'**
  String get latency;

  /// No description provided for @boardOccupiedTitle.
  ///
  /// In en, this message translates to:
  /// **'Pull the darts out of the board'**
  String get boardOccupiedTitle;

  /// No description provided for @boardOccupiedText.
  ///
  /// In en, this message translates to:
  /// **'The cameras see something in the board. Pull out the darts before the game starts.'**
  String get boardOccupiedText;

  /// No description provided for @boardOccupiedBanner.
  ///
  /// In en, this message translates to:
  /// **'Darts in the board'**
  String get boardOccupiedBanner;

  /// No description provided for @checkBoardAgain.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get checkBoardAgain;

  /// No description provided for @startAnyway.
  ///
  /// In en, this message translates to:
  /// **'Start anyway'**
  String get startAnyway;

  /// No description provided for @show.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get show;

  /// No description provided for @storeEmptyReference.
  ///
  /// In en, this message translates to:
  /// **'Store empty board'**
  String get storeEmptyReference;

  /// No description provided for @emptyReferenceStored.
  ///
  /// In en, this message translates to:
  /// **'Empty board stored'**
  String get emptyReferenceStored;

  /// No description provided for @boardNotEmpty.
  ///
  /// In en, this message translates to:
  /// **'The board is not empty; pull out the darts first.'**
  String get boardNotEmpty;

  /// No description provided for @storeReferenceFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not store the empty board'**
  String get storeReferenceFailed;

  /// No description provided for @searchEngines.
  ///
  /// In en, this message translates to:
  /// **'Search the network for engines'**
  String get searchEngines;

  /// No description provided for @searchingEngines.
  ///
  /// In en, this message translates to:
  /// **'Searching the network…'**
  String get searchingEngines;

  /// No description provided for @noEnginesFound.
  ///
  /// In en, this message translates to:
  /// **'No engine found. Guest Wi-Fi, client isolation or separate networks block the search; type the address instead.'**
  String get noEnginesFound;

  /// No description provided for @foundEngines.
  ///
  /// In en, this message translates to:
  /// **'Engines in the network'**
  String get foundEngines;

  /// No description provided for @engineIncompatible.
  ///
  /// In en, this message translates to:
  /// **'incompatible ({protocol})'**
  String engineIncompatible(String protocol);

  /// No description provided for @boardIsEmpty.
  ///
  /// In en, this message translates to:
  /// **'The board is empty'**
  String get boardIsEmpty;

  /// No description provided for @boardIsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Store the empty board again?'**
  String get boardIsEmptyTitle;

  /// No description provided for @boardIsEmptyText.
  ///
  /// In en, this message translates to:
  /// **'Only if no dart or other object is in the board. The current camera images become the new empty board, and the check compares with them from now on.'**
  String get boardIsEmptyText;

  /// No description provided for @boardNotStill.
  ///
  /// In en, this message translates to:
  /// **'The image is not still yet; wait a moment and try again.'**
  String get boardNotStill;

  /// No description provided for @engineThisDevice.
  ///
  /// In en, this message translates to:
  /// **'On this device'**
  String get engineThisDevice;

  /// No description provided for @engineNetwork.
  ///
  /// In en, this message translates to:
  /// **'In the network'**
  String get engineNetwork;

  /// No description provided for @localEngineStopped.
  ///
  /// In en, this message translates to:
  /// **'The engine on this device is stopped.'**
  String get localEngineStopped;

  /// No description provided for @localEngineStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting the engine…'**
  String get localEngineStarting;

  /// No description provided for @localEngineRunning.
  ///
  /// In en, this message translates to:
  /// **'The engine runs on this device ({url}).'**
  String localEngineRunning(String url);

  /// No description provided for @localEngineNotFound.
  ///
  /// In en, this message translates to:
  /// **'The engine program was not found. Enter its path under Log.'**
  String get localEngineNotFound;

  /// No description provided for @localEngineNoCameras.
  ///
  /// In en, this message translates to:
  /// **'No camera could be started: are they plugged in, or used by another program?'**
  String get localEngineNoCameras;

  /// No description provided for @localEnginePortInUse.
  ///
  /// In en, this message translates to:
  /// **'The engine\'s port is in use; another engine may be running.'**
  String get localEnginePortInUse;

  /// No description provided for @localEngineCrashed.
  ///
  /// In en, this message translates to:
  /// **'The engine stopped unexpectedly; the log shows why.'**
  String get localEngineCrashed;

  /// No description provided for @useCameras.
  ///
  /// In en, this message translates to:
  /// **'Use the cameras'**
  String get useCameras;

  /// No description provided for @useCamerasHint.
  ///
  /// In en, this message translates to:
  /// **'Live images and the board check; darts are still simulated until detection is ready.'**
  String get useCamerasHint;

  /// No description provided for @engineLog.
  ///
  /// In en, this message translates to:
  /// **'Log'**
  String get engineLog;

  /// No description provided for @startEngine.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get startEngine;

  /// No description provided for @stopEngine.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stopEngine;

  /// No description provided for @engineProgram.
  ///
  /// In en, this message translates to:
  /// **'Engine program'**
  String get engineProgram;

  /// No description provided for @engineProgramHint.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to find it automatically'**
  String get engineProgramHint;

  /// No description provided for @engineLogEmpty.
  ///
  /// In en, this message translates to:
  /// **'No output yet.'**
  String get engineLogEmpty;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @diagnosis.
  ///
  /// In en, this message translates to:
  /// **'Setup diagnosis'**
  String get diagnosis;

  /// No description provided for @startDiagnosis.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get startDiagnosis;

  /// No description provided for @restartDiagnosis.
  ///
  /// In en, this message translates to:
  /// **'Start again'**
  String get restartDiagnosis;

  /// No description provided for @stopDiagnosis.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stopDiagnosis;

  /// No description provided for @diagnosisIntro.
  ///
  /// In en, this message translates to:
  /// **'The diagnosis watches the cameras while you follow the steps: an empty board, then one dart at a time at 8 to 10 places. It lists what is wrong with the setup and what to do about it. Start the cameras about 30 s before, so their exposure has settled.'**
  String get diagnosisIntro;

  /// No description provided for @diagnosisNeedsEngine.
  ///
  /// In en, this message translates to:
  /// **'Connect to an engine first.'**
  String get diagnosisNeedsEngine;

  /// No description provided for @diagnosisNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'This engine cannot run the diagnosis; it needs the cameras (start it with the cameras).'**
  String get diagnosisNotAvailable;

  /// No description provided for @diagnosisFailed.
  ///
  /// In en, this message translates to:
  /// **'The diagnosis could not start ({code}).'**
  String diagnosisFailed(String code);

  /// No description provided for @diagnosisStopFailed.
  ///
  /// In en, this message translates to:
  /// **'The diagnosis could not be stopped ({code}).'**
  String diagnosisStopFailed(String code);

  /// No description provided for @stepEmptyBoard.
  ///
  /// In en, this message translates to:
  /// **'Leave the board empty and take your hand out of view.'**
  String get stepEmptyBoard;

  /// No description provided for @stepRemoveDarts.
  ///
  /// In en, this message translates to:
  /// **'Pull all darts out of the board.'**
  String get stepRemoveDarts;

  /// No description provided for @stepInsertDart.
  ///
  /// In en, this message translates to:
  /// **'Put one dart into the board and take your hand away.'**
  String get stepInsertDart;

  /// No description provided for @stepInsertDartHint.
  ///
  /// In en, this message translates to:
  /// **'Repeat at 8 to 10 places, also the bull and near the double ring.'**
  String get stepInsertDartHint;

  /// No description provided for @stepRemoveDart.
  ///
  /// In en, this message translates to:
  /// **'Pull the dart out again.'**
  String get stepRemoveDart;

  /// No description provided for @diagnosisMoving.
  ///
  /// In en, this message translates to:
  /// **'The image moves – hold still'**
  String get diagnosisMoving;

  /// No description provided for @diagnosisSettling.
  ///
  /// In en, this message translates to:
  /// **'Still – waiting a moment'**
  String get diagnosisSettling;

  /// No description provided for @diagnosisMeasuring.
  ///
  /// In en, this message translates to:
  /// **'Measuring…'**
  String get diagnosisMeasuring;

  /// No description provided for @diagnosisMeasured.
  ///
  /// In en, this message translates to:
  /// **'Measured'**
  String get diagnosisMeasured;

  /// No description provided for @diagnosisStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get diagnosisStopped;

  /// No description provided for @diagnosisSummary.
  ///
  /// In en, this message translates to:
  /// **'{time} · {empty, plural, =1{1 empty board} other{{empty} empty boards}} · {darts, plural, =1{1 dart} other{{darts} darts}}'**
  String diagnosisSummary(String time, int empty, int darts);

  /// No description provided for @diagnosisFindings.
  ///
  /// In en, this message translates to:
  /// **'Findings'**
  String get diagnosisFindings;

  /// No description provided for @diagnosisNoFindings.
  ///
  /// In en, this message translates to:
  /// **'Nothing found so far.'**
  String get diagnosisNoFindings;

  /// No description provided for @cameraNumber.
  ///
  /// In en, this message translates to:
  /// **'Camera {number}'**
  String cameraNumber(int number);

  /// No description provided for @diagnosisPeriods.
  ///
  /// In en, this message translates to:
  /// **'Measured moments ({count})'**
  String diagnosisPeriods(int count);

  /// No description provided for @periodEmpty.
  ///
  /// In en, this message translates to:
  /// **'empty board'**
  String get periodEmpty;

  /// No description provided for @periodDartNotLocated.
  ///
  /// In en, this message translates to:
  /// **'dart, not located'**
  String get periodDartNotLocated;

  /// No description provided for @periodDartLocated.
  ///
  /// In en, this message translates to:
  /// **'dart at {x}, {y} mm, {cameras} cameras agree within {plane} mm'**
  String periodDartLocated(String x, String y, int cameras, String plane);

  /// No description provided for @dartSeen.
  ///
  /// In en, this message translates to:
  /// **'dart seen'**
  String get dartSeen;

  /// No description provided for @dartCut.
  ///
  /// In en, this message translates to:
  /// **'dart cut at the border'**
  String get dartCut;

  /// No description provided for @dartNotSeen.
  ///
  /// In en, this message translates to:
  /// **'dart not seen'**
  String get dartNotSeen;

  /// No description provided for @periodCalibration.
  ///
  /// In en, this message translates to:
  /// **'{mm} mm off calibration'**
  String periodCalibration(String mm);

  /// No description provided for @periodBrightness.
  ///
  /// In en, this message translates to:
  /// **'brightness {value}'**
  String periodBrightness(int value);

  /// No description provided for @findingLostFrames.
  ///
  /// In en, this message translates to:
  /// **'Lost {percent} % of its frames.'**
  String findingLostFrames(String percent);

  /// No description provided for @hintLostFrames.
  ///
  /// In en, this message translates to:
  /// **'Plug the camera into another USB port or a powered hub, and close other programs that use the cameras.'**
  String get hintLostFrames;

  /// No description provided for @findingFewStillMoments.
  ///
  /// In en, this message translates to:
  /// **'Only {count} still moments in {seconds} s.'**
  String findingFewStillMoments(int count, String seconds);

  /// No description provided for @hintFewStillMoments.
  ///
  /// In en, this message translates to:
  /// **'Hold each state still for a few seconds with the hand out of view; if the image never settles, check for vibrations.'**
  String get hintFewStillMoments;

  /// No description provided for @findingNotEmptyAtStart.
  ///
  /// In en, this message translates to:
  /// **'The board was not empty at the start: its wires are partly hidden.'**
  String get findingNotEmptyAtStart;

  /// No description provided for @hintNotEmptyAtStart.
  ///
  /// In en, this message translates to:
  /// **'Start with an empty board; everything after it is compared with this first image.'**
  String get hintNotEmptyAtStart;

  /// No description provided for @findingNoRefinement.
  ///
  /// In en, this message translates to:
  /// **'No refinement for this camera: calibration and darts were not checked.'**
  String get findingNoRefinement;

  /// No description provided for @hintNoRefinement.
  ///
  /// In en, this message translates to:
  /// **'Calibrate it on the extrinsic page and refine all cameras (step 5).'**
  String get hintNoRefinement;

  /// No description provided for @findingBoardNotFound.
  ///
  /// In en, this message translates to:
  /// **'The board was not found on any empty board.'**
  String get findingBoardNotFound;

  /// No description provided for @hintBoardNotFound.
  ///
  /// In en, this message translates to:
  /// **'Check the camera\'s view and focus, and the light on the board.'**
  String get hintBoardNotFound;

  /// No description provided for @findingCalibrationOff.
  ///
  /// In en, this message translates to:
  /// **'The board is {mm} mm off this camera\'s calibration.'**
  String findingCalibrationOff(String mm);

  /// No description provided for @hintCalibrationOff.
  ///
  /// In en, this message translates to:
  /// **'If the camera or the board moved, calibrate the camera again and refine all cameras (extrinsic page, step 5).'**
  String get hintCalibrationOff;

  /// No description provided for @findingDrift.
  ///
  /// In en, this message translates to:
  /// **'The image moved by {px} px within {minutes} min.'**
  String findingDrift(String px, String minutes);

  /// No description provided for @hintDrift.
  ///
  /// In en, this message translates to:
  /// **'Let the cameras run for about 10 minutes before calibrating and playing, so they are warm; if it keeps moving, tighten the camera\'s mount.'**
  String get hintDrift;

  /// No description provided for @findingLightChanged.
  ///
  /// In en, this message translates to:
  /// **'The empty board\'s brightness changed by {percent} % ({low} at {lowS} s, {high} at {highS} s).'**
  String findingLightChanged(String percent, String low, String lowS, String high, String highS);

  /// No description provided for @hintExposureSettling.
  ///
  /// In en, this message translates to:
  /// **'After the cameras start, their automatic exposure needs a moment: begin about 30 s after starting them, and keep the ring light on.'**
  String get hintExposureSettling;

  /// No description provided for @hintLightChanged.
  ///
  /// In en, this message translates to:
  /// **'Use the ring light and keep daylight and room light constant during the test.'**
  String get hintLightChanged;

  /// No description provided for @findingBoardChanged.
  ///
  /// In en, this message translates to:
  /// **'The empty board changed {count, plural, =1{once} other{{count} times}} between darts.'**
  String findingBoardChanged(int count);

  /// No description provided for @hintBoardChanged.
  ///
  /// In en, this message translates to:
  /// **'Usually fibres pushed out by darts or a slight change of focus; harmless, as the reference is refreshed after every takeout.'**
  String get hintBoardChanged;

  /// No description provided for @findingNoDarts.
  ///
  /// In en, this message translates to:
  /// **'No dart was found in the test.'**
  String get findingNoDarts;

  /// No description provided for @hintNoDarts.
  ///
  /// In en, this message translates to:
  /// **'Put darts into the board one at a time and take the hand away each time.'**
  String get hintNoDarts;

  /// No description provided for @findingDartsLocated.
  ///
  /// In en, this message translates to:
  /// **'{located} of {darts} darts located, {abstained} without a result.'**
  String findingDartsLocated(int located, int darts, int abstained);

  /// No description provided for @hintDartsLocated.
  ///
  /// In en, this message translates to:
  /// **'The findings per camera show why darts were not located.'**
  String get hintDartsLocated;

  /// No description provided for @findingDartsCutLost.
  ///
  /// In en, this message translates to:
  /// **'Cut {cut} of {darts} darts at the image border and could not help locate {lost} of them.'**
  String findingDartsCutLost(int cut, int darts, int lost);

  /// No description provided for @hintDartsCutLost.
  ///
  /// In en, this message translates to:
  /// **'Tilt or move the camera so that the board and about 15 cm above it are in view, then calibrate it again.'**
  String get hintDartsCutLost;

  /// No description provided for @findingDartsCut.
  ///
  /// In en, this message translates to:
  /// **'Cut {cut} of {darts} darts at the image border.'**
  String findingDartsCut(int cut, int darts);

  /// No description provided for @hintDartsCut.
  ///
  /// In en, this message translates to:
  /// **'Harmless while the darts are still located; more of the space above the board in view would make it more robust.'**
  String get hintDartsCut;

  /// No description provided for @findingDartsNotSeen.
  ///
  /// In en, this message translates to:
  /// **'Did not see {missed} of {darts} darts.'**
  String findingDartsNotSeen(int missed, int darts);

  /// No description provided for @hintDartsNotSeen.
  ///
  /// In en, this message translates to:
  /// **'Check that the camera sees the whole board; dark darts on dark sectors need good light.'**
  String get hintDartsNotSeen;

  /// No description provided for @findingCameraDisagrees.
  ///
  /// In en, this message translates to:
  /// **'Disagreed with the other cameras on {disagreed} of {darts} darts.'**
  String findingCameraDisagrees(int disagreed, int darts);

  /// No description provided for @hintCameraDisagrees.
  ///
  /// In en, this message translates to:
  /// **'Run the calibration check; if it is off, calibrate this camera again and refine all cameras.'**
  String get hintCameraDisagrees;

  /// No description provided for @findingPlanesAgree.
  ///
  /// In en, this message translates to:
  /// **'Where three cameras saw a dart, they agreed within {mm} mm (median).'**
  String findingPlanesAgree(String mm);

  /// No description provided for @hintPlanesAgree.
  ///
  /// In en, this message translates to:
  /// **'Refine all cameras again; if one camera stands out, calibrate it first.'**
  String get hintPlanesAgree;

  /// No description provided for @connectTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect an engine'**
  String get connectTitle;

  /// No description provided for @connectIntro.
  ///
  /// In en, this message translates to:
  /// **'The engine runs the cameras and detects the darts. It runs on this device or on another one in your network.'**
  String get connectIntro;

  /// No description provided for @playWithoutEngine.
  ///
  /// In en, this message translates to:
  /// **'Play without an engine (enter darts by hand)'**
  String get playWithoutEngine;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @settingsConnection.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get settingsConnection;

  /// No description provided for @connectedThisDevice.
  ///
  /// In en, this message translates to:
  /// **'Connected to the engine on this device'**
  String get connectedThisDevice;

  /// No description provided for @connectedNetwork.
  ///
  /// In en, this message translates to:
  /// **'Connected to an engine in the network'**
  String get connectedNetwork;

  /// No description provided for @playingWithoutEngine.
  ///
  /// In en, this message translates to:
  /// **'Without an engine – darts are entered by hand'**
  String get playingWithoutEngine;

  /// No description provided for @playingWithoutEngineHint.
  ///
  /// In en, this message translates to:
  /// **'Connect an engine to detect darts and use the cameras.'**
  String get playingWithoutEngineHint;

  /// No description provided for @settingsCamerasBoard.
  ///
  /// In en, this message translates to:
  /// **'Cameras and darts'**
  String get settingsCamerasBoard;

  /// No description provided for @settingsSetup.
  ///
  /// In en, this message translates to:
  /// **'Setup'**
  String get settingsSetup;

  /// No description provided for @setupAssignHint.
  ///
  /// In en, this message translates to:
  /// **'Which camera is camera 1, 2 and 3'**
  String get setupAssignHint;

  /// No description provided for @setupDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get setupDone;

  /// No description provided for @setupMissing.
  ///
  /// In en, this message translates to:
  /// **'To do'**
  String get setupMissing;

  /// No description provided for @setupStale.
  ///
  /// In en, this message translates to:
  /// **'Out of date'**
  String get setupStale;

  /// No description provided for @setupProblem.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get setupProblem;

  /// No description provided for @settingsCamerasHint.
  ///
  /// In en, this message translates to:
  /// **'Live images and the state of each camera'**
  String get settingsCamerasHint;

  /// No description provided for @settingsDiagnosisHint.
  ///
  /// In en, this message translates to:
  /// **'Find out what is wrong with the setup, step by step'**
  String get settingsDiagnosisHint;

  /// No description provided for @settingsEmptyBoardHint.
  ///
  /// In en, this message translates to:
  /// **'Store the cameras\' images of the empty board for the board check'**
  String get settingsEmptyBoardHint;

  /// No description provided for @settingsCalibration.
  ///
  /// In en, this message translates to:
  /// **'Calibration'**
  String get settingsCalibration;

  /// No description provided for @calibration.
  ///
  /// In en, this message translates to:
  /// **'Calibrate the cameras'**
  String get calibration;

  /// No description provided for @calibrationInSetupTool.
  ///
  /// In en, this message translates to:
  /// **'For now in the setup program dartpilot_setup on Linux'**
  String get calibrationInSetupTool;

  /// No description provided for @playTogether.
  ///
  /// In en, this message translates to:
  /// **'Play together'**
  String get playTogether;

  /// No description provided for @lobby.
  ///
  /// In en, this message translates to:
  /// **'Lobby'**
  String get lobby;

  /// No description provided for @lobbyComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Play with friends on other devices – coming with #124'**
  String get lobbyComingSoon;

  /// No description provided for @diagnosisProgress.
  ///
  /// In en, this message translates to:
  /// **'Darts: {done} of {target}'**
  String diagnosisProgress(int done, int target);

  /// No description provided for @stepRemoveLastDart.
  ///
  /// In en, this message translates to:
  /// **'Pull the last dart out – then you are done.'**
  String get stepRemoveLastDart;

  /// No description provided for @diagnosisEnough.
  ///
  /// In en, this message translates to:
  /// **'Enough darts measured – the diagnosis is complete.'**
  String get diagnosisEnough;

  /// No description provided for @finishDiagnosis.
  ///
  /// In en, this message translates to:
  /// **'Finish the diagnosis'**
  String get finishDiagnosis;

  /// No description provided for @diagnosisMoreDartsOptional.
  ///
  /// In en, this message translates to:
  /// **'More darts are possible, but not needed.'**
  String get diagnosisMoreDartsOptional;

  /// No description provided for @diagnosisFinished.
  ///
  /// In en, this message translates to:
  /// **'Diagnosis finished'**
  String get diagnosisFinished;

  /// No description provided for @resultProblems.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 problem found} other{{count} problems found}}'**
  String resultProblems(int count);

  /// No description provided for @resultWarnings.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 warning} other{{count} warnings}}'**
  String resultWarnings(int count);

  /// No description provided for @resultFixHint.
  ///
  /// In en, this message translates to:
  /// **'The findings below say what to do. Run the diagnosis again afterwards.'**
  String get resultFixHint;

  /// No description provided for @resultAllGood.
  ///
  /// In en, this message translates to:
  /// **'All good'**
  String get resultAllGood;

  /// No description provided for @resultAllGoodHint.
  ///
  /// In en, this message translates to:
  /// **'The setup is ready to play.'**
  String get resultAllGoodHint;

  /// No description provided for @resultFewDarts.
  ///
  /// In en, this message translates to:
  /// **'Only {done} of {target} darts measured; the findings on darts are less certain.'**
  String resultFewDarts(int done, int target);

  /// No description provided for @navStatistics.
  ///
  /// In en, this message translates to:
  /// **'Players'**
  String get navStatistics;

  /// No description provided for @statisticsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No players yet. Create a profile; every game counts for its statistics.'**
  String get statisticsEmpty;

  /// No description provided for @statsGamesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 game} other{{count} games}}'**
  String statsGamesCount(int count);

  /// No description provided for @statsGames.
  ///
  /// In en, this message translates to:
  /// **'Games'**
  String get statsGames;

  /// No description provided for @statsWon.
  ///
  /// In en, this message translates to:
  /// **'{count} won'**
  String statsWon(int count);

  /// No description provided for @statsDarts.
  ///
  /// In en, this message translates to:
  /// **'Darts'**
  String get statsDarts;

  /// No description provided for @statsFirst9.
  ///
  /// In en, this message translates to:
  /// **'First 9 average'**
  String get statsFirst9;

  /// No description provided for @statsLegs.
  ///
  /// In en, this message translates to:
  /// **'Legs'**
  String get statsLegs;

  /// No description provided for @statsBestLeg.
  ///
  /// In en, this message translates to:
  /// **'Best leg'**
  String get statsBestLeg;

  /// No description provided for @statsDartsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 dart} other{{count} darts}}'**
  String statsDartsCount(int count);

  /// No description provided for @statsCheckoutRate.
  ///
  /// In en, this message translates to:
  /// **'Checkout rate'**
  String get statsCheckoutRate;

  /// No description provided for @statsHighestFinish.
  ///
  /// In en, this message translates to:
  /// **'Highest finish'**
  String get statsHighestFinish;

  /// No description provided for @statsMarksPerRound.
  ///
  /// In en, this message translates to:
  /// **'Marks per round'**
  String get statsMarksPerRound;

  /// No description provided for @statsClockHitRate.
  ///
  /// In en, this message translates to:
  /// **'Around the Clock hits'**
  String get statsClockHitRate;

  /// No description provided for @periodLastGame.
  ///
  /// In en, this message translates to:
  /// **'Last game'**
  String get periodLastGame;

  /// No description provided for @periodWeek.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get periodWeek;

  /// No description provided for @periodMonth.
  ///
  /// In en, this message translates to:
  /// **'30 days'**
  String get periodMonth;

  /// No description provided for @periodAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get periodAll;

  /// No description provided for @statsNoGamesInPeriod.
  ///
  /// In en, this message translates to:
  /// **'No games in this period.'**
  String get statsNoGamesInPeriod;

  /// No description provided for @statsHits.
  ///
  /// In en, this message translates to:
  /// **'Where the darts landed'**
  String get statsHits;

  /// No description provided for @ringTriple.
  ///
  /// In en, this message translates to:
  /// **'Triple'**
  String get ringTriple;

  /// No description provided for @ringDouble.
  ///
  /// In en, this message translates to:
  /// **'Double'**
  String get ringDouble;

  /// No description provided for @ringSingleInner.
  ///
  /// In en, this message translates to:
  /// **'Single (inner)'**
  String get ringSingleInner;

  /// No description provided for @ringSingleOuter.
  ///
  /// In en, this message translates to:
  /// **'Single (outer)'**
  String get ringSingleOuter;

  /// No description provided for @ringOuterBull.
  ///
  /// In en, this message translates to:
  /// **'Outer bull'**
  String get ringOuterBull;

  /// No description provided for @ringBull.
  ///
  /// In en, this message translates to:
  /// **'Bull'**
  String get ringBull;

  /// No description provided for @ringMiss.
  ///
  /// In en, this message translates to:
  /// **'Miss'**
  String get ringMiss;

  /// No description provided for @statsFavouriteDoubles.
  ///
  /// In en, this message translates to:
  /// **'Finished on'**
  String get statsFavouriteDoubles;

  /// No description provided for @statsHistory.
  ///
  /// In en, this message translates to:
  /// **'Games'**
  String get statsHistory;

  /// No description provided for @statsOpponents.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{against 1 player} other{against {count} players}}'**
  String statsOpponents(int count);

  /// No description provided for @statsSolo.
  ///
  /// In en, this message translates to:
  /// **'solo'**
  String get statsSolo;

  /// No description provided for @localEngineNoAnswer.
  ///
  /// In en, this message translates to:
  /// **'The program did not answer as the engine and was stopped. Check the engine program under Log.'**
  String get localEngineNoAnswer;

  /// No description provided for @newProfile.
  ///
  /// In en, this message translates to:
  /// **'New profile'**
  String get newProfile;

  /// No description provided for @profileName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get profileName;

  /// No description provided for @profileNameEmpty.
  ///
  /// In en, this message translates to:
  /// **'Enter a name.'**
  String get profileNameEmpty;

  /// No description provided for @profileNameExists.
  ///
  /// In en, this message translates to:
  /// **'There is a profile with this name already.'**
  String get profileNameExists;

  /// No description provided for @createProfile.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get createProfile;

  /// No description provided for @pickPlayersHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the players in the order they throw.'**
  String get pickPlayersHint;

  /// No description provided for @throwingOrder.
  ///
  /// In en, this message translates to:
  /// **'Order: {order}'**
  String throwingOrder(String order);

  /// No description provided for @statsNoGamesYet.
  ///
  /// In en, this message translates to:
  /// **'No games yet'**
  String get statsNoGamesYet;

  /// No description provided for @deleteProfile.
  ///
  /// In en, this message translates to:
  /// **'Delete profile'**
  String get deleteProfile;

  /// No description provided for @deleteProfileText.
  ///
  /// In en, this message translates to:
  /// **'{name} is removed from the players. The games stay kept and count again if a profile with this name is created.'**
  String deleteProfileText(String name);

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @firstProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Who is playing?'**
  String get firstProfileTitle;

  /// No description provided for @firstProfileText.
  ///
  /// In en, this message translates to:
  /// **'Create a player profile; every game counts for its statistics.'**
  String get firstProfileText;

  /// No description provided for @calibStepLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get calibStepLight;

  /// No description provided for @calibStepBoard.
  ///
  /// In en, this message translates to:
  /// **'Board'**
  String get calibStepBoard;

  /// No description provided for @calibStepRefine.
  ///
  /// In en, this message translates to:
  /// **'Refine'**
  String get calibStepRefine;

  /// No description provided for @calibStepDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get calibStepDone;

  /// No description provided for @calibNeedsCameras.
  ///
  /// In en, this message translates to:
  /// **'Calibration needs an engine with cameras. Connect one first.'**
  String get calibNeedsCameras;

  /// No description provided for @calibIntro.
  ///
  /// In en, this message translates to:
  /// **'The engine measures the board from every camera: no target to hold, no measuring tape. You need an empty board and the light you play in; it takes a few minutes.'**
  String get calibIntro;

  /// No description provided for @calibStale.
  ///
  /// In en, this message translates to:
  /// **'A camera was measured again after the last refinement: refine all cameras once more.'**
  String get calibStale;

  /// No description provided for @calibBoardMissing.
  ///
  /// In en, this message translates to:
  /// **'board not measured'**
  String get calibBoardMissing;

  /// No description provided for @calibBoardMeasured.
  ///
  /// In en, this message translates to:
  /// **'board {mm} mm'**
  String calibBoardMeasured(String mm);

  /// No description provided for @calibLensOwn.
  ///
  /// In en, this message translates to:
  /// **'own lens calibration'**
  String get calibLensOwn;

  /// No description provided for @calibLensNone.
  ///
  /// In en, this message translates to:
  /// **'no lens calibration'**
  String get calibLensNone;

  /// No description provided for @calibStart.
  ///
  /// In en, this message translates to:
  /// **'Start calibration'**
  String get calibStart;

  /// No description provided for @calibLightInstruction.
  ///
  /// In en, this message translates to:
  /// **'Empty the board and switch on the light you play in.'**
  String get calibLightInstruction;

  /// No description provided for @calibLightHint.
  ///
  /// In en, this message translates to:
  /// **'The engine tries every colour temperature on all cameras and keeps the one in the middle of where the board is found. This takes about a minute.'**
  String get calibLightHint;

  /// No description provided for @calibLightSettling.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the cameras\' exposure: {seconds} s'**
  String calibLightSettling(int seconds);

  /// No description provided for @calibLightSweeping.
  ///
  /// In en, this message translates to:
  /// **'Trying {kelvin} K …'**
  String calibLightSweeping(int kelvin);

  /// No description provided for @calibLightDone.
  ///
  /// In en, this message translates to:
  /// **'Light set for every camera.'**
  String get calibLightDone;

  /// No description provided for @calibLightFailed.
  ///
  /// In en, this message translates to:
  /// **'The light could not be set.'**
  String get calibLightFailed;

  /// No description provided for @calibLightNotFound.
  ///
  /// In en, this message translates to:
  /// **'board not found'**
  String get calibLightNotFound;

  /// No description provided for @calibLightTune.
  ///
  /// In en, this message translates to:
  /// **'Set the light'**
  String get calibLightTune;

  /// No description provided for @calibLightAgain.
  ///
  /// In en, this message translates to:
  /// **'Set again'**
  String get calibLightAgain;

  /// No description provided for @calibNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get calibNext;

  /// No description provided for @calibCameraOf.
  ///
  /// In en, this message translates to:
  /// **'Camera {number} of {count}'**
  String calibCameraOf(int number, int count);

  /// No description provided for @calibBoardDetectInstruction.
  ///
  /// In en, this message translates to:
  /// **'Keep the board empty, hand out of view, and detect it.'**
  String get calibBoardDetectInstruction;

  /// No description provided for @calibBoardDetectHint.
  ///
  /// In en, this message translates to:
  /// **'The engine finds the rings and the 20 wires of the board in this camera\'s image.'**
  String get calibBoardDetectHint;

  /// No description provided for @calibBoardTap20.
  ///
  /// In en, this message translates to:
  /// **'Tap into the field of the 20.'**
  String get calibBoardTap20;

  /// No description provided for @calibBoardTap20Hint.
  ///
  /// In en, this message translates to:
  /// **'Anywhere between the bull and the double ring. The colours repeat every second field, so the engine needs to be told which one is the 20.'**
  String get calibBoardTap20Hint;

  /// No description provided for @calibBoardCheck.
  ///
  /// In en, this message translates to:
  /// **'Do the numbers match the board?'**
  String get calibBoardCheck;

  /// No description provided for @calibBoardCheckHint.
  ///
  /// In en, this message translates to:
  /// **'If not, tap into the 20 again.'**
  String get calibBoardCheckHint;

  /// No description provided for @calibBoardNotFound.
  ///
  /// In en, this message translates to:
  /// **'Board not found: remove all darts, keep the hand out of view, and check the light (step 1).'**
  String get calibBoardNotFound;

  /// No description provided for @calibBoardFit.
  ///
  /// In en, this message translates to:
  /// **'Board fit {fit} mm (worst {worst} mm)'**
  String calibBoardFit(String fit, String worst);

  /// No description provided for @calibBoardDetect.
  ///
  /// In en, this message translates to:
  /// **'Detect the board'**
  String get calibBoardDetect;

  /// No description provided for @calibBoardDetectAgain.
  ///
  /// In en, this message translates to:
  /// **'Detect again'**
  String get calibBoardDetectAgain;

  /// No description provided for @calibNumbersMatchNext.
  ///
  /// In en, this message translates to:
  /// **'Numbers match – next camera'**
  String get calibNumbersMatchNext;

  /// No description provided for @calibNumbersMatchRefine.
  ///
  /// In en, this message translates to:
  /// **'Numbers match – refine'**
  String get calibNumbersMatchRefine;

  /// No description provided for @calibRefineInstruction.
  ///
  /// In en, this message translates to:
  /// **'Refine all cameras together.'**
  String get calibRefineInstruction;

  /// No description provided for @calibRefineHint.
  ///
  /// In en, this message translates to:
  /// **'From the boards of all cameras the engine computes every camera\'s position and lens, and the real size of your board.'**
  String get calibRefineHint;

  /// No description provided for @calibQualityGood.
  ///
  /// In en, this message translates to:
  /// **'good'**
  String get calibQualityGood;

  /// No description provided for @calibQualityFair.
  ///
  /// In en, this message translates to:
  /// **'usable'**
  String get calibQualityFair;

  /// No description provided for @calibQualityPoor.
  ///
  /// In en, this message translates to:
  /// **'not good enough'**
  String get calibQualityPoor;

  /// No description provided for @calibLensFromOwn.
  ///
  /// In en, this message translates to:
  /// **'Lens from its own lens calibration'**
  String get calibLensFromOwn;

  /// No description provided for @calibLensFromModel.
  ///
  /// In en, this message translates to:
  /// **'Lens from another camera of the same model'**
  String get calibLensFromModel;

  /// No description provided for @calibLensFromBoard.
  ///
  /// In en, this message translates to:
  /// **'Lens from the board only'**
  String get calibLensFromBoard;

  /// No description provided for @calibAdviceDetectAgain.
  ///
  /// In en, this message translates to:
  /// **'Measure the board of this camera again in even light.'**
  String get calibAdviceDetectAgain;

  /// No description provided for @calibAdviceLens.
  ///
  /// In en, this message translates to:
  /// **'A lens calibration of this camera would make it more accurate.'**
  String get calibAdviceLens;

  /// No description provided for @calibMeasureAgain.
  ///
  /// In en, this message translates to:
  /// **'Measure again'**
  String get calibMeasureAgain;

  /// No description provided for @calibMeasuredBoard.
  ///
  /// In en, this message translates to:
  /// **'Your board: outer bull {bull} mm, treble centre {treble} mm'**
  String calibMeasuredBoard(String bull, String treble);

  /// No description provided for @calibRefine.
  ///
  /// In en, this message translates to:
  /// **'Refine'**
  String get calibRefine;

  /// No description provided for @calibRefineAgain.
  ///
  /// In en, this message translates to:
  /// **'Refine again'**
  String get calibRefineAgain;

  /// No description provided for @calibDone.
  ///
  /// In en, this message translates to:
  /// **'The cameras are calibrated.'**
  String get calibDone;

  /// No description provided for @calibDoneHint.
  ///
  /// In en, this message translates to:
  /// **'Check the whole setup with a few darts in the setup diagnosis.'**
  String get calibDoneHint;

  /// No description provided for @calibErrorBusy.
  ///
  /// In en, this message translates to:
  /// **'The engine is still busy with another step.'**
  String get calibErrorBusy;

  /// No description provided for @calibErrorNoDetection.
  ///
  /// In en, this message translates to:
  /// **'Detect the board first.'**
  String get calibErrorNoDetection;

  /// No description provided for @calibErrorOutsideBoard.
  ///
  /// In en, this message translates to:
  /// **'That point is not in a field of the board; tap into the 20 between bull and double ring.'**
  String get calibErrorOutsideBoard;

  /// No description provided for @calibErrorFitFailed.
  ///
  /// In en, this message translates to:
  /// **'The board could not be fitted; detect it again.'**
  String get calibErrorFitFailed;

  /// No description provided for @calibErrorNoBoardPlanes.
  ///
  /// In en, this message translates to:
  /// **'No camera has a measured board yet.'**
  String get calibErrorNoBoardPlanes;

  /// No description provided for @calibErrorPoseFailed.
  ///
  /// In en, this message translates to:
  /// **'A camera could not be placed; measure its board again.'**
  String get calibErrorPoseFailed;

  /// No description provided for @calibErrorSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'The calibration could not be saved.'**
  String get calibErrorSaveFailed;

  /// No description provided for @calibErrorOther.
  ///
  /// In en, this message translates to:
  /// **'Failed ({code}).'**
  String calibErrorOther(String code);

  /// No description provided for @calibrationHint.
  ///
  /// In en, this message translates to:
  /// **'Light, board and refinement, step by step'**
  String get calibrationHint;

  /// No description provided for @addBot.
  ///
  /// In en, this message translates to:
  /// **'Bot'**
  String get addBot;

  /// No description provided for @botDifficulty.
  ///
  /// In en, this message translates to:
  /// **'Difficulty'**
  String get botDifficulty;

  /// No description provided for @botAverage.
  ///
  /// In en, this message translates to:
  /// **'Average about {average}'**
  String botAverage(int average);

  /// No description provided for @botName.
  ///
  /// In en, this message translates to:
  /// **'Bot · {name}'**
  String botName(int level, String name);

  /// No description provided for @statsAgainstBots.
  ///
  /// In en, this message translates to:
  /// **'against bot level {levels}'**
  String statsAgainstBots(String levels);

  /// No description provided for @botLevel1.
  ///
  /// In en, this message translates to:
  /// **'Beginner'**
  String get botLevel1;

  /// No description provided for @botLevel2.
  ///
  /// In en, this message translates to:
  /// **'Occasional player'**
  String get botLevel2;

  /// No description provided for @botLevel3.
  ///
  /// In en, this message translates to:
  /// **'Pub player'**
  String get botLevel3;

  /// No description provided for @botLevel4.
  ///
  /// In en, this message translates to:
  /// **'Hobby player'**
  String get botLevel4;

  /// No description provided for @botLevel5.
  ///
  /// In en, this message translates to:
  /// **'Club player'**
  String get botLevel5;

  /// No description provided for @botLevel6.
  ///
  /// In en, this message translates to:
  /// **'League player'**
  String get botLevel6;

  /// No description provided for @botLevel7.
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get botLevel7;

  /// No description provided for @botLevel8.
  ///
  /// In en, this message translates to:
  /// **'Very strong'**
  String get botLevel8;

  /// No description provided for @botLevel9.
  ///
  /// In en, this message translates to:
  /// **'Semi-pro'**
  String get botLevel9;

  /// No description provided for @botLevel10.
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get botLevel10;

  /// No description provided for @calibrationCheck.
  ///
  /// In en, this message translates to:
  /// **'Calibration check'**
  String get calibrationCheck;

  /// No description provided for @calibrationCheckHint.
  ///
  /// In en, this message translates to:
  /// **'Has a camera moved? Every camera against its calibration'**
  String get calibrationCheckHint;

  /// No description provided for @calibrationCheckIntro.
  ///
  /// In en, this message translates to:
  /// **'Keep the board empty. Blue rings show where the calibration expects the board\'s points, green dots where they are now; long amber lines mean the camera or the board has moved. The engine also checks this in the background whenever the board is empty.'**
  String get calibrationCheckIntro;

  /// No description provided for @checkOk.
  ///
  /// In en, this message translates to:
  /// **'Matches the calibration ({mm} mm).'**
  String checkOk(String mm);

  /// No description provided for @checkOff.
  ///
  /// In en, this message translates to:
  /// **'Slightly off ({mm} mm), e.g. other light. Detection still works.'**
  String checkOff(String mm);

  /// No description provided for @checkMoved.
  ///
  /// In en, this message translates to:
  /// **'The camera or the board has moved ({mm} mm). Measure this camera again.'**
  String checkMoved(String mm);

  /// No description provided for @checkWrongPort.
  ///
  /// In en, this message translates to:
  /// **'Wrong USB port? This image fits the calibration of camera {camera}.'**
  String checkWrongPort(String camera);

  /// No description provided for @checkNoBoard.
  ///
  /// In en, this message translates to:
  /// **'No board found – darts in the board or a hand in view?'**
  String get checkNoBoard;

  /// No description provided for @checkNotCalibrated.
  ///
  /// In en, this message translates to:
  /// **'Not calibrated yet.'**
  String get checkNotCalibrated;

  /// No description provided for @checkChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking …'**
  String get checkChecking;

  /// No description provided for @referenceRun.
  ///
  /// In en, this message translates to:
  /// **'Reference measurement'**
  String get referenceRun;

  /// No description provided for @settingsReferenceHint.
  ///
  /// In en, this message translates to:
  /// **'How accurate is the detection? Darts in known positions show it in millimetres'**
  String get settingsReferenceHint;

  /// No description provided for @referenceIntro.
  ///
  /// In en, this message translates to:
  /// **'You push one dart after the other by hand into a known position: the centre of the bull, then corners where a radial wire meets a ring wire. The engine locates every dart, and the distance from the position is the error of the whole system, from calibration to tip. Ten darts take about five minutes; the board must be calibrated.'**
  String get referenceIntro;

  /// No description provided for @referenceWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the next position…'**
  String get referenceWaiting;

  /// No description provided for @referenceStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped after {count, plural, =1{1 dart} other{{count} darts}}. Start again for a verdict.'**
  String referenceStopped(int count);

  /// No description provided for @referenceNotCalibrated.
  ///
  /// In en, this message translates to:
  /// **'Calibrate the cameras first (Settings → Calibration).'**
  String get referenceNotCalibrated;

  /// No description provided for @referenceProgress.
  ///
  /// In en, this message translates to:
  /// **'Dart {number} of {total}'**
  String referenceProgress(int number, int total);

  /// No description provided for @referenceBullCentre.
  ///
  /// In en, this message translates to:
  /// **'Push a dart into the very centre of the bull, then take your hand away.'**
  String get referenceBullCentre;

  /// No description provided for @referenceCorner.
  ///
  /// In en, this message translates to:
  /// **'Push a dart into {field}, into the corner at the wire between {a} and {b}, then take your hand away.'**
  String referenceCorner(String field, int a, int b);

  /// No description provided for @referenceCornerHint.
  ///
  /// In en, this message translates to:
  /// **'The point touches both wires: the radial wire and the ring wire. Push it in by hand, do not throw.'**
  String get referenceCornerHint;

  /// No description provided for @referenceResults.
  ///
  /// In en, this message translates to:
  /// **'Measured darts'**
  String get referenceResults;

  /// No description provided for @referenceAbstained.
  ///
  /// In en, this message translates to:
  /// **'Not located'**
  String get referenceAbstained;

  /// No description provided for @referenceError.
  ///
  /// In en, this message translates to:
  /// **'{mm} mm off'**
  String referenceError(String mm);

  /// No description provided for @referenceCamerasUsed.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 camera} other{{count} cameras}}'**
  String referenceCamerasUsed(int count);

  /// No description provided for @referenceLocated.
  ///
  /// In en, this message translates to:
  /// **'Located'**
  String get referenceLocated;

  /// No description provided for @referenceMedian.
  ///
  /// In en, this message translates to:
  /// **'Median error'**
  String get referenceMedian;

  /// No description provided for @referenceP90.
  ///
  /// In en, this message translates to:
  /// **'90 % within'**
  String get referenceP90;

  /// No description provided for @referenceMax.
  ///
  /// In en, this message translates to:
  /// **'Worst'**
  String get referenceMax;

  /// No description provided for @referenceGood.
  ///
  /// In en, this message translates to:
  /// **'The detection is accurate.'**
  String get referenceGood;

  /// No description provided for @referenceNotGood.
  ///
  /// In en, this message translates to:
  /// **'The detection is not accurate enough yet.'**
  String get referenceNotGood;

  /// No description provided for @referenceNotGoodHint.
  ///
  /// In en, this message translates to:
  /// **'Run the setup diagnosis to see where the error comes from, then calibrate the cameras it names again.'**
  String get referenceNotGoodHint;

  /// No description provided for @referenceCamerasDisagree.
  ///
  /// In en, this message translates to:
  /// **'The cameras disagree about where it is'**
  String get referenceCamerasDisagree;

  /// No description provided for @referenceSeenByOneCamera.
  ///
  /// In en, this message translates to:
  /// **'Only one camera saw it'**
  String get referenceSeenByOneCamera;

  /// No description provided for @cameraMovedNotice.
  ///
  /// In en, this message translates to:
  /// **'{camera} was moved – its calibration is being checked.'**
  String cameraMovedNotice(String camera);

  /// No description provided for @rigKnockedNotice.
  ///
  /// In en, this message translates to:
  /// **'The rig was knocked – the calibration is being checked.'**
  String get rigKnockedNotice;

  /// No description provided for @simulateDarts.
  ///
  /// In en, this message translates to:
  /// **'Simulate darts'**
  String get simulateDarts;

  /// No description provided for @simulateDartsHint.
  ///
  /// In en, this message translates to:
  /// **'For trying the app: the engine plays generated darts instead of detecting them.'**
  String get simulateDartsHint;

  /// No description provided for @localEngineLiveUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This engine cannot detect darts yet. Switch on \"Simulate darts\", or update the engine.'**
  String get localEngineLiveUnavailable;

  /// No description provided for @detectionPaused.
  ///
  /// In en, this message translates to:
  /// **'Detection paused'**
  String get detectionPaused;

  /// No description provided for @detectionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Darts are not detected right now.'**
  String get detectionUnavailable;

  /// No description provided for @shareEngine.
  ///
  /// In en, this message translates to:
  /// **'Share in the network'**
  String get shareEngine;

  /// No description provided for @shareEngineHint.
  ///
  /// In en, this message translates to:
  /// **'Phones and tablets in your home network can connect to this engine. Only in a network you trust: there is no PIN yet.'**
  String get shareEngineHint;

  /// No description provided for @showEngineQr.
  ///
  /// In en, this message translates to:
  /// **'QR code'**
  String get showEngineQr;

  /// No description provided for @engineQrTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect another device'**
  String get engineQrTitle;

  /// No description provided for @engineQrHint.
  ///
  /// In en, this message translates to:
  /// **'Scan this code with the DartPilot app on your phone or tablet (Engine → In the network → scan).'**
  String get engineQrHint;

  /// No description provided for @engineQrNoNetwork.
  ///
  /// In en, this message translates to:
  /// **'This device has no address in a home network.'**
  String get engineQrNoNetwork;

  /// No description provided for @scanEngineQr.
  ///
  /// In en, this message translates to:
  /// **'Scan QR code'**
  String get scanEngineQr;

  /// No description provided for @scanEngineQrUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The camera cannot be used to scan. Allow the camera for DartPilot, or type the address shown under the QR code.'**
  String get scanEngineQrUnavailable;

  /// No description provided for @scanEngineQrHint.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at the QR code that the engine\'s device shows.'**
  String get scanEngineQrHint;

  /// No description provided for @enterAddressManually.
  ///
  /// In en, this message translates to:
  /// **'Enter the address or scan a QR code'**
  String get enterAddressManually;

  /// No description provided for @restartEngine.
  ///
  /// In en, this message translates to:
  /// **'Restart the engine'**
  String get restartEngine;

  /// No description provided for @engineSettings.
  ///
  /// In en, this message translates to:
  /// **'Engine'**
  String get engineSettings;

  /// No description provided for @assignCameras.
  ///
  /// In en, this message translates to:
  /// **'Assign cameras'**
  String get assignCameras;

  /// No description provided for @assignCamerasHint.
  ///
  /// In en, this message translates to:
  /// **'Each camera gets its place: camera 1, 2, 3. The live image shows which is which. The arrows swap two cameras, and a name helps to find one again.'**
  String get assignCamerasHint;

  /// No description provided for @cameraNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name (optional)'**
  String get cameraNameLabel;

  /// No description provided for @moveCameraUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get moveCameraUp;

  /// No description provided for @moveCameraDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get moveCameraDown;

  /// No description provided for @saveCameraOrder.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get saveCameraOrder;

  /// No description provided for @statsAverageTrend.
  ///
  /// In en, this message translates to:
  /// **'Average over games (X01)'**
  String get statsAverageTrend;

  /// No description provided for @statsHitBoard.
  ///
  /// In en, this message translates to:
  /// **'Hit board'**
  String get statsHitBoard;

  /// No description provided for @statsMisses.
  ///
  /// In en, this message translates to:
  /// **'Misses: {count}'**
  String statsMisses(int count);

  /// No description provided for @statsExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get statsExport;

  /// No description provided for @exportDartsCsv.
  ///
  /// In en, this message translates to:
  /// **'All darts as CSV'**
  String get exportDartsCsv;

  /// No description provided for @exportGamesJson.
  ///
  /// In en, this message translates to:
  /// **'Games and figures as JSON'**
  String get exportGamesJson;

  /// No description provided for @exportSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved: {path}'**
  String exportSaved(String path);

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String exportFailed(String error);

  /// No description provided for @copyPath.
  ///
  /// In en, this message translates to:
  /// **'Copy path'**
  String get copyPath;

  /// No description provided for @myDarts.
  ///
  /// In en, this message translates to:
  /// **'My darts'**
  String get myDarts;

  /// No description provided for @myDartsHint.
  ///
  /// In en, this message translates to:
  /// **'Measure your darts so that detection finds them better'**
  String get myDartsHint;

  /// No description provided for @myDartsIntro.
  ///
  /// In en, this message translates to:
  /// **'Optional: the engine measures a dart set (point, barrel, length, appearance). It then finds the point more precisely and tells new darts from those in the board. Without a set it detects any dart as before.'**
  String get myDartsIntro;

  /// No description provided for @dartSetsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This engine cannot measure darts yet.'**
  String get dartSetsUnavailable;

  /// No description provided for @noDartSets.
  ///
  /// In en, this message translates to:
  /// **'No dart set measured yet.'**
  String get noDartSets;

  /// No description provided for @addDartSet.
  ///
  /// In en, this message translates to:
  /// **'Add dart set'**
  String get addDartSet;

  /// No description provided for @renameDartSet.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get renameDartSet;

  /// No description provided for @deleteDartSetTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String deleteDartSetTitle(String name);

  /// No description provided for @deleteDartSetText.
  ///
  /// In en, this message translates to:
  /// **'Its dimensions and reference images are deleted on the engine; players who throw it keep their games.'**
  String get deleteDartSetText;

  /// No description provided for @dartSetName.
  ///
  /// In en, this message translates to:
  /// **'Name of the set'**
  String get dartSetName;

  /// No description provided for @dartSetNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Anna\'s darts'**
  String get dartSetNameHint;

  /// No description provided for @dartSetStart.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get dartSetStart;

  /// No description provided for @dartSetInUse.
  ///
  /// In en, this message translates to:
  /// **'in use'**
  String get dartSetInUse;

  /// No description provided for @dartSetThrownBy.
  ///
  /// In en, this message translates to:
  /// **'Thrown by:'**
  String get dartSetThrownBy;

  /// No description provided for @dartPoint.
  ///
  /// In en, this message translates to:
  /// **'Point'**
  String get dartPoint;

  /// No description provided for @dartBarrel.
  ///
  /// In en, this message translates to:
  /// **'Barrel'**
  String get dartBarrel;

  /// No description provided for @dartTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get dartTotal;

  /// No description provided for @dartSetPutIn.
  ///
  /// In en, this message translates to:
  /// **'Put one dart of the set into the board and take your hand away.'**
  String get dartSetPutIn;

  /// No description provided for @dartSetMeasuring.
  ///
  /// In en, this message translates to:
  /// **'Measuring …'**
  String get dartSetMeasuring;

  /// No description provided for @dartSetPlaced.
  ///
  /// In en, this message translates to:
  /// **'Measured. Pull the dart and put it in somewhere else.'**
  String get dartSetPlaced;

  /// No description provided for @dartSetDone.
  ///
  /// In en, this message translates to:
  /// **'Done – the set is measured.'**
  String get dartSetDone;

  /// No description provided for @dartSetProgress.
  ///
  /// In en, this message translates to:
  /// **'{placed} of {needed} places'**
  String dartSetProgress(int placed, int needed);

  /// No description provided for @dartSetClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get dartSetClose;

  /// No description provided for @dartSetNotCalibrated.
  ///
  /// In en, this message translates to:
  /// **'The cameras are not calibrated yet.'**
  String get dartSetNotCalibrated;

  /// No description provided for @dartSetBoardNotEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please pull all darts out of the board first.'**
  String get dartSetBoardNotEmpty;

  /// No description provided for @dartSetBusy.
  ///
  /// In en, this message translates to:
  /// **'The engine is busy. Try again in a moment.'**
  String get dartSetBusy;

  /// No description provided for @dartSetFailed.
  ///
  /// In en, this message translates to:
  /// **'Measuring failed: {reason}'**
  String dartSetFailed(String reason);

  /// No description provided for @dartFlight.
  ///
  /// In en, this message translates to:
  /// **'Flight'**
  String get dartFlight;

  /// No description provided for @dartSetPlacementFailed.
  ///
  /// In en, this message translates to:
  /// **'{reason} Pull the dart and put it in somewhere else.'**
  String dartSetPlacementFailed(String reason);

  /// No description provided for @dartSetCamerasDisagree.
  ///
  /// In en, this message translates to:
  /// **'The cameras did not agree.'**
  String get dartSetCamerasDisagree;

  /// No description provided for @dartSetSeenByOne.
  ///
  /// In en, this message translates to:
  /// **'Only one camera saw the dart.'**
  String get dartSetSeenByOne;

  /// No description provided for @dartSetPlacementsDisagree.
  ///
  /// In en, this message translates to:
  /// **'This place does not fit the other measurements.'**
  String get dartSetPlacementsDisagree;

  /// No description provided for @dartSetNotMeasured.
  ///
  /// In en, this message translates to:
  /// **'The dart could not be measured here.'**
  String get dartSetNotMeasured;

  /// No description provided for @dartSetSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'The set could not be saved.'**
  String get dartSetSaveFailed;

  /// No description provided for @dartSetBoardStillOccupied.
  ///
  /// In en, this message translates to:
  /// **'The engine still sees something in the board. If it is empty, store the empty board again – otherwise the measurement cannot go on.'**
  String get dartSetBoardStillOccupied;

  /// No description provided for @dartMeasureUncertain.
  ///
  /// In en, this message translates to:
  /// **'uncertain'**
  String get dartMeasureUncertain;

  /// No description provided for @pairTitle.
  ///
  /// In en, this message translates to:
  /// **'Pair with the engine'**
  String get pairTitle;

  /// No description provided for @pairText.
  ///
  /// In en, this message translates to:
  /// **'The engine at {address} only accepts paired devices. Enter the PIN its device shows – this is needed only once.'**
  String pairText(String address);

  /// No description provided for @pairPin.
  ///
  /// In en, this message translates to:
  /// **'PIN'**
  String get pairPin;

  /// No description provided for @pairButton.
  ///
  /// In en, this message translates to:
  /// **'Pair'**
  String get pairButton;

  /// No description provided for @pairWrongPin.
  ///
  /// In en, this message translates to:
  /// **'The PIN is wrong. Look at the engine\'s device again.'**
  String get pairWrongPin;

  /// No description provided for @pairTooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many wrong attempts. Wait a minute.'**
  String get pairTooManyAttempts;

  /// No description provided for @pairFailed.
  ///
  /// In en, this message translates to:
  /// **'Pairing failed: {error}'**
  String pairFailed(String error);

  /// No description provided for @engineQrPin.
  ///
  /// In en, this message translates to:
  /// **'PIN for other devices: {pin}'**
  String engineQrPin(String pin);

  /// No description provided for @pairedDevices.
  ///
  /// In en, this message translates to:
  /// **'Paired devices'**
  String get pairedDevices;

  /// No description provided for @noPairedDevices.
  ///
  /// In en, this message translates to:
  /// **'No device paired yet.'**
  String get noPairedDevices;

  /// No description provided for @pairedDeviceSeen.
  ///
  /// In en, this message translates to:
  /// **'last {when}'**
  String pairedDeviceSeen(String when);

  /// No description provided for @unpairDevice.
  ///
  /// In en, this message translates to:
  /// **'Unpair'**
  String get unpairDevice;

  /// No description provided for @watchGame.
  ///
  /// In en, this message translates to:
  /// **'Watching'**
  String get watchGame;

  /// No description provided for @sharedGameEnded.
  ///
  /// In en, this message translates to:
  /// **'The game on the other display has ended.'**
  String get sharedGameEnded;

  /// No description provided for @watchGameTitle.
  ///
  /// In en, this message translates to:
  /// **'Watch the running game: {mode}'**
  String watchGameTitle(String mode);

  /// No description provided for @scoreCaller.
  ///
  /// In en, this message translates to:
  /// **'Score caller'**
  String get scoreCaller;

  /// No description provided for @settingsDisplay.
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get settingsDisplay;

  /// No description provided for @appearancePreset.
  ///
  /// In en, this message translates to:
  /// **'Starting point'**
  String get appearancePreset;

  /// No description provided for @appearancePresetHint.
  ///
  /// In en, this message translates to:
  /// **'Pick one and change single values below. Reset returns to it.'**
  String get appearancePresetHint;

  /// No description provided for @presetStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get presetStandard;

  /// No description provided for @presetLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get presetLight;

  /// No description provided for @presetHighContrast.
  ///
  /// In en, this message translates to:
  /// **'High contrast'**
  String get presetHighContrast;

  /// No description provided for @presetScoreboard.
  ///
  /// In en, this message translates to:
  /// **'Scoreboard'**
  String get presetScoreboard;

  /// No description provided for @appearanceReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get appearanceReset;

  /// No description provided for @highContrast.
  ///
  /// In en, this message translates to:
  /// **'High contrast'**
  String get highContrast;

  /// No description provided for @highContrastHint.
  ///
  /// In en, this message translates to:
  /// **'Pure black and white with stronger borders'**
  String get highContrastHint;

  /// No description provided for @accentColour.
  ///
  /// In en, this message translates to:
  /// **'Accent colour'**
  String get accentColour;

  /// No description provided for @accentCustom.
  ///
  /// In en, this message translates to:
  /// **'Own colour'**
  String get accentCustom;

  /// No description provided for @accentHue.
  ///
  /// In en, this message translates to:
  /// **'Hue'**
  String get accentHue;

  /// No description provided for @accentApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get accentApply;

  /// No description provided for @accentAdjusted.
  ///
  /// In en, this message translates to:
  /// **'Made lighter or darker so that text stays readable.'**
  String get accentAdjusted;

  /// No description provided for @accentSky.
  ///
  /// In en, this message translates to:
  /// **'Sky blue'**
  String get accentSky;

  /// No description provided for @accentGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get accentGreen;

  /// No description provided for @accentTeal.
  ///
  /// In en, this message translates to:
  /// **'Teal'**
  String get accentTeal;

  /// No description provided for @accentViolet.
  ///
  /// In en, this message translates to:
  /// **'Violet'**
  String get accentViolet;

  /// No description provided for @accentPink.
  ///
  /// In en, this message translates to:
  /// **'Pink'**
  String get accentPink;

  /// No description provided for @accentOrange.
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get accentOrange;

  /// No description provided for @accentRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get accentRed;

  /// No description provided for @accentGold.
  ///
  /// In en, this message translates to:
  /// **'Gold'**
  String get accentGold;

  /// No description provided for @textSize.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get textSize;

  /// No description provided for @textSizeHint.
  ///
  /// In en, this message translates to:
  /// **'On top of the system\'s text size'**
  String get textSizeHint;

  /// No description provided for @textSmall.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get textSmall;

  /// No description provided for @textNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get textNormal;

  /// No description provided for @textLarge.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get textLarge;

  /// No description provided for @textLarger.
  ///
  /// In en, this message translates to:
  /// **'Larger'**
  String get textLarger;

  /// No description provided for @brightnessHint.
  ///
  /// In en, this message translates to:
  /// **'Dark, light, or as the system is set. Every text keeps enough contrast in both.'**
  String get brightnessHint;

  /// No description provided for @brightnessSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get brightnessSystem;

  /// No description provided for @brightnessDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get brightnessDark;

  /// No description provided for @brightnessLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get brightnessLight;

  /// No description provided for @displayStyle.
  ///
  /// In en, this message translates to:
  /// **'Game display'**
  String get displayStyle;

  /// No description provided for @displayStyleHint.
  ///
  /// In en, this message translates to:
  /// **'Clear shows the remaining score large in the app\'s colours; the scoreboard fits more on less room. Automatic: scoreboard on phones, clear elsewhere.'**
  String get displayStyleHint;

  /// No description provided for @displayAuto.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get displayAuto;

  /// No description provided for @displayStyleClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get displayStyleClear;

  /// No description provided for @displayStyleScoreboard.
  ///
  /// In en, this message translates to:
  /// **'Scoreboard'**
  String get displayStyleScoreboard;

  /// No description provided for @viewingDistance.
  ///
  /// In en, this message translates to:
  /// **'Viewing distance'**
  String get viewingDistance;

  /// No description provided for @viewingDistanceHint.
  ///
  /// In en, this message translates to:
  /// **'Far shows only what matters, very large, for a screen at the board or a TV. Automatic: far on large screens.'**
  String get viewingDistanceHint;

  /// No description provided for @viewingNear.
  ///
  /// In en, this message translates to:
  /// **'Near'**
  String get viewingNear;

  /// No description provided for @viewingFar.
  ///
  /// In en, this message translates to:
  /// **'Far'**
  String get viewingFar;

  /// No description provided for @scoreCallerHint.
  ///
  /// In en, this message translates to:
  /// **'Announces each visit\'s score, like a caller'**
  String get scoreCallerHint;

  /// No description provided for @callerVolume.
  ///
  /// In en, this message translates to:
  /// **'Caller volume'**
  String get callerVolume;

  /// No description provided for @callerTest.
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get callerTest;

  /// No description provided for @callerNoVoice.
  ///
  /// In en, this message translates to:
  /// **'This device has no speech output. On Linux: install speech-dispatcher (spd-say).'**
  String get callerNoVoice;

  /// No description provided for @cameraAssignFailed.
  ///
  /// In en, this message translates to:
  /// **'Assignment not stored: {error}'**
  String cameraAssignFailed(String error);

  /// No description provided for @addSetMeasure.
  ///
  /// In en, this message translates to:
  /// **'Measure in the board'**
  String get addSetMeasure;

  /// No description provided for @addSetMeasureHint.
  ///
  /// In en, this message translates to:
  /// **'Put one dart in at four places – the cameras measure it'**
  String get addSetMeasureHint;

  /// No description provided for @addSetEnter.
  ///
  /// In en, this message translates to:
  /// **'Type in the dimensions'**
  String get addSetEnter;

  /// No description provided for @addSetEnterHint.
  ///
  /// In en, this message translates to:
  /// **'For example from the packaging'**
  String get addSetEnterHint;

  /// No description provided for @enterDims.
  ///
  /// In en, this message translates to:
  /// **'Enter dimensions'**
  String get enterDims;

  /// No description provided for @dimsHint.
  ///
  /// In en, this message translates to:
  /// **'Values e.g. from the packaging. An empty field keeps the measured value.'**
  String get dimsHint;

  /// No description provided for @dimTotal.
  ///
  /// In en, this message translates to:
  /// **'Total length'**
  String get dimTotal;

  /// No description provided for @dimPoint.
  ///
  /// In en, this message translates to:
  /// **'Point'**
  String get dimPoint;

  /// No description provided for @dimBarrel.
  ///
  /// In en, this message translates to:
  /// **'Barrel'**
  String get dimBarrel;

  /// No description provided for @dimBarrelDiameter.
  ///
  /// In en, this message translates to:
  /// **'Barrel diameter'**
  String get dimBarrelDiameter;

  /// No description provided for @dimShaft.
  ///
  /// In en, this message translates to:
  /// **'Shaft'**
  String get dimShaft;

  /// No description provided for @dimFlight.
  ///
  /// In en, this message translates to:
  /// **'Flight'**
  String get dimFlight;

  /// No description provided for @dimWeight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get dimWeight;

  /// No description provided for @dimEntered.
  ///
  /// In en, this message translates to:
  /// **'entered'**
  String get dimEntered;

  /// No description provided for @dimPhoto.
  ///
  /// In en, this message translates to:
  /// **'photo'**
  String get dimPhoto;

  /// No description provided for @dimMeasuredValue.
  ///
  /// In en, this message translates to:
  /// **'measured: {value}'**
  String dimMeasuredValue(String value);

  /// No description provided for @dimsSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get dimsSave;

  /// No description provided for @dimsImplausible.
  ///
  /// In en, this message translates to:
  /// **'A value lies outside what a dart can have.'**
  String get dimsImplausible;

  /// No description provided for @addSetPhoto.
  ///
  /// In en, this message translates to:
  /// **'Measure by photo'**
  String get addSetPhoto;

  /// No description provided for @addSetPhotoHint.
  ///
  /// In en, this message translates to:
  /// **'Lay the dart on the printed sheet and take a photo'**
  String get addSetPhotoHint;

  /// No description provided for @dartPhotoHowTo.
  ///
  /// In en, this message translates to:
  /// **'Print the dart sheet (docs/calibration/dart-sheet-A4.png) at 100 % on A4 and lay it flat. Put one dart of the set in the middle of the sheet. Take the photo from above, with all four corner markers fully in view.'**
  String get dartPhotoHowTo;

  /// No description provided for @dartPhotoTake.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get dartPhotoTake;

  /// No description provided for @dartPhotoMeasuring.
  ///
  /// In en, this message translates to:
  /// **'Measuring the photo …'**
  String get dartPhotoMeasuring;

  /// No description provided for @dartPhotoDone.
  ///
  /// In en, this message translates to:
  /// **'Photo measured – the dimensions are with the set.'**
  String get dartPhotoDone;

  /// No description provided for @dartPhotoNoSheet.
  ///
  /// In en, this message translates to:
  /// **'The sheet was not found. All four markers must be fully in the picture.'**
  String get dartPhotoNoSheet;

  /// No description provided for @dartPhotoNoDart.
  ///
  /// In en, this message translates to:
  /// **'No dart was found on the sheet. Put it in the middle, without shadow.'**
  String get dartPhotoNoDart;

  /// No description provided for @modeGrouping.
  ///
  /// In en, this message translates to:
  /// **'Grouping'**
  String get modeGrouping;

  /// No description provided for @modeGroupingDescription.
  ///
  /// In en, this message translates to:
  /// **'Darts at one target, scored by how tightly they group'**
  String get modeGroupingDescription;

  /// No description provided for @groupingTarget.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get groupingTarget;

  /// No description provided for @groupingDartCount.
  ///
  /// In en, this message translates to:
  /// **'Darts per round'**
  String get groupingDartCount;

  /// No description provided for @groupingPickPlayer.
  ///
  /// In en, this message translates to:
  /// **'Who throws? Only profiles keep their precision.'**
  String get groupingPickPlayer;

  /// No description provided for @groupingProgress.
  ///
  /// In en, this message translates to:
  /// **'Dart {thrown} of {total}'**
  String groupingProgress(int thrown, int total);

  /// No description provided for @precisionSpread.
  ///
  /// In en, this message translates to:
  /// **'Spread'**
  String get precisionSpread;

  /// No description provided for @precisionOffset.
  ///
  /// In en, this message translates to:
  /// **'Offset'**
  String get precisionOffset;

  /// No description provided for @precisionOnTarget.
  ///
  /// In en, this message translates to:
  /// **'on target'**
  String get precisionOnTarget;

  /// No description provided for @offsetRight.
  ///
  /// In en, this message translates to:
  /// **'{mm} mm right'**
  String offsetRight(String mm);

  /// No description provided for @offsetLeft.
  ///
  /// In en, this message translates to:
  /// **'{mm} mm left'**
  String offsetLeft(String mm);

  /// No description provided for @offsetHigh.
  ///
  /// In en, this message translates to:
  /// **'{mm} mm high'**
  String offsetHigh(String mm);

  /// No description provided for @offsetLow.
  ///
  /// In en, this message translates to:
  /// **'{mm} mm low'**
  String offsetLow(String mm);

  /// No description provided for @missFromTarget.
  ///
  /// In en, this message translates to:
  /// **'{mm} mm off: {direction}'**
  String missFromTarget(String mm, String direction);

  /// No description provided for @groupingNotMeasured.
  ///
  /// In en, this message translates to:
  /// **'Keypad darts and corrected darts have no measured point and do not count for the group.'**
  String get groupingNotMeasured;

  /// No description provided for @roundDone.
  ///
  /// In en, this message translates to:
  /// **'Round done'**
  String get roundDone;

  /// No description provided for @roundAgain.
  ///
  /// In en, this message translates to:
  /// **'Another round'**
  String get roundAgain;

  /// No description provided for @resultSpread.
  ///
  /// In en, this message translates to:
  /// **'Spread: {value}'**
  String resultSpread(String value);

  /// No description provided for @resultOffset.
  ///
  /// In en, this message translates to:
  /// **'Offset: {value}'**
  String resultOffset(String value);

  /// No description provided for @resultHitRate.
  ///
  /// In en, this message translates to:
  /// **'Hit rate: {value}'**
  String resultHitRate(String value);

  /// No description provided for @resultCheckouts.
  ///
  /// In en, this message translates to:
  /// **'Checkout rate: {done} of {total}'**
  String resultCheckouts(int done, int total);

  /// No description provided for @statsPrecision.
  ///
  /// In en, this message translates to:
  /// **'Precision'**
  String get statsPrecision;

  /// No description provided for @statsPrecisionEmpty.
  ///
  /// In en, this message translates to:
  /// **'Play the grouping training to see your spread and offset per target.'**
  String get statsPrecisionEmpty;

  /// No description provided for @statsPrecisionTrend.
  ///
  /// In en, this message translates to:
  /// **'Spread per week'**
  String get statsPrecisionTrend;

  /// No description provided for @statsPrecisionHelp.
  ///
  /// In en, this message translates to:
  /// **'Spread: how far the darts lie from their own middle (root mean square). Offset: how far that middle lies from the target. The ellipse holds about two in five darts.'**
  String get statsPrecisionHelp;

  /// No description provided for @modeDoubles.
  ///
  /// In en, this message translates to:
  /// **'Doubles practice'**
  String get modeDoubles;

  /// No description provided for @modeDoublesDescription.
  ///
  /// In en, this message translates to:
  /// **'One visit at each double; your doubles ranked by hit rate and spread'**
  String get modeDoublesDescription;

  /// No description provided for @doublesSet.
  ///
  /// In en, this message translates to:
  /// **'Doubles'**
  String get doublesSet;

  /// No description provided for @doublesTop10.
  ///
  /// In en, this message translates to:
  /// **'The 10 most played'**
  String get doublesTop10;

  /// No description provided for @doublesAll.
  ///
  /// In en, this message translates to:
  /// **'All 20 and the bull'**
  String get doublesAll;

  /// No description provided for @doublesWeakest.
  ///
  /// In en, this message translates to:
  /// **'Your 5 weakest'**
  String get doublesWeakest;

  /// No description provided for @doublesRanking.
  ///
  /// In en, this message translates to:
  /// **'Your doubles, best first'**
  String get doublesRanking;

  /// No description provided for @doublesRound.
  ///
  /// In en, this message translates to:
  /// **'This round'**
  String get doublesRound;

  /// No description provided for @modeCheckout.
  ///
  /// In en, this message translates to:
  /// **'Checkout trainer'**
  String get modeCheckout;

  /// No description provided for @modeCheckoutDescription.
  ///
  /// In en, this message translates to:
  /// **'Random finishes or the 121 ladder; every miss measured against the field to aim at'**
  String get modeCheckoutDescription;

  /// No description provided for @checkoutRange.
  ///
  /// In en, this message translates to:
  /// **'Finishes'**
  String get checkoutRange;

  /// No description provided for @checkoutCount.
  ///
  /// In en, this message translates to:
  /// **'Checkouts per round'**
  String get checkoutCount;

  /// No description provided for @checkoutDarts.
  ///
  /// In en, this message translates to:
  /// **'Darts per checkout'**
  String get checkoutDarts;

  /// No description provided for @checkoutAim.
  ///
  /// In en, this message translates to:
  /// **'Aim: {field}'**
  String checkoutAim(String field);

  /// No description provided for @checkoutProgress.
  ///
  /// In en, this message translates to:
  /// **'Checkout {number} of {total}'**
  String checkoutProgress(int number, int total);

  /// No description provided for @checkoutLeft.
  ///
  /// In en, this message translates to:
  /// **'{points} left'**
  String checkoutLeft(int points);

  /// No description provided for @checkoutHit.
  ///
  /// In en, this message translates to:
  /// **'Checked out'**
  String get checkoutHit;

  /// No description provided for @checkoutMissed.
  ///
  /// In en, this message translates to:
  /// **'Not checked out'**
  String get checkoutMissed;

  /// No description provided for @aimedAt.
  ///
  /// In en, this message translates to:
  /// **'at {field}'**
  String aimedAt(String field);

  /// No description provided for @modePrecision.
  ///
  /// In en, this message translates to:
  /// **'Precision training'**
  String get modePrecision;

  /// No description provided for @modePrecisionDescription.
  ///
  /// In en, this message translates to:
  /// **'Grouping, doubles and checkouts, measured in millimetres'**
  String get modePrecisionDescription;

  /// No description provided for @or.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get or;

  /// No description provided for @pickCandidate.
  ///
  /// In en, this message translates to:
  /// **'Tap the right field, or tap the board where the dart is.'**
  String get pickCandidate;

  /// No description provided for @callCheckout.
  ///
  /// In en, this message translates to:
  /// **'Say the checkout'**
  String get callCheckout;

  /// No description provided for @modeMoreGames.
  ///
  /// In en, this message translates to:
  /// **'More games'**
  String get modeMoreGames;

  /// No description provided for @modeMoreGamesDescription.
  ///
  /// In en, this message translates to:
  /// **'Shanghai, Bob\'s 27, Halve-It and Killer'**
  String get modeMoreGamesDescription;

  /// No description provided for @modeShanghai.
  ///
  /// In en, this message translates to:
  /// **'Shanghai'**
  String get modeShanghai;

  /// No description provided for @modeShanghaiDescription.
  ///
  /// In en, this message translates to:
  /// **'Rounds 1 to 7 at that number; single, double and triple in one visit win at once'**
  String get modeShanghaiDescription;

  /// No description provided for @shanghaiAllNumbers.
  ///
  /// In en, this message translates to:
  /// **'All 20 numbers instead of 7'**
  String get shanghaiAllNumbers;

  /// No description provided for @modeBobs27.
  ///
  /// In en, this message translates to:
  /// **'Bob\'s 27'**
  String get modeBobs27;

  /// No description provided for @modeBobs27Description.
  ///
  /// In en, this message translates to:
  /// **'Doubles practice: start with 27, D1 to the bull; a visit without a hit costs the double'**
  String get modeBobs27Description;

  /// No description provided for @modeHalveIt.
  ///
  /// In en, this message translates to:
  /// **'Halve-It'**
  String get modeHalveIt;

  /// No description provided for @modeHalveItDescription.
  ///
  /// In en, this message translates to:
  /// **'Start with 40; a visit without a hit on the target halves your score'**
  String get modeHalveItDescription;

  /// No description provided for @roundOf.
  ///
  /// In en, this message translates to:
  /// **'Round {round} of {total}'**
  String roundOf(int round, int total);

  /// No description provided for @playerOut.
  ///
  /// In en, this message translates to:
  /// **'out'**
  String get playerOut;

  /// No description provided for @targetAnyDouble.
  ///
  /// In en, this message translates to:
  /// **'any double'**
  String get targetAnyDouble;

  /// No description provided for @targetAnyTriple.
  ///
  /// In en, this message translates to:
  /// **'any triple'**
  String get targetAnyTriple;

  /// No description provided for @cutThroat.
  ///
  /// In en, this message translates to:
  /// **'Cut-throat: points go to the opponents, the lowest score wins'**
  String get cutThroat;

  /// No description provided for @ladderBest.
  ///
  /// In en, this message translates to:
  /// **'Highest checkout: {score}'**
  String ladderBest(String score);

  /// No description provided for @modeKiller.
  ///
  /// In en, this message translates to:
  /// **'Killer'**
  String get modeKiller;

  /// No description provided for @modeKillerDescription.
  ///
  /// In en, this message translates to:
  /// **'Hit your own double three times to become a killer, then take your opponents\' lives'**
  String get modeKillerDescription;

  /// No description provided for @killerIsKiller.
  ///
  /// In en, this message translates to:
  /// **'Killer'**
  String get killerIsKiller;

  /// No description provided for @killerMarks.
  ///
  /// In en, this message translates to:
  /// **'{marks} of {needed} on {field}'**
  String killerMarks(int marks, int needed, String field);

  /// No description provided for @throwViewTitle.
  ///
  /// In en, this message translates to:
  /// **'Dart {label}'**
  String throwViewTitle(String label);

  /// No description provided for @throwViewBefore.
  ///
  /// In en, this message translates to:
  /// **'Before'**
  String get throwViewBefore;

  /// No description provided for @throwViewAfter.
  ///
  /// In en, this message translates to:
  /// **'After'**
  String get throwViewAfter;

  /// No description provided for @throwViewLegend.
  ///
  /// In en, this message translates to:
  /// **'Line: the dart\'s axis as the camera saw it. Ring: the tip it found. Cross: the located point.'**
  String get throwViewLegend;

  /// No description provided for @throwViewNoEngine.
  ///
  /// In en, this message translates to:
  /// **'Camera views come from the engine. Connect to the engine that detected this dart.'**
  String get throwViewNoEngine;

  /// No description provided for @throwViewNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'The engine has no camera images of this dart, e.g. because it was entered by hand or simulated.'**
  String get throwViewNotAvailable;

  /// No description provided for @throwViewFailed.
  ///
  /// In en, this message translates to:
  /// **'The camera views could not be loaded ({code}).'**
  String throwViewFailed(String code);

  /// No description provided for @throwViewCorrect.
  ///
  /// In en, this message translates to:
  /// **'Correct this dart'**
  String get throwViewCorrect;

  /// No description provided for @throwViewUsed.
  ///
  /// In en, this message translates to:
  /// **'counted'**
  String get throwViewUsed;

  /// No description provided for @throwViewNotUsed.
  ///
  /// In en, this message translates to:
  /// **'not counted'**
  String get throwViewNotUsed;

  /// No description provided for @throwViewNotSeen.
  ///
  /// In en, this message translates to:
  /// **'did not see the dart'**
  String get throwViewNotSeen;

  /// No description provided for @throwViewCut.
  ///
  /// In en, this message translates to:
  /// **'dart cut by the image border'**
  String get throwViewCut;

  /// No description provided for @throwViewDisagrees.
  ///
  /// In en, this message translates to:
  /// **'disagrees with the other cameras'**
  String get throwViewDisagrees;

  /// No description provided for @throwViewPlaneDistance.
  ///
  /// In en, this message translates to:
  /// **'{mm} mm off the point'**
  String throwViewPlaneDistance(String mm);

  /// No description provided for @throwViewOpen.
  ///
  /// In en, this message translates to:
  /// **'Camera views'**
  String get throwViewOpen;

  /// No description provided for @gameThrowsTitle.
  ///
  /// In en, this message translates to:
  /// **'Darts of the game'**
  String get gameThrowsTitle;

  /// No description provided for @x01Legs.
  ///
  /// In en, this message translates to:
  /// **'{legs, plural, =1{1 leg} other{{legs} legs}}'**
  String x01Legs(int legs);

  /// No description provided for @x01DartsThrown.
  ///
  /// In en, this message translates to:
  /// **'{darts, plural, =1{1 dart} other{{darts} darts}}'**
  String x01DartsThrown(int darts);

  /// No description provided for @gameScreenLayout.
  ///
  /// In en, this message translates to:
  /// **'Game screen'**
  String get gameScreenLayout;

  /// No description provided for @gameScreenLayoutHint.
  ///
  /// In en, this message translates to:
  /// **'Kept for this device, whatever the preset'**
  String get gameScreenLayoutHint;

  /// No description provided for @boardSide.
  ///
  /// In en, this message translates to:
  /// **'Board side'**
  String get boardSide;

  /// No description provided for @boardSideHint.
  ///
  /// In en, this message translates to:
  /// **'Where the board stands when it fits beside the score'**
  String get boardSideHint;

  /// No description provided for @boardLeft.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get boardLeft;

  /// No description provided for @boardRight.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get boardRight;

  /// No description provided for @boardSize.
  ///
  /// In en, this message translates to:
  /// **'Board size'**
  String get boardSize;

  /// No description provided for @boardSizeHint.
  ///
  /// In en, this message translates to:
  /// **'How much of the game screen the board takes; the score always keeps room to be read'**
  String get boardSizeHint;

  /// No description provided for @boardSmall.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get boardSmall;

  /// No description provided for @boardMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get boardMedium;

  /// No description provided for @boardLarge.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get boardLarge;

  /// No description provided for @panelDetails.
  ///
  /// In en, this message translates to:
  /// **'Score panel shows'**
  String get panelDetails;

  /// No description provided for @detailVisitDarts.
  ///
  /// In en, this message translates to:
  /// **'Darts of the visit'**
  String get detailVisitDarts;

  /// No description provided for @detailCheckout.
  ///
  /// In en, this message translates to:
  /// **'Checkout route'**
  String get detailCheckout;

  /// No description provided for @detailAverage.
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get detailAverage;

  /// No description provided for @detailDartsThrown.
  ///
  /// In en, this message translates to:
  /// **'Darts thrown'**
  String get detailDartsThrown;

  /// No description provided for @celebration.
  ///
  /// In en, this message translates to:
  /// **'180 and checkout'**
  String get celebration;

  /// No description provided for @celebrationHint.
  ///
  /// In en, this message translates to:
  /// **'How a 180 or a checkout shows on the game screen; where the system asks for less motion, it shows without moving'**
  String get celebrationHint;

  /// No description provided for @celebrationFull.
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get celebrationFull;

  /// No description provided for @celebrationSubtle.
  ///
  /// In en, this message translates to:
  /// **'Subtle'**
  String get celebrationSubtle;

  /// No description provided for @celebrationOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get celebrationOff;

  /// No description provided for @celebrateCheckout.
  ///
  /// In en, this message translates to:
  /// **'Checkout {points}'**
  String celebrateCheckout(int points);

  /// No description provided for @boardColours.
  ///
  /// In en, this message translates to:
  /// **'Board colours'**
  String get boardColours;

  /// No description provided for @boardColoursHint.
  ///
  /// In en, this message translates to:
  /// **'For the drawn board; a photographed board keeps its own'**
  String get boardColoursHint;

  /// No description provided for @boardClassic.
  ///
  /// In en, this message translates to:
  /// **'Classic'**
  String get boardClassic;

  /// No description provided for @boardColourSafe.
  ///
  /// In en, this message translates to:
  /// **'Colour-safe'**
  String get boardColourSafe;

  /// No description provided for @boardContrast.
  ///
  /// In en, this message translates to:
  /// **'Contrast'**
  String get boardContrast;

  /// No description provided for @dartColour.
  ///
  /// In en, this message translates to:
  /// **'Darts on the board'**
  String get dartColour;

  /// No description provided for @dartAccent.
  ///
  /// In en, this message translates to:
  /// **'Accent'**
  String get dartAccent;

  /// No description provided for @dartWhite.
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get dartWhite;

  /// No description provided for @dartYellow.
  ///
  /// In en, this message translates to:
  /// **'Yellow'**
  String get dartYellow;

  /// No description provided for @dartCyan.
  ///
  /// In en, this message translates to:
  /// **'Cyan'**
  String get dartCyan;

  /// No description provided for @dartMagenta.
  ///
  /// In en, this message translates to:
  /// **'Magenta'**
  String get dartMagenta;

  /// No description provided for @playerColour.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get playerColour;

  /// No description provided for @playerColourOf.
  ///
  /// In en, this message translates to:
  /// **'Colour of {player}'**
  String playerColourOf(String player);

  /// No description provided for @playerColourReset.
  ///
  /// In en, this message translates to:
  /// **'By order'**
  String get playerColourReset;

  /// No description provided for @appearanceShare.
  ///
  /// In en, this message translates to:
  /// **'Share the appearance'**
  String get appearanceShare;

  /// No description provided for @appearanceShareHint.
  ///
  /// In en, this message translates to:
  /// **'As a QR code or a code to copy, for another device'**
  String get appearanceShareHint;

  /// No description provided for @appearanceApply.
  ///
  /// In en, this message translates to:
  /// **'Take over an appearance'**
  String get appearanceApply;

  /// No description provided for @appearanceApplyHint.
  ///
  /// In en, this message translates to:
  /// **'From another device\'s code or QR code; the viewing distance stays as it is here'**
  String get appearanceApplyHint;

  /// No description provided for @appearanceCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get appearanceCopy;

  /// No description provided for @appearanceCopied.
  ///
  /// In en, this message translates to:
  /// **'Code copied'**
  String get appearanceCopied;

  /// No description provided for @appearanceCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Appearance code'**
  String get appearanceCodeLabel;

  /// No description provided for @appearanceCodeInvalid.
  ///
  /// In en, this message translates to:
  /// **'This is not an appearance code from DartPilot'**
  String get appearanceCodeInvalid;

  /// No description provided for @appearanceScanHint.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at the QR code under Share the appearance on the other device'**
  String get appearanceScanHint;

  /// No description provided for @appearanceScanUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The camera cannot be used to scan. Allow the camera for DartPilot, or paste the code shown under the QR code.'**
  String get appearanceScanUnavailable;

  /// No description provided for @appearancePreview.
  ///
  /// In en, this message translates to:
  /// **'Adjust with preview'**
  String get appearancePreview;

  /// No description provided for @appearancePreviewHint.
  ///
  /// In en, this message translates to:
  /// **'A game screen shows every change at once'**
  String get appearancePreviewHint;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About DartPilot'**
  String get aboutTitle;

  /// No description provided for @aboutHint.
  ///
  /// In en, this message translates to:
  /// **'Version, licence and source code'**
  String get aboutHint;

  /// No description provided for @aboutVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String aboutVersion(String version);

  /// No description provided for @aboutDevelopmentBuild.
  ///
  /// In en, this message translates to:
  /// **'Development build'**
  String get aboutDevelopmentBuild;

  /// No description provided for @aboutDescription.
  ///
  /// In en, this message translates to:
  /// **'Scores steel darts with cameras on the board, or by hand without any. Free and open source, made for playing at home.'**
  String get aboutDescription;

  /// No description provided for @aboutLicence.
  ///
  /// In en, this message translates to:
  /// **'Licence'**
  String get aboutLicence;

  /// No description provided for @aboutLicenceText.
  ///
  /// In en, this message translates to:
  /// **'Free software under the GNU General Public License, version 3 or later (GPL-3.0-or-later). It comes without any warranty. You may share and change it under that licence.'**
  String get aboutLicenceText;

  /// No description provided for @aboutLegalese.
  ///
  /// In en, this message translates to:
  /// **'Copyright (C) DartPilot contributors. GPL-3.0-or-later, without any warranty.'**
  String get aboutLegalese;

  /// No description provided for @aboutSource.
  ///
  /// In en, this message translates to:
  /// **'Source code'**
  String get aboutSource;

  /// No description provided for @aboutGuide.
  ///
  /// In en, this message translates to:
  /// **'Player guide'**
  String get aboutGuide;

  /// No description provided for @aboutCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get aboutCopyLink;

  /// No description provided for @aboutLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get aboutLinkCopied;

  /// No description provided for @aboutThirdParty.
  ///
  /// In en, this message translates to:
  /// **'Licences of included software'**
  String get aboutThirdParty;

  /// No description provided for @aboutThirdPartyHint.
  ///
  /// In en, this message translates to:
  /// **'Flutter and the packages this app is built with'**
  String get aboutThirdPartyHint;

  /// No description provided for @aboutCredits.
  ///
  /// In en, this message translates to:
  /// **'Credits'**
  String get aboutCredits;

  /// No description provided for @aboutCreditsText.
  ///
  /// In en, this message translates to:
  /// **'The DartPilot icon is part of DartPilot and under its licence. The icons in the app are Material Icons by Google (Apache License 2.0) and Cupertino Icons by the Flutter authors (MIT License). The app is built with Flutter. Thanks to everyone who reports bugs, tests and contributes.'**
  String get aboutCreditsText;

  /// No description provided for @exportDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Downloaded: {name}'**
  String exportDownloaded(String name);
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
