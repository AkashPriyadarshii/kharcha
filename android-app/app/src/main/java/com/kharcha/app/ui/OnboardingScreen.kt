package com.kharcha.app.ui

import android.content.Context
import androidx.compose.foundation.background
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
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
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
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * First-launch flow. 3 steps: name → capture permissions → app lock opt-in.
 * Never shows again (UserPrefs.isOnboarded). Lock runs AFTER onboarding —
 * first launch must not be blocked by a lock nobody set up.
 */
@Composable
fun OnboardingScreen(
    captureSetup: CaptureSetup,
    lockEnrollable: Boolean,
    onRequestSms: () -> Unit,
    onOpenListenerSettings: () -> Unit,
    onDone: (name: String) -> Unit,
) {
    val context = LocalContext.current
    var step by remember { mutableStateOf(0) }
    var name by remember { mutableStateOf(UserPrefs.name(context)) }

    Column(Modifier.fillMaxSize().padding(horizontal = 24.dp)) {
        Spacer(Modifier.height(56.dp))
        // Progress dots
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            repeat(3) { i ->
                Box(
                    Modifier.size(if (i == step) 24.dp else 8.dp).height(8.dp)
                        .clip(CircleShape)
                        .semantics { contentDescription = "Step ${i + 1} of 3" }
                        .background(
                            if (i == step) MaterialTheme.colorScheme.primary
                            else if (i < step) MaterialTheme.colorScheme.primary.copy(alpha = 0.4f)
                            else MaterialTheme.colorScheme.surfaceVariant
                        ),
                )
            }
        }
        Spacer(Modifier.height(32.dp))

        when (step) {
            0 -> {
                Text("Kharcha", style = MaterialTheme.typography.headlineLarge, fontWeight = FontWeight.Bold)
                Spacer(Modifier.height(4.dp))
                Text(
                    "Your expenses, tracked automatically. Every UPI payment lands here — no typing, no cloud, no ads.",
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.secondary,
                )
                Spacer(Modifier.height(32.dp))
                Text("What should we call you?", style = MaterialTheme.typography.titleMedium)
                Spacer(Modifier.height(8.dp))
                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    label = { Text("Your name") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth().semantics { contentDescription = "Your name" },
                )
                Spacer(Modifier.height(12.dp))
                Text(
                    "Optional — used only for your greeting on the home screen. It never leaves this phone.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.secondary,
                )
            }
            1 -> {
                Text("Auto-capture payments", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
                Spacer(Modifier.height(4.dp))
                Text(
                    "Two switches make every GPay / PhonePe / Paytm / BHIM payment appear by itself:",
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.secondary,
                )
                Spacer(Modifier.height(16.dp))
                PermissionCard(
                    title = "SMS messages",
                    body = "Reads payment SMS from your bank apps to record spends.",
                    done = captureSetup.smsGranted,
                    actionLabel = if (captureSetup.smsGranted) "Granted" else "Enable SMS",
                    onAction = onRequestSms,
                )
                Spacer(Modifier.height(12.dp))
                PermissionCard(
                    title = "Notifications",
                    body = "Watches UPI payment notifications from GPay, PhonePe, Paytm, CRED, BHIM and Amazon Pay.",
                    done = captureSetup.listenerEnabled,
                    actionLabel = if (captureSetup.listenerEnabled) "Enabled" else "Enable notifications",
                    onAction = onOpenListenerSettings,
                )
                Spacer(Modifier.height(12.dp))
                Text(
                    "Everything is read on-device and parsed by a local engine. Nothing is uploaded — there is no server.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.secondary,
                )
            }
            2 -> {
                Text("Lock it down", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
                Spacer(Modifier.height(4.dp))
                Text(
                    if (lockEnrollable)
                        "Open the app with your fingerprint or PIN — optional, on by default if you set it."
                    else
                        "App lock needs a fingerprint or PIN set up in system settings first. You can turn it on later from Settings.",
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.secondary,
                )
                Spacer(Modifier.height(24.dp))
                var lockOn by remember { mutableStateOf(lockEnrollable && AppLock.isEnabled(context)) }
                Surface(
                    shape = MaterialTheme.shapes.medium,
                    color = MaterialTheme.colorScheme.surface,
                    tonalElevation = 1.dp,
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
                                else "Not available — no biometrics on this device",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.secondary,
                            )
                        }
                        Switch(
                            checked = lockOn,
                            enabled = lockEnrollable,
                            onCheckedChange = { on ->
                                lockOn = on
                                AppLock.setEnabled(context, on)
                            },
                            modifier = Modifier.semantics { contentDescription = "Toggle app lock" },
                        )
                    }
                }
            }
        }

        Spacer(Modifier.weight(1f))
        if (step > 0) {
            OutlinedButton(
                onClick = { step-- },
                modifier = Modifier.fillMaxWidth().heightIn(min = 52.dp),
            ) { Text("Back") }
            Spacer(Modifier.height(8.dp))
        }
        val last = step == 2
        Button(
            onClick = {
                if (last) { UserPrefs.setName(context, name.trim()); UserPrefs.markOnboarded(context); onDone(name.trim()) }
                else step++
            },
            modifier = Modifier.fillMaxWidth().heightIn(min = 52.dp),
        ) { Text(if (last) "Start tracking" else "Continue", fontSize = 16.sp) }
        Spacer(Modifier.height(32.dp))
    }
}

@Composable
private fun PermissionCard(title: String, body: String, done: Boolean, actionLabel: String, onAction: () -> Unit) {
    Card(
        Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = if (done) MaterialTheme.colorScheme.secondaryContainer else MaterialTheme.colorScheme.surface
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
    ) {
        Column(Modifier.padding(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(title, style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f))
                if (done) Text("✓", color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Bold, fontSize = 20.sp)
            }
            Spacer(Modifier.height(4.dp))
            Text(body, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.secondary)
            Spacer(Modifier.height(12.dp))
            if (!done) {
                Button(onClick = onAction, modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp)) { Text(actionLabel) }
            }
        }
    }
}