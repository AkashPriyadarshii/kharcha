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
 *
 * v0.1.1 fixes: (1) drop the per-key tombstone set (it grew forever and
 * `sbn.key` survives some re-posts) — dedupe is now a short rolling time
 * window, Dart's `upi_ref` check is the real authority; (2) only write
 * notifications that look like a payment (contain an amount); (3) read the
 * amount from title OR text (some UPI apps put it in the title); (4) the whole
 * handler is crash-contained so a bad notification never kills the service.
 */
class UpiNotificationListener : NotificationListenerService() {

    companion object {
        private const val PREFS = "kharcha_inbox"
        private const val LAST_SEEN = "last_seen_utc_ms"
        private const val LAST_TEXT = "last_text"
        // Re-posts of the identical notification (e.g. an in-place update)
        // within this window are treated as the same event. This is strictly
        // for Android notification spam (re-post within seconds), NOT for
        // payment dedup — the Dart-side upi_ref + time-window check is the
        // real authority. 60s was too aggressive: paying the same friend ₹1
        // twice within a minute produced identical text and the second was
        // silently dropped before Dart ever saw it.
        private const val DEDUPE_WINDOW_MS = 5_000L
        private val AMOUNT_RE = Regex("""(?:₹|Rs\.?|INR|inr)\s*\d""")

        private val dateFmt = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }
    }

    private val handler = Handler(Looper.getMainLooper())

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        try {
            val pkg = sbn.packageName
            val extras = sbn.notification?.extras ?: return
            val text = (
                extras.getCharSequence("android.title")?.toString()
                    ?: ""
                ) + " " + (
                extras.getCharSequence("android.text")?.toString()
                    ?: ""
                )
            if (!AMOUNT_RE.containsMatchIn(text)) return // not a payment
            if (text.isBlank()) return

            val prefs: SharedPreferences = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val now = System.currentTimeMillis()
            val lastSeen = prefs.getLong(LAST_SEEN, 0L)
            val lastText = prefs.getString(LAST_TEXT, null)
            if (now - lastSeen < DEDUPE_WINDOW_MS && lastText == text) return

            prefs.edit().putLong(LAST_SEEN, now).putString(LAST_TEXT, text).apply()

            val line =
                "{\"package\":\"${escape(pkg)}\",\"text\":\"${escape(text)}\",\"seenAt\":\"${dateFmt.format(Date(now))}\"}\n"
            appendToInbox(line)
        } catch (_: Exception) {
            // A bad notification must never crash the service — skip it.
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification) {
        // no-op: capture already happened on post.
    }

    private fun appendToInbox(line: String) {
        Thread {
            try {
                val file = File(cacheDir, "upi_inbox.jsonl")
                file.parentFile?.mkdirs()
                synchronized("upi_inbox_lock".intern()) {
                    file.appendText(line)
                }
            } catch (_: Exception) {
                // Never crash the service on a file-write failure.
            }
        }.start()
    }

    private fun escape(s: String): String =
        s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", " ").replace("\r", " ")
}

