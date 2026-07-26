package com.example.tg_proxy

import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat

object PythonProxy {
    fun start(context: Context) {
        ContextCompat.startForegroundService(
            context,
            Intent(context, TelegramProxyService::class.java)
        )
    }
}
