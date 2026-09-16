package com.kharcha.app.db

import androidx.room.Dao
import androidx.room.Database
import androidx.room.Query
import androidx.room.Insert
import androidx.room.Update
import androidx.room.Delete
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase
import com.kharcha.app.capture.CaptureDao
import android.content.Context
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.launch

@Dao
interface KharchaDao {
    @Insert suspend fun insert(txn: TransactionRow): Long
    @Update suspend fun update(txn: TransactionRow)
    @Delete suspend fun delete(txn: TransactionRow)
    @Query("DELETE FROM transactions WHERE id = :id")
    suspend fun deleteById(id: Long)

    /** Soft delete: hide, restorable from Trash. Hard purge only via purgeTrash. */
    @Query("UPDATE transactions SET isDeleted = 1 WHERE id = :id")
    suspend fun trashById(id: Long)

    @Query("UPDATE transactions SET isDeleted = 0 WHERE id = :id")
    suspend fun restoreById(id: Long)

    @Query("DELETE FROM transactions WHERE isDeleted = 1")
    suspend fun purgeTrash()

    @Query("SELECT * FROM transactions WHERE isDeleted = 1 ORDER BY timestampMs DESC")
    fun trashed(): Flow<List<TransactionRow>>

    @Query("SELECT * FROM transactions WHERE id = :id LIMIT 1")
    suspend fun transactionById(id: Long): TransactionRow?

    @Query("SELECT * FROM transactions WHERE isDeleted = 0 ORDER BY timestampMs DESC")
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

    /** Recency-ordered rows for the dedupe gate. Bounded: full-table read per SMS was an ANR. */
    /** Recency-ordered rows for the dedupe gate (mirrors Dart limit(1) contract).
     * LIMIT 200 (audit): a full-table scan × JNA serialize per SMS = ANR inside
     * goAsync; 200 recency-ordered rows covers the ±5 min window with margin. */
    @Query("SELECT * FROM transactions WHERE isDeleted = 0 ORDER BY timestampMs DESC LIMIT 200")
    suspend fun recentTransactions(): List<TransactionRow>

    @Query("SELECT COALESCE(SUM(amountPaise), 0) FROM transactions WHERE isDeleted = 0 AND isIncome = 0 AND timestampMs >= :fromMs AND timestampMs < :toMs")
    suspend fun spendBetween(fromMs: Long, toMs: Long): Long

    @Query("SELECT COALESCE(SUM(amountPaise), 0) FROM transactions WHERE isDeleted = 0 AND isIncome = 1 AND timestampMs >= :fromMs AND timestampMs < :toMs")
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

    @Query("SELECT COALESCE(SUM(amountPaise), 0) FROM transactions WHERE isDeleted = 0 AND isIncome = 0 AND categoryId = :categoryId AND timestampMs >= :fromMs AND timestampMs < :toMs")
    suspend fun categorySpend(categoryId: Long, fromMs: Long, toMs: Long): Long

    @Query("DELETE FROM budgets WHERE categoryId = :categoryId")
    suspend fun deleteBudget(categoryId: Long)

    // --- Goals ---
    @Insert(onConflict = androidx.room.OnConflictStrategy.REPLACE) suspend fun upsertGoal(goal: Goal)

    @Query("SELECT * FROM goals")
    fun allGoals(): kotlinx.coroutines.flow.Flow<List<Goal>>

    @Query("UPDATE goals SET savedPaise = savedPaise + :amount WHERE id = :id")
    suspend fun addSaving(id: Long, amount: Long)
}

@Database(
    entities = [TransactionRow::class, Category::class, RuleRow::class, Wallet::class, Budget::class, Goal::class],
    version = 5,
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

        private val MIGRATION_2_3 = object : Migration(2, 3) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL("ALTER TABLE transactions ADD COLUMN paymentMethod TEXT")
            }
        }

        // Rebasing: budget-pack owns 3→4 (goals). This is 4→5.
        private val MIGRATION_4_5 = object : Migration(4, 5) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL("ALTER TABLE transactions ADD COLUMN isDeleted INTEGER NOT NULL DEFAULT 0")
            }
        }

        /** Throttled VACUUM (30d): single-user DB fragments slowly; no scheduler yet, on-open check is enough. */
        private fun vacuumIfDue(context: Context, db: SupportSQLiteDatabase) {
            CoroutineScope(Dispatchers.IO).launch {
                try {
                    val p = context.getSharedPreferences("maintenance", Context.MODE_PRIVATE)
                    val now = System.currentTimeMillis()
                    if (now - p.getLong("last_vacuum_ms", 0) > 30L * 24 * 60 * 60 * 1000) {
                        db.execSQL("VACUUM")
                        p.edit().putLong("last_vacuum_ms", now).apply()
                    }
                } catch (e: Exception) {
                    com.kharcha.app.capture.CrashLog.log(context, "Maintenance", "vacuum failed: ${e.message}")
                }
        private val MIGRATION_3_4 = object : Migration(3, 4) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL("CREATE TABLE IF NOT EXISTS goals (id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, name TEXT NOT NULL, targetPaise INTEGER NOT NULL, savedPaise INTEGER NOT NULL DEFAULT 0)")
            }
        }

        fun create(context: Context): AppDatabase =
            Room.databaseBuilder(context, AppDatabase::class.java, "kharcha.db")
                .addMigrations(MIGRATION_1_2, MIGRATION_2_3, MIGRATION_3_4, MIGRATION_4_5)
                .addCallback(SeedCallback())
                .addCallback(object : RoomDatabase.Callback() {
                    override fun onOpen(db: SupportSQLiteDatabase) {
                        super.onOpen(db)
                        vacuumIfDue(context, db)
                    }
                })
                .build()
    }
}