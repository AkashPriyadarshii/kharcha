package com.kharcha.app.ui

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily

// Ink-green on warm paper — kharcha's identity, not Material default blue.
private val InkGreen = Color(0xFF1B5E45)
private val InkGreenDark = Color(0xFF9ED8B8)
private val WarmPaper = Color(0xFFFAF6EE)
private val Ink = Color(0xFF21201C)
val Amber = Color(0xFFB7791F)
val AmberDark = Color(0xFFE0A83C)

private val LightColors = lightColorScheme(
    primary = InkGreen,
    onPrimary = Color.White,
    primaryContainer = Color(0xFFCFEBDD),
    onPrimaryContainer = Ink,
    secondary = Color(0xFF5C6B63),
    tertiary = Amber,
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
    onPrimaryContainer = Color(0xFFD3F2E0),
    secondary = Color(0xFFABC3B6),
    onSecondary = Color(0xFF123025),
    secondaryContainer = Color(0xFF29473B),
    onSecondaryContainer = Color(0xFFCDE9DB),
    tertiary = AmberDark,
    onTertiary = Color(0xFF3F2E00),
    error = Color(0xFFFFB4AB),
    onError = Color(0xFF690005),
    errorContainer = Color(0xFF93000A),
    onErrorContainer = Color(0xFFFFDAD6),
    background = Color(0xFF12120E),
    onBackground = Color(0xFFE8E4DA),
    surface = Color(0xFF191913),
    onSurface = Color(0xFFE8E4DA),
    surfaceVariant = Color(0xFF43483F),
    onSurfaceVariant = Color(0xFFC3C9BE),
    outline = Color(0xFF8D9488),
    outlineVariant = Color(0xFF43483F),
)

@Composable
fun KharchaTheme(darkTheme: Boolean = isSystemInDarkTheme(), content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = if (darkTheme) DarkColors else LightColors,
        content = content,
    )
}

/** Tabular numerals so amounts don't jitter; monospace is universally available. */
val TabularNumerals: FontFamily = FontFamily.Monospace

/** Always-exact ₹ formatting (receipts, export preview). */
fun formatPaise(paise: Long): String {
    val abs = kotlin.math.abs(paise)
    val rupees = abs / 100
    val p = abs % 100
    val sign = if (paise < 0) "-" else ""
    return "${sign}₹%,d.%02d".format(rupees, p)
}

/** Hero/list formatting: hide paise for round ≥₹100 amounts (less noise). */
fun formatPaiseCompact(paise: Long): String {
    val abs = kotlin.math.abs(paise)
    val sign = if (paise < 0) "-" else ""
    return if (abs % 100 == 0L && abs >= 10_000L) {
        "${sign}₹%,d".format(abs / 100)
    } else {
        formatPaise(paise)
    }
}
