# Native side of the Android spike (#104): libusb and libuvc on the file descriptors that the Android USB host API
# grants, streaming the cameras and measuring them. Built by the spike app's Gradle (externalNativeBuild) with the NDK;
# not part of the desktop build.
cmake_minimum_required(VERSION 3.22)
project(dartpilot_android_spike C CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include(FetchContent)
# libusb (LGPL-2.1-or-later) and libuvc (BSD-3-Clause), both compatible with GPL-3.0-or-later
FetchContent_Declare(libusb GIT_REPOSITORY https://github.com/libusb/libusb.git GIT_TAG v1.0.27)
FetchContent_Declare(libuvc GIT_REPOSITORY https://github.com/libuvc/libuvc.git GIT_TAG d07de4fa23905ee8cac06f5d24b2a03d42a3b363)
FetchContent_GetProperties(libusb)
if(NOT libusb_POPULATED)
  FetchContent_Populate(libusb)
endif()
FetchContent_GetProperties(libuvc)
if(NOT libuvc_POPULATED)
  FetchContent_Populate(libuvc)
endif()

# libusb with its Android configuration, as its own android/jni/libusb.mk builds it
add_library(usb STATIC
  ${libusb_SOURCE_DIR}/libusb/core.c
  ${libusb_SOURCE_DIR}/libusb/descriptor.c
  ${libusb_SOURCE_DIR}/libusb/hotplug.c
  ${libusb_SOURCE_DIR}/libusb/io.c
  ${libusb_SOURCE_DIR}/libusb/sync.c
  ${libusb_SOURCE_DIR}/libusb/strerror.c
  ${libusb_SOURCE_DIR}/libusb/os/linux_usbfs.c
  ${libusb_SOURCE_DIR}/libusb/os/events_posix.c
  ${libusb_SOURCE_DIR}/libusb/os/threads_posix.c
  ${libusb_SOURCE_DIR}/libusb/os/linux_netlink.c)
target_include_directories(usb PUBLIC ${libusb_SOURCE_DIR}/libusb PRIVATE ${libusb_SOURCE_DIR}/android ${libusb_SOURCE_DIR}/libusb/os)
target_link_libraries(usb PUBLIC log)

# libuvc without JPEG decoding
set(libuvc_VERSION_MAJOR 0)
set(libuvc_VERSION_MINOR 0)
set(libuvc_VERSION_PATCH 7)
set(libuvc_VERSION 0.0.7)
configure_file(${libuvc_SOURCE_DIR}/include/libuvc/libuvc_config.h.in ${CMAKE_CURRENT_BINARY_DIR}/include/libuvc/libuvc_config.h)
add_library(uvc STATIC
  ${libuvc_SOURCE_DIR}/src/ctrl.c
  ${libuvc_SOURCE_DIR}/src/ctrl-gen.c
  ${libuvc_SOURCE_DIR}/src/device.c
  ${libuvc_SOURCE_DIR}/src/diag.c
  ${libuvc_SOURCE_DIR}/src/frame.c
  ${libuvc_SOURCE_DIR}/src/init.c
  ${libuvc_SOURCE_DIR}/src/misc.c
  ${libuvc_SOURCE_DIR}/src/stream.c)
target_include_directories(uvc PUBLIC ${libuvc_SOURCE_DIR}/include ${CMAKE_CURRENT_BINARY_DIR}/include)
target_link_libraries(uvc PUBLIC usb)

add_library(dartpilot_spike SHARED spike.cpp jni.cpp)
target_link_libraries(dartpilot_spike PRIVATE uvc log)
