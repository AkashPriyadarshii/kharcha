package com.kharcha.app.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import android.widget.Toast
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
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Checkbox
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import kotlinx.coroutines.launch
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
import com.kharcha.app.db.Goal
import com.kharcha.app.db.OVERALL_BUDGET_ID
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
data class CaptureSetup(
    val smsGranted: Boolean,
    val listenerEnabled: Boolean,
    val notificationsAllowed: Boolean = true,
)

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

internal fun monthLabel(month: YearMonth): String {
    val name = month.month.getDisplayName(MonthTextStyle.FULL, Locale.ENGLISH)
    return "$name ${month.year}".uppercase(Locale.ENGLISH)
}

/** "2h ago" / "3d ago" — dead-man signal for silent listener death. */
internal fun captureAge(lastMs: Long, now: Long = System.currentTimeMillis()): String {
    if (lastMs <= 0) return "never"
    val m = (now - lastMs) / 60_000
    return when {
        m < 1 -> "just now"
        m < 60 -> "${m}m ago"
        m < 1440 -> "${m / 60}h ago"
        else -> "${m / 1440}d ago"
    }
}

@Composable
fun HomeScreen(
    vm: AppViewModel,
    categories: List<Category>,
    userName: String,
    lastCaptureMs: Long = 0,
    onShowAll: () -> Unit,
    onReports: () -> Unit,
    onAdd: () -> Unit,
    onSetBudget: () -> Unit,
    onAddGoal: () -> Unit,
    onOpenBudgets: () -> Unit = onSetBudget,
    onOpenGoals: () -> Unit = onAddGoal,
    captureSetup: CaptureSetup?,
    onRequestSms: () -> Unit,
    onOpenListenerSettings: () -> Unit,
) {
    val month by vm.selectedMonth.collectAsState()
    val totals by vm.totals.collectAsState()
    val txns by vm.transactions.collectAsState()
    val budgets by vm.budgets.collectAsState()
    val spendMap by vm.budgetSpends.collectAsState()
    val subs by vm.subscriptions.collectAsState()
    val carryMap by vm.budgetCarry.collectAsState()
    val goals by vm.goals.collectAsState()
    val loaded by vm.dataLoaded.collectAsState()

    val catEmoji: (Long?) -> String = { id -> categories.firstOrNull { it.id == id }?.emoji ?: "🧾" }
    val catName: (Long?) -> String = { id ->
        categories.firstOrNull { it.id == id }?.name ?: "Uncategorised"
    }

    val context = LocalContext.current
    var showCustomizeHome by remember { mutableStateOf(false) }
    var showBudgetsPref by remember { mutableStateOf(UserPrefs.showHomeBudgets(context)) }
    var showGoalsPref by remember { mutableStateOf(UserPrefs.showHomeGoals(context)) }
    var showSubsPref by remember { mutableStateOf(UserPrefs.showHomeSubs(context)) }
    var showBurnPref by remember { mutableStateOf(UserPrefs.showHomeDailyBurn(context)) }

    LazyColumn(
        modifier = Modifier.fillMaxSize().padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
            item {
                Spacer(Modifier.height(4.dp))
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                    Column {
                        Text(
                            if (userName.isBlank()) "Kharcha" else "Hi ${userName.trim()},",
                            style = MaterialTheme.typography.headlineMedium,
                        )
                        if (userName.isNotBlank()) {
                            Text("Here's your money.", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.secondary)
                        }
                    }
                    TextButton(
                        onClick = { showCustomizeHome = true },
                        modifier = Modifier.semantics { contentDescription = "Customize home feed" }
                    ) {
                        Text("Customize", fontSize = 13.sp, color = MaterialTheme.colorScheme.primary)
                    }
                }
            }
            if (captureSetup != null) {
                item {
                    CaptureSetupCard(captureSetup, onRequestSms, onOpenListenerSettings)
                }
            }
            item {
                HomeSummaryCard(vm, month, totals, lastCaptureMs, budgets, showBurnPref)
            }
            if (showBudgetsPref) {
                item {
                    SectionHeader("Budgets", "Manage →", "Manage all budgets", onOpenBudgets)
                }
                if (budgets.isEmpty()) {
                    item { Text("No budgets yet — set caps per category in Budgets.", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.secondary) }
                } else {
                    items(budgets, key = { "b_${it.categoryId}" }) { b ->
                        val carry = carryMap[b.categoryId] ?: 0L
                        BudgetLine(
                            b.copy(monthlyLimitPaise = b.monthlyLimitPaise + carry),
                            spendMap[b.categoryId] ?: 0L,
                            if (b.categoryId == OVERALL_BUDGET_ID) "Overall"
                            else "${catEmoji(b.categoryId)} ${catName(b.categoryId)}",
                            note = if (carry > 0) "+${formatPaiseCompact(carry)} rollover" else null,
                        )
                    }
                }
            }
            if (showSubsPref && subs.isNotEmpty()) {
                item {
                    Column {
                        Text("Subscriptions", style = MaterialTheme.typography.titleMedium)
                        Spacer(Modifier.height(4.dp))
                        // ponytail: suspects only (2+ months, same merchant + amount). Confirm by tapping through.
                        subs.take(5).forEach { s ->
                            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                Text(s.merchant, style = MaterialTheme.typography.bodyLarge)
                                Text(
                                    "${formatPaiseCompact(s.amountPaise)} · monthly",
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = MaterialTheme.colorScheme.secondary,
                                    fontFamily = TabularNumerals,
                                )
                            }
                        }
                    }
                }
            }
            if (showGoalsPref) {
                item {
                    SectionHeader("Savings Goals", "Manage →", "Manage all savings goals", onOpenGoals)
                }
                if (goals.isEmpty()) {
                    item { Text("No goals yet — track savings milestones in Goals.", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.secondary) }
                } else {
                    items(goals, key = { "g_${it.id}" }) { g -> GoalLine(g) }
                }
            }
            item {
                SectionHeader("Reports", "Insights →", "Open reports", onReports)
            }
            item {
                SectionHeader("Recent", "View all →", "View all transactions", onShowAll)
            }
            when {
                !loaded -> items(6, key = { "skel_$it" }) { SkeletonRow() }
                txns.isEmpty() -> item {
                    EmptyState(
                        title = "No spends yet",
                        body = "Pay via UPI and it appears here automatically — or add one by hand.",
                        actionLabel = "Add expense",
                        onAction = onAdd,
                    )
                }
                else -> items(txns.take(8), key = { "t_${it.id}" }) { txn ->
                    TransactionLine(txn, catEmoji(txn.categoryId), catName(txn.categoryId))
                }
            }
            item {
                Spacer(Modifier.height(88.dp)) // clear the FAB
            }
        }

    if (showCustomizeHome) {
        AlertDialog(
            onDismissRequest = { showCustomizeHome = false },
            title = { Text("Customize Home Feed") },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(
                        "Toggle which sections appear on your home screen:",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.secondary,
                    )
                    Row(
                        Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text("Category Budgets", style = MaterialTheme.typography.bodyLarge)
                        Switch(
                            checked = showBudgetsPref,
                            onCheckedChange = {
                                showBudgetsPref = it
                                UserPrefs.setShowHomeBudgets(context, it)
                            },
                        )
                    }
                    Row(
                        Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text("Savings Goals", style = MaterialTheme.typography.bodyLarge)
                        Switch(
                            checked = showGoalsPref,
                            onCheckedChange = {
                                showGoalsPref = it
                                UserPrefs.setShowHomeGoals(context, it)
                            },
                        )
                    }
                    Row(
                        Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text("Subscriptions (Suspects)", style = MaterialTheme.typography.bodyLarge)
                        Switch(
                            checked = showSubsPref,
                            onCheckedChange = {
                                showSubsPref = it
                                UserPrefs.setShowHomeSubs(context, it)
                            },
                        )
                    }
                    Row(
                        Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text("Daily Burn Rate Pace", style = MaterialTheme.typography.bodyLarge)
                        Switch(
                            checked = showBurnPref,
                            onCheckedChange = {
                                showBurnPref = it
                                UserPrefs.setShowHomeDailyBurn(context, it)
                            },
                        )
                    }
                }
            },
            confirmButton = {
                TextButton(onClick = { showCustomizeHome = false }) {
                    Text("Done")
                }
            },
        )
    }
}

/** Section header row: title left, tappable action right. */
@Composable
private fun SectionHeader(title: String, action: String, actionDesc: String, onAction: () -> Unit) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
        Text(title, style = MaterialTheme.typography.titleMedium)
        Text(
            action,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.primary,
            modifier = Modifier
                .heightIn(min = 48.dp)
                .padding(horizontal = 8.dp)
                .clickable { onAction() }
                .semantics { contentDescription = actionDesc },
        )
    }
}

/** Month switcher + spend summary card (extracted from HomeScreen's LazyColumn). */
@Composable
private fun HomeSummaryCard(
    vm: AppViewModel,
    month: YearMonth,
    totals: MonthTotals,
    lastCaptureMs: Long,
    budgets: List<Budget>,
    showBurnPref: Boolean,
) {
    val net = totals.income - totals.spend
    val today = remember { java.time.LocalDate.now() }
    val isCurrentMonth = remember(month, today) { month == YearMonth.from(today) }
    Column {
        // Month switcher: kills "what month am I seeing?" confusion.
        Row(
            Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            IconButton(
                onClick = { vm.shiftMonth(-1) },
                modifier = Modifier.size(48.dp),
            ) {
                Icon(
                    Icons.AutoMirrored.Filled.KeyboardArrowLeft,
                    contentDescription = "Previous month",
                )
            }
            Text(monthLabel(month), style = MaterialTheme.typography.titleMedium)
            IconButton(
                onClick = { vm.shiftMonth(1) },
                modifier = Modifier.size(48.dp),
            ) {
                Icon(
                    Icons.AutoMirrored.Filled.KeyboardArrowRight,
                    contentDescription = "Next month",
                )
            }
        }
        Card(
            Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(8.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
            border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant),
        ) {
            Column(Modifier.padding(16.dp)) {
                Text(
                    "SPENT · ${monthLabel(month)}",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.secondary,
                )
                Text(
                    "Auto-capture \u00b7 ${captureAge(lastCaptureMs)}",
                    style = MaterialTheme.typography.labelSmall,
                    color = if (lastCaptureMs > 0) MaterialTheme.colorScheme.secondary else MaterialTheme.colorScheme.error,
                )
                AnimatedCurrencyText(
                    totals.spend,
                    TextStyle(
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
                // Daily burn rate: only meaningful with an overall cap on the live month.
                val overallCap = budgets.firstOrNull { it.categoryId == OVERALL_BUDGET_ID }
                if (showBurnPref && overallCap != null && isCurrentMonth) {
                    val remaining = overallCap.monthlyLimitPaise - totals.spend
                    val daysLeft = remember(month, today) { month.lengthOfMonth() - today.dayOfMonth + 1 }
                    Text(
                        if (remaining >= 0) "${formatPaiseCompact(remaining / daysLeft.coerceAtLeast(1))}/day · $daysLeft days left"
                        else "${formatPaiseCompact(-remaining)} over pace",
                        style = MaterialTheme.typography.bodyMedium,
                        color = if (remaining >= 0) MaterialTheme.colorScheme.secondary else MaterialTheme.colorScheme.error,
                    )
                }
            }
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
private fun BudgetLine(budget: Budget, spent: Long, categoryLabel: String, note: String? = null) {
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
        note?.let {
            Text(
                it,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.secondary,
            )
        }
        SegmentedMeter(
            ratio = ratio,
            activeColor = barColor,
            modifier = Modifier.fillMaxWidth().padding(top = 6.dp),
        )
    }
}

@Composable
private fun GoalLine(goal: Goal) {
    val target = goal.targetPaise
    val ratio = if (target <= 0) 0f else goal.savedPaise.toFloat() / target
    val done = target > 0 && goal.savedPaise >= target
    val status = if (done) "Saved ✓" else "${formatPaiseCompact(target - goal.savedPaise)} left"
    Column(
        Modifier.fillMaxWidth().semantics {
            contentDescription = "${goal.name} goal: saved ${formatPaise(goal.savedPaise)} of ${formatPaise(target)}, $status"
        },
    ) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Text(goal.name, style = MaterialTheme.typography.bodyLarge)
            Text(
                status,
                style = MaterialTheme.typography.bodyMedium,
                fontFamily = TabularNumerals,
                color = if (done) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.secondary,
            )
        }
        Text(
            "${formatPaiseCompact(goal.savedPaise)} of ${formatPaiseCompact(target)}",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.secondary,
        )
        SegmentedMeter(
            ratio = ratio,
            activeColor = MaterialTheme.colorScheme.primary,
            modifier = Modifier.fillMaxWidth().padding(top = 6.dp),
        )
    }
}

@Composable
fun SegmentedMeter(
    ratio: Float,
    activeColor: androidx.compose.ui.graphics.Color,
    modifier: Modifier = Modifier,
    segments: Int = 10,
) {
    val filledCount = (ratio * segments).toInt().coerceIn(0, segments)
    val inactiveColor = MaterialTheme.colorScheme.surfaceVariant
    Row(
        modifier = modifier.height(6.dp),
        horizontalArrangement = Arrangement.spacedBy(3.dp),
    ) {
        for (i in 0 until segments) {
            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxSize()
                    .clip(RoundedCornerShape(2.dp))
                    .background(if (i < filledCount) activeColor else inactiveColor),
            )
        }
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
        BrandAvatar(txn.merchant, emoji)
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

@OptIn(ExperimentalMaterial3Api::class)
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
    val wallets by vm.wallets.collectAsState()
    var query by remember { mutableStateOf("") }
    var filter by remember { mutableStateOf(AllFilter.ALL) }
    var selectMode by remember { mutableStateOf(false) }
    var selected by remember { mutableStateOf<Set<Long>>(emptySet()) }
    var showBulkCat by remember { mutableStateOf(false) }
    val context = LocalContext.current
    val bulkScope = rememberCoroutineScope()
    var catId by remember { mutableStateOf<Long?>(null) }
    var method by remember { mutableStateOf<String?>(null) }
    var minPaise by remember { mutableStateOf(0L) }
    var walletId by remember { mutableStateOf<Long?>(null) }
    var dateMode by remember { mutableStateOf("All") }
    var dateFrom by remember { mutableStateOf<Long?>(null) }
    var dateTo by remember { mutableStateOf<Long?>(null) }
    var showFrom by remember { mutableStateOf(false) }
    var showTo by remember { mutableStateOf(false) }

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
        val matchCat = catId == null || t.categoryId == catId
        val matchMethod = method == null || t.paymentMethod == method
        val matchAmount = t.amountPaise >= minPaise
        val matchWallet = walletId == null || t.walletId == walletId
        val from = dateFrom
        val to = dateTo
        val matchDate = (from == null || t.timestampMs >= from) &&
            (to == null || t.timestampMs < to)
        matchQuery && matchFilter && matchCat && matchMethod && matchAmount && matchWallet && matchDate
    }
    val filtering = query.isNotBlank() || filter != AllFilter.ALL || catId != null ||
        method != null || minPaise > 0 || walletId != null || dateFrom != null
    val grouped = visible.groupBy { dayKeyFmt.format(Date(it.timestampMs)) }

    Column(modifier.fillMaxSize().padding(16.dp)) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
            Text("All transactions", style = MaterialTheme.typography.titleLarge)
            TextButton(onClick = { selectMode = !selectMode; selected = emptySet() }) {
                Text(if (selectMode) "Done" else "Select")
            }
        }
        if (selectMode && selected.isNotEmpty()) {
            Row(horizontalArrangement = Arrangement.spacedBy(4.dp), verticalAlignment = Alignment.CenterVertically) {
                Text("${selected.size} picked", style = MaterialTheme.typography.bodyMedium)
                TextButton(onClick = {
                    bulkScope.launch { vm.bulkDelete(selected); selected = emptySet() }
                }) { Text("Delete", color = MaterialTheme.colorScheme.error) }
                TextButton(onClick = { showBulkCat = true }) { Text("Category") }
                TextButton(
                    enabled = selected.size == 2,
                    onClick = {
                        val ids = selected.toList()
                        bulkScope.launch {
                            val ok = vm.linkTransactions(ids[0], ids[1])
                            selected = emptySet()
                            Toast.makeText(context, if (ok) "Linked as pair" else "Link failed", Toast.LENGTH_SHORT).show()
                        }
                    },
                ) { Text("Link") }
            }
        }
        if (showBulkCat) {
            var bulkCat by remember { mutableStateOf<Long?>(null) }
            AlertDialog(
                onDismissRequest = { showBulkCat = false },
                title = { Text("Set category") },
                text = {
                    androidx.compose.foundation.lazy.LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        items(categories, key = { it.id }) { c ->
                            FilterChip(
                                selected = bulkCat == c.id,
                                onClick = { bulkCat = c.id },
                                label = { Text("${c.emoji} ${c.name}") },
                            )
                        }
                    }
                },
                confirmButton = {
                    TextButton(onClick = {
                        val c = bulkCat
                        showBulkCat = false
                        if (c != null) bulkScope.launch { vm.bulkCategorize(selected, c); selected = emptySet() }
                    }) { Text("Apply") }
                },
                dismissButton = { TextButton(onClick = { showBulkCat = false }) { Text("Cancel") } },
            )
        }
        var showFilterSheet by remember { mutableStateOf(false) }
        val secondaryActiveCount = (if (catId != null) 1 else 0) +
            (if (method != null) 1 else 0) +
            (if (minPaise > 0) 1 else 0) +
            (if (walletId != null) 1 else 0) +
            (if (dateMode != "All") 1 else 0)

        Spacer(Modifier.height(8.dp))
        OutlinedTextField(
            value = query,
            onValueChange = { query = it },
            label = { Text("Search merchant, note") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth().semantics { contentDescription = "Search transactions" },
        )
        Spacer(Modifier.height(8.dp))

        // Single clean primary row: Status + "Filters (N)" trigger
        androidx.compose.foundation.lazy.LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            item {
                FilterChip(
                    selected = secondaryActiveCount > 0,
                    onClick = { showFilterSheet = true },
                    label = { Text(if (secondaryActiveCount > 0) "Filters ($secondaryActiveCount)" else "Filters") },
                )
            }
            items(AllFilter.entries.toList()) { f ->
                FilterChip(
                    selected = filter == f,
                    onClick = { filter = f },
                    label = { Text(f.label) },
                )
            }
        }

        // Active filter pills quick-dismiss strip (shown only when secondary filters are set)
        if (secondaryActiveCount > 0) {
            Spacer(Modifier.height(4.dp))
            androidx.compose.foundation.lazy.LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                catId?.let { cid ->
                    item {
                        FilterChip(
                            selected = true,
                            onClick = { catId = null },
                            label = { Text("${catName(cid)} ✕") },
                        )
                    }
                }
                method?.let { m ->
                    item {
                        FilterChip(
                            selected = true,
                            onClick = { method = null },
                            label = { Text("$m ✕") },
                        )
                    }
                }
                if (minPaise > 0) {
                    item {
                        FilterChip(
                            selected = true,
                            onClick = { minPaise = 0L },
                            label = { Text("₹${minPaise / 100}+ ✕") },
                        )
                    }
                }
                walletId?.let { wid ->
                    val wName = wallets.firstOrNull { it.id == wid }?.name ?: "Wallet"
                    item {
                        FilterChip(
                            selected = true,
                            onClick = { walletId = null },
                            label = { Text("$wName ✕") },
                        )
                    }
                }
                if (dateMode != "All") {
                    item {
                        FilterChip(
                            selected = true,
                            onClick = { dateMode = "All"; dateFrom = null; dateTo = null },
                            label = { Text("$dateMode ✕") },
                        )
                    }
                }
            }
        }

        if (showFilterSheet) {
            ModalBottomSheet(onDismissRequest = { showFilterSheet = false }) {
                Column(
                    Modifier
                        .fillMaxWidth()
                        .verticalScroll(rememberScrollState())
                        .padding(horizontal = 16.dp)
                        .padding(bottom = 32.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Row(
                        Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text("Filters", style = MaterialTheme.typography.titleLarge)
                        TextButton(onClick = {
                            catId = null
                            method = null
                            minPaise = 0L
                            walletId = null
                            dateMode = "All"
                            dateFrom = null
                            dateTo = null
                        }) { Text("Reset all") }
                    }

                    Text("Category", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
                    androidx.compose.foundation.lazy.LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        item {
                            FilterChip(selected = catId == null, onClick = { catId = null }, label = { Text("All") })
                        }
                        items(categories, key = { "sheet_cat_${it.id}" }) { c ->
                            FilterChip(
                                selected = catId == c.id,
                                onClick = { catId = if (catId == c.id) null else c.id },
                                label = { Text("${c.emoji} ${c.name}") },
                            )
                        }
                    }

                    Text("Payment Method", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
                    androidx.compose.foundation.lazy.LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        item {
                            FilterChip(selected = method == null, onClick = { method = null }, label = { Text("Any") })
                        }
                        items(PaymentMethods) { m ->
                            FilterChip(
                                selected = method == m,
                                onClick = { method = if (method == m) null else m },
                                label = { Text(m) },
                            )
                        }
                    }

                    Text("Minimum Amount", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
                    androidx.compose.foundation.lazy.LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        val amounts = listOf(0L to "Any ₹", 50_000L to "₹500+", 200_000L to "₹2k+", 1_000_000L to "₹10k+")
                        items(amounts) { (v, label) ->
                            FilterChip(
                                selected = minPaise == v,
                                onClick = { minPaise = v },
                                label = { Text(label) },
                            )
                        }
                    }

                    if (wallets.isNotEmpty()) {
                        Text("Account / Wallet", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
                        androidx.compose.foundation.lazy.LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            item {
                                FilterChip(selected = walletId == null, onClick = { walletId = null }, label = { Text("All") })
                            }
                            items(wallets, key = { "sheet_w_${it.id}" }) { w ->
                                FilterChip(
                                    selected = walletId == w.id,
                                    onClick = { walletId = if (walletId == w.id) null else w.id },
                                    label = { Text(w.name) },
                                )
                            }
                        }
                    }

                    Text("Date Range", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
                    val zone = java.time.ZoneId.systemDefault()
                    fun dayMs(y: Int, m: Int, d: Int) =
                        java.time.LocalDate.of(y, m, d).atStartOfDay(zone).toInstant().toEpochMilli()
                    val dates = listOf("All", "7D", "Month", "Cycle", "Custom")
                    androidx.compose.foundation.lazy.LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        items(dates) { label ->
                            FilterChip(
                                selected = dateMode == label,
                                onClick = {
                                    dateMode = label
                                    val now = System.currentTimeMillis()
                                    when (label) {
                                        "All" -> { dateFrom = null; dateTo = null }
                                        "7D" -> { dateFrom = now - 7L * 24 * 60 * 60 * 1000; dateTo = null }
                                        "Month" -> monthRange(java.time.YearMonth.now()).let { dateFrom = it.first; dateTo = it.second }
                                        "Cycle" -> {
                                            val t = java.time.LocalDate.now(zone)
                                            if (t.dayOfMonth >= 25) {
                                                val n = t.plusMonths(1)
                                                dateFrom = dayMs(t.year, t.monthValue, 25)
                                                dateTo = dayMs(n.year, n.monthValue, 25)
                                            } else {
                                                val p = t.minusMonths(1)
                                                dateFrom = dayMs(p.year, p.monthValue, 25)
                                                dateTo = dayMs(t.year, t.monthValue, 25)
                                            }
                                        }
                                        "Custom" -> showFrom = true
                                    }
                                },
                                label = { Text(if (label == "Cycle") "Cycle 25–24" else label) },
                            )
                        }
                    }
                    if (dateMode == "Custom") {
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                            TextButton(onClick = { showFrom = true }) {
                                Text(dateFrom?.let { "From ${dateFmt.format(Date(it))}" } ?: "From…")
                            }
                            TextButton(onClick = { showTo = true }) {
                                Text(dateTo?.let { "To ${dateFmt.format(Date(it))}" } ?: "To…")
                            }
                        }
                    }

                    Button(
                        onClick = { showFilterSheet = false },
                        modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
                    ) { Text("Apply filters") }
                }
            }
        }
        if (showFrom) {
            val st = androidx.compose.material3.rememberDatePickerState(initialSelectedDateMillis = dateFrom)
            androidx.compose.material3.DatePickerDialog(
                onDismissRequest = { showFrom = false },
                confirmButton = {
                    TextButton(onClick = {
                        st.selectedDateMillis?.let { dateFrom = it }
                        showFrom = false
                    }) { Text("OK") }
                },
                dismissButton = { TextButton(onClick = { showFrom = false }) { Text("Cancel") } },
            ) { androidx.compose.material3.DatePicker(st) }
        }
        if (showTo) {
            val st = androidx.compose.material3.rememberDatePickerState(initialSelectedDateMillis = dateTo)
            androidx.compose.material3.DatePickerDialog(
                onDismissRequest = { showTo = false },
                confirmButton = {
                    TextButton(onClick = {
                        // End of selected day, exclusive upper bound.
                        st.selectedDateMillis?.let { dateTo = it + 24L * 60 * 60 * 1000 }
                        showTo = false
                    }) { Text("OK") }
                },
                dismissButton = { TextButton(onClick = { showTo = false }) { Text("Cancel") } },
            ) { androidx.compose.material3.DatePicker(st) }
        }
        Spacer(Modifier.height(8.dp))
        when {
            !loaded -> LazyColumn(verticalArrangement = Arrangement.spacedBy(4.dp)) { items(6) { SkeletonRow() } }
            visible.isEmpty() -> EmptyState(
                title = if (filtering) "Nothing matches" else "No spends yet",
                body = if (filtering) "Try a different search or filter."
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
                                .clickable {
                                    if (selectMode) selected = if (txn.id in selected) selected - txn.id else selected + txn.id
                                    else onTap(txn)
                                }
                                .semantics { contentDescription = "Edit ${txn.merchant}" },
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            if (selectMode) {
                                Checkbox(checked = txn.id in selected, onCheckedChange = null)
                            }
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
