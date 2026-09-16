package com.kharcha.app.ui

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.kharcha.app.db.Goal
import kotlinx.coroutines.launch
import uniffi.kharcha_core.parseAmount

/** Savings goals: pick an existing goal to log savings, or New for name + target. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun GoalSheet(
    vm: AppViewModel,
    goals: List<Goal>,
    onDismiss: () -> Unit,
) {
    var amount by remember { mutableStateOf("") }
    var name by remember { mutableStateOf("") }
    var target by remember { mutableStateOf("") }
    var selectedId by remember { mutableStateOf<Long?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()

    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(Modifier.fillMaxWidth().padding(horizontal = 16.dp).padding(bottom = 32.dp)) {
            Text("Savings goals", style = MaterialTheme.typography.titleLarge)
            LazyRow(horizontalArrangement = androidx.compose.foundation.layout.Arrangement.spacedBy(6.dp)) {
                item { FilterChip(selected = selectedId == null, onClick = { selectedId = null }, label = { Text("+ New") }) }
                items(goals, key = { it.id }) { g ->
                    FilterChip(selected = selectedId == g.id, onClick = { selectedId = g.id }, label = { Text(g.name) })
                }
            }
            if (selectedId == null) {
                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    label = { Text("Goal name (e.g. Emergency fund)") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
                )
                OutlinedTextField(
                    value = target,
                    onValueChange = { target = it.filter { c -> c.isDigit() || c == '.' } },
                    label = { Text("Target (₹)") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
                )
            } else {
                OutlinedTextField(
                    value = amount,
                    onValueChange = { amount = it.filter { c -> c.isDigit() || c == '.' } },
                    label = { Text("Add savings (₹)") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
                )
            }
            error?.let { Text(it, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall) }
            Button(
                onClick = {
                    val id = selectedId
                    if (id == null) {
                        if (name.isBlank()) run { error = "Name the goal"; return@Button }
                        val t = runCatching { parseAmount(target.ifBlank { null }) }.getOrNull() ?: run { error = "Enter a valid target"; return@Button }
                        scope.launch { vm.setGoal(name.trim(), t) }
                    } else {
                        val p = runCatching { parseAmount(amount.ifBlank { null }) }.getOrNull() ?: run { error = "Enter a valid amount"; return@Button }
                        scope.launch { vm.addSaving(id, p) }
                    }
                    onDismiss()
                },
                modifier = Modifier.fillMaxWidth().padding(top = 12.dp),
            ) { Text("Save") }
        }
    }
}
