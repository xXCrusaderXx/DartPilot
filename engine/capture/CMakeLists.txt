find_package(Threads REQUIRED)
dartpilot_add_module(capture DEPS opencv_core opencv_imgproc opencv_videoio Threads::Threads)
