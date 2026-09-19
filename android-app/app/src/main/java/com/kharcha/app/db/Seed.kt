package com.kharcha.app.db

import androidx.room.RoomDatabase
import androidx.sqlite.db.SupportSQLiteDatabase
import com.kharcha.app.capture.CrashLog
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/**
 * Seeds categories (FIXED ids — rules reference them) + builtin rules.
 * Deterministic ids from day one: no auto-increment, no lookup dance.
 */
private val SEED_CATEGORIES = listOf(
    1L to Pair("Food", "🍔"), 2L to Pair("Groceries", "🛒"), 3L to Pair("Transport", "🚕"), 4L to Pair("Shopping", "🛍️"),
    5L to Pair("Bills", "🧾"), 6L to Pair("Entertainment", "🎬"), 7L to Pair("Healthcare", "💊"), 8L to Pair("Travel", "✈️"),
    9L to Pair("Education", "📚"), 10L to Pair("Gift", "🎁"), 11L to Pair("Business", "💼"), 12L to Pair("Other", "⋯"),
)

// (pattern, categoryId) — merchant roots, ported from the Dart seed set.
private val SEED_RULES = listOf(
    "swiggy" to 1L, "zomato" to 1L, "dominos" to 1L, "kfc" to 1L, "mcdonald" to 1L,
    "pizza hut" to 1L, "burger king" to 1L, "chaayos" to 1L, "barbeque" to 1L,
    "bigbasket" to 2L, "blinkit" to 2L, "zepto" to 2L, "instamart" to 2L,
    "dmart" to 2L, "more" to 2L, "reliance fresh" to 2L, "jiomart" to 2L,
    "uber" to 3L, "ola" to 3L, "rapido" to 3L, "irctc" to 8L, "redbus" to 8L,
    "makemytrip" to 8L, "goibibo" to 8L, "air india" to 8L, "indigo" to 8L,
    "amazon" to 4L, "flipkart" to 4L, "myntra" to 4L, "meesho" to 4L,
    "ajio" to 4L, "nykaa" to 4L, "reliance" to 5L, "jio" to 5L, "airtel" to 5L,
    "vodafone" to 5L, "bsnl" to 5L, "tata power" to 5L, "adani electricity" to 5L,
    "pvr" to 6L, "inox" to 6L, "bookmyshow" to 6L, "netflix" to 6L,
    "apollo pharmacy" to 7L, "1mg" to 7L, "pharmeasy" to 7L, "netmeds" to 7L, "medplus" to 7L, "practo" to 7L, "tata 1mg" to 7L,
    "dr lal pathlabs" to 7L, "thyrocare" to 7L, "metropolis labs" to 7L,
    "starbucks" to 1L, "subway" to 1L, "haldiram" to 1L, "chai point" to 1L, "eatclub" to 1L,
    "faasos" to 1L, "behrouz biryani" to 1L, "ovenstory" to 1L, "freshmenu" to 1L, "box8" to 1L,
    "nature basket" to 2L, "milkbasket" to 2L, "country delight" to 2L, "dunzo" to 2L,
    "licious" to 2L, "fresh to home" to 2L, "otipy" to 2L,
    "namma yatri" to 3L, "blusmart" to 3L, "yulu" to 3L, "fastag" to 3L, "zoomcar" to 3L,
    "zudio" to 4L, "decathlon" to 4L, "croma" to 4L, "vijay sales" to 4L, "tata cliq" to 4L, "zara" to 4L,
    "h&m" to 4L, "uniqlo" to 4L, "lifestyle" to 4L, "ikea" to 4L, "westside" to 4L, "reliance digital" to 4L,
    "bescom" to 5L, "mahadiscom" to 5L, "mgl" to 5L,
    "indane gas" to 5L, "bharat gas" to 5L, "act broadband" to 5L, "excitel" to 5L, "tatasky" to 5L,
    "spotify" to 6L, "hotstar" to 6L, "sony liv" to 6L,
    "zee5" to 6L, "prime video" to 6L, "youtube premium" to 6L, "jiosaavn" to 6L,
    "cleartrip" to 8L, "easemytrip" to 8L, "akasa air" to 8L,
    "spicejet" to 8L, "oyo" to 8L, "yatra" to 8L,
    "coursera" to 9L, "udemy" to 9L, "unacademy" to 9L, "physicswallah" to 9L,
    "byjus" to 9L, "vedantu" to 9L, "aakash institute" to 9L,
    "ferns n petals" to 10L,
    "petrol" to 3L, "indian oil" to 3L, "hp petrol" to 3L, "bharat petroleum" to 3L,
    "shell fuel" to 3L, "metro parking" to 3L,
    "salary" to 10L, "upi" to 12L,
    "amzn" to 4L, "phonepe" to 12L, "tatapower" to 5L, "paytm" to 12L,
)

class SeedCallback : RoomDatabase.Callback() {
    override fun onCreate(db: SupportSQLiteDatabase) {
        super.onCreate(db)
        db.beginTransaction()
        try {
            SEED_CATEGORIES.forEach { (id, pair) ->
                db.execSQL("INSERT INTO categories (id, name, emoji, isIncome, sort) VALUES (?, ?, ?, 0, ?)", arrayOf<Any>(id, pair.first, pair.second, id))
            }
            db.execSQL("INSERT INTO categories (id, name, emoji, isIncome, sort) VALUES (100, 'Income', '↑', 1, 0)")
            SEED_RULES.forEach { (pattern, categoryId) ->
                db.execSQL("INSERT INTO rules (pattern, ruleType, categoryId) VALUES (?, 'builtin', ?)", arrayOf<Any>(pattern, categoryId))
            }
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
    }

    override fun onOpen(db: SupportSQLiteDatabase) {
        super.onOpen(db)
        // ponytail: sync newly added builtin rules into existing DBs on open without schema migrations.
        // Must run on Dispatchers.IO with try-catch so it never blocks main thread or crashes Room initialization.
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val existing = mutableSetOf<String>()
                db.query("SELECT pattern FROM rules").use { cursor ->
                    while (cursor.moveToNext()) existing.add(cursor.getString(0))
                }
                db.beginTransaction()
                try {
                    SEED_RULES.forEach { (pattern, categoryId) ->
                        if (pattern !in existing) {
                            db.execSQL(
                                "INSERT INTO rules (pattern, ruleType, categoryId) VALUES (?, 'builtin', ?)",
                                arrayOf<Any>(pattern, categoryId)
                            )
                        }
                    }
                    db.setTransactionSuccessful()
                } finally {
                    db.endTransaction()
                }
            } catch (e: Exception) {
                CrashLog.log("SeedCallback", "rule sync on open failed: ${e.message}")
            }
        }
    }
}