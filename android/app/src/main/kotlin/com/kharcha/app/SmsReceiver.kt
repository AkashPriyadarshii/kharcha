package com.kharcha.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

class SmsReceiver : BroadcastReceiver() {

    companion object {
        private val AMOUNT_RE = Regex("""(?:₹|Rs\.?|INR|inr)\s*\d""")
        private val dateFmt = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }

        fun isBlockedSender(sender: String): Boolean {
            val upper = sender.uppercase()
            return upper.contains("JIO") ||
                   upper.contains("AIRTEL") ||
                   upper.contains("VICARE") ||
                   upper.contains("VIALRT") ||
                   upper.contains("BSNL") ||
                   upper.contains("IDEA") ||
                   upper.contains("VODAFONE") ||
                   upper.contains("PROMO") ||
                   upper.contains("OFFER") ||
                   upper.contains("ALERTS") ||
                   upper.contains("REMIND") ||
                   upper.contains("COUPON") ||
                   upper.contains("DEALS")
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        val pendingResult = goAsync()
        Thread {
            try {
                val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
                if (messages.isNullOrEmpty()) return@Thread

                val smsMap = mutableMapOf<String, StringBuilder>()
                for (message in messages) {
                    val sender = message.originatingAddress ?: "SMS"
                    val body = message.messageBody ?: continue
                    smsMap.getOrPut(sender) { StringBuilder() }.append(body)
                }

                val now = System.currentTimeMillis()
                val seenAt = dateFmt.format(Date(now))

                for ((sender, bodyBuilder) in smsMap) {
                    val text = bodyBuilder.toString().trim()
                    if (!AMOUNT_RE.containsMatchIn(text)) continue

                    val parsedTxn = com.pennywiseai.parser.core.bank.BankParserFactory.parse(text, sender, now)
                        ?: if (!isBlockedSender(sender)) GenericUpiParser.parse(text, sender, now) else null
                    
                    val parsedJson = if (parsedTxn != null) {
                        """
                        ,"parsed":{
                            "amount":${parsedTxn.amount},
                            "merchant":"${escape(parsedTxn.merchant ?: "Unknown")}",
                            "type":"${escape(parsedTxn.type.name)}",
                            "reference":${if (parsedTxn.reference != null) "\"${escape(parsedTxn.reference!!)}\"" else "null"},
                            "balance":${parsedTxn.balance?.toPlainString() ?: "null"},
                            "accountMask":${if (parsedTxn.accountLast4 != null) "\"${escape(parsedTxn.accountLast4!!)}\"" else "null"},
                            "bankName":${if (parsedTxn.bankName != null) "\"${escape(parsedTxn.bankName!!)}\"" else "null"}
                        }
                        """.trimIndent().replace("\n", "")
                    } else ""

                    var wasNotified = false
                    if (parsedTxn != null) {
                        val insertRes = KharchaDatabaseHelper(context).insertTransaction(parsedTxn, now)
                        if (insertRes != null && !insertRes.isDuplicate) {
                            TransactionNotifier.show(context, parsedTxn)
                            wasNotified = true
                        }
                    }

                    val line = "{\"package\":\"sms.${escape(sender)}\",\"text\":\"${escape(text)}\",\"seenAt\":\"$seenAt\",\"notified\":$wasNotified$parsedJson}\n"
                    
                    val file = File(context.cacheDir, "upi_inbox.jsonl")
                    file.parentFile?.mkdirs()
                    synchronized("upi_inbox_lock".intern()) {
                        file.appendText(line)
                    }
                }
            } catch (_: Exception) {
            } finally {
                pendingResult.finish()
            }
        }.start()
    }

    private fun escape(s: String): String =
        s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", " ").replace("\r", " ")
}
