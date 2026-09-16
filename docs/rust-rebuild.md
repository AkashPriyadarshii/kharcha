# Rust .so rebuild recipe

The app loads a committed arm64 binary
(`android-app/app/src/main/jniLibs/arm64-v8a/libkharcha_core.so`) plus
committed UniFFI bindings (`core/generated/.../kharcha_core.kt`). Both are
built from `Desktop/kharcha-core/dist/` on a machine with the Android SDK.
This box has the Rust side ready
(`aarch64-linux-android` target + `uniffi-bindgen` installed) but NO Android
SDK, so no new native exports can ship until the steps below run once.

Rule until then: no new `#[uniffi::export]` fns. New logic lives app-side
(Kotlin). Pure-Rust accuracy fixes may land with `cargo test` cover, but
they reach the phone only with a rebuilt .so.

## One-time setup (needs network, ~4 GB disk)

1. Install Android cmdline-tools into `%LOCALAPPDATA%/Android/Sdk/cmdline-tools/latest`.
2. `sdkmanager "platforms;android-36" "ndk;<version>"` (any recent NDK; record the version here when run).
3. Set `ANDROID_NDK_HOME=%LOCALAPPDATA%/Android/Sdk/ndk/<version>`.
4. Linker config for the target (cargo-ndk does this automatically;
   otherwise `.cargo/config.toml`):
   `[target.aarch64-linux-android] linker = "<ndk>/toolchains/llvm/prebuilt/windows-x86_64/bin/aarch64-linux-android35-clang.cmd"`

## Rebuild (every Rust change that must reach the phone)

1. `cd Desktop/kharcha-core && cargo test` — 59/59 green or stop.
2. `cargo build --release --target aarch64-linux-android` — produces
   `target/aarch64-linux-android/release/libkharcha_core.so`.
3. Copy it over `dist/kharcha_core-arm64-v8a.so` AND over the repo's
   `android-app/app/src/main/jniLibs/arm64-v8a/libkharcha_core.so`.
4. Regenerate bindings (exact command from CLAUDE.md):
   `uniffi-bindgen generate --language kotlin --library <the .so> --out-dir <generated> --no-format`
   then move the output over `kharcha_core.kt`.
5. `cargo test` + `./gradlew.bat :app:assembleDebug`, both green.
6. Device smoke: TEST_CAPTURE intent parses, no `UnsatisfiedLinkError` in `kharcha.log`.
7. Commit .so + bindings + Rust source together. Never one without the others.

## Never

- Hand-edit the generated `kharcha_core.kt` to fake a new export.
- Commit a Rust export without its rebuilt .so (runtime crash on device).
- Rebuild from anything but the Desktop dist crate (provenance).
