package com.kharcha.app.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
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
import androidx.compose.material3.Switch
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
import com.kharcha.app.db.TransactionRow
import kotlinx.coroutines.launch
import uniffi.kharcha_core.normalizeMerchantText
import uniffi.kharcha_core.parseAmount

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddSheet(
    vm: AppViewModel,
    categories: List<Category>,
    onDismiss: () -> Unit,
) {
    var amount by remember { mutableStateOf("") }
    var merchant by remember { mutableStateOf("") }
    var note by remember { mutableStateOf("") }
    var isIncome by remember { mutableStateOf(false) }
    var selectedId by remember { mutableStateOf<Long?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()

    val shown = categories.filter { it.isIncome == isIncome }

    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(Modifier.fillMaxWidth().padding(horizontal = 16.dp).padding(bottom = 32.dp)) {
            Text(if (isIncome) "Add income" else "Add expense", style = MaterialTheme.typography.titleLarge)
            OutlinedTextField(
                value = amount,
                onValueChange = { amount = it.filter { c -> c.isDigit() || c == '.' } },
                label = { Text("Amount (₹)") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
            OutlinedTextField(
                value = merchant,
                onValueChange = { merchant = it },
                label = { Text("Merchant") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
            )
            OutlinedTextField(
                value = note,
                onValueChange = { note = it },
                label = { Text("Note (optional)") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
            )
            Row(Modifier.fillMaxWidth().padding(top = 8.dp), horizontalArrangement = Arrangement.SpaceBetween) {
                Text("Income")
                Switch(checked = isIncome, onCheckedChange = { isIncome = it; selectedId = null })
            }
            LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                items(shown, key = { it.id }) { cat ->
                    FilterChip(
                        selected = selectedId == cat.id,
                        onClick = { selectedId = cat.id },
                        label = { Text("${cat.emoji} ${cat.name}") },
                    )
                }
            }
            error?.let { Text(it, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall) }
            Button(
                onClick = {
                    val paise = parseAmount(amount.ifBlank { null }) ?: run {
                        error = "Enter a valid amount"; return@Button
                    }
                    val name = merchant.ifBlank { "Manual" }
                    scope.launch {
                        vm.saveTransaction(
                            TransactionRow(
                                amountPaise = paise,
                                merchant = normalizeMerchantText(name),
                                categoryId = selectedId,
                                note = note.ifBlank { null },
                                isIncome = isIncome,
                                timestampMs = System.currentTimeMillis(),
                            )
                        )
                        vm.refreshTotals()
                    }
                    onDismiss()
                },
                modifier = Modifier.fillMaxWidth().padding(top = 12.dp),
            ) { Text("Save") }
        }
    }
}