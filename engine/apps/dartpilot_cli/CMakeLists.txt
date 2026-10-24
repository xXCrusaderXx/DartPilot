add_executable(dartpilot main.cpp analyse_command.cpp capture_check_command.cpp focus_command.cpp record_command.cpp replay_command.cpp serve_command.cpp preview_sources.cpp board_watch.cpp live_diagnosis.cpp white_balance_command.cpp)
target_link_libraries(dartpilot PRIVATE dartpilot::replay dartpilot::session dartpilot::api dartpilot_version opencv_highgui opencv_imgcodecs)
