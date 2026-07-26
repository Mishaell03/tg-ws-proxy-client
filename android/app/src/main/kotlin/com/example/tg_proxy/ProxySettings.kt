package com.example.tg_proxy

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.security.SecureRandom

object ProxySettings {
    private const val PREFS = "proxy_settings"
    private const val CONFIG = "config"
    private const val ENABLED = "enabled"
    private const val DEFAULT_SECRET = "5ffd11a0e7765ff28e394636f2d29d17"
    private val defaultDcIps = listOf(
        "1:149.154.175.53", "2:149.154.167.220", "3:149.154.175.100",
        "4:149.154.167.220", "5:91.108.56.130", "203:91.105.192.100"
    )

    fun defaults(): Map<String, Any> = linkedMapOf(
        "host" to "127.0.0.1", "port" to 1443, "secret" to DEFAULT_SECRET,
        "dcIp" to defaultDcIps, "bufferKb" to 256, "poolSize" to 2,
        "cfProxy" to true, "cfProxyDomains" to emptyList<String>(),
        "cfWorkerDomains" to emptyList<String>(), "forceTestDc" to false,
        "wsKeepaliveInterval" to 30
    )

    fun load(context: Context): Map<String, Any> {
        val raw = prefs(context).getString(CONFIG, null)
            ?: return defaults().also { persist(context, it) }
        return try { fromJson(JSONObject(raw)) } catch (_: Exception) {
            defaults().also { persist(context, it) }
        }
    }

    fun save(context: Context, values: Map<String, Any?>): Map<String, Any> {
        val merged = load(context).toMutableMap()
        values.forEach { (key, value) -> if (value != null) merged[key] = value }
        return validate(merged).also { persist(context, it) }
    }

    fun isEnabled(context: Context) = prefs(context).getBoolean(ENABLED, false)

    fun setEnabled(context: Context, enabled: Boolean) {
        prefs(context).edit().putBoolean(ENABLED, enabled).apply()
    }

    fun toJsonString(context: Context) = toJson(load(context)).toString()

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun persist(context: Context, values: Map<String, Any>) {
        prefs(context).edit().putString(CONFIG, toJson(values).toString()).apply()
    }

    private fun validate(input: Map<String, Any>): Map<String, Any> {
        val host = input["host"].toString().trim()
        require(host.isNotEmpty()) { "host must not be empty" }
        val port = number(input, "port", 1443)
        require(port in 1..65535) { "port must be between 1 and 65535" }
        val secret = input["secret"].toString().trim().lowercase()
        require(secret.matches(Regex("[0-9a-f]{32}"))) {
            "secret must contain exactly 32 hex characters"
        }
        val dcIps = stringList(input["dcIp"])
        require(dcIps.isNotEmpty()) { "dcIp must not be empty" }
        dcIps.forEach {
            require(it.matches(Regex("-?\\d+:[^:]+"))) { "invalid dcIp entry: $it" }
        }
        val bufferKb = number(input, "bufferKb", 256)
        require(bufferKb in 4..16384) { "bufferKb must be between 4 and 16384" }
        val poolSize = number(input, "poolSize", 2)
        require(poolSize in 0..32) { "poolSize must be between 0 and 32" }
        val keepalive = number(input, "wsKeepaliveInterval", 30)
        require(keepalive in 0..3600) { "wsKeepaliveInterval must be between 0 and 3600" }
        return linkedMapOf(
            "host" to host, "port" to port, "secret" to secret, "dcIp" to dcIps,
            "bufferKb" to bufferKb, "poolSize" to poolSize,
            "cfProxy" to boolean(input, "cfProxy", true),
            "cfProxyDomains" to stringList(input["cfProxyDomains"]),
            "cfWorkerDomains" to stringList(input["cfWorkerDomains"]),
            "forceTestDc" to boolean(input, "forceTestDc", false),
            "wsKeepaliveInterval" to keepalive
        )
    }

    private fun number(input: Map<String, Any>, key: String, fallback: Int) =
        (input[key] as? Number)?.toInt() ?: input[key]?.toString()?.toIntOrNull() ?: fallback

    private fun boolean(input: Map<String, Any>, key: String, fallback: Boolean) =
        input[key] as? Boolean ?: input[key]?.toString()?.toBooleanStrictOrNull() ?: fallback

    private fun stringList(value: Any?): List<String> = when (value) {
        is List<*> -> value.mapNotNull { it?.toString()?.trim() }.filter { it.isNotEmpty() }
        is JSONArray -> (0 until value.length()).map { value.getString(it).trim() }.filter { it.isNotEmpty() }
        null -> emptyList()
        else -> value.toString().replace(';', ',').split(',', '\n')
            .map { it.trim() }.filter { it.isNotEmpty() }
    }

    private fun toJson(values: Map<String, Any>) = JSONObject().apply {
        values.forEach { (key, value) -> put(key, if (value is List<*>) JSONArray(value) else value) }
    }

    private fun fromJson(json: JSONObject): Map<String, Any> =
        validate(defaults().toMutableMap().apply {
            json.keys().forEach { key -> this[key] = json.get(key) }
        })

    fun randomSecret(): String = ByteArray(16)
        .also { SecureRandom().nextBytes(it) }
        .joinToString("") { "%02x".format(it) }
}
