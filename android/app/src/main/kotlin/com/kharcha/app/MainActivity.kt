package com.kharcha.app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.kharcha.app/capture")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openNotificationListenerSettings" -> {
                        try {
                            startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("activity_not_found", e.message, null)
                        }
                    }
                    "requestNotificationPermission" -> {
                        // Android 13+: request the runtime dialog directly.
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                            ContextCompat.checkSelfPermission(
                                this,
                                Manifest.permission.POST_NOTIFICATIONS
                            ) != PackageManager.PERMISSION_GRANTED
                        ) {
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                                REQ_NOTIFICATIONS
                            )
                        }
                        result.success(true)
                    }
                    "requestBatteryOptimizationExemption" -> {
                        val pm = getSystemService(POWER_SERVICE) as? PowerManager
                        if (pm != null && !pm.isIgnoringBatteryOptimizations(packageName)) {
                            val intent = Intent(
                                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                                Uri.parse("package:$packageName")
                            )
                            try {
                                startActivity(intent)
                            } catch (_: Exception) {
                                // Fallback: the general list if the direct prompt is blocked.
                                startActivity(
                                    Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                                )
                            }
                        }
                        result.success(true)
                    }
                    "openBatteryOptimizationSettings" -> {
                        try {
                            startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("activity_not_found", e.message, null)
                        }
                    }
                    "requestSmsPermission" -> {
                        if (ContextCompat.checkSelfPermission(
                                this, Manifest.permission.RECEIVE_SMS
                            ) != PackageManager.PERMISSION_GRANTED
                        ) {
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(Manifest.permission.RECEIVE_SMS, Manifest.permission.READ_SMS),
                                REQ_SMS
                            )
                        }
                        result.success(true)
                    }
                    "getCaptureStatus" -> {
                        val pm = getSystemService(POWER_SERVICE) as? PowerManager
                        val enabledListeners = Settings.Secure.getString(
                            contentResolver, "enabled_notification_listeners"
                        ) ?: ""
                        result.success(
                            mapOf(
                                "capture" to enabledListeners.contains(packageName),
                                "sms" to (ContextCompat.checkSelfPermission(
                                    this, Manifest.permission.RECEIVE_SMS
                                ) == PackageManager.PERMISSION_GRANTED),
                                "notifications" to (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
                                    ContextCompat.checkSelfPermission(
                                        this, Manifest.permission.POST_NOTIFICATIONS
                                    ) == PackageManager.PERMISSION_GRANTED),
                                "battery" to (pm?.isIgnoringBatteryOptimizations(packageName) == true),
                            )
                        )
                    }
                    else -> result.notImplemented()
                }
            }
        // Auto-update: expose installed version + install a downloaded APK via
        // the system installer (FileProvider, so it works with a debug-signed
        // sideload build).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.kharcha.app/update")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getVersion" -> {
                        try {
                            result.success(packageManager.getPackageInfo(packageName, 0).versionName)
                        } catch (e: Exception) {
                            result.error("version_error", e.message, null)
                        }
                    }
                    "installApk" -> {
                        val path = call.argument<String>("path")
                        if (path == null) {
                            result.error("no_path", "APK path missing", null)
                            return@setMethodCallHandler
                        }
                        val apk = File(path)
                        if (!apk.exists() || apk.length() == 0L) {
                            result.error("missing_apk", "APK not found or empty", null)
                            return@setMethodCallHandler
                        }
                        // Sanity: refuses any update not signed with this app's
                        // cert — protects against a truncated/mismatched APK.
                        try {
                            val uri = FileProvider.getUriForFile(this@MainActivity, "$packageName.fileprovider", apk)
                            val intent = Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(uri, "application/vnd.android.package-archive")
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }
                            startActivity(intent)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("install_error", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.kharcha.app/sms")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "catchUpSms" -> {
                        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) != PackageManager.PERMISSION_GRANTED) {
                            result.success("")
                            return@setMethodCallHandler
                        }
                        
                        val prefs = getSharedPreferences("kharcha_sms_prefs", android.content.Context.MODE_PRIVATE)
                        val sinceMs = prefs.getLong("last_sms_time", System.currentTimeMillis() - 7L * 24 * 60 * 60 * 1000)
                        val newLastSmsTime = System.currentTimeMillis()
                        
                        val amountRe = Regex("""(?:₹|Rs\.?|INR|inr)\s*\d""")
                        val uri = android.net.Uri.parse("content://sms/inbox")
                        val projection = arrayOf("address", "body", "date")
                        val selection = "date > ?"
                        val selectionArgs = arrayOf(sinceMs.toString())
                        val sortOrder = "date ASC"
                        
                        val sb = StringBuilder()
                        
                        try {
                            contentResolver.query(uri, projection, selection, selectionArgs, sortOrder)?.use { cursor ->
                                val bodyIdx = cursor.getColumnIndex("body")
                                val addressIdx = cursor.getColumnIndex("address")
                                val dateIdx = cursor.getColumnIndex("date")
                                
                                while (cursor.moveToNext()) {
                                    val body = cursor.getString(bodyIdx) ?: ""
                                    // Skip non-financial SMS early — no point sending
                                    // OTPs, spam, and marketing to the Dart parser.
                                    if (!amountRe.containsMatchIn(body)) continue
                                    val address = cursor.getString(addressIdx) ?: ""
                                    val date = cursor.getLong(dateIdx)
                                    
                                    val df = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", java.util.Locale.US)
                                    df.timeZone = java.util.TimeZone.getTimeZone("UTC")
                                    val dateStr = df.format(java.util.Date(date))
                                    
                                    val json = org.json.JSONObject()
                                    json.put("package", "sms.$address")
                                    json.put("text", body)
                                    json.put("seenAt", dateStr)
                                    sb.append(json.toString()).append("\n")
                                }
                            }
                            prefs.edit().putLong("last_sms_time", newLastSmsTime).apply()
                            result.success(sb.toString())
                        } catch (e: Exception) {
                            result.error("sms_error", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    companion object {
        private const val REQ_NOTIFICATIONS = 3001
        private const val REQ_SMS = 3002
    }
}
