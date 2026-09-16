package com.kharcha.app.capture

import com.kharcha.app.db.RuleRow
import com.kharcha.app.db.TransactionRow
import uniffi.kharcha_core.CaptureDecision
import uniffi.kharcha_core.ExistingRow
import uniffi.kharcha_core.Rule
import uniffi.kharcha_core.checkCapture
import uniffi.kharcha_core.categorizeMerchant
import uniffi.kharcha_core.isSpam
import uniffi.kharcha_core.parseCapture

sealed class IngestResult {
    object Spam : IngestResult()
    object Unparsed : IngestResult()
    data class Inserted(val id: Long) : IngestResult()
    data class Duplicate(val backfilledRef: Boolean) : IngestResult()
}

/**
 * One funnel for BOTH capture channels (SMS + notification listener).
 * All decisions live in kharcha-core (Rust): spam filter, parse, dedupe.
 * The app layer only maps rows and writes.
 */
object CaptureEngine {
    private const val DEDUPE_WINDOW_MS = 5 * 60 * 1000L

    suspend fun ingest(body: String, sender: String, timestampMs: Long, dao: CaptureDao, txnDao: com.kharcha.app.db.KharchaDao): IngestResult {
        if (isSpam(body)) return IngestResult.Spam

        val parsed = parseCapture(body, sender, timestampMs) ?: return IngestResult.Unparsed
        val payment = parsed.payment

        val existing = txnDao.recentTransactions().map {
            ExistingRow(
                upiRef = it.upiRef,
                amountPaise = it.amountPaise,
                isIncome = it.isIncome,
                txnMs = it.timestampMs,
                isDeleted = false,
                contentHash = it.contentHash?.toULong(),
            )
        }

        return when (val decision = checkCapture(
            candidateRef = payment.upiRef,
            amountPaise = payment.amountPaise,
            isIncome = payment.isIncome,
            txnMs = parsed.timestampMs,
            candidateHash = parsed.contentHash,
            existing = existing,
        )) {
            is CaptureDecision.Insert -> {
                val categoryId = categorize(payment.merchant, txnDao.allRules())
                IngestResult.Inserted(
                    txnDao.insert(
                        TransactionRow(
                            amountPaise = payment.amountPaise,
                            merchant = payment.merchant,
                            categoryId = categoryId,
                            upiRef = payment.upiRef,
                            bankName = payment.bankName,
                            accountMask = payment.accountMask,
                            needsReview = payment.needsReview,
                            isIncome = payment.isIncome,
                            timestampMs = parsed.timestampMs,
                            contentHash = parsed.contentHash.toLong(),
                            sender = parsed.sender,
                        )
                    )
                )
            }
            is CaptureDecision.Skip -> {
                val candidateRef = payment.upiRef
                if (decision.backfillRef && candidateRef != null) {
                    val target = dao.backfillTarget(
                        payment.amountPaise, payment.isIncome,
                        parsed.timestampMs - DEDUPE_WINDOW_MS, parsed.timestampMs + DEDUPE_WINDOW_MS,
                    )
                    if (target != null) dao.updateRef(target.id, candidateRef)
                }
                IngestResult.Duplicate(decision.backfillRef)
            }
        }
    }

    /** Categorize via kharcha-core rule matcher ("learned" rules beat "builtin" in Rust). */
    suspend fun categorize(merchant: String, rules: List<RuleRow>): Long? {
        if (rules.isEmpty()) return null
        return categorizeMerchant(
            merchant,
            rules.map { Rule(pattern = it.pattern, ruleType = it.ruleType, categoryId = it.categoryId) }
        )?.categoryId
    }
}