package com.kharcha.app.db

import androidx.room.Dao
import androidx.room.Database
import androidx.room.Query
import androidx.room.Insert
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase
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

    // --- Wallets ---
    @Insert suspend fun insertWallet(wallet: Wallet): Long

    @Query("SELECT * FROM wallets ORDER BY name")
    fun allWallets(): Flow<List<Wallet>>

    @Query("SELECT * FROM wallets WHERE name = :name LIMIT 1")
    suspend fun walletByName(name: String): Wallet?

    @Query("UPDATE wallets SET balancePaise = :balance WHERE id = :id")
    suspend fun updateWalletBalance(id: Long, balance: Long)

    @Query("UPDATE transactions SET walletId = :walletId WHERE id = :txnId")
    suspend fun assignWallet(txnId: Long, walletId: Long)

    // --- Budgets ---
    @Insert(onConflict = androidx.room.OnConflictStrategy.REPLACE) suspend fun upsertBudget(budget: Budget)

    @Query("SELECT * FROM budgets")
    fun allBudgets(): Flow<List<Budget>>

    @Query("SELECT COALESCE(SUM(amountPaise), 0) FROM transactions WHERE isIncome = 0 AND categoryId = :categoryId AND timestampMs >= :fromMs AND timestampMs < :toMs")
    suspend fun categorySpend(categoryId: Long, fromMs: Long, toMs: Long): Long

    @Query("DELETE FROM budgets WHERE categoryId = :categoryId")
    suspend fun deleteBudget(categoryId: Long)
}

@Database(
    entities = [TransactionRow::class, Category::class, RuleRow::class, Wallet::class, Budget::class],
    version = 2,
    exportSchema = false,
)
abstract class AppDatabase : RoomDatabase() {
    abstract fun dao(): KharchaDao
    abstract fun captureDao(): CaptureDao

    companion object {
        private val MIGRATION_1_2 = object : Migration(1, 2) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL("CREATE TABLE IF NOT EXISTS wallets (id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, name TEXT NOT NULL, balancePaise INTEGER, isIncomeWallet INTEGER NOT NULL DEFAULT 0)")
                db.execSQL("CREATE TABLE IF NOT EXISTS budgets (categoryId INTEGER NOT NULL PRIMARY KEY, monthlyLimitPaise INTEGER NOT NULL)")
                db.execSQL("ALTER TABLE transactions ADD COLUMN walletId INTEGER")
            }
        }

        fun create(context: Context): AppDatabase =
            Room.databaseBuilder(context, AppDatabase::class.java, "kharcha.db")
                .addMigrations(MIGRATION_1_2)
                .addCallback(SeedCallback())
                .build()
    }
}