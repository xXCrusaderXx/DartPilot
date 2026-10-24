// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'DartPilot';

  @override
  String get chooseGame => 'Spiel wählen';

  @override
  String get modeX01 => 'X01';

  @override
  String get modeX01Description => '501 oder 301, Double-Out';

  @override
  String get modeCricket => 'Cricket';

  @override
  String get modeCricketDescription => '15 bis 20 und Bull schließen';

  @override
  String get modeAroundTheClock => 'Around the Clock';

  @override
  String get modeAroundTheClockDescription => '1 bis 20 der Reihe nach treffen';

  @override
  String get modeTraining => 'Freies Werfen';

  @override
  String get modeTrainingDescription => 'Jeder Dart wird angezeigt und gezählt';

  @override
  String get inputBoard => 'Scheibe';

  @override
  String get inputKeypad => 'Tastenfeld';

  @override
  String get single => 'Single';

  @override
  String get double => 'Double';

  @override
  String get triple => 'Triple';

  @override
  String get miss => 'Daneben';

  @override
  String get undo => 'Rückgängig';

  @override
  String get visit => 'Aufnahme';

  @override
  String get darts => 'Darts';

  @override
  String get points => 'Punkte';

  @override
  String get average => '3-Dart-Schnitt';

  @override
  String get newVisit => 'Nächste Aufnahme';

  @override
  String get noThrowsYet => 'Tippe auf die Scheibe oder nutze das Tastenfeld';

  @override
  String get x01Setup => 'Neues X01-Spiel';

  @override
  String get players => 'Spieler';

  @override
  String get addPlayer => 'Spieler hinzufügen';

  @override
  String playerName(int number) {
    return 'Spieler $number';
  }

  @override
  String get startScore => 'Startpunktzahl';

  @override
  String get doubleIn => 'Double-In';

  @override
  String get doubleOut => 'Double-Out';

  @override
  String get legsToWin => 'Legs zum Sieg';

  @override
  String get startGame => 'Spiel starten';

  @override
  String leg(int number) {
    return 'Leg $number';
  }

  @override
  String get legs => 'Legs';

  @override
  String get checkout => 'Checkout';

  @override
  String get bust => 'Überworfen';

  @override
  String get notIn => 'nicht drin';

  @override
  String legWonBy(String name) {
    return '$name gewinnt das Leg';
  }

  @override
  String matchWonBy(String name) {
    return '$name gewinnt!';
  }

  @override
  String get newGame => 'Neues Spiel';

  @override
  String get backToMenu => 'Menü';

  @override
  String get removePlayer => 'Spieler entfernen';

  @override
  String get cricketSetup => 'Neues Cricket-Spiel';

  @override
  String get aroundTheClockSetup => 'Neues Around-the-Clock-Spiel';

  @override
  String get endWithBull => 'Mit Bull beenden';

  @override
  String get target => 'Ziel';

  @override
  String get marksPerRound => 'Marks pro Runde';

  @override
  String get hitRate => 'Trefferquote';

  @override
  String get bull => 'Bull';
}
