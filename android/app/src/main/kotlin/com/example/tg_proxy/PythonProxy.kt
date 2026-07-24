package com.example.tg_proxy

import android.content.Context
import com.chaquo.python.Python
import com.chaquo.python.android.AndroidPlatform


object PythonProxy {

    fun start(context: Context) {

        Thread {

            if (!Python.isStarted()) {
                Python.start(AndroidPlatform(context))
            }

            val py = Python.getInstance()

            val module = py.getModule("proxy.tg_ws_proxy")

            module.callAttr("main")

        }.start()
    }
}