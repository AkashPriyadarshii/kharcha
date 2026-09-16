package com.kharcha.app.db

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "categories")
data class Category(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val name: String,
    val emoji: String,
    @ColumnInfo(defaultValue = "0") val isIncome: Boolean = false,
    @ColumnInfo(defaultValue = "0") val sort: Int = 0,
)

@Entity(tableName = "rules")
data class RuleRow(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val pattern: String,
    val ruleType: String, // "builtin" | "learned" — learned beats builtin (sorting in Rust)
    val categoryId: Long,
)

@Entity(tableName = "transactions")
data class TransactionRow(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    /** Integer paise — exact, matches kharcha-core. */
    val amountPaise: Long,
    val merchant: String,
    val categoryId: Long? = null,
    val note: String? = null,
    val upiRef: String? = null,
    val bankName: String? = null,
    val accountMask: String? = null,
    @ColumnInfo(defaultValue = "0") val needsReview: Boolean = false,
    @ColumnInfo(defaultValue = "0") val isIncome: Boolean = false,
    /** Wallet/capture timestamp, epoch millis. */
    val timestampMs: Long,
    /** FNV-1a64 dedupe key from kharcha-core (bit-identical bits in Long). */
    val contentHash: Long? = null,
    val sender: String? = null,
    /** Set when a bank/card wallet is identified from the message. */
    val walletId: Long? = null,
)

@Entity(tableName = "wallets")
data class Wallet(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val name: String,
    /** Last known balance from bank SMS, paise. Null until first seen. */
    val balancePaise: Long? = null,
    @ColumnInfo(defaultValue = "0") val isIncomeWallet: Boolean = false,
)

@Entity(tableName = "budgets")
data class Budget(
    @PrimaryKey val categoryId: Long,
    /** Monthly cap, paise. */
    val monthlyLimitPaise: Long,
)