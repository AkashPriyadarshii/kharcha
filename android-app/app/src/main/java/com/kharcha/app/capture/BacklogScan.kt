package com.kharcha.app.capture

import android.content.Context
import android.provider.Telephony
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

data class BacklogResult(val inserted: Int, val duplicates: Int, val skipped: Int)

/**
 * One-shot import of pre-install bank SMS, run once after onboarding.
 * Every message routes through CaptureEngine.ingest — the same funnel as
 * live SMS — so spam/parse/dedupe/wallet logic lives in exactly one place.
 */
// ponytail: per-message ingest reloads the txn list each call; switch to the
// parseCaptures batch + one existing-load if the caps below ever grow.
object BacklogScan {
    private const val WINDOW_DAYS = 90L
    private const val MAX_ROWS = 500

    suspend fun scan(appContext: Context, dao: CaptureDao, txnDao: com.kharcha.app.db.KharchaDao): BacklogResult =
        withContext(Dispatchers.IO) {
            var inserted = 0
            var duplicates = 0
            var skipped = 0
            // ponytail: Rs/INR/₹ prefilter in SQL keeps the cursor small; Rust re-validates every body. Extend here if a bank format evades it.
            val since = System.currentTimeMillis() - WINDOW_DAYS * 24 * 60 * 60 * 1000L
            val cursor = appContext.contentResolver.query(
                Telephony.Sms.Inbox.CONTENT_URI,
                arrayOf(Telephony.Sms.BODY, Telephony.Sms.ADDRESS, Telephony.Sms.DATE),
                Telephony.Sms.DATE + " > ? AND (" + Telephony.Sms.BODY + " GLOB '*Rs*' OR " +
                    Telephony.Sms.BODY + " GLOB '*INR*' OR " + Telephony.Sms.BODY + " GLOB '*₹*')",
                arrayOf(since.toString()),
                Telephony.Sms.DATE + " DESC",
            ) ?: return@withContext BacklogResult(0, 0, 0)
            cursor.use {
                val b = it.getColumnIndexOrThrow(Telephony.Sms.BODY)
                val a = it.getColumnIndexOrThrow(Telephony.Sms.ADDRESS)
                val d = it.getColumnIndexOrThrow(Telephony.Sms.DATE)
                var read = 0
                while (it.moveToNext() && read++ < MAX_ROWS) {
                    val body = it.getString(b) ?: continue
                    when (CaptureEngine.ingest(appContext, body, it.getString(a) ?: "", it.getLong(d), dao, txnDao, quiet = true)) {
                        is IngestResult.Inserted -> inserted++
                        is IngestResult.Duplicate -> duplicates++
                        else -> skipped++
                    }
                }
            }
            BacklogResult(inserted, duplicates, skipped)
        }
}
