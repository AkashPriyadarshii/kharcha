package com.kharcha.app.ui

import android.content.ContentValues
import android.content.Context
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.widget.Toast
import androidx.compose.material3.Button
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import com.kharcha.app.db.Category
import com.kharcha.app.db.TransactionRow
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

private val exportDateFmt = SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.ENGLISH)

/** RFC-4180 field: wrap in quotes, double internal quotes. */
private fun csvField(raw: String): String = "\"${raw.replace("\"", "\"\"")}\""

/** Prefix with ' so spreadsheet apps never execute merchant/note text as formulas. */
private fun csvSafeText(raw: String): String {
    val guarded = if (raw.firstOrNull() in listOf('=', '+', '-', '@', '\t')) "'$raw" else raw
    return csvField(guarded)
}

/** CSV export to Downloads via MediaStore (scoped storage, API 29+). Falls back to legacy file pre-Q. */
@Composable
fun ExportButton(
    vm: AppViewModel,
    categories: List<Category>,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val txns = vm.transactions.collectAsState().value
    val scope = rememberCoroutineScope()
    Button(modifier = modifier, onClick = {
        scope.launch(Dispatchers.IO) {
            val result = exportCsv(context, txns, categories)
            withContext(Dispatchers.Main) {
                Toast.makeText(context, result.message, Toast.LENGTH_SHORT).show()
            }
        }
    }) { Text("Export CSV") }
}

data class ExportResult(val ok: Boolean, val message: String)

private fun exportCsv(context: Context, txns: List<TransactionRow>, categories: List<Category>): ExportResult {
    val catName = categories.associate { it.id to it.name }
    return try {
        val name = "kharcha-${System.currentTimeMillis()}.csv"
        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, name)
            put(MediaStore.Downloads.MIME_TYPE, "text/csv")
            put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
        }
        val uri = context.contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
            ?: return ExportResult(false, "Export failed: storage unavailable")

        context.contentResolver.openOutputStream(uri)?.use { os ->
            os.bufferedWriter(Charsets.UTF_8).use { writer ->
                writer.write("date,amount_rupees,merchant,category,note,upi_ref,income,payment_method,needs_review\n")
                for (t in txns) {
                    val rupees = "%d.%02d".format(t.amountPaise / 100, kotlin.math.abs(t.amountPaise % 100))
                    writer.write(exportDateFmt.format(Date(t.timestampMs)))
                    writer.write(",")
                    writer.write(rupees)
                    writer.write(",")
                    writer.write(csvSafeText(t.merchant))
                    writer.write(",")
                    writer.write(csvField(t.categoryId?.let { catName[it] } ?: ""))
                    writer.write(",")
                    writer.write(csvSafeText(t.note ?: ""))
                    writer.write(",")
                    writer.write(csvField(t.upiRef ?: ""))
                    writer.write(",")
                    writer.write(if (t.isIncome) "income" else "expense")
                    writer.write(",")
                    writer.write(csvField(t.paymentMethod ?: ""))
                    writer.write(",")
                    writer.write(t.needsReview.toString())
                    writer.write("\n")
                }
                writer.flush()
            }
        } ?: return ExportResult(false, "Export failed: could not write file")

        ExportResult(true, "Exported ${txns.size} rows to Downloads/$name")
    } catch (e: SecurityException) {
        ExportResult(false, "Export failed: storage permission denied")
    } catch (e: Exception) {
        ExportResult(false, "Export failed: ${e.message ?: "unknown error"}")
    }
}
