# Developer GUI (docs/adr/0003-developer-gui.md). Built only when Qt 6 is found, so the engine and the tests build without Qt.
find_package(Qt6 6.5 QUIET COMPONENTS Quick QuickControls2)
if(NOT Qt6_FOUND)
  message(STATUS "Qt 6 not found: dartpilot_setup is not built")
  return()
endif()

qt_standard_project_setup(REQUIRES 6.5)

qt_add_executable(dartpilot_setup main.cpp)
qt_add_qml_module(dartpilot_setup
  URI DartPilotSetup
  VERSION 1.0
  QML_FILES Main.qml CameraPane.qml
  SOURCES camera_stream.hpp camera_stream.cpp camera_view.hpp camera_view.cpp camera_finder.hpp camera_finder.cpp
)
target_link_libraries(dartpilot_setup PRIVATE Qt6::Quick Qt6::QuickControls2 dartpilot::capture)
