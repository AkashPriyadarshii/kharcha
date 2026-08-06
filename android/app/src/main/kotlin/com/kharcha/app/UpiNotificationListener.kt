package com.kharcha.app

import android.content.Context
import android.content.SharedPreferences
import android.os.Handler
import android.os.Looper
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/**
 * Watches UPI payment notifications and appends them to an inbox file the
 * Flutter side drains on startup (offline-first; works with app not running).
 *
 * Writes raw text as JSONL lines: {"package","text","seenAt"}. Parsing +
 * dedupe happens in Dart (`lib/core/upi_parser.dart`), so the Kotlin side
 * stays dumb and the logic stays unit-testable.
 *
 * A NotificationListenerService must be explicitly enabled by the user in
 * Settings — see the capture-disclosure screen.
 */
class UpiNotificationListener : NotificationListenerService() {

    companion object {
        private const val PREFS = "kharcha_inbox"
        private const val LAST_SEEN = "last_seen_utc_ms"
        private const val UPI_PACKAGES =
            setOf(
                "com.google.android.apps.nbu.paisa.user", // Google Pay
                "net.one97.paytm", // Paytm
                "com.phonepe.app", // PhonePe
                "com.axis.mobile", // Axis BHIM
                "com.chqbook", // etc.
            )

        private val dateFmt = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }
    }

    private val handler = Handler(Looper.getMainLooper())

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        val pkg = sbn.packageName
        if (pkg !in UPI_PACKAGES) return

        val prefs: SharedPreferences = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val now = System.currentTimeMillis()
        val lastSeen = prefs.getLong(LAST_SEEN, 0L)

        // Respect an existing in-flight copy for this sbn (notifications can
        // be re-posted with the same key, e.g. update). Skip dups by key.
        val key = sbn.key
        if (prefs.contains(key)) return
        prefs.edit().putBoolean(key, true).putLong(LAST_SEEN, now).apply()

        val text = sbn.notification?.extras?.getCharSequence("android.text")?.toString() ?: return
        if (text.isBlank()) return

        val line =
            "{\"package\":\"${escape(pkg)}\",\"text\":\"${escape(text)}\",\"seenAt\":\"${dateFmt.format(Date(now))}\"}\n"
        appendToInbox(line)
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification) {
        // no-op: capture already happened on post.
    }

    private fun appendToInbox(line: String) {
        try {
            val file = File(cacheDir, "upi_inbox.jsonl")
            file.parentFile?.mkdirs()
            file.appendText(line)
        } catch (_: Exception) {
            // Never crash the service on a file-write failure; the notification
            // is lost rather than double-captured. Underlying errors are rare.
        }
    }

    private fun escape(s: String): String =
        s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", " ").replace("\r", " ")
}
