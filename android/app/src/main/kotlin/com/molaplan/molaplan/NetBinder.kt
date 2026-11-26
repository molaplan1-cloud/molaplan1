package com.molaplan.molaplan

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * t219u: a real request failed at the network level. On devices such as the HTC 5G Hub the app's
 * own process can have no default network (the modem serves the tethered Wi-Fi clients, but
 * ConnectivityManager.activeNetwork is null or lacks INTERNET for apps), so every socket fails
 * although the internet works. This binds the process to any internet-capable network
 * (cellular preferred), requests cellular if none is listed, and unbinds again as soon as a
 * normal default network exists. It never runs before a request, only after one failed.
 */
object NetBinder {
    private val main = Handler(Looper.getMainLooper())
    private var pending: ConnectivityManager.NetworkCallback? = null
    private var watching = false

    fun register(app: Context, messenger: BinaryMessenger) {
        MethodChannel(messenger, "molaplan/net").setMethodCallHandler { call, result ->
            when (call.method) {
                "ensureInternet" -> ensure(app) { result.success(it) }
                else -> result.notImplemented()
            }
        }
        // Drop the fallback binding as soon as a normal default network with internet shows up.
        if (watching) return
        try {
            val cm = app.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            cm.registerDefaultNetworkCallback(object : ConnectivityManager.NetworkCallback() {
                override fun onCapabilitiesChanged(network: Network, caps: NetworkCapabilities) {
                    val bound = cm.boundNetworkForProcess ?: return
                    if (bound != network && caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)) {
                        cm.bindProcessToNetwork(null)
                    }
                }
            })
            watching = true
        } catch (_: Exception) {}
    }

    private fun describe(cm: ConnectivityManager, n: Network?): String {
        if (n == null) return "none"
        val c = cm.getNetworkCapabilities(n) ?: return "$n(no caps)"
        val t = buildList {
            if (c.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)) add("cell")
            if (c.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) add("wifi")
            if (c.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET)) add("eth")
            if (c.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) add("vpn")
            if (c.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)) add("internet")
            if (c.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)) add("validated")
        }
        return "$n(${t.joinToString(",")})"
    }

    private fun hasInternet(cm: ConnectivityManager, n: Network?): Boolean =
        n != null && cm.getNetworkCapabilities(n)?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) == true

    private fun ensure(app: Context, done: (Map<String, Any?>) -> Unit) {
        val cm = app.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val active = cm.activeNetwork
        val bound = cm.boundNetworkForProcess
        @Suppress("DEPRECATION")
        val all = try { cm.allNetworks.toList() } catch (e: Exception) { emptyList() }
        val diag = "active=${describe(cm, active)} bound=${describe(cm, bound)} all=[${all.joinToString(" ") { describe(cm, it) }}]"
        fun reply(action: String, changed: Boolean, net: Network? = null) =
            done(mapOf("action" to action, "changed" to changed, "network" to describe(cm, net), "diag" to diag))

        // A normal default network exists: no binding needed (drop an old fallback binding).
        if (hasInternet(cm, active)) {
            if (bound != null && bound != active) {
                cm.bindProcessToNetwork(null)
                return reply("unbound", true, active)
            }
            return reply("default", false, active)
        }
        // No usable default network: pick an internet-capable one (validated, cellular first).
        val candidates = all.filter { hasInternet(cm, it) }.sortedByDescending {
            val c = cm.getNetworkCapabilities(it)
            (if (c?.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED) == true) 2 else 0) +
                (if (c?.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) == true) 1 else 0)
        }
        val pick = candidates.firstOrNull()
        if (pick != null) {
            if (pick == bound) return reply("bound", false, pick)
            val ok = cm.bindProcessToNetwork(pick)
            return reply(if (ok) "bound" else "bind_failed", ok, pick)
        }
        // Nothing listed: ask for cellular data explicitly (up to 10 s).
        if (pending != null) return reply("requesting", false)
        var answered = false
        val cb = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                main.post {
                    if (answered) return@post
                    answered = true
                    val ok = cm.bindProcessToNetwork(network)
                    reply(if (ok) "cellular" else "bind_failed", ok, network)
                }
            }
        }
        try {
            val req = NetworkRequest.Builder()
                .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                .addTransportType(NetworkCapabilities.TRANSPORT_CELLULAR)
                .build()
            pending = cb
            cm.requestNetwork(req, cb)
        } catch (e: Exception) {
            pending = null
            return done(mapOf("action" to "request_failed", "changed" to false, "network" to "none", "diag" to "$diag err=$e"))
        }
        main.postDelayed({
            if (!answered) {
                answered = true
                try { cm.unregisterNetworkCallback(cb) } catch (_: Exception) {}
                pending = null
                reply("no_network", false)
            }
        }, 10_000)
    }
}
