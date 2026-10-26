# ADR 0012: Remote play – identity, pairing and transport

- **Status:** proposed
- **Date:** 2026-10-26
- **Issues:** #124

## Context

Players want to add friends and play together over the internet without accounts and without a server run by the project (#124). Each player has their own board, cameras and engine. The engine API stays on the local network and is never reachable from the internet (ADR 0007, ADR 0008). Game rules live in the app, and one app leads a game while others replay its record (ADR 0010).

#124 sets the security requirements: every message end-to-end encrypted and signed; the app makes only outgoing connections, so no port is opened; short codes never serve as keys; camera images only with explicit per-game consent. This ADR decides what #124 leaves open: the transport, what a player's identity is, how friends pair, and what is shared during a game.

## Decision

### Transport: Nostr relays

Apps exchange small signed and encrypted messages through **Nostr relays**: public servers that store and forward events, run by many independent operators.

- Every message to a friend is encrypted with **NIP-44 (version 2)** and wrapped with **NIP-59** (gift wrap), so a relay sees neither the content nor who talks to whom. NIP-04 is never used.
- The app keeps a list of relays, with a few well-known public relays as the default; the player can change it. A message goes to two or three relays, so one relay being down does not matter.
- Only outgoing WebSocket connections, as #124 requires. No server of the project and no open port.
- Presence ("online", "in a lobby") is a short-lived event with an expiry (NIP-40). An app that goes quiet counts as offline after a few minutes.

### Identity: one Nostr key pair per player

- Each app creates a **secp256k1 key pair** (BIP-340 Schnorr signatures) on first start. The public key is the player ID, shown in its short form (`npub…`) and as a few words for reading out.
  - #124 suggested Ed25519 or X25519. Nostr signs with secp256k1, though, and a second key next to the transport key would double what has to be stored, backed up and verified.
- The private key stays in the platform's secure storage (`flutter_secure_storage`: Android Keystore, Windows DPAPI, Linux Secret Service).
- **Backup** as 24 recovery words (BIP-39, with the key derived as in **NIP-06**) and as a QR code. Without it, a lost device loses the identity and the friend list; the app says so when the player adds the first friend.
- Name and avatar are local data that the app sends to friends, not an account.

### Pairing

1. **QR code and token** first: the token holds the public key, the name and relay hints (NIP-19 `nprofile`). The receiving app sends a friend request through the relays, and the other player accepts it.
2. **Verification:** after every pairing both apps show the same four words, derived from both public keys. The players compare them, so a key swapped on the way is noticed.
3. **Short code** (`7-falcon-river-mint`) in a second step: a one-time PAKE (**CPace** over ristretto255, following the CFRG draft and its test vectors) run through the relays. A guess needs a live attempt, the code is used once and expires after five minutes. Until then, QR code and token cover phone to phone and messenger.

Friends can be removed or blocked; a blocked key is ignored.

### During a game: the record of ADR 0010, over the relays

- The host's app leads the game as in ADR 0010 and sends its game record to the players of the lobby after every change. The other apps replay it, so all displays agree without a second set of rules.
- Each player's engine detects that player's darts. Their app sends the darts (board points, as `add_throw` would carry them) to the host, which applies them to the game.
- **Throws only**, no live board view. Camera images over the internet need a direct connection and the per-game consent of #124; they are a later decision (WebRTC, with a TURN server that someone would have to run).
- A game record is a few kilobytes, sent a few times a minute, well within what public relays accept.

### Libraries

| Purpose | Library | Licence |
| ------- | ------- | ------- |
| ChaCha20, HMAC, HKDF for NIP-44 | `cryptography` (Dart) | Apache-2.0 |
| secp256k1, BIP-340 | `pointycastle` | MIT |
| Secure key storage | `flutter_secure_storage` | BSD-3-Clause |
| CPace on ristretto255 (step 2) | `sodium_libs` (libsodium) | MIT, libsodium ISC |

All are compatible with GPL-3.0-or-later. NIP-44 and BIP-340 are checked against their published test vectors before any message leaves the app.

## Alternatives considered

- **A server run by the project:** simplest to build, but #124 rules it out. Someone would have to pay for and moderate it, and it would see who plays with whom.
- **WebRTC for everything:** direct and fast, but it needs a signalling channel to find the other app (Nostr or a server anyway) and a TURN relay for players behind strict NATs, which again is a server. Kept for camera views later.
- **Matrix:** end-to-end encrypted and federated, but every player needs an account on a homeserver.
- **libp2p:** no server, but Dart support is thin, and NAT traversal again needs relays.
- **Ed25519 identity plus a separate Nostr key:** follows #124 literally, but means two keys to back up and a binding between them to verify, for no gain on this transport.

## Consequences

- New app parts: key creation and backup, a friend list, pairing by QR code and token, lobbies, and a relay client with NIP-44 and NIP-59. The engine does not change.
- Relays are run by others and may drop events or go away. The app copes by sending to several relays and treating friends as offline when nothing arrives.
- Public lobbies with strangers stay out: without a server there is nobody to stop cheating or abuse (#124).
- To be decided before building:
  - this ADR as a whole,
  - the default relays,
  - whether the short code (CPace) is part of the first version.
