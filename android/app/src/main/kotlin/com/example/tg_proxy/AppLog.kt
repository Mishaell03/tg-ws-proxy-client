package com.example.tg_proxy

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.os.Build
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

object AppLog {
    private const val APP_LOG_FILE = "app.log"
    private const val MAX_LOG_BYTES = 16 * 1024L
    private val timestamp = SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.US)

    @Synchronized
    fun append(context: Context, message: String) {
        try {
            val file = File(context.filesDir, APP_LOG_FILE)
            if (file.length() > MAX_LOG_BYTES) {
                file.writeText("")
            }
            file.appendText("${timestamp.format(Date())} $message\n")
        } catch (_: RuntimeException) {
        }
    }

    fun export(context: Context, destination: Uri) {
        val stream = context.contentResolver.openOutputStream(destination)
            ?: error("Unable to open selected file")
        stream.buffered().use { output ->
            ZipOutputStream(output).use { zip ->
                addText(zip, "diagnostics.txt", diagnostics(context))
                listOf(
                    "app.log",
                    "service.log",
                    "proxy.log",
                    "proxy.log.1"
                ).forEach { name ->
                    val file = File(context.filesDir, name)
                    if (file.isFile) {
                        zip.putNextEntry(ZipEntry(name))
                        file.inputStream().buffered().use { it.copyTo(zip) }
                        zip.closeEntry()
                    }
                }
            }
        }
    }

    private fun diagnostics(context: Context): String {
        val connectivity = context.getSystemService(Context.CONNECTIVITY_SERVICE)
            as ConnectivityManager
        val capabilities = connectivity.activeNetwork?.let {
            connectivity.getNetworkCapabilities(it)
        }
        val transport = when {
            capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) == true -> "cellular"
            capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true -> "wifi"
            capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) == true -> "ethernet"
            capabilities == null -> "none"
            else -> "other"
        }
        val validated = capabilities?.hasCapability(
            NetworkCapabilities.NET_CAPABILITY_VALIDATED
        ) == true
        val settings = JSONObject(ProxySettings.toJsonString(context)).apply {
            if (has("secret")) put("secret", "<redacted>")
        }
        val packageInfo = context.packageManager.getPackageInfo(context.packageName, 0)
        return buildString {
            appendLine("exportedAt=${timestamp.format(Date())}")
            appendLine("appVersion=${packageInfo.versionName} (${packageInfo.longVersionCode})")
            appendLine("device=${Build.MANUFACTURER} ${Build.MODEL}")
            appendLine("android=${Build.VERSION.RELEASE} sdk=${Build.VERSION.SDK_INT}")
            appendLine("proxyEnabled=${ProxySettings.isEnabled(context)}")
            appendLine("network=$transport validated=$validated")
            appendLine("settings=$settings")
        }
    }

    private fun addText(zip: ZipOutputStream, name: String, text: String) {
        zip.putNextEntry(ZipEntry(name))
        zip.write(text.toByteArray(Charsets.UTF_8))
        zip.closeEntry()
    }
}
