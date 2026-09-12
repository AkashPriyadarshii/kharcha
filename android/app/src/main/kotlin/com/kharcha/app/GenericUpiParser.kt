package com.kharcha.app

import com.pennywiseai.parser.core.ParsedTransaction
import com.pennywiseai.parser.core.TransactionType
import java.math.BigDecimal

object GenericUpiParser {
    
    private val AMOUNT_RE = Regex("""(?:Rs\.?|INR|₹)\s?(\d+(?:[.,]\d+)?)""", RegexOption.IGNORE_CASE)

    // Non-transaction rejection: recharge, bill due, OTP, marketing/loans, payment requests, failures
    private val NON_TRANSACTION_RE = Regex(
        """(?i)\b(?:""" +
        // 1. Telecom recharge & data packs
        """recharge|recharged|validity\s+expires|validity\s+expiring|validity\s+ending|plan\s+expires|plan\s+expiring|pack\s+expires|pack\s+expiring|data\s+pack|daily\s+data|talktime|unlimited\s+5g|prepaid\s+account|for\s+your\s+(?:jio|airtel|vi|vodafone|idea|bsnl)\b|""" +
        // 2. Bill due & statements
        """is\s+due|due\s+date|due\s+on|bill\s+generated|bill\s+due|overdue|payment\s+reminder|reminder:|minimum\s+amount\s+due|total\s+amount\s+due|statement\s+for|statement\s+generated|""" +
        // 3. OTP & security codes
        """otp|one\s+time\s+password|verification\s+code|security\s+code|secret\s+code|do\s+not\s+share|auth\s+code|use\s+code\s+\d|""" +
        // 4. Marketing, loans, rewards, lottery, referral spam
        """pre-approved|pre\s+approved|loan\s+offer|apply\s+for\s+loan|instant\s+loan|personal\s+loan|credit\s+limit|congratulations|claim\s+your\s+reward|voucher|scratch\s+card|refer\s+and\s+earn|invest\s+in|supercoins|flat\s+off|discount|""" +
        // 5. Payment requests, collect requests, pending, initiated (payment NOT completed)
        """requesting\s+payment|requested\s+payment|payment\s+request|has\s+requested|collect\s+request|approve\s+request|autopay\s+request|mandate\s+request|request\s+to\s+pay|request\s+of|requested\b|mandate\s+created|autopay\s+scheduled|standing\s+instruction|payment\s+pending|transaction\s+pending|txn\s+pending|payment\s+is\s+pending|payment\s+initiated|transaction\s+initiated|txn\s+initiated|processing\s+payment|in\s+progress|scheduled\s+for|will\s+be\s+debited|will\s+be\s+credited|""" +
        // 6. Failed & declined transactions
        """failed|declined|unsuccessful|cancelled|canceled|could\s+not\s+be\s+processed|timed\s+out|aborted|rejected""" +
        """)\b"""
    )
    
    // Credit markers: strictly money received by or credited to the user
    private val CREDIT_RE = Regex(
        """(?i)\b(?:credited\s+(?:to\s+(?:your|a\/c|acct|account)|with|in)|deposited\s+(?:in|to\s+(?:your|a\/c|acct|account))|received\s+from|paid\s+you|sent\s+you|(?:sent|paid|transferred|given|credited).{0,20}to\s+you|money\s+received|refund\s+credited|cashback\s+credited)\b"""
    )
    // Debit markers: paid, debited, sent to (if not 'sent to you')
    private val DEBIT_RE = Regex(
        """(?i)\b(?:debited\s+(?:from|for|by)|paid\s+to|spent\s+(?:on|at)|transferred\s+to|purchase\s+at|charged\s+to|withdrawn\s+from|debited|paid|spent)\b"""
    )
    
    // Merchant extraction markers
    private val VPA_RE = Regex("""(?i)([a-zA-Z0-9.\-_]+@[a-zA-Z]+)""")
    private val PAID_TO_RE = Regex("""(?i)(?:paid to|sent to)\s+([^0-9]+?)(?:\s+(?:for|on|via|ref|upi|Rs|₹|inr)|$)""")
    private val RECEIVED_FROM_RE = Regex("""(?i)(?:received from|from)\s+([^0-9]+?)(?:\s+(?:for|on|via|ref|upi|Rs|₹|inr)|$)""")
    private val AT_RE = Regex("""(?i)\b(?:at)\s+([^0-9]+?)(?:\s+(?:on|via|ref|upi|Rs|₹|inr)|$)""")
    private val REF_RE = Regex("""(?i)(?:upi\s*ref|utr|ref\s*id|txn\s*id|trans\s*id)[\s:#-]*([0-9a-zA-Z]{8,})""")
    private val BARE_REF_RE = Regex("""\b(\d{12})\b""")
    
    fun parse(text: String, sender: String, timestamp: Long): ParsedTransaction? {
        // 0. Explicit rejection of non-transaction messages
        if (NON_TRANSACTION_RE.containsMatchIn(text)) return null

        val allMatches = AMOUNT_RE.findAll(text).toList()
        if (allMatches.isEmpty()) return null

        var amountMatch: MatchResult? = null
        var foundBal: BigDecimal? = null

        for (m in allMatches) {
            val prefix = text.substring(0, m.range.first)
            val isBalance = Regex("""(?i)\b(?:bal|balance|avl\s*bal|available\s*(?:bal|balance)|limit|credit\s*limit)[\s:=-]*$""").containsMatchIn(prefix)
            if (isBalance) {
                if (foundBal == null) {
                    try {
                        foundBal = BigDecimal(m.groupValues[1].replace(",", ""))
                    } catch (_: Exception) {}
                }
            } else if (amountMatch == null) {
                amountMatch = m
            }
        }
        if (amountMatch == null) {
            amountMatch = allMatches.first()
        }

        val amountStr = amountMatch.groupValues[1].replace(",", "")
        val amount = try {
            BigDecimal(amountStr)
        } catch (e: Exception) {
            return null
        }
        if (amount <= BigDecimal.ZERO) return null
        
        val isCredit = CREDIT_RE.containsMatchIn(text)
        val isDebit = DEBIT_RE.containsMatchIn(text)

        // If neither matched, it is NOT a verified completed payment notification
        if (!isCredit && !isDebit) {
            return null
        }

        val isRefund = Regex("""(?i)\b(?:refund|cashback|reversed|reversal)\b""").containsMatchIn(text)
        var type = if (isCredit && (!isDebit || isRefund)) {
            TransactionType.INCOME
        } else {
            TransactionType.EXPENSE
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

        var reference: String? = REF_RE.find(text)?.groupValues?.getOrNull(1)
        if (reference == null) {
            val bareMatch = BARE_REF_RE.find(text)
            if (bareMatch != null) {
                val cand = bareMatch.groupValues[1]
                val idx = bareMatch.range.first
                val prefix = text.substring(0, idx)
                if (!Regex("""(?i)(?:a/c|acct|account|card)(?:\s*no\.?|\s*number)?(?:\s*ending\s*(?:in|with))?\s*(?:x|X|\*)*\s*$""").containsMatchIn(prefix)) {
                    reference = cand
                }
            }
        }

        return ParsedTransaction(
            amount = amount,
            type = type,
            merchant = merchant,
            reference = reference,
            accountLast4 = null,
            balance = foundBal,
            smsBody = text,
            sender = sender,
            timestamp = timestamp,
            bankName = "App" // generic
        )
    }
}
