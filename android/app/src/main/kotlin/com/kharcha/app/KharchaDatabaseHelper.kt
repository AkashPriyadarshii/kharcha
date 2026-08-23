package com.kharcha.app

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.content.ContentValues
import android.util.Log
import java.io.File
import com.pennywiseai.parser.core.ParsedTransaction
import java.util.Date

data class CategoryResult(val id: Int, val name: String, val emoji: String?)
data class InsertResult(val transactionId: Long, val category: CategoryResult?, val isDuplicate: Boolean)

class KharchaDatabaseHelper(private val context: Context) {
    private val dbPath: String
        get() = File(context.getDir("flutter", Context.MODE_PRIVATE).parentFile, "app_flutter/kharcha.sqlite").absolutePath

    private fun getDb(): SQLiteDatabase {
        return SQLiteDatabase.openDatabase(dbPath, null, SQLiteDatabase.OPEN_READWRITE)
    }

    private fun normalizeMerchant(merchant: String): String {
        return merchant.lowercase().replace(Regex("[^a-z0-9]+"), " ").trim()
    }

    fun insertTransaction(txn: ParsedTransaction, seenAt: Long): InsertResult? {
        var db: SQLiteDatabase? = null
        try {
            db = getDb()
            
            // 1. Dedupe check
            val windowBefore = (seenAt / 1000) - 300 // 5 mins
            val windowAfter = (seenAt / 1000) + 300
            val isIncomeInt = if (txn.type.name == "INCOME" || txn.type.name == "REFUND") 1 else 0
            
            val cursor = db.rawQuery(
                "SELECT id, upi_ref FROM transactions WHERE amount = ? AND is_income = ? AND txn_date BETWEEN ? AND ? AND is_deleted = 0 LIMIT 1",
                arrayOf(txn.amount.toDouble().toString(), isIncomeInt.toString(), windowBefore.toString(), windowAfter.toString())
            )
            
            if (cursor.moveToFirst()) {
                val existingId = cursor.getLong(0)
                val existingRef = cursor.getString(1)
                cursor.close()
                
                val hasDistinctRefs = txn.reference != null && txn.reference!!.isNotEmpty() &&
                    existingRef != null && existingRef.isNotEmpty() &&
                    txn.reference != existingRef
                    
                if (!hasDistinctRefs) {
                    return InsertResult(existingId, null, true)
                }
            } else {
                cursor.close()
            }
            
            // 2. Find Category
            var categoryId: Int? = null
            var categoryName: String? = null
            var categoryEmoji: String? = null
            
            if (isIncomeInt == 1) {
                val cCursor = db.rawQuery("SELECT id, name, emoji FROM categories WHERE name = 'Other income' LIMIT 1", null)
                if (cCursor.moveToFirst()) {
                    categoryId = cCursor.getInt(0)
                    categoryName = cCursor.getString(1)
                    categoryEmoji = cCursor.getString(2)
                }
                cCursor.close()
            } else {
                val normalized = normalizeMerchant(txn.merchant ?: "")
                val rCursor = db.rawQuery("SELECT pattern, category_id, emoji, type FROM rules", null)
                var bestRuleLen = -1
                var bestRuleType = ""
                
                while (rCursor.moveToNext()) {
                    val pattern = normalizeMerchant(rCursor.getString(0))
                    val cid = rCursor.getInt(1)
                    val emoji = rCursor.getString(2)
                    val type = rCursor.getString(3)
                    
                    if (pattern.isNotEmpty() && Regex("\\\\b\\\\\b").containsMatchIn(normalized)) {
                        val isLearned = type == "learned"
                        val currentIsLearned = bestRuleType == "learned"
                        
                        if (categoryId == null || (isLearned && !currentIsLearned) || (isLearned == currentIsLearned && pattern.length > bestRuleLen)) {
                            categoryId = cid
                            categoryEmoji = emoji
                            bestRuleLen = pattern.length
                            bestRuleType = type
                        }
                    }
                }
                rCursor.close()
                
                if (categoryId != null) {
                    val cCursor = db.rawQuery("SELECT name FROM categories WHERE id = ?", arrayOf(categoryId.toString()))
                    if (cCursor.moveToFirst()) {
                        categoryName = cCursor.getString(0)
                    }
                    cCursor.close()
                }
            }
            
            // 3. Find/Create Wallet
            var walletId: Int? = null
            if (txn.accountLast4 != null && txn.accountLast4!!.isNotEmpty()) {
                val wCursor = db.rawQuery("SELECT id, account_mask FROM wallets", null)
                while (wCursor.moveToNext()) {
                    val mask = wCursor.getString(1)
                    if (mask != null && mask.isNotEmpty() && txn.accountLast4!!.contains(mask)) {
                        walletId = wCursor.getInt(0)
                        break
                    }
                }
                wCursor.close()
                
                if (walletId == null) {
                    val newName = if (txn.bankName != null) "${txn.bankName} (${txn.accountLast4})" else "Account (${txn.accountLast4})"
                    val wValues = ContentValues().apply {
                        put("name", newName)
                        put("currency", "INR")
                        put("account_mask", txn.accountLast4)
                        put("bank_name", txn.bankName)
                        put("dirty", 1)
                        put("created_at", (System.currentTimeMillis() / 1000).toString())
                        put("updated_at", (System.currentTimeMillis() / 1000).toString())
                    }
                    walletId = db.insert("wallets", null, wValues).toInt()
                }
            } else {
                val wCursor = db.rawQuery("SELECT id FROM wallets LIMIT 1", null)
                if (wCursor.moveToFirst()) {
                    walletId = wCursor.getInt(0)
                }
                wCursor.close()
            }
            
            // 4. Insert Transaction
            val values = ContentValues().apply {
                put("amount", txn.amount.toDouble())
                put("merchant", txn.merchant?.trim() ?: "Unknown")
                put("category_id", categoryId)
                put("wallet_id", walletId)
                put("payment_method", "upi")
                put("upi_ref", txn.reference?.trim())
                put("source", "notification")
                put("txn_date", seenAt / 1000)
                put("is_income", isIncomeInt)
                put("emoji", categoryEmoji)
                put("account_mask", txn.accountLast4)
                put("needs_review", 0)
                put("dirty", 1)
                put("created_at", (System.currentTimeMillis() / 1000).toString())
                put("updated_at", (System.currentTimeMillis() / 1000).toString())
            }
            
            val id = db.insert("transactions", null, values)
            
            var catResult: CategoryResult? = null
            if (categoryId != null && categoryName != null) {
                catResult = CategoryResult(categoryId, categoryName, categoryEmoji)
            }
            return InsertResult(id, catResult, false)
            
        } catch (e: Exception) {
            Log.e("KharchaDB", "Error inserting into Kharcha SQLite", e)
            return null
        } finally {
            db?.close()
        }
    }
}
