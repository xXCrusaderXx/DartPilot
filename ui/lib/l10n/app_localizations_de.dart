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

  @override
  String get engine => 'Engine';

  @override
  String get engineAddress => 'Engine-Adresse';

  @override
  String get connect => 'Verbinden';

  @override
  String get disconnect => 'Trennen';

  @override
  String get engineConnected => 'Verbunden';

  @override
  String get engineConnecting => 'Verbinde…';

  @override
  String get engineDisconnected => 'Nicht verbunden';

  @override
  String get engineFailed => 'Verbindung fehlgeschlagen';

  @override
  String get engineSimulated => 'simuliert';

  @override
  String uncertainDart(String label, int percent) {
    return 'Unsicher: $label ($percent %)';
  }

  @override
  String get uncertainNoPoint => 'Ein Dart wurde erkannt, aber nicht wo';

  @override
  String get confirm => 'Bestätigen';

  @override
  String get discard => 'Verwerfen';

  @override
  String get tapToCorrect => 'Tippe auf die Stelle, an der der Dart steckt';

  @override
  String get recentDarts => 'Letzte Darts';

  @override
  String correctingDart(String label) {
    return '$label korrigieren – tippe auf die Scheibe';
  }

  @override
  String get cancel => 'Abbrechen';

  @override
  String missingDarts(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count Darts fehlen', one: '1 Dart fehlt');
    return '$_temp0';
  }

  @override
  String get countAsMiss => 'Als Daneben zählen';

  @override
  String get enterManually => 'Selbst eingeben';

  @override
  String get cameras => 'Kameras';

  @override
  String get waitingForImage => 'Warte auf das erste Bild…';

  @override
  String get cameraOk => 'OK';

  @override
  String get cameraDegraded => 'Gestört';

  @override
  String get cameraLost => 'Verloren';

  @override
  String get noCameras => 'Die Engine hat keine Kameras';

  @override
  String fps(String value) {
    return '$value fps';
  }

  @override
  String get lostFrames => 'Verloren';

  @override
  String get droppedFrames => 'Verworfen';

  @override
  String get brightness => 'Helligkeit';

  @override
  String get preview => 'Vorschau';

  @override
  String get expandAll => 'Alle aufklappen';

  @override
  String get collapseAll => 'Alle zuklappen';

  @override
  String get tapToEnlarge => 'Tippe auf das Bild, um es zu vergrößern';

  @override
  String get latency => 'Latenz';
}
