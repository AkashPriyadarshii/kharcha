package com.kharcha.app.ui

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.kharcha.app.KharchaApp
import com.kharcha.app.db.Budget
import com.kharcha.app.db.Goal
import com.kharcha.app.db.OVERALL_BUDGET_ID
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
            dao.allTransactions().collect {
                dataLoaded.value = true
                refreshTotals()
                refreshBudgetSpends()
            }
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

    /**
     * Unspent carried from last month, per budget. One-month carry only,
     * overspend never carries.
     * ponytail: read-time calc, no migration; compounding later if asked.
     */
    val budgetCarry: MutableStateFlow<Map<Long, Long>> = MutableStateFlow(emptyMap())

    fun refreshBudgetSpends() {
        val month = selectedMonth.value
        viewModelScope.launch {
            val (start, end) = monthRange(month)
            val (pStart, pEnd) = monthRange(month.minusMonths(1))
            val map = mutableMapOf<Long, Long>()
            val carry = mutableMapOf<Long, Long>()
            for (b in budgets.value) {
                val spend = if (b.categoryId == OVERALL_BUDGET_ID) dao.spendBetween(start, end)
                else dao.categorySpend(b.categoryId, start, end)
                map[b.categoryId] = spend
                val prev = if (b.categoryId == OVERALL_BUDGET_ID) dao.spendBetween(pStart, pEnd)
                else dao.categorySpend(b.categoryId, pStart, pEnd)
                carry[b.categoryId] = maxOf(0L, b.monthlyLimitPaise - prev)
            }
            budgetSpends.value = map
            budgetCarry.value = carry
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

    val rules: StateFlow<List<RuleRow>> =
        dao.allRulesFlow().stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    suspend fun deleteRule(id: Long) {
        dao.deleteRule(id)
    }

    suspend fun renameCategory(category: com.kharcha.app.db.Category, name: String, emoji: String) {
        dao.updateCategory(category.copy(name = name, emoji = emoji))
    }

    suspend fun setCategoryHidden(id: Long, hidden: Boolean) {
        dao.setCategoryHidden(id, hidden)
    }

    suspend fun renameWallet(id: Long, name: String) {
        dao.renameWallet(id, name)
    }

    suspend fun setWalletArchived(id: Long, archived: Boolean) {
        dao.setWalletArchived(id, archived)
    }

    /** Factory wipe: transactions only. Rules, budgets, wallets, categories stay. */
    suspend fun wipeAllTransactions() {
        dao.wipeTransactions()
        lastDeleted = null
        refreshAll()
    }

    val goals: StateFlow<List<Goal>> =
        dao.allGoals().stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    suspend fun setGoal(name: String, targetPaise: Long) {
        dao.upsertGoal(Goal(name = name, targetPaise = targetPaise))
    }

    suspend fun addSaving(goalId: Long, amountPaise: Long) {
        dao.addSaving(goalId, amountPaise)
    }

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
        dao.trashById(id)
        lastDeleted = row
        refreshAll()
        return row
    }

    suspend fun restoreLastDeleted(): Long? {
        val row = lastDeleted ?: return null
        lastDeleted = null
        dao.restoreById(row.id)
        refreshAll()
        return row.id
    }

    val trashed: StateFlow<List<TransactionRow>> =
        dao.trashed().stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    suspend fun restoreTransaction(id: Long) {
        dao.restoreById(id)
        refreshAll()
    }

    suspend fun emptyTrash() {
        dao.purgeTrash()
        refreshAll()
    }

    fun clearUndo() {
        lastDeleted = null
    }
}
