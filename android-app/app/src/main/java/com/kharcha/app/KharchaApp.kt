package com.kharcha.app

import android.app.Application
import com.kharcha.app.capture.CrashLog
import com.kharcha.app.db.AppDatabase
import uniffi.kharcha_core.uniffiEnsureInitialized

/**
 * Installs a crash logger and opens the Room database. Any exception that
 * escapes Application.onCreate would brick the app into an infinite launch
 * loop — degrade gracefully instead.
 */
class KharchaApp : Application() {
    lateinit var database: AppDatabase
        private set

    override fun onCreate() {
        super.onCreate()

        // Uncaught exception handler — writes to app-private kharcha.log,
        // then rethrows to Android's default handler (show-force-close).
        val default = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            CrashLog.crash(this, thread, throwable)
            default?.uncaughtException(thread, throwable)
        }

        try {
            uniffiEnsureInitialized()
        } catch (t: Throwable) {
            CrashLog.log(this, "KharchaApp", "core .so failed to load: ${t.message}")
        }
        database = AppDatabase.create(this)
    }
}