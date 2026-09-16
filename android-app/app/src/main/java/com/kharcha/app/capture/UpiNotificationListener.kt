package com.kharcha.app.capture

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import com.kharcha.app.KharchaApp
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * Push-capture path (GPay/PhonePe/any UPI app notification).
 * Only inspects the title + text extras, never full content.
 */
class UpiNotificationListener : NotificationListenerService() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        super.onNotificationPosted(sbn)
        val extras = sbn.notification?.extras ?: return
        if (!sbn.isOngoing) {
            val title = extras.getCharSequence("android.title")?.toString() ?: return
            val text = extras.getCharSequence("android.text")?.toString() ?: ""
            val body = "$title $text"
            if (body.isBlank()) return
            val app = applicationContext as KharchaApp
            scope.launch {
                CaptureEngine.ingest(
                    body = body,
                    sender = sbn.packageName,
                    timestampMs = System.currentTimeMillis(),
                    dao = app.database.captureDao(),
                    txnDao = app.database.dao(),
                )
            }
        }
    }
}