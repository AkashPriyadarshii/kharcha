package com.kharcha.app.capture

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import com.kharcha.app.KharchaApp
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/** SMS capture path — deduped downstream against the notification channel. */
class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
        val app = context.applicationContext as KharchaApp
        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: return
        val pending = goAsync()

        CoroutineScope(SupervisorJob() + Dispatchers.IO).launch {
            try {
                val body = messages.joinToString(separator = "") { it.messageBody }
                val first = messages.firstOrNull() ?: return@launch
                CaptureEngine.ingest(
                    body = body,
                    sender = first.originatingAddress ?: "",
                    timestampMs = first.timestampMillis,
                    dao = app.database.captureDao(),
                    txnDao = app.database.dao(),
                )
            } finally {
                pending.finish()
            }
        }
    }
}