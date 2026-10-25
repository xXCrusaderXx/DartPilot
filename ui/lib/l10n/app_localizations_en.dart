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

  @override
  String get navStatistics => 'Players';

  @override
  String get statisticsEmpty => 'No players yet. Create a profile; every game counts for its statistics.';

  @override
  String statsGamesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count games', one: '1 game');
    return '$_temp0';
  }

  @override
  String get statsGames => 'Games';

  @override
  String statsWon(int count) {
    return '$count won';
  }

  @override
  String get statsDarts => 'Darts';

  @override
  String get statsFirst9 => 'First 9 average';

  @override
  String get statsLegs => 'Legs';

  @override
  String get statsBestLeg => 'Best leg';

  @override
  String statsDartsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count darts', one: '1 dart');
    return '$_temp0';
  }

  @override
  String get statsCheckoutRate => 'Checkout rate';

  @override
  String get statsHighestFinish => 'Highest finish';

  @override
  String get statsMarksPerRound => 'Marks per round';

  @override
  String get statsClockHitRate => 'Around the Clock hits';

  @override
  String get periodLastGame => 'Last game';

  @override
  String get periodWeek => '7 days';

  @override
  String get periodMonth => '30 days';

  @override
  String get periodAll => 'All';

  @override
  String get statsNoGamesInPeriod => 'No games in this period.';

  @override
  String get statsHits => 'Where the darts landed';

  @override
  String get ringTriple => 'Triple';

  @override
  String get ringDouble => 'Double';

  @override
  String get ringSingleInner => 'Single (inner)';

  @override
  String get ringSingleOuter => 'Single (outer)';

  @override
  String get ringOuterBull => 'Outer bull';

  @override
  String get ringBull => 'Bull';

  @override
  String get ringMiss => 'Miss';

  @override
  String get statsFavouriteDoubles => 'Finished on';

  @override
  String get statsHistory => 'Games';

  @override
  String statsOpponents(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'against $count players',
      one: 'against 1 player',
    );
    return '$_temp0';
  }

  @override
  String get statsSolo => 'solo';

  @override
  String get localEngineNoAnswer =>
      'The program did not answer as the engine and was stopped. Check the engine program under Log.';

  @override
  String get newProfile => 'New profile';

  @override
  String get profileName => 'Name';

  @override
  String get profileNameEmpty => 'Enter a name.';

  @override
  String get profileNameExists => 'There is a profile with this name already.';

  @override
  String get createProfile => 'Create';

  @override
  String get pickPlayersHint => 'Tap the players in the order they throw.';

  @override
  String throwingOrder(String order) {
    return 'Order: $order';
  }

  @override
  String get statsNoGamesYet => 'No games yet';

  @override
  String get deleteProfile => 'Delete profile';

  @override
  String deleteProfileText(String name) {
    return '$name is removed from the players. The games stay kept and count again if a profile with this name is created.';
  }

  @override
  String get delete => 'Delete';

  @override
  String get firstProfileTitle => 'Who is playing?';

  @override
  String get firstProfileText => 'Create a player profile; every game counts for its statistics.';

  @override
  String get calibStepLight => 'Light';

  @override
  String get calibStepBoard => 'Board';

  @override
  String get calibStepRefine => 'Refine';

  @override
  String get calibStepDone => 'Done';

  @override
  String get calibNeedsCameras => 'Calibration needs an engine with cameras. Connect one first.';

  @override
  String get calibIntro =>
      'The engine measures the board from every camera: no target to hold, no measuring tape. You need an empty board and the light you play in; it takes a few minutes.';

  @override
  String get calibStale => 'A camera was measured again after the last refinement: refine all cameras once more.';

  @override
  String get calibBoardMissing => 'board not measured';

  @override
  String calibBoardMeasured(String mm) {
    return 'board $mm mm';
  }

  @override
  String get calibLensOwn => 'own lens calibration';

  @override
  String get calibLensNone => 'no lens calibration';

  @override
  String get calibStart => 'Start calibration';

  @override
  String get calibLightInstruction => 'Empty the board and switch on the light you play in.';

  @override
  String get calibLightHint =>
      'The engine tries every colour temperature on all cameras and keeps the one in the middle of where the board is found. This takes about a minute.';

  @override
  String calibLightSettling(int seconds) {
    return 'Waiting for the cameras\' exposure: $seconds s';
  }

  @override
  String calibLightSweeping(int kelvin) {
    return 'Trying $kelvin K …';
  }

  @override
  String get calibLightDone => 'Light set for every camera.';

  @override
  String get calibLightFailed => 'The light could not be set.';

  @override
  String get calibLightNotFound => 'board not found';

  @override
  String get calibLightTune => 'Set the light';

  @override
  String get calibLightAgain => 'Set again';

  @override
  String get calibNext => 'Next';

  @override
  String calibCameraOf(int number, int count) {
    return 'Camera $number of $count';
  }

  @override
  String get calibBoardDetectInstruction => 'Keep the board empty, hand out of view, and detect it.';

  @override
  String get calibBoardDetectHint =>
      'The engine finds the rings and the 20 wires of the board in this camera\'s image.';

  @override
  String get calibBoardTap20 => 'Tap into the field of the 20.';

  @override
  String get calibBoardTap20Hint =>
      'Anywhere between the bull and the double ring. The colours repeat every second field, so the engine needs to be told which one is the 20.';

  @override
  String get calibBoardCheck => 'Do the numbers match the board?';

  @override
  String get calibBoardCheckHint => 'If not, tap into the 20 again.';

  @override
  String get calibBoardNotFound =>
      'Board not found: remove all darts, keep the hand out of view, and check the light (step 1).';

  @override
  String calibBoardFit(String fit, String worst) {
    return 'Board fit $fit mm (worst $worst mm)';
  }

  @override
  String get calibBoardDetect => 'Detect the board';

  @override
  String get calibBoardDetectAgain => 'Detect again';

  @override
  String get calibNumbersMatchNext => 'Numbers match – next camera';

  @override
  String get calibNumbersMatchRefine => 'Numbers match – refine';

  @override
  String get calibRefineInstruction => 'Refine all cameras together.';

  @override
  String get calibRefineHint =>
      'From the boards of all cameras the engine computes every camera\'s position and lens, and the real size of your board.';

  @override
  String get calibQualityGood => 'good';

  @override
  String get calibQualityFair => 'usable';

  @override
  String get calibQualityPoor => 'not good enough';

  @override
  String get calibLensFromOwn => 'Lens from its own lens calibration';

  @override
  String get calibLensFromModel => 'Lens from another camera of the same model';

  @override
  String get calibLensFromBoard => 'Lens from the board only';

  @override
  String get calibAdviceDetectAgain => 'Measure the board of this camera again in even light.';

  @override
  String get calibAdviceLens => 'A lens calibration of this camera would make it more accurate.';

  @override
  String get calibMeasureAgain => 'Measure again';

  @override
  String calibMeasuredBoard(String bull, String treble) {
    return 'Your board: outer bull $bull mm, treble centre $treble mm';
  }

  @override
  String get calibRefine => 'Refine';

  @override
  String get calibRefineAgain => 'Refine again';

  @override
  String get calibDone => 'The cameras are calibrated.';

  @override
  String get calibDoneHint => 'Check the whole setup with a few darts in the setup diagnosis.';

  @override
  String get calibErrorBusy => 'The engine is still busy with another step.';

  @override
  String get calibErrorNoDetection => 'Detect the board first.';

  @override
  String get calibErrorOutsideBoard =>
      'That point is not in a field of the board; tap into the 20 between bull and double ring.';

  @override
  String get calibErrorFitFailed => 'The board could not be fitted; detect it again.';

  @override
  String get calibErrorNoBoardPlanes => 'No camera has a measured board yet.';

  @override
  String get calibErrorPoseFailed => 'A camera could not be placed; measure its board again.';

  @override
  String get calibErrorSaveFailed => 'The calibration could not be saved.';

  @override
  String calibErrorOther(String code) {
    return 'Failed ($code).';
  }

  @override
  String get calibrationHint => 'Light, board and refinement, step by step';

  @override
  String get addBot => 'Bot';

  @override
  String get botDifficulty => 'Difficulty';

  @override
  String botAverage(int average) {
    return 'Average about $average';
  }

  @override
  String botName(int level, String name) {
    return 'Bot · $name';
  }

  @override
  String statsAgainstBots(String levels) {
    return 'against bot level $levels';
  }

  @override
  String get botLevel1 => 'Beginner';

  @override
  String get botLevel2 => 'Occasional player';

  @override
  String get botLevel3 => 'Pub player';

  @override
  String get botLevel4 => 'Hobby player';

  @override
  String get botLevel5 => 'Club player';

  @override
  String get botLevel6 => 'League player';

  @override
  String get botLevel7 => 'Strong';

  @override
  String get botLevel8 => 'Very strong';

  @override
  String get botLevel9 => 'Semi-pro';

  @override
  String get botLevel10 => 'Pro';

  @override
  String get calibrationCheck => 'Calibration check';

  @override
  String get calibrationCheckHint => 'Has a camera moved? Every camera against its calibration';

  @override
  String get calibrationCheckIntro =>
      'Keep the board empty. Blue rings show where the calibration expects the board\'s points, green dots where they are now; long amber lines mean the camera or the board has moved. The engine also checks this in the background whenever the board is empty.';

  @override
  String checkOk(String mm) {
    return 'Matches the calibration ($mm mm).';
  }

  @override
  String checkOff(String mm) {
    return 'Slightly off ($mm mm), e.g. other light. Detection still works.';
  }

  @override
  String checkMoved(String mm) {
    return 'The camera or the board has moved ($mm mm). Measure this camera again.';
  }

  @override
  String checkWrongPort(String camera) {
    return 'Wrong USB port? This image fits the calibration of camera $camera.';
  }

  @override
  String get checkNoBoard => 'No board found – darts in the board or a hand in view?';

  @override
  String get checkNotCalibrated => 'Not calibrated yet.';

  @override
  String get checkChecking => 'Checking …';

  @override
  String homeCameraMoved(String camera) {
    return '$camera has moved – measure it again.';
  }

  @override
  String homeCameraWrongPort(String camera) {
    return '$camera is on another USB port than when it was calibrated.';
  }

  @override
  String get referenceRun => 'Reference measurement';

  @override
  String get settingsReferenceHint => 'How accurate is the detection? Darts in known positions show it in millimetres';

  @override
  String get referenceIntro =>
      'You push one dart after the other by hand into a known position: the centre of the bull, then corners where a radial wire meets a ring wire. The engine locates every dart, and the distance from the position is the error of the whole system, from calibration to tip. Ten darts take about five minutes; the board must be calibrated.';

  @override
  String get referenceNotCalibrated => 'Calibrate the cameras first (Settings → Calibration).';

  @override
  String referenceProgress(int number, int total) {
    return 'Dart $number of $total';
  }

  @override
  String get referenceBullCentre => 'Push a dart into the very centre of the bull, then take your hand away.';

  @override
  String referenceCorner(String field, int a, int b) {
    return 'Push a dart into $field, into the corner at the wire between $a and $b, then take your hand away.';
  }

  @override
  String get referenceCornerHint =>
      'The point touches both wires: the radial wire and the ring wire. Push it in by hand, do not throw.';

  @override
  String get referenceResults => 'Measured darts';

  @override
  String get referenceAbstained => 'Not located';

  @override
  String referenceError(String mm) {
    return '$mm mm off';
  }

  @override
  String referenceCamerasUsed(int count) {
    return '$count cameras';
  }

  @override
  String get referenceLocated => 'Located';

  @override
  String get referenceMedian => 'Median error';

  @override
  String get referenceP90 => '90 % within';

  @override
  String get referenceMax => 'Worst';

  @override
  String get referenceGood => 'The detection is accurate.';

  @override
  String get referenceNotGood => 'The detection is not accurate enough yet.';

  @override
  String get referenceNotGoodHint =>
      'Run the setup diagnosis to see where the error comes from, then calibrate the cameras it names again.';

  @override
  String get referenceCamerasDisagree => 'The cameras disagree about where it is';

  @override
  String get referenceSeenByOneCamera => 'Only one camera saw it';

  @override
  String cameraMovedNotice(String camera) {
    return '$camera was moved – its calibration is being checked.';
  }

  @override
  String get rigKnockedNotice => 'The rig was knocked – the calibration is being checked.';

  @override
  String get simulateDarts => 'Simulate darts';

  @override
  String get simulateDartsHint => 'For trying the app: the engine plays generated darts instead of detecting them.';

  @override
  String get localEngineLiveUnavailable =>
      'This engine cannot detect darts yet. Switch on \"Simulate darts\", or update the engine.';

  @override
  String get detectionNotCalibrated =>
      'Not calibrated yet – darts are not detected. Calibrate the cameras under Settings.';

  @override
  String get detectionWaitingForEmptyBoard => 'Waiting for an empty, still board before detecting darts.';

  @override
  String get detectionPaused => 'Detection paused';

  @override
  String get detectionUnavailable => 'Darts are not detected right now.';

  @override
  String get shareEngine => 'Share in the network';

  @override
  String get shareEngineHint =>
      'Phones and tablets in your home network can connect to this engine. Only in a network you trust: there is no PIN yet.';

  @override
  String get showEngineQr => 'QR code';

  @override
  String get engineQrTitle => 'Connect another device';

  @override
  String get engineQrHint =>
      'Scan this code with the DartPilot app on your phone or tablet (Engine → In the network → scan).';

  @override
  String get engineQrNoNetwork => 'This device has no address in a home network.';

  @override
  String get scanEngineQr => 'Scan QR code';

  @override
  String get scanEngineQrHint => 'Point the camera at the QR code that the engine\'s device shows.';

  @override
  String get enterAddressManually => 'Enter the address or scan a QR code';

  @override
  String get restartEngine => 'Restart the engine';

  @override
  String get engineSettings => 'Engine';

  @override
  String get assignCameras => 'Assign cameras';

  @override
  String get assignCamerasHint =>
      'Each camera gets its place: camera 1, 2, 3. The live image shows which is which. The arrows swap two cameras, and a name helps to find one again.';

  @override
  String get cameraNameLabel => 'Name (optional)';

  @override
  String get moveCameraUp => 'Move up';

  @override
  String get moveCameraDown => 'Move down';

  @override
  String get saveCameraOrder => 'Apply';

  @override
  String get newCamerasTitle => 'New cameras found';

  @override
  String get newCamerasText => 'Assign them once, so that camera 1, 2 and 3 are always the same.';

  @override
  String get statsAverageTrend => 'Average over games (X01)';

  @override
  String get statsHitBoard => 'Hit board';

  @override
  String statsMisses(int count) {
    return 'Misses: $count';
  }

  @override
  String get statsExport => 'Export';

  @override
  String get exportDartsCsv => 'All darts as CSV';

  @override
  String get exportGamesJson => 'Games and figures as JSON';

  @override
  String exportSaved(String path) {
    return 'Saved: $path';
  }

  @override
  String exportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get copyPath => 'Copy path';
}
