package com.kharcha.app.ui

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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
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
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * 3-step modern onboarding:
 * Step 0: Name & Greeting
 * Step 1: Auto-Capture & Reliability (SMS + Notification Listener + Restricted Settings Guide + Battery Optimization)
 * Step 2: Privacy & App Lock
 */
@Composable
fun OnboardingScreen(
    captureSetup: CaptureSetup,
    batteryIgnored: Boolean = true,
    lockEnrollable: Boolean,
    onRequestSms: () -> Unit,
    onRequestNotifications: () -> Unit,
    onOpenListenerSettings: () -> Unit,
    onOpenAppSettings: () -> Unit,
    onRequestIgnoreBattery: () -> Unit,
    onDone: () -> Unit,
) {
    val context = LocalContext.current
    var step by remember { mutableStateOf(0) }
    var name by remember { mutableStateOf(UserPrefs.name(context)) }

    Surface(
        modifier = Modifier.fillMaxSize(),
        color = MaterialTheme.colorScheme.background,
        contentColor = MaterialTheme.colorScheme.onBackground,
    ) {
        Column(
            Modifier
                .fillMaxSize()
                .padding(horizontal = 24.dp)
                .verticalScroll(rememberScrollState()),
        ) {
            Spacer(Modifier.height(48.dp))

            // Progress Dots
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier.padding(bottom = 16.dp),
            ) {
                repeat(3) { i ->
                    Box(
                        Modifier
                            .size(if (i == step) 28.dp else 8.dp, 8.dp)
                            .clip(CircleShape)
                            .semantics { contentDescription = "Step ${i + 1} of 3" }
                            .background(
                                if (i == step) MaterialTheme.colorScheme.primary
                                else if (i < step) MaterialTheme.colorScheme.primary.copy(alpha = 0.5f)
                                else MaterialTheme.colorScheme.surfaceVariant
                            ),
                    )
                }
            }
            Spacer(Modifier.height(16.dp))

            when (step) {
                0 -> {
                    Text(
                        "Welcome to Kharcha",
                        style = MaterialTheme.typography.headlineLarge,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onBackground,
                    )
                    Spacer(Modifier.height(8.dp))
                    Text(
                        "Track Indian UPI & bank expenses 100% offline. Zero ads, zero cloud, zero telemetry.",
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.secondary,
                    )
                    Spacer(Modifier.height(28.dp))
                    Text(
                        "What should we call you?",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.onBackground,
                    )
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
                        "Used only for your greeting. Stays strictly on this phone.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.secondary,
                    )
                }
                1 -> {
                    Text(
                        "Auto-Capture & Reliability",
                        style = MaterialTheme.typography.headlineSmall,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onBackground,
                    )
                    Spacer(Modifier.height(6.dp))
                    Text(
                        "Kharcha runs an offline Rust engine to record payments automatically.",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.secondary,
                    )
                Spacer(Modifier.height(16.dp))

                // Step 1: SMS Capture
                PermissionCard(
                    title = "1. Bank SMS Capture",
                    body = "Reads transaction SMS alerts from HDFC, SBI, ICICI, Axis, and others.",
                    done = captureSetup.smsGranted,
                    actionLabel = if (captureSetup.smsGranted) "Granted ✓" else "Enable SMS",
                    onAction = onRequestSms,
                )

                Spacer(Modifier.height(10.dp))

                // Step 2: Push Notifications
                PermissionCard(
                    title = "2. UPI App Notification Access",
                    body = "Watches notifications from GPay, PhonePe, Paytm, CRED, BHIM, super.money, Navi, and Tata Neu.",
                    done = captureSetup.listenerEnabled,
                    actionLabel = if (captureSetup.listenerEnabled) "Enabled ✓" else "Enable Access",
                    onAction = onOpenListenerSettings,
                )

                Spacer(Modifier.height(10.dp))

                // Step 3: Sideloaded / Restricted Settings Warning Card
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(12.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                    border = androidx.compose.foundation.BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant),
                    elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
                ) {
                    Column(Modifier.padding(14.dp)) {
                        Text(
                            "⚠️ Android 13+ Restricted Setting Notice",
                            style = MaterialTheme.typography.labelLarge,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.tertiary,
                        )
                        Spacer(Modifier.height(4.dp))
                        Text(
                            "If Notification Access is greyed out ('Restricted setting'), tap 'App Info' below → tap 3-dots in top right → choose 'Allow restricted settings'.",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurface,
                            lineHeight = 16.sp,
                        )
                        Spacer(Modifier.height(8.dp))
                        OutlinedButton(
                            onClick = onOpenAppSettings,
                            modifier = Modifier.heightIn(min = 38.dp),
                        ) {
                            Text("Open App Info (Allow Restricted)", fontSize = 13.sp)
                        }
                    }
                }

                Spacer(Modifier.height(10.dp))

                // Step 4: Battery Optimization Card
                PermissionCard(
                    title = "3. Background Keep-Alive",
                    body = "Prevents aggressive Android battery savers from killing the background UPI listener.",
                    done = batteryIgnored,
                    actionLabel = if (batteryIgnored) "Unrestricted ✓" else "Ignore Optimization",
                    onAction = onRequestIgnoreBattery,
                )
            }
            2 -> {
                Text(
                    "Security & Privacy",
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onBackground,
                )
                Spacer(Modifier.height(8.dp))
                Text(
                    if (lockEnrollable) "Optionally lock Kharcha with your biometric or device screen lock."
                    else "No screen lock or biometric enrolled on this phone yet. You can enable it anytime later in Settings.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.secondary,
                )
                Spacer(Modifier.height(20.dp))

                var lockOn by remember { mutableStateOf(false) }
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(12.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                    elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
                ) {
                    Row(
                        Modifier.padding(16.dp).fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Column(Modifier.weight(1f)) {
                            Text(
                                "App lock on launch",
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.SemiBold,
                                color = MaterialTheme.colorScheme.onSurface,
                            )
                            Text(
                                "Fingerprint, face, or device PIN check",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.secondary,
                            )
                        }
                        Switch(
                            checked = lockOn && lockEnrollable,
                            enabled = lockEnrollable,
                            onCheckedChange = {
                                lockOn = it
                                AppLock.setEnabled(context, it)
                            },
                        )
                    }
                }
            }
        }

        Spacer(Modifier.weight(1f))
        Spacer(Modifier.height(24.dp))

        // Navigation Footer Buttons
        Row(
            Modifier.fillMaxWidth().padding(bottom = 32.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            if (step > 0) {
                TextButton(onClick = { step-- }) {
                    Text("Back", fontSize = 16.sp)
                }
            } else {
                Spacer(Modifier.size(1.dp))
            }

            Button(
                onClick = {
                    if (step == 0) {
                        UserPrefs.setName(context, name.trim())
                    }
                    if (step < 2) {
                        step++
                    } else {
                        UserPrefs.markOnboarded(context)
                        onDone()
                    }
                },
                modifier = Modifier.heightIn(min = 48.dp),
            ) {
                Text(
                    if (step < 2) "Continue" else "Get Started",
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold,
                )
            }
        }
    }
}
}

@Composable
private fun PermissionCard(
    title: String,
    body: String,
    done: Boolean,
    actionLabel: String,
    onAction: () -> Unit,
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        border = androidx.compose.foundation.BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.6f)),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
    ) {
        Row(
            Modifier.padding(16.dp).fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(Modifier.weight(1f).padding(end = 12.dp)) {
                Text(title, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onSurface)
                Spacer(Modifier.height(2.dp))
                Text(body, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.secondary)
            }
            if (done) {
                Surface(
                    shape = CircleShape,
                    color = MaterialTheme.colorScheme.primaryContainer,
                    modifier = Modifier.size(36.dp),
                ) {
                    Box(contentAlignment = Alignment.Center) {
                        Text("✓", color = MaterialTheme.colorScheme.onPrimaryContainer, fontWeight = FontWeight.Bold)
                    }
                }
            } else {
                OutlinedButton(onClick = onAction, modifier = Modifier.heightIn(min = 40.dp)) {
                    Text(actionLabel, fontSize = 13.sp)
                }
            }
        }
    }
}