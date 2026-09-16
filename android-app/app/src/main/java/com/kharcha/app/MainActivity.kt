package com.kharcha.app

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.fragment.app.FragmentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.dp
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.viewmodel.compose.viewModel
import com.kharcha.app.ui.AddSheet
import com.kharcha.app.ui.AllTransactionsScreen
import com.kharcha.app.ui.AppLock
import com.kharcha.app.ui.AppViewModel
import com.kharcha.app.ui.BudgetSheet
import com.kharcha.app.ui.ExportButton
import com.kharcha.app.ui.HomeScreen
import com.kharcha.app.ui.KharchaTheme
import kotlinx.coroutines.runBlocking

class MainActivity : FragmentActivity() {
    private var unlocked = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        val permissionLauncher = registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) {}
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            permissionLauncher.launch(arrayOf(Manifest.permission.POST_NOTIFICATIONS))
        }
        if (checkSelfPermission(Manifest.permission.READ_SMS) != PackageManager.PERMISSION_GRANTED) {
            permissionLauncher.launch(arrayOf(Manifest.permission.RECEIVE_SMS, Manifest.permission.READ_SMS))
        }

        // Lock gates content on first resume.
        unlocked = !AppLock.isEnabled(this)
        if (!unlocked) {
            AppLock.promptIfNeeded(this) { ok -> unlocked = ok }
        }

        setContent {
            KharchaTheme {
                if (unlocked) App() else LockedPlaceholder()
            }
        }
    }

    override fun onResume() {
        super.onResume()
        if (AppLock.isEnabled(this) && !unlocked) {
            AppLock.promptIfNeeded(this) { ok -> unlocked = ok }
        }
    }
}

/** Shown while auth is pending (or failed). */
@Composable
private fun LockedPlaceholder() {
    androidx.compose.material3.Text(
        "Locked",
        modifier = Modifier,
        style = androidx.compose.material3.MaterialTheme.typography.headlineMedium,
        color = androidx.compose.material3.MaterialTheme.colorScheme.secondary,
    )
}

@Composable
private fun App() {
    val vm: AppViewModel = viewModel()
    var showAdd by remember { mutableStateOf(false) }
    var showBudget by remember { mutableStateOf(false) }
    var showAll by remember { mutableStateOf(false) }
    val context = LocalContext.current
    val app = context.applicationContext as KharchaApp
    val categories by remember { mutableStateOf(runBlocking { app.database.dao().allCategoriesOnce() }) }
    var lockEnabled by remember { mutableStateOf(AppLock.isEnabled(context)) }

    val categoryName: (Long?) -> String = { id ->
        if (id == null) "Uncategorized" else categories.firstOrNull { it.id == id }?.let { "${it.emoji} ${it.name}" } ?: "?"
    }

    if (showAll) {
        BackHandler { showAll = false }
        androidx.compose.foundation.layout.Column {
            AllTransactionsScreen(vm, categoryName, Modifier.weight(1f))
            ExportButton(vm, Modifier.padding(16.dp))
        }
    } else {
        HomeScreen(
            vm,
            categoryName = categoryName,
            onShowAll = { showAll = true },
            onAdd = { showAdd = true },
            onSetBudget = { showBudget = true },
            lockEnabled = lockEnabled,
            onToggleLock = {
                lockEnabled = it
                AppLock.setEnabled(context, it)
            },
        )
    }

    if (showAdd) AddSheet(vm, categories, onDismiss = { showAdd = false })
    if (showBudget) BudgetSheet(vm, categories, onDismiss = { showBudget = false })
}