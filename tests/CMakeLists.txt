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
