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
  String get engineFailedRefused => 'Unter dieser Adresse antwortet nichts. Läuft die Engine?';

  @override
  String get engineFailedTimeout => 'Die Engine war nicht rechtzeitig erreichbar. Prüfe Adresse und Netzwerk.';

  @override
  String get engineFailedHost => 'Diese Adresse wurde im Netzwerk nicht gefunden.';

  @override
  String get engineFailedAddress => 'Das ist keine Engine-Adresse; sie sieht aus wie ws://192.168.1.20:8484/.';

  @override
  String get engineRetry => 'Erneut versuchen';

  @override
  String get engineErrorDisconnected => 'Die Verbindung zur Engine ist abgerissen.';

  @override
  String get engineErrorTimeout => 'Die Engine hat nicht geantwortet.';

  @override
  String get engineSimulated => 'simuliert';

  @override
  String uncertainDart(String label, String percent) {
    return 'Unsicher: $label ($percent)';
  }

  @override
  String get uncertainNoPoint => 'Ein Dart wurde erkannt, aber nicht wo';

  @override
  String get confirm => 'Bestätigen';

  @override
  String get discard => 'Verwerfen';

  @override
  String get discardCameraOrderTitle => 'Geänderte Reihenfolge und Namen verwerfen?';

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
  String get removeDarts => 'Darts entfernen';

  @override
  String get removeDartsHint => 'Die nächste Aufnahme beginnt, sobald die Darts aus dem Board sind.';

  @override
  String get dartsRemoved => 'Darts sind raus';

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
  String get cameraUnknown => 'Unbekannt';

  @override
  String cameraNoFrameFor(int seconds) {
    return 'Kein Bild seit $seconds s';
  }

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
  String diagnosisStopFailed(String code) {
    return 'Die Diagnose konnte nicht gestoppt werden ($code).';
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
    String _temp0 = intl.Intl.pluralLogic(
      empty,
      locale: localeName,
      other: '$empty leere Scheiben',
      one: '1 leere Scheibe',
    );
    String _temp1 = intl.Intl.pluralLogic(darts, locale: localeName, other: '$darts Darts', one: '1 Dart');
    return '$time · $_temp0 · $_temp1';
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
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count-mal', one: 'einmal');
    return 'Die leere Scheibe hat sich zwischen den Darts $_temp0 verändert.';
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
  String get navStatistics => 'Spieler';

  @override
  String get statisticsEmpty => 'Noch keine Spieler. Leg ein Profil an; jedes Spiel zählt für seine Statistik.';

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

  @override
  String get localEngineNoAnswer =>
      'Das Programm hat sich nicht als Engine gemeldet und wurde beendet. Prüf das Engine-Programm unter Log.';

  @override
  String get newProfile => 'Neues Profil';

  @override
  String get profileName => 'Name';

  @override
  String get profileNameEmpty => 'Gib einen Namen ein.';

  @override
  String get profileNameExists => 'Es gibt schon ein Profil mit diesem Namen.';

  @override
  String get createProfile => 'Anlegen';

  @override
  String get pickPlayersHint => 'Tipp die Spieler in der Reihenfolge an, in der sie werfen.';

  @override
  String throwingOrder(String order) {
    return 'Reihenfolge: $order';
  }

  @override
  String get statsNoGamesYet => 'Noch keine Spiele';

  @override
  String get deleteProfile => 'Profil löschen';

  @override
  String deleteProfileText(String name) {
    return '$name wird aus den Spielern entfernt. Die Spiele bleiben gespeichert und zählen wieder, wenn ein Profil mit diesem Namen angelegt wird.';
  }

  @override
  String get delete => 'Löschen';

  @override
  String get firstProfileTitle => 'Wer spielt?';

  @override
  String get firstProfileText => 'Leg ein Spielerprofil an; jedes Spiel zählt für seine Statistik.';

  @override
  String get calibStepLight => 'Licht';

  @override
  String get calibStepBoard => 'Scheibe';

  @override
  String get calibStepRefine => 'Verfeinern';

  @override
  String get calibStepDone => 'Fertig';

  @override
  String get calibNeedsCameras => 'Die Kalibrierung braucht eine Engine mit Kameras. Verbinde zuerst eine.';

  @override
  String get calibIntro =>
      'Die Engine misst die Scheibe aus jeder Kamera ein: ohne Muster zum Halten, ohne Maßband. Du brauchst eine leere Scheibe und das Licht, in dem du spielst; das dauert ein paar Minuten.';

  @override
  String get calibStale =>
      'Eine Kamera wurde nach dem letzten Verfeinern neu eingemessen: Verfeinere alle Kameras noch einmal.';

  @override
  String get calibBoardMissing => 'Scheibe nicht eingemessen';

  @override
  String calibBoardMeasured(String mm) {
    return 'Scheibe $mm mm';
  }

  @override
  String get calibLensOwn => 'eigene Linsenkalibrierung';

  @override
  String get calibLensNone => 'keine Linsenkalibrierung';

  @override
  String get calibStart => 'Kalibrierung starten';

  @override
  String get calibLightInstruction => 'Leere die Scheibe und schalte das Licht ein, in dem du spielst.';

  @override
  String get calibLightHint =>
      'Die Engine probiert auf allen Kameras jede Farbtemperatur und behält die in der Mitte des Bereichs, in dem die Scheibe gefunden wird. Das dauert etwa eine Minute.';

  @override
  String calibLightSettling(int seconds) {
    return 'Warte auf die Belichtung der Kameras: $seconds s';
  }

  @override
  String calibLightSweeping(int kelvin) {
    return 'Probiere $kelvin K …';
  }

  @override
  String get calibLightDone => 'Licht für jede Kamera eingestellt.';

  @override
  String get calibLightFailed => 'Das Licht ließ sich nicht einstellen.';

  @override
  String get calibLightNotFound => 'Scheibe nicht gefunden';

  @override
  String get calibLightTune => 'Licht einstellen';

  @override
  String get calibLightAgain => 'Erneut einstellen';

  @override
  String get calibNext => 'Weiter';

  @override
  String calibCameraOf(int number, int count) {
    return 'Kamera $number von $count';
  }

  @override
  String get calibBoardDetectInstruction => 'Lass die Scheibe leer, die Hand aus dem Bild, und erkenne sie.';

  @override
  String get calibBoardDetectHint => 'Die Engine findet Ringe und die 20 Drähte der Scheibe im Bild dieser Kamera.';

  @override
  String get calibBoardTap20 => 'Tippe in das Feld der 20.';

  @override
  String get calibBoardTap20Hint =>
      'Irgendwo zwischen Bull und Doppelring. Die Farben wiederholen sich jedes zweite Feld, deshalb muss die Engine gesagt bekommen, welches die 20 ist.';

  @override
  String get calibBoardCheck => 'Stimmen die Zahlen mit der Scheibe überein?';

  @override
  String get calibBoardCheckHint => 'Wenn nicht, tipp noch einmal in die 20.';

  @override
  String get calibBoardNotFound =>
      'Scheibe nicht gefunden: Zieh alle Darts, nimm die Hand aus dem Bild und prüf das Licht (Schritt 1).';

  @override
  String calibBoardFit(String fit, String worst) {
    return 'Passung der Scheibe $fit mm (schlechtester Punkt $worst mm)';
  }

  @override
  String get calibBoardDetect => 'Scheibe erkennen';

  @override
  String get calibBoardDetectAgain => 'Erneut erkennen';

  @override
  String get calibNumbersMatchNext => 'Zahlen stimmen – nächste Kamera';

  @override
  String get calibNumbersMatchRefine => 'Zahlen stimmen – verfeinern';

  @override
  String get calibRefineInstruction => 'Verfeinere alle Kameras zusammen.';

  @override
  String get calibRefineHint =>
      'Aus den Scheiben aller Kameras berechnet die Engine Lage und Linse jeder Kamera und die wirkliche Größe deiner Scheibe.';

  @override
  String get calibQualityGood => 'gut';

  @override
  String get calibQualityFair => 'brauchbar';

  @override
  String get calibQualityPoor => 'nicht gut genug';

  @override
  String get calibLensFromOwn => 'Linse aus der eigenen Linsenkalibrierung';

  @override
  String get calibLensFromModel => 'Linse von einer anderen Kamera desselben Modells';

  @override
  String get calibLensFromBoard => 'Linse nur aus der Scheibe';

  @override
  String get calibAdviceDetectAgain => 'Miss die Scheibe dieser Kamera bei gleichmäßigem Licht noch einmal ein.';

  @override
  String get calibAdviceLens => 'Eine Linsenkalibrierung dieser Kamera würde sie genauer machen.';

  @override
  String get calibMeasureAgain => 'Neu einmessen';

  @override
  String calibMeasuredBoard(String bull, String treble) {
    return 'Deine Scheibe: Single-Bull $bull mm, Mitte Triple $treble mm';
  }

  @override
  String get calibRefine => 'Verfeinern';

  @override
  String get calibRefineAgain => 'Erneut verfeinern';

  @override
  String get calibDone => 'Die Kameras sind kalibriert.';

  @override
  String get calibDoneHint => 'Prüf die ganze Einrichtung mit ein paar Darts in der Einrichtungsdiagnose.';

  @override
  String get calibErrorBusy => 'Die Engine ist noch mit einem anderen Schritt beschäftigt.';

  @override
  String get calibErrorNoDetection => 'Erkenne zuerst die Scheibe.';

  @override
  String get calibErrorOutsideBoard =>
      'Dieser Punkt liegt in keinem Feld der Scheibe; tipp in die 20 zwischen Bull und Doppelring.';

  @override
  String get calibErrorFitFailed => 'Die Scheibe ließ sich nicht einpassen; erkenne sie noch einmal.';

  @override
  String get calibErrorNoBoardPlanes => 'Noch keine Kamera hat eine eingemessene Scheibe.';

  @override
  String get calibErrorPoseFailed => 'Eine Kamera ließ sich nicht einordnen; miss ihre Scheibe noch einmal ein.';

  @override
  String get calibErrorSaveFailed => 'Die Kalibrierung konnte nicht gespeichert werden.';

  @override
  String calibErrorOther(String code) {
    return 'Fehlgeschlagen ($code).';
  }

  @override
  String get calibrationHint => 'Licht, Scheibe und Verfeinern, Schritt für Schritt';

  @override
  String get addBot => 'Bot';

  @override
  String get botDifficulty => 'Schwierigkeit';

  @override
  String botAverage(int average) {
    return 'Average etwa $average';
  }

  @override
  String botName(int level, String name) {
    return 'Bot · $name';
  }

  @override
  String statsAgainstBots(String levels) {
    return 'gegen Bot Stufe $levels';
  }

  @override
  String get botLevel1 => 'Anfänger';

  @override
  String get botLevel2 => 'Gelegenheitsspieler';

  @override
  String get botLevel3 => 'Kneipenspieler';

  @override
  String get botLevel4 => 'Hobbyspieler';

  @override
  String get botLevel5 => 'Vereinsspieler';

  @override
  String get botLevel6 => 'Ligaspieler';

  @override
  String get botLevel7 => 'Stark';

  @override
  String get botLevel8 => 'Sehr stark';

  @override
  String get botLevel9 => 'Halbprofi';

  @override
  String get botLevel10 => 'Profi';

  @override
  String get calibrationCheck => 'Kalibriercheck';

  @override
  String get calibrationCheckHint => 'Hat sich eine Kamera bewegt? Jede Kamera gegen ihre Kalibrierung';

  @override
  String get calibrationCheckIntro =>
      'Lass die Scheibe leer. Blaue Ringe zeigen, wo die Kalibrierung die Punkte der Scheibe erwartet, grüne Punkte, wo sie gerade liegen; lange gelbe Linien heißen, dass sich Kamera oder Scheibe bewegt haben. Die Engine prüft das auch im Hintergrund, immer wenn die Scheibe leer ist.';

  @override
  String checkOk(String mm) {
    return 'Passt zur Kalibrierung ($mm mm).';
  }

  @override
  String checkOff(String mm) {
    return 'Leicht daneben ($mm mm), z. B. anderes Licht. Die Erkennung funktioniert noch.';
  }

  @override
  String checkMoved(String mm) {
    return 'Kamera oder Scheibe hat sich bewegt ($mm mm). Miss diese Kamera neu ein.';
  }

  @override
  String checkWrongPort(String camera) {
    return 'Falscher USB-Port? Dieses Bild passt zur Kalibrierung von Kamera $camera.';
  }

  @override
  String get checkNoBoard => 'Keine Scheibe gefunden – Darts in der Scheibe oder eine Hand im Bild?';

  @override
  String get checkNotCalibrated => 'Noch nicht kalibriert.';

  @override
  String get checkChecking => 'Prüfe …';

  @override
  String homeCameraMoved(String camera) {
    return '$camera hat sich bewegt – miss sie neu ein.';
  }

  @override
  String homeCameraWrongPort(String camera) {
    return '$camera steckt an einem anderen USB-Port als beim Kalibrieren.';
  }

  @override
  String get referenceRun => 'Referenzmessung';

  @override
  String get settingsReferenceHint =>
      'Wie genau ist die Erkennung? Darts an bekannten Stellen zeigen es in Millimetern';

  @override
  String get referenceIntro =>
      'Du steckst einen Dart nach dem anderen von Hand an eine bekannte Stelle: in die Mitte des Bulls, dann in Ecken, wo ein Radialdraht auf einen Ringdraht trifft. Die Engine ortet jeden Dart, und der Abstand zur Stelle ist der Fehler des ganzen Systems, von der Kalibrierung bis zur Spitze. Zehn Darts dauern etwa fünf Minuten; die Scheibe muss kalibriert sein.';

  @override
  String get referenceWaiting => 'Warte auf die nächste Position…';

  @override
  String referenceStopped(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count Darts', one: '1 Dart');
    return 'Nach $_temp0 abgebrochen. Starte neu für ein Urteil.';
  }

  @override
  String get referenceNotCalibrated => 'Kalibriere zuerst die Kameras (Einstellungen → Kalibrierung).';

  @override
  String referenceProgress(int number, int total) {
    return 'Dart $number von $total';
  }

  @override
  String get referenceBullCentre => 'Steck einen Dart genau in die Mitte des Bulls und nimm die Hand weg.';

  @override
  String referenceCorner(String field, int a, int b) {
    return 'Steck einen Dart in $field, in die Ecke am Draht zwischen $a und $b, und nimm die Hand weg.';
  }

  @override
  String get referenceCornerHint =>
      'Die Spitze berührt beide Drähte: den Radialdraht und den Ringdraht. Von Hand stecken, nicht werfen.';

  @override
  String get referenceResults => 'Gemessene Darts';

  @override
  String get referenceAbstained => 'Nicht geortet';

  @override
  String referenceError(String mm) {
    return '$mm mm daneben';
  }

  @override
  String referenceCamerasUsed(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count Kameras', one: '1 Kamera');
    return '$_temp0';
  }

  @override
  String get referenceLocated => 'Geortet';

  @override
  String get referenceMedian => 'Median-Fehler';

  @override
  String get referenceP90 => '90 % innerhalb';

  @override
  String get referenceMax => 'Schlechtester';

  @override
  String get referenceGood => 'Die Erkennung ist genau.';

  @override
  String get referenceNotGood => 'Die Erkennung ist noch nicht genau genug.';

  @override
  String get referenceNotGoodHint =>
      'Lass die Einrichtungsdiagnose laufen, um zu sehen, woher der Fehler kommt, und kalibriere die genannten Kameras neu.';

  @override
  String get referenceCamerasDisagree => 'Die Kameras sind sich nicht einig, wo er steckt';

  @override
  String get referenceSeenByOneCamera => 'Nur eine Kamera hat ihn gesehen';

  @override
  String cameraMovedNotice(String camera) {
    return '$camera wurde verschoben – die Kalibrierung wird geprüft.';
  }

  @override
  String get rigKnockedNotice => 'Das Gestell wurde angestoßen – die Kalibrierung wird geprüft.';

  @override
  String get simulateDarts => 'Darts simulieren';

  @override
  String get simulateDartsHint => 'Zum Ausprobieren: Die Engine spielt erzeugte Darts, statt sie zu erkennen.';

  @override
  String get localEngineLiveUnavailable =>
      'Diese Engine kann noch keine Darts erkennen. Schalte „Darts simulieren“ ein oder aktualisiere die Engine.';

  @override
  String get detectionNotCalibrated =>
      'Noch nicht kalibriert – Darts werden nicht erkannt. Kalibriere die Kameras unter Einstellungen.';

  @override
  String get detectionWaitingForEmptyBoard => 'Warte auf eine leere, ruhige Scheibe, bevor Darts erkannt werden.';

  @override
  String get detectionPaused => 'Erkennung pausiert';

  @override
  String get detectionUnavailable => 'Darts werden gerade nicht erkannt.';

  @override
  String get shareEngine => 'Im Netzwerk freigeben';

  @override
  String get shareEngineHint =>
      'Handys und Tablets im Heimnetz können sich mit dieser Engine verbinden. Nur in einem Netz, dem du vertraust: Es gibt noch keinen PIN.';

  @override
  String get showEngineQr => 'QR-Code';

  @override
  String get engineQrTitle => 'Anderes Gerät verbinden';

  @override
  String get engineQrHint =>
      'Scanne diesen Code mit der DartPilot-App auf Handy oder Tablet (Engine → Im Netzwerk → Scannen).';

  @override
  String get engineQrNoNetwork => 'Dieses Gerät hat keine Adresse in einem Heimnetz.';

  @override
  String get scanEngineQr => 'QR-Code scannen';

  @override
  String get scanEngineQrHint => 'Richte die Kamera auf den QR-Code, den das Gerät mit der Engine anzeigt.';

  @override
  String get enterAddressManually => 'Adresse eingeben oder QR-Code scannen';

  @override
  String get restartEngine => 'Engine neu starten';

  @override
  String get engineSettings => 'Engine';

  @override
  String get assignCameras => 'Kameras zuordnen';

  @override
  String get assignCamerasHint =>
      'Jede Kamera bekommt ihren Platz: Kamera 1, 2, 3. Am Livebild erkennst du, welche welche ist. Mit den Pfeilen tauschst du zwei Kameras, ein Name hilft beim Wiederfinden.';

  @override
  String get cameraNameLabel => 'Name (optional)';

  @override
  String get moveCameraUp => 'Nach oben';

  @override
  String get moveCameraDown => 'Nach unten';

  @override
  String get saveCameraOrder => 'Übernehmen';

  @override
  String get newCamerasTitle => 'Neue Kameras gefunden';

  @override
  String get newCamerasText => 'Ordne sie einmal zu, damit Kamera 1, 2 und 3 immer dieselben sind.';

  @override
  String get statsAverageTrend => 'Average-Verlauf (X01)';

  @override
  String get statsHitBoard => 'Trefferbild';

  @override
  String statsMisses(int count) {
    return 'Daneben: $count';
  }

  @override
  String get statsExport => 'Exportieren';

  @override
  String get exportDartsCsv => 'Alle Darts als CSV';

  @override
  String get exportGamesJson => 'Spiele und Kennzahlen als JSON';

  @override
  String exportSaved(String path) {
    return 'Gespeichert: $path';
  }

  @override
  String exportFailed(String error) {
    return 'Export fehlgeschlagen: $error';
  }

  @override
  String get copyPath => 'Pfad kopieren';

  @override
  String get myDarts => 'Meine Darts';

  @override
  String get myDartsHint => 'Deine Darts vermessen, damit die Erkennung sie besser findet';

  @override
  String get myDartsIntro =>
      'Optional: Die Engine vermisst ein Dart-Set (Spitze, Barrel, Länge, Aussehen). Damit findet sie die Spitze genauer und hält neue Darts von steckenden auseinander. Ohne Set erkennt sie jeden Dart wie bisher.';

  @override
  String get dartSetsUnavailable => 'Diese Engine kann noch keine Darts vermessen.';

  @override
  String get noDartSets => 'Noch kein Dart-Set vermessen.';

  @override
  String get addDartSet => 'Dart-Set hinzufügen';

  @override
  String get renameDartSet => 'Umbenennen';

  @override
  String get dartSetName => 'Name des Sets';

  @override
  String get dartSetNameHint => 'z. B. Annas Darts';

  @override
  String get dartSetStart => 'Weiter';

  @override
  String get dartSetInUse => 'im Einsatz';

  @override
  String get dartSetThrownBy => 'Geworfen von:';

  @override
  String get dartPoint => 'Spitze';

  @override
  String get dartBarrel => 'Barrel';

  @override
  String get dartTotal => 'Gesamt';

  @override
  String get dartSetPutIn => 'Steck einen Dart des Sets ins Board und nimm die Hand weg.';

  @override
  String get dartSetMeasuring => 'Wird vermessen …';

  @override
  String get dartSetPlaced => 'Gemessen. Zieh den Dart und steck ihn an eine andere Stelle.';

  @override
  String get dartSetDone => 'Fertig – das Set ist vermessen.';

  @override
  String dartSetProgress(int placed, int needed) {
    return '$placed von $needed Stellen';
  }

  @override
  String get dartSetClose => 'Schließen';

  @override
  String get dartSetNotCalibrated => 'Die Kameras sind noch nicht kalibriert.';

  @override
  String get dartSetBoardNotEmpty => 'Bitte erst alle Darts aus dem Board ziehen.';

  @override
  String get dartSetBusy => 'Die Engine ist gerade beschäftigt. Versuch es gleich noch einmal.';

  @override
  String dartSetFailed(String reason) {
    return 'Vermessen fehlgeschlagen: $reason';
  }

  @override
  String get dartFlight => 'Flight';

  @override
  String dartSetPlacementFailed(String reason) {
    return '$reason Zieh den Dart und steck ihn an eine andere Stelle.';
  }

  @override
  String get dartSetCamerasDisagree => 'Die Kameras waren sich nicht einig.';

  @override
  String get dartSetSeenByOne => 'Nur eine Kamera hat den Dart gesehen.';

  @override
  String get dartSetPlacementsDisagree => 'Diese Stelle passt nicht zu den anderen Messungen.';

  @override
  String get dartSetNotMeasured => 'Der Dart ließ sich hier nicht vermessen.';

  @override
  String get dartSetSaveFailed => 'Das Set konnte nicht gespeichert werden.';

  @override
  String get dartSetBoardStillOccupied =>
      'Die Engine sieht noch etwas im Board. Ist es leer, speichere das leere Board neu – sonst geht es nicht weiter.';

  @override
  String get dartMeasureUncertain => 'unsicher';

  @override
  String get pairTitle => 'Mit der Engine koppeln';

  @override
  String pairText(String address) {
    return 'Die Engine unter $address lässt nur gekoppelte Geräte zu. Gib die PIN ein, die auf ihrem Gerät angezeigt wird – das ist nur einmal nötig.';
  }

  @override
  String get pairPin => 'PIN';

  @override
  String get pairButton => 'Koppeln';

  @override
  String get pairWrongPin => 'Die PIN stimmt nicht. Schau noch einmal auf das Gerät der Engine.';

  @override
  String get pairTooManyAttempts => 'Zu viele falsche Versuche. Warte eine Minute.';

  @override
  String pairFailed(String error) {
    return 'Koppeln fehlgeschlagen: $error';
  }

  @override
  String engineQrPin(String pin) {
    return 'PIN für andere Geräte: $pin';
  }

  @override
  String get pairedDevices => 'Gekoppelte Geräte';

  @override
  String get noPairedDevices => 'Noch kein Gerät gekoppelt.';

  @override
  String pairedDeviceSeen(String when) {
    return 'zuletzt $when';
  }

  @override
  String get unpairDevice => 'Entkoppeln';

  @override
  String get watchGame => 'Zuschauen';

  @override
  String get sharedGameEnded => 'Das Spiel auf dem anderen Gerät ist beendet.';

  @override
  String watchGameTitle(String mode) {
    return 'Laufendes Spiel ansehen: $mode';
  }

  @override
  String get scoreCaller => 'Score-Ansage';

  @override
  String get scoreCallerHint => 'Sagt die Punkte jeder Aufnahme an, wie ein Caller';

  @override
  String get callerVolume => 'Lautstärke der Ansage';

  @override
  String get callerTest => 'Probe';

  @override
  String get callerNoVoice =>
      'Auf diesem Gerät gibt es keine Sprachausgabe. Unter Linux: speech-dispatcher installieren (spd-say).';

  @override
  String cameraAssignFailed(String error) {
    return 'Zuordnung nicht gespeichert: $error';
  }

  @override
  String get addSetMeasure => 'Im Board vermessen';

  @override
  String get addSetMeasureHint => 'Einen Dart an vier Stellen stecken – die Kameras messen ihn';

  @override
  String get addSetEnter => 'Maße eintippen';

  @override
  String get addSetEnterHint => 'Zum Beispiel von der Verpackung';

  @override
  String get enterDims => 'Maße eingeben';

  @override
  String get dimsHint => 'Werte z. B. von der Verpackung. Ein leeres Feld lässt den gemessenen Wert gelten.';

  @override
  String get dimTotal => 'Gesamtlänge';

  @override
  String get dimPoint => 'Spitze';

  @override
  String get dimBarrel => 'Barrel';

  @override
  String get dimBarrelDiameter => 'Barrel-Durchmesser';

  @override
  String get dimShaft => 'Schaft';

  @override
  String get dimFlight => 'Flight';

  @override
  String get dimWeight => 'Gewicht';

  @override
  String get dimEntered => 'eingegeben';

  @override
  String get dimPhoto => 'Foto';

  @override
  String dimMeasuredValue(String value) {
    return 'gemessen: $value';
  }

  @override
  String get dimsSave => 'Speichern';

  @override
  String get dimsImplausible => 'Ein Wert liegt außerhalb dessen, was ein Dart haben kann.';

  @override
  String get addSetPhoto => 'Per Foto vermessen';

  @override
  String get addSetPhotoHint => 'Dart auf das ausgedruckte Messblatt legen und fotografieren';

  @override
  String get dartPhotoHowTo =>
      'Das Messblatt (docs/calibration/dart-sheet-A4.png) in 100 % auf A4 drucken und flach hinlegen. Einen Dart des Sets mitten aufs Blatt legen. Von oben fotografieren, so dass alle vier Marker in den Ecken ganz zu sehen sind.';

  @override
  String get dartPhotoTake => 'Foto aufnehmen';

  @override
  String get dartPhotoMeasuring => 'Foto wird ausgewertet …';

  @override
  String get dartPhotoDone => 'Foto ausgewertet – die Maße stehen beim Set.';

  @override
  String get dartPhotoNoSheet => 'Das Messblatt wurde nicht gefunden. Alle vier Marker müssen ganz im Bild sein.';

  @override
  String get dartPhotoNoDart => 'Auf dem Blatt wurde kein Dart gefunden. Leg ihn mitten aufs Blatt, ohne Schatten.';

  @override
  String get modeGrouping => 'Gruppieren';

  @override
  String get modeGroupingDescription => 'Darts auf ein Ziel, bewertet danach, wie eng sie liegen';

  @override
  String get groupingTarget => 'Ziel';

  @override
  String get groupingDartCount => 'Darts pro Runde';

  @override
  String get groupingPickPlayer => 'Wer wirft? Nur Profile behalten ihre Präzision.';

  @override
  String groupingProgress(int thrown, int total) {
    return 'Dart $thrown von $total';
  }

  @override
  String get precisionSpread => 'Streuung';

  @override
  String get precisionOffset => 'Versatz';

  @override
  String get precisionOnTarget => 'im Ziel';

  @override
  String offsetRight(String mm) {
    return '$mm mm rechts';
  }

  @override
  String offsetLeft(String mm) {
    return '$mm mm links';
  }

  @override
  String offsetHigh(String mm) {
    return '$mm mm hoch';
  }

  @override
  String offsetLow(String mm) {
    return '$mm mm tief';
  }

  @override
  String missFromTarget(String mm, String direction) {
    return '$mm mm daneben: $direction';
  }

  @override
  String get groupingNotMeasured =>
      'Darts über die Zifferntasten und korrigierte Darts haben keinen gemessenen Punkt und zählen nicht für die Gruppe.';

  @override
  String get groupingDone => 'Runde fertig';

  @override
  String get groupingAgain => 'Noch eine Runde';

  @override
  String get statsPrecision => 'Präzision';

  @override
  String get statsPrecisionEmpty =>
      'Spiel das Gruppieren-Training, um deine Streuung und deinen Versatz pro Ziel zu sehen.';

  @override
  String get statsPrecisionTrend => 'Streuung pro Woche';

  @override
  String get statsPrecisionHelp =>
      'Streuung: wie weit die Darts im Mittel von ihrer eigenen Mitte liegen (quadratisches Mittel). Versatz: wie weit diese Mitte vom Ziel liegt. In der Ellipse liegen etwa zwei von fünf Darts.';

  @override
  String get modeDoubles => 'Doppel-Training';

  @override
  String get modeDoublesDescription => 'Eine Aufnahme pro Doppel; deine Doppel sortiert nach Trefferquote und Streuung';

  @override
  String get doublesSet => 'Doppel';

  @override
  String get doublesTop10 => 'Die 10 meistgespielten';

  @override
  String get doublesAll => 'Alle 20 und Bull';

  @override
  String get doublesWeakest => 'Deine 5 schwächsten';

  @override
  String get doublesRanking => 'Deine Doppel, die besten zuerst';

  @override
  String get doublesRound => 'Diese Runde';

  @override
  String get modeCheckout => 'Checkout-Trainer';

  @override
  String get modeCheckoutDescription =>
      'Zufällige Finishes oder die 121-Leiter; jeder Fehlwurf gemessen am Feld, auf das du zielen solltest';

  @override
  String get checkoutRange => 'Finishes';

  @override
  String get checkoutCount => 'Checkouts pro Runde';

  @override
  String get checkoutDarts => 'Darts pro Checkout';

  @override
  String checkoutAim(String field) {
    return 'Ziel: $field';
  }

  @override
  String checkoutProgress(int number, int total) {
    return 'Checkout $number von $total';
  }

  @override
  String checkoutLeft(int points) {
    return 'Rest $points';
  }

  @override
  String get checkoutHit => 'Gecheckt';

  @override
  String get checkoutMissed => 'Nicht gecheckt';

  @override
  String aimedAt(String field) {
    return 'auf $field';
  }

  @override
  String get modePrecision => 'Präzisionstraining';

  @override
  String get modePrecisionDescription => 'Gruppieren, Doppel und Checkouts, gemessen in Millimetern';

  @override
  String get or => 'oder';

  @override
  String get pickCandidate => 'Tipp auf das richtige Feld oder auf die Stelle im Board, wo der Dart steckt.';

  @override
  String get callCheckout => 'Checkout ansagen';

  @override
  String get modeMoreGames => 'Weitere Spiele';

  @override
  String get modeMoreGamesDescription => 'Shanghai, Bob\'s 27, Halve-It und Killer';

  @override
  String get modeShanghai => 'Shanghai';

  @override
  String get modeShanghaiDescription =>
      'Runden 1 bis 7 auf die jeweilige Zahl; Single, Double und Triple in einer Aufnahme gewinnen sofort';

  @override
  String get shanghaiAllNumbers => 'Alle 20 Zahlen statt 7';

  @override
  String get modeBobs27 => 'Bob\'s 27';

  @override
  String get modeBobs27Description =>
      'Doppel-Training: Start mit 27, D1 bis Bull; eine Aufnahme ohne Treffer kostet das Doppel';

  @override
  String get modeHalveIt => 'Halve-It';

  @override
  String get modeHalveItDescription => 'Start mit 40; eine Aufnahme ohne Treffer auf das Ziel halbiert deine Punkte';

  @override
  String roundOf(int round, int total) {
    return 'Runde $round von $total';
  }

  @override
  String get playerOut => 'raus';

  @override
  String get targetAnyDouble => 'beliebiges Doppel';

  @override
  String get targetAnyTriple => 'beliebiges Triple';

  @override
  String get cutThroat => 'Cut-Throat: Punkte gehen an die Gegner, die wenigsten Punkte gewinnen';

  @override
  String ladderBest(String score) {
    return 'Höchster Checkout: $score';
  }

  @override
  String get modeKiller => 'Killer';

  @override
  String get modeKillerDescription =>
      'Triff dreimal dein eigenes Doppel, dann wirst du Killer und nimmst den anderen Leben';

  @override
  String get killerIsKiller => 'Killer';

  @override
  String killerMarks(int marks, int needed, String field) {
    return '$marks von $needed auf $field';
  }

  @override
  String throwViewTitle(String label) {
    return 'Dart $label';
  }

  @override
  String get throwViewBefore => 'Vorher';

  @override
  String get throwViewAfter => 'Nachher';

  @override
  String get throwViewLegend =>
      'Linie: die Achse des Darts, wie die Kamera ihn sah. Ring: die gefundene Spitze. Kreuz: der berechnete Punkt.';

  @override
  String get throwViewNoEngine =>
      'Kamerabilder kommen von der Engine. Verbinde dich mit der Engine, die diesen Dart erkannt hat.';

  @override
  String get throwViewNotAvailable =>
      'Die Engine hat keine Kamerabilder dieses Darts, z. B. weil er von Hand eingegeben oder simuliert wurde.';

  @override
  String throwViewFailed(String code) {
    return 'Die Kamerabilder konnten nicht geladen werden ($code).';
  }

  @override
  String get throwViewCorrect => 'Diesen Dart korrigieren';

  @override
  String get throwViewUsed => 'gezählt';

  @override
  String get throwViewNotUsed => 'nicht gezählt';

  @override
  String get throwViewNotSeen => 'hat den Dart nicht gesehen';

  @override
  String get throwViewCut => 'Dart vom Bildrand abgeschnitten';

  @override
  String get throwViewDisagrees => 'passt nicht zu den anderen Kameras';

  @override
  String throwViewPlaneDistance(String mm) {
    return '$mm mm neben dem Punkt';
  }

  @override
  String get throwViewOpen => 'Kamerabilder';

  @override
  String get gameThrowsTitle => 'Darts des Spiels';
}
