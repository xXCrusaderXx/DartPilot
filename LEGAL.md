# Legal notes and contribution policy

This document explains the project's legal position and the rules that keep it in place. Contributors must follow it. If a contribution you want to make conflicts with it, **don't make the contribution**. Open an issue and ask first.

Hobbyists wrote this document, not lawyers. It is not legal advice; it describes how the project operates.

---

## No affiliation

DartPilot is an independent, non-commercial open-source project. It is **not affiliated with, endorsed by, or sponsored by any manufacturer of dartboards, darts, or dart scoring systems**, including the makers of commercial camera-based scoring products.

Product and company names (for example dartboard brands or other scoring systems) are trademarks of their owners. This project uses them only to describe compatibility or to compare results. It does not use their logos, and it does not claim to be compatible with a product unless that has been tested.

## Third-party code

DartPilot is its own implementation. Other open-source projects, such as [OpenDartboard](https://github.com/OpenDartboard/OpenDartboard), [ThrowVision](https://github.com/kashiwagiren/ThrowVision) and [InstaDarts](https://github.com/Instadarts/instadarts), serve as technical references (see section 9 of the [technical plan](docs/technical_plan.md#9-fork-an-existing-project-or-build-our-own)).

- Ideas and published methods may be used freely. Code may only be copied when its license is compatible with GPL-3.0-or-later.
- Copied or adapted code keeps its copyright and license notices. Name its origin, license and version in the PR and in the file.
- Code from commercial products, decompiled or reverse-engineered binaries, or code whose license is unclear is never accepted.
- Libraries the engine links against (OpenCV, GoogleTest, …) must have a GPL-compatible license.
- Release packages carry the licence texts of the native code they include: the AppImage those of OpenCV and its codecs, IXWebSocket, nlohmann/json and every library copied next to the engine, the Windows zip the notice for the Visual C++ runtime. They sit in `licenses/` next to the app's program, and the app lists them on its licence page beside the Dart packages. A new bundled library brings its licence the same way.
- Fonts are bundled only under the SIL Open Font License 1.1 or another GPL-compatible font licence, with the licence file next to the font files. The player app bundles Barlow Condensed (Jeremy Tribby) and Inter (Rasmus Andersson), both OFL 1.1, in `ui/assets/fonts/`; that folder's README names their source and version, and the app lists their licences on its licence page.

## Sounds

The app's sound effects in `ui/assets/sounds/` are made by the project: [`tools/dartpilot_tools/sounds.py`](tools/dartpilot_tools/sounds.py) synthesises them from sines and noise, so they are licensed like the rest of the code. Change a sound by changing its recipe and running the script, not by adding a sample from elsewhere. Spoken calls come from the device's own text-to-speech and are not part of the repository.

## Recordings and datasets

Camera recordings are the basis of the benchmark. They need care, because a camera pointed at a dartboard can also see a room and the people in it.

- **No people.** Frames must show the dartboard and its surroundings only. No faces, bodies, voices, names, or other personal data. Crop or mask a frame before sharing it if needed; don't share it if that is not possible.
- **Rights.** Only share recordings you made yourself or have permission to share. State the license; CC BY 4.0 is preferred.
- **Not in Git.** Recordings and datasets are never committed. `data/` is ignored; datasets are published separately and referenced by version.
- **Annotations** made in this project are licensed like the dataset they belong to.
- Datasets, images and models taken from elsewhere keep their license. Name the source and license, and use them only when the license allows it.

## Forbidden content

Don't add any of the following to this repository, and don't base a contribution on it:

1. **Recordings showing people**, or any other personal data.
2. **Code, models, or data under incompatible or unclear licenses**, or taken from commercial products.
3. **Confidential material**: anything obtained under an NDA or by breaking an agreement or access control.
4. **Logos, artwork, or other brand assets** of dartboard or scoring-system makers.
5. **Credentials, tokens, or API keys** of any kind.

## Privacy

The engine processes camera images locally. It has no telemetry, collects no personal data, and has no accounts. Recordings are only written to disk when the user starts a recording or replay session, and they stay on the computer unless the user shares them.

Online multiplayer is a later phase. Before it exists, this section will describe exactly which data leaves the computer.

## License and warranty

DartPilot's source code is licensed under the [GNU General Public License v3.0 or later](LICENSE). The software comes **without any warranty**, as stated in sections 15 and 16 of the GPL. Scores it reports may be wrong; you use it at your own risk.

## Concerns and takedown requests

If you believe this repository contains material that infringes your rights, or that violates the rules above:

- Open a public [issue](https://github.com/xXCrusaderXx/DartPilot/issues) for non-sensitive concerns.
- Use private vulnerability reporting as described in [SECURITY.md](SECURITY.md) if the report contains confidential or personal details.

Please name the affected files or commits and the basis of your claim. The maintainers will reply promptly and remove infringing material.
