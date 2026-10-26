# Online play – concept

**Status: draft for discussion.** Nothing here is decided or built yet. Once the maintainer has agreed on the parts, they become ADRs (ADR 0012 covers the peer-to-peer part, still proposed) and milestones.

Players with their own board, cameras and engine play each other over the internet: with friends, in public matches with people they find online, and in tournaments anyone can organize and join. Three ways to connect sit under one game protocol:

| Way | What it is for | Who runs it |
| --- | --- | --- |
| **Peer to peer** | a game with friends, right now, no infrastructure | nobody: the host's app |
| **Server** | matchmaking, lobbies, tournaments, simple and reliable | anyone: open source and self-hostable |
| **Swarm** | public matches and tournaments without any central point | everyone who plays and switches it on |

## Principles

- **Opt-in.** Online play is off until the player switches it on. A local game never needs the internet.
- **No server the project must run.** A server is optional and anyone can run one. Peer to peer and the swarm work without one.
- **The engine API stays local** (ADR 0007, ADR 0008). Online traffic goes through a separate component, the app or a network service, never through the engine's port.
- **One game protocol, interchangeable transports.** Lobbies, games and tournaments mean the same thing over every way. A transport only carries signed messages.
- **Signed, encrypted, consented.** Every message is signed by its author. Messages between players are end-to-end encrypted. Camera images leave the house only with consent per game (#124).
- **Game rules stay in the app.** The leading app holds the game and others replay its record (ADR 0010), online as on several displays.

## The common protocol

All ways carry the same messages, each signed with the author's key, versioned, and small (a few kilobytes):

- **Presence:** "online", "in a lobby", "looking for a 501 match", with an expiry.
- **Lobby:** created by its host with mode, settings, visibility (invite only, friends, public) and seats; join, leave, ready, start.
- **Game:** the leading app's game record (ADR 0010) after every change; a guest's darts as board points; corrections; end of game with the result signed by both players.
- **Tournament:** created and signed by its organizer: format, registration, bracket, schedule, results. Each match of a tournament is an ordinary lobby.
- **Fair play:** a request to see a dart's camera views (#129) and the answer, given or refused; reports.

### Identity

- Each player has a key pair created on the device; the public key is the player ID, shown as a short ID and a few words.
- Backup as recovery words and QR code; restore on a new device.
- Name and avatar are chosen by the player and sent with presence; they are not unique and not an account.
- A **guest identity** per game is possible for peer to peer with friends, so nobody has to create a key to try it.

### Friends and online status

- **Adding a friend:** by QR code side by side, by a token sent in a messenger, or by a short code read out on the phone (a one-time PAKE, #124); later also from a match ("add as friend" after playing someone). After every pairing both apps show the same check words.
- Friendship is mutual and can be removed or blocked at any time; a blocked key is ignored on every way.
- **The friend list** shows per friend: name, avatar, online status, what they are doing ("in a 501 match", "in a tournament", "looking for a game"), and their last games against me with the score.
- **Online status** is a presence message that only friends can read (encrypted to them) and that expires after a few minutes, so a friend who closes the app shows as offline. The player chooses: visible to friends, to everyone, or invisible.
- **Invitations:** from the friend list straight into a lobby, with a notification on the friend's device; accept, decline, or "later".
- **Where the list lives:** on the player's devices, backed up with the identity (encrypted with the player's key), so a new device gets the friends back on restore. Hubs and the swarm only carry presence and invitations; they never hold the list.
- **Over each way:** peer to peer alone has no presence: friends are only reachable while an invite runs. Through a hub, presence and invitations are immediate. Through the swarm they travel by gossip and can take a few seconds.

## The three ways

### Peer to peer

As in ADR 0012: the leading player's app hosts, guests connect directly over WebRTC, after an invite code and an answer code (QR or text). A public STUN server finds the way through home routers. Without a relay, players behind strict NATs cannot connect. Good for: friends, no setup.

### Server ("DartPilot Hub")

A small open-source server that anyone can run on a Pi, a rented machine or at a club:

- presence, matchmaking ("find me a 501 opponent around my level"), public and private lobbies, tournaments,
- relays games for players who cannot connect directly, so strict NATs work,
- the entry point into the swarm for new nodes.

Several hubs can exist side by side; a player chooses one or several. Hubs do not need to talk to each other in the first version.

### Swarm

Every node that contributes keeps the network alive:

- **Who contributes:** mainly engine hosts (a PC or Pi next to the board), which run anyway, are on mains power and mostly online. Phones use the swarm but do not contribute by default.
- **What a node does:** stores part of the announcements in a distributed hash table (Kademlia, as in BitTorrent), so "open 501 matches" or "tournaments this week" can be looked up; passes new announcements on by gossip; relays connections for players who cannot connect directly; keeps copies of tournament state.
- **How it starts:** a new node needs one known node. Hubs and a few community nodes serve as entry points; after that the node finds others itself.
- **Implementation:** a separate network service next to the engine (`dartpilot-net`), built on `rust-libp2p` (MIT), which provides the hash table, gossip, NAT traversal and relaying. The app talks to it locally, like to the engine.
- **Limits a node respects:** bandwidth and storage caps, only on Wi-Fi or mains power, pause during own games if wanted.

## Controlling it in the app

### Settings → Online

- **Online play** on/off: the master switch, off by default. Off means no connection to anything.
- **My profile:** name, avatar, player ID, check words; **back up** (recovery words, QR) and **restore**.
- **Friends:** the friend list, add a friend (QR code, token, short code), pending requests, blocked players.
- **Visibility:** who sees me online (nobody, friends, everyone); accept invites from (friends, everyone); appear in public matchmaking yes/no.
- **Servers:**
  - the list of hubs with status and ping, one marked as default;
  - **add** by address or QR code;
  - **search**: hubs in the home network (mDNS, like engine discovery #109), hubs announced in the swarm, and a public list if one exists;
  - remove; use none.
- **Swarm mode:**
  - **off**,
  - **use**: find matches and tournaments through the swarm, contribute nothing,
  - **contribute**: also store and relay for others.
  - With *contribute*: upload limit (e.g. 1 Mbit/s), storage limit (e.g. 200 MB), only on Wi-Fi, only on mains power, pause during my games.
  - Status: connected nodes, data stored, traffic today, players relayed.
  - On a phone, *contribute* is only offered for the engine host the phone controls, so the phone's battery stays out of it.
- **Camera evidence:** when an opponent asks to see a dart's camera views: ask me each time, always allow, never.

### Home → Play online

- **Friends:** who is online and what they are doing; invite one straight into a lobby.
- **Invite someone new:** peer to peer with codes, or add them as a friend.
- **Quick match:** mode and settings, then matchmaking on the chosen ways (hub, swarm or both); shows waiting time and how many are looking.
- **Lobbies:** open public lobbies to join, and creating one (invite only, friends, public).
- **Tournaments:** browse (this week, my level, my friends'), register, my tournaments; create one as organizer (format, dates, seats, rules, co-organizers).
- A small indicator everywhere: online or offline, and through which way the current game runs.

## Fair play

Each player's engine reports its own player's darts, and nobody sees the other board. That is the biggest problem of every online dart system, whichever way connects:

- **Signed throws:** the engine signs each throw with its own key, so a dart cannot be changed between engine and opponent.
- **Evidence on request:** the opponent may ask for a dart's camera views (#129); the player decides (see settings). A refusal is visible.
- **Trust levels:** friends' games count as trusted; public matches show both players' calibration quality and evidence rate; tournaments can require evidence or a minimum trust.
- **Reputation and reports:** results signed by both players; disputes go to the tournament organizer, or for public matches into a reputation score.
- It cannot be made impossible to cheat. Rankings carry trust levels instead of pretending otherwise.

## Tournaments

- Formats: knockout, round robin, groups then knockout; best of legs or sets per round.
- The organizer signs the tournament, the bracket and each result. The swarm or the hub only carries and stores them. Co-organizers can continue if the organizer goes offline.
- Each match is a lobby. Its host is the higher seed or chosen by lot.
- A no-show after a set time loses the match.

## Milestones (proposal)

| Milestone | Content |
| --- | --- |
| **Online: protocol and identity** | the common protocol, keys with backup and restore, guest identity, *Settings → Online* with the master switch, profile and visibility |
| **Online: friends** | adding friends (QR code, token, short code), the friend list, online status and invitations over hubs and the swarm |
| **Online: peer to peer** | invite and answer codes, WebRTC, playing a game over it (ADR 0012) |
| **Online: server** | the DartPilot Hub (open source, self-hostable), server list and search in the app, matchmaking, public lobbies, relaying |
| **Online: tournaments** | tournament protocol, organizing and joining, first on hubs |
| **Online: swarm** | `dartpilot-net` with libp2p, hash table and gossip, relaying, swarm mode settings with limits, matches and tournaments in the swarm |
| **Online: fair play** | signed throws, evidence on request, trust levels and reputation, across all ways |

The order follows what each step needs. Peer to peer needs only the protocol and identity. The hub makes matchmaking and tournaments work simply. The swarm builds on both, with hubs as its entry points.

## Open questions

1. Hub federation: do hubs talk to each other, or only through the swarm?
2. Levels for matchmaking: from the app's statistics (3-dart average), self-declared, or from results?
3. Public lobbies and tournaments need moderation: who blocks abusers in the swarm? Per-player block lists, organizer powers, shared block lists?
4. Voice or chat in a match, or only darts?
5. A live view of the other board (camera images) as an option for trusted games?
6. Which game modes online: all, or X01 and Cricket first?
7. Do online games count in the statistics like local ones, and are they marked?
8. Phones as swarm contributors: never, or opt-in on Wi-Fi and mains power?
9. Who runs the first public hub and community entry nodes, if anyone?
