package com.kharcha.app.capture

import com.kharcha.app.db.RuleRow
import com.kharcha.app.db.TransactionRow
import com.kharcha.app.db.Wallet
import com.kharcha.app.ui.UserPrefs
import uniffi.kharcha_core.CaptureDecision
import uniffi.kharcha_core.ExistingRow
import uniffi.kharcha_core.Rule
import uniffi.kharcha_core.checkCapture
import uniffi.kharcha_core.categorizeMerchant
import uniffi.kharcha_core.isSpam
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import uniffi.kharcha_core.maxBodyBytes
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
    private val ingestMutex = Mutex()
    private const val DEDUPE_WINDOW_MS = 5 * 60 * 1000L

    // Audit #3: caps exist in Rust but nothing enforced them here. $title $text
    // joins and SMS joinToString("") were passed unbounded into the FFI. The
    // Rust parser also re-guards, but fail EARLY — a 1 MB paste-attack string
    // shouldn't even cross JNA. Char length ≈ byte length for ASCII-heavy
    // SMS; multibyte text only over-counts (safer direction).
    private val maxBody = maxBodyBytes().toInt()

    suspend fun ingest(appContext: android.content.Context, body: String, sender: String, timestampMs: Long, dao: CaptureDao, txnDao: com.kharcha.app.db.KharchaDao, quiet: Boolean = false): IngestResult {
        if (body.length > maxBody) return IngestResult.Unparsed
        return ingestMutex.withLock {
            try {
                ingestInner(appContext, body, sender, timestampMs, dao, txnDao, quiet)
            } catch (e: Exception) {
                CaptureEngine.logCrash(appContext, e)
                IngestResult.Unparsed
            }
        }
    }

    private fun logCrash(appContext: android.content.Context, e: Exception) {
        CrashLog.log(appContext, "CaptureEngine", "ingest failed: ${e.message}")
    }

    private suspend fun ingestInner(appContext: android.content.Context, body: String, sender: String, timestampMs: Long, dao: CaptureDao, txnDao: com.kharcha.app.db.KharchaDao, quiet: Boolean): IngestResult {
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
                val merchantName = resolveMerchantName(appContext, payment.merchant)
                val categoryId = categorize(merchantName, txnDao.allRules())
                val lowerBody = body.lowercase()
                val isMandateBody = lowerBody.contains("mandate") || lowerBody.contains("autopay") ||
                        lowerBody.contains("auto-debit") || lowerBody.contains("nach") || lowerBody.contains("standing instruction")
                val initialNote = if (isMandateBody) "Autopay Mandate" else null
                val txnId = txnDao.insert(
                    TransactionRow(
                        amountPaise = payment.amountPaise,
                        merchant = merchantName,
                        categoryId = categoryId,
                        note = initialNote,
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
                if (payment.bankName != null || payment.accountMask != null) {
                    val name = buildString {
                        append(payment.bankName ?: "Wallet")
                        payment.accountMask?.let { append(" (").append(it).append(")") }
                    }
                    val walletId = txnDao.walletByName(name)?.id
                        ?: txnDao.insertWallet(Wallet(name = name))
                    txnDao.assignWallet(txnId, walletId)
                    payment.balancePaise?.let { txnDao.updateWalletBalance(walletId, it) }
                }
                UserPrefs.stampCapture(appContext)
                if (!quiet) CaptureNotify.inserted(appContext, merchantName, payment.amountPaise, null)
                checkBudgetAlerts(appContext, txnDao, categoryId)
                Pairing.maybePair(txnDao, txnId, payment.amountPaise, payment.isIncome, parsed.timestampMs)
                CoroutineScope(Dispatchers.IO).launch {
                    try { com.kharcha.app.widget.KharchaWidget.refresh(appContext) } catch (_: Exception) {}
                }
                IngestResult.Inserted(txnId)
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

    /** Resolves 10-digit Indian phone numbers against Android ContactsContract if permission is granted. */
    fun resolveMerchantName(context: android.content.Context, rawMerchant: String): String {
        if (!rawMerchant.matches(Regex("^[6-9]\\d{9}$"))) return rawMerchant
        if (androidx.core.content.ContextCompat.checkSelfPermission(
                context,
                android.Manifest.permission.READ_CONTACTS
            ) != android.content.pm.PackageManager.PERMISSION_GRANTED
        ) {
            return "UPI User (${rawMerchant.takeLast(4)})"
        }
        return try {
            val uri = android.net.Uri.withAppendedPath(
                android.provider.ContactsContract.PhoneLookup.CONTENT_FILTER_URI,
                android.net.Uri.encode(rawMerchant)
            )
            context.contentResolver.query(
                uri,
                arrayOf(android.provider.ContactsContract.PhoneLookup.DISPLAY_NAME),
                null,
                null,
                null
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    cursor.getString(0)?.takeIf { it.isNotBlank() } ?: "UPI User (${rawMerchant.takeLast(4)})"
                } else {
                    "UPI User (${rawMerchant.takeLast(4)})"
                }
            } ?: "UPI User (${rawMerchant.takeLast(4)})"
        } catch (_: Exception) {
            "UPI User (${rawMerchant.takeLast(4)})"
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

    /**
     * Ingest-time threshold alerts: 50/80/100, upward crossings only.
     * Fired level persists in prefs so each insert doesn't re-buzz.
     */
    private suspend fun checkBudgetAlerts(
        appContext: android.content.Context,
        txnDao: com.kharcha.app.db.KharchaDao,
        categoryId: Long?,
    ) {
        if (categoryId == null) return
        val limit = txnDao.allBudgetsOnce().firstOrNull { it.categoryId == categoryId }?.monthlyLimitPaise ?: return
        if (limit <= 0) return
        val start = java.util.Calendar.getInstance().apply {
            set(java.util.Calendar.DAY_OF_MONTH, 1)
            set(java.util.Calendar.HOUR_OF_DAY, 0)
            set(java.util.Calendar.MINUTE, 0)
            set(java.util.Calendar.SECOND, 0)
            set(java.util.Calendar.MILLISECOND, 0)
        }.timeInMillis
        val spend = txnDao.categorySpend(categoryId, start, System.currentTimeMillis())
        val level = listOf(100, 80, 50).firstOrNull { spend * 100 >= limit * it } ?: return
        if (level <= UserPrefs.budgetAlertLevel(appContext, categoryId)) return
        UserPrefs.setBudgetAlertLevel(appContext, categoryId, level)
        val name = txnDao.allCategoriesOnce().firstOrNull { it.id == categoryId }?.name ?: "Budget"
        val left = limit - spend
        CaptureNotify.alert(
            appContext,
            "$name budget $level%",
            if (left >= 0) "${formatCompact(left)} left this month" else "${formatCompact(-left)} over",
        )
    }

    private fun formatCompact(paise: Long): String {
        val abs = kotlin.math.abs(paise)
        return if (abs % 100 == 0L && abs >= 10_000L) "₹%,d".format(abs / 100) else "₹${abs / 100}.${"%02d".format(abs % 100)}"
    }
}