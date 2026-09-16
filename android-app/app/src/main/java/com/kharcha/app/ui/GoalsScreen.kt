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
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
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
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.foundation.text.KeyboardOptions
import com.kharcha.app.db.Goal
import kotlinx.coroutines.launch
import uniffi.kharcha_core.parseAmount

/**
 * Dedicated Savings Goals screen: track targets, log manual savings contributions,
 * view progress meters, and manage savings milestones.
 */
@Composable
fun GoalsScreen(
    vm: AppViewModel,
    onBack: () -> Unit,
    onAddGoal: () -> Unit,
) {
    val goals by vm.goals.collectAsState()
    val scope = rememberCoroutineScope()
    var deletingGoal by remember { mutableStateOf<Goal?>(null) }
    var depositingGoal by remember { mutableStateOf<Goal?>(null) }
    var depositAmountText by remember { mutableStateOf("") }
    var depositError by remember { mutableStateOf<String?>(null) }

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
                Text("Savings Goals", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
            }
            TextButton(onClick = onAddGoal) {
                Text("+ New Goal", fontWeight = FontWeight.SemiBold)
            }
        }

        Spacer(Modifier.height(8.dp))

        if (goals.isEmpty()) {
            Column(
                Modifier
                    .fillMaxWidth()
                    .weight(1f),
                verticalArrangement = Arrangement.Center,
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text("No savings goals yet", style = MaterialTheme.typography.titleMedium)
                Spacer(Modifier.height(4.dp))
                Text(
                    "Set a target for an emergency fund, travel, or gadget, and log savings as you go.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.secondary,
                )
                Spacer(Modifier.height(16.dp))
                Button(onClick = onAddGoal) {
                    Text("Create a goal")
                }
            }
        } else {
            LazyColumn(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                items(goals, key = { "g_${it.id}" }) { g ->
                    val target = g.targetPaise
                    val ratio = if (target <= 0) 0f else g.savedPaise.toFloat() / target
                    val done = target > 0 && g.savedPaise >= target
                    val status = if (done) "Target reached ✓" else "${formatPaiseCompact(target - g.savedPaise)} left"

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
                                Text(g.name, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    OutlinedButton(
                                        onClick = {
                                            depositingGoal = g
                                            depositAmountText = ""
                                            depositError = null
                                        },
                                        modifier = Modifier.height(34.dp),
                                    ) {
                                        Text("+ Save", fontSize = 12.sp)
                                    }
                                    IconButton(
                                        onClick = { deletingGoal = g },
                                        modifier = Modifier.size(36.dp),
                                    ) {
                                        Text("×", fontSize = 20.sp, color = MaterialTheme.colorScheme.secondary)
                                    }
                                }
                            }
                            Row(
                                Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                Text(
                                    "${formatPaiseCompact(g.savedPaise)} of ${formatPaiseCompact(target)}",
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
                                    color = if (done) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.secondary,
                                )
                            }
                            SegmentedMeter(
                                ratio = ratio,
                                activeColor = MaterialTheme.colorScheme.primary,
                                modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
                            )
                        }
                    }
                }
            }
        }
    }

    depositingGoal?.let { g ->
        AlertDialog(
            onDismissRequest = { depositingGoal = null },
            title = { Text("Log savings to ${g.name}") },
            text = {
                Column {
                    Text("How much did you set aside?", style = MaterialTheme.typography.bodyMedium)
                    Spacer(Modifier.height(8.dp))
                    OutlinedTextField(
                        value = depositAmountText,
                        onValueChange = {
                            depositAmountText = it
                            depositError = null
                        },
                        label = { Text("Amount (₹)") },
                        singleLine = true,
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                        isError = depositError != null,
                        supportingText = depositError?.let { { Text(it) } },
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            },
            confirmButton = {
                Button(onClick = {
                    val p = parseAmount(depositAmountText)
                    if (p == null || p <= 0) {
                        depositError = "Enter a valid amount"
                        return@Button
                    }
                    val id = g.id
                    depositingGoal = null
                    scope.launch { vm.addSaving(id, p) }
                }) { Text("Save") }
            },
            dismissButton = { TextButton(onClick = { depositingGoal = null }) { Text("Cancel") } },
        )
    }

    deletingGoal?.let { g ->
        AlertDialog(
            onDismissRequest = { deletingGoal = null },
            title = { Text("Delete savings goal?") },
            text = { Text("Delete '${g.name}'? Logged savings data for this target will be removed.") },
            confirmButton = {
                TextButton(onClick = {
                    val id = g.id
                    deletingGoal = null
                    scope.launch { vm.deleteGoal(id) }
                }) { Text("Delete", color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = { TextButton(onClick = { deletingGoal = null }) { Text("Cancel") } },
        )
    }
}
