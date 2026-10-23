# Pipeline order: each module may only depend on the ones before it. scoring depends on none.
add_subdirectory(scoring)
add_subdirectory(capture)
add_subdirectory(event_detection)
add_subdirectory(tip_candidates)
add_subdirectory(geometry)
add_subdirectory(fusion)
add_subdirectory(replay)

add_subdirectory(apps/dartpilot_cli)
add_subdirectory(apps/dartpilot_setup)
