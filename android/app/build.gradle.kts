import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val hifiLocalProperties = Properties().apply {
    rootProject.file("local.properties").inputStream().use { load(it) }
}
val hifiKeyProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val hifiFlutterSdk = hifiLocalProperties.getProperty("flutter.sdk")
val hifiDart = "$hifiFlutterSdk/bin/cache/dart-sdk/bin/" +
    if (System.getProperty("os.name").lowercase().contains("windows")) "dart.exe" else "dart"

android {
    namespace = "com.winheo.hide_player_flutter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.winheo.hide_player_flutter"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = maxOf(26, flutter.minSdkVersion)
        targetSdk = 36
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        externalNativeBuild {
            cmake {
                arguments += listOf("-DHIFI_DART_EXECUTABLE=$hifiDart", "-DCMAKE_BUILD_TYPE=Release", "-DANDROID_STL=c++_shared")
                targets += "hifi_audio_ffi"
            }
        }
    }

    externalNativeBuild {
        cmake {
            path = file("../../native/CMakeLists.txt")
            version = "3.22.1"
        }
    }

    signingConfigs {
        // Release signing comes from android/key.properties (git-ignored).
        if (hifiKeyProperties.isNotEmpty()) {
            create("release") {
                storeFile = file(hifiKeyProperties.getProperty("storeFile"))
                storePassword = hifiKeyProperties.getProperty("storePassword")
                keyAlias = hifiKeyProperties.getProperty("keyAlias")
                keyPassword = hifiKeyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Falls back to debug keys when key.properties is missing (e.g. CI / other machines).
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
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
