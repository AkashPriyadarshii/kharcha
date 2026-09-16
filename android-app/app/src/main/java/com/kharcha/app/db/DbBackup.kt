package com.kharcha.app.db

import android.content.Context
import android.net.Uri
import com.kharcha.app.KharchaApp
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Full-file backup / restore (.kharchabackup).
 * VACUUM INTO snapshots a compact consistent copy without closing Room;
 * restore closes Room, swaps the file, and restarts the process.
 */
object DbBackup {
    private val stamp = SimpleDateFormat("yyyyMMdd-HHmm", Locale.ENGLISH)

    fun fileName(): String = "kharcha-${stamp.format(Date())}.kharchabackup"

    /** Compact consistent snapshot under filesDir/backup. Null on failure. */
    fun snapshot(context: Context): File? {
        return try {
            val dir = File(context.filesDir, "backup").apply { mkdirs() }
            val out = File(dir, fileName())
            val app = context.applicationContext as KharchaApp
            app.database.openHelper.writableDatabase.execSQL("VACUUM INTO ?", arrayOf(out.absolutePath))
            out
        } catch (e: Exception) {
            com.kharcha.app.capture.CrashLog.log(context, "DbBackup", "snapshot failed: ${e.message}")
            null
        }
    }

    fun exportTo(context: Context, uri: Uri): Boolean {
        return try {
            val src = snapshot(context) ?: return false
            context.contentResolver.openOutputStream(uri)?.use { o -> src.inputStream().use { it.copyTo(o) } }
                ?: return false
            src.delete()
            true
        } catch (e: Exception) {
            com.kharcha.app.capture.CrashLog.log(context, "DbBackup", "export failed: ${e.message}")
            false
        }
    }

    /**
     * Swap in a picked backup. Validates it opens as SQLite first so a bad
     * file never touches the live DB.
     * ponytail: process restart instead of live reopen — one path, no half-open states.
     */
    fun importFrom(context: Context, uri: Uri): Boolean {
        return try {
            val app = context.applicationContext as KharchaApp
            val tmp = File(context.filesDir, "restore.db")
            context.contentResolver.openInputStream(uri)?.use { i -> tmp.outputStream().use { i.copyTo(it) } }
                ?: return false
            try {
                android.database.sqlite.SQLiteDatabase.openDatabase(
                    tmp.absolutePath, null, android.database.sqlite.SQLiteDatabase.OPEN_READONLY,
                ).close()
            } catch (e: Exception) {
                tmp.delete()
                com.kharcha.app.capture.CrashLog.log(context, "DbBackup", "not a database: ${e.message}")
                return false
            }
            app.database.close()
            val live = context.getDatabasePath("kharcha.db")
            tmp.copyTo(live, overwrite = true)
            tmp.delete()
            File(live.absolutePath + "-wal").delete()
            File(live.absolutePath + "-shm").delete()
            val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            context.startActivity(android.content.Intent.makeRestartActivityTask(launch?.component))
            Runtime.getRuntime().exit(0)
            true
        } catch (e: Exception) {
            com.kharcha.app.capture.CrashLog.log(context, "DbBackup", "import failed: ${e.message}")
            false
        }
    }
}
