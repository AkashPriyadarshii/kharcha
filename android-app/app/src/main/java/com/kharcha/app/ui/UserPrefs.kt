package com.kharcha.app.ui

import android.content.Context

/** First-launch + profile prefs. Separate file from AppLock (lock has its own). */
object UserPrefs {
    private const val PREFS = "user"
    private const val KEY_ONBOARDED = "onboarded"
    private const val KEY_NAME = "name"
    private const val KEY_LISTENER_WANTED = "listener_wanted"
    private const val KEY_LAST_CAPTURE_MS = "last_capture_ms"

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

    private const val KEY_SECURE_FLAG = "secure_flag"
    private const val KEY_SUMMARY_ON = "summary_on"
    private const val KEY_SUMMARY_HOUR = "summary_hour"
    private const val KEY_SUMMARY_MIN = "summary_min"

    /** Mask the app thumbnail in the recent-apps switcher. */
    fun secureFlag(context: Context): Boolean =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(KEY_SECURE_FLAG, false)

    fun setSecureFlag(context: Context, on: Boolean) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean(KEY_SECURE_FLAG, on).apply()
    }

    /** Daily summary push. Default 21:00 per PRD. */
    fun summaryOn(context: Context): Boolean =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(KEY_SUMMARY_ON, false)

    fun setSummaryOn(context: Context, on: Boolean) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean(KEY_SUMMARY_ON, on).apply()
    }

    fun summaryHour(context: Context): Int =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getInt(KEY_SUMMARY_HOUR, 21)

    fun summaryMinute(context: Context): Int =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getInt(KEY_SUMMARY_MIN, 0)

    fun setSummaryTime(context: Context, hour: Int, minute: Int) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putInt(KEY_SUMMARY_HOUR, hour).putInt(KEY_SUMMARY_MIN, minute).apply()
    }

    private const val KEY_BACKLOG_SCANNED = "backlog_scanned"

    /** True once the one-shot pre-install SMS import has run — never repeats. */
    fun backlogScanned(context: Context): Boolean =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(KEY_BACKLOG_SCANNED, false)

    fun markBacklogScanned(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean(KEY_BACKLOG_SCANNED, true).apply()
    }

    /** Highest budget-alert level already pushed per category (0/50/80/100). */
    fun budgetAlertLevel(context: Context, categoryId: Long): Int =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getInt("alert_$categoryId", 0)

    fun setBudgetAlertLevel(context: Context, categoryId: Long, level: Int) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putInt("alert_$categoryId", level).apply()
    }

    /** Last successful auto-capture, 0 = never. Dead-man signal for silent listener death. */
    fun lastCaptureMs(context: Context): Long =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getLong(KEY_LAST_CAPTURE_MS, 0)

    fun stampCapture(context: Context, ms: Long = System.currentTimeMillis()) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putLong(KEY_LAST_CAPTURE_MS, ms).apply()
    }

    // Home screen customizable sections
    private const val KEY_SHOW_HOME_BUDGETS = "show_home_budgets"
    private const val KEY_SHOW_HOME_GOALS = "show_home_goals"
    private const val KEY_SHOW_HOME_SUBS = "show_home_subs"
    private const val KEY_SHOW_HOME_DAILY_BURN = "show_home_daily_burn"

    fun showHomeBudgets(context: Context): Boolean =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(KEY_SHOW_HOME_BUDGETS, true)

    fun setShowHomeBudgets(context: Context, show: Boolean) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean(KEY_SHOW_HOME_BUDGETS, show).apply()
    }

    fun showHomeGoals(context: Context): Boolean =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(KEY_SHOW_HOME_GOALS, true)

    fun setShowHomeGoals(context: Context, show: Boolean) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean(KEY_SHOW_HOME_GOALS, show).apply()
    }

    fun showHomeSubs(context: Context): Boolean =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(KEY_SHOW_HOME_SUBS, true)

    fun setShowHomeSubs(context: Context, show: Boolean) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean(KEY_SHOW_HOME_SUBS, show).apply()
    }

    fun showHomeDailyBurn(context: Context): Boolean =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(KEY_SHOW_HOME_DAILY_BURN, true)

    fun setShowHomeDailyBurn(context: Context, show: Boolean) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean(KEY_SHOW_HOME_DAILY_BURN, show).apply()
    }
}