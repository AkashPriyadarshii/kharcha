package com.kharcha.app.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
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
import com.kharcha.app.db.Category
import com.kharcha.app.db.TransactionRow
import kotlinx.coroutines.launch

/** Deleted transactions: restore per row or purge forever. */
@Composable
fun TrashScreen(
    vm: AppViewModel,
    categories: List<Category>,
    onBack: () -> Unit,
) {
    val trash by vm.trashed.collectAsState()
    val scope = rememberCoroutineScope()
    var confirmPurge by remember { mutableStateOf(false) }
    val emoji: (Long?) -> String = { id -> categories.firstOrNull { it.id == id }?.emoji ?: "🧾" }
    val name: (Long?) -> String = { id -> categories.firstOrNull { it.id == id }?.name ?: "Uncategorised" }

    Column(Modifier.fillMaxSize().padding(horizontal = 16.dp, vertical = 12.dp)) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
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
                Text("Trash", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
            }
            if (trash.isNotEmpty()) {
                TextButton(onClick = { confirmPurge = true }) {
                    Text("Empty", color = MaterialTheme.colorScheme.error)
                }
            } else {
                Spacer(Modifier.padding(horizontal = 24.dp))
            }
        }
        if (trash.isEmpty()) {
            Text(
                "Nothing deleted — removed transactions land here for restore.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.secondary,
                modifier = Modifier.padding(top = 24.dp),
            )
        } else {
            LazyColumn(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                items(trash, key = { it.id }) { t: TransactionRow ->
                    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                        Box(Modifier.weight(1f)) { TransactionLine(t, emoji(t.categoryId), name(t.categoryId)) }
                        TextButton(onClick = { scope.launch { vm.restoreTransaction(t.id) } }) {
                            Text("Restore")
                        }
                    }
                }
                item { Spacer(Modifier.height(88.dp)) }
            }
        }
    }

    if (confirmPurge) {
        AlertDialog(
            onDismissRequest = { confirmPurge = false },
            title = { Text("Empty trash?") },
            text = { Text("${trash.size} records will be destroyed permanently.") },
            confirmButton = {
                TextButton(onClick = {
                    confirmPurge = false
                    scope.launch { vm.emptyTrash() }
                }) { Text("Empty", color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = { TextButton(onClick = { confirmPurge = false }) { Text("Cancel") } },
        )
    }
}
