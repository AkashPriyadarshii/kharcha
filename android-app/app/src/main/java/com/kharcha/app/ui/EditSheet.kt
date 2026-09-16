package com.kharcha.app.ui

import androidx.compose.foundation.clickable
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
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.kharcha.app.db.Category
import com.kharcha.app.db.RuleRow
import com.kharcha.app.db.TransactionRow
import kotlinx.coroutines.launch

/**
 * Edit a transaction: merchant, note, category. Toggling "remember category"
 * also writes a RuleRow so the merchant auto-categorizes on future captures.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EditSheet(
    txn: TransactionRow,
    categories: List<Category>,
    vm: AppViewModel,
    onDismiss: () -> Unit,
) {
    var merchant by remember { mutableStateOf(txn.merchant) }
    var note by remember { mutableStateOf(txn.note ?: "") }
    var categoryId by remember { mutableStateOf(txn.categoryId) }
    var teachRule by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(Modifier.fillMaxWidth().padding(horizontal = 16.dp).padding(bottom = 32.dp)) {
            Text("Edit transaction", style = MaterialTheme.typography.titleMedium)
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
                label = { Text("Note") },
                modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
            )
            LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.padding(top = 12.dp)) {
                items(categories, key = { it.id }) { cat ->
                    FilterChip(
                        selected = categoryId == cat.id,
                        onClick = { categoryId = cat.id },
                        label = { Text("${cat.emoji} ${cat.name}") },
                    )
                }
            }
            Row(
                Modifier.fillMaxWidth().padding(top = 12.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = androidx.compose.ui.Alignment.CenterVertically,
            ) {
                Text(
                    "Remember category",
                    style = MaterialTheme.typography.bodyMedium,
                    modifier = Modifier.weight(1f).clickable { teachRule = !teachRule },
                )
                androidx.compose.material3.Checkbox(checked = teachRule, onCheckedChange = { teachRule = it })
            }
            Button(
                onClick = {
                    scope.launch {
                        vm.updateTransaction(
                            txn.copy(merchant = merchant.trim(), note = note.trim(), categoryId = categoryId),
                            teachRule,
                        )
                    }
                    onDismiss()
                },
                modifier = Modifier.fillMaxWidth().padding(top = 12.dp),
            ) { Text("Save") }
            TextButton(
                onClick = {
                    scope.launch { vm.deleteTransaction(txn.id) }
                    onDismiss()
                },
                modifier = Modifier.fillMaxWidth(),
            ) { Text("Delete", color = MaterialTheme.colorScheme.error) }
        }
    }
}