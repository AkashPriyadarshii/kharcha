import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.kharcha.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications requires core library desugaring.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.kharcha.app"
        // Android 12+ (design requirement)
        minSdk = 32
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Store native libs page-aligned (uncompressed). Some Android 12+ installers
    // reject APKs with compressed .so files ("package is invalid").
    packaging {
        jniLibs {
            useLegacyPackaging = false
        }
    }

    signingConfigs {
        // Play-Store-only. Keystore parked (android/key.properties.release) —
        // sideload MUST stay debug-signed or installs conflict on every device.
        create("release") {
            val props = Properties().apply {
                val f = rootProject.file("key.properties")
                if (f.exists()) f.inputStream().use { load(it) }
            }
            storeFile = if (props.containsKey("storeFile")) {
                file(props.getProperty("storeFile")) // app module dir → android/app/
            } else null
            storePassword = props.getProperty("storePassword") ?: ""
            keyAlias = props.getProperty("keyAlias") ?: ""
            keyPassword = props.getProperty("keyPassword") ?: ""
        }
    }

    buildTypes {
        release {
            // Falls back to debug signing if key.properties is missing
            // (CI, fresh clone) so `flutter run --release` still works.
            val hasKey = rootProject.file("key.properties").exists()
            signingConfig = if (hasKey) signingConfigs.getByName("release") else signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation(project(":parser-core"))
}

flutter {
    source = "../.."
}
