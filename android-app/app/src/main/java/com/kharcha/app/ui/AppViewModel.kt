package com.kharcha.app.ui

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.kharcha.app.KharchaApp
import com.kharcha.app.db.Budget
import com.kharcha.app.db.RuleRow
import com.kharcha.app.db.TransactionRow
import com.kharcha.app.db.Wallet
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.time.YearMonth
import java.time.ZoneId

data class MonthTotals(val spend: Long, val income: Long)

/** First/last millis of [month] in device timezone. End is exclusive. */
fun monthRange(month: YearMonth, zone: ZoneId = ZoneId.systemDefault()): Pair<Long, Long> {
    val start = month.atDay(1).atStartOfDay(zone).toInstant().toEpochMilli()
    val end = month.plusMonths(1).atDay(1).atStartOfDay(zone).toInstant().toEpochMilli()
    return start to end
}

class AppViewModel(app: Application) : AndroidViewModel(app) {
    private val db = (app as KharchaApp).database
    val dao get() = db.dao()

    val transactions: StateFlow<List<TransactionRow>> =
        dao.allTransactions()
            .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    val wallets: StateFlow<List<Wallet>> =
        dao.allWallets().stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    val budgets: StateFlow<List<Budget>> =
        dao.allBudgets().stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    /** True after the first DB emission — lets UI tell loading apart from empty. */
    val dataLoaded: MutableStateFlow<Boolean> = MutableStateFlow(false)

    init {
        viewModelScope.launch {
            dao.allTransactions().collect { dataLoaded.value = true }
        }
    }

    /** Visible month for hero + budgets. Defaults to current month. */
    val selectedMonth: MutableStateFlow<YearMonth> = MutableStateFlow(YearMonth.now())

    fun shiftMonth(delta: Long) {
        selectedMonth.value = selectedMonth.value.plusMonths(delta)
        refreshTotals()
        refreshBudgetSpends()
    }

    /** Category spend this month, for budget progress. */
    val budgetSpends: MutableStateFlow<Map<Long, Long>> = MutableStateFlow(emptyMap())

    fun refreshBudgetSpends() {
        val month = selectedMonth.value
        viewModelScope.launch {
            val (start, end) = monthRange(month)
            val map = mutableMapOf<Long, Long>()
            for (b in budgets.value) {
                map[b.categoryId] = dao.categorySpend(b.categoryId, start, end)
            }
            budgetSpends.value = map
        }
    }

    /** Selected-month spend/income. */
    val totals: MutableStateFlow<MonthTotals> = MutableStateFlow(MonthTotals(0, 0))

    fun refreshTotals() {
        val month = selectedMonth.value
        viewModelScope.launch {
            val (start, end) = monthRange(month)
            totals.value = MonthTotals(
                spend = dao.spendBetween(start, end),
                income = dao.incomeBetween(start, end),
            )
        }
    }

    fun refreshAll() {
        refreshTotals()
        refreshBudgetSpends()
    }

    suspend fun saveTransaction(txn: TransactionRow): Long {
        val id = dao.insert(txn)
        refreshAll()
        return id
    }

    suspend fun setBudget(categoryId: Long, limitPaise: Long) {
        dao.upsertBudget(Budget(categoryId, limitPaise))
        refreshBudgetSpends()
    }

    suspend fun removeBudget(categoryId: Long) = dao.deleteBudget(categoryId)

    suspend fun updateTransaction(txn: TransactionRow, teachRule: Boolean) {
        dao.update(txn)
        if (teachRule && txn.categoryId != null && txn.merchant.isNotBlank()) {
            // Dedupe learned rules: re-teaching the same merchant must not append rows forever.
            val existing = dao.allRules().any {
                it.categoryId == txn.categoryId && it.pattern.equals(txn.merchant, ignoreCase = true)
            }
            if (!existing) {
                dao.insertRule(RuleRow(pattern = txn.merchant, ruleType = "learned", categoryId = txn.categoryId))
            }
        }
        refreshAll()
    }

    /** Last deleted row for Snackbar undo. Cleared on restore or next delete. */
    var lastDeleted: TransactionRow? = null
        private set

    suspend fun deleteTransaction(id: Long): TransactionRow? {
        val row = dao.transactionById(id)
        dao.deleteById(id)
        lastDeleted = row
        refreshAll()
        return row
    }

    suspend fun restoreLastDeleted(): Long? {
        val row = lastDeleted ?: return null
        lastDeleted = null
        val id = dao.insert(row.copy(id = 0))
        refreshAll()
        return id
    }

    fun clearUndo() {
        lastDeleted = null
    }
}
