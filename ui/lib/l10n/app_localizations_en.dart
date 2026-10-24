// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'DartPilot';

  @override
  String get chooseGame => 'Choose a game';

  @override
  String get modeX01 => 'X01';

  @override
  String get modeX01Description => '501 or 301, double out';

  @override
  String get modeCricket => 'Cricket';

  @override
  String get modeCricketDescription => 'Close 15 to 20 and bull';

  @override
  String get modeAroundTheClock => 'Around the Clock';

  @override
  String get modeAroundTheClockDescription => 'Hit 1 to 20 in order';

  @override
  String get modeTraining => 'Free throwing';

  @override
  String get modeTrainingDescription => 'Every dart is shown and counted';

  @override
  String get inputBoard => 'Board';

  @override
  String get inputKeypad => 'Keypad';

  @override
  String get single => 'Single';

  @override
  String get double => 'Double';

  @override
  String get triple => 'Triple';

  @override
  String get miss => 'Miss';

  @override
  String get undo => 'Undo';

  @override
  String get visit => 'Visit';

  @override
  String get darts => 'Darts';

  @override
  String get points => 'Points';

  @override
  String get average => '3-dart average';

  @override
  String get newVisit => 'Next visit';

  @override
  String get noThrowsYet => 'Tap the board or use the keypad';

  @override
  String get x01Setup => 'New X01 game';

  @override
  String get players => 'Players';

  @override
  String get addPlayer => 'Add player';

  @override
  String playerName(int number) {
    return 'Player $number';
  }

  @override
  String get startScore => 'Start score';

  @override
  String get doubleIn => 'Double in';

  @override
  String get doubleOut => 'Double out';

  @override
  String get legsToWin => 'Legs to win';

  @override
  String get startGame => 'Start game';

  @override
  String leg(int number) {
    return 'Leg $number';
  }

  @override
  String get legs => 'Legs';

  @override
  String get checkout => 'Checkout';

  @override
  String get bust => 'Bust';

  @override
  String get notIn => 'not in';

  @override
  String legWonBy(String name) {
    return '$name wins the leg';
  }

  @override
  String matchWonBy(String name) {
    return '$name wins!';
  }

  @override
  String get newGame => 'New game';

  @override
  String get backToMenu => 'Menu';

  @override
  String get removePlayer => 'Remove player';

  @override
  String get cricketSetup => 'New Cricket game';

  @override
  String get aroundTheClockSetup => 'New Around the Clock game';

  @override
  String get endWithBull => 'Finish with the bull';

  @override
  String get target => 'Target';

  @override
  String get marksPerRound => 'Marks per round';

  @override
  String get hitRate => 'Hit rate';

  @override
  String get bull => 'Bull';

  @override
  String get engine => 'Engine';

  @override
  String get engineAddress => 'Engine address';

  @override
  String get connect => 'Connect';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get engineConnected => 'Connected';

  @override
  String get engineConnecting => 'Connecting…';

  @override
  String get engineDisconnected => 'Not connected';

  @override
  String get engineFailed => 'Connection failed';

  @override
  String get engineSimulated => 'simulated';

  @override
  String uncertainDart(String label, int percent) {
    return 'Uncertain: $label ($percent %)';
  }

  @override
  String get uncertainNoPoint => 'A dart was detected, but not where';

  @override
  String get confirm => 'Confirm';

  @override
  String get discard => 'Discard';

  @override
  String get tapToCorrect => 'Tap the board where the dart is';

  @override
  String get recentDarts => 'Last darts';

  @override
  String correctingDart(String label) {
    return 'Correcting $label – tap the board';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String missingDarts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count darts are missing',
      one: '1 dart is missing',
    );
    return '$_temp0';
  }

  @override
  String get countAsMiss => 'Count as miss';

  @override
  String get enterManually => 'Enter them';

  @override
  String get cameras => 'Cameras';

  @override
  String get waitingForImage => 'Waiting for the first image…';

  @override
  String get cameraOk => 'OK';

  @override
  String get cameraDegraded => 'Degraded';

  @override
  String get cameraLost => 'Lost';

  @override
  String get noCameras => 'The engine has no cameras';

  @override
  String fps(String value) {
    return '$value fps';
  }

  @override
  String get lostFrames => 'Lost';

  @override
  String get droppedFrames => 'Dropped';

  @override
  String get brightness => 'Brightness';

  @override
  String get preview => 'Preview';

  @override
  String get expandAll => 'Expand all';

  @override
  String get collapseAll => 'Collapse all';

  @override
  String get tapToEnlarge => 'Tap the image to enlarge it';

  @override
  String get latency => 'Latency';

  @override
  String get boardOccupiedTitle => 'Pull the darts out of the board';

  @override
  String get boardOccupiedText => 'The cameras see something in the board. Pull out the darts before the game starts.';

  @override
  String get boardOccupiedBanner => 'Darts in the board';

  @override
  String get checkBoardAgain => 'Check again';

  @override
  String get startAnyway => 'Start anyway';

  @override
  String get show => 'Show';

  @override
  String get emptyReferenceMissing => 'No image of the empty board stored';

  @override
  String get storeEmptyReference => 'Store empty board';

  @override
  String get emptyReferenceStored => 'Empty board stored';

  @override
  String get boardNotEmpty => 'The board is not empty; pull out the darts first.';

  @override
  String get storeReferenceFailed => 'Could not store the empty board';

  @override
  String get searchEngines => 'Search the network for engines';

  @override
  String get searchingEngines => 'Searching the network…';

  @override
  String get noEnginesFound =>
      'No engine found. Guest Wi-Fi, client isolation or separate networks block the search; type the address instead.';

  @override
  String get foundEngines => 'Engines in the network';

  @override
  String engineIncompatible(String protocol) {
    return 'incompatible ($protocol)';
  }

  @override
  String get boardIsEmpty => 'The board is empty';

  @override
  String get boardIsEmptyTitle => 'Store the empty board again?';

  @override
  String get boardIsEmptyText =>
      'Only if no dart or other object is in the board. The current camera images become the new empty board, and the check compares with them from now on.';

  @override
  String get boardNotStill => 'The image is not still yet; wait a moment and try again.';

  @override
  String get engineThisDevice => 'On this device';

  @override
  String get engineNetwork => 'In the network';

  @override
  String get localEngineStopped => 'The engine on this device is stopped.';

  @override
  String get localEngineStarting => 'Starting the engine…';

  @override
  String localEngineRunning(String url) {
    return 'The engine runs on this device ($url).';
  }

  @override
  String get localEngineNotFound => 'The engine program was not found. Enter its path under Log.';

  @override
  String get localEngineNoCameras => 'No camera could be started: are they plugged in, or used by another program?';

  @override
  String get localEnginePortInUse => 'The engine\'s port is in use; another engine may be running.';

  @override
  String get localEngineCrashed => 'The engine stopped unexpectedly; the log shows why.';

  @override
  String get useCameras => 'Use the cameras';

  @override
  String get useCamerasHint => 'Live images and the board check; darts are still simulated until detection is ready.';

  @override
  String get engineLog => 'Log';

  @override
  String get startEngine => 'Start';

  @override
  String get stopEngine => 'Stop';

  @override
  String get engineProgram => 'Engine program';

  @override
  String get engineProgramHint => 'Leave empty to find it automatically';

  @override
  String get engineLogEmpty => 'No output yet.';

  @override
  String get close => 'Close';
}
