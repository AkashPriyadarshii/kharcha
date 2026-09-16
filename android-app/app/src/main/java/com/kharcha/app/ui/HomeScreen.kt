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
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Card
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.kharcha.app.db.TransactionRow
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

private val dateFmt = SimpleDateFormat("d MMM", Locale.ENGLISH)

@Composable
fun HomeScreen(
    vm: AppViewModel,
    onShowAll: () -> Unit,
    onAdd: () -> Unit,
    categoryName: (Long?) -> String,
) {
    LaunchedEffect(Unit) { vm.refreshTotals() }
    val totals = vm.totals.collectAsState().value
    val txns = vm.transactions.collectAsState().value

    Scaffold { padding ->
        Column(
            modifier = Modifier.fillMaxSize().padding(padding).padding(16.dp),
        ) {
            Text("Kharcha", style = MaterialTheme.typography.headlineMedium)
            Spacer(Modifier.height(8.dp))
            Card(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(16.dp)) {
                    Text("Spent this month", style = MaterialTheme.typography.labelMedium)
                    Text(formatPaise(totals.spend), style = MaterialTheme.typography.headlineLarge)
                    Spacer(Modifier.height(6.dp))
                    Text(
                        "Received ${formatPaise(totals.income)}",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.secondary,
                    )
                }
            }
            Row(
                Modifier.fillMaxWidth().padding(top = 12.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text("Recent", style = MaterialTheme.typography.titleMedium)
                Text("View all →", style = MaterialTheme.typography.bodyMedium, modifier = Modifier.clickable { onShowAll() }.padding(4.dp))
            }
            LazyColumn(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                items(txns.take(8)) { txn -> TransactionLine(txn, categoryName) }
                item {
                    Spacer(Modifier.height(4.dp))
                    Text(
                        "+ Add manually",
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.fillMaxWidth().clickable { onAdd() }.padding(vertical = 12.dp),
                    )
                }
            }
        }
    }
}

@Composable
fun AllTransactionsScreen(vm: AppViewModel, categoryName: (Long?) -> String) {
    val txns = vm.transactions.collectAsState().value
    Column(Modifier.fillMaxSize().padding(16.dp)) {
        Text("All transactions", style = MaterialTheme.typography.titleLarge)
        Spacer(Modifier.height(8.dp))
        LazyColumn(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            items(txns) { txn -> TransactionLine(txn, categoryName) }
        }
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