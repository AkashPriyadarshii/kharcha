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
import kotlinx.coroutines.launch

/** Rename / re-emoji / hide categories. Hidden ones leave pickers; rows keep history. */
@Composable
fun CategoriesScreen(
    vm: AppViewModel,
    categories: List<Category>,
    onBack: () -> Unit,
) {
    val scope = rememberCoroutineScope()
    var editing by remember { mutableStateOf<Category?>(null) }

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
            Text("Categories", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
            Spacer(Modifier.weight(1f))
            TextButton(onClick = { editing = Category(id = -1, name = "", emoji = "") }) { Text("+ New") }
        }
        Spacer(Modifier.height(8.dp))
        LazyColumn(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            items(categories, key = { it.id }) { c ->
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    Text(c.emoji, style = MaterialTheme.typography.titleLarge)
                    Column(Modifier.weight(1f).padding(horizontal = 12.dp)) {
                        Text(c.name, style = MaterialTheme.typography.bodyLarge)
                        if (c.isHidden) {
                            Text("Hidden", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.secondary)
                        }
                    }
                    TextButton(onClick = { editing = c }) { Text("Edit") }
                    Switch(
                        checked = !c.isHidden,
                        onCheckedChange = { scope.launch { vm.setCategoryHidden(c.id, !it) } },
                    )
                }
            }
            item { Spacer(Modifier.height(88.dp)) }
        }
    }

    editing?.let { c ->
        var name by remember(c.id) { mutableStateOf(c.name) }
        var emoji by remember(c.id) { mutableStateOf(c.emoji) }
        val isNew = c.id == -1L
        AlertDialog(
            onDismissRequest = { editing = null },
            title = { Text(if (isNew) "New category" else "Edit category") },
            text = {
                Column {
                    OutlinedTextField(value = name, onValueChange = { name = it }, label = { Text("Name") }, singleLine = true)
                    Spacer(Modifier.height(8.dp))
                    OutlinedTextField(value = emoji, onValueChange = { emoji = it }, label = { Text("Emoji") }, singleLine = true)
                }
            },
            confirmButton = {
                TextButton(onClick = {
                    editing = null
                    if (name.isNotBlank()) scope.launch {
                        if (isNew) vm.addCategory(name.trim(), emoji.ifBlank { "🧾" })
                        else vm.renameCategory(c, name.trim(), emoji.ifBlank { c.emoji })
                    }
                }) { Text("Save") }
            },
            dismissButton = { TextButton(onClick = { editing = null }) { Text("Cancel") } },
        )
    }
}
