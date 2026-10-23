cmake_minimum_required(VERSION 3.20)

# Release builds override it with -DDARTPILOT_VERSION=X.Y.Z[-suffix] (see .github/workflows/release.yml)
set(DARTPILOT_VERSION 0.1.0 CACHE STRING "DartPilot version, X.Y.Z with an optional -suffix")
string(REGEX MATCH "^[0-9]+\\.[0-9]+\\.[0-9]+" DARTPILOT_VERSION_NUMBER "${DARTPILOT_VERSION}")
if(NOT DARTPILOT_VERSION_NUMBER)
  message(FATAL_ERROR "DARTPILOT_VERSION '${DARTPILOT_VERSION}' is not X.Y.Z[-suffix]")
endif()

project(DartPilot VERSION ${DARTPILOT_VERSION_NUMBER} LANGUAGES CXX)

option(DARTPILOT_BUILD_TESTS "Build the tests (run with ctest)" OFF)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
endif()

# Without COMPONENTS every installed module is imported; the modules needed are checked below,
# because the geometry modules differ between OpenCV builds. CONFIG uses OpenCV's own package
# configuration, so a FindOpenCV.cmake of another project on CMAKE_MODULE_PATH cannot take over.
find_package(OpenCV REQUIRED CONFIG)
if(OpenCV_VERSION VERSION_LESS 4)
  message(FATAL_ERROR "OpenCV ${OpenCV_VERSION} found, DartPilot needs OpenCV 4 or newer")
endif()
# OpenCV 5 split calib3d into geometry (projection, triangulation) and calib (calibration)
if(TARGET opencv_calib3d)
  set(DARTPILOT_OPENCV_GEOMETRY opencv_calib3d)
else()
  set(DARTPILOT_OPENCV_GEOMETRY opencv_geometry opencv_calib)
endif()
foreach(target opencv_core opencv_imgproc opencv_imgcodecs opencv_videoio opencv_highgui ${DARTPILOT_OPENCV_GEOMETRY})
  if(NOT TARGET ${target})
    message(FATAL_ERROR "OpenCV ${OpenCV_VERSION} lacks the ${target} module. Found: ${OpenCV_LIBS}")
  endif()
endforeach()
# ChArUco detection (CharucoDetector) needs OpenCV 4.7; older versions build without it.
if(OpenCV_VERSION VERSION_GREATER_EQUAL 4.7 AND TARGET opencv_objdetect)
  set(DARTPILOT_HAVE_CHARUCO ON)
else()
  set(DARTPILOT_HAVE_CHARUCO OFF)
  message(STATUS "OpenCV ${OpenCV_VERSION}: ChArUco detection needs 4.7 or newer and is not built")
endif()

add_compile_options(-Wall -Wextra -Wpedantic)

# Version header shared by the app and the tests
configure_file(engine/version.hpp.in ${CMAKE_BINARY_DIR}/generated/dartpilot/version.hpp @ONLY)
add_library(dartpilot_version INTERFACE)
target_include_directories(dartpilot_version INTERFACE ${CMAKE_BINARY_DIR}/generated)

# One static library per pipeline stage: engine/<name>/{include/dartpilot/<name>,src}.
# DEPS lists the modules (without prefix) and other targets it links against.
function(dartpilot_add_module name)
  cmake_parse_arguments(MOD "" "" "DEPS" ${ARGN})
  file(GLOB_RECURSE sources CONFIGURE_DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/src/*.cpp)
  add_library(dartpilot_${name} STATIC ${sources})
  add_library(dartpilot::${name} ALIAS dartpilot_${name})
  target_include_directories(dartpilot_${name} PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)
  foreach(dep ${MOD_DEPS})
    if(TARGET dartpilot_${dep})
      target_link_libraries(dartpilot_${name} PUBLIC dartpilot::${dep})
    else()
      target_link_libraries(dartpilot_${name} PUBLIC ${dep})
    endif()
  endforeach()
endfunction()

add_subdirectory(engine)

if(DARTPILOT_BUILD_TESTS)
  enable_testing()
  add_subdirectory(tests)
endif()
