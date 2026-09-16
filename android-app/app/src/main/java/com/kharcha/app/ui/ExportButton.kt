package com.kharcha.app.ui

import android.content.Context
import android.os.Environment
import android.widget.Toast
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import com.kharcha.app.KharchaApp
import com.kharcha.app.db.TransactionRow
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

private val exportDateFmt = SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.ENGLISH)

/** CSV export to public Downloads — MediaStore-free (minSdk 32, API 29+ scoped storage). */
@Composable
fun ExportButton(vm: AppViewModel, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val collect = vm.transactions.collectAsState().value
    Button(modifier = modifier, onClick = {
        CoroutineScope(Dispatchers.IO).launch {
            val ok = exportCsv(context, collect)
            kotlinx.coroutines.withContext(Dispatchers.Main) {
                Toast.makeText(context, if (ok) "Exported to Downloads/Kharcha" else "Export failed", Toast.LENGTH_SHORT).show()
            }
        }
    }) { Text("Export CSV") }
}

private fun exportCsv(context: Context, txns: List<TransactionRow>): Boolean {
    return try {
        val dir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        val file = File(dir, "kharcha-${System.currentTimeMillis()}.csv")
        val sb = StringBuilder()
        sb.append("date,amount,merchant,category,note,upiRef,income,needsReview\n")
        for (t in txns) {
            sb.append(exportDateFmt.format(Date(t.timestampMs))).append(',')
                .append(t.amountPaise / 100.0).append(',')
                .append("\"${t.merchant.replace("\"", "\\\"")}\"").append(',')
                .append(t.categoryId ?: "").append(',')
                .append("\"${(t.note ?: "").replace("\"", "\\\"")}\"").append(',')
                .append(t.upiRef ?: "").append(',')
                .append(t.isIncome).append(',')
                .append(t.needsReview).append('\n')
        }
        file.writeText(sb.toString())
        true
    } catch (e: Exception) {
        false
    }
}