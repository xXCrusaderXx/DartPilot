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

## Everything else

Use a public [issue](https://github.com/xXCrusaderXx/DartPilot/issues) for ordinary bugs, feature requests, and documentation problems.
