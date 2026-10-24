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
  String get chooseGame => 'Play locally or solo';

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

  @override
  String get diagnosis => 'Setup diagnosis';

  @override
  String get startDiagnosis => 'Start';

  @override
  String get restartDiagnosis => 'Start again';

  @override
  String get stopDiagnosis => 'Stop';

  @override
  String get diagnosisIntro =>
      'The diagnosis watches the cameras while you follow the steps: an empty board, then one dart at a time at 8 to 10 places. It lists what is wrong with the setup and what to do about it. Start the cameras about 30 s before, so their exposure has settled.';

  @override
  String get diagnosisNeedsEngine => 'Connect to an engine first.';

  @override
  String get diagnosisNotAvailable =>
      'This engine cannot run the diagnosis; it needs the cameras (start it with the cameras).';

  @override
  String diagnosisFailed(String code) {
    return 'The diagnosis could not start ($code).';
  }

  @override
  String get stepEmptyBoard => 'Leave the board empty and take your hand out of view.';

  @override
  String get stepRemoveDarts => 'Pull all darts out of the board.';

  @override
  String get stepInsertDart => 'Put one dart into the board and take your hand away.';

  @override
  String get stepInsertDartHint => 'Repeat at 8 to 10 places, also the bull and near the double ring.';

  @override
  String get stepRemoveDart => 'Pull the dart out again.';

  @override
  String get diagnosisMoving => 'The image moves – hold still';

  @override
  String get diagnosisSettling => 'Still – waiting a moment';

  @override
  String get diagnosisMeasuring => 'Measuring…';

  @override
  String get diagnosisMeasured => 'Measured';

  @override
  String get diagnosisStopped => 'Stopped';

  @override
  String diagnosisSummary(String time, int empty, int darts) {
    return '$time · $empty empty boards · $darts darts';
  }

  @override
  String get diagnosisFindings => 'Findings';

  @override
  String get diagnosisNoFindings => 'Nothing found so far.';

  @override
  String cameraNumber(int number) {
    return 'Camera $number';
  }

  @override
  String diagnosisPeriods(int count) {
    return 'Measured moments ($count)';
  }

  @override
  String get periodEmpty => 'empty board';

  @override
  String get periodDartNotLocated => 'dart, not located';

  @override
  String periodDartLocated(String x, String y, int cameras, String plane) {
    return 'dart at $x, $y mm, $cameras cameras agree within $plane mm';
  }

  @override
  String get dartSeen => 'dart seen';

  @override
  String get dartCut => 'dart cut at the border';

  @override
  String get dartNotSeen => 'dart not seen';

  @override
  String periodCalibration(String mm) {
    return '$mm mm off calibration';
  }

  @override
  String periodBrightness(int value) {
    return 'brightness $value';
  }

  @override
  String findingLostFrames(String percent) {
    return 'Lost $percent % of its frames.';
  }

  @override
  String get hintLostFrames =>
      'Plug the camera into another USB port or a powered hub, and close other programs that use the cameras.';

  @override
  String findingFewStillMoments(int count, String seconds) {
    return 'Only $count still moments in $seconds s.';
  }

  @override
  String get hintFewStillMoments =>
      'Hold each state still for a few seconds with the hand out of view; if the image never settles, check for vibrations.';

  @override
  String get findingNotEmptyAtStart => 'The board was not empty at the start: its wires are partly hidden.';

  @override
  String get hintNotEmptyAtStart => 'Start with an empty board; everything after it is compared with this first image.';

  @override
  String get findingNoRefinement => 'No refinement for this camera: calibration and darts were not checked.';

  @override
  String get hintNoRefinement => 'Calibrate it on the extrinsic page and refine all cameras (step 5).';

  @override
  String get findingBoardNotFound => 'The board was not found on any empty board.';

  @override
  String get hintBoardNotFound => 'Check the camera\'s view and focus, and the light on the board.';

  @override
  String findingCalibrationOff(String mm) {
    return 'The board is $mm mm off this camera\'s calibration.';
  }

  @override
  String get hintCalibrationOff =>
      'If the camera or the board moved, calibrate the camera again and refine all cameras (extrinsic page, step 5).';

  @override
  String findingDrift(String px, String minutes) {
    return 'The image moved by $px px within $minutes min.';
  }

  @override
  String get hintDrift =>
      'Let the cameras run for about 10 minutes before calibrating and playing, so they are warm; if it keeps moving, tighten the camera\'s mount.';

  @override
  String findingLightChanged(String percent, String low, String lowS, String high, String highS) {
    return 'The empty board\'s brightness changed by $percent % ($low at $lowS s, $high at $highS s).';
  }

  @override
  String get hintExposureSettling =>
      'After the cameras start, their automatic exposure needs a moment: begin about 30 s after starting them, and keep the ring light on.';

  @override
  String get hintLightChanged => 'Use the ring light and keep daylight and room light constant during the test.';

  @override
  String findingBoardChanged(int count) {
    return 'The empty board changed $count times between darts.';
  }

  @override
  String get hintBoardChanged =>
      'Usually fibres pushed out by darts or a slight change of focus; harmless, as the reference is refreshed after every takeout.';

  @override
  String get findingNoDarts => 'No dart was found in the test.';

  @override
  String get hintNoDarts => 'Put darts into the board one at a time and take the hand away each time.';

  @override
  String findingDartsLocated(int located, int darts, int abstained) {
    return '$located of $darts darts located, $abstained without a result.';
  }

  @override
  String get hintDartsLocated => 'The findings per camera show why darts were not located.';

  @override
  String findingDartsCutLost(int cut, int darts, int lost) {
    return 'Cut $cut of $darts darts at the image border and could not help locate $lost of them.';
  }

  @override
  String get hintDartsCutLost =>
      'Tilt or move the camera so that the board and about 15 cm above it are in view, then calibrate it again.';

  @override
  String findingDartsCut(int cut, int darts) {
    return 'Cut $cut of $darts darts at the image border.';
  }

  @override
  String get hintDartsCut =>
      'Harmless while the darts are still located; more of the space above the board in view would make it more robust.';

  @override
  String findingDartsNotSeen(int missed, int darts) {
    return 'Did not see $missed of $darts darts.';
  }

  @override
  String get hintDartsNotSeen =>
      'Check that the camera sees the whole board; dark darts on dark sectors need good light.';

  @override
  String findingCameraDisagrees(int disagreed, int darts) {
    return 'Disagreed with the other cameras on $disagreed of $darts darts.';
  }

  @override
  String get hintCameraDisagrees =>
      'Run the calibration check; if it is off, calibrate this camera again and refine all cameras.';

  @override
  String findingPlanesAgree(String mm) {
    return 'Where three cameras saw a dart, they agreed within $mm mm (median).';
  }

  @override
  String get hintPlanesAgree => 'Refine all cameras again; if one camera stands out, calibrate it first.';

  @override
  String get connectTitle => 'Connect an engine';

  @override
  String get connectIntro =>
      'The engine runs the cameras and detects the darts. It runs on this device or on another one in your network.';

  @override
  String get playWithoutEngine => 'Play without an engine (enter darts by hand)';

  @override
  String get navHome => 'Home';

  @override
  String get navSettings => 'Settings';

  @override
  String get settingsConnection => 'Connection';

  @override
  String get connectedThisDevice => 'Connected to the engine on this device';

  @override
  String get connectedNetwork => 'Connected to an engine in the network';

  @override
  String get playingWithoutEngine => 'Without an engine – darts are entered by hand';

  @override
  String get playingWithoutEngineHint => 'Connect an engine to detect darts and use the cameras.';

  @override
  String get settingsCamerasBoard => 'Cameras and board';

  @override
  String get settingsCamerasHint => 'Live images and the state of each camera';

  @override
  String get settingsDiagnosisHint => 'Find out what is wrong with the setup, step by step';

  @override
  String get settingsEmptyBoardHint => 'Store the cameras\' images of the empty board for the board check';

  @override
  String get settingsCalibration => 'Calibration';

  @override
  String get calibration => 'Calibrate the cameras';

  @override
  String get calibrationInSetupTool => 'For now in the setup program dartpilot_setup on Linux';

  @override
  String get playTogether => 'Play together';

  @override
  String get lobby => 'Lobby';

  @override
  String get lobbyComingSoon => 'Play with friends on other devices – coming with #124';

  @override
  String diagnosisProgress(int done, int target) {
    return 'Darts: $done of $target';
  }

  @override
  String get stepRemoveLastDart => 'Pull the last dart out – then you are done.';

  @override
  String get diagnosisEnough => 'Enough darts measured – the diagnosis is complete.';

  @override
  String get finishDiagnosis => 'Finish the diagnosis';

  @override
  String get diagnosisMoreDartsOptional => 'More darts are possible, but not needed.';

  @override
  String get diagnosisFinished => 'Diagnosis finished';

  @override
  String resultProblems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count problems found',
      one: '1 problem found',
    );
    return '$_temp0';
  }

  @override
  String resultWarnings(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count warnings', one: '1 warning');
    return '$_temp0';
  }

  @override
  String get resultFixHint => 'The findings below say what to do. Run the diagnosis again afterwards.';

  @override
  String get resultAllGood => 'All good';

  @override
  String get resultAllGoodHint => 'The setup is ready to play.';

  @override
  String resultFewDarts(int done, int target) {
    return 'Only $done of $target darts measured; the findings on darts are less certain.';
  }
}
