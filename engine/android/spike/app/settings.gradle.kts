// Android shell of the #104 spike: three UVC cameras on a phone through libuvc (native side in ../CMakeLists.txt).
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.application") version "9.1.0" apply false
}

rootProject.name = "dartpilot-uvc-spike"
include(":spike")
