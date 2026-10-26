# ADR 0012: Remote play – peer to peer, the leading player hosts

- **Status:** accepted
- **Date:** 2026-10-26
- **Issues:** #124

## Context

Players want to play together over the internet without accounts and without a server run by the project (#124). Each player has their own board, cameras and engine. The engine API stays on the local network and is never reachable from the internet (ADR 0007, ADR 0008). Game rules live in the app, and one app leads a game while others replay its record (ADR 0010).

#124 sets the security requirements: every message end-to-end encrypted and authenticated; the app makes only outgoing connections, so no port is opened; short codes never serve as keys; camera images only with explicit per-game consent.

The maintainer decided that the first online mode is **peer to peer, with the leading player's app as the host**.

## Decision

### Peer to peer over WebRTC data channels

- The host is the app that starts the online game. Every guest connects **directly to the host** over a WebRTC data channel (`flutter_webrtc`: Android, Linux, Windows). Guests do not connect to each other.
- WebRTC traverses home routers with ICE: each app learns its public address from a **STUN server** and both try direct paths. No port is opened, and no game data passes any server. A public STUN server is the default, and the player can change it or switch it off for play in the same network.
- DTLS encrypts every data channel, and the invite and answer codes carry each side's certificate fingerprint, so a channel only comes up with the app that made the code.
- Strict NATs (some mobile networks, symmetric NAT on both sides) block a direct path. Without a TURN relay, which would be a server, such players cannot connect; the app says so plainly instead of trying forever.

### Invite and answer codes

1. The host creates an invite: the WebRTC offer (with its fingerprint and candidate addresses), the game's mode and the host's name, compressed into a code shown as a QR code and as text for a messenger.
2. The guest's app reads it and answers with its own code (the WebRTC answer), which the guest sends back the same way.
3. The host's app reads the answer and the data channel comes up.
4. Both apps then show the same four words, derived from both fingerprints. The players compare them by voice or in the messenger, so a code swapped on the way is noticed.

An invite is good for one guest and expires after ten minutes. A host invites several guests one after the other.

### During a game: the record of ADR 0010, over the data channels

- The host's app leads the game as in ADR 0010 and sends its game record to every guest after every change; the guests replay it, so all displays agree without a second set of rules.
- Each player's engine detects that player's darts. A guest's app sends its darts (board points, as `add_throw` carries them) and corrections to the host, which applies them for the player at the oche and sends the record on.
- **Throws only.** A live view of the other boards would send camera images and needs the per-game consent of #124; it is a later decision.
- If the host leaves, the game ends for everyone; guests keep the game in their statistics as it stood.

## Alternatives considered

- **Nostr relays** (the first draft of this ADR): no own server, friends list and presence for free, but every message passes relays run by others. Kept for later, for finding friends and inviting them without exchanging codes; the game itself stays peer to peer.
- **The host opens a port** (port forwarding or UPnP): one code instead of two, but it breaks the no-open-port requirement of #124 and needs router settings many players cannot change.
- **A server run by the project**, signalling or relay: simplest for players, but #124 rules it out.
- **libp2p:** also peer to peer, but Dart support is thin and NAT traversal again needs relays.

## Consequences

- New app parts: online lobby with invite and answer codes (QR and text), the WebRTC connection, and sending the game record and darts over it. The engine does not change.
- Two codes per guest are more effort than one link. Finding friends and inviting them without codes is the next step, built on this transport.
- No persistent identity or friend list yet: a game is between whoever exchanged codes. Keys, backup and friends (#124) follow with that step.
- Public lobbies with strangers stay out: without a server there is nobody to stop cheating or abuse.
