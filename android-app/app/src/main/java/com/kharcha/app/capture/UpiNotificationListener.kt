package com.kharcha.app.capture

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import com.kharcha.app.KharchaApp
import kotlinx.coroutines.CoroutineExceptionHandler
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * Push-capture path. Only inspects the title + text extras, never full content.
 *
 * Audit #4: (1) previously ingested EVERY app's notifications — a WhatsApp
 * message with an amount would be parsed as a payment. Now allowlisted to UPI
 * apps + common banks (sender package feeds dedupe's cross-channel window, so
 * extras don't matter). (2) `!isOngoing` gate dropped: GPay posts its payment
 * confirmation as a sticky/ongoing notification; skipping it lost captures.
 * Dedupe in Rust handles any repeats.
 */
class UpiNotificationListener : NotificationListenerService() {
    private val scope = CoroutineScope(
        SupervisorJob() + Dispatchers.IO +
            CoroutineExceptionHandler { _, e ->
                CrashLog.log(applicationContext, "UpiListener", "ingest failed: ${e.message}")
            }
    )

    // ponytail: static allowlist, one line per package. Configurable later if
    // real-world captures show a missing app (add when observed, not before).
    private val allowlist = setOf(
        "com.google.android.apps.nbu.paisa.user", // GPay
        "com.phonepe.app",                        // PhonePe
        "in.org.npci.upiapp",                     // BHIM
        "com.cred.app",                           // CRED
        "com.paytm.app",                          // Paytm
        "com.netone.start",                       // Paytm (legacy pkg)
        "com.amazon.mPay.android",                // Amazon Pay
        "money.super.app",                        // super.money (Flipkart)
        "com.supermoney.app",                     // super.money alias
        "com.navi.navi",                          // Navi UPI
        "indwin.c3.shareapp",                     // slice UPI
        "com.whatsapp",                           // WhatsApp Pay
        "com.tatadigital.tcp",                    // Tata Neu
        "org.altruist.BajajFinserv",              // Bajaj Pay
        "com.mobikwik_new",                       // MobiKwik
        "com.freecharge.android",                 // Freecharge
    )

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        super.onNotificationPosted(sbn)
        if (sbn.packageName !in allowlist) return
        val extras = sbn.notification?.extras ?: return
        val title = extras.getCharSequence("android.title")?.toString() ?: return
        val text = extras.getCharSequence("android.text")?.toString() ?: ""
        val body = "$title $text"
        if (body.isBlank()) return
        val app = applicationContext as KharchaApp
        scope.launch {
            CaptureEngine.ingest(
                appContext = applicationContext,
                body = body,
                sender = sbn.packageName,
                timestampMs = System.currentTimeMillis(),
                dao = app.database.captureDao(),
                txnDao = app.database.dao(),
            )
        }
    }
}