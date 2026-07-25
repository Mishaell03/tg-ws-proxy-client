package com.example.tg_proxy

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import androidx.core.content.ContextCompat
import com.chaquo.python.Python
import com.chaquo.python.android.AndroidPlatform

class TelegramProxyService : Service() {

    private var wakeLock: PowerManager.WakeLock? = null
    private var proxyThread: Thread? = null
    @Volatile private var isRunning = false
    private var networkCallback: ConnectivityManager.NetworkCallback? = null
    private var screenReceiver: ScreenReceiver? = null
    private var keepaliveSocket: java.net.Socket? = null

    override fun onCreate() {
        super.onCreate()
        startForeground(1, createNotification())
        acquireWakeLock()
        registerScreenReceiver()
        scheduleKeepAlive()
        registerNetworkCallback()
        startJavaKeepaliveThread()
    }

    private fun startJavaKeepaliveThread() {
        Thread {
            Looper.prepare()
            val handler = Handler(Looper.myLooper()!!)
            println("JAVA_KEEPALIVE: handler started")

            fun doTick() {
                // 1. Проверяем не завис ли Python
                try {
                    if (Python.isStarted()) {
                        val py = Python.getInstance()
                        val module = py.getModule("proxy.tg_ws_proxy")

                        val lastActivity = module.callAttr("get_last_activity").toDouble()
                        val now = System.currentTimeMillis() / 1000.0
                        val elapsed = now - lastActivity

                        println("JAVA_KEEPALIVE: tick, elapsed=${elapsed.toInt()}s")

                        // Пингуем Python
                        module.callAttr("android_keepalive")

                        // Если Python не обновлял активность больше 30 секунд — перезапускаем
                        if (lastActivity > 0 && elapsed > 30) {
                            println("JAVA_KEEPALIVE: Python frozen ${elapsed.toInt()}s, restarting")
                            proxyThread?.interrupt()
                            Thread.sleep(500)
                            isRunning = false
                            startPythonProxyInThread()
                            return
                        }
                    }
                } catch (e: Exception) {
                    println("JAVA_KEEPALIVE: jni error: $e")
                }

                // 2. Обновляем socket ping чтобы будить epoll
                Thread {
                    try {
                        keepaliveSocket?.close()
                        keepaliveSocket = null
                        val sock = java.net.Socket()
                        sock.connect(
                            java.net.InetSocketAddress("127.0.0.1", 1443),
                            1000
                        )
                        keepaliveSocket = sock
                        println("JAVA_KEEPALIVE: socket refreshed")
                    } catch (e: Exception) {
                        println("JAVA_KEEPALIVE: socket failed: $e")
                        keepaliveSocket = null
                    }
                }.start()
            }

            fun scheduleNextTick() {
                handler.postDelayed({
                    doTick()
                    scheduleNextTick()
                }, 5_000L)
            }

            handler.postDelayed({
                println("JAVA_KEEPALIVE: first tick")
                doTick()
                scheduleNextTick()
            }, 3_000L)

            Looper.loop()
        }.also {
            it.isDaemon = true
            it.name = "JavaKeepaliveThread"
            it.priority = Thread.MAX_PRIORITY
            it.start()
        }
    }

    private fun acquireWakeLock() {
        val pm = getSystemService(POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "tg_proxy:proxy_lock"
        ).also { it.acquire(10 * 60 * 60 * 1000L) }
    }

    private fun registerNetworkCallback() {
        val cm = getSystemService(CONNECTIVITY_SERVICE) as ConnectivityManager
        val activeNetwork = cm.activeNetwork
        if (activeNetwork != null) {
            val bound = cm.bindProcessToNetwork(activeNetwork)
            println("SERVICE: bound to active network = $bound")
        }
        val request = NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .build()
        networkCallback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                println("SERVICE: network available callback")
                val threadDead = proxyThread?.isAlive != true
                if (!isRunning || threadDead) {
                    isRunning = true
                    startPythonProxyInThread()
                }
            }
            override fun onLost(network: Network) {
                println("SERVICE: network lost")
                val newActive = cm.activeNetwork
                if (newActive != null) {
                    cm.bindProcessToNetwork(newActive)
                }
            }
        }
        try {
            cm.registerNetworkCallback(request, networkCallback!!)
            println("SERVICE: network callback registered")
        } catch (e: Exception) {
            println("SERVICE: registerNetworkCallback failed: $e")
        }
        if (!isRunning) {
            isRunning = true
            startPythonProxyInThread()
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val threadAlive = proxyThread?.isAlive == true
        println("SERVICE: onStartCommand, threadAlive=$threadAlive, isRunning=$isRunning")
        if (!threadAlive) {
            println("SERVICE: starting proxy thread")
            isRunning = true
            startPythonProxyInThread()
        } else {
            println("SERVICE: thread alive, just pinging")
            try {
                if (Python.isStarted()) {
                    val py = Python.getInstance()
                    val module = py.getModule("proxy.tg_ws_proxy")
                    module.callAttr("android_keepalive")
                }
            } catch (e: Exception) {
                println("SERVICE: ping failed: $e")
            }
        }
        return START_STICKY
    }

    private fun startPythonProxyInThread() {
        proxyThread = Thread {
            android.os.Process.setThreadPriority(android.os.Process.THREAD_PRIORITY_FOREGROUND)
            try {
                if (!Python.isStarted()) {
                    Python.start(AndroidPlatform(applicationContext))
                }
                val py = Python.getInstance()
                val module = py.getModule("proxy.tg_ws_proxy")
                module.callAttr("android_start")
            } catch (e: Exception) {
                println("PYTHON ERROR: $e")
            } finally {
                isRunning = false
                println("SERVICE: proxy thread exited")
            }
        }.also {
            it.isDaemon = false
            it.name = "ProxyThread"
            it.priority = Thread.MAX_PRIORITY
            it.start()
        }
    }

    private fun registerScreenReceiver() {
        screenReceiver = ScreenReceiver()
        val filter = android.content.IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_USER_PRESENT)
        }
        registerReceiver(screenReceiver, filter)
        println("SERVICE: screen receiver registered")
    }

    private fun scheduleKeepAlive() {
        val alarmManager = getSystemService(ALARM_SERVICE) as AlarmManager
        val intent = Intent(this, KeepAliveReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.setRepeating(
            AlarmManager.RTC_WAKEUP,
            System.currentTimeMillis() + 60_000L,
            60_000L,
            pendingIntent
        )
        println("SERVICE: keepalive alarm scheduled")
    }

    override fun onDestroy() {
        isRunning = false
        proxyThread?.interrupt()
        keepaliveSocket?.close()
        wakeLock?.let { if (it.isHeld) it.release() }
        networkCallback?.let {
            (getSystemService(CONNECTIVITY_SERVICE) as ConnectivityManager)
                .unregisterNetworkCallback(it)
        }
        screenReceiver?.let { unregisterReceiver(it) }
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotification(): Notification {
        val channelId = "telegram_proxy"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel(
                channelId, "Telegram Proxy", NotificationManager.IMPORTANCE_LOW
            ).also {
                getSystemService(NotificationManager::class.java)
                    .createNotificationChannel(it)
            }
        }
        return Notification.Builder(this, channelId)
            .setContentTitle("Telegram Proxy")
            .setContentText("Работает в фоне")
            .setSmallIcon(android.R.drawable.ic_menu_info_details)
            .build()
    }
}

class KeepAliveReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        println("KEEPALIVE: alarm fired")
        val serviceIntent = Intent(context, TelegramProxyService::class.java)
        ContextCompat.startForegroundService(context, serviceIntent)
        try {
            if (Python.isStarted()) {
                val py = Python.getInstance()
                val module = py.getModule("proxy.tg_ws_proxy")
                module.callAttr("android_keepalive")
            }
        } catch (e: Exception) {
            println("KEEPALIVE: python ping failed: $e")
        }
    }
}