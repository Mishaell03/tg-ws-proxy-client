package com.example.tg_proxy

import android.content.Context
import android.content.ComponentName
import android.content.Intent
import android.os.Build
import android.service.quicksettings.TileService
import androidx.core.content.ContextCompat

object ProxyToggle {
    fun start(context: Context) {
        ProxySettings.setEnabled(context, true)
        ContextCompat.startForegroundService(
            context,
            Intent(context, TelegramProxyService::class.java).apply {
                action = TelegramProxyService.ACTION_START_PROXY
                putExtra(
                    TelegramProxyService.EXTRA_CONFIG_JSON,
                    ProxySettings.toJsonString(context)
                )
            }
        )
        refreshTile(context)
    }

    fun stop(context: Context) {
        ProxySettings.setEnabled(context, false)
        context.stopService(Intent(context, TelegramProxyService::class.java))
        refreshTile(context)
    }

    fun toggle(context: Context): Boolean {
        return if (ProxySettings.isEnabled(context)) {
            AppLog.append(context, "Proxy toggle requested stop")
            stop(context)
            false
        } else {
            AppLog.append(context, "Proxy toggle requested start")
            start(context)
            true
        }
    }

    private fun refreshTile(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            TileService.requestListeningState(
                context,
                ComponentName(context, ProxyTileService::class.java)
            )
        }
    }
}
