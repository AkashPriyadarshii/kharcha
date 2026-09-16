package com.kharcha.app.ui

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

// Ink-green on warm paper — kharcha's identity, not Material default blue.
private val InkGreen = Color(0xFF1B5E45)
private val InkGreenDark = Color(0xFF9ED8B8)
private val WarmPaper = Color(0xFFFAF6EE)
private val Ink = Color(0xFF21201C)

private val LightColors = lightColorScheme(
    primary = InkGreen,
    onPrimary = Color.White,
    primaryContainer = Color(0xFFCFEBDD),
    onPrimaryContainer = Ink,
    secondary = Color(0xFF5C6B63),
    background = WarmPaper,
    onBackground = Ink,
    surface = Color(0xFFFFFDF7),
    onSurface = Ink,
    error = Color(0xFFBA1A1A),
)

private val DarkColors = darkColorScheme(
    primary = InkGreenDark,
    onPrimary = Color(0xFF003823),
    primaryContainer = Color(0xFF0B4D35),
    onPrimaryContainer = Color(0xFFCFEBDD),
    background = Color(0xFF171713),
    onBackground = Color(0xFFE6E2D8),
    surface = Color(0xFF1E1E19),
    onSurface = Color(0xFFE6E2D8),
)

@Composable
fun KharchaTheme(darkTheme: Boolean = false, content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = if (darkTheme) DarkColors else LightColors,
        content = content,
    )
}

fun formatPaise(paise: Long): String {
    val abs = kotlin.math.abs(paise)
    val rupees = abs / 100
    val p = abs % 100
    return "₹%,d.%02d".format(rupees, p)
}