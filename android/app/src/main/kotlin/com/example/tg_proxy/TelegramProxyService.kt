package com.example.tg_proxy

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.AlarmManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock
import android.util.Log
import androidx.core.app.NotificationCompat
import com.chaquo.python.Python
import com.chaquo.python.android.AndroidPlatform
import java.io.File

class TelegramProxyService : Service() {
    private val stateLock = Any()
    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    private var shuttingDown = false
    private var proxyThread: Thread? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var wifiLock: WifiManager.WifiLock? = null
    private var silentAudioTrack: AudioTrack? = null
    private var silentAudioThread: Thread? = null
    private var networkCallback: ConnectivityManager.NetworkCallback? = null
    private var screenReceiver: BroadcastReceiver? = null
    private var activeDefaultNetwork: Network? = null
    private var networkValidated: Boolean? = null
    private var networkIsCellular = false
    private var processRestartScheduled = false
    private var serviceStartedAtElapsedMs = 0L
    @Volatile
    private var configJson: String? = null
    @Volatile
    private var manuallyStopped = false

    private val restartProxy = Runnable { ensureProxyRunning() }
    private val networkChanged = Runnable { notifyPythonNetworkChanged() }
    private val healthCheck = object : Runnable {
        override fun run() {
            if (!shuttingDown) {
                promoteToForeground()
                refreshBackgroundLocks()
                startSilentAudioKeepAlive()
                ensureProxyRunning()
                checkPythonHeartbeat("health check")
                scheduleWatchdog()
                mainHandler.postDelayed(this, HEALTH_CHECK_DELAY_MS)
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        shuttingDown = false
        manuallyStopped = false
        processRestartScheduled = false
        serviceStartedAtElapsedMs = SystemClock.elapsedRealtime()
        logLifecycle("onCreate")
        promoteToForeground()
        acquireBackgroundLocks()
        startSilentAudioKeepAlive()
        registerNetworkCallback()
        registerScreenReceiver()
        scheduleWatchdog()
        scheduleHealthCheck()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP_PROXY) {
            ProxySettings.setEnabled(this, false)
            manuallyStopped = true
            shuttingDown = true
            logLifecycle("Manual stop requested")
            stopSelf()
            return START_NOT_STICKY
        }

        intent?.getStringExtra(EXTRA_CONFIG_JSON)?.let { configJson = it }
        shuttingDown = false
        manuallyStopped = false
        logLifecycle("onStartCommand action=${intent?.action ?: "none"}")
        promoteToForeground()
        acquireBackgroundLocks()
        startSilentAudioKeepAlive()

        if (intent?.action == ACTION_RELOAD_PROXY && proxyThread?.isAlive == true) {
            logLifecycle("Proxy configuration reload requested")
            try {
                if (Python.isStarted()) {
                    Python.getInstance().getModule(PYTHON_MODULE).callAttr("android_stop")
                }
            } catch (error: RuntimeException) {
                Log.w(TAG, "Unable to reload Python proxy cleanly", error)
            }
        }

        ensureProxyRunning()
        scheduleWatchdog()
        scheduleHealthCheck()
        return START_STICKY
    }

    private fun ensureProxyRunning() {
        synchronized(stateLock) {
            if (shuttingDown || proxyThread?.isAlive == true) {
                return
            }

            mainHandler.removeCallbacks(restartProxy)
            proxyThread = Thread({ runPythonProxy() }, PROXY_THREAD_NAME).also {
                it.isDaemon = false
                it.start()
            }
            logLifecycle("Python thread started")
        }
    }

    private fun runPythonProxy() {
        android.os.Process.setThreadPriority(android.os.Process.THREAD_PRIORITY_FOREGROUND)
        try {
            if (!Python.isStarted()) {
                Python.start(AndroidPlatform(applicationContext))
            }
            val module = Python.getInstance().getModule(PYTHON_MODULE)
            val logPath = filesDir.resolve("proxy.log").absolutePath
            val heartbeatPath = filesDir.resolve(PYTHON_HEARTBEAT_FILE).absolutePath
            Log.i(TAG, "Starting Python proxy")
            val effectiveConfig = configJson ?: ProxySettings.toJsonString(this)
            module.callAttr(
                "android_start",
                logPath,
                heartbeatPath,
                networkIsCellular,
                effectiveConfig
            )
            Log.w(TAG, "Python proxy exited")
            logLifecycle("Python proxy exited")
        } catch (error: Throwable) {
            Log.e(TAG, "Python proxy crashed", error)
            logLifecycle("Python proxy crashed: ${error.message}", error)
        } finally {
            val shouldRestart = synchronized(stateLock) {
                if (proxyThread === Thread.currentThread()) {
                    proxyThread = null
                }
                !shuttingDown && !manuallyStopped && ProxySettings.isEnabled(this)
            }
            if (shouldRestart) {
                mainHandler.removeCallbacks(restartProxy)
                mainHandler.postDelayed(restartProxy, RESTART_DELAY_MS)
                logLifecycle("Python restart scheduled in ${RESTART_DELAY_MS}ms")
            }
        }
    }

    private fun registerNetworkCallback() {
        val connectivityManager =
            getSystemService(CONNECTIVITY_SERVICE) as ConnectivityManager
        activeDefaultNetwork = connectivityManager.activeNetwork
        networkValidated = activeDefaultNetwork?.let { network ->
            connectivityManager.getNetworkCapabilities(network)?.hasCapability(
                NetworkCapabilities.NET_CAPABILITY_VALIDATED
            )
        }
        networkIsCellular = activeDefaultNetwork?.let { network ->
            connectivityManager.getNetworkCapabilities(network)?.hasTransport(
                NetworkCapabilities.TRANSPORT_CELLULAR
            )
        } == true

        networkCallback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                val previousNetwork = activeDefaultNetwork
                activeDefaultNetwork = network
                ensureProxyRunning()
                if (previousNetwork != null && previousNetwork != network) {
                    schedulePythonNetworkChanged("switched")
                }
            }

            override fun onLost(network: Network) {
                if (activeDefaultNetwork != network) {
                    return
                }
                activeDefaultNetwork = null
                networkValidated = false
                schedulePythonNetworkChanged("lost")
            }

            override fun onCapabilitiesChanged(
                network: Network,
                networkCapabilities: NetworkCapabilities
            ) {
                val validated = networkCapabilities.hasCapability(
                    NetworkCapabilities.NET_CAPABILITY_VALIDATED
                )
                val isCellular = networkCapabilities.hasTransport(
                    NetworkCapabilities.TRANSPORT_CELLULAR
                )
                if (activeDefaultNetwork == network && networkIsCellular != isCellular) {
                    networkIsCellular = isCellular
                    schedulePythonNetworkChanged(
                        if (isCellular) "using cellular" else "using non-cellular"
                    )
                }
                if (activeDefaultNetwork == network && networkValidated != validated) {
                    networkValidated = validated
                    logLifecycle(
                        "Default network ${if (validated) "validated" else "not validated"}"
                    )
                }
            }
        }

        try {
            connectivityManager.registerDefaultNetworkCallback(networkCallback!!)
        } catch (error: RuntimeException) {
            Log.w(TAG, "Unable to register network callback", error)
        }
    }

    private fun registerScreenReceiver() {
        screenReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                when (intent.action) {
                    Intent.ACTION_SCREEN_ON -> {
                        acquireBackgroundLocks()
                        ensureProxyRunning()
                        checkPythonHeartbeat("screen on")
                        scheduleWatchdog()
                    }
                    Intent.ACTION_USER_PRESENT -> {
                        acquireBackgroundLocks()
                        ensureProxyRunning()
                        checkPythonHeartbeat("user present")
                        scheduleWatchdog()
                    }
                    Intent.ACTION_SCREEN_OFF -> {
                        acquireBackgroundLocks()
                        ensureProxyRunning()
                        scheduleWatchdog()
                    }
                }
            }
        }

        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_USER_PRESENT)
        }
        registerReceiver(screenReceiver, filter)
    }

    private fun schedulePythonNetworkChanged(reason: String) {
        logLifecycle("Default network $reason")
        mainHandler.removeCallbacks(networkChanged)
        mainHandler.postDelayed(networkChanged, NETWORK_CHANGE_DEBOUNCE_MS)
    }

    private fun notifyPythonNetworkChanged() {
        try {
            if (Python.isStarted()) {
                Python.getInstance()
                    .getModule(PYTHON_MODULE)
                    .callAttr("android_network_changed", networkIsCellular)
            }
        } catch (error: RuntimeException) {
            Log.w(TAG, "Unable to notify Python about network change", error)
        }
    }

    private fun checkPythonHeartbeat(reason: String) {
        if (processRestartScheduled || proxyThread?.isAlive != true) {
            return
        }

        val serviceAge = SystemClock.elapsedRealtime() - serviceStartedAtElapsedMs
        if (serviceAge < PYTHON_HEARTBEAT_GRACE_MS) {
            return
        }

        val heartbeatFile = File(filesDir, PYTHON_HEARTBEAT_FILE)
        val heartbeatAge = System.currentTimeMillis() - heartbeatFile.lastModified()
        if (!heartbeatFile.exists() || heartbeatAge > PYTHON_HEARTBEAT_STALE_MS) {
            restartProxyProcess(
                "$reason; Python heartbeat stale for ${heartbeatAge.coerceAtLeast(0L)}ms"
            )
        }
    }

    private fun restartProxyProcess(reason: String) {
        if (processRestartScheduled || shuttingDown) {
            return
        }
        processRestartScheduled = true
        logLifecycle("Proxy process restart requested: $reason")
        scheduleServiceRestart(reason)
        mainHandler.postDelayed(
            { android.os.Process.killProcess(android.os.Process.myPid()) },
            PROCESS_KILL_DELAY_MS
        )
    }

    private fun acquireBackgroundLocks() {
        if (wakeLock?.isHeld != true) {
            val powerManager = getSystemService(POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                cpuWakeLockTag()
            ).apply {
                setReferenceCounted(false)
                acquire()
            }
        }

        if (wifiLock?.isHeld != true) {
            try {
                val wifiManager =
                    applicationContext.getSystemService(WIFI_SERVICE) as WifiManager
                @Suppress("DEPRECATION")
                wifiLock = wifiManager.createWifiLock(
                    WifiManager.WIFI_MODE_FULL_HIGH_PERF,
                    "$packageName:proxy_wifi"
                ).apply {
                    setReferenceCounted(false)
                    acquire()
                }
            } catch (error: RuntimeException) {
                Log.w(TAG, "Unable to acquire Wi-Fi lock", error)
            }
        }
    }

    // Transsion firmware may remove the kernel lock while leaving isHeld=true.
    // Recycle both locks before its idle freezer gets a chance to suspend us.
    private fun refreshBackgroundLocks() {
        if (wakeLock?.isHeld == true) {
            wakeLock?.release()
        }
        wakeLock = null
        if (wifiLock?.isHeld == true) {
            wifiLock?.release()
        }
        wifiLock = null
        acquireBackgroundLocks()
    }

    // TECNO Hiber freezes idle UIDs even when a normal FGS is visible. A
    // silent PCM stream is recognized as active media by that firmware. It
    // contains only zero samples, so it produces no audible output.
    private fun startSilentAudioKeepAlive() {
        synchronized(stateLock) {
            if (silentAudioThread?.isAlive == true) {
                return
            }

            val minBuffer = AudioTrack.getMinBufferSize(
                SILENT_AUDIO_SAMPLE_RATE,
                AudioFormat.CHANNEL_OUT_MONO,
                AudioFormat.ENCODING_PCM_16BIT
            )
            if (minBuffer <= 0) {
                Log.w(TAG, "Unable to initialize silent audio keepalive: buffer=$minBuffer")
                return
            }

            val track = try {
                AudioTrack.Builder()
                    .setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_MEDIA)
                            .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                            .build()
                    )
                    .setAudioFormat(
                        AudioFormat.Builder()
                            .setSampleRate(SILENT_AUDIO_SAMPLE_RATE)
                            .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                            .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                            .build()
                    )
                    .setBufferSizeInBytes(maxOf(minBuffer, SILENT_AUDIO_BUFFER_BYTES))
                    .setTransferMode(AudioTrack.MODE_STREAM)
                    .build()
            } catch (error: RuntimeException) {
                Log.w(TAG, "Unable to create silent audio keepalive", error)
                return
            }

            if (track.state != AudioTrack.STATE_INITIALIZED) {
                track.release()
                Log.w(TAG, "Silent audio keepalive is not initialized")
                return
            }

            val silence = ByteArray(SILENT_AUDIO_BUFFER_BYTES)
            try {
                track.play()
            } catch (error: IllegalStateException) {
                track.release()
                Log.w(TAG, "Unable to start silent audio keepalive", error)
                return
            }

            silentAudioTrack = track
            silentAudioThread = Thread({
                android.os.Process.setThreadPriority(android.os.Process.THREAD_PRIORITY_AUDIO)
                try {
                    while (!shuttingDown && silentAudioTrack === track) {
                        if (track.write(silence, 0, silence.size, AudioTrack.WRITE_BLOCKING) < 0) {
                            break
                        }
                    }
                } catch (error: Throwable) {
                    if (!shuttingDown) {
                        Log.w(TAG, "Silent audio keepalive stopped", error)
                    }
                } finally {
                    try {
                        track.pause()
                    } catch (_: IllegalStateException) {
                    }
                    track.release()
                    synchronized(stateLock) {
                        if (silentAudioTrack === track) {
                            silentAudioTrack = null
                            silentAudioThread = null
                        }
                    }
                }
            }, "TelegramProxyAudioKeepalive").also {
                it.isDaemon = false
                it.start()
            }
            logLifecycle("Silent audio keepalive started")
        }
    }

    private fun stopSilentAudioKeepAlive() {
        val track = synchronized(stateLock) {
            silentAudioTrack.also {
                silentAudioTrack = null
                silentAudioThread = null
            }
        }
        if (track != null) {
            try {
                track.pause()
            } catch (_: IllegalStateException) {
            }
            track.flush()
        }
    }

    private fun cpuWakeLockTag(): String {
        val transsionBrands = setOf("TECNO", "INFINIX", "ITEL")
        return if (Build.MANUFACTURER.uppercase() in transsionBrands) {
            // Transsion firmware proxies arbitrary tags but keeps WkService active.
            TRANSSION_WAKE_LOCK_TAG
        } else {
            "$packageName:proxy_cpu"
        }
    }

    private fun releaseBackgroundLocks() {
        wifiLock?.let { if (it.isHeld) it.release() }
        wifiLock = null
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
    }

    private fun scheduleHealthCheck() {
        mainHandler.removeCallbacks(healthCheck)
        mainHandler.postDelayed(healthCheck, HEALTH_CHECK_DELAY_MS)
    }

    private fun scheduleServiceRestart(reason: String) {
        logLifecycle("Service restart scheduled: $reason")
        val intent = Intent(this, ProxyBootReceiver::class.java).apply {
            action = ACTION_RESTART_PROXY
        }
        val pendingIntent = PendingIntent.getBroadcast(
            this,
            RESTART_REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val alarmManager = getSystemService(ALARM_SERVICE) as AlarmManager
        val triggerAt = System.currentTimeMillis() + SERVICE_RESTART_DELAY_MS
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

    private fun scheduleWatchdog() {
        val intent = Intent(this, ProxyBootReceiver::class.java).apply {
            action = ACTION_WATCHDOG
        }
        val pendingIntent = PendingIntent.getBroadcast(
            this,
            WATCHDOG_REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val alarmManager = getSystemService(ALARM_SERVICE) as AlarmManager
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

    private fun promoteToForeground() {
        val notification = createNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE or
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun createNotification(): Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "Telegram Proxy",
                NotificationManager.IMPORTANCE_LOW
            )
            getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }

        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val contentIntent = launchIntent?.let {
            PendingIntent.getActivity(
                this,
                0,
                it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }
        val toggleIntent = PendingIntent.getBroadcast(
            this,
            TOGGLE_REQUEST_CODE,
            Intent(this, ProxyActionReceiver::class.java).apply {
                action = ProxyActionReceiver.ACTION_TOGGLE_PROXY
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle("Telegram Proxy")
            .setContentText("Proxy is running")
            .setSmallIcon(R.drawable.contour)
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setContentIntent(contentIntent)
            .addAction(R.drawable.contour, "Stop proxy", toggleIntent)
            .build()
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        logLifecycle("onTaskRemoved")
        if (!manuallyStopped && ProxySettings.isEnabled(this)) {
            refreshBackgroundLocks()
            startSilentAudioKeepAlive()
            ensureProxyRunning()
            scheduleServiceRestart("task removed")
        }
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        logLifecycle("onDestroy")
        shuttingDown = true
        mainHandler.removeCallbacks(restartProxy)
        mainHandler.removeCallbacks(healthCheck)
        mainHandler.removeCallbacks(networkChanged)
        if (!manuallyStopped && ProxySettings.isEnabled(this)) {
            scheduleServiceRestart("service destroyed")
        }

        networkCallback?.let { callback ->
            try {
                (getSystemService(CONNECTIVITY_SERVICE) as ConnectivityManager)
                    .unregisterNetworkCallback(callback)
            } catch (error: RuntimeException) {
                Log.w(TAG, "Unable to unregister network callback", error)
            }
        }
        networkCallback = null
        activeDefaultNetwork = null
        networkValidated = null

        screenReceiver?.let { receiver ->
            try {
                unregisterReceiver(receiver)
            } catch (error: RuntimeException) {
                Log.w(TAG, "Unable to unregister screen receiver", error)
            }
        }
        screenReceiver = null

        try {
            if (Python.isStarted()) {
                Python.getInstance().getModule(PYTHON_MODULE).callAttr("android_stop")
            }
        } catch (error: RuntimeException) {
            Log.w(TAG, "Unable to stop Python proxy cleanly", error)
        }

        stopSilentAudioKeepAlive()
        releaseBackgroundLocks()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun logLifecycle(message: String, error: Throwable? = null) {
        if (error == null) {
            Log.i(TAG, message)
        } else {
            Log.e(TAG, message, error)
        }

        try {
            val logFile = File(filesDir, SERVICE_LOG_FILE)
            if (logFile.length() > MAX_SERVICE_LOG_BYTES) {
                logFile.writeText("")
            }
            logFile.appendText("${System.currentTimeMillis()} $message\n")
        } catch (ignored: RuntimeException) {
        }
    }

    companion object {
        const val ACTION_RESTART_PROXY = "com.example.tg_proxy.RESTART_PROXY"
        const val ACTION_WATCHDOG = "com.example.tg_proxy.WATCHDOG"
        const val ACTION_START_PROXY = "com.example.tg_proxy.START_PROXY"
        const val ACTION_STOP_PROXY = "com.example.tg_proxy.STOP_PROXY"
        const val ACTION_RELOAD_PROXY = "com.example.tg_proxy.RELOAD_PROXY"
        const val EXTRA_CONFIG_JSON = "proxy_config_json"
        private const val TAG = "TelegramProxyService"
        private const val PYTHON_MODULE = "proxy.tg_ws_proxy"
        private const val PROXY_THREAD_NAME = "TelegramProxyPython"
        private const val NOTIFICATION_CHANNEL_ID = "telegram_proxy"
        private const val NOTIFICATION_ID = 1
        private const val RESTART_DELAY_MS = 3_000L
        private const val HEALTH_CHECK_DELAY_MS = 10_000L
        private const val NETWORK_CHANGE_DEBOUNCE_MS = 5_000L
        private const val SERVICE_RESTART_DELAY_MS = 2_000L
        private const val PROCESS_KILL_DELAY_MS = 500L
        private const val PYTHON_HEARTBEAT_GRACE_MS = 30_000L
        private const val PYTHON_HEARTBEAT_STALE_MS = 45_000L
        private const val RESTART_REQUEST_CODE = 1443
        private const val WATCHDOG_REQUEST_CODE = 1444
        private const val TOGGLE_REQUEST_CODE = 1445
        private const val WATCHDOG_INTERVAL_MS = 60_000L
        private const val SERVICE_LOG_FILE = "service.log"
        private const val PYTHON_HEARTBEAT_FILE = "proxy.heartbeat"
        private const val TRANSSION_WAKE_LOCK_TAG = "WkService"
        private const val SILENT_AUDIO_SAMPLE_RATE = 8_000
        private const val SILENT_AUDIO_BUFFER_BYTES = 2_048
        private const val MAX_SERVICE_LOG_BYTES = 16 * 1024
    }
}
