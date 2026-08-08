package com.kharcha.app

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.kharcha.app/capture")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openNotificationListenerSettings" -> {
                        val intent =
                            Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                        startActivity(intent)
                        result.success(null)
                    }
                    "openBatteryOptimizationSettings" -> {
                        // System settings page — no permission needed to open.
                        val intent =
                            Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                        startActivity(intent)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
