package com.example.tg_proxy

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel


class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "proxy"
        ).setMethodCallHandler { call, result ->
            if (call.method == "start") {
                PythonProxy.start(this)
                result.success("started")
            } else {
                result.notImplemented()
            }
        }
    }
}