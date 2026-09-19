package com.kharcha.app.ui

import androidx.compose.foundation.layout.RowScope
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.navigation.NavHostController
import androidx.navigation.compose.currentBackStackEntryAsState
import com.kharcha.app.capture.CrashLog

/** Bottom-nav destinations. */
internal object Tab {
    const val ROUTE_HOME = "home"
    const val ROUTE_TXN = "transactions"
    const val ROUTE_REPORTS = "reports"
    const val ROUTE_SETTINGS = "settings"
    const val ROUTE_CONSOLE_LOG = "console_log"
    const val ROUTE_TRASH = "trash"
    const val ROUTE_RULES = "rules"
    const val ROUTE_CATS = "categories"
    const val ROUTE_WALLETS = "wallets"
    const val ROUTE_BUDGETS = "budgets"
    const val ROUTE_GOALS = "goals"
}

/** Bottom-bar tab: select state + navigate + nav log in one place (was 4x duplicated in MainActivity). */
@Composable
fun RowScope.TabItem(label: String, icon: ImageVector, route: String, nav: NavHostController) {
    val backStack by nav.currentBackStackEntryAsState()
    NavigationBarItem(
        selected = backStack?.destination?.route == route,
        onClick = {
            CrashLog.log("Navigation", "User navigated to $label")
            nav.navigate(route) {
                popUpTo(nav.graph.startDestinationId) { saveState = true }
                launchSingleTop = true
                restoreState = true
            }
        },
        icon = { Icon(icon, contentDescription = label) },
        label = { Text(label) },
    )
}