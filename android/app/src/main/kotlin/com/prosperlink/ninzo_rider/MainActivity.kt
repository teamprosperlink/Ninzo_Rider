package com.prosperlink.ninzo_rider

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Shift 42: whether the phone sets its own time, and its date settings.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ninzo/device").setMethodCallHandler { call, result ->
            when (call.method) {
                "autoTime" -> result.success(Settings.Global.getInt(contentResolver, Settings.Global.AUTO_TIME, 1) == 1)
                "openDateSettings" -> {
                    startActivity(Intent(Settings.ACTION_DATE_SETTINGS))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
