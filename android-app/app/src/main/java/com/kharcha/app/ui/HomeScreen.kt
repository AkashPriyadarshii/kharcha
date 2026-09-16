package com.kharcha.app.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Switch
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
import com.kharcha.app.db.Budget
import com.kharcha.app.db.Category
import com.kharcha.app.db.TransactionRow
import java.text.SimpleDateFormat
import java.time.YearMonth
import java.time.format.TextStyle as MonthTextStyle
import java.util.Calendar
import java.util.Date
import java.util.Locale

private val dateFmt = SimpleDateFormat("d MMM", Locale.ENGLISH)
private val dayKeyFmt = SimpleDateFormat("yyyy-MM-dd", Locale.ENGLISH)

/** Capture permission state for the onboarding card. Null = fully set up (card hidden). */
data class CaptureSetup(val smsGranted: Boolean, val listenerEnabled: Boolean)

/** Today / Yesterday / 12 Sep — relative, glanceable. */
fun relativeDay(ts: Long): String {
    val cal = Calendar.getInstance()
    val today = dayKeyFmt.format(Date(cal.timeInMillis))
    cal.add(Calendar.DAY_OF_YEAR, -1)
    val yesterday = dayKeyFmt.format(Date(cal.timeInMillis))
    val key = dayKeyFmt.format(Date(ts))
    return when (key) {
        today -> "Today"
        yesterday -> "Yesterday"
        else -> dateFmt.format(Date(ts))
    }
}

private fun monthLabel(month: YearMonth): String {
    val name = month.month.getDisplayName(MonthTextStyle.FULL, Locale.ENGLISH)
    return "$name ${month.year}".uppercase(Locale.ENGLISH)
}

@Composable
fun HomeScreen(
    vm: AppViewModel,
    categories: List<Category>,
    onShowAll: () -> Unit,
    onAdd: () -> Unit,
    onSetBudget: () -> Unit,
    lockEnabled: Boolean,
    lockEnrollable: Boolean,
    onToggleLock: (Boolean) -> Unit,
    captureSetup: CaptureSetup?,
    onRequestSms: () -> Unit,
    onOpenListenerSettings: () -> Unit,
    snackbarHost: SnackbarHostState,
) {
    val month by vm.selectedMonth.collectAsState()
    val totals by vm.totals.collectAsState()
    val txns by vm.transactions.collectAsState()
    val budgets by vm.budgets.collectAsState()
    val spendMap by vm.budgetSpends.collectAsState()
    val loaded by vm.dataLoaded.collectAsState()

    val catEmoji: (Long?) -> String = { id -> categories.firstOrNull { it.id == id }?.emoji ?: "🧾" }
    val catName: (Long?) -> String = { id ->
        categories.firstOrNull { it.id == id }?.name ?: "Uncategorised"
    }
    val net = totals.income - totals.spend

    Scaffold(
        snackbarHost = { SnackbarHost(snackbarHost) },
        floatingActionButton = {
            FloatingActionButton(
                onClick = onAdd,
                modifier = Modifier.semantics { contentDescription = "Add transaction" },
            ) { Text("+", fontSize = 28.sp, fontWeight = FontWeight.Bold) }
        },
    ) { padding ->
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(padding).padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item {
                Spacer(Modifier.height(4.dp))
                Text("Kharcha", style = MaterialTheme.typography.headlineMedium)
            }
            if (captureSetup != null) {
                item {
                    CaptureSetupCard(captureSetup, onRequestSms, onOpenListenerSettings)
                }
            }
            item {
                // Month switcher: kills "what month am I seeing?" confusion.
                Row(
                    Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    TextButton(
                        onClick = { vm.shiftMonth(-1) },
                        modifier = Modifier.size(48.dp).semantics { contentDescription = "Previous month" },
                    ) { Text("‹", fontSize = 24.sp) }
                    Text(monthLabel(month), style = MaterialTheme.typography.titleMedium)
                    TextButton(
                        onClick = { vm.shiftMonth(1) },
                        modifier = Modifier.size(48.dp).semantics { contentDescription = "Next month" },
                    ) { Text("›", fontSize = 24.sp) }
                }
                Card(
                    Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                    elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
                ) {
                    Column(Modifier.padding(16.dp)) {
                        Text(
                            "SPENT · ${monthLabel(month)}",
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.secondary,
                        )
                        Text(
                            formatPaiseCompact(totals.spend),
                            style = TextStyle(
                                fontFamily = TabularNumerals,
                                fontSize = 44.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = MaterialTheme.colorScheme.onSurface,
                            ),
                        )
                        Spacer(Modifier.height(4.dp))
                        Text(
                            "In ${formatPaiseCompact(totals.income)} · Left ${formatPaiseCompact(net)}",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.secondary,
                        )
                    }
                }
            }
            item {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                    Text("Budgets", style = MaterialTheme.typography.titleMedium)
                    Text(
                        "Set new",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.primary,
                        modifier = Modifier
                            .heightIn(min = 48.dp)
                            .padding(horizontal = 8.dp)
                            .clickable { onSetBudget() }
                            .semantics { contentDescription = "Set a new budget" },
                    )
                }
            }
            if (budgets.isEmpty()) {
                item { Text("No budgets yet — set caps per category.", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.secondary) }
            } else {
                items(budgets, key = { it.categoryId }) { b ->
                    BudgetLine(b, spendMap[b.categoryId] ?: 0L, "${catEmoji(b.categoryId)} ${catName(b.categoryId)}")
                }
            }
            item {
                Row(Modifier.fillMaxWidth().padding(top = 4.dp), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                    Text("Recent", style = MaterialTheme.typography.titleMedium)
                    Text(
                        "View all →",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.primary,
                        modifier = Modifier
                            .heightIn(min = 48.dp)
                            .padding(horizontal = 8.dp)
                            .clickable { onShowAll() }
                            .semantics { contentDescription = "View all transactions" },
                    )
                }
            }
            when {
                !loaded -> items(6) { SkeletonRow() }
                txns.isEmpty() -> item {
                    EmptyState(
                        title = "No spends yet",
                        body = "Pay via UPI and it appears here automatically — or add one by hand.",
                        actionLabel = "Add expense",
                        onAction = onAdd,
                    )
                }
                else -> items(txns.take(8), key = { it.id }) { txn ->
                    TransactionLine(txn, catEmoji(txn.categoryId), catName(txn.categoryId))
                }
            }
            item {
                // Settings live here until a Profile tab exists — grouped, not mid-scroll.
                Text("Settings", style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(top = 8.dp))
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text("App lock", style = MaterialTheme.typography.bodyLarge)
                        Text(
                            if (!lockEnrollable) "Biometrics not set up on this device"
                            else "Ask for fingerprint on launch",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.secondary,
                        )
                    }
                    Switch(
                        checked = lockEnabled && lockEnrollable,
                        enabled = lockEnrollable,
                        onCheckedChange = onToggleLock,
                        modifier = Modifier.semantics { contentDescription = "Toggle app lock" },
                    )
                }
            }
            item { Spacer(Modifier.height(88.dp)) } // clear the FAB
        }
    }
}

@Composable
private fun CaptureSetupCard(
    setup: CaptureSetup,
    onRequestSms: () -> Unit,
    onOpenListenerSettings: () -> Unit,
) {
    Card(
        Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer),
    ) {
        Column(Modifier.padding(16.dp)) {
            Text("Auto-capture UPI payments", style = MaterialTheme.typography.titleMedium)
            Spacer(Modifier.height(4.dp))
            Text(
                "Every GPay / PhonePe / Paytm payment appears here by itself — no typing. Turn on both:",
                style = MaterialTheme.typography.bodyMedium,
            )
            Spacer(Modifier.height(8.dp))
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                if (!setup.smsGranted) {
                    Button(onClick = onRequestSms, modifier = Modifier.weight(1f).heightIn(min = 48.dp)) {
                        Text("Enable SMS")
                    }
                }
                if (!setup.listenerEnabled) {
                    OutlinedButton(onClick = onOpenListenerSettings, modifier = Modifier.weight(1f).heightIn(min = 48.dp)) {
                        Text("Enable notifications")
                    }
                }
            }
        }
    }
}

@Composable
private fun BudgetLine(budget: Budget, spent: Long, categoryLabel: String) {
    val limit = budget.monthlyLimitPaise
    // Never cap at 100%: overflow must be visible, not clipped.
    val ratio = if (limit <= 0) 0f else spent.toFloat() / limit
    val over = spent > limit
    val near = !over && limit > 0 && spent * 5 >= limit * 4 // ≥80% amber
    val barColor = when {
        over -> MaterialTheme.colorScheme.error
        near -> if (androidx.compose.foundation.isSystemInDarkTheme()) AmberDark else Amber
        else -> MaterialTheme.colorScheme.primary
    }
    val status = when {
        over -> "${formatPaiseCompact(spent - limit)} over"
        else -> "${formatPaiseCompact(limit - spent)} left"
    }
    Column(
        Modifier.fillMaxWidth().semantics {
            contentDescription = "$categoryLabel budget: spent ${formatPaise(spent)} of ${formatPaise(limit)}, $status"
        },
    ) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Text(categoryLabel, style = MaterialTheme.typography.bodyLarge)
            Text(
                status,
                style = MaterialTheme.typography.bodyMedium,
                fontFamily = TabularNumerals,
                color = if (over) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.secondary,
            )
        }
        Text(
            "${formatPaiseCompact(spent)} of ${formatPaiseCompact(limit)}",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.secondary,
        )
        LinearProgressIndicator(
            progress = { ratio.coerceIn(0f, 1f) },
            modifier = Modifier.fillMaxWidth().padding(top = 4.dp),
            color = barColor,
            trackColor = MaterialTheme.colorScheme.surfaceVariant,
        )
    }
}

@Composable
fun TransactionLine(txn: TransactionRow, emoji: String, category: String) {
    val amountColor = if (txn.isIncome) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onBackground
    val sign = if (txn.isIncome) "+" else "−"
    Row(
        Modifier.fillMaxWidth().heightIn(min = 56.dp).padding(vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            Modifier.size(40.dp).clip(CircleShape)
                .background(MaterialTheme.colorScheme.primaryContainer),
            contentAlignment = Alignment.Center,
        ) { Text(emoji, fontSize = 20.sp) }
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Text(txn.merchant, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.SemiBold)
            Text(
                "$category · ${relativeDay(txn.timestampMs)}${txn.paymentMethod?.let { " · $it" } ?: ""}",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.secondary,
            )
        }
        if (txn.needsReview) {
            Box(
                Modifier.size(8.dp).clip(CircleShape).background(Amber)
                    .semantics { contentDescription = "Needs category review" },
            )
            Spacer(Modifier.width(8.dp))
        }
        Text(
            "$sign${formatPaiseCompact(txn.amountPaise)}",
            style = TextStyle(fontFamily = TabularNumerals, fontSize = 16.sp, fontWeight = FontWeight.Medium),
            color = amountColor,
            modifier = Modifier.semantics {
                contentDescription = if (txn.isIncome) "Income ${formatPaise(txn.amountPaise)}" else "Spent ${formatPaise(txn.amountPaise)}"
            },
        )
    }
}

@Composable
private fun SkeletonRow() {
    Row(Modifier.fillMaxWidth().padding(vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.size(40.dp).clip(CircleShape).background(MaterialTheme.colorScheme.surfaceVariant))
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Box(Modifier.fillMaxWidth(0.5f).height(14.dp).clip(CircleShape).background(MaterialTheme.colorScheme.surfaceVariant))
            Spacer(Modifier.height(6.dp))
            Box(Modifier.fillMaxWidth(0.3f).height(12.dp).clip(CircleShape).background(MaterialTheme.colorScheme.surfaceVariant))
        }
    }
}

@Composable
fun EmptyState(title: String, body: String, actionLabel: String, onAction: () -> Unit) {
    Column(Modifier.fillMaxWidth().padding(vertical = 16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Text("🧾", fontSize = 40.sp)
        Spacer(Modifier.height(8.dp))
        Text(title, style = MaterialTheme.typography.titleMedium)
        Text(body, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.secondary)
        Spacer(Modifier.height(12.dp))
        Button(onClick = onAction, modifier = Modifier.heightIn(min = 48.dp)) { Text(actionLabel) }
    }
}

@Composable
fun AllTransactionsScreen(
    vm: AppViewModel,
    categories: List<Category>,
    modifier: Modifier = Modifier,
    onTap: (TransactionRow) -> Unit = {},
    onAdd: () -> Unit = {},
) {
    val txns by vm.transactions.collectAsState()
    val loaded by vm.dataLoaded.collectAsState()
    var query by remember { mutableStateOf("") }
    var filter by remember { mutableStateOf(AllFilter.ALL) }

    val catEmoji: (Long?) -> String = { id -> categories.firstOrNull { it.id == id }?.emoji ?: "🧾" }
    val catName: (Long?) -> String = { id -> categories.firstOrNull { it.id == id }?.name ?: "Uncategorised" }

    val visible = txns.filter { t ->
        val q = query.trim()
        val matchQuery = q.isEmpty() ||
            t.merchant.contains(q, ignoreCase = true) ||
            (t.note?.contains(q, ignoreCase = true) == true)
        val matchFilter = when (filter) {
            AllFilter.ALL -> true
            AllFilter.NEEDS_REVIEW -> t.needsReview
            AllFilter.INCOME -> t.isIncome
            AllFilter.UNCATEGORISED -> t.categoryId == null
        }
        matchQuery && matchFilter
    }
    val grouped = visible.groupBy { dayKeyFmt.format(Date(it.timestampMs)) }

    Column(modifier.fillMaxSize().padding(16.dp)) {
        Text("All transactions", style = MaterialTheme.typography.titleLarge)
        Spacer(Modifier.height(8.dp))
        OutlinedTextField(
            value = query,
            onValueChange = { query = it },
            label = { Text("Search merchant, note") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth().semantics { contentDescription = "Search transactions" },
        )
        Spacer(Modifier.height(8.dp))
        androidx.compose.foundation.lazy.LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            items(AllFilter.entries.toList()) { f ->
                FilterChip(
                    selected = filter == f,
                    onClick = { filter = f },
                    label = { Text(f.label) },
                )
            }
        }
        Spacer(Modifier.height(8.dp))
        when {
            !loaded -> LazyColumn(verticalArrangement = Arrangement.spacedBy(4.dp)) { items(6) { SkeletonRow() } }
            visible.isEmpty() -> EmptyState(
                title = if (query.isNotBlank() || filter != AllFilter.ALL) "Nothing matches" else "No spends yet",
                body = if (query.isNotBlank() || filter != AllFilter.ALL) "Try a different search or filter."
                else "Pay via UPI and it appears here, or add one by hand.",
                actionLabel = "Add expense",
                onAction = onAdd,
            )
            else -> LazyColumn(
                verticalArrangement = Arrangement.spacedBy(4.dp),
                modifier = Modifier.semantics { contentDescription = "Transaction list" },
            ) {
                for ((day, rows) in grouped) {
                    val dayNet = rows.sumOf { if (it.isIncome) it.amountPaise else -it.amountPaise }
                    item(key = "h$day") {
                        Row(Modifier.fillMaxWidth().padding(top = 8.dp), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text(relativeDay(rows.first().timestampMs), style = MaterialTheme.typography.titleSmall)
                            Text(
                                formatPaiseCompact(dayNet),
                                style = TextStyle(fontFamily = TabularNumerals),
                                color = MaterialTheme.colorScheme.secondary,
                            )
                        }
                    }
                    items(rows, key = { it.id }) { txn ->
                        Row(
                            Modifier.fillMaxWidth()
                                .heightIn(min = 56.dp)
                                .clickable { onTap(txn) }
                                .semantics { contentDescription = "Edit ${txn.merchant}" },
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            TransactionLine(txn, catEmoji(txn.categoryId), catName(txn.categoryId))
                        }
                    }
                }
            }
        }
    }
}

enum class AllFilter(val label: String) {
    ALL("All"),
    NEEDS_REVIEW("Needs review"),
    INCOME("Income"),
    UNCATEGORISED("Uncategorised"),
}
