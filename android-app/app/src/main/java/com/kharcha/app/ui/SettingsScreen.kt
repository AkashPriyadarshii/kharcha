package com.kharcha.app.ui

import android.content.Context
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
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
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
import com.kharcha.app.db.Category

/**
 * Settings: profile (name), capture status, app lock, export, version.
 * Also the offline "update" UX — this app has no INTERNET permission by
 * design (fully offline), so updates are manual sideloads of the APK from
 * the GitHub release. That is stated plainly instead of a dead check button.
 */
@Composable
fun SettingsScreen(
    vm: AppViewModel,
    categories: List<Category>,
    captureSetup: CaptureSetup,
    lockEnrollable: Boolean,
    onRequestSms: () -> Unit,
    onOpenListenerSettings: () -> Unit,
    onRunIntro: () -> Unit,
    onShareLog: () -> Unit,
) {
    val context = LocalContext.current
    var name by remember { mutableStateOf(UserPrefs.name(context)) }
    var editingName by remember { mutableStateOf(false) }
    var lockEnabled by remember { mutableStateOf(AppLock.isEnabled(context)) }
    val version = "${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})"

    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
        Text(
            "Settings",
            style = MaterialTheme.typography.titleLarge,
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp),
        )

        Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            // Profile
            Card(
                Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
            ) {
                Column(Modifier.fillMaxWidth().padding(16.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Box(
                            Modifier.size(48.dp).clip(CircleShape)
                                .background(MaterialTheme.colorScheme.primaryContainer),
                            contentAlignment = Alignment.Center,
                        ) {
                            Text(
                                if (name.isNotBlank()) name.trim().first().uppercase() else "K",
                                fontSize = 22.sp, fontWeight = FontWeight.Bold,
                            )
                        }
                        Spacer(Modifier.width(12.dp))
                        Column(Modifier.weight(1f)) {
                            Text(if (name.isNotBlank()) name else "Kharcha user", style = MaterialTheme.typography.titleMedium)
                            Text("v$version", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.secondary)
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
                            label = { Text("Your name") },
                            singleLine = true,
                            modifier = Modifier.fillMaxWidth().semantics { contentDescription = "Your name" },
                        )
                        Spacer(Modifier.height(8.dp))
                        TextButton(onClick = {
                            UserPrefs.setName(context, name.trim())
                            editingName = false
                        }) { Text("Save name") }
                    }
                }
            }

            // Capture
            SectionTitle("Capture")
            Card(
                Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
            ) {
                Column(Modifier.padding(16.dp)) {
                    SettingRow(
                        title = "SMS messages",
                        subtitle = if (captureSetup.smsGranted) "On — payment SMS are parsed" else "Off — spend SMS are ignored",
                        trailing = {
                            if (!captureSetup.smsGranted) {
                                OutlinedButton(onClick = onRequestSms, modifier = Modifier.heightIn(min = 44.dp)) {
                                    Text("Enable")
                                }
                            } else Text("✓", color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Bold, fontSize = 18.sp)
                        },
                    )
                    HorizontalRule()
                    SettingRow(
                        title = "Notifications",
                        subtitle = if (captureSetup.listenerEnabled) "On — UPI app notifications are watched"
                        else "Off — push payment alerts are ignored",
                        trailing = {
                            if (!captureSetup.listenerEnabled) {
                                OutlinedButton(onClick = onOpenListenerSettings, modifier = Modifier.heightIn(min = 44.dp)) {
                                    Text("Enable")
                                }
                            } else Text("✓", color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Bold, fontSize = 18.sp)
                        },
                    )
                }
            }

            // Debug log
            Card(
                Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
            ) {
                SettingRow(
                    title = "Share debug log",
                    subtitle = "Errors + crashes are saved here",
                    trailing = {
                        OutlinedButton(onClick = onShareLog, modifier = Modifier.heightIn(min = 44.dp)) { Text("Share") }
                    },
                )
            }

            // Security
            SectionTitle("Security")
            Card(
                Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
            ) {
                Row(
                    Modifier.fillMaxWidth().padding(16.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column(Modifier.weight(1f)) {
                        Text("App lock", style = MaterialTheme.typography.bodyLarge)
                        Text(
                            if (lockEnrollable) "Fingerprint or PIN before the app opens"
                            else "Needs a fingerprint/PIN in system settings first",
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
                        modifier = Modifier.semantics { contentDescription = "Toggle app lock" },
                    )
                }
            }

            // Data
            SectionTitle("Data")
            ExportButton(vm, categories, Modifier.fillMaxWidth())

            // Setup
            SectionTitle("Setup")
            OutlinedButton(onClick = onRunIntro, modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp)) {
                Text("Run setup tour again (name, capture, lock)")
            }

            // About / updates
            SectionTitle("About")
            Card(
                Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.secondaryContainer),
            ) {
                Column(Modifier.padding(16.dp)) {
                    Text("Updates", style = MaterialTheme.typography.titleSmall)
                    Spacer(Modifier.height(4.dp))
                    Text(
                        "Kharcha is fully offline — no internet permission, so it cannot check for updates itself. " +
                            "New versions are installed as an APK from the GitHub release page; your data stays on this phone.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSecondaryContainer,
                    )
                }
            }
            Text(
                "Made in India · Money data never leaves this device · No ads, no cloud, no AI",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.secondary,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp),
            )
            Spacer(Modifier.height(24.dp))
        }
    }
}

@Composable
private fun SectionTitle(text: String) {
    Text(
        text,
        style = MaterialTheme.typography.labelMedium,
        color = MaterialTheme.colorScheme.secondary,
        modifier = Modifier.padding(top = 8.dp),
    )
}

@Composable
private fun SettingRow(title: String, subtitle: String, trailing: @Composable () -> Unit) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f).padding(end = 12.dp)) {
            Text(title, style = MaterialTheme.typography.bodyLarge)
            Text(subtitle, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.secondary)
        }
        trailing()
    }
}

@Composable
private fun HorizontalRule() {
    Box(
        Modifier.fillMaxWidth().height(1.dp).padding(vertical = 8.dp)
            .background(MaterialTheme.colorScheme.surfaceVariant),
    )
}