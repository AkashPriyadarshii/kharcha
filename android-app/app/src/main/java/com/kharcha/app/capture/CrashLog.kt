package com.kharcha.app.capture

import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.content.FileProvider
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Tiny on-device error log. No INTERNET permission by design, so errors can't
 * leave the phone — but the owner needs to debug crashes on HIS phone, so we
 * append failures + crashes to an app-private file and share it via the
 * Android share sheet (Settings → "Share debug log").
 */
object CrashLog {
    private val stamp = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.ENGLISH)

    private fun file(context: Context): File =
        File(context.filesDir, "kharcha.log")

    /** Log to logcat AND the file — one call, both sinks. */
    fun log(context: Context, tag: String, message: String) {
        Log.w(tag, message)
        try {
            file(context).appendText("${stamp.format(Date())} [$tag] $message\n")
        } catch (_: Exception) {
            // Disk failures must not crash the crash-logger.
        }
    }

    fun crash(context: Context, thread: Thread, throwable: Throwable) {
        log(context, "Crash", "$thread ${throwable.stackTraceToString()}")
    }

    fun export(context: Context) {
        val f = file(context)
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
    }
}