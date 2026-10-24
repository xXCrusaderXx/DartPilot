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
  String get chooseGame => 'Lokal oder solo spielen';

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

  @override
  String get boardOccupiedTitle => 'Darts aus der Scheibe ziehen';

  @override
  String get boardOccupiedText =>
      'Die Kameras sehen etwas in der Scheibe. Zieh die Darts heraus, bevor das Spiel beginnt.';

  @override
  String get boardOccupiedBanner => 'Darts in der Scheibe';

  @override
  String get checkBoardAgain => 'Erneut prüfen';

  @override
  String get startAnyway => 'Trotzdem starten';

  @override
  String get show => 'Anzeigen';

  @override
  String get emptyReferenceMissing => 'Kein Bild der leeren Scheibe gespeichert';

  @override
  String get storeEmptyReference => 'Leere Scheibe speichern';

  @override
  String get emptyReferenceStored => 'Leere Scheibe gespeichert';

  @override
  String get boardNotEmpty => 'Die Scheibe ist nicht leer; zieh zuerst die Darts.';

  @override
  String get storeReferenceFailed => 'Leere Scheibe konnte nicht gespeichert werden';

  @override
  String get searchEngines => 'Engines im Netzwerk suchen';

  @override
  String get searchingEngines => 'Suche im Netzwerk…';

  @override
  String get noEnginesFound =>
      'Keine Engine gefunden. Gast-WLAN, Client-Isolation oder getrennte Netze verhindern die Suche; gib die Adresse dann von Hand ein.';

  @override
  String get foundEngines => 'Engines im Netzwerk';

  @override
  String engineIncompatible(String protocol) {
    return 'inkompatibel ($protocol)';
  }

  @override
  String get boardIsEmpty => 'Die Scheibe ist leer';

  @override
  String get boardIsEmptyTitle => 'Leere Scheibe neu speichern?';

  @override
  String get boardIsEmptyText =>
      'Nur wenn wirklich kein Dart und nichts anderes in der Scheibe steckt. Die aktuellen Kamerabilder werden das neue Bild der leeren Scheibe, und die Prüfung vergleicht ab jetzt damit.';

  @override
  String get boardNotStill => 'Das Bild ist noch nicht ruhig; warte einen Moment und versuch es noch einmal.';

  @override
  String get engineThisDevice => 'Auf diesem Gerät';

  @override
  String get engineNetwork => 'Im Netzwerk';

  @override
  String get localEngineStopped => 'Die Engine auf diesem Gerät ist gestoppt.';

  @override
  String get localEngineStarting => 'Engine startet…';

  @override
  String localEngineRunning(String url) {
    return 'Die Engine läuft auf diesem Gerät ($url).';
  }

  @override
  String get localEngineNotFound => 'Das Engine-Programm wurde nicht gefunden. Trag seinen Pfad unter Log ein.';

  @override
  String get localEngineNoCameras =>
      'Keine Kamera ließ sich starten: Sind sie eingesteckt oder von einem anderen Programm belegt?';

  @override
  String get localEnginePortInUse => 'Der Port der Engine ist belegt; vielleicht läuft schon eine andere Engine.';

  @override
  String get localEngineCrashed => 'Die Engine hat sich unerwartet beendet; das Log zeigt warum.';

  @override
  String get useCameras => 'Kameras verwenden';

  @override
  String get useCamerasHint =>
      'Livebilder und die Scheibenprüfung; Darts sind simuliert, bis die Erkennung fertig ist.';

  @override
  String get engineLog => 'Log';

  @override
  String get startEngine => 'Starten';

  @override
  String get stopEngine => 'Stoppen';

  @override
  String get engineProgram => 'Engine-Programm';

  @override
  String get engineProgramHint => 'Leer lassen, um es automatisch zu suchen';

  @override
  String get engineLogEmpty => 'Noch keine Ausgabe.';

  @override
  String get close => 'Schließen';

  @override
  String get diagnosis => 'Einrichtungsdiagnose';

  @override
  String get startDiagnosis => 'Starten';

  @override
  String get restartDiagnosis => 'Neu starten';

  @override
  String get stopDiagnosis => 'Stoppen';

  @override
  String get diagnosisIntro =>
      'Die Diagnose beobachtet die Kameras, während du den Schritten folgst: erst eine leere Scheibe, dann einzeln Darts an 8 bis 10 Stellen. Sie zeigt, was an der Einrichtung nicht stimmt und was zu tun ist. Starte die Kameras etwa 30 s vorher, damit sich ihre Belichtung eingestellt hat.';

  @override
  String get diagnosisNeedsEngine => 'Verbinde dich zuerst mit einer Engine.';

  @override
  String get diagnosisNotAvailable =>
      'Diese Engine kann die Diagnose nicht ausführen; sie braucht die Kameras (mit Kameras starten).';

  @override
  String diagnosisFailed(String code) {
    return 'Die Diagnose konnte nicht starten ($code).';
  }

  @override
  String get stepEmptyBoard => 'Lass die Scheibe leer und nimm die Hand aus dem Bild.';

  @override
  String get stepRemoveDarts => 'Zieh alle Darts aus der Scheibe.';

  @override
  String get stepInsertDart => 'Steck einen Dart in die Scheibe und nimm die Hand weg.';

  @override
  String get stepInsertDartHint => 'Wiederhole das an 8 bis 10 Stellen, auch im Bull und nahe am Doppelring.';

  @override
  String get stepRemoveDart => 'Zieh den Dart wieder heraus.';

  @override
  String get diagnosisMoving => 'Bild bewegt sich – ruhig halten';

  @override
  String get diagnosisSettling => 'Ruhig – kurz warten';

  @override
  String get diagnosisMeasuring => 'Misst…';

  @override
  String get diagnosisMeasured => 'Gemessen';

  @override
  String get diagnosisStopped => 'Gestoppt';

  @override
  String diagnosisSummary(String time, int empty, int darts) {
    return '$time · $empty leere Scheiben · $darts Darts';
  }

  @override
  String get diagnosisFindings => 'Befunde';

  @override
  String get diagnosisNoFindings => 'Bisher nichts gefunden.';

  @override
  String cameraNumber(int number) {
    return 'Kamera $number';
  }

  @override
  String diagnosisPeriods(int count) {
    return 'Gemessene Momente ($count)';
  }

  @override
  String get periodEmpty => 'leere Scheibe';

  @override
  String get periodDartNotLocated => 'Dart, nicht geortet';

  @override
  String periodDartLocated(String x, String y, int cameras, String plane) {
    return 'Dart bei $x, $y mm, $cameras Kameras einig auf $plane mm';
  }

  @override
  String get dartSeen => 'Dart gesehen';

  @override
  String get dartCut => 'Dart am Rand abgeschnitten';

  @override
  String get dartNotSeen => 'Dart nicht gesehen';

  @override
  String periodCalibration(String mm) {
    return '$mm mm neben der Kalibrierung';
  }

  @override
  String periodBrightness(int value) {
    return 'Helligkeit $value';
  }

  @override
  String findingLostFrames(String percent) {
    return 'Hat $percent % der Bilder verloren.';
  }

  @override
  String get hintLostFrames =>
      'Steck die Kamera an einen anderen USB-Port oder einen aktiven Hub und schließ andere Programme, die die Kameras nutzen.';

  @override
  String findingFewStillMoments(int count, String seconds) {
    return 'Nur $count ruhige Momente in $seconds s.';
  }

  @override
  String get hintFewStillMoments =>
      'Halte jeden Zustand ein paar Sekunden ruhig, die Hand aus dem Bild; kommt das Bild nie zur Ruhe, prüf auf Vibrationen.';

  @override
  String get findingNotEmptyAtStart => 'Die Scheibe war zu Beginn nicht leer: Ihre Drähte sind teilweise verdeckt.';

  @override
  String get hintNotEmptyAtStart => 'Beginne mit leerer Scheibe; alles Weitere wird mit diesem ersten Bild verglichen.';

  @override
  String get findingNoRefinement =>
      'Für diese Kamera gibt es keine Verfeinerung: Kalibrierung und Darts wurden nicht geprüft.';

  @override
  String get hintNoRefinement => 'Kalibriere sie auf der Extrinsik-Seite und verfeinere alle Kameras (Schritt 5).';

  @override
  String get findingBoardNotFound => 'Die Scheibe wurde auf keinem Bild der leeren Scheibe gefunden.';

  @override
  String get hintBoardNotFound => 'Prüf Blickwinkel und Schärfe der Kamera und das Licht auf der Scheibe.';

  @override
  String findingCalibrationOff(String mm) {
    return 'Die Scheibe liegt $mm mm neben der Kalibrierung dieser Kamera.';
  }

  @override
  String get hintCalibrationOff =>
      'Wenn Kamera oder Scheibe bewegt wurden, kalibriere die Kamera neu und verfeinere alle Kameras (Extrinsik-Seite, Schritt 5).';

  @override
  String findingDrift(String px, String minutes) {
    return 'Das Bild hat sich um $px px in $minutes min bewegt.';
  }

  @override
  String get hintDrift =>
      'Lass die Kameras vor dem Kalibrieren und Spielen etwa 10 Minuten laufen, damit sie warm sind; bewegt es sich weiter, zieh die Halterung der Kamera fest.';

  @override
  String findingLightChanged(String percent, String low, String lowS, String high, String highS) {
    return 'Die Helligkeit der leeren Scheibe hat sich um $percent % geändert ($low bei $lowS s, $high bei $highS s).';
  }

  @override
  String get hintExposureSettling =>
      'Nach dem Start braucht die automatische Belichtung einen Moment: Beginne etwa 30 s nach dem Start der Kameras und lass das Ringlicht an.';

  @override
  String get hintLightChanged => 'Nutze das Ringlicht und halte Tages- und Raumlicht während des Tests gleich.';

  @override
  String findingBoardChanged(int count) {
    return 'Die leere Scheibe hat sich zwischen den Darts $count-mal verändert.';
  }

  @override
  String get hintBoardChanged =>
      'Meist von Darts herausgedrückte Fasern oder eine leicht veränderte Schärfe; harmlos, da das Vergleichsbild nach jedem Ziehen erneuert wird.';

  @override
  String get findingNoDarts => 'Im Test wurde kein Dart gefunden.';

  @override
  String get hintNoDarts => 'Steck die Darts einzeln in die Scheibe und nimm jedes Mal die Hand weg.';

  @override
  String findingDartsLocated(int located, int darts, int abstained) {
    return '$located von $darts Darts geortet, $abstained ohne Ergebnis.';
  }

  @override
  String get hintDartsLocated => 'Warum Darts nicht geortet wurden, zeigen die Befunde pro Kamera.';

  @override
  String findingDartsCutLost(int cut, int darts, int lost) {
    return 'Hat $cut von $darts Darts am Bildrand abgeschnitten und konnte $lost davon nicht mit orten.';
  }

  @override
  String get hintDartsCutLost =>
      'Neig oder versetz die Kamera so, dass die Scheibe und etwa 15 cm darüber im Bild sind, und kalibriere sie dann neu.';

  @override
  String findingDartsCut(int cut, int darts) {
    return 'Hat $cut von $darts Darts am Bildrand abgeschnitten.';
  }

  @override
  String get hintDartsCut =>
      'Harmlos, solange die Darts trotzdem geortet werden; mehr Raum über der Scheibe im Bild macht es robuster.';

  @override
  String findingDartsNotSeen(int missed, int darts) {
    return 'Hat $missed von $darts Darts nicht gesehen.';
  }

  @override
  String get hintDartsNotSeen =>
      'Prüf, ob die Kamera die ganze Scheibe sieht; dunkle Darts auf dunklen Feldern brauchen gutes Licht.';

  @override
  String findingCameraDisagrees(int disagreed, int darts) {
    return 'Lag bei $disagreed von $darts Darts anders als die übrigen Kameras.';
  }

  @override
  String get hintCameraDisagrees =>
      'Mach den Kalibriertest; liegt er daneben, kalibriere diese Kamera neu und verfeinere alle Kameras.';

  @override
  String findingPlanesAgree(String mm) {
    return 'Wo drei Kameras einen Dart sahen, stimmten sie auf $mm mm überein (Median).';
  }

  @override
  String get hintPlanesAgree => 'Verfeinere alle Kameras erneut; fällt eine Kamera heraus, kalibriere sie zuerst.';

  @override
  String get connectTitle => 'Engine verbinden';

  @override
  String get connectIntro =>
      'Die Engine steuert die Kameras und erkennt die Darts. Sie läuft auf diesem Gerät oder auf einem anderen in deinem Netzwerk.';

  @override
  String get playWithoutEngine => 'Ohne Engine spielen (Darts von Hand eingeben)';

  @override
  String get navHome => 'Home';

  @override
  String get navSettings => 'Einstellungen';

  @override
  String get settingsConnection => 'Verbindung';

  @override
  String get connectedThisDevice => 'Verbunden mit der Engine auf diesem Gerät';

  @override
  String get connectedNetwork => 'Verbunden mit einer Engine im Netzwerk';

  @override
  String get playingWithoutEngine => 'Ohne Engine – Darts werden von Hand eingegeben';

  @override
  String get playingWithoutEngineHint => 'Verbinde eine Engine, um Darts zu erkennen und die Kameras zu nutzen.';

  @override
  String get settingsCamerasBoard => 'Kameras und Scheibe';

  @override
  String get settingsCamerasHint => 'Livebilder und der Zustand jeder Kamera';

  @override
  String get settingsDiagnosisHint => 'Schritt für Schritt herausfinden, was an der Einrichtung nicht stimmt';

  @override
  String get settingsEmptyBoardHint => 'Die Bilder der leeren Scheibe für die Scheibenprüfung speichern';

  @override
  String get settingsCalibration => 'Kalibrierung';

  @override
  String get calibration => 'Kameras kalibrieren';

  @override
  String get calibrationInSetupTool => 'Vorerst im Einrichtungsprogramm dartpilot_setup unter Linux';

  @override
  String get playTogether => 'Zusammen spielen';

  @override
  String get lobby => 'Lobby';

  @override
  String get lobbyComingSoon => 'Mit Freunden auf anderen Geräten spielen – kommt mit #124';

  @override
  String diagnosisProgress(int done, int target) {
    return 'Darts: $done von $target';
  }

  @override
  String get stepRemoveLastDart => 'Zieh den letzten Dart heraus – dann bist du fertig.';

  @override
  String get diagnosisEnough => 'Genug Darts gemessen – die Diagnose ist fertig.';

  @override
  String get finishDiagnosis => 'Diagnose beenden';

  @override
  String get diagnosisMoreDartsOptional => 'Weitere Darts sind möglich, aber nicht nötig.';

  @override
  String get diagnosisFinished => 'Diagnose abgeschlossen';

  @override
  String resultProblems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Probleme gefunden',
      one: '1 Problem gefunden',
    );
    return '$_temp0';
  }

  @override
  String resultWarnings(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count Warnungen', one: '1 Warnung');
    return '$_temp0';
  }

  @override
  String get resultFixHint => 'Die Befunde unten sagen, was zu tun ist. Danach die Diagnose noch einmal laufen lassen.';

  @override
  String get resultAllGood => 'Alles in Ordnung';

  @override
  String get resultAllGoodHint => 'Die Einrichtung ist bereit zum Spielen.';

  @override
  String resultFewDarts(int done, int target) {
    return 'Nur $done von $target Darts gemessen; die Befunde zu Darts sind weniger sicher.';
  }

  @override
  String get navStatistics => 'Statistik';

  @override
  String get statisticsEmpty =>
      'Noch keine Statistik. Wer mit eigenem Namen spielt (nicht „Spieler 1“), bekommt nach dem ersten Spiel eine Statistik.';

  @override
  String statsGamesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count Spiele', one: '1 Spiel');
    return '$_temp0';
  }

  @override
  String get statsGames => 'Spiele';

  @override
  String statsWon(int count) {
    return '$count gewonnen';
  }

  @override
  String get statsDarts => 'Darts';

  @override
  String get statsFirst9 => 'First-9-Average';

  @override
  String get statsLegs => 'Legs';

  @override
  String get statsBestLeg => 'Bestes Leg';

  @override
  String statsDartsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count Darts', one: '1 Dart');
    return '$_temp0';
  }

  @override
  String get statsCheckoutRate => 'Checkout-Quote';

  @override
  String get statsHighestFinish => 'Höchstes Finish';

  @override
  String get statsMarksPerRound => 'Marks pro Runde';

  @override
  String get statsClockHitRate => 'Around-the-Clock-Treffer';

  @override
  String get periodLastGame => 'Letztes Spiel';

  @override
  String get periodWeek => '7 Tage';

  @override
  String get periodMonth => '30 Tage';

  @override
  String get periodAll => 'Gesamt';

  @override
  String get statsNoGamesInPeriod => 'Keine Spiele in diesem Zeitraum.';

  @override
  String get statsHits => 'Wo die Darts landeten';

  @override
  String get ringTriple => 'Triple';

  @override
  String get ringDouble => 'Double';

  @override
  String get ringSingleInner => 'Single (innen)';

  @override
  String get ringSingleOuter => 'Single (außen)';

  @override
  String get ringOuterBull => 'Single-Bull';

  @override
  String get ringBull => 'Bull';

  @override
  String get ringMiss => 'Daneben';

  @override
  String get statsFavouriteDoubles => 'Beendet auf';

  @override
  String get statsHistory => 'Spiele';

  @override
  String statsOpponents(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'gegen $count Spieler',
      one: 'gegen 1 Spieler',
    );
    return '$_temp0';
  }

  @override
  String get statsSolo => 'solo';
}
