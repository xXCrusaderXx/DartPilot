# Pipeline order: each module may only depend on the ones before it. scoring depends on none.
add_subdirectory(scoring)
add_subdirectory(capture)
# Session recording and reading (docs/replay-format.md); needs only capture
add_subdirectory(session)
add_subdirectory(event_detection)
add_subdirectory(tip_candidates)
add_subdirectory(geometry)
add_subdirectory(fusion)
add_subdirectory(replay)
# Engine API for the player app and other clients (ADR 0007)
add_subdirectory(api)

add_subdirectory(apps/dartpilot_cli)
add_subdirectory(apps/dartpilot_setup)
