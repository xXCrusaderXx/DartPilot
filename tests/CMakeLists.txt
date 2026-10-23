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
