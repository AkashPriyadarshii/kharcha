import org.jetbrains.kotlin.gradle.tasks.KotlinCompile
import java.util.Properties
import java.io.FileInputStream

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.ksp)
}

// Real release key if present locally (key.properties + keystore/ are
// gitignored — PUBLIC repo). Without it, release falls back to debug signing
// so sideloads still work from a fresh clone (BACKUP_KEYS contract).
val keystoreProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) load(FileInputStream(f))
}
val hasReleaseKey = keystoreProps.getProperty("storeFile") != null

android {
    namespace = "com.kharcha.app"
    compileSdk = 36

    defaultConfig {
        // Same ID as the legacy Flutter app ON PURPOSE: sideloading replaces it.
        // There is no DB migration path — the Flutter Drift DB is abandoned, v0.1 starts fresh.
        applicationId = "com.akash.kharcha.app"
        minSdk = 32
        targetSdk = 36
        versionCode = 3
        versionName = "0.1.2"
        ndk { abiFilters += listOf("arm64-v8a") }
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = rootProject.file(keystoreProps.getProperty("storeFile"))
                storePassword = keystoreProps.getProperty("storePassword")
                keyAlias = keystoreProps.getProperty("keyAlias")
                keyPassword = keystoreProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            // Real key (CN=Akash Priyadarshi) when key.properties exists —
            // REQUIRED to update an already-installed build (same signature).
            // Fallback: debug key so fresh-clone sideloads still install.
            signingConfig = if (hasReleaseKey) signingConfigs.getByName("release") else signingConfigs.getByName("debug")
        }
    }

    buildFeatures {
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions { jvmTarget = "17" }

    buildFeatures {
        compose = true
    }

    packaging {
        jniLibs { useLegacyPackaging = false }
    }
}

/** Build the Rust core for android-arm64 with cargo-ndk and drop the .so into jniLibs. */
tasks.register<Exec>("buildKharchaCore") {
    workingDir = rootProject.projectDir.parentFile.resolve("kharcha-core")
    commandLine(
        "cargo", "ndk", "-t", "arm64-v8a",
        "-o", rootProject.projectDir.resolve("app/src/main/jniLibs"),
        "build", "--release"
    )
}
// tasks.named("preBuild").configure { dependsOn("buildKharchaCore") } // disabled: .so + bindings from Desktop/kharcha-core dist/

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.fragment.ktx)
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.compose.material.icons.core)
    implementation(libs.androidx.navigation.compose)
    implementation(libs.androidx.compose.tooling.preview)
    debugImplementation(libs.androidx.compose.tooling)
    implementation(libs.androidx.room.runtime)
    implementation(libs.androidx.room.ktx)
    ksp(libs.androidx.room.compiler)
    implementation("net.java.dev.jna:jna:5.15.0@aar")
    implementation(libs.androidx.biometric)
    implementation(libs.glance.appwidget)
}