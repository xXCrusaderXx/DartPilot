# Security policy

## Supported versions

Only the latest release gets security fixes.

## Reporting a vulnerability

Please **don't** open a public issue for security problems. Use [GitHub private vulnerability reporting](https://github.com/xXCrusaderXx/DartPilot/security/advisories/new) instead. It creates a private advisory that only the maintainers can see.

Relevant topics include:

- unsafe handling of replay files, datasets or configuration (path traversal, overwriting files outside the chosen folder, crashes on malformed input),
- the engine's network interface and, once it exists, online multiplayer (unauthenticated access, exposing camera images, remote code execution),
- camera images or recordings leaving the computer without the user's action,
- legal or takedown requests that contain confidential details (see [LEGAL.md](LEGAL.md)).

Please include the affected version or commit, the impact, and the steps to reproduce. A minimal proof of concept helps.

You will get a first answer within 7 days. Please give us a reasonable amount of time to release a fix before you disclose the issue publicly.

## The engine in the network

`dartpilot serve` listens only on localhost unless started with `--listen`. In the network, clients from other computers must pair with a 6-digit PIN shown by the engine and then present a 256-bit token. The engine stores only a SHA-256 of each token, and limits failed attempts to 5 per minute and address. The connection is plain `ws://` without encryption: anyone who can read the traffic of your network can read a token. Run it in a home network you trust, and use `unpair` (or delete `paired-clients.json` in the data directory) to remove a device. Details: [docs/engine-api.md](docs/engine-api.md#pairing).

## Everything else

Use a public [issue](https://github.com/xXCrusaderXx/DartPilot/issues) for ordinary bugs, feature requests, and documentation problems.
