package com.kharcha.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import com.pennywiseai.parser.core.ParsedTransaction
import java.math.RoundingMode

/**
 * Shows a rich, PennyWise-style notification when a transaction is captured.
 *
 * Format: "💸 ₹450 - Swiggy" / "Expense • HDFC Bank • A/c **4321"
 * Tapping opens the app (which drains the inbox and shows the transaction).
 *
 * Uses a unique notification ID per transaction (hash of amount+merchant+time)
 * so rapid captures don't overwrite each other.
 */
object TransactionNotifier {

    private const val CHANNEL_ID = "kharcha_transactions"
    private const val CHANNEL_NAME = "Transaction Alerts"

    fun show(context: Context, parsed: ParsedTransaction) {
        try {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            // Create channel (idempotent)
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Alerts for captured UPI/bank transactions"
            }
            nm.createNotificationChannel(channel)

            // Format amount: ₹1,234.50 or ₹450
            val amt = parsed.amount.setScale(2, RoundingMode.HALF_UP)
            val amtStr = if (amt.stripTrailingZeros().scale() <= 0) {
                "₹${amt.toBigInteger()}"
            } else {
                "₹$amt"
            }

            val merchant = parsed.merchant ?: "Unknown"
            val typeName = parsed.type.name // EXPENSE, INCOME, CREDIT, etc.
            val emoji = when {
                typeName.contains("INCOME", ignoreCase = true) -> "💰"
                typeName.contains("REFUND", ignoreCase = true) -> "↩️"
                typeName.contains("CREDIT", ignoreCase = true) && typeName != "EXPENSE" -> "💳"
                typeName.contains("TRANSFER", ignoreCase = true) -> "🔄"
                typeName.contains("INVESTMENT", ignoreCase = true) -> "📈"
                else -> "💸"
            }

            val title = "$emoji $amtStr - $merchant"

            // Subtitle: "Expense • HDFC Bank • A/c **4321"
            val parts = mutableListOf<String>()
            parts.add(typeName.lowercase().replaceFirstChar { it.uppercase() })
            if (!parsed.bankName.isNullOrBlank()) parts.add(parsed.bankName!!)
            if (!parsed.accountLast4.isNullOrBlank()) parts.add("A/c **${parsed.accountLast4}")
            val subtitle = parts.joinToString(" • ")

            // Tap intent: just open the app
            val launchIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                parsed.hashCode(),
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val notification = NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_launcher_foreground)
                .setContentTitle(title)
                .setContentText(subtitle)
                .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                .setContentIntent(pendingIntent)
                .setAutoCancel(true)
                .build()

            // Unique ID per transaction so multiple captures don't clobber each other
            val notifId = (parsed.hashCode() and 0x7FFFFFFF) % 100_000 + 1000
            nm.notify(notifId, notification)
        } catch (_: Exception) {
            // Never crash the receiver/service for a notification failure
        }
    }
}
