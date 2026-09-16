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
        uniffiEnsureInitialized()
        database = AppDatabase.create(this)
    }
}