package com.kharcha.app.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.kharcha.app.db.Wallet
import kotlinx.coroutines.launch

/** Detected accounts: rename for humans, archive the dead ones. History stays. */
@Composable
fun WalletsScreen(
    vm: AppViewModel,
    onBack: () -> Unit,
) {
    val wallets by vm.wallets.collectAsState()
    val scope = rememberCoroutineScope()
    var renaming by remember { mutableStateOf<Wallet?>(null) }
    var balancing by remember { mutableStateOf<Wallet?>(null) }

    Column(Modifier.fillMaxSize().padding(horizontal = 16.dp, vertical = 12.dp)) {
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            IconButton(
                onClick = onBack,
                modifier = Modifier.size(48.dp),
            ) {
                Icon(
                    Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = "Back",
                )
            }
            Text("Accounts", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
        }
        Spacer(Modifier.height(8.dp))
        if (wallets.isEmpty()) {
            Text(
                "No accounts yet — they appear when bank SMS names them.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.secondary,
                modifier = Modifier.padding(top = 24.dp),
            )
        } else {
            LazyColumn(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                items(wallets, key = { it.id }) { w ->
                    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text(w.name, style = MaterialTheme.typography.bodyLarge)
                            Text(
                                if (w.isArchived) "Archived"
                                else w.balancePaise?.let { "Balance ${formatPaiseCompact(it)}" } ?: "Balance unknown",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.secondary,
                            )
                        }
                        TextButton(onClick = { renaming = w }) { Text("Rename") }
                        TextButton(onClick = { balancing = w }) { Text("Balance") }
                        Switch(
                            checked = !w.isArchived,
                            onCheckedChange = { scope.launch { vm.setWalletArchived(w.id, !it) } },
                        )
                    }
                }
                item { Spacer(Modifier.height(88.dp)) }
            }
        }
    }

    renaming?.let { w ->
        var name by remember(w.id) { mutableStateOf(w.name) }
        AlertDialog(
            onDismissRequest = { renaming = null },
            title = { Text("Rename account") },
            text = {
                OutlinedTextField(value = name, onValueChange = { name = it }, label = { Text("Name") }, singleLine = true)
            },
            confirmButton = {
                TextButton(onClick = {
                    renaming = null
                    if (name.isNotBlank()) scope.launch { vm.renameWallet(w.id, name.trim()) }
                }) { Text("Save") }
            },
            dismissButton = { TextButton(onClick = { renaming = null }) { Text("Cancel") } },
        )
    }

    balancing?.let { w ->
        var amount by remember(w.id) { mutableStateOf("") }
        var error by remember(w.id) { mutableStateOf<String?>(null) }
        AlertDialog(
            onDismissRequest = { balancing = null },
            title = { Text("Set balance") },
            text = {
                Column {
                    Text(
                        "Corrects drift from unlogged cash. Overwrites the SMS-tracked figure.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.secondary,
                    )
                    Spacer(Modifier.height(8.dp))
                    OutlinedTextField(
                        value = amount,
                        onValueChange = { amount = it.filter { c -> c.isDigit() || c == '.' } },
                        label = { Text("Balance (₹)") },
                        singleLine = true,
                    )
                    error?.let { Text(it, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall) }
                }
            },
            confirmButton = {
                TextButton(onClick = {
                    val p = runCatching { uniffi.kharcha_core.parseAmount(amount.ifBlank { null }) }.getOrNull()
                    if (p == null) { error = "Enter a valid amount"; return@TextButton }
                    balancing = null
                    scope.launch { vm.setWalletBalance(w.id, p) }
                }) { Text("Save") }
            },
            dismissButton = { TextButton(onClick = { balancing = null }) { Text("Cancel") } },
        )
    }
}
