package com.kharcha.app.db

import androidx.room.Dao
import androidx.room.Database
import androidx.room.Query
import androidx.room.Insert
import androidx.room.Room
import androidx.room.RoomDatabase
import com.kharcha.app.capture.CaptureDao
import android.content.Context
import kotlinx.coroutines.flow.Flow

@Dao
interface KharchaDao {
    @Insert suspend fun insert(txn: TransactionRow): Long

    @Query("SELECT * FROM transactions ORDER BY timestampMs DESC")
    fun allTransactions(): Flow<List<TransactionRow>>

    @Query("SELECT * FROM categories ORDER BY sort ASC, name ASC")
    fun allCategories(): Flow<List<Category>>

    @Query("SELECT * FROM categories ORDER BY sort ASC, name ASC")
    suspend fun allCategoriesOnce(): List<Category>

    @Query("SELECT * FROM rules")
    suspend fun allRules(): List<RuleRow>

    @Query("SELECT * FROM rules ORDER BY id")
    fun allRulesFlow(): Flow<List<RuleRow>>

    @Insert suspend fun insertRule(rule: RuleRow)

    @Query("SELECT id FROM categories WHERE name = :name LIMIT 1")
    suspend fun categoryIdByName(name: String): Long?

    /** Recency-ordered rows for the dedupe gate (mirrors Dart limit(1) contract). */
    @Query("SELECT * FROM transactions ORDER BY timestampMs DESC")
    suspend fun recentTransactions(): List<TransactionRow>

    @Query("SELECT COALESCE(SUM(amountPaise), 0) FROM transactions WHERE isIncome = 0 AND timestampMs >= :fromMs AND timestampMs < :toMs")
    suspend fun spendBetween(fromMs: Long, toMs: Long): Long

    @Query("SELECT COALESCE(SUM(amountPaise), 0) FROM transactions WHERE isIncome = 1 AND timestampMs >= :fromMs AND timestampMs < :toMs")
    suspend fun incomeBetween(fromMs: Long, toMs: Long): Long
}

@Database(
    entities = [TransactionRow::class, Category::class, RuleRow::class],
    version = 1,
    exportSchema = false,
)
abstract class AppDatabase : RoomDatabase() {
    abstract fun dao(): KharchaDao
    abstract fun captureDao(): CaptureDao

    companion object {
        fun create(context: Context): AppDatabase =
            Room.databaseBuilder(context, AppDatabase::class.java, "kharcha.db")
                .addCallback(SeedCallback())
                .build()
    }
}