package com.kharcha.app

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.viewmodel.compose.viewModel
import com.kharcha.app.ui.AddSheet
import com.kharcha.app.ui.AllTransactionsScreen
import com.kharcha.app.ui.AppViewModel
import com.kharcha.app.ui.HomeScreen
import com.kharcha.app.ui.KharchaTheme
import kotlinx.coroutines.runBlocking

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        val smsPermission = registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) {}
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            smsPermission.launch(arrayOf(Manifest.permission.POST_NOTIFICATIONS))
        }
        if (checkSelfPermission(Manifest.permission.READ_SMS) != PackageManager.PERMISSION_GRANTED) {
            smsPermission.launch(arrayOf(Manifest.permission.RECEIVE_SMS, Manifest.permission.READ_SMS))
        }

        setContent {
            KharchaTheme { App() }
        }
    }
}

@Composable
private fun App() {
    val vm: AppViewModel = viewModel()
    var showAdd by remember { mutableStateOf(false) }
    var showAll by remember { mutableStateOf(false) }
    val context = LocalContext.current
    val app = context.applicationContext as KharchaApp
    val categories by remember { mutableStateOf(runBlocking { app.database.dao().allCategoriesOnce() }) }

    val categoryName: (Long?) -> String = { id ->
        if (id == null) "Uncategorized" else categories.firstOrNull { it.id == id }?.let { "${it.emoji} ${it.name}" } ?: "?"
    }

    if (showAll) {
        BackHandler { showAll = false }
        AllTransactionsScreen(vm, categoryName)
    } else {
        HomeScreen(vm, onShowAll = { showAll = true }, onAdd = { showAdd = true }, categoryName = categoryName)
    }

    if (showAdd) {
        AddSheet(vm, categories, onDismiss = { showAdd = false })
    }
}