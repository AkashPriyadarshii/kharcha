package com.kharcha.app.ui

import android.content.Context
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TimePicker
import androidx.compose.material3.rememberTimePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kharcha.app.BuildConfig
import com.kharcha.app.MainActivity
import com.kharcha.app.capture.CrashLog
import com.kharcha.app.capture.SummaryAlarm
import com.kharcha.app.db.Category
import com.kharcha.app.db.DbBackup
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * Clean, organized Settings Screen:
 * - Profile (Name + Avatar + Offline status)
 * - Auto-Capture & Permissions (Bank SMS, UPI Push Listener, Battery Exemption, Restricted Settings)
 * - Developer & Diagnostics (Console Log, Share Debug Log)
 * - Security (Biometric App Lock)
 * - Data & Backup (CSV Export)
 * - About & Offline Philosophy
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    vm: AppViewModel,
    categories: List<Category>,
    captureSetup: CaptureSetup,
    batteryIgnored: Boolean = true,
    lockEnrollable: Boolean,
    onRequestSms: () -> Unit,
    onRequestNotifications: () -> Unit,
    onOpenListenerSettings: () -> Unit,
    onOpenAppSettings: () -> Unit,
    onRequestIgnoreBattery: () -> Unit,
    onRunIntro: () -> Unit,
    onOpenConsoleLog: () -> Unit,
    onOpenTrash: () -> Unit,
    onOpenRules: () -> Unit,
    onOpenCats: () -> Unit,
    onOpenWallets: () -> Unit,
) {
    val context = LocalContext.current
    val activity = context as? MainActivity
    val scope = rememberCoroutineScope()
    var name by remember { mutableStateOf(UserPrefs.name(context)) }
    var editingName by remember { mutableStateOf(false) }
    var lockEnabled by remember { mutableStateOf(AppLock.isEnabled(context)) }
    var themeMode by remember { mutableStateOf(ThemePrefs.mode(context)) }
    var dynamicOn by remember { mutableStateOf(ThemePrefs.dynamic(context)) }
    var graceMin by remember { mutableStateOf(AppLock.graceMin(context)) }
    var secureOn by remember { mutableStateOf(UserPrefs.secureFlag(context)) }
    var summaryOn by remember { mutableStateOf(UserPrefs.summaryOn(context)) }
    var sumHour by remember { mutableStateOf(UserPrefs.summaryHour(context)) }
    var sumMin by remember { mutableStateOf(UserPrefs.summaryMinute(context)) }
    var showTime by remember { mutableStateOf(false) }
    var confirmWipe by remember { mutableStateOf(false) }
    val version = "${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})"

    Column(
        Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp, vertical = 16.dp),
    ) {
        Text(
            "Settings",
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold,
        )
        Spacer(Modifier.height(16.dp))

        // 1. Profile Section
        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
            elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
        ) {
            Column(Modifier.padding(16.dp)) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Surface(
                        modifier = Modifier.size(48.dp),
                        shape = CircleShape,
                        color = MaterialTheme.colorScheme.primaryContainer,
                    ) {
                        Box(contentAlignment = Alignment.Center) {
                            Text(
                                if (name.isNotBlank()) name.trim().first().uppercase() else "K",
                                fontSize = 20.sp,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.onPrimaryContainer,
                            )
                        }
                    }
                    Spacer(Modifier.width(14.dp))
                    Column(Modifier.weight(1f)) {
                        Text(
                            if (name.isNotBlank()) name else "Kharcha user",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold,
                        )
                        Text(
                            "Version $version · Offline Mode",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.secondary,
                        )
                    }
                    TextButton(onClick = { editingName = !editingName }) {
                        Text(if (editingName) "Done" else "Edit")
                    }
                }

                if (editingName) {
                    Spacer(Modifier.height(12.dp))
                    OutlinedTextField(
                        value = name,
                        onValueChange = { name = it },
                        label = { Text("Display Name") },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth(),
                    )
                    Spacer(Modifier.height(8.dp))
                    Button(
                        onClick = {
                            UserPrefs.setName(context, name.trim())
                            editingName = false
                        },
                        modifier = Modifier.align(Alignment.End),
                    ) {
                        Text("Save Name")
                    }
                }
            }
        }

        Spacer(Modifier.height(20.dp))

        // 1b. Appearance Section
        SectionHeader("Appearance")
        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
            elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
        ) {
            Column(Modifier.padding(16.dp)) {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    listOf("system" to "System", "light" to "Light", "dark" to "Dark").forEach { (v, label) ->
                        FilterChip(
                            selected = themeMode == v,
                            onClick = {
                                themeMode = v
                                ThemePrefs.setMode(context, v)
                                activity?.refreshTheme()
                            },
                            label = { Text(label) },
                        )
                    }
                }
                Spacer(Modifier.height(8.dp))
                Row(
                    Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column(Modifier.weight(1f).padding(end = 12.dp)) {
                        Text("Dynamic color", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
                        Text(
                            "Tint from wallpaper (Monet)",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.secondary,
                        )
                    }
                    Switch(
                        checked = dynamicOn,
                        onCheckedChange = {
                            dynamicOn = it
                            ThemePrefs.setDynamic(context, it)
                            activity?.refreshTheme()
                        },
                    )
                }
            }
        }

        Spacer(Modifier.height(20.dp))

        // 2. Auto-Capture & Reliability Section
        SectionHeader("Auto-Capture & Permissions")
        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
            elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
        ) {
            Column(Modifier.padding(16.dp)) {
                SettingActionRow(
                    title = "Bank SMS Capture",
                    subtitle = if (captureSetup.smsGranted) "Active · Parsing bank spend SMS" else "Disabled · Spend SMS will not be recorded",
                    isDone = captureSetup.smsGranted,
                    actionText = "Enable",
                    onAction = onRequestSms,
                )
                HorizontalDivider(Modifier.padding(vertical = 12.dp), color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f))
                SettingActionRow(
                    title = "UPI Notification Access",
                    subtitle = if (captureSetup.listenerEnabled) "Active · Ingesting GPay, PhonePe, Paytm, etc." else "Disabled · Push alerts ignored",
                    isDone = captureSetup.listenerEnabled,
                    actionText = "Enable",
                    onAction = onOpenListenerSettings,
                )
                HorizontalDivider(Modifier.padding(vertical = 12.dp), color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f))
                SettingActionRow(
                    title = "Battery Optimization Exemption",
                    subtitle = if (batteryIgnored) "Unrestricted · Reliable background capture" else "Restricted · System may kill capture service",
                    isDone = batteryIgnored,
                    actionText = "Exempt",
                    onAction = onRequestIgnoreBattery,
                )
                HorizontalDivider(Modifier.padding(vertical = 12.dp), color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f))
                SettingActionRow(
                    title = "Allow Restricted Settings",
                    subtitle = "For sideloaded APKs on Android 13+ if permissions are greyed out",
                    isDone = false,
                    alwaysAction = true,
                    actionText = "App Info",
                    onAction = onOpenAppSettings,
                )
            }
        }

        Spacer(Modifier.height(20.dp))

        // 3. Diagnostics & Console Log Section
        SectionHeader("Diagnostics & Logs")
        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
            elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
        ) {
            Column(Modifier.padding(16.dp)) {
                Row(
                    Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column(Modifier.weight(1f).padding(end = 12.dp)) {
                        Text("Live Console Log", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
                        Text(
                            "Interactive terminal, custom export/import, live test probe",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.secondary,
                        )
                    }
                    Button(onClick = onOpenConsoleLog, modifier = Modifier.heightIn(min = 40.dp)) {
                        Text("Open Console")
                    }
                }
            }
        }

        Spacer(Modifier.height(20.dp))

        // 4. Security & Privacy Section
        SectionHeader("Security & Privacy")
        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
            elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
        ) {
            Row(
                Modifier.padding(16.dp).fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(Modifier.weight(1f).padding(end = 12.dp)) {
                    Text("App Lock", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
                    Text(
                        if (lockEnrollable) "Require fingerprint, face, or PIN on launch"
                        else "Requires a device screen lock or fingerprint in Android settings",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.secondary,
                    )
                }
                Switch(
                    checked = lockEnabled && lockEnrollable,
                    enabled = lockEnrollable,
                    onCheckedChange = { on ->
                        lockEnabled = on
                        AppLock.setEnabled(context, on)
                    },
                )
            }
            Spacer(Modifier.height(8.dp))
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf(0 to "At once", 1 to "1 min", 5 to "5 min").forEach { (v, label) ->
                    FilterChip(
                        selected = graceMin == v,
                        onClick = {
                            graceMin = v
                            AppLock.setGraceMin(context, v)
                        },
                        label = { Text(label) },
                    )
                }
            }
            Spacer(Modifier.height(8.dp))
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(Modifier.weight(1f).padding(end = 12.dp)) {
                    Text("Hide in app switcher", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
                    Text(
                        "Mask the thumbnail in recent apps",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.secondary,
                    )
                }
                Switch(
                    checked = secureOn,
                    onCheckedChange = {
                        secureOn = it
                        UserPrefs.setSecureFlag(context, it)
                        activity?.applySecureFlag()
                    },
                )
            }
        }

        Spacer(Modifier.height(20.dp))

        // 4b. Notifications Section
        SectionHeader("Notifications")
        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
            elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
        ) {
            Column(Modifier.padding(16.dp)) {
                Row(
                    Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column(Modifier.weight(1f).padding(end = 12.dp)) {
                        Text("Daily summary", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
                        Text(
                            "Today's spend as one push",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.secondary,
                        )
                    }
                    Switch(
                        checked = summaryOn,
                        onCheckedChange = {
                            summaryOn = it
                            UserPrefs.setSummaryOn(context, it)
                            SummaryAlarm.refresh(context)
                        },
                    )
                }
                if (summaryOn) {
                    Spacer(Modifier.height(8.dp))
                    OutlinedButton(
                        onClick = { showTime = true },
                        modifier = Modifier.heightIn(min = 46.dp),
                    ) {
                        Text("At %02d:%02d".format(sumHour, sumMin))
                    }
                }
            }
        }

        if (showTime) {
            val tp = rememberTimePickerState(initialHour = sumHour, initialMinute = sumMin)
            AlertDialog(
                onDismissRequest = { showTime = false },
                title = { Text("Summary time") },
                text = { TimePicker(tp) },
                confirmButton = {
                    TextButton(onClick = {
                        showTime = false
                        sumHour = tp.hour
                        sumMin = tp.minute
                        UserPrefs.setSummaryTime(context, tp.hour, tp.minute)
                        SummaryAlarm.refresh(context)
                    }) { Text("Save") }
                },
                dismissButton = { TextButton(onClick = { showTime = false }) { Text("Cancel") } },
            )
        }

        Spacer(Modifier.height(20.dp))

        // 4c. Manage Section
        SectionHeader("Manage")
        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
            elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
        ) {
            Column(Modifier.padding(16.dp)) {
                SettingActionRow(
                    title = "Rules",
                    subtitle = "Inspect and delete categorization rules",
                    isDone = false,
                    alwaysAction = true,
                    actionText = "Open",
                    onAction = onOpenRules,
                )
                HorizontalDivider(Modifier.padding(vertical = 12.dp), color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f))
                SettingActionRow(
                    title = "Categories",
                    subtitle = "Rename, re-emoji, hide unused",
                    isDone = false,
                    alwaysAction = true,
                    actionText = "Open",
                    onAction = onOpenCats,
                )
                HorizontalDivider(Modifier.padding(vertical = 12.dp), color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f))
                SettingActionRow(
                    title = "Accounts",
                    subtitle = "Rename and archive bank accounts",
                    isDone = false,
                    alwaysAction = true,
                    actionText = "Open",
                    onAction = onOpenWallets,
                )
            }
        }

        Spacer(Modifier.height(20.dp))

        // 5. Data & Backup Section
        SectionHeader("Data & Storage")
        ExportButton(vm, categories, Modifier.fillMaxWidth())
        Spacer(Modifier.height(8.dp))
        val trashCount = vm.trashed.collectAsState().value.size
        val backupLauncher = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/octet-stream")) { uri ->
            if (uri == null) return@rememberLauncherForActivityResult
            scope.launch(Dispatchers.IO) {
                val ok = DbBackup.exportTo(context, uri)
                withContext(Dispatchers.Main) {
                    Toast.makeText(context, if (ok) "Backup saved" else "Backup failed", Toast.LENGTH_LONG).show()
                }
            }
        }
        val restoreLauncher = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
            if (uri == null) return@rememberLauncherForActivityResult
            scope.launch(Dispatchers.IO) {
                // Success restarts the app inside importFrom; only failure returns.
                if (!DbBackup.importFrom(context, uri)) {
                    withContext(Dispatchers.Main) {
                        Toast.makeText(context, "Restore failed — not a valid backup", Toast.LENGTH_LONG).show()
                    }
                }
            }
        }
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedButton(
                onClick = { backupLauncher.launch(DbBackup.fileName()) },
                modifier = Modifier.weight(1f).heightIn(min = 46.dp),
            ) { Text("Backup") }
            OutlinedButton(
                onClick = { restoreLauncher.launch(arrayOf("application/octet-stream")) },
                modifier = Modifier.weight(1f).heightIn(min = 46.dp),
            ) { Text("Restore") }
        }
        Spacer(Modifier.height(8.dp))
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedButton(
                onClick = { CrashLog.export(context) },
                modifier = Modifier.weight(1f).heightIn(min = 46.dp),
            ) { Text("Export log") }
            OutlinedButton(
                onClick = { confirmWipe = true },
                modifier = Modifier.weight(1f).heightIn(min = 46.dp),
            ) { Text("Wipe data", color = MaterialTheme.colorScheme.error) }
        }

        if (confirmWipe) {
            AlertDialog(
                onDismissRequest = { confirmWipe = false },
                title = { Text("Wipe all transactions?") },
                text = { Text("Every transaction is destroyed, including Trash. Rules, budgets and categories stay.") },
                confirmButton = {
                    TextButton(onClick = {
                        confirmWipe = false
                        scope.launch(Dispatchers.IO) {
                            vm.wipeAllTransactions()
                            withContext(Dispatchers.Main) {
                                Toast.makeText(context, "All transactions wiped", Toast.LENGTH_LONG).show()
                            }
                        }
                    }) { Text("Wipe", color = MaterialTheme.colorScheme.error) }
                },
                dismissButton = { TextButton(onClick = { confirmWipe = false }) { Text("Cancel") } },
            )
        }

        Spacer(Modifier.height(8.dp))
        Row(
            Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text("Trash", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
            Text(
                if (trashCount == 0) "Empty" else "$trashCount deleted →",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.primary,
                modifier = Modifier
                    .heightIn(min = 48.dp)
                    .padding(horizontal = 8.dp)
                    .clickable { onOpenTrash() }
                    .semantics { contentDescription = "Open trash" },
            )
        }

        Spacer(Modifier.height(20.dp))

        // 6. Reset & Tour
        SectionHeader("App Setup")
        OutlinedButton(
            onClick = onRunIntro,
            modifier = Modifier.fillMaxWidth().heightIn(min = 46.dp),
            shape = RoundedCornerShape(12.dp),
        ) {
            Text("Re-run Onboarding Setup Tour")
        }

        Spacer(Modifier.height(24.dp))

        // Footer Note
        Text(
            "Kharcha · 100% Offline · No Cloud · Zero AI Analytics",
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.secondary,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(32.dp))
    }
}

@Composable
private fun SectionHeader(title: String) {
    Text(
        text = title,
        style = MaterialTheme.typography.labelLarge,
        fontWeight = FontWeight.Bold,
        color = MaterialTheme.colorScheme.primary,
        modifier = Modifier.padding(bottom = 8.dp, start = 4.dp),
    )
}

@Composable
private fun SettingActionRow(
    title: String,
    subtitle: String,
    isDone: Boolean,
    actionText: String,
    onAction: () -> Unit,
    alwaysAction: Boolean = false,
) {
    Row(
        Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f).padding(end = 12.dp)) {
            Text(title, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurface)
            Spacer(Modifier.height(2.dp))
            Text(subtitle, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.secondary)
        }
        if (isDone && !alwaysAction) {
            Surface(
                shape = CircleShape,
                color = MaterialTheme.colorScheme.primaryContainer,
                modifier = Modifier.size(32.dp),
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Text("✓", color = MaterialTheme.colorScheme.onPrimaryContainer, fontWeight = FontWeight.Bold)
                }
            }
        } else {
            OutlinedButton(onClick = onAction, modifier = Modifier.heightIn(min = 36.dp)) {
                Text(actionText, fontSize = 13.sp)
            }
        }
    }
}