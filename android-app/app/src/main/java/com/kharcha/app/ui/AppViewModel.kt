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
import java.util.Calendar

data class MonthTotals(val spend: Long, val income: Long)

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

    /** Category spend this month, for budget progress. */
    val budgetSpends: MutableStateFlow<Map<Long, Long>> = MutableStateFlow(emptyMap())

    fun refreshBudgetSpends() {
        viewModelScope.launch {
            val cal = Calendar.getInstance()
            val start = cal.apply {
                set(Calendar.DAY_OF_MONTH, 1); set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
            }.timeInMillis
            val end = start + 31L * 24 * 60 * 60 * 1000
            val map = budgets.value.associate { it.categoryId to dao.categorySpend(it.categoryId, start, end) }
            budgetSpends.value = map
        }
    }
    /** This-month spend/income, refreshed on save/launch. */
    val totals: MutableStateFlow<MonthTotals> = MutableStateFlow(MonthTotals(0, 0))

    fun refreshTotals() {
        viewModelScope.launch {
            val cal = Calendar.getInstance()
            val start = cal.apply {
                set(Calendar.DAY_OF_MONTH, 1); set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
            }.timeInMillis
            val end = start + 31L * 24 * 60 * 60 * 1000
            totals.value = MonthTotals(
                spend = dao.spendBetween(start, end),
                income = dao.incomeBetween(start, end),
            )
        }
    }

    suspend fun saveTransaction(txn: TransactionRow): Long {
        val id = dao.insert(txn)
        refreshBudgetSpends()
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
            dao.insertRule(RuleRow(pattern = txn.merchant, ruleType = "learned", categoryId = txn.categoryId))
        }
    }

    suspend fun deleteTransaction(id: Long) = dao.deleteById(id)
}