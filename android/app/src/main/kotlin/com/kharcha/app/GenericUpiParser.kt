package com.kharcha.app

import com.pennywiseai.parser.core.ParsedTransaction
import com.pennywiseai.parser.core.TransactionType
import java.math.BigDecimal

object GenericUpiParser {
    
    private val AMOUNT_RE = Regex("""(?:Rs\.?|INR|₹)\s?(\d+(?:[.,]\d+)?)""", RegexOption.IGNORE_CASE)
    
    // Credit markers: received, credited, sent to you, requested
    private val CREDIT_RE = Regex("""(?i)\b(received|credited|sent to you|requested)\b""")
    // Debit markers: paid, debited, sent to (if not 'sent to you')
    private val DEBIT_RE = Regex("""(?i)\b(paid|debited|sent to|spent)\b""")
    
    // Merchant extraction markers
    private val VPA_RE = Regex("""(?i)([a-zA-Z0-9.\-_]+@[a-zA-Z]+)""")
    private val PAID_TO_RE = Regex("""(?i)(?:paid to|sent to)\s+([^0-9]+?)(?:\s+(?:for|on|via|ref|upi|Rs|₹|inr)|$)""")
    private val RECEIVED_FROM_RE = Regex("""(?i)(?:received from|from)\s+([^0-9]+?)(?:\s+(?:for|on|via|ref|upi|Rs|₹|inr)|$)""")
    private val AT_RE = Regex("""(?i)\b(?:at)\s+([^0-9]+?)(?:\s+(?:on|via|ref|upi|Rs|₹|inr)|$)""")
    
    fun parse(text: String, sender: String, timestamp: Long): ParsedTransaction? {
        val amountMatch = AMOUNT_RE.find(text) ?: return null
        val amountStr = amountMatch.groupValues[1].replace(",", "")
        val amount = try {
            BigDecimal(amountStr)
        } catch (e: Exception) {
            return null
        }
        
        var type = TransactionType.EXPENSE
        if (CREDIT_RE.containsMatchIn(text)) {
            type = TransactionType.INCOME
        } else if (DEBIT_RE.containsMatchIn(text)) {
            type = TransactionType.EXPENSE
        } else {
            // Default to EXPENSE if we can't tell, but let's try to be smart.
            // If it's a notification from GPay/PhonePe without explicit words, usually it's an expense.
        }

        var merchant = "Unknown"
        val vpaMatch = VPA_RE.find(text)
        if (vpaMatch != null) {
            merchant = vpaMatch.groupValues[1].trim()
        } else {
            if (type == TransactionType.INCOME) {
                val fromMatch = RECEIVED_FROM_RE.find(text)
                if (fromMatch != null) {
                    merchant = fromMatch.groupValues[1].trim()
                }
            } else {
                val toMatch = PAID_TO_RE.find(text)
                if (toMatch != null) {
                    merchant = toMatch.groupValues[1].trim()
                    if (merchant.equals("you", ignoreCase = true)) {
                        // "paid to you" is income actually.
                        merchant = "Unknown"
                        type = TransactionType.INCOME
                    }
                } else {
                    val atMatch = AT_RE.find(text)
                    if (atMatch != null) {
                        merchant = atMatch.groupValues[1].trim()
                    }
                }
            }
        }
        
        // Cleanup merchant
        merchant = merchant.trim().replace(Regex("""\s+"""), " ")
        if (merchant.isBlank() || merchant.equals("you", ignoreCase = true) || merchant.equals("a", ignoreCase = true)) {
            merchant = "Unknown"
        }

        return ParsedTransaction(
            amount = amount,
            type = type,
            merchant = merchant,
            reference = null,
            accountLast4 = null,
            balance = null,
            smsBody = text,
            sender = sender,
            timestamp = timestamp,
            bankName = "App" // generic
        )
    }
}
