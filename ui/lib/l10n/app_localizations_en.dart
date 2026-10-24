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
  String get comingSoon => 'Coming soon';

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
}
