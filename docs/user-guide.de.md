# DartPilot – Anleitung für Spieler

DartPilot zählt Steeldarts. Du kannst jeden Dart von Hand eingeben oder drei Kameras am Board die Darts erkennen lassen. Diese Anleitung ist für Spieler: wie du die App installierst, ein Spiel startest und nutzt, was sie bietet.

English: [player guide](user-guide.md).

- [Installieren](#installieren)
- [Erster Start](#erster-start)
- [Darts eingeben](#darts-eingeben)
- [Spiele](#spiele)
- [Training](#training)
- [Spieler und Statistik](#spieler-und-statistik)
- [Ton und Score-Ansage](#ton-und-score-ansage)
- [Handy oder Tablet als zweite Anzeige](#handy-oder-tablet-als-zweite-anzeige)
- [Wenn etwas nicht klappt](#wenn-etwas-nicht-klappt)

## Installieren

Lade die Datei für dein Gerät aus dem [neuesten Release](https://github.com/xXCrusaderXx/DartPilot/releases/latest) herunter. Mit `SHA256SUMS` neben den Dateien prüfst du, ob ein Download vollständig ist (`sha256sum -c SHA256SUMS --ignore-missing`).

| Gerät | Datei | Was es kann |
| ----- | ----- | ----------- |
| Linux-PC | `DartPilot-<Version>-x86_64.AppImage` | Alles, auch die Kamera-Engine |
| Android-Handy oder -Tablet | `DartPilot-<Version>.apk` | Darts von Hand eingeben, oder das Spiel einer Kamera-Engine im Netzwerk anzeigen |
| Windows-PC | `DartPilot-<Version>-windows-x64.zip` | Darts von Hand eingeben, oder mit einer Engine auf einem Linux-PC im Netzwerk verbinden |
| Webbrowser | `DartPilot-<Version>-web.zip` | Darts von Hand eingeben, oder das Spiel einer Engine im Netzwerk anzeigen |

### Linux

1. Mach die Datei ausführbar und starte sie: Rechtsklick, in den Eigenschaften „Als Programm ausführen“ erlauben, dann doppelklicken. Im Terminal: `chmod +x DartPilot-*.AppImage` und `./DartPilot-*.AppImage`.
2. Damit DartPilot im Anwendungsmenü erscheint, nimm ein Werkzeug wie Gear Lever oder AppImageLauncher, oder leg die Datei nach `~/Applications`.

Das AppImage läuft auf Ubuntu 22.04, Debian 12, Fedora 38 und neuer, und auf anderen Distributionen dieses Alters. Es braucht einen Desktop mit GTK 3, den jeder übliche Desktop hat. Für die Score-Ansage installiere speech-dispatcher (siehe [Ton und Score-Ansage](#ton-und-score-ansage)).

### Android

1. Öffne die APK auf dem Handy. Android fragt, ob Apps aus dieser Quelle (Browser oder Dateimanager) installiert werden dürfen; erlaube es einmal.
2. Für ein Update installierst du die neue APK über die alte. Spiele und Spieler bleiben erhalten.

Das Handy betreibt selbst keine Kameras. Es ist eine Anzeigetafel zum Eintippen, oder eine zweite Anzeige für das Spiel einer Kamera-Engine.

### Windows

Entpacke den Ordner an einen beliebigen Ort, zum Beispiel in `Dokumente`, und starte `dartpilot-app.exe`. Windows warnt eventuell vor einem unbekannten Herausgeber, weil die App nicht signiert ist: wähle **Weitere Informationen → Trotzdem ausführen**. Die Kamera-Engine für Windows kommt in einem späteren Release; bis dahin gibst du Darts von Hand ein oder verbindest dich mit einer Engine auf einem Linux-PC.

### Web

Entpacke den Ordner auf einen beliebigen Webserver, oder stelle ihn auf deinem eigenen PC bereit, zum Beispiel mit `python3 -m http.server 8080` im Ordner, und öffne diese Adresse im Browser. Liefere ihn über `http://` aus, wenn er sich mit einer Engine verbinden soll: Browser verbieten einer über `https://` geladenen Seite, mit der Engine zu sprechen. Spiele und Spieler bleiben in diesem Browser.

## Erster Start

Der erste Bildschirm fragt, wie du spielen willst.

- **Ohne Engine spielen (Darts von Hand eingeben):** keine Kameras nötig. Alle Spiele und Trainings funktionieren; du tippst für jeden Dart auf die Scheibe oder das Tastenfeld.
- **Auf diesem Gerät** (Linux): die App startet die Kamera-Engine selbst. Steck vorher die drei Kameras an. Beim ersten Mal richtest du sie unter **Einstellungen → Kameras & Erkennung** ein: Kameras zuordnen, vom Board aus kalibrieren und das Ergebnis von der Einrichtungsdiagnose prüfen lassen. [Kameras einrichten](setup-guide.de.md) führt Schritt für Schritt durch Montage, Schärfe, Kalibrierung und Prüfung.
- **Im Netzwerk:** die Engine läuft auf einem anderen PC. Die App sucht sie in deinem Heimnetz; findet sie nichts, tipp die Adresse ein, die dieser PC anzeigt, zum Beispiel `ws://192.168.1.20:8484`. Beim ersten Mal gibst du die PIN ein, die das Gerät der Engine zeigt.

Ändern kannst du das später unter **Einstellungen → Verbindung**.

## Darts eingeben

Mit Kameras erscheinen die Darts von selbst, etwa eine halbe Sekunde nachdem sie stecken. Ziehst du die Darts aus dem Board, endet die Aufnahme und der Nächste ist dran.

Von Hand nimmst du eine von zwei Eingaben, zwischen denen du jederzeit wechseln kannst:

- **Scheibe:** tipp dorthin, wo der Dart steckt. Die App merkt sich dabei die genaue Stelle, die das Präzisionstraining und die Trefferstatistik nutzen.
- **Tastenfeld:** wähle Single, Double oder Triple, dann die Zahl; **Daneben** für einen Dart außerhalb der Wertungsfläche.

Die App merkt sich deine Wahl auf diesem Gerät fürs nächste Spiel. Sind Kameras verbunden, bleibt die Scheibe zu sehen, damit du siehst, wo sie jeden Dart gefunden haben; nach einer Korrektur mit dem Tastenfeld kehrt die App dorthin zurück.

Am Computer oder an einer TV-Box mit Tastatur kannst du die Darts auch tippen: **S**, **D** oder **T** und dann die Zahl (**T20**, **D16**, **5**), **B** fürs Bull, **25** fürs Single-Bull, **M** oder **0** für Daneben. Eine Zahl ab 3 zählt sofort; nach 1 oder 2 tippst du die zweite Ziffer oder drückst **Enter**. **Rücktaste** löscht, was du getippt hast, oder nimmt den letzten Dart zurück.

**Rückgängig** nimmt den letzten Dart zurück. Um einen Dart zu korrigieren, den die Kameras falsch erkannt haben, tipp ihn in der Liste der letzten Darts an und tipp dann das Feld an, wo er wirklich steckt; solange ist der Dart in der Aufnahme eingerahmt. Eine Korrektur hilft DartPilot auch zu messen, wie gut die Erkennung arbeitet.

Stecken beim Spielstart noch Darts im Board, warnt dich die App; zieh sie zuerst heraus.

## Spiele

Starte ein Spiel auf dem Startbildschirm, wähle die Spieler in der Wurfreihenfolge (Profile oder Bots), stell die Optionen ein und drück **Spiel starten**. Ein verlassenes Spiel bleibt erhalten und lässt sich mit **Weiterspielen** fortsetzen.

- **X01:** 501 oder 301 genau auf null herunterspielen. Der letzte Dart muss ein Double sein (Double-Out); Double-In und die Zahl der Legs sind Optionen. Die App zeigt einen Checkout, sobald einer möglich ist.
- **Cricket:** schließe 15 bis 20 und das Bull mit je drei Treffern, und punkte auf Zahlen, die deine Gegner noch nicht geschlossen haben. Bei **Cut-Throat** gehen die Punkte an die Gegner, und die wenigsten Punkte gewinnen.
- **Around the Clock:** triff 1 bis 20 der Reihe nach.
- **Shanghai:** sieben Runden, jede auf ihre Zahl (1 in der ersten Runde, 2 in der zweiten, …). Single, Double und Triple der Zahl in einer Aufnahme gewinnen sofort.
- **Bob's 27:** Doppeltraining. Du beginnst mit 27 Punkten und wirfst auf D1, D2 bis zum Bull; ein Treffer bringt den Wert des Doubles, eine Aufnahme ohne Treffer kostet ihn. Unter null bist du raus.
- **Halve-It:** du beginnst mit 40 Punkten; jede Runde hat ein Ziel, und eine Aufnahme ohne Treffer darauf halbiert deine Punkte.
- **Killer:** jeder Spieler bekommt eine Zahl. Triff dein eigenes Double dreimal, um Killer zu werden, und nimm dann deinen Gegnern Leben, indem du ihre Doubles triffst. Wer als Letzter noch Leben hat, gewinnt.

Bots werfen wie Spieler von Anfänger (Stufe 1) bis Profi (Stufe 10), so hast du auch allein einen Gegner.

## Training

- **Freies Werfen:** jeder Dart wird gezeigt und gezählt, ohne Regeln.
- Das **Präzisionstraining** misst jeden Dart in Millimetern gegen das, worauf du gezielt hast:
  - **Gruppieren:** mehrere Darts auf ein Ziel; gewertet wird, wie eng sie beieinander liegen.
  - **Doppel-Training:** eine Aufnahme auf jedes Double; deine Doubles werden nach Trefferquote und Streuung geordnet.
  - **Checkout-Trainer:** zufällige Finishes oder die 121er-Leiter; jeder Fehlwurf wird gegen das Feld gemessen, auf das du zielen musstest.

Präzision braucht die genaue Stelle jedes Darts: Darts von den Kameras oder auf der Scheibe angetippt zählen, Darts vom Tastenfeld nicht.

## Spieler und Statistik

Leg für jeden Spieler ein Profil an; jedes Spiel eines Profils zählt für seine Statistik. Die Seite **Spieler** zeigt je Spieler und Zeitraum: Durchschnitt und First-9-Durchschnitt, Checkout-Quote und höchstes Finish, bestes Leg, Cricket-Treffer pro Runde, Trefferquote bei Around the Clock, wo die Darts gelandet sind, sowie Streuung und Versatz aus dem Präzisionstraining. Jeder Spieler kann sich eine Farbe aussuchen.

**Exportieren** speichert alle Darts als CSV oder alle Spiele mit den Kennzahlen als JSON, für eine Tabellenkalkulation oder eigene Auswertungen. Die Datei landet am PC im Download-Ordner, unter Android im Ordner der App, im Browser als Download.

## Ton und Score-Ansage

Die Score-Ansage sagt die Punkte jeder Aufnahme an, wie ein Caller im Turnier: „One hundred and eighty!“, „No score“ bei einem Bust, „Game shot, and the first leg!“. Sie ist an, wenn das Gerät sprechen kann.

Dazu kommen wenige kurze Effekte: ein leiser Aufprall für jeden Dart, zwei fallende Töne bei einem Bust, ein kurzer Akkord beim Game Shot und ein doppeltes Ticken, wenn die Kameras dich bitten, einen Dart zu bestätigen. Bei eingeschalteter Ansage spricht sie das Ende der Aufnahme und die 180, ohne zusätzlichen Ton. Auf dem Handy vibriert jeder Dart, den du eingibst.

Unter **Einstellungen → Ton & Ansager** schaltest du Effekte, Ansage und Vibration ein oder aus und stellst ihre Lautstärke ein; **Probe hören** spielt eine Beispiel-Aufnahme.

Unter Linux nutzt die Ansage speech-dispatcher, das manche Distributionen nicht von sich aus installieren:

```sh
sudo apt install speech-dispatcher        # Debian, Ubuntu
sudo dnf install speech-dispatcher        # Fedora
sudo pacman -S speech-dispatcher espeak-ng   # Arch
```

Meldet die App, dass das Gerät keine Sprachausgabe hat, fehlt speech-dispatcher. Unter Android, Windows und im Browser spricht die Stimme des Systems.

## Handy oder Tablet als zweite Anzeige

Ein Handy oder Tablet kann das laufende Spiel der Kamera-Engine zeigen, zum Beispiel neben dem Board, während der PC es auf dem Fernseher zeigt.

1. Am PC mit der Engine: **Einstellungen → Verbindung**, **Im Netzwerk freigeben** einschalten. Tu das nur in einem Netz, dem du vertraust. **QR-Code** zeigt einen Code mit der Adresse zum Scannen.
2. Am Handy: im Verbindungsbildschirm der App **Im Netzwerk** öffnen. Scanne den QR-Code, wähle die Engine aus der Liste oder tipp ihre Adresse ein.
3. Fragt die Engine nach einer PIN, gib die PIN ein, die ihr PC zeigt. Das ist nur einmal nötig.

Das Handy zeigt dann das laufende Spiel mit. Darts werden auf dem Gerät eingegeben und korrigiert, das das Spiel führt. Gast-WLAN und Netze, die Geräte voneinander trennen, verhindern die Suche; verbinde beide Geräte mit demselben Heimnetz.

## Wenn etwas nicht klappt

| Problem | Was hilft |
| ------- | --------- |
| Das AppImage startet nicht | Mach es ausführbar (siehe [Linux](#linux)). Meldet es FUSE, starte es mit `--appimage-extract-and-run`. |
| „Das Engine-Programm wurde nicht gefunden“ | Nur das Linux-AppImage enthält die Engine. Unter Windows und Android verbindest du dich mit einer Engine im Netzwerk oder spielst von Hand. |
| „Keine Kamera ließ sich starten“ | Prüfe, ob die Kameras angesteckt sind und kein anderes Programm sie nutzt (Videoanruf, OBS). Unter Linux muss dein Benutzer Kameras nutzen dürfen, meist über die Gruppe `video`. |
| „Der Port der Engine ist belegt“ | Es läuft schon eine Engine, etwa von einem früheren Start. Beende sie oder starte den PC neu. |
| Keine Engine im Netzwerk gefunden | Beide Geräte müssen im selben Heimnetz sein, nicht im Gastnetz. Tipp die Adresse ein, die der PC der Engine zeigt. |
| Die Browser-Version verbindet sich nicht | Lade sie über `http://`, nicht `https://`, und tipp die Adresse der Engine ein; Browser können das Netz nicht durchsuchen. |
| Darts landen im falschen Feld | **Einstellungen → Kameras & Erkennung → Erweitert → Einrichtungsdiagnose** prüft die Einrichtung Schritt für Schritt; die [Einrichtungsdiagnose](setup-diagnosis.md) erklärt jeden Befund (auf Englisch). Korrigiere falsche Darts im Spiel; das hilft den Messungen. |
| Keine Ansage zu hören | Installiere unter Linux speech-dispatcher (siehe [Ton und Score-Ansage](#ton-und-score-ansage)) und prüfe die Lautstärke der Ansage. |

Kommst du nicht weiter? Eröffne ein [Issue](https://github.com/xXCrusaderXx/DartPilot/issues) und nenn die Version aus **Einstellungen → Über DartPilot**, dein Gerät und was du gemacht hast.
