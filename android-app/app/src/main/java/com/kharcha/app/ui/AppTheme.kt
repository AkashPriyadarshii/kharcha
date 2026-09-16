package com.kharcha.app.ui

import android.content.Context
import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
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
    surfaceVariant = Color(0xFFE8E4DA),
    onSurfaceVariant = Color(0xFF5C6B63),
    outline = Color(0xFF7A786F),
    outlineVariant = Color(0xFFD6D1C6),
    error = Color(0xFFBA1A1A),
)

private val DarkColors = darkColorScheme(
    primary = InkGreenDark,
    onPrimary = Color(0xFF003823),
    primaryContainer = Color(0xFF0B4D35),
    onPrimaryContainer = Color(0xFFD3F2E0),
    secondary = Color(0xFFD0D7D1),
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
    onBackground = Color(0xFFF2EFE9),
    surface = Color(0xFF1E1F1A),
    onSurface = Color(0xFFF2EFE9),
    surfaceVariant = Color(0xFF2C2F29),
    onSurfaceVariant = Color(0xFFE2E4DE),
    outline = Color(0xFF8D9488),
    outlineVariant = Color(0xFF4A4E46),
)

@Composable
fun KharchaTheme(darkTheme: Boolean = isSystemInDarkTheme(), dynamicColor: Boolean = false, content: @Composable () -> Unit) {
    val colorScheme = if (dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        val ctx = LocalContext.current
        if (darkTheme) dynamicDarkColorScheme(ctx) else dynamicLightColorScheme(ctx)
    } else if (darkTheme) DarkColors else LightColors
    MaterialTheme(
        colorScheme = colorScheme,
        content = content,
    )
}

/** Appearance prefs: system|light|dark + Monet wallpaper tint. */
object ThemePrefs {
    private const val PREFS = "theme"
    private const val KEY_MODE = "mode"
    private const val KEY_DYNAMIC = "dynamic"

    fun mode(context: Context): String =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY_MODE, "system") ?: "system"

    fun setMode(context: Context, mode: String) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY_MODE, mode).apply()
    }

    fun dynamic(context: Context): Boolean =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(KEY_DYNAMIC, false)

    fun setDynamic(context: Context, on: Boolean) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean(KEY_DYNAMIC, on).apply()
    }
}

/** Tabular numerals and slashed zero so amounts don't jitter and 0/O is distinct. Monospace fallback. */
val TabularNumerals: FontFamily = FontFamily.Monospace
const val NumberFontFeatures: String = "tnum, zero"

/** Split paise into symbol+rupees and optional decimal paise for two-tone typography. */
fun formatPaiseParts(paise: Long): Pair<String, String> {
    val abs = kotlin.math.abs(paise)
    val sign = if (paise < 0) "-" else ""
    val rupees = abs / 100
    val p = abs % 100
    return if (p == 0L && abs >= 10_000L) {
        "${sign}₹%,d".format(rupees) to ""
    } else {
        "${sign}₹%,d".format(rupees) to ".%02d".format(p)
    }
}

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
