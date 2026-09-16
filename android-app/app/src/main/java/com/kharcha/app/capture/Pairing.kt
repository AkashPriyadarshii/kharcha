package com.kharcha.app.capture

import com.kharcha.app.db.TransactionRow

/**
 * Transfer pairing + refund matching, app-side (no new FFI: the committed
 * .so can't grow exports without an NDK rebuild). Links live in the note
 * column under a Transfers category, so zero migration.
 */
object Pairing {
    private const val WINDOW_MS = 7L * 24 * 60 * 60 * 1000
    const val TRANSFERS = "Transfers"

    /** After any insert: link an opposite-sign same-amount row inside 7 days. */
    suspend fun maybePair(
        txnDao: com.kharcha.app.db.KharchaDao,
        txnId: Long,
        amountPaise: Long,
        isIncome: Boolean,
        timestampMs: Long,
    ) {
        val row = txnDao.transactionById(txnId) ?: return
        if (row.note?.startsWith("Paired") == true) return
        val other = txnDao.pairCandidate(
            amountPaise, isIncome, txnId,
            timestampMs - WINDOW_MS, timestampMs + WINDOW_MS, timestampMs,
        ) ?: return
        link(txnDao, row, other)
    }

    /** Manual link of two explicit rows (bulk action). */
    suspend fun linkIds(txnDao: com.kharcha.app.db.KharchaDao, aId: Long, bId: Long): Boolean {
        val a = txnDao.transactionById(aId) ?: return false
        val b = txnDao.transactionById(bId) ?: return false
        link(txnDao, a, b)
        return true
    }

    private suspend fun link(
        txnDao: com.kharcha.app.db.KharchaDao,
        a: TransactionRow,
        b: TransactionRow,
    ) {
        // Incoming money against an earlier debit reads as a refund; else a transfer.
        val kind = if (a.isIncome) "Refund" else "Transfer"
        val catId = transfersId(txnDao)
        txnDao.update(a.copy(note = "Paired $kind of #${b.id}", categoryId = catId))
        txnDao.update(b.copy(note = "Paired $kind of #${a.id}", categoryId = catId))
    }

    private suspend fun transfersId(txnDao: com.kharcha.app.db.KharchaDao): Long? {
        txnDao.categoryIdByName(TRANSFERS)?.let { return it }
        return runCatching {
            txnDao.insertCategory(com.kharcha.app.db.Category(name = TRANSFERS, emoji = "⇄", sort = 99))
        }.getOrNull()
    }
}
