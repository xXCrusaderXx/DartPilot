# Run with: cmake -B build -DDARTPILOT_BUILD_TESTS=ON && cmake --build build && ctest --test-dir build --output-on-failure
# The tests need no cameras; recorded inputs will come from small fixtures in this directory.

include(FetchContent)
FetchContent_Declare(
  googletest
  URL https://github.com/google/googletest/releases/download/v1.17.0/googletest-1.17.0.tar.gz
  URL_HASH SHA256=65fab701d9829d38cb77c14acdc431d2108bfdbf8979e40eb8ae567edf10b27c
  DOWNLOAD_EXTRACT_TIMESTAMP TRUE
)
set(INSTALL_GTEST OFF CACHE BOOL "" FORCE)
FetchContent_MakeAvailable(googletest)
include(GoogleTest)

add_executable(SmokeTest SmokeTest.cpp)
target_link_libraries(SmokeTest PRIVATE dartpilot::replay dartpilot_version GTest::gtest_main)
gtest_discover_tests(SmokeTest)

add_executable(FocusTest FocusTest.cpp)
target_link_libraries(FocusTest PRIVATE dartpilot::capture GTest::gtest_main)
gtest_discover_tests(FocusTest)

add_executable(V4l2DeviceTest V4l2DeviceTest.cpp)
target_link_libraries(V4l2DeviceTest PRIVATE dartpilot::capture GTest::gtest_main)
gtest_discover_tests(V4l2DeviceTest)

add_executable(IntrinsicsTest IntrinsicsTest.cpp)
target_link_libraries(IntrinsicsTest PRIVATE dartpilot::geometry opencv_imgcodecs GTest::gtest_main)
target_compile_definitions(IntrinsicsTest PRIVATE DARTPILOT_SOURCE_DIR="${PROJECT_SOURCE_DIR}")
gtest_discover_tests(IntrinsicsTest)

add_executable(CaptureTest CaptureTest.cpp)
target_link_libraries(CaptureTest PRIVATE dartpilot::capture GTest::gtest_main)
gtest_discover_tests(CaptureTest)

add_executable(ScoringTest ScoringTest.cpp)
target_link_libraries(ScoringTest PRIVATE dartpilot::scoring GTest::gtest_main)
gtest_discover_tests(ScoringTest)

add_executable(SessionTest SessionTest.cpp)
target_link_libraries(SessionTest PRIVATE dartpilot::session GTest::gtest_main)
gtest_discover_tests(SessionTest)

add_executable(BoardDetectionTest BoardDetectionTest.cpp)
target_link_libraries(BoardDetectionTest PRIVATE dartpilot::geometry opencv_imgcodecs GTest::gtest_main)
gtest_discover_tests(BoardDetectionTest)

add_executable(BoardPlaneTest BoardPlaneTest.cpp)
target_link_libraries(BoardPlaneTest PRIVATE dartpilot::geometry opencv_imgcodecs GTest::gtest_main)
gtest_discover_tests(BoardPlaneTest)

add_executable(BoardRefinementTest BoardRefinementTest.cpp)
target_link_libraries(BoardRefinementTest PRIVATE dartpilot::geometry GTest::gtest_main)
gtest_discover_tests(BoardRefinementTest)

add_executable(CalibrationStoreTest CalibrationStoreTest.cpp)
target_link_libraries(CalibrationStoreTest PRIVATE dartpilot::geometry opencv_imgcodecs GTest::gtest_main)
gtest_discover_tests(CalibrationStoreTest)

add_executable(ReplayTest ReplayTest.cpp)
target_link_libraries(ReplayTest PRIVATE dartpilot::replay opencv_imgcodecs GTest::gtest_main)
target_compile_definitions(ReplayTest PRIVATE DARTPILOT_SOURCE_DIR="${PROJECT_SOURCE_DIR}")
gtest_discover_tests(ReplayTest)

add_executable(ApiTest ApiTest.cpp)
target_link_libraries(ApiTest PRIVATE dartpilot::api GTest::gtest_main)
gtest_discover_tests(ApiTest)

add_executable(DartLocationTest DartLocationTest.cpp)
target_link_libraries(DartLocationTest PRIVATE dartpilot::fusion dartpilot::geometry GTest::gtest_main)
gtest_discover_tests(DartLocationTest)

add_executable(BoardStateTest BoardStateTest.cpp)
target_link_libraries(BoardStateTest PRIVATE dartpilot::geometry opencv_imgcodecs GTest::gtest_main)
gtest_discover_tests(BoardStateTest)

add_executable(DiagnosisTest DiagnosisTest.cpp)
target_link_libraries(DiagnosisTest PRIVATE dartpilot::replay opencv_imgcodecs GTest::gtest_main)
gtest_discover_tests(DiagnosisTest)
