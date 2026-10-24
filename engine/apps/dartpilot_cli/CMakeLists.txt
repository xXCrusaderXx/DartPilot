add_executable(dartpilot main.cpp capture_check_command.cpp focus_command.cpp record_command.cpp replay_command.cpp)
target_link_libraries(dartpilot PRIVATE dartpilot::replay dartpilot::session dartpilot_version opencv_highgui opencv_imgcodecs)
