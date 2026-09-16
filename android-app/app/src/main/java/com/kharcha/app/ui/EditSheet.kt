package com.kharcha.app.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kharcha.app.db.Category
import com.kharcha.app.db.TransactionRow
import kotlinx.coroutines.launch
import uniffi.kharcha_core.normalizeMerchantText
import uniffi.kharcha_core.parseAmount
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

private val editDayFmt = SimpleDateFormat("EEE, d MMM yyyy", Locale.ENGLISH)

/**
 * Edit a transaction: amount, merchant, note, category, date, payment method.
 * Toggling "remember category" writes a RuleRow so the merchant auto-categorizes.
 * Delete asks for confirmation; undo is offered via Snackbar by the caller.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EditSheet(
    txn: TransactionRow,
    categories: List<Category>,
    vm: AppViewModel,
    onDismiss: () -> Unit,
    onDeleted: (TransactionRow) -> Unit = {},
) {
    var amount by remember { mutableStateOf("%d.%02d".format(txn.amountPaise / 100, kotlin.math.abs(txn.amountPaise % 100))) }
    var merchant by remember { mutableStateOf(txn.merchant) }
    var note by remember { mutableStateOf(txn.note ?: "") }
    var categoryId by remember { mutableStateOf(txn.categoryId) }
    var dateMs by remember { mutableStateOf(txn.timestampMs) }
    var showDate by remember { mutableStateOf(false) }
    var method by remember { mutableStateOf(txn.paymentMethod ?: "UPI") }
    var teachRule by remember { mutableStateOf(false) }
    var confirmDelete by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()

    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(
            Modifier.fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .imePadding()
                .padding(horizontal = 16.dp)
                .padding(bottom = 32.dp),
        ) {
            Text("Edit transaction", style = MaterialTheme.typography.titleMedium)
            OutlinedTextField(
                value = amount,
                onValueChange = {
                    amount = it.filter { c -> c.isDigit() || c == '.' }
                    error = null
                },
                label = { Text("Amount (₹)") },
                singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                textStyle = TextStyle(fontFamily = TabularNumerals, fontSize = 24.sp),
                modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
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
                label = { Text("Note") },
                modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
            )
            Row(Modifier.fillMaxWidth().padding(top = 12.dp), horizontalArrangement = Arrangement.SpaceBetween) {
                TextButton(onClick = { showDate = true }) { Text(editDayFmt.format(Date(dateMs))) }
                LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    items(PaymentMethods) { m ->
                        FilterChip(selected = method == m, onClick = { method = m }, label = { Text(m) })
                    }
                }
            }
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
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    "Remember category",
                    style = MaterialTheme.typography.bodyMedium,
                    modifier = Modifier.weight(1f).clickable { teachRule = !teachRule },
                )
                androidx.compose.material3.Checkbox(checked = teachRule, onCheckedChange = { teachRule = it })
            }
            error?.let { Text(it, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall) }
            Button(
                onClick = {
                    val paise = parseAmount(amount.ifBlank { null }) ?: run {
                        error = "Enter an amount like 240"; return@Button
                    }
                    val cleanMerchant = merchant.trim().ifEmpty { txn.merchant }
                    scope.launch {
                        vm.updateTransaction(
                            txn.copy(
                                amountPaise = paise,
                                merchant = runCatching { normalizeMerchantText(cleanMerchant) }.getOrNull() ?: cleanMerchant,
                                note = note.trim().ifEmpty { null },
                                categoryId = categoryId,
                                timestampMs = dateMs,
                                paymentMethod = method,
                            ),
                            teachRule,
                        )
                    }
                    onDismiss()
                },
                modifier = Modifier.fillMaxWidth().padding(top = 12.dp),
            ) { Text("Save") }
            TextButton(
                onClick = { confirmDelete = true },
                modifier = Modifier.fillMaxWidth(),
            ) { Text("Delete", color = MaterialTheme.colorScheme.error) }
        }
    }

    if (showDate) {
        val state = rememberDatePickerState(initialSelectedDateMillis = dateMs)
        DatePickerDialog(
            onDismissRequest = { showDate = false },
            confirmButton = {
                TextButton(onClick = {
                    state.selectedDateMillis?.let { dateMs = it }
                    showDate = false
                }) { Text("OK") }
            },
            dismissButton = { TextButton(onClick = { showDate = false }) { Text("Cancel") } },
        ) { DatePicker(state) }
    }

    if (confirmDelete) {
        AlertDialog(
            onDismissRequest = { confirmDelete = false },
            title = { Text("Delete \"${txn.merchant} ${formatPaiseCompact(txn.amountPaise)}\"?") },
            text = { Text("This removes the record permanently. You can undo right after.") },
            confirmButton = {
                TextButton(onClick = {
                    confirmDelete = false
                    scope.launch {
                        val deleted = vm.deleteTransaction(txn.id)
                        if (deleted != null) onDeleted(deleted)
                    }
                    onDismiss()
                }) { Text("Delete", color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = { TextButton(onClick = { confirmDelete = false }) { Text("Cancel") } },
        )
    }
}
