package com.example.tg_proxy

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat
import com.chaquo.python.Python

class ScreenReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_SCREEN_OFF -> {
                println("SCREEN: screen off — clearing blacklists")
                pingPython()
            }
            Intent.ACTION_SCREEN_ON,
            Intent.ACTION_USER_PRESENT -> {
                println("SCREEN: screen on/unlocked — clearing blacklists")
                pingPython()
                // Сервис НЕ перезапускаем — он должен уже работать
                ensureServiceRunning(context)
            }
        }
    }

    private fun pingPython() {
        try {
            if (Python.isStarted()) {
                val py = Python.getInstance()
                val module = py.getModule("proxy.tg_ws_proxy")
                module.callAttr("android_keepalive")
            }
        } catch (e: Exception) {
            println("SCREEN: python ping failed: $e")
        }
    }

    private fun ensureServiceRunning(context: Context) {
        val serviceIntent = Intent(context, TelegramProxyService::class.java)
        ContextCompat.startForegroundService(context, serviceIntent)
    }
}