package com.kharcha.app

import android.app.Application
import com.kharcha.app.db.AppDatabase
import uniffi.kharcha_core.uniffiEnsureInitialized

class KharchaApp : Application() {
    lateinit var database: AppDatabase
        private set

    override fun onCreate() {
        super.onCreate()
        // Loads libkharcha_core.so and validates uniffi checksums once.
        try {
            // Load libkharcha_core.so. On a corrupted/partial install the
            // UnsatisfiedLinkError would kill Application.onCreate → boot
            // loop; degrade to an uncrashing app instead (audit #9).
            uniffiEnsureInitialized()
        } catch (t: Throwable) {
            android.util.Log.e("KharchaApp", "core .so failed to load: ${t.message}")
        }
        database = AppDatabase.create(this)
    }
}