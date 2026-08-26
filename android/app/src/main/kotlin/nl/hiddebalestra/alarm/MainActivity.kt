package nl.hiddebalestra.alarm

import android.app.KeyguardManager
import android.app.NotificationManager
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// Bridges two things the `alarm` plugin and `permission_handler` don't cover:
/// Android 14+'s USE_FULL_SCREEN_INTENT runtime toggle, and forcing this
/// Activity to actually show over the lock screen (and wake the display)
/// while an alarm/timer is ringing. The plugin re-launches this same
/// launcher Activity via a full-screen-intent PendingIntent, but without
/// show-when-locked/turn-screen-on the OS can leave the screen off/locked on
/// many devices even though the Activity technically started.
class MainActivity : FlutterActivity() {
    private val channelName = "nl.hiddebalestra.alarm/full_screen_intent"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "isGranted" -> result.success(isFullScreenIntentGranted())
                "openSettings" -> {
                    openFullScreenIntentSettings()
                    result.success(null)
                }
                "showOverLockscreen" -> {
                    showOverLockscreen()
                    result.success(null)
                }
                "restoreLockscreen" -> {
                    restoreLockscreen()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    /// Called right before the ringing screen is shown, so it's visible and
    /// usable even when the device was fully locked/asleep.
    private fun showOverLockscreen() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val keyguardManager = getSystemService(KeyguardManager::class.java)
            keyguardManager?.requestDismissKeyguard(this, null)
        }
    }

    /// Called once the ringing screen is dismissed, so the app doesn't keep
    /// bypassing the lock screen outside of an actual alarm/timer ringing.
    private fun restoreLockscreen() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(false)
            setTurnScreenOn(false)
        } else {
            @Suppress("DEPRECATION")
            window.clearFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }
    }

    private fun isFullScreenIntentGranted(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return true
        val notificationManager = getSystemService(NotificationManager::class.java)
        return notificationManager?.canUseFullScreenIntent() ?: true
    }

    private fun openFullScreenIntentSettings() {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT).apply {
                data = Uri.parse("package:$packageName")
            }
        } else {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            }
        }
        startActivity(intent)
    }
}
