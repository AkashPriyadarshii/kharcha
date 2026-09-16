package com.kharcha.app.capture

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

/** One buzz per auto-captured transaction. Notify on Insert only — dupes stay silent. */
object CaptureNotify {
    private const val CHANNEL_ID = "capture"
    private const val CHANNEL_NAME = "Captured payments"
    private var channelMade = false

    fun inserted(context: Context, merchant: String, amountPaise: Long, category: String?) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(context, android.Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) return
        val mgr = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return
        if (!channelMade) {
            mgr.createNotificationChannel(NotificationChannel(CHANNEL_ID, CHANNEL_NAME, NotificationManager.IMPORTANCE_DEFAULT))
            channelMade = true
        }
        val rupees = "₹" + (amountPaise / 100) + if (amountPaise % 100 == 0L) "" else ".%02d".format(amountPaise % 100)
        val text = "$rupees · $merchant" + (if (category != null) " · $category" else "")
        val n = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("Payment captured")
            .setContentText(text)
            .setAutoCancel(true)
            .build()
        mgr.notify((System.currentTimeMillis() % Int.MAX_VALUE).toInt(), n)
    }

    /** Threshold + summary pushes. Own channel so capture buzz stays separate. */
    fun alert(context: Context, title: String, text: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(context, android.Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) return
        val mgr = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return
        mgr.createNotificationChannel(NotificationChannel("alerts", "Budget alerts", NotificationManager.IMPORTANCE_DEFAULT))
        val n = NotificationCompat.Builder(context, "alerts")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(text)
            .setAutoCancel(true)
            .build()
        mgr.notify("alerts", title.hashCode(), n)
    }
}
