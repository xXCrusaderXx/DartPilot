# ADR 0010: One game on several displays

- **Status:** accepted
- **Date:** 2026-10-25
- **Issues:** #116

## Context

Players want to follow one game on several devices: a phone in the hand to confirm and correct darts, a tablet or a TV on the wall to watch. The engine detects darts and knows nothing about games; game rules live in the app (#37, ADR 0007). Several apps connected to one engine all receive the same `throw` messages, but each would keep its own game, and corrections, undo and manual darts would make them drift apart.

## Decision

**One app leads the game; the others watch it.**

- The leading app is the one on which the game was started. Only it applies throws, corrections, undo and bot darts.
- After every change it sends its game to the engine with `share_game`. The game is the app's own game record (`ui/lib/src/stats/game_record.dart`): mode, settings, players, bots and every dart as a board point in mm. Leaving the game sends `end_shared_game`.
- The engine relays it as `shared_game` to every client and keeps the latest one for clients that connect later. It treats the game as an opaque object and never reads it, so the engine stays free of game rules.
- A watching app replays the record with the same game classes as the leader. The displays therefore agree exactly, also after corrections, without a second set of rules or a diff protocol. Watching shows the game without input, and keeps and shares nothing.

## Alternatives considered

- **Every app keeps its own game from the engine's throws:** corrections, undo and darts entered by hand happen on one device only, so the games drift apart.
- **Game state in the engine:** the engine would need every game mode's rules, which belong to the app (#37) and change more often than detection.
- **Apps talking to each other directly:** a second network path next to the engine, with its own discovery and pairing; the engine connection already exists on every display.

## Consequences

- The engine API gains `share_game`, `end_shared_game` and `shared_game` (docs/engine-api.md).
- A shared game is as large as its darts, a few kilobytes per game; the engine refuses more than 256 KB.
- Only one game is shared at a time per engine. Several boards per engine are out of scope (ADR 0007).
- Taking over the lead (e.g. the phone's battery dies) is not part of this decision; a watching display can start its own game.
