package com.example.tg_proxy

import android.app.ActivityManager
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.content.ContextCompat
import java.io.File

class ProxyBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (
            action != Intent.ACTION_BOOT_COMPLETED &&
            action != TelegramProxyService.ACTION_RESTART_PROXY &&
            action != TelegramProxyService.ACTION_WATCHDOG &&
            action != Intent.ACTION_SCREEN_ON &&
            action != Intent.ACTION_USER_PRESENT
        ) {
            return
        }

        try {
            if (action == TelegramProxyService.ACTION_WATCHDOG ||
                action == Intent.ACTION_SCREEN_ON ||
                action == Intent.ACTION_USER_PRESENT
            ) {
                scheduleNextWatchdog(context)
                if (isProxyHeartbeatStale(context)) {
                    restartStuckProxy(context)
                    return
                }
            }

            ContextCompat.startForegroundService(
                context,
                Intent(context, TelegramProxyService::class.java)
            )
        } catch (error: RuntimeException) {
            Log.e("ProxyBootReceiver", "Unable to start proxy for $action", error)
        }
    }

    private fun scheduleNextWatchdog(context: Context) {
        val intent = Intent(context, ProxyBootReceiver::class.java).apply {
            action = TelegramProxyService.ACTION_WATCHDOG
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            WATCHDOG_REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val triggerAt = System.currentTimeMillis() + WATCHDOG_INTERVAL_MS
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && alarmManager.canScheduleExactAlarms()) {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerAt,
                pendingIntent
            )
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerAt,
                pendingIntent
            )
        } else {
            alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
        }
    }

    private fun isProxyHeartbeatStale(context: Context): Boolean {
        val heartbeat = File(context.filesDir, HEARTBEAT_FILE)
        return heartbeat.exists() &&
            System.currentTimeMillis() - heartbeat.lastModified() > HEARTBEAT_STALE_MS
    }

    private fun restartStuckProxy(context: Context) {
        Log.w(TAG, "Proxy heartbeat is stale; restarting :proxy process")
        val activityManager =
            context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val proxyProcess = activityManager.runningAppProcesses
            ?.firstOrNull { it.processName == "${context.packageName}:proxy" }
        if (proxyProcess != null) {
            android.os.Process.killProcess(proxyProcess.pid)
        }

        ContextCompat.startForegroundService(
            context,
            Intent(context, TelegramProxyService::class.java)
        )
    }

    companion object {
        private const val TAG = "ProxyBootReceiver"
        private const val HEARTBEAT_FILE = "proxy.heartbeat"
        private const val HEARTBEAT_STALE_MS = 45_000L
        private const val WATCHDOG_INTERVAL_MS = 60_000L
        private const val WATCHDOG_REQUEST_CODE = 1444
    }
}
