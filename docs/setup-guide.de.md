# DartPilot – Kameras einrichten

Diese Anleitung ist für Spieler, die ihre Darts von Kameras erkennen lassen wollen. Ohne Kameras geht jedes Spiel auch: Du gibst die Darts von Hand ein (siehe die [Anleitung für Spieler](user-guide.de.md)).

English: [Setting up the cameras](setup-guide.md).

- [Was du brauchst](#was-du-brauchst)
- [Kameras anbringen](#kameras-anbringen)
- [Schärfe](#schärfe)
- [Kameras anschließen](#kameras-anschließen)
- [Kamera-Erkennung starten](#kamera-erkennung-starten)
- [Einrichten in der App](#einrichten-in-der-app)
- [Einrichtung prüfen](#einrichtung-prüfen)
- [Wenn sich eine Kamera oder die Scheibe bewegt](#wenn-sich-eine-kamera-oder-die-scheibe-bewegt)
- [Wenn etwas nicht klappt](#wenn-etwas-nicht-klappt)

## Was du brauchst

- Eine Steeldart-Scheibe mit Zahlenring.
- Drei USB-Kameras (UVC), die 1280×720 mit 30 Bildern pro Sekunde liefern, zum Beispiel als MJPG. Die Kameras, mit denen DartPilot entwickelt wurde, stehen in [hardware.md](hardware.md).
- Einen Ring oder ein Surround, das die drei Kameras um die Scheibe hält, und ruhiges, gleichmäßiges Licht: Ein LED-Ring um die Scheibe ist am besten.
- Einen USB-2.0-Hub, am besten mit eigenem Netzteil, damit sich die drei Kameras einen Anschluss teilen.
- Einen Rechner mit Linux für die Kamera-Erkennung (die Engine). Windows und Android folgen in späteren Versionen. Handys und Tablets können das Spiel über das Netzwerk anzeigen.

## Kameras anbringen

- Verteil die drei Kameras um die Scheibe, etwa **120° auseinander**.
- Jede Kamera schaut aus etwa **35–45° über der Scheibenebene** auf die Scheibe und sieht die **ganze Scheibe** samt Doppelring, ohne sie am Bildrand abzuschneiden.
- Die Scheibe sollte einen guten Teil jedes Bildes füllen: bei 720p-Kameras etwa 650 Pixel breit.
- Befestige die Kameras fest. Eine Kamera, die sich um Bruchteile eines Millimeters bewegt, verschiebt jeden Dart, den sie sieht.
- Halte Kabel, Lampe und den üblichen Weg deiner Hand so weit es geht aus den Bildern.
- Beleuchte die Scheibe gleichmäßig, ohne harte Schatten oder Spiegelungen. Spiel im selben Licht, in dem du kalibrierst.

## Schärfe

Stell die Schärfe einmal ein, mit der Kamera an ihrem endgültigen Platz, und zwar **vor** dem Kalibrieren. Viele günstige Kameras stellt man scharf, indem man die Linse im Gewinde dreht; oft ist sie mit einem Tropfen Kleber gesichert, den du vorsichtig lösen musst. Jede spätere Drehung an der Linse macht die Kalibrierung dieser Kamera ungültig.

## Kameras anschließen

- Steck alle drei Kameras in denselben Hub und den Hub in den Rechner.
- DartPilot unterscheidet die Kameras am **USB-Anschluss**, in dem sie stecken. Lass jede Kamera in ihrem Anschluss: Nach einem Tausch ordnest du die Kameras neu zu.

## Kamera-Erkennung starten

Am einfachsten geht es mit der Linux-App (AppImage): Wähl beim ersten Start **Mit Kameras an diesem Rechner**, oder später unter **Einstellungen → Kameras & Erkennung**. Die App startet die Engine dann selbst.

Im Terminal startet die Engine so:

```sh
dartpilot serve --cameras --listen 0.0.0.0
```

Mit `--listen 0.0.0.0` können sich Handys und Tablets in deinem Netzwerk verbinden; lass es weg, wenn nur dieser Rechner das Spiel zeigt.

## Einrichten in der App

Öffne **Einstellungen → Kameras & Erkennung**. Dort stehen die Schritte der Einrichtung der Reihe nach, jeder mit seinem Zustand; ein fehlender Schritt ist markiert, und auf der Startseite führt eine Zeile zum nächsten offenen Schritt.

Lass die Kameras vor dem Kalibrieren etwa **10 Minuten** laufen, damit sie warm sind und ihr Bild nicht mehr wandert.

1. **Kameras** – prüf die Livebilder: Alle drei Kameras zeigen die ganze Scheibe, scharf und gut beleuchtet.
2. **Kameras zuordnen** – jede Kamera bekommt ihren Platz: Kamera 1, 2, 3. Am Livebild erkennst du, welche welche ist; mit den Pfeilen tauschst du zwei Kameras, ein Name hilft beim Wiederfinden.
3. **Kameras kalibrieren** – mit **leerer Scheibe** und dem Licht, in dem du spielst. Ohne Muster zum Halten, ohne Maßband: Die Engine misst die Scheibe aus jeder Kamera ein.
   - *Licht*: Die Engine probiert auf allen Kameras jede Farbtemperatur und behält die in der Mitte des Bereichs, in dem sie die Scheibe findet (etwa eine Minute).
   - *Scheibe*: Jede Kamera findet die Scheibe.
   - *Verfeinern*: Aus den Scheiben aller Kameras berechnet die Engine Lage und Linse jeder Kamera und die wirkliche Größe deiner Scheibe.
4. **Kalibriercheck** – bestätigt, dass die Kalibrierung zur Scheibe passt.
5. **Leere Scheibe speichern** – die Engine merkt sich ein Bild der leeren Scheibe, damit sie später erkennt, ob noch Darts darin stecken.

Freiwillig: **Meine Darts** misst deine Darts als Referenz ein. Die Erkennung funktioniert auch ohne.

## Einrichtung prüfen

Unter **Erweitert** macht die **Einrichtungsdiagnose** einen kurzen Test und listet auf, was nicht stimmt, jeweils mit einem Hinweis:

1. Starte die Kameras und warte etwa 30 Sekunden, bis sich ihre Belichtung eingestellt hat.
2. Lass die Scheibe 5 Sekunden leer, die Hand aus dem Bild.
3. Steck einen Dart in die Scheibe, nimm die Hand weg und warte 5 Sekunden; zieh ihn und warte mit leerer Scheibe. Wiederhol das an 8 bis 10 Stellen, auch im Bull und nahe am Doppelring.

Was dabei geprüft wird, steht in [setup-diagnosis.md](setup-diagnosis.md).

Spiel danach ein paar Aufnahmen und achte auf die Darts in der Scheibenansicht: Ist sich die Engine bei einem Dart unsicher, zeigt sie dir die Möglichkeiten zum Bestätigen, und einen Dart korrigierst du, indem du ihn in der Liste der letzten Darts antippst und dann das Feld, wo er wirklich steckt.

## Wenn sich eine Kamera oder die Scheibe bewegt

Wurde eine Kamera angestoßen, die Scheibe gedreht oder abgenommen, oder hast du an einer Linse gedreht: Kalibrier diese Kamera neu und **verfeinere alle Kameras** (Schritt 3). Der Kalibriercheck und die Diagnose sagen dir, wann das nötig ist.

## Wenn etwas nicht klappt

| Was du siehst | Was du tun kannst |
| - | - |
| Eine Kamera verliert Bilder | Nimm einen anderen USB-Anschluss oder einen Hub mit eigenem Netzteil. |
| Eine Kamera findet die Scheibe nicht | Prüf, ob die Kamera die ganze Scheibe sieht und das Licht an ist; leere die Scheibe. |
| Die Scheibe wandert von der Kalibrierung weg | Lass die Kameras etwa 10 Minuten warm laufen; bewegt es sich weiter, zieh die Halterung der Kamera fest. |
| Die Helligkeit ändert sich beim Spielen | Warte nach dem Start auf die Belichtung; nimm ruhiges Licht wie einen LED-Ring. |
| Eine Kamera schneidet Darts am Bildrand ab | Neig sie so, dass die ganze Scheibe mit etwas Rand im Bild ist. |
| Die Kameras sind sich uneinig, wo ein Dart steckt | Mach den Kalibriercheck; liegt er daneben, kalibrier diese Kamera neu und verfeinere alle Kameras. |
| Im Spiel: „Kameras zählen gerade nicht“ | Die Erkennung ist pausiert oder eine Kamera ausgefallen. Gib die Darts von Hand ein, bis die Kameras wieder da sind. |

Die technischen Hintergründe stehen in [calibration.md](calibration.md) und [hardware.md](hardware.md).
