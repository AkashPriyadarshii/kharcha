package com.kharcha.app.capture

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.kharcha.app.KharchaApp
import com.kharcha.app.ui.UserPrefs
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import java.util.Calendar

/**
 * Daily spend summary push ("Aaj ₹540 kharcha hue").
 * Inexact daily alarm: no exact-alarm permission, Doze-friendly.
 * Boot receiver re-arms after reboot.
 */
object SummaryAlarm {
    private const val REQ = 1001
    const val ACTION = "com.akash.kharcha.DAILY_SUMMARY"

    fun refresh(context: Context) {
        if (UserPrefs.summaryOn(context)) schedule(context)
        else cancel(context)
    }

    fun schedule(context: Context) {
        val mgr = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val pi = pending(context)
        mgr.cancel(pi)
        mgr.setInexactRepeating(AlarmManager.RTC_WAKEUP, nextTrigger(context), AlarmManager.INTERVAL_DAY, pi)
    }

    fun cancel(context: Context) {
        val mgr = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        mgr.cancel(pending(context))
    }

    private fun nextTrigger(context: Context): Long {
        val c = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, UserPrefs.summaryHour(context))
            set(Calendar.MINUTE, UserPrefs.summaryMinute(context))
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        if (c.timeInMillis <= System.currentTimeMillis()) c.add(Calendar.DAY_OF_YEAR, 1)
        return c.timeInMillis
    }

    private fun pending(context: Context): PendingIntent {
        val i = Intent(context, SummaryReceiver::class.java).setAction(ACTION)
        return PendingIntent.getBroadcast(
            context, REQ, i,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}

class SummaryReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            SummaryAlarm.refresh(context)
            return
        }
        if (!UserPrefs.summaryOn(context)) return
        CoroutineScope(SupervisorJob() + Dispatchers.IO).launch {
            try {
                val app = context.applicationContext as KharchaApp
                val start = Calendar.getInstance().apply {
                    set(Calendar.HOUR_OF_DAY, 0)
                    set(Calendar.MINUTE, 0)
                    set(Calendar.SECOND, 0)
                    set(Calendar.MILLISECOND, 0)
                }.timeInMillis
                val spend = app.database.dao().spendBetween(start, start + 24L * 60 * 60 * 1000)
                push(context, spend)
            } catch (e: Exception) {
                CrashLog.log(context, "Summary", "failed: ${e.message}")
            }
        }
    }

    private fun push(context: Context, spendPaise: Long) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(context, android.Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) return
        val mgr = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return
        mgr.createNotificationChannel(NotificationChannel("summary", "Daily summary", NotificationManager.IMPORTANCE_DEFAULT))
        val rupees = "₹" + (spendPaise / 100)
        val n = NotificationCompat.Builder(context, "summary")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("Kharcha daily summary")
            .setContentText("Aaj $rupees kharcha hue.")
            .setAutoCancel(true)
            .build()
        mgr.notify("summary", 7, n)
    }
}
