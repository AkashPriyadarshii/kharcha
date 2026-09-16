package com.kharcha.app.capture

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import androidx.core.content.FileProvider
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * High-performance, crash-resilient in-memory circular buffer + persistent file log.
 * - Live StateFlow<List<String>> for instant Compose UI reactivity.
 * - Thread-safe, bounded to 500 lines to prevent OOM/slowdowns.
 * - Direct export/import to custom URIs via Storage Access Framework (SAF).
 * - Clear log, test injection, and system share sheet support.
 */
object CrashLog {
    private const val MAX_ENTRIES = 1000
    private val stamp = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.ENGLISH)

    private val _liveLogs = MutableStateFlow<List<String>>(emptyList())
    val liveLogs: StateFlow<List<String>> = _liveLogs.asStateFlow()

    @Volatile
    private var appContext: Context? = null

    private fun file(context: Context): File =
        File(context.filesDir, "kharcha.log")

    fun init(context: Context) {
        appContext = context.applicationContext
        try {
            val f = file(context)
            if (f.exists()) {
                val lines = f.readLines().takeLast(MAX_ENTRIES)
                _liveLogs.value = lines
            } else {
                _liveLogs.value = listOf("${stamp.format(Date())} [System] Console log initialized.")
            }
        } catch (_: Exception) {
            _liveLogs.value = emptyList()
        }
    }

    /** Log to logcat, memory buffer, and disk file using cached appContext — never throws. */
    fun log(tag: String, message: String) {
        val ctx = appContext
        if (ctx != null) {
            log(ctx, tag, message)
        } else {
            Log.w(tag, message)
        }
    }

    /** Log to logcat, memory buffer, and disk file — never throws. */
    fun log(context: Context, tag: String, message: String) {
        if (appContext == null) {
            appContext = context.applicationContext
        }
        Log.w(tag, message)
        val entry = "${stamp.format(Date())} [$tag] $message"
        synchronized(this) {
            val current = _liveLogs.value.toMutableList()
            if (current.size >= MAX_ENTRIES) {
                current.removeAt(0)
            }
            current.add(entry)
            _liveLogs.value = current
        }
        try {
            file(context).appendText("$entry\n")
        } catch (_: Exception) {
            // Disk write failure must never crash the app
        }
    }

    fun crash(context: Context, thread: Thread, throwable: Throwable) {
        log(context, "Crash", "$thread: ${throwable.stackTraceToString()}")
    }

    fun clear(context: Context) {
        synchronized(this) {
            _liveLogs.value = emptyList()
        }
        try {
            val f = file(context)
            if (f.exists()) f.delete()
        } catch (_: Exception) {}
        log(context, "System", "Logs cleared.")
    }

    fun readAll(context: Context): String {
        return try {
            val f = file(context)
            if (f.exists()) f.readText() else _liveLogs.value.joinToString("\n")
        } catch (_: Exception) {
            _liveLogs.value.joinToString("\n")
        }
    }

    /** Export log to a user-selected custom URI (SAF). */
    fun exportToUri(context: Context, uri: Uri): Boolean {
        return try {
            val content = readAll(context)
            context.contentResolver.openOutputStream(uri)?.use { os ->
                os.write(content.toByteArray(Charsets.UTF_8))
                os.flush()
            }
            log(context, "Console", "Exported logs to custom location: $uri")
            true
        } catch (e: Exception) {
            log(context, "Console", "Export failed: ${e.message}")
            false
        }
    }

    /** Import external log from a user-selected URI (SAF) into Kharcha console. */
    fun importFromUri(context: Context, uri: Uri): Boolean {
        return try {
            val text = context.contentResolver.openInputStream(uri)?.use { inputStream ->
                inputStream.bufferedReader(Charsets.UTF_8).readText()
            } ?: return false

            val lines = text.lines().filter { it.isNotBlank() }.takeLast(MAX_ENTRIES)
            synchronized(this) {
                _liveLogs.value = lines
            }
            file(context).writeText(lines.joinToString("\n") + "\n")
            log(context, "Console", "Imported ${lines.size} log lines from $uri")
            true
        } catch (e: Exception) {
            log(context, "Console", "Import failed: ${e.message}")
            false
        }
    }

    /** Legacy system share-sheet dispatch. */
    fun export(context: Context) {
        try {
            val f = file(context)
            if (!f.exists()) {
                f.writeText("${stamp.format(Date())} [System] Log initialized.\n")
            }
            val uri = FileProvider.getUriForFile(
                context,
                "${context.packageName}.fileprovider",
                f,
            )
            val share = Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                putExtra(Intent.EXTRA_STREAM, uri)
                putExtra(Intent.EXTRA_SUBJECT, "Kharcha debug log")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            context.startActivity(Intent.createChooser(share, "Share Kharcha log"))
        } catch (e: Exception) {
            log(context, "Console", "Share export failed: ${e.message}")
        }
    }
}