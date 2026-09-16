package com.kharcha.app.ui

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.graphics.layer.drawLayer
import androidx.compose.ui.graphics.rememberGraphicsLayer
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.FileProvider
import java.io.File
import java.io.FileOutputStream
import java.time.YearMonth
import java.time.format.TextStyle as MonthStyle
import java.util.Locale
import kotlinx.coroutines.launch

/** Pure month-summary card: spend + top-3 merchants with logos. No screen chrome. */
@Composable
fun ShareCardContent(month: YearMonth, totalSpend: Long, top3: List<Pair<String, Long>>) {
    Column(
        Modifier.background(MaterialTheme.colorScheme.surface).padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            "${month.month.getDisplayName(MonthStyle.FULL, Locale.ENGLISH)} ${month.year}",
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.colorScheme.secondary,
        )
        Spacer(Modifier.height(8.dp))
        Text(
            "I spent ${formatPaiseCompact(totalSpend)}",
            fontSize = 30.sp, fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onSurface,
        )
        Spacer(Modifier.height(16.dp))
        top3.forEachIndexed { i, (merchant, amount) ->
            Row(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp))
                    .background(MaterialTheme.colorScheme.surfaceVariant).padding(12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                // ponytail: merchant emoji lookup skipped; BrandAvatar falls back to receipt.
                BrandAvatar(merchant, "🧾", 36.dp)
                Spacer(Modifier.width(12.dp))
                Text(
                    "${i + 1}. $merchant", Modifier.weight(1f),
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onSurface,
                )
                Text(formatPaiseCompact(amount), color = MaterialTheme.colorScheme.secondary)
            }
            Spacer(Modifier.height(8.dp))
        }
        Spacer(Modifier.height(8.dp))
        Text("tracked by Kharcha", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.secondary)
    }
}

/**
 * Renders [card] off-screen via graphics layer → PNG → FileProvider share.
 * Same authority + grant-flags pattern as CrashLog export. 0 deps.
 */
@OptIn(ExperimentalComposeUiApi::class)
@Composable
fun ShareCardSharer(
    context: Context,
    card: @Composable () -> Unit,
    fileName: String = "kharcha-share-${System.currentTimeMillis()}.png",
    onShared: () -> Unit = {},
) {
    val layer = rememberGraphicsLayer()
    val scope = rememberCoroutineScope()
    androidx.compose.material3.Button(onClick = {
        scope.launch {
            val bmp = layer.toImageBitmap().asAndroidBitmap()
            val dir = File(context.cacheDir, "share").apply { mkdirs() }
            val f = File(dir, fileName)
            FileOutputStream(f).use { bmp.compress(Bitmap.CompressFormat.PNG, 100, it) }
            val uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", f)
            context.startActivity(
                Intent(Intent.ACTION_SEND).apply {
                    type = "image/png"
                    putExtra(Intent.EXTRA_STREAM, uri)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }.let { Intent.createChooser(it, "Share") }.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
            onShared()
        }
    }) { Text("Share") }
    Column(Modifier.drawWithContent { drawLayer(layer); drawContent() }) { card() }
}
