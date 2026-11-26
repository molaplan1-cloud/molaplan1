package com.molaplan.molaplan

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.net.wifi.WifiManager
import android.os.Build
import android.os.SystemClock
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import android.os.Bundle
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private var lock: WifiManager.MulticastLock? = null

    // t228u: in-app update install (non device owner).
    private var pendingInstall: MethodChannel.Result? = null
    private var pendingInstallFile: File? = null
    private var installStartedAt = 0L

    private fun sessionInstall(f: File, why: String): String = try {
        // SHA-256 was checked in Dart; the native check still requires our own package + signing key.
        val r = SilentUpdater.install(this, f, null)
        if (r.startsWith("started")) "session ($why)" else "failed: $r"
    } catch (e: Exception) {
        "failed: ${e.message ?: e.javaClass.simpleName}"
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQ_INSTALL) return
        val res = pendingInstall ?: return
        pendingInstall = null
        val f = pendingInstallFile
        val quick = SystemClock.elapsedRealtime() - installStartedAt < QUICK_RETURN_MS
        res.success(
            when {
                resultCode == RESULT_OK -> "installed"
                resultCode == RESULT_FIRST_USER ->
                    "failed: install result ${data?.getIntExtra("android.intent.extra.INSTALL_RESULT", 0) ?: 0}"
                quick && f != null -> sessionInstall(f, "installer returned at once")
                else -> "cancelled"
            }
        )
    }

    override fun onResume() {
        super.onResume()
        // The session's confirmation is shown right here while the app is in front.
        SilentUpdater.foreground = { confirm ->
            try {
                startActivity(confirm); true
            } catch (e: Exception) {
                false
            }
        }
    }

    override fun onPause() {
        SilentUpdater.foreground = null
        super.onPause()
    }

    // t209u: one engine for the app and the background bridge (see BridgeService.kt).
    override fun provideFlutterEngine(context: Context): FlutterEngine = EngineHolder.get(context)

    // Keep the engine when the bridge service runs; otherwise close it with the activity as before.
    override fun shouldDestroyEngineWithHost(): Boolean = !BridgeService.running

    override fun onCreate(savedInstanceState: Bundle?) {
        EngineHolder.activityAttached = true
        super.onCreate(savedInstanceState)
    }

    override fun onDestroy() {
        EngineHolder.activityAttached = false
        super.onDestroy()
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        // These handlers use the activity; the engine may outlive it (background bridge).
        val m = flutterEngine.dartExecutor.binaryMessenger
        for (c in listOf("molaplan/link", "molaplan/multicast", "molaplan/notify", "molaplan/update")) {
            MethodChannel(m, c).setMethodCallHandler(null)
        }
        super.cleanUpFlutterEngine(flutterEngine)
    }
    private var linkChannel: MethodChannel? = null
    private var initialLink: String? = null

    // molaplan://tile/<id> from a notification tap or the ntfy app (Click header).
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val d = intent.dataString
        if (d != null && d.startsWith("molaplan:")) linkChannel?.invokeMethod("open", d)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        initialLink = intent?.dataString?.takeIf { it.startsWith("molaplan:") }
        linkChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "molaplan/link").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "initial" -> { result.success(initialLink); initialLink = null }
                    else -> result.notImplemented()
                }
            }
        }
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
                // Network scan: this device's name and the default gateway.
                "netInfo" -> {
                    var gw: String? = null
                    try {
                        val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as android.net.ConnectivityManager
                        val lp = cm.getLinkProperties(cm.activeNetwork)
                        gw = lp?.routes?.firstOrNull { it.isDefaultRoute && it.gateway is java.net.Inet4Address }?.gateway?.hostAddress
                    } catch (e: Exception) {}
                    val name = try { Settings.Global.getString(contentResolver, "device_name") } catch (e: Exception) { null }
                    result.success(mapOf(
                        "model" to Build.MODEL,
                        "maker" to Build.MANUFACTURER,
                        "name" to name,
                        "gateway" to gw,
                        "tablet" to (resources.configuration.smallestScreenWidthDp >= 600)
                    ))
                }
                "wifiSettings" -> {
                    startActivity(Intent(Settings.ACTION_WIFI_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // Local notifications (ntfy replies while the app is in the background).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "molaplan/notify").setMethodCallHandler { call, result ->
            when (call.method) {
                "ask" -> {
                    if (Build.VERSION.SDK_INT >= 33 &&
                        checkSelfPermission("android.permission.POST_NOTIFICATIONS") != android.content.pm.PackageManager.PERMISSION_GRANTED
                    ) {
                        requestPermissions(arrayOf("android.permission.POST_NOTIFICATIONS"), 7001)
                    }
                    result.success(null)
                }
                "show" -> {
                    try {
                        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
                        val prio = call.argument<Int>("priority") ?: 3
                        val channel = if (prio >= 4) "alerts" else "replies"
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            nm.createNotificationChannel(
                                android.app.NotificationChannel("replies", "Ilmoitukset", android.app.NotificationManager.IMPORTANCE_DEFAULT)
                            )
                            nm.createNotificationChannel(
                                android.app.NotificationChannel("alerts", "Tärkeät ilmoitukset", android.app.NotificationManager.IMPORTANCE_HIGH)
                            )
                        }
                        val link = call.argument<String>("link")
                        val tap = Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                        if (link != null) { tap.action = Intent.ACTION_VIEW; tap.data = Uri.parse(link) }
                        val id = (System.currentTimeMillis() % 100000).toInt()
                        val open = android.app.PendingIntent.getActivity(
                            this, id, tap,
                            android.app.PendingIntent.FLAG_IMMUTABLE or android.app.PendingIntent.FLAG_UPDATE_CURRENT
                        )
                        val b = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                            android.app.Notification.Builder(this, channel) else @Suppress("DEPRECATION") android.app.Notification.Builder(this)
                        val n = b.setSmallIcon(applicationInfo.icon)
                            .setContentTitle(call.argument<String>("title") ?: "Molaplan")
                            .setContentText(call.argument<String>("body") ?: "")
                            .setStyle(android.app.Notification.BigTextStyle().bigText(call.argument<String>("body") ?: ""))
                            .setContentIntent(open)
                            .setAutoCancel(true)
                            .build()
                        nm.notify(id, n)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // In-app updates.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "molaplan/update").setMethodCallHandler { call, result ->
            when (call.method) {
                "abis" -> result.success(Build.SUPPORTED_ABIS.toList())
                "cacheDir" -> result.success(File(cacheDir, "updates").apply { mkdirs() }.absolutePath)
                "canInstall" -> result.success(
                    Build.VERSION.SDK_INT < Build.VERSION_CODES.O || packageManager.canRequestPackageInstalls()
                )
                "openInstallSettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startActivity(
                            Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName"))
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        )
                    }
                    result.success(null)
                }
                "install" -> {
                    // t228u: never NEW_TASK here. With NEW_TASK the installer joined a stale package
                    // installer task on Samsung (SM-T575) and nothing was shown. Started for a result
                    // in our own task the prompt always appears; if the installer still returns at
                    // once (it went to another task / was swallowed), the PackageInstaller session
                    // path asks instead.
                    val f = File(call.argument<String>("path")!!)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && !packageManager.canRequestPackageInstalls()) {
                        result.success("needs_permission")
                    } else {
                        pendingInstall?.success("superseded")
                        pendingInstall = null
                        try {
                            val uri = FileProvider.getUriForFile(this, "$packageName.updates", f)
                            @Suppress("DEPRECATION")
                            val i = Intent(Intent.ACTION_INSTALL_PACKAGE)
                                .setDataAndType(uri, "application/vnd.android.package-archive")
                                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                .putExtra(Intent.EXTRA_RETURN_RESULT, true)
                            pendingInstall = result
                            pendingInstallFile = f
                            installStartedAt = SystemClock.elapsedRealtime()
                            @Suppress("DEPRECATION")
                            startActivityForResult(i, REQ_INSTALL)
                        } catch (e: Exception) {
                            pendingInstall = null
                            result.success(sessionInstall(f, "intent ${e.javaClass.simpleName}"))
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    companion object {
        const val REQ_INSTALL = 4713
        /** A real prompt takes longer than this to answer; quicker means it was never shown. */
        const val QUICK_RETURN_MS = 1500L
    }
}
