package com.kharcha.app.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.input.ImeAction
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

val PaymentMethods = listOf("UPI", "Cash", "Card", "Wallet")

private val dayFmt = SimpleDateFormat("EEE, d MMM", Locale.ENGLISH)

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
    var dateMs by remember { mutableStateOf(System.currentTimeMillis()) }
    var showDate by remember { mutableStateOf(false) }
    var method by remember { mutableStateOf("UPI") }
    var error by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()
    val amountFocus = remember { FocusRequester() }

    val shown = categories.filter { it.isIncome == isIncome }
    val normalizedPreview = merchant.takeIf { it.isNotBlank() }?.let {
        runCatching { normalizeMerchantText(it) }.getOrNull()
    }
    val paisePreview = parseAmount(amount.ifBlank { null })

    LaunchedEffect(Unit) { amountFocus.requestFocus() }

    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(
            Modifier.fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .imePadding()
                .padding(horizontal = 16.dp)
                .padding(bottom = 32.dp),
        ) {
            SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
                SegmentedButton(
                    selected = !isIncome,
                    onClick = { isIncome = false; selectedId = null },
                    shape = SegmentedButtonDefaults.itemShape(0, 2),
                    label = { Text("Expense") },
                )
                SegmentedButton(
                    selected = isIncome,
                    onClick = { isIncome = true; selectedId = null },
                    shape = SegmentedButtonDefaults.itemShape(1, 2),
                    label = { Text("Income") },
                )
            }
            OutlinedTextField(
                value = amount,
                onValueChange = { raw ->
                    // Single optional decimal point, max 2dp while typing.
                    val clean = raw.filter { c -> c.isDigit() || c == '.' }
                    val dot = clean.indexOf('.')
                    amount = if (dot >= 0) {
                        clean.substring(0, dot + 1) + clean.substring(dot + 1).filter { it.isDigit() }.take(2)
                    } else clean.take(12)
                    error = null
                },
                label = { Text("Amount (₹)") },
                placeholder = { Text("₹0") },
                singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number, imeAction = ImeAction.Next),
                textStyle = TextStyle(fontFamily = TabularNumerals, fontSize = 28.sp),
                modifier = Modifier.fillMaxWidth().padding(top = 12.dp).focusRequester(amountFocus),
            )
            OutlinedTextField(
                value = merchant,
                onValueChange = { merchant = it },
                label = { Text(if (isIncome) "From / Source" else "Merchant") },
                singleLine = true,
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Next),
                supportingText = normalizedPreview
                    ?.takeIf { it != merchant }
                    ?.let { { Text("Saved as “$it”") } },
                modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
            )
            OutlinedTextField(
                value = note,
                onValueChange = { note = it },
                label = { Text("Note (optional)") },
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
                keyboardActions = KeyboardActions(onDone = { /* keep sheet open; Save is explicit */ }),
                modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
            )
            Row(Modifier.fillMaxWidth().padding(top = 12.dp), horizontalArrangement = Arrangement.SpaceBetween) {
                TextButton(onClick = { showDate = true }) { Text(dayFmt.format(Date(dateMs))) }
                LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    items(PaymentMethods) { m ->
                        FilterChip(
                            selected = method == m,
                            onClick = { method = m },
                            label = { Text(m) },
                        )
                    }
                }
            }
            Text("Category", style = MaterialTheme.typography.labelLarge, modifier = Modifier.padding(top = 8.dp))
            LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.padding(top = 4.dp)) {
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
                enabled = paisePreview != null,
                onClick = {
                    val paise = paisePreview ?: run {
                        error = "Enter an amount like 240"; return@Button
                    }
                    val name = merchant.ifBlank { "Manual" }
                    scope.launch {
                        vm.saveTransaction(
                            TransactionRow(
                                amountPaise = paise,
                                merchant = runCatching { normalizeMerchantText(name) }.getOrNull() ?: name.trim(),
                                categoryId = selectedId,
                                note = note.ifBlank { null },
                                isIncome = isIncome,
                                timestampMs = dateMs,
                                paymentMethod = method,
                            ),
                        )
                    }
                    onDismiss()
                },
                modifier = Modifier.fillMaxWidth().padding(top = 12.dp),
            ) {
                Text(
                    if (paisePreview != null) "Save ${formatPaiseCompact(paisePreview)}" else "Save",
                )
            }
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
}
