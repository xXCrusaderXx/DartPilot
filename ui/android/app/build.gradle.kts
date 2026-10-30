import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// The release key: from android/key.properties (storeFile, storePassword, keyAlias, keyPassword) on a developer's
// machine, or from the environment in the release workflow. Without one, release builds are signed with the debug key,
// which installs fine but cannot update an APK signed with the release key.
val releaseKey = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) FileInputStream(file).use { load(it) }
    mapOf(
        "storeFile" to "DARTPILOT_KEYSTORE",
        "storePassword" to "DARTPILOT_KEYSTORE_PASSWORD",
        "keyAlias" to "DARTPILOT_KEY_ALIAS",
        "keyPassword" to "DARTPILOT_KEY_PASSWORD",
    ).forEach { (key, variable) -> System.getenv(variable)?.takeIf { it.isNotEmpty() }?.let { setProperty(key, it) } }
}
val hasReleaseKey = listOf("storeFile", "storePassword", "keyAlias", "keyPassword").all {
    !releaseKey.getProperty(it).isNullOrEmpty()
}

android {
    namespace = "io.github.xxcrusaderxx.dartpilot"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "io.github.xxcrusaderxx.dartpilot"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = file(releaseKey.getProperty("storeFile"))
                storePassword = releaseKey.getProperty("storePassword")
                keyAlias = releaseKey.getProperty("keyAlias")
                keyPassword = releaseKey.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else {
                logger.warn("WARNING: no release key (android/key.properties or DARTPILOT_KEYSTORE); the release build is signed with the debug key.")
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
