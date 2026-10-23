# Developer GUI (docs/adr/0003-developer-gui.md). Built only when Qt 6 is found, so the engine and the tests build without Qt.
find_package(Qt6 6.5 QUIET COMPONENTS Quick QuickControls2 Concurrent)
if(NOT Qt6_FOUND)
  message(STATUS "Qt 6 not found: dartpilot_setup is not built")
  return()
endif()

qt_standard_project_setup(REQUIRES 6.5)

qt_add_executable(dartpilot_setup main.cpp)
set_source_files_properties(Tokens.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
qt_add_qml_module(dartpilot_setup
  URI DartPilotSetup
  VERSION 1.0
  QML_FILES
    Main.qml Tokens.qml
    Card.qml Chip.qml NavButton.qml PageHeader.qml StepCard.qml
    CamerasPage.qml CameraPane.qml IntrinsicPage.qml ExtrinsicPage.qml
    CaptureGuide.qml GuideDialog.qml PatternWindow.qml
  SOURCES
    calibration_paths.hpp
    camera_finder.hpp camera_finder.cpp
    camera_stream.hpp camera_stream.cpp
    camera_view.hpp camera_view.cpp
    intrinsic_view.hpp intrinsic_view.cpp
    pattern_image_provider.hpp pattern_image_provider.cpp
    stream_view.hpp stream_view.cpp
)
target_link_libraries(dartpilot_setup PRIVATE Qt6::Quick Qt6::QuickControls2 Qt6::Concurrent dartpilot::capture dartpilot::geometry opencv_objdetect)
