package com.kharcha.app.ui

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kharcha.app.capture.CrashLog

@Composable
fun ConsoleLogScreen(
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val logs by CrashLog.liveLogs.collectAsState()
    val listState = rememberLazyListState()
    var filterQuery by remember { mutableStateOf("") }

    // SAF Launchers for custom location export & import
    val exportLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.CreateDocument("text/plain"),
    ) { uri ->
        if (uri != null) {
            val ok = CrashLog.exportToUri(context, uri)
            Toast.makeText(
                context,
                if (ok) "Logs exported successfully" else "Failed to export logs",
                Toast.LENGTH_SHORT
            ).show()
        }
    }

    val importLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.OpenDocument(),
    ) { uri ->
        if (uri != null) {
            val ok = CrashLog.importFromUri(context, uri)
            Toast.makeText(
                context,
                if (ok) "Logs imported successfully" else "Failed to import logs",
                Toast.LENGTH_SHORT
            ).show()
        }
    }

    // Auto-scroll to bottom when new logs arrive
    LaunchedEffect(logs.size) {
        if (logs.isNotEmpty()) {
            listState.animateScrollToItem(logs.size - 1)
        }
    }

    val displayLogs = remember(logs, filterQuery) {
        if (filterQuery.isBlank()) logs
        else logs.filter { it.contains(filterQuery, ignoreCase = true) }
    }

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .padding(16.dp),
    ) {
        // Top Bar
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                TextButton(onClick = onBack) {
                    Text("← Back", fontSize = 16.sp, fontWeight = FontWeight.Bold)
                }
                Spacer(Modifier.width(8.dp))
                Text(
                    "Console Log",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                )
            }
            Text(
                "${logs.size} entries",
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.secondary,
            )
        }

        Spacer(Modifier.height(8.dp))

        // Action Toolbar (Custom Export, Import, Test, Clear, Copy)
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .horizontalScroll(rememberScrollState()),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Button(onClick = {
                exportLauncher.launch("kharcha-console-${System.currentTimeMillis()}.log")
            }) {
                Text("Export...")
            }

            OutlinedButton(onClick = {
                importLauncher.launch(arrayOf("text/*", "*/*"))
            }) {
                Text("Import...")
            }

            OutlinedButton(onClick = {
                CrashLog.log(context, "TestProbe", "Live test log trigger at ${System.currentTimeMillis()}")
            }) {
                Text("Test Log")
            }

            OutlinedButton(onClick = {
                val cm = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                cm.setPrimaryClip(ClipData.newPlainText("Kharcha Console Log", CrashLog.readAll(context)))
                Toast.makeText(context, "All logs copied to clipboard", Toast.LENGTH_SHORT).show()
            }) {
                Text("Copy All")
            }

            OutlinedButton(onClick = { CrashLog.clear(context) }) {
                Text("Clear", color = MaterialTheme.colorScheme.error)
            }
        }

        Spacer(Modifier.height(12.dp))

        // Terminal Output Card
        Card(
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f),
            shape = RoundedCornerShape(8.dp),
            colors = CardDefaults.cardColors(containerColor = Color(0xFF1E1E1E)),
        ) {
            if (displayLogs.isEmpty()) {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        "No console logs recorded yet.",
                        color = Color.LightGray,
                        fontFamily = FontFamily.Monospace,
                        fontSize = 13.sp,
                    )
                }
            } else {
                LazyColumn(
                    state = listState,
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(8.dp),
                ) {
                    itemsIndexed(displayLogs) { _, line ->
                        val textColor = when {
                            line.contains("[Crash]", ignoreCase = true) -> Color(0xFFFF5252)
                            line.contains("[Error]", ignoreCase = true) || line.contains("failed", ignoreCase = true) -> Color(0xFFFF8A80)
                            line.contains("[SmsReceiver]", ignoreCase = true) -> Color(0xFF81D4FA)
                            line.contains("[UpiListener]", ignoreCase = true) -> Color(0xFFB39DDB)
                            line.contains("[CaptureEngine]", ignoreCase = true) -> Color(0xFFA5D6A7)
                            line.contains("[Console]", ignoreCase = true) -> Color(0xFFFFD54F)
                            else -> Color(0xFFE0E0E0)
                        }
                        Text(
                            text = line,
                            color = textColor,
                            fontFamily = FontFamily.Monospace,
                            fontSize = 11.sp,
                            lineHeight = 15.sp,
                            modifier = Modifier.padding(vertical = 2.dp),
                        )
                    }
                }
            }
        }
    }
}
