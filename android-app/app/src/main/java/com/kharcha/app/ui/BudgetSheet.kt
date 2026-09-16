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
import com.kharcha.app.db.Category
import com.kharcha.app.db.OVERALL_BUDGET_ID
import kotlinx.coroutines.launch
import uniffi.kharcha_core.parseAmount

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BudgetSheet(
    vm: AppViewModel,
    categories: List<Category>,
    onDismiss: () -> Unit,
) {
    var amount by remember { mutableStateOf("") }
    var selectedId by remember { mutableStateOf<Long?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()

    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(Modifier.fillMaxWidth().padding(horizontal = 16.dp).padding(bottom = 32.dp)) {
            Text("Set monthly budget", style = MaterialTheme.typography.titleLarge)
            LazyRow(horizontalArrangement = androidx.compose.foundation.layout.Arrangement.spacedBy(6.dp)) {
                item { FilterChip(selected = selectedId == OVERALL_BUDGET_ID, onClick = { selectedId = OVERALL_BUDGET_ID }, label = { Text("Overall") }) }
                items(categories.filter { !it.isIncome && !it.isHidden }, key = { it.id }) { cat ->
                    FilterChip(selected = selectedId == cat.id, onClick = { selectedId = cat.id }, label = { Text("${cat.emoji} ${cat.name}") })
                }
            }
            OutlinedTextField(
                value = amount,
                onValueChange = { amount = it.filter { c -> c.isDigit() || c == '.' } },
                label = { Text("Monthly limit (₹)") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
            )
            error?.let { Text(it, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall) }
            Button(
                onClick = {
                    val catId = selectedId ?: run { error = "Pick a category"; return@Button }
                    val paise = runCatching { parseAmount(amount.ifBlank { null }) }.getOrNull() ?: run { error = "Enter a valid amount"; return@Button }
                    scope.launch { vm.setBudget(catId, paise) }
                    onDismiss()
                },
                modifier = Modifier.fillMaxWidth().padding(top = 12.dp),
            ) { Text("Save") }
        }
    }
}