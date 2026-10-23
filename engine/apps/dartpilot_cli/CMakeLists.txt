add_executable(dartpilot main.cpp focus_command.cpp)
target_link_libraries(dartpilot PRIVATE dartpilot::replay dartpilot_version opencv_highgui opencv_imgcodecs)
