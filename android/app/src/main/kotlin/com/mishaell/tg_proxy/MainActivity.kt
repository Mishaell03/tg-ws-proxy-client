package com.mishaell.tg_proxy

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.drawable.Icon
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class MainActivity : FlutterActivity() {
    private val channel = "proxy"
    private var pendingLogExport: MethodChannel.Result? = null

    companion object {
        private const val ACTION_TOGGLE_PROXY = "com.mishaell.tg_proxy.TOGGLE_PROXY"
        private const val SHORTCUT_TOGGLE_PROXY = "toggle_proxy"
        private const val NOTIFICATION_PERMISSION_REQUEST_CODE = 1001
        private const val LOG_EXPORT_REQUEST_CODE = 1002
        private const val HEARTBEAT_FRESH_MS = 45_000L
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        installProxyShortcut()
        handleShortcutIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleShortcutIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        requestNotificationPermission()
        requestBatteryOptimizationExemption()

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    ProxySettings.setEnabled(this, true)
                    startProxyService(ProxySettings.toJsonString(this))
                    result.success(true)
                }
                "stop" -> {
                    stopProxyService(this)
                    result.success(true)
                }
                "getSettings" -> result.success(ProxySettings.load(this))
                "saveSettings" -> saveSettings(call.arguments, result)
                "getStatus" -> result.success(proxyStatus())
                "generateSecret" -> result.success(ProxySettings.randomSecret())
                "log" -> {
                    AppLog.append(this, call.argument<String>("message") ?: "UI event")
                    result.success(null)
                }
                "exportLogs" -> exportLogs(result)
                "openTelegram" -> result.success(
                    openTelegram(call.argument<String>("url"))
                )
                else -> result.notImplemented()
            }
        }
    }

    private fun openTelegram(proxyUrl: String?): Boolean {
        val uri = proxyUrl?.let(Uri::parse) ?: return false
        if (uri.scheme != "tg" || uri.host != "proxy") {
            AppLog.append(this, "Rejected invalid Telegram proxy link")
            return false
        }
        val intent = Intent(Intent.ACTION_VIEW, uri)
        return if (intent.resolveActivity(packageManager) != null) {
            startActivity(intent)
            true
        } else {
            AppLog.append(this, "Telegram link handler is unavailable")
            false
        }
    }

    private fun installProxyShortcut() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N_MR1) return

        val shortcutManager = getSystemService(ShortcutManager::class.java)
        val shortcut = ShortcutInfo.Builder(this, SHORTCUT_TOGGLE_PROXY)
            .setShortLabel("Proxy")
            .setLongLabel("Toggle Telegram proxy")
            .setIcon(Icon.createWithResource(this, R.drawable.contour))
            .setIntent(
                Intent(this, MainActivity::class.java).apply {
                    action = ACTION_TOGGLE_PROXY
                }
            )
            .build()

        shortcutManager.dynamicShortcuts = listOf(shortcut)
    }

    private fun handleShortcutIntent(intent: Intent?) {
        if (intent?.action != ACTION_TOGGLE_PROXY) return

        toggleProxyFromShortcut()
        moveTaskToBack(true)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            finishAndRemoveTask()
        } else {
            finish()
        }
    }

    private fun toggleProxyFromShortcut() {
        AppLog.append(this, "Launcher quick action requested proxy toggle")
        ProxyToggle.toggle(this)
    }

    private fun stopProxyService(context: Context) {
        ProxyToggle.stop(context)
    }

    private fun saveSettings(arguments: Any?, result: MethodChannel.Result) {
        try {
            val values = (arguments as? Map<*, *>)
                ?.entries
                ?.associate { it.key.toString() to it.value }
                ?: emptyMap()
            val settings = ProxySettings.save(this, values)
            if (ProxySettings.isEnabled(this)) {
                startProxyService(ProxySettings.toJsonString(this), reload = true)
            }
            result.success(settings)
        } catch (error: IllegalArgumentException) {
            result.error("INVALID_SETTINGS", error.message, null)
        }
    }

    private fun exportLogs(result: MethodChannel.Result) {
        if (pendingLogExport != null) {
            result.error("EXPORT_IN_PROGRESS", "Log export is already open", null)
            return
        }
        pendingLogExport = result
        val fileName = "tg-proxy-logs-${
            SimpleDateFormat("yyyyMMdd-HHmmss", Locale.US).format(Date())
        }.zip"
        startActivityForResult(
            Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "application/zip"
                putExtra(Intent.EXTRA_TITLE, fileName)
            },
            LOG_EXPORT_REQUEST_CODE
        )
    }

    @Deprecated("Deprecated by Android, retained for the Flutter activity result flow")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != LOG_EXPORT_REQUEST_CODE) return
        val result = pendingLogExport ?: return
        pendingLogExport = null
        val destination = data?.data
        if (resultCode != RESULT_OK || destination == null) {
            result.success(false)
            return
        }
        try {
            AppLog.append(this, "Exporting application logs")
            AppLog.export(this, destination)
            result.success(true)
        } catch (error: Exception) {
            AppLog.append(this, "Log export failed: ${error.message}")
            result.error("EXPORT_FAILED", error.message, null)
        }
    }

    private fun requestBatteryOptimizationExemption() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = getSystemService(POWER_SERVICE) as PowerManager
            if (!powerManager.isIgnoringBatteryOptimizations(packageName)) {
                startActivity(Intent().apply {
                    action = android.provider.Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
                    data = Uri.parse("package:$packageName")
                })
            }
        }
    }

    private fun requestNotificationPermission() {
        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                NOTIFICATION_PERMISSION_REQUEST_CODE
            )
        }
    }

    private fun startProxyService(configJson: String, reload: Boolean = false) {
        ProxySettings.setEnabled(this, true)
        val intent = Intent(this, TelegramProxyService::class.java).apply {
            action = if (reload) {
                TelegramProxyService.ACTION_RELOAD_PROXY
            } else {
                TelegramProxyService.ACTION_START_PROXY
            }
            putExtra(TelegramProxyService.EXTRA_CONFIG_JSON, configJson)
        }
        ContextCompat.startForegroundService(this, intent)
    }

    private fun proxyStatus(): Map<String, Any> {
        val enabled = ProxySettings.isEnabled(this)
        val heartbeat = File(filesDir, "proxy.heartbeat")
        val lastHeartbeat = if (heartbeat.exists()) heartbeat.lastModified() else 0L
        val heartbeatAge = if (lastHeartbeat > 0L) {
            (System.currentTimeMillis() - lastHeartbeat).coerceAtLeast(0L)
        } else {
            Long.MAX_VALUE
        }
        val running = enabled && heartbeatAge <= HEARTBEAT_FRESH_MS
        val status = mutableMapOf<String, Any>(
            "enabled" to enabled,
            "running" to running,
            "lastHeartbeatMs" to lastHeartbeat
        )
        if (enabled && !running) {
            val lastError = File(filesDir, "proxy.log")
                .takeIf { it.exists() }
                ?.readLines()
                ?.lastOrNull { it.contains(" ERROR ") }
            if (lastError != null) {
                status["error"] = lastError
                if (
                    lastError.contains("Errno 98") ||
                    lastError.contains("address already in use", ignoreCase = true)
                ) {
                    status["errorCode"] = "PORT_IN_USE"
                    status["errorPort"] = (ProxySettings.load(this)["port"] as? Number)
                        ?.toInt() ?: 1443
                }
            }
        }
        return status
    }
}
