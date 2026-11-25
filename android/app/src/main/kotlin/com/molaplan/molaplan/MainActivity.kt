package com.molaplan.molaplan

import android.content.Context
import android.net.wifi.WifiManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var lock: WifiManager.MulticastLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // mDNS device discovery needs a multicast lock on Android.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "molaplan/multicast").setMethodCallHandler { call, result ->
            when (call.method) {
                "acquire" -> {
                    if (lock == null) {
                        val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                        lock = wifi.createMulticastLock("molaplan-mdns").apply { setReferenceCounted(false) }
                    }
                    lock?.acquire()
                    result.success(null)
                }
                "release" -> {
                    lock?.release()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
