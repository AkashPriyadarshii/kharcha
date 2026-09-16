package com.kharcha.app.ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kharcha.app.db.Budget
import com.kharcha.app.db.Category
import com.kharcha.app.db.OVERALL_BUDGET_ID
import kotlinx.coroutines.launch

/**
 * Dedicated Budgets management screen: see all category caps,
 * spent progress with segmented meters, add new caps, and remove caps.
 */
@Composable
fun BudgetsScreen(
    vm: AppViewModel,
    categories: List<Category>,
    onBack: () -> Unit,
    onAddBudget: () -> Unit,
) {
    val budgets by vm.budgets.collectAsState()
    val spendMap by vm.budgetSpends.collectAsState()
    val carryMap by vm.budgetCarry.collectAsState()
    val scope = rememberCoroutineScope()
    var deletingBudget by remember { mutableStateOf<Budget?>(null) }

    val catName = categories.associate { it.id to it.name }
    val catEmoji = categories.associate { it.id to it.emoji }

    Column(
        Modifier
            .fillMaxSize()
            .padding(horizontal = 16.dp, vertical = 12.dp)
    ) {
        Row(
            Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                IconButton(
                    onClick = onBack,
                    modifier = Modifier.size(48.dp),
                ) {
                    Icon(
                        Icons.AutoMirrored.Filled.ArrowBack,
                        contentDescription = "Back",
                    )
                }
                Text("Monthly Budgets", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
            }
            TextButton(onClick = onAddBudget) {
                Text("+ Add Cap", fontWeight = FontWeight.SemiBold)
            }
        }

        Spacer(Modifier.height(8.dp))

        if (budgets.isEmpty()) {
            Column(
                Modifier
                    .fillMaxWidth()
                    .weight(1f),
                verticalArrangement = Arrangement.Center,
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text("No budgets set yet", style = MaterialTheme.typography.titleMedium)
                Spacer(Modifier.height(4.dp))
                Text(
                    "Set caps on categories to track spending limits and rollover surplus.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.secondary,
                )
                Spacer(Modifier.height(16.dp))
                Button(onClick = onAddBudget) {
                    Text("Set your first budget")
                }
            }
        } else {
            LazyColumn(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                items(budgets, key = { "b_${it.categoryId}" }) { b ->
                    val carry = carryMap[b.categoryId] ?: 0L
                    val effectiveLimit = b.monthlyLimitPaise + carry
                    val spent = spendMap[b.categoryId] ?: 0L
                    val label = if (b.categoryId == OVERALL_BUDGET_ID) "Overall Monthly Cap"
                    else "${catEmoji[b.categoryId] ?: "🧾"} ${catName[b.categoryId] ?: "Category"}"

                    val ratio = if (effectiveLimit <= 0) 0f else spent.toFloat() / effectiveLimit
                    val over = spent > effectiveLimit
                    val status = when {
                        over -> "${formatPaiseCompact(spent - effectiveLimit)} over cap"
                        else -> "${formatPaiseCompact(effectiveLimit - spent)} remaining"
                    }

                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(8.dp),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant),
                    ) {
                        Column(Modifier.padding(14.dp)) {
                            Row(
                                Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                Text(label, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
                                TextButton(onClick = { deletingBudget = b }) {
                                    Text("Remove", color = MaterialTheme.colorScheme.error, fontSize = 13.sp)
                                }
                            }
                            Row(
                                Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                Text(
                                    "${formatPaiseCompact(spent)} of ${formatPaiseCompact(effectiveLimit)}",
                                    style = TextStyle(fontFamily = TabularNumerals, fontSize = 14.sp),
                                    color = MaterialTheme.colorScheme.onSurface,
                                )
                                Text(
                                    status,
                                    style = TextStyle(
                                        fontFamily = TabularNumerals,
                                        fontSize = 13.sp,
                                        fontWeight = FontWeight.Medium,
                                    ),
                                    color = if (over) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.secondary,
                                )
                            }
                            if (carry > 0) {
                                Spacer(Modifier.height(2.dp))
                                Text(
                                    "+${formatPaiseCompact(carry)} unspent rollover from last month",
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.primary,
                                )
                            }
                            SegmentedMeter(
                                ratio = ratio,
                                activeColor = if (over) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.primary,
                                modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
                            )
                        }
                    }
                }
            }
        }
    }

    deletingBudget?.let { b ->
        val label = if (b.categoryId == OVERALL_BUDGET_ID) "Overall"
        else catName[b.categoryId] ?: "this category"
        AlertDialog(
            onDismissRequest = { deletingBudget = null },
            title = { Text("Remove budget?") },
            text = { Text("Remove the spending limit for $label? Logged transactions will remain unaffected.") },
            confirmButton = {
                TextButton(onClick = {
                    val id = b.categoryId
                    deletingBudget = null
                    scope.launch { vm.removeBudget(id) }
                }) { Text("Remove", color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = { TextButton(onClick = { deletingBudget = null }) { Text("Cancel") } },
        )
    }
}
