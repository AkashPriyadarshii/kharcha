package com.kharcha.app.capture

import androidx.room.Dao
import androidx.room.Query
import androidx.room.Update
import com.kharcha.app.db.TransactionRow

/** Dedupe + backfill helpers used by the capture engine. */
@Dao
interface CaptureDao {
    @Query("UPDATE transactions SET upiRef = :ref WHERE id = :id")
    suspend fun updateRef(id: Long, ref: String)

    @Query(
        """SELECT * FROM transactions
           WHERE isDeleted = 0 AND amountPaise = :amountPaise AND isIncome = :isIncome
             AND timestampMs BETWEEN :fromMs AND :toMs
           ORDER BY timestampMs DESC LIMIT 1"""
    )
    suspend fun backfillTarget(amountPaise: Long, isIncome: Boolean, fromMs: Long, toMs: Long): TransactionRow?
}