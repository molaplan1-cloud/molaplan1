package com.molaplan.molaplan

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.ConnectivityManager
import android.net.Network
import android.net.Uri
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/**
 * t209u / R027: the in-app home bridge keeps running with the app closed and the screen off.
 *
 * There is ONE Flutter engine ([EngineHolder]). While bridge mode is on, this foreground service
 * owns it and runs the normal app headless (no window); when the app is opened, the activity
 * attaches to the same engine – so there is never a second bridge connecting with the same home key.
 * The service holds a partial wake lock and a Wi-Fi lock, restarts itself (START_STICKY), starts on
 * boot ([BootReceiver]) and tells the Dart side when a network comes back so the relay link
 * reconnects at once instead of waiting for its back-off timer.
 */
class BridgeService : Service() {
    companion object {
        @Volatile var running = false
        private const val NOTIFICATION_ID = 4711
        private const val CHANNEL = "bridge"
        private const val PREFS = "molaplan_bridge"

        fun enabled(ctx: Context) = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean("enabled", false)

        fun setEnabled(ctx: Context, on: Boolean) {
            ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean("enabled", on).apply()
            val i = Intent(ctx, BridgeService::class.java)
            if (on) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) ctx.startForegroundService(i) else ctx.startService(i)
            } else {
                ctx.stopService(i)
            }
        }
    }

    private var wake: PowerManager.WakeLock? = null
    private var wifi: WifiManager.WifiLock? = null
    private var netCallback: ConnectivityManager.NetworkCallback? = null
    private val main = Handler(Looper.getMainLooper())

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        running = true
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL, "Kotisilta", NotificationManager.IMPORTANCE_LOW).apply {
                    description = "Molaplan-kotisilta toimii taustalla"
                    setShowBadge(false)
                }
            )
        }
        val open = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val b = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) Notification.Builder(this, CHANNEL)
        else @Suppress("DEPRECATION") Notification.Builder(this)
        val n = b.setSmallIcon(applicationInfo.icon)
            .setContentTitle("Molaplan-kotisilta käynnissä")
            .setContentText("Välittää etäkomennot kodin laitteille.")
            .setContentIntent(open)
            .setOngoing(true)
            .build()
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(NOTIFICATION_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION_ID, n)
        }
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wake = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "molaplan:bridge").apply {
            setReferenceCounted(false)
            acquire()
        }
        val wm = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        @Suppress("DEPRECATION")
        wifi = wm.createWifiLock(WifiManager.WIFI_MODE_FULL_HIGH_PERF, "molaplan:bridge").apply {
            setReferenceCounted(false)
            acquire()
        }
        val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        netCallback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                main.post { EngineHolder.notify("networkUp") }
            }
            override fun onLost(network: Network) {
                main.post { EngineHolder.notify("networkLost") }
            }
        }
        try {
            cm.registerDefaultNetworkCallback(netCallback!!)
        } catch (e: Exception) {
            netCallback = null
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Runs the app headless when no activity has started the engine yet (boot, app swiped away).
        EngineHolder.get(this)
        return START_STICKY
    }

    override fun onDestroy() {
        running = false
        try {
            netCallback?.let { (getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager).unregisterNetworkCallback(it) }
        } catch (e: Exception) {}
        wake?.let { if (it.isHeld) it.release() }
        wifi?.let { if (it.isHeld) it.release() }
        if (!EngineHolder.activityAttached) EngineHolder.destroy()
        super.onDestroy()
    }
}

/** Starts the bridge after a reboot or an app update, when bridge mode was on. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val a = intent.action ?: return
        if (a == Intent.ACTION_BOOT_COMPLETED || a == Intent.ACTION_MY_PACKAGE_REPLACED ||
            a == "android.intent.action.QUICKBOOT_POWERON"
        ) {
            if (BridgeService.enabled(context)) BridgeService.setEnabled(context, true)
        }
        // t282u: after an in-app APK update the process is gone; bring the UI back.
        if (a == Intent.ACTION_MY_PACKAGE_REPLACED) {
            SilentUpdater.relaunchAfterUpdate(context)
        }
    }
}

/** The app's single Flutter engine, shared by [MainActivity] and [BridgeService]. */
object EngineHolder {
    const val ID = "molaplan_main"
    @Volatile var activityAttached = false
    private var channel: MethodChannel? = null

    fun get(ctx: Context): FlutterEngine {
        FlutterEngineCache.getInstance().get(ID)?.let { return it }
        val app = ctx.applicationContext
        val loader = FlutterInjector.instance().flutterLoader()
        loader.startInitialization(app)
        loader.ensureInitializationComplete(app, null)
        val e = FlutterEngine(app)
        e.addEngineLifecycleListener(object : FlutterEngine.EngineLifecycleListener {
            override fun onPreEngineRestart() {}
            override fun onEngineWillDestroy() {
                FlutterEngineCache.getInstance().remove(ID)
                channel = null
            }
        })
        NetBinder.register(app, e.dartExecutor.binaryMessenger) // t219u
        channel = MethodChannel(e.dartExecutor.binaryMessenger, "molaplan/bridge_service").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> { BridgeService.setEnabled(app, true); result.success(true) }
                    "stop" -> { BridgeService.setEnabled(app, false); result.success(true) }
                    "running" -> result.success(BridgeService.running)
                    "batteryExempt" -> {
                        val pm = app.getSystemService(Context.POWER_SERVICE) as PowerManager
                        result.success(Build.VERSION.SDK_INT < Build.VERSION_CODES.M || pm.isIgnoringBatteryOptimizations(app.packageName))
                    }
                    "requestBatteryExemption" -> {
                        try {
                            app.startActivity(
                                Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:${app.packageName}"))
                                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            )
                            result.success(true)
                        } catch (ex: Exception) {
                            // Some vendors hide the direct prompt: open the list instead.
                            try {
                                app.startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                            } catch (_: Exception) {}
                            result.success(false)
                        }
                    }
                    // t211u: silent self-update (device owner) / prompt fallback.
                    "deviceOwner" -> result.success(SilentUpdater.isDeviceOwner(app))
                    // t230u: shown in 'Omat kotisillat' (e.g. "HTC 5G Hub", "SM-T575").
                    "model" -> result.success(listOf(android.os.Build.MANUFACTURER, android.os.Build.MODEL).joinToString(" ").trim())
                    "installUpdate" -> {
                        val path = call.argument<String>("path")
                        if (path == null) result.error("args", "path missing", null)
                        else Thread {
                            val r = try { SilentUpdater.install(app, java.io.File(path), call.argument<String>("sha256")) }
                                    catch (ex: Exception) { "error ${ex.message}" }
                            android.os.Handler(android.os.Looper.getMainLooper()).post { result.success(r) }
                        }.start()
                    }
                    "lastUpdate" -> result.success(SilentUpdater.last(app))
                    "versionCode" -> {
                        val p = app.packageManager.getPackageInfo(app.packageName, 0)
                        @Suppress("DEPRECATION")
                        result.success(if (Build.VERSION.SDK_INT >= 28) p.longVersionCode else p.versionCode.toLong())
                    }
                    else -> result.notImplemented()
                }
            }
        }
        e.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        FlutterEngineCache.getInstance().put(ID, e)
        return e
    }

    fun notify(method: String) {
        channel?.invokeMethod(method, null)
    }

    fun destroy() {
        FlutterEngineCache.getInstance().get(ID)?.destroy()
    }
}
