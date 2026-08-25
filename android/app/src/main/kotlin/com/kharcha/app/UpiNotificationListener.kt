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

class UpiNotificationListener : NotificationListenerService() {

    companion object {
        private const val PREFS = "kharcha_inbox"
        private const val LAST_SEEN = "last_seen_utc_ms"
        private const val LAST_TEXT = "last_text"
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

            if (pkg.contains("whatsapp", ignoreCase = true) ||
                pkg.contains("telegram", ignoreCase = true) ||
                pkg.contains("instagram", ignoreCase = true) ||
                pkg.contains("messaging", ignoreCase = true) ||
                pkg.contains("mms", ignoreCase = true) ||
                pkg.contains("facebook", ignoreCase = true)) {
                return
            }

            if (!AMOUNT_RE.containsMatchIn(text)) return
            if (text.isBlank()) return

            val prefs: SharedPreferences = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val now = System.currentTimeMillis()
            val lastSeen = prefs.getLong(LAST_SEEN, 0L)
            val lastText = prefs.getString(LAST_TEXT, null)
            if (now - lastSeen < DEDUPE_WINDOW_MS && lastText == text) return

            prefs.edit().putLong(LAST_SEEN, now).putString(LAST_TEXT, text).apply()

            val parsedTxn = com.pennywiseai.parser.core.bank.BankParserFactory.parse(text, pkg, now) ?: GenericUpiParser.parse(text, pkg, now)
            val parsedJson = if (parsedTxn != null) {
                """
                ,"parsed":{
                    "amount":${parsedTxn.amount},
                    "merchant":"${escape(parsedTxn.merchant ?: "Unknown")}",
                    "type":"${parsedTxn.type.name}",
                    "reference":${if (parsedTxn.reference != null) "\"${escape(parsedTxn.reference!!)}\"" else "null"},
                    "balance":${parsedTxn.balance},
                    "accountMask":${if (parsedTxn.accountLast4 != null) "\"${escape(parsedTxn.accountLast4!!)}\"" else "null"},
                    "bankName":${if (parsedTxn.bankName != null) "\"${escape(parsedTxn.bankName!!)}\"" else "null"}
                }
                """.trimIndent().replace("\n", "")
            } else ""

            val line =
                "{\"package\":\"${escape(pkg)}\",\"text\":\"${escape(text)}\",\"seenAt\":\"${dateFmt.format(Date(now))}\"$parsedJson}\n"
            
            Thread {
                try {
                    val file = File(cacheDir, "upi_inbox.jsonl")
                    file.parentFile?.mkdirs()
                    synchronized("upi_inbox_lock".intern()) {
                        file.appendText(line)
                    }
                    if (parsedTxn != null) {
                        val insertRes = KharchaDatabaseHelper(this@UpiNotificationListener).insertTransaction(parsedTxn, now)
                        if (insertRes != null && !insertRes.isDuplicate) {
                            TransactionNotifier.show(this@UpiNotificationListener, parsedTxn)
                        }
                    }
                } catch (_: Exception) {
                }
            }.start()

        } catch (_: Exception) {
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification) {
    }

    private fun escape(s: String): String =
        s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", " ").replace("\r", " ")
}
