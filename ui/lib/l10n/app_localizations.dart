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

  /// No description provided for @emptyReferenceMissing.
  ///
  /// In en, this message translates to:
  /// **'No image of the empty board stored'**
  String get emptyReferenceMissing;

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
  /// **'{time} · {empty} empty boards · {darts} darts'**
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
  /// **'The empty board changed {count} times between darts.'**
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
