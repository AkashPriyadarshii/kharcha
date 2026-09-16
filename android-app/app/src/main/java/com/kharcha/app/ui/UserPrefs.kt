package com.kharcha.app.ui

import android.content.Context

/** First-launch + profile prefs. Separate file from AppLock (lock has its own). */
object UserPrefs {
    private const val PREFS = "user"
    private const val KEY_ONBOARDED = "onboarded"
    private const val KEY_NAME = "name"
    private const val KEY_LISTENER_WANTED = "listener_wanted"

    fun isOnboarded(context: Context): Boolean =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(KEY_ONBOARDED, false)

    fun markOnboarded(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean(KEY_ONBOARDED, true).apply()
    }

    fun name(context: Context): String =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY_NAME, null) ?: ""

    fun setName(context: Context, name: String) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY_NAME, name).apply()
    }

    /** True once the user opted into notification capture — gates the watchdog. */
    fun listenerWanted(context: Context): Boolean =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(KEY_LISTENER_WANTED, false)

    fun setListenerWanted(context: Context, wanted: Boolean) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean(KEY_LISTENER_WANTED, wanted).apply()
    }
}