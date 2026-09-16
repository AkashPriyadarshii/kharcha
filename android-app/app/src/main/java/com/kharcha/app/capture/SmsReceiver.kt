package com.kharcha.app.capture

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import com.kharcha.app.KharchaApp
import kotlinx.coroutines.CoroutineExceptionHandler
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/** SMS capture path — deduped downstream against the notification channel. */
class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        // Fail-safe: ANY failure in this receiver (even getting the messages
        // out of the PDU — corrupted multi-part payloads can throw there) must
        // never crash the app. Offer/spam messages arrive here all day.
        try {
            val app = context.applicationContext as KharchaApp
            if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

            val pending = goAsync()
            val errors = CoroutineExceptionHandler { _, e ->
                CrashLog.log(context, "SmsReceiver", "ingest failed: ${e.message}")
            }

            CoroutineScope(SupervisorJob() + Dispatchers.IO + errors).launch {
                try {
                    val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: return@launch
                    val first = messages.firstOrNull() ?: return@launch
                    val body = messages.joinToString(separator = "") { it.messageBody }
                    val sender = first.originatingAddress ?: ""
                    val timestampMs = first.timestampMillis

                    CaptureEngine.ingest(
                        appContext = context,
                        body = body,
                        sender = sender,
                        timestampMs = timestampMs,
                        dao = app.database.captureDao(),
                        txnDao = app.database.dao(),
                    )
                } catch (e: Exception) {
                    CrashLog.log(context, "SmsReceiver", "sms parse failed: ${e.message}")
                } finally {
                    pending.finish()
                }
            }
        } catch (e: Exception) {
            CrashLog.log(context, "SmsReceiver", "receiver failed: ${e.message}")
        }
    }
}