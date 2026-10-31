# DartPilot – Setting up the cameras

This guide is for players who want DartPilot to detect their darts with cameras. Without cameras every game works too: you enter the darts by hand (see the [player guide](user-guide.md)).

Deutsch: [Kameras einrichten](setup-guide.de.md).

- [What you need](#what-you-need)
- [Mounting the cameras](#mounting-the-cameras)
- [Focus](#focus)
- [Connecting the cameras](#connecting-the-cameras)
- [Starting the camera detection](#starting-the-camera-detection)
- [Setting up in the app](#setting-up-in-the-app)
- [Checking the setup](#checking-the-setup)
- [When a camera or the board moves](#when-a-camera-or-the-board-moves)
- [When something does not work](#when-something-does-not-work)

## What you need

- A steel-dart board with its number ring.
- Three USB cameras (UVC) that deliver 1280×720 at 30 frames per second, for example as MJPG. The cameras DartPilot was developed with are listed in [hardware.md](hardware.md).
- A surround or ring that holds the three cameras around the board, and steady, even light: an LED ring around the board works best.
- A USB 2.0 hub, preferably with its own power supply, so the three cameras share one connection.
- A computer with Linux for the camera detection (the engine). Windows and Android follow in later releases. Phones and tablets can show the game over the network.

## Mounting the cameras

- Place the three cameras around the board, about **120° apart**.
- Each camera looks at the board from about **35–45° above the board plane** and sees the **whole board**, including the double ring, without cutting it at the image edge.
- The board should fill a good part of each image: with 720p cameras about 650 pixels across.
- Mount the cameras firmly. A camera that moves by a fraction of a millimetre shifts every dart it sees.
- Keep cables, the light and your hand's usual path out of the images as far as you can.
- Light the board evenly, without hard shadows or reflections. Play in the light you calibrate in.

## Focus

Set the focus once, with the camera in its final place, **before** calibrating. Many cheap cameras are focused by turning the lens in its thread; the lens is often fixed with a drop of glue that you have to loosen carefully. Every turn of the lens afterwards invalidates the calibration of that camera.

## Connecting the cameras

- Plug all three cameras into the same hub, and the hub into the computer.
- DartPilot tells the cameras apart by the **USB port** they are plugged into. Keep each camera in its port: after swapping ports, assign the cameras again.

## Starting the camera detection

The easiest way is the Linux app (AppImage): on the first start choose **With cameras on this computer**, or later in **Settings → Cameras & detection**. The app starts the engine itself.

From a terminal the engine starts with:

```sh
dartpilot serve --cameras --listen 0.0.0.0
```

`--listen 0.0.0.0` lets phones and tablets in your network connect; leave it out if only this computer shows the game.

## Setting up in the app

Open **Settings → Cameras & detection**. The setup steps are listed in order, each with its state; a step that is missing is marked, and Home shows a line that leads to the next open step.

Let the cameras run for about **10 minutes** before you calibrate, so they are warm and their image no longer drifts.

1. **Cameras** – check the live images: all three cameras show the whole board, sharp and well lit.
2. **Assign cameras** – each camera gets its place: camera 1, 2, 3. The live images show which is which; the arrows swap two cameras, and a name helps to find them again.
3. **Calibrate cameras** – with an **empty board** and the light you play in. No pattern to hold and no tape measure: the engine measures the board from every camera.
   - *Light*: the engine tries every colour temperature on all cameras and keeps the one in the middle of the range where it finds the board (about a minute).
   - *Board*: each camera finds the board.
   - *Refine*: from the boards of all cameras the engine computes the position and lens of each camera and the real size of your board.
4. **Calibration check** – confirms that the calibration fits the board.
5. **Save empty board** – the engine keeps an image of the empty board, so it can tell later whether darts are still in it.

Optional: **My darts** measures your darts as a reference. Detection works without it.

## Checking the setup

Under **Advanced**, the **setup diagnosis** runs a short test and lists what is wrong, each finding with a hint:

1. Start the cameras and wait about 30 seconds until their exposure has settled.
2. Keep the board empty for 5 seconds, your hand out of view.
3. Put one dart into the board, take your hand away and wait 5 seconds; pull it and wait with the empty board. Repeat at 8 to 10 places, including the bull and near the double ring.

Details on the checks are in [setup-diagnosis.md](setup-diagnosis.md).

Then play a few visits and watch the darts on the board view: a dart the engine is unsure about is shown with its candidates for you to confirm, and you correct a dart by tapping it in the list of recent darts and then the field where it really is.

## When a camera or the board moves

If a camera was bumped, the board was turned or taken off, or you turned a lens: calibrate that camera again and **refine all cameras** (step 3). The calibration check and the diagnosis tell you when this is needed.

## When something does not work

| What you see | What to do |
| - | - |
| A camera loses frames | Use another USB port or a hub with its own power supply. |
| The board is not found in a camera | Check that the camera sees the whole board and that the light is on; empty the board. |
| The board drifts away from the calibration | Let the cameras warm up about 10 minutes; if it keeps moving, tighten the camera's mount. |
| The brightness changes during play | Wait for the exposure after starting; use steady light such as an LED ring. |
| A camera cuts darts at the image edge | Tilt it so the whole board and a margin around it are in view. |
| The cameras disagree about where a dart is | Run the calibration check; if it is off, calibrate that camera again and refine all cameras. |
| In a game: "the cameras are not counting" | Detection is paused or a camera dropped out. Enter the darts by hand until the cameras are back. |

The technical background is in [calibration.md](calibration.md) and [hardware.md](hardware.md).
