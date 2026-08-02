package com.mishaell.tg_proxy

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class ProxyActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_TOGGLE_PROXY) return
        ProxyToggle.toggle(context)
    }

    companion object {
        const val ACTION_TOGGLE_PROXY = "com.mishaell.tg_proxy.ACTION_TOGGLE_PROXY"
    }
}
