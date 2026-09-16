package com.kharcha.app.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kharcha.app.db.Category
import com.kharcha.app.db.TransactionRow
import java.time.YearMonth

/**
 * Month reports: category breakdown with bars + biggest spenders. Read-only,
 * no new deps — slices the already-loaded transaction list.
 */
@Composable
fun ReportsScreen(
    vm: AppViewModel,
    categories: List<Category>,
) {
    val txns by vm.transactions.collectAsState()
    val month by vm.selectedMonth.collectAsState()
    var monthView by remember { mutableStateOf(month) }

    val monthStart = monthView.atDay(1).atStartOfDay(java.time.ZoneId.systemDefault()).toInstant().toEpochMilli()
    val monthEnd = monthView.plusMonths(1).atDay(1).atStartOfDay(java.time.ZoneId.systemDefault()).toInstant().toEpochMilli()
    val monthTxns = txns.filter { it.timestampMs in monthStart until monthEnd }

    val catName = categories.associate { it.id to it.name }
    val catEmoji = categories.associate { it.id to it.emoji }

    val spend = monthTxns.filter { !it.isIncome }
    val income = monthTxns.filter { it.isIncome }
    val totalSpend = spend.sumOf { it.amountPaise }
    val totalIncome = income.sumOf { it.amountPaise }
    val byCat = spend.groupBy { it.categoryId }.map { (catId, rows) ->
        CatSpend(catId, rows.sumOf { it.amountPaise }, rows.size)
    }.sortedByDescending { it.amount }.take(8)
    val topMerchants = spend.groupBy { it.merchant }.map { (m, rows) ->
        m to rows.sumOf { it.amountPaise }
    }.sortedByDescending { it.second }.take(5)

    var showShare by remember { mutableStateOf(false) }

    Column(Modifier.fillMaxSize()) {
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text("Reports", style = MaterialTheme.typography.titleLarge, modifier = Modifier.weight(1f))
            if (monthTxns.isNotEmpty()) TextButton(onClick = { showShare = true }) { Text("Share") }
        }
        if (showShare && monthTxns.isNotEmpty()) {
            androidx.compose.material3.AlertDialog(
                onDismissRequest = { showShare = false },
                confirmButton = {
                    ShareCardSharer(
                        context = androidx.compose.ui.platform.LocalContext.current,
                        card = { ShareCardContent(monthView, totalSpend, topMerchants.take(3)) },
                        onShared = { showShare = false },
                    )
                },
                dismissButton = { TextButton(onClick = { showShare = false }) { Text("Close") } },
                text = { ShareCardContent(monthView, totalSpend, topMerchants.take(3)) },
            )
        }

        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 16.dp)) {
            // Month pager
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                TextButton(
                    onClick = { monthView = monthView.minusMonths(1) },
                    modifier = Modifier.size(48.dp).semantics { contentDescription = "Previous month" },
                ) { Text("‹", fontSize = 24.sp) }
                Text(monthLabel(monthView), style = MaterialTheme.typography.titleMedium)
                TextButton(
                    onClick = { monthView = monthView.plusMonths(1) },
                    enabled = monthView < YearMonth.now(),
                    modifier = Modifier.size(48.dp).semantics { contentDescription = "Next month" },
                ) { Text("›", fontSize = 24.sp) }
            }
            Spacer(Modifier.height(8.dp))

            // Summary
            Card(
                Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
            ) {
                Row(Modifier.fillMaxWidth().padding(16.dp)) {
                    Stat("Spent", totalSpend, modifier = Modifier.weight(1f))
                    Stat("Income", totalIncome, modifier = Modifier.weight(1f))
                    Stat("Net", totalIncome - totalSpend, modifier = Modifier.weight(1f), accent = (totalIncome - totalSpend) >= 0)
                }
            }
            Spacer(Modifier.height(16.dp))

            if (monthTxns.isEmpty()) {
                EmptyState(
                    title = "Nothing this month",
                    body = "Spends from ${monthLabel(monthView)} will show up here.",
                    actionLabel = "Back to today",
                    onAction = { monthView = YearMonth.now() },
                )
            } else {
                Text("By category", style = MaterialTheme.typography.titleMedium)
                Spacer(Modifier.height(8.dp))
                if (byCat.isEmpty()) {
                    Text("No expenses this month — only income.", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.secondary)
                } else {
                    byCat.forEach { c ->
                        CategoryBar(
                            label = if (c.categoryId != null) "${catEmoji[c.categoryId] ?: "🧾"} ${catName[c.categoryId] ?: "Uncategorised"}" else "Uncategorised",
                            amount = c.amount,
                            total = totalSpend,
                            count = c.count,
                        )
                        Spacer(Modifier.height(10.dp))
                    }
                }
                Spacer(Modifier.height(16.dp))
                if (topMerchants.isNotEmpty()) {
                    Text("Most spent at", style = MaterialTheme.typography.titleMedium)
                    Spacer(Modifier.height(8.dp))
                    Card(
                        Modifier.fillMaxWidth(),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
                    ) {
                        Column(Modifier.padding(16.dp)) {
                            topMerchants.forEachIndexed { i, (merchant, amount) ->
                                if (i > 0) Spacer(Modifier.height(10.dp))
                                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                                    Text("${i + 1}.", style = MaterialTheme.typography.bodyLarge, color = MaterialTheme.colorScheme.secondary, modifier = Modifier.width(24.dp))
                                    Text(merchant, style = MaterialTheme.typography.bodyLarge, modifier = Modifier.weight(1f))
                                    Text(
                                        formatPaiseCompact(amount),
                                        style = TextStyle(fontFamily = TabularNumerals),
                                        color = MaterialTheme.colorScheme.secondary,
                                    )
                                }
                            }
                        }
                    }
                }
                Spacer(Modifier.height(32.dp))
            }
        }
    }
}

private data class CatSpend(val categoryId: Long?, val amount: Long, val count: Int)

@Composable
private fun Stat(label: String, amount: Long, modifier: Modifier = Modifier, accent: Boolean = true) {
    Column(modifier) {
        Text(label, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.secondary)
        Text(
            formatPaiseCompact(amount),
            style = TextStyle(fontFamily = TabularNumerals, fontSize = 17.sp, fontWeight = FontWeight.SemiBold),
            color = if (accent) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.error,
        )
    }
}

@Composable
private fun CategoryBar(label: String, amount: Long, total: Long, count: Int) {
    val ratio = if (total <= 0) 0f else amount.toFloat() / total
    Column(Modifier.fillMaxWidth().semantics {
        contentDescription = "$label: ${formatPaise(amount)}, $count transactions"
    }) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Text(label, style = MaterialTheme.typography.bodyLarge)
            Text(formatPaiseCompact(amount), style = TextStyle(fontFamily = TabularNumerals), color = MaterialTheme.colorScheme.secondary)
        }
        Row(Modifier.fillMaxWidth().padding(top = 4.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier.weight(ratio.coerceIn(0.02f, 1f)).height(10.dp)
                    .clip(RoundedCornerShape(5.dp))
                    .background(MaterialTheme.colorScheme.primary),
            )
            Spacer(Modifier.width(8.dp))
            Text("$count×", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.secondary)
        }
    }
}
