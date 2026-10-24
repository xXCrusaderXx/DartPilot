# Test fixtures

`session-v1/` is a minimal session in the format of [docs/replay-format.md](../../docs/replay-format.md), read by both `tests/ReplayTest.cpp` and `tools/tests/test_session.py`, so the C++ and Python readers are held to the same files. It contains text only: `frames.mjpg` holds short placeholder strings instead of JPEGs, so no recording is ever committed (see [LEGAL.md](../../LEGAL.md)). Its last frame of `usb-1.3` is truncated on purpose, and two frames share an exposure time to pin down the replay order.
