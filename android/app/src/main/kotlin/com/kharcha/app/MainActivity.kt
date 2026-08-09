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
                        startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                        result.success(null)
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
                        val pm = getSystemService(POWER_SERVICE) as PowerManager
                        if (!pm.isIgnoringBatteryOptimizations(packageName)) {
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
                        startActivity(
                            Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                        )
                        result.success(null)
                    }
                    "getCaptureStatus" -> {
                        val pm = getSystemService(POWER_SERVICE) as PowerManager
                        val enabledListeners = Settings.Secure.getString(
                            contentResolver, "enabled_notification_listeners"
                        ) ?: ""
                        result.success(
                            mapOf(
                                "capture" to enabledListeners.contains(packageName),
                                "notifications" to (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
                                    ContextCompat.checkSelfPermission(
                                        this, Manifest.permission.POST_NOTIFICATIONS
                                    ) == PackageManager.PERMISSION_GRANTED),
                                "battery" to pm.isIgnoringBatteryOptimizations(packageName),
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
                        result.success(packageManager.getPackageInfo(packageName, 0).versionName)
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
                        val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", apk)
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(uri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        startActivity(intent)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    companion object {
        private const val REQ_NOTIFICATIONS = 3001
    }
}
