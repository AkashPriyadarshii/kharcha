package com.kharcha.app.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Card
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.kharcha.app.db.Budget
import com.kharcha.app.db.TransactionRow
import com.kharcha.app.db.Wallet
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

private val dateFmt = SimpleDateFormat("d MMM", Locale.ENGLISH)

@Composable
fun HomeScreen(
    vm: AppViewModel,
    categoryName: (Long?) -> String,
    onShowAll: () -> Unit,
    onAdd: () -> Unit,
    onSetBudget: () -> Unit,
    lockEnabled: Boolean,
    onToggleLock: (Boolean) -> Unit,
) {
    LaunchedEffect(Unit) {
        vm.refreshTotals()
        vm.refreshBudgetSpends()
    }
    val totals = vm.totals.collectAsState().value
    val txns = vm.transactions.collectAsState().value
    val wallets = vm.wallets.collectAsState().value
    val budgets = vm.budgets.collectAsState().value
    val spendMap = vm.budgetSpends.collectAsState().value

    Scaffold { padding ->
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(padding).padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item {
                Spacer(Modifier.height(4.dp))
                Text("Kharcha", style = MaterialTheme.typography.headlineMedium)
            }
            item {
                Card(Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(16.dp)) {
                        Text("Spent this month", style = MaterialTheme.typography.labelMedium)
                        Text(formatPaise(totals.spend), style = MaterialTheme.typography.headlineLarge)
                        Spacer(Modifier.height(6.dp))
                        Text("Received ${formatPaise(totals.income)}", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.secondary)
                    }
                }
            }
            if (wallets.isNotEmpty()) {
                item {
                    Text("Wallets", style = MaterialTheme.typography.titleMedium)
                    LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        items(wallets) { w -> WalletChip(w) }
                    }
                }
            }
            item {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                    Text("Budgets", style = MaterialTheme.typography.titleMedium)
                    Text("Set new", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.primary, modifier = Modifier.padding(4.dp).clickable { onSetBudget() })
                }
            }
            if (budgets.isEmpty()) {
                item { Text("No budgets yet — set caps per category.", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.secondary) }
            } else {
                items(budgets) { b -> BudgetLine(b, spendMap[b.categoryId] ?: 0L, categoryName(b.categoryId)) }
            }
            item {
                Row(Modifier.fillMaxWidth().padding(top = 4.dp), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                    Text("Recent", style = MaterialTheme.typography.titleMedium)
                    Text("View all →", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.primary, modifier = Modifier.padding(4.dp).clickable { onShowAll() })
                }
            }
            items(txns.take(8)) { txn -> TransactionLine(txn, categoryName) }
            item {
                Text("+ Add manually", style = MaterialTheme.typography.bodyLarge, color = MaterialTheme.colorScheme.primary, modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp).clickable { onAdd() })
            }
            item {
                Row(Modifier.fillMaxWidth().padding(vertical = 8.dp), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                    Text("App lock", style = MaterialTheme.typography.bodyLarge)
                    Switch(checked = lockEnabled, onCheckedChange = onToggleLock)
                }
            }
            item { Spacer(Modifier.height(8.dp)) }
        }
    }
}

@Composable
private fun WalletChip(w: Wallet) {
    AssistChip(
        onClick = {},
        label = { Text("${w.name} · ${w.balancePaise?.let(::formatPaise) ?: "—"}") },
    )
}

@Composable
private fun BudgetLine(budget: Budget, spent: Long, categoryLabel: String) {
    val ratio = if (budget.monthlyLimitPaise <= 0) 0f else (spent.toFloat() / budget.monthlyLimitPaise).coerceIn(0f, 1f)
    val over = spent > budget.monthlyLimitPaise
    Column(Modifier.fillMaxWidth()) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Text(categoryLabel, style = MaterialTheme.typography.bodyLarge)
            Text("${formatPaise(spent)} / ${formatPaise(budget.monthlyLimitPaise)}", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.secondary)
        }
        LinearProgressIndicator(
            progress = { ratio },
            modifier = Modifier.fillMaxWidth().padding(top = 4.dp),
            color = if (over) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.primary,
        )
    }
}

@Composable
private fun TransactionLine(txn: TransactionRow, categoryName: (Long?) -> String) {
    Row(Modifier.fillMaxWidth().padding(vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f)) {
            Text(txn.merchant, style = MaterialTheme.typography.bodyLarge)
            Text(
                "${categoryName(txn.categoryId)} · ${dateFmt.format(Date(txn.timestampMs))}${if (txn.needsReview) " · review" else ""}",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.secondary,
            )
        }
        Text(
            formatPaise(txn.amountPaise),
            style = MaterialTheme.typography.bodyLarge,
            color = if (txn.isIncome) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onBackground,
        )
    }
}
@Composable
fun AllTransactionsScreen(
    vm: AppViewModel,
    categoryName: (Long?) -> String,
    modifier: Modifier = Modifier,
    onTap: (TransactionRow) -> Unit = {},
) {
    val txns = vm.transactions.collectAsState().value
    Column(modifier.fillMaxSize().padding(16.dp)) {
        Text("All transactions", style = MaterialTheme.typography.titleLarge)
        Spacer(Modifier.height(8.dp))
        LazyColumn(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            items(txns, key = { it.id }) { txn ->
                Row(
                    Modifier.fillMaxWidth().clickable { onTap(txn) },
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    TransactionLine(txn, categoryName)
                }
            }
        }
    }
}
