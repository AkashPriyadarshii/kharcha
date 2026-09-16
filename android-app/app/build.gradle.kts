import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.ksp)
}

android {
    namespace = "com.kharcha.app"
    compileSdk = 36

    defaultConfig {
        // app2 while both apps coexist — same ID would silently replace the legacy Flutter app.
        applicationId = "com.kharcha.app"
        minSdk = 32
        targetSdk = 36
        versionCode = 1
        versionName = "0.1.0"
        ndk { abiFilters += listOf("arm64-v8a") }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
        }
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
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.compose.tooling.preview)
    debugImplementation(libs.androidx.compose.tooling)
    implementation(libs.androidx.navigation.compose)
    implementation(libs.androidx.room.runtime)
    implementation(libs.androidx.room.ktx)
    ksp(libs.androidx.room.compiler)
    implementation(libs.jna)
    implementation(libs.androidx.biometric)
}