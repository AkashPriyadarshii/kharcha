package com.kharcha.app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.provider.Settings
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.SnackbarResult
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.fragment.app.FragmentActivity
import androidx.lifecycle.viewmodel.compose.viewModel
import com.kharcha.app.ui.AddSheet
import com.kharcha.app.ui.AllTransactionsScreen
import com.kharcha.app.ui.AppLock
import com.kharcha.app.ui.OnboardingScreen
import com.kharcha.app.ui.ReportsScreen
import com.kharcha.app.ui.SettingsScreen
import com.kharcha.app.ui.UserPrefs
import com.kharcha.app.ui.AppViewModel
import com.kharcha.app.ui.BudgetSheet
import com.kharcha.app.ui.CaptureSetup
import com.kharcha.app.ui.EditSheet
import com.kharcha.app.ui.ExportButton
import com.kharcha.app.ui.HomeScreen
import com.kharcha.app.ui.KharchaTheme
import com.kharcha.app.ui.formatPaiseCompact
import kotlinx.coroutines.launch

class MainActivity : FragmentActivity() {
    // Compose state (not plain vars): auth results must recompose the content.
    private val unlocked = mutableStateOf(false)
    private val enrolled = mutableStateOf(true)
    private val smsGranted = mutableStateOf(false)
    private val listenerEnabled = mutableStateOf(false)

    private val smsLauncher =
        registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { refreshCaptureState() }

    /** Compose-readable capture state for the onboarding card. */
    val smsState get() = smsGranted
    val listenerState get() = listenerEnabled

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        refreshCaptureState()

        // Fail-closed lock: locked until biometrics pass. No silent unlock.
        unlocked.value = !AppLock.isEnabled(this)
        if (!unlocked.value) {
            AppLock.promptIfNeeded(this) { ok, okEnrolled ->
                enrolled.value = okEnrolled
                unlocked.value = ok
            }
        }

        setContent {
            KharchaTheme {
                if (unlocked.value) App() else LockedPlaceholder(
                    enrolled = enrolled.value,
                    onRetry = {
                        AppLock.promptIfNeeded(this) { ok, okEnrolled ->
                            enrolled.value = okEnrolled
                            unlocked.value = ok
                        }
                    },
                    onDisable = {
                        AppLock.setEnabled(this, false)
                        unlocked.value = true
                    },
                )
            }
        }
    }

    override fun onResume() {
        super.onResume()
        refreshCaptureState()
        if (AppLock.isEnabled(this) && !unlocked.value) {
            AppLock.promptIfNeeded(this) { ok, okEnrolled ->
                enrolled.value = okEnrolled
                unlocked.value = ok
            }
        }
    }

    fun refreshCaptureState() {
        smsGranted.value =
            checkSelfPermission(Manifest.permission.RECEIVE_SMS) == PackageManager.PERMISSION_GRANTED &&
                checkSelfPermission(Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED
        listenerEnabled.value = isNotificationListenerOn()
    }

    fun requestSms() {
        smsLauncher.launch(arrayOf(Manifest.permission.RECEIVE_SMS, Manifest.permission.READ_SMS))
    }

    fun openListenerSettings() {
        startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
    }

    private fun isNotificationListenerOn(): Boolean {
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners") ?: return false
        return flat.split(":").any { it.contains(packageName, ignoreCase = true) }
    }
}

/** Shown while auth is pending (or failed). Fail-closed with retry — never a dead grey wall. */
@Composable
private fun LockedPlaceholder(enrolled: Boolean, onRetry: () -> Unit, onDisable: () -> Unit) {
    Column(
        Modifier.fillMaxSize().padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Spacer(Modifier.height(96.dp))
        Text("🔒", style = MaterialTheme.typography.displayMedium)
        Spacer(Modifier.height(16.dp))
        Text("Kharcha is locked", style = MaterialTheme.typography.headlineSmall)
        Spacer(Modifier.height(8.dp))
        Text(
            if (enrolled) "Unlock with your fingerprint to see your money."
            else "App lock is on, but no fingerprint is set up on this device. Add one in system settings — or turn lock off.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.secondary,
        )
        Spacer(Modifier.height(24.dp))
        if (enrolled) {
            Button(onClick = onRetry, modifier = Modifier.semantics { contentDescription = "Retry unlock" }) {
                Text("Unlock")
            }
        } else {
            Button(onClick = onDisable) { Text("Turn lock off") }
        }
    }
}

@Composable
private fun App() {
    val vm: AppViewModel = viewModel()
    val context = LocalContext.current
    val activity = context as? MainActivity
    var showAdd by remember { mutableStateOf(false) }
    var showBudget by remember { mutableStateOf(false) }
    var showAll by remember { mutableStateOf(false) }
    var showReports by remember { mutableStateOf(false) }
    var showSettings by remember { mutableStateOf(false) }
    var editTxn by remember { mutableStateOf<com.kharcha.app.db.TransactionRow?>(null) }
    var skipOnboarding by remember { mutableStateOf(UserPrefs.isOnboarded(context)) }
    val app = context.applicationContext as KharchaApp
    // Flow collection — no runBlocking on the main thread, always fresh after reseeds.
    val categories by app.database.dao().allCategories().collectAsState(initial = emptyList())
    val snackbar = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()

    LaunchedEffect(Unit) { vm.refreshAll() }

    if (!skipOnboarding) {
        OnboardingScreen(
            captureSetup = CaptureSetup(
                smsGranted = activity?.smsState?.value ?: false,
                listenerEnabled = activity?.listenerState?.value ?: false,
            ),
            lockEnrollable = activity?.let { AppLock.canAuthenticate(it) } ?: true,
            onRequestSms = { activity?.requestSms() },
            onOpenListenerSettings = { activity?.openListenerSettings() },
            onDone = { skipOnboarding = true },
        )
        return
    }

    val showSnackbar: (String, String?, suspend () -> Unit) -> Unit = { message, action, onAction ->
        scope.launch {
            val result = snackbar.showSnackbar(message, actionLabel = action)
            if (result == SnackbarResult.ActionPerformed) onAction()
            else vm.clearUndo()
        }
    }

    when {
        showSettings -> {
            BackHandler { showSettings = false }
            SettingsScreen(
                vm,
                categories,
                captureSetup = CaptureSetup(
                    smsGranted = activity?.smsState?.value ?: false,
                    listenerEnabled = activity?.listenerState?.value ?: false,
                ),
                lockEnrollable = activity?.let { AppLock.canAuthenticate(it) } ?: true,
                onRequestSms = { activity?.requestSms() },
                onOpenListenerSettings = { activity?.openListenerSettings() },
                onBack = { showSettings = false },
            )
        }
        showReports -> {
            BackHandler { showReports = false }
            ReportsScreen(vm, categories, onBack = { showReports = false })
        }
        showAll -> {
            BackHandler { showAll = false }
            Column {
                AllTransactionsScreen(
                    vm,
                    categories,
                    Modifier.weight(1f),
                    onTap = { editTxn = it },
                    onAdd = { showAdd = true },
                )
                ExportButton(vm, categories, Modifier.padding(16.dp))
            }
        }
        else -> HomeScreen(
            vm,
            categories = categories,
            userName = UserPrefs.name(context),
            onShowAll = { showAll = true },
            onReports = { showReports = true },
            onSettings = { showSettings = true },
            onAdd = { showAdd = true },
            onSetBudget = { showBudget = true },
            captureSetup = run {
                val sms = activity?.smsState?.value ?: false
                val listener = activity?.listenerState?.value ?: false
                if (sms && listener) null else CaptureSetup(smsGranted = sms, listenerEnabled = listener)
            },
            onRequestSms = { activity?.requestSms() },
            onOpenListenerSettings = { activity?.openListenerSettings() },
            snackbarHost = snackbar,
        )
    }

    if (showAdd) AddSheet(vm, categories, onDismiss = { showAdd = false })
    if (showBudget) BudgetSheet(vm, categories, onDismiss = { showBudget = false })
    editTxn?.let { txn ->
        EditSheet(
            txn,
            categories,
            vm,
            onDismiss = { editTxn = null },
            onDeleted = { deleted ->
                showSnackbar("Deleted ${deleted.merchant} ${formatPaiseCompact(deleted.amountPaise)}", "Undo") {
                    vm.restoreLastDeleted()
                }
            },
        )
    }
}
