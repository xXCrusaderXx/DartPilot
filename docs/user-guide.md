# DartPilot player guide

DartPilot keeps the score of steel-tip darts. You can enter every dart by hand, or let three cameras on the board detect the darts for you. This guide is for players: how to install the app, start a game, and use what it offers.

Deutsch: [Anleitung für Spieler](user-guide.de.md).

- [Install](#install)
- [First start](#first-start)
- [Entering darts](#entering-darts)
- [Games](#games)
- [Training](#training)
- [Players and statistics](#players-and-statistics)
- [Sound and score caller](#sound-and-score-caller)
- [A phone or tablet as a second display](#a-phone-or-tablet-as-a-second-display)
- [Troubleshooting](#troubleshooting)

## Install

Download the file for your device from the [latest release](https://github.com/xXCrusaderXx/DartPilot/releases/latest). `SHA256SUMS` next to the files lets you check that a download is complete (`sha256sum -c SHA256SUMS --ignore-missing`).

| Device | File | What it can do |
| ------ | ---- | -------------- |
| Linux PC | `DartPilot-<version>-x86_64.AppImage` | Everything, including the camera engine |
| Android phone or tablet | `DartPilot-<version>.apk` | Enter darts by hand, or show the game of a camera engine in your network |
| Windows PC | `DartPilot-<version>-windows-x64.zip` | Enter darts by hand, or connect to an engine on a Linux PC in your network |
| Web browser | `DartPilot-<version>-web.zip` | Enter darts by hand, or show the game of an engine in your network |

### Linux

1. Make the file executable and start it: right-click it, allow it to run as a program in its properties, and double-click. In a terminal: `chmod +x DartPilot-*.AppImage` and `./DartPilot-*.AppImage`.
2. To get DartPilot into your application menu, use a tool such as Gear Lever or AppImageLauncher, or move the file to `~/Applications`.

The AppImage runs on Ubuntu 22.04, Debian 12, Fedora 38 and newer, and on other distributions of that age. It needs a desktop with GTK 3, which every common desktop has. For the score caller, install speech-dispatcher (see [Sound and score caller](#sound-and-score-caller)).

### Android

1. Open the APK on the phone. Android asks you to allow installing apps from this source (your browser or file manager); allow it once.
2. When updating, install the new APK over the old one. Your games and players stay.

The phone does not run cameras itself. It is a scoreboard you type into, or a second display for a game on a camera engine.

### Windows

Unzip the folder anywhere, for example into `Documents`, and start `dartpilot-app.exe`. Windows may warn that the app is from an unknown publisher, because it is not signed: choose **More info → Run anyway**. The camera engine for Windows comes in a later release; until then, enter darts by hand or connect to an engine on a Linux PC.

### Web

Unzip the folder onto any web server, or serve it on your own PC, for example with `python3 -m http.server 8080` inside the folder, and open that address in the browser. Serve it over `http://` if it should connect to an engine: browsers block a page loaded over `https://` from talking to the engine. Games and players stay in that browser.

## First start

The first screen asks how to play.

- **Play without an engine (enter darts by hand):** no cameras needed. Every game and training works; you tap the board or the keypad for each dart.
- **On this device** (Linux): the app starts the camera engine itself. Plug in the three cameras first. The first time, set them up under **Settings → Setup**: assign the cameras, calibrate from the board, and let the setup diagnosis check the result. [Hardware](hardware.md) describes the board, cameras and mounting; [calibration](calibration.md) explains what happens in the background.
- **In the network:** the engine runs on another PC. The app searches your home network for it; if it finds nothing, type the address shown on that PC, for example `ws://192.168.1.20:8484`. The first time, enter the PIN the engine's device shows.

You can change this later under **Settings → Connection**.

## Entering darts

With cameras, the darts appear by themselves about half a second after they land. Pulling the darts out of the board ends the visit and passes the turn on.

By hand, use one of two inputs, which you can switch at any time:

- **Board:** tap where the dart landed. The app also keeps the exact spot, which the precision training and the hit statistics use.
- **Keypad:** choose Single, Double or Triple, then the number; **Miss** for a dart outside the scoring area.

**Undo** takes back the last dart. To correct a dart the cameras got wrong, tap it in the list of the visit and tap the board where it really is. A correction also helps DartPilot measure how well its detection works.

If darts are still in the board when a game starts, the app warns you; take them out first.

## Games

Start a game from the home screen, pick the players in the order they throw (profiles or bots), choose the options, and press **Start game**. A game you leave is kept and can be continued with **Play on**.

- **X01:** 501 or 301 down to exactly zero. The last dart must be a double (double out); double in and the number of legs are options. The app shows a checkout when one is possible.
- **Cricket:** close 15 to 20 and the bull with three marks each, and score on numbers your opponents have not closed. In **cut-throat**, points go to the opponents instead, and the lowest score wins.
- **Around the Clock:** hit 1 to 20 in order.
- **Shanghai:** seven rounds, each at its number (1 in the first round, 2 in the second, …). Single, double and triple of the number in one visit wins at once.
- **Bob's 27:** doubles practice. Start with 27 points and throw at D1, D2 up to the bull; a hit adds the double, a visit without a hit costs its value. Below zero you are out.
- **Halve-It:** start with 40 points; every round has a target, and a visit without a hit on it halves your score.
- **Killer:** every player gets a number. Hit your own double three times to become a killer, then take your opponents' lives by hitting their doubles. The last player with lives wins.

Bots throw like players from beginner (level 1) to pro (level 10), so you can play alone against an opponent.

## Training

- **Free throwing:** every dart is shown and counted, without rules.
- **Precision training** measures each dart in millimetres against what you aimed at:
  - **Grouping:** several darts at one target; the score is how tightly they group.
  - **Doubles practice:** one visit at each double; your doubles are ranked by hit rate and spread.
  - **Checkout trainer:** random finishes or the 121 ladder; every miss is measured against the field you had to aim at.

Precision needs the exact spot of each dart: darts from the cameras or tapped on the board count, keypad darts do not.

## Players and statistics

Create a profile for every player; each game a profile plays counts for its statistics. The **Players** page shows per player and period: averages and first-9 average, checkout rate and highest finish, best leg, Cricket marks per round, Around the Clock hit rate, where the darts landed, and the spread and offset from the precision training. Each player can choose a colour.

**Export** saves all darts as CSV, or all games with the figures as JSON, for a spreadsheet or your own analysis. The file goes to the Downloads folder on a PC, to the app's folder on Android, or is downloaded by the browser.

## Sound and score caller

The score caller announces the score of each visit, like a caller at a tournament: "One hundred and eighty!", "No score" for a bust, "Game shot, and the first leg!". It is on where the device can speak.

A few short effects go with it: a soft thud for each dart, two falling notes for a bust, a short chord for a game shot, and a double tick when the cameras ask you to confirm a dart. With the caller on, it speaks the end of a visit and the 180 without an extra sound. On a phone, each dart you enter vibrates.

Under **Settings → Sound & caller** you switch effects, caller and vibration on or off and set their volume; **Play a sample** plays a sample visit.

On Linux the caller uses speech-dispatcher, which some distributions do not install by default:

```sh
sudo apt install speech-dispatcher        # Debian, Ubuntu
sudo dnf install speech-dispatcher        # Fedora
sudo pacman -S speech-dispatcher espeak-ng   # Arch
```

If the app says the device has no speech output, speech-dispatcher is missing. On Android, Windows and in the browser the system's own voice is used.

## A phone or tablet as a second display

A phone or tablet can show the running game of the camera engine, for example next to the board, while the PC shows it on the TV.

1. On the PC with the engine: **Settings → Connection**, switch on **Share in the network**. Only do this in a network you trust. **QR code** shows a code with its address for the phone to scan.
2. On the phone: in the app's connection screen, open **In the network**. Scan the QR code, pick the engine from the list, or type its address.
3. If the engine asks for a PIN, enter the PIN its PC shows. This is needed only once.

The phone then shows the running game as it goes on. Darts are entered and corrected on the device that leads the game. Guest Wi-Fi and networks that keep devices apart block the search; connect both devices to the same home network.

## Troubleshooting

| Problem | What to do |
| ------- | ---------- |
| The AppImage does not start | Make it executable (see [Linux](#linux)). If it reports FUSE, start it with `--appimage-extract-and-run`. |
| "The engine program was not found" | Only the Linux AppImage includes the engine. On Windows and Android, connect to an engine in the network or play by hand. |
| "No camera could be started" | Check that the cameras are plugged in and not used by another program (a video call, OBS). On Linux your user must be allowed to use cameras, usually through the `video` group. |
| "The engine's port is in use" | Another engine is already running, for example from an earlier start. Close it or restart the PC. |
| No engine found in the network | Both devices must be in the same home network, not a guest network. Type the address shown on the engine's PC. |
| The browser version cannot connect | Load it over `http://`, not `https://`, and type the engine's address; browsers cannot search the network. |
| Darts are detected in the wrong field | **Settings → Setup diagnosis** checks the setup step by step; [setup diagnosis](setup-diagnosis.md) explains each finding. Correct wrong darts in the game; it helps the measurements. |
| No voice | Install speech-dispatcher on Linux (see [Sound and score caller](#sound-and-score-caller)) and check the caller volume. |

Still stuck? Open an [issue](https://github.com/xXCrusaderXx/DartPilot/issues) and give the version from **Settings → About DartPilot**, your device, and what you did.
