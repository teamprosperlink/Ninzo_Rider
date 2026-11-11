package com.prosperlink.ninzo_rider

import android.content.pm.PackageManager
import android.os.Build
import java.security.MessageDigest
import android.content.Intent
import android.os.Bundle
import android.os.Process
import android.os.SystemClock
import android.provider.Settings
import android.view.animation.DecelerateInterpolator
import android.window.SplashScreenView
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pushChannel: MethodChannel? = null

    /** Android 12+'s launch screen, held until the app's first frame is up. */
    private var launchScreen: SplashScreenView? = null
    private var firstFrameUp = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            splashScreen.setOnExitAnimationListener { view ->
                launchScreen = view
                if (firstFrameUp) leaveLaunchScreen()
            }
        }
    }

    /**
     * Back on the app's first screen (Home, Welcome…): the app goes to the
     * background instead of closing, as Android 12+ does for apps' first
     * screens. Opening it again shows the same screen at once, with no
     * restart and no blank launch screen in between.
     */
    override fun popSystemNavigator(): Boolean {
        moveTaskToBack(true)
        return true
    }

    override fun onFlutterUiDisplayed() {
        super.onFlutterUiDisplayed()
        firstFrameUp = true
        leaveLaunchScreen()
    }

    /**
     * The launch screen's Ninzo mark slides up onto the splash's own (54dp above
     * the middle), then the launch screen fades, showing the rest of the splash.
     */
    private fun leaveLaunchScreen() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
        val view = launchScreen ?: return
        launchScreen = null
        val up = -SPLASH_MARK_ABOVE_MIDDLE_DP * resources.displayMetrics.density
        val fade = { view.animate().alpha(0f).setDuration(200).withEndAction { view.remove() }.start() }
        val icon = view.iconView
        if (icon == null) {
            fade()
            return
        }
        icon.animate().translationY(up).setDuration(300).setInterpolator(DecelerateInterpolator())
            .withEndAction { fade() }.start()
    }

    /** The push tap that opened the app, until Dart asks for it. */
    private var launchTap: Map<String, Any?>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Shift pushes with the app's own buttons (ShiftPushes).
        launchTap = tapOf(intent)
        pushChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ninzo/push").apply {
            setMethodCallHandler { call, result ->
                @Suppress("UNCHECKED_CAST")
                val args = call.arguments as? Map<String, Any?> ?: emptyMap()
                when (call.method) {
                    "show" -> {
                        ShiftPushes.show(applicationContext, ShiftPushes.Push.of(args))
                        result.success(null)
                    }
                    "schedule" -> {
                        ShiftPushes.schedule(applicationContext, ShiftPushes.Push.of(args), (args["at"] as Number).toLong())
                        result.success(null)
                    }
                    "cancel" -> {
                        ShiftPushes.cancel(applicationContext, (args["id"] as Number).toInt())
                        result.success(null)
                    }
                    "launch" -> {
                        result.success(launchTap)
                        launchTap = null
                    }
                    else -> result.notImplemented()
                }
            }
        }
        // Shift 42: whether the phone sets its own time, and its date settings.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ninzo/device").setMethodCallHandler { call, result ->
            when (call.method) {
                // How long ago the phone started the app: the splash's 3 s count from then.
                "launchElapsed" -> result.success(
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        SystemClock.elapsedRealtime() - Process.getStartElapsedRealtime()
                    } else {
                        0L
                    },
                )
                "autoTime" -> result.success(Settings.Global.getInt(contentResolver, Settings.Global.AUTO_TIME, 1) == 1)
                // Register 14-16: the map's key, and what a key limited to this app asks for.
                "googleApi" -> result.success(googleApi())
                // The rider API base URL, STAGING_API_URL in .env.
                "appConfig" -> result.success(
                    mapOf("riderApiUrl" to packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
                        .metaData?.getString("ninzo.STAGING_API_URL")),
                )
                "openDateSettings" -> {
                    startActivity(Intent(Settings.ACTION_DATE_SETTINGS))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        tapOf(intent)?.let { pushChannel?.invokeMethod("tapped", it) }
    }

    /** A tap on a shift push: closes it and says which button. Read once. */
    private fun tapOf(intent: Intent?): Map<String, Any?>? {
        if (intent?.action != ShiftPushes.ACTION_TAP) return null
        intent.action = null
        val id = intent.getIntExtra(ShiftPushes.EXTRA_ID, -1)
        getSystemService(android.app.NotificationManager::class.java).cancel(id)
        return mapOf(
            "action" to intent.getStringExtra(ShiftPushes.EXTRA_ACTION),
            "payload" to intent.getStringExtra(ShiftPushes.EXTRA_PAYLOAD),
        )
    }

    private fun googleApi(): Map<String, String?> {
        val info = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
        val signature = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNING_CERTIFICATES)
                .signingInfo?.apkContentsSigners?.firstOrNull()
        } else {
            @Suppress("DEPRECATION")
            packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNATURES).signatures?.firstOrNull()
        }
        val sha1 = signature?.let {
            MessageDigest.getInstance("SHA-1").digest(it.toByteArray()).joinToString("") { b -> "%02X".format(b) }
        }
        return mapOf(
            "key" to info.metaData?.getString("com.google.android.geo.API_KEY"),
            "package" to packageName,
            "sha1" to sha1,
        )
    }
}

/** The splash draws its Ninzo mark this far above the middle (lockup 212dp tall, mark 104dp). */
private const val SPLASH_MARK_ABOVE_MIDDLE_DP = 54f
