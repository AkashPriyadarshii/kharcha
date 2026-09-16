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
import kotlinx.coroutines.flow.Flow

@Dao
interface KharchaDao {
    @Insert suspend fun insert(txn: TransactionRow): Long
    @Update suspend fun update(txn: TransactionRow)
    @Delete suspend fun delete(txn: TransactionRow)
    @Query("DELETE FROM transactions WHERE id = :id")
    suspend fun deleteById(id: Long)

    @Query("SELECT * FROM transactions WHERE id = :id LIMIT 1")
    suspend fun transactionById(id: Long): TransactionRow?

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

    /** Recency-ordered rows for the dedupe gate. Bounded: full-table read per SMS was an ANR. */
    /** Recency-ordered rows for the dedupe gate (mirrors Dart limit(1) contract).
     * LIMIT 200 (audit): a full-table scan × JNA serialize per SMS = ANR inside
     * goAsync; 200 recency-ordered rows covers the ±5 min window with margin. */
    @Query("SELECT * FROM transactions ORDER BY timestampMs DESC LIMIT 200")
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

    @Query("SELECT * FROM budgets")
    suspend fun allBudgetsOnce(): List<Budget>

    @Query("SELECT COALESCE(SUM(amountPaise), 0) FROM transactions WHERE isIncome = 0 AND categoryId = :categoryId AND timestampMs >= :fromMs AND timestampMs < :toMs")
    suspend fun categorySpend(categoryId: Long, fromMs: Long, toMs: Long): Long

    @Query("DELETE FROM budgets WHERE categoryId = :categoryId")
    suspend fun deleteBudget(categoryId: Long)

    // --- Managers ---
    @Query("DELETE FROM rules WHERE id = :id")
    suspend fun deleteRule(id: Long)

    @Update suspend fun updateCategory(category: Category)

    @Query("UPDATE categories SET isHidden = :hidden WHERE id = :id")
    suspend fun setCategoryHidden(id: Long, hidden: Boolean)

    @Query("UPDATE wallets SET name = :name WHERE id = :id")
    suspend fun renameWallet(id: Long, name: String)

    @Query("UPDATE wallets SET isArchived = :archived WHERE id = :id")
    suspend fun setWalletArchived(id: Long, archived: Boolean)

    @Insert suspend fun insertCategory(category: Category): Long

    /** Counterpart for transfer/refund pairing: same amount, opposite sign, 7-day window, unpaired. */
    @Query(
        """SELECT * FROM transactions
           WHERE amountPaise = :amountPaise AND isIncome != :isIncome AND id != :excludeId
             AND timestampMs BETWEEN :fromMs AND :toMs AND (note IS NULL OR note NOT LIKE 'Paired%')
           ORDER BY ABS(timestampMs - :ts) LIMIT 1"""
    )
    suspend fun pairCandidate(amountPaise: Long, isIncome: Boolean, excludeId: Long, fromMs: Long, toMs: Long, ts: Long): TransactionRow?

    /** Recurring suspects: same merchant + amount in 2+ distinct months. */
    @Query(
        """SELECT merchant AS merchant, amountPaise AS amountPaise,
             COUNT(DISTINCT strftime('%Y-%m', datetime(timestampMs / 1000, 'unixepoch'))) AS months
           FROM transactions WHERE isIncome = 0
           GROUP BY merchant, amountPaise HAVING months >= 2 ORDER BY amountPaise DESC"""
    )
    fun subscriptions(): Flow<List<SubRow>>

    @Query("DELETE FROM transactions")
    suspend fun wipeTransactions()
}

@Database(
    entities = [TransactionRow::class, Category::class, RuleRow::class, Wallet::class, Budget::class],
    version = 4,
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

        // NOTE: third claimant on 3→4 (also budget-pack goals, db-safety
        // isDeleted). Whoever merges second rebases to 4→5, third to 5→6.
        private val MIGRATION_3_4 = object : Migration(3, 4) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL("ALTER TABLE categories ADD COLUMN isHidden INTEGER NOT NULL DEFAULT 0")
                db.execSQL("ALTER TABLE wallets ADD COLUMN isArchived INTEGER NOT NULL DEFAULT 0")
            }
        }

        fun create(context: Context): AppDatabase =
            Room.databaseBuilder(context, AppDatabase::class.java, "kharcha.db")
                .addMigrations(MIGRATION_1_2, MIGRATION_2_3, MIGRATION_3_4)
                .addCallback(SeedCallback())
                .build()
    }
}