package com.molaplan.molaplan

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.provider.Settings
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import java.util.Calendar
import java.util.Collections
import java.util.concurrent.ConcurrentHashMap
import kotlin.math.min

/**
 * t282u / pt286u: lightweight foreground listener for ntfy JSON streams.
 * Runs without a Flutter engine so camera-panel alarms arrive when Molaplan is closed.
 * Never subscribes to command topics (they carry the PIN).
 */
object NtfyListenFilter {
    fun isCommandTopic(topic: String): Boolean {
        val t = topic.trim().lowercase()
        return t.endsWith("-cmd") || t.contains("-cmd-")
    }

    fun looksLikeStatusJson(body: String): Boolean {
        val s = body.trim()
        if (!s.startsWith("{")) return false
        return try {
            val j = JSONObject(s)
            j.optInt("v", 0) == 1 || j.has("relays") || j.has("state")
        } catch (_: Exception) {
            false
        }
    }

    fun shouldNotify(event: String, title: String, message: String, tags: List<String>): Boolean {
        if (event != "message") return false
        if (title.trim().equals("Tila JSON", ignoreCase = true)) return false
        if (tags.any { it.equals("robot", ignoreCase = true) }) return false
        if (looksLikeStatusJson(message)) return false
        return true
    }

    fun inQuietHours(from: String?, to: String?, nowMin: Int): Boolean {
        val f = parseHm(from) ?: return false
        val t = parseHm(to) ?: return false
        return if (f <= t) nowMin in f until t else nowMin >= f || nowMin < t
    }

    fun parseHm(s: String?): Int? {
        if (s.isNullOrBlank()) return null
        val p = s.trim().split(":")
        if (p.size < 2) return null
        val h = p[0].toIntOrNull() ?: return null
        val m = p[1].toIntOrNull() ?: return null
        if (h !in 0..23 || m !in 0..59) return null
        return h * 60 + m
    }
}

class NtfyListenService : Service() {
    @Volatile private var stop = false
    @Volatile private var generation = 0
    private val workers = Collections.synchronizedList(mutableListOf<Thread>())
    private val connections = Collections.synchronizedList(mutableListOf<HttpURLConnection>())

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startFg()
        restartWorkers()
        if (topics().isEmpty()) {
            stopSelf()
            return START_NOT_STICKY
        }
        return START_STICKY
    }

    override fun onDestroy() {
        stop = true
        generation++
        dropConnections()
        workers.toList().forEach { it.interrupt() }
        workers.clear()
        super.onDestroy()
    }

    private fun dropConnections() {
        connections.toList().forEach { c -> try { c.disconnect() } catch (_: Exception) {} }
        connections.clear()
    }

    private fun startFg() {
        ensureChannels()
        val open = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val b = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            Notification.Builder(this, CH_LISTEN)
        else @Suppress("DEPRECATION") Notification.Builder(this)
        val n = b.setSmallIcon(applicationInfo.icon)
            .setContentTitle("Molaplan")
            .setContentText("Kuuntelee ilmoituksia")
            .setContentIntent(open)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .build()
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(FG_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(FG_ID, n)
        }
    }

    private fun restartWorkers() {
        generation++
        val gen = generation
        dropConnections()
        workers.toList().forEach { it.interrupt() }
        workers.clear()
        stop = false
        for (t in topics()) {
            if (NtfyListenFilter.isCommandTopic(t.topic)) continue
            val th = Thread({ listenLoop(t, gen) }, "ntfy-listen-${t.topic}")
            workers.add(th)
            th.start()
        }
    }

    private fun listenLoop(t: Topic, gen: Int) {
        var backoff = 1000L
        while (!stop && gen == generation && !Thread.currentThread().isInterrupted) {
            var conn: HttpURLConnection? = null
            try {
                val since = lastId(t) ?: (System.currentTimeMillis() / 1000).toString()
                val url = URL("${t.server}/${t.topic}/json?since=$since")
                conn = (url.openConnection() as HttpURLConnection).apply {
                    connectTimeout = 15000
                    readTimeout = 120_000
                    instanceFollowRedirects = true
                    setRequestProperty("Accept", "application/x-ndjson")
                    setRequestProperty("User-Agent", "Molaplan")
                    if (t.token.isNotEmpty()) setRequestProperty("Authorization", "Bearer ${t.token}")
                }
                connections.add(conn)
                if (gen != generation) return
                val code = conn.responseCode
                if (code !in 200..299) {
                    conn.errorStream?.close()
                    throw RuntimeException("http $code")
                }
                BufferedReader(InputStreamReader(conn.inputStream, Charsets.UTF_8)).use { reader ->
                    backoff = 1000L
                    while (!stop && gen == generation && !Thread.currentThread().isInterrupted) {
                        val line = reader.readLine() ?: break
                        if (line.isBlank()) continue
                        handleLine(t, line)
                    }
                }
            } catch (_: InterruptedException) {
                break
            } catch (_: Exception) {
                // Reconnect with backoff; keepalives normally arrive every 30–45 s.
            } finally {
                try { connections.remove(conn) } catch (_: Exception) {}
                try { conn?.disconnect() } catch (_: Exception) {}
            }
            if (stop || gen != generation) break
            try {
                Thread.sleep(backoff)
            } catch (_: InterruptedException) {
                break
            }
            backoff = min(backoff * 2, 60_000L)
        }
    }

    private fun handleLine(t: Topic, line: String) {
        val j = try { JSONObject(line) } catch (_: Exception) { return }
        val event = j.optString("event", "message")
        val id = j.optString("id", "")
        if (id.isNotEmpty()) saveLastId(t, id)
        if (event != "message") return
        val title = j.optString("title", "")
        val message = j.optString("message", "")
        val tags = mutableListOf<String>()
        val ta = j.optJSONArray("tags")
        if (ta != null) for (i in 0 until ta.length()) tags.add(ta.optString(i))
        if (!NtfyListenFilter.shouldNotify(event, title, message, tags)) return
        if (id.isNotEmpty() && !seenIds.add(id)) return
        trimSeen()
        val prio = j.optInt("priority", 3).coerceIn(1, 5)
        if (!allowedByQuiet(prio)) return
        // Flutter already shows in-app banners for the automation topic while the UI is open.
        if (t.kind == "notify" && appForeground) return
        postNotification(title.ifBlank { "Molaplan" }, message, prio, j.optString("click", ""))
    }

    private fun allowedByQuiet(prio: Int): Boolean {
        if (prio >= 5) return true
        val c = config()
        val muted = c.optLong("mutedUntil", 0L)
        if (muted > 0 && System.currentTimeMillis() < muted) return false
        val now = Calendar.getInstance()
        val nowMin = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
        return !NtfyListenFilter.inQuietHours(c.optString("quietFrom", null), c.optString("quietTo", null), nowMin)
    }

    private fun postNotification(title: String, body: String, prio: Int, click: String) {
        ensureChannels()
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        val channel = "ntfy_$prio"
        val tap = Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
        if (click.isNotBlank() && click.startsWith("molaplan:")) {
            tap.action = Intent.ACTION_VIEW
            tap.data = Uri.parse(click)
        }
        val nid = (title + body + System.currentTimeMillis()).hashCode() and 0x7fffffff
        val notifyId = if (nid == FG_ID) nid + 1 else nid
        val open = PendingIntent.getActivity(
            this, notifyId, tap,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val b = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            Notification.Builder(this, channel)
        else @Suppress("DEPRECATION") Notification.Builder(this)
        b.setSmallIcon(applicationInfo.icon)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setContentIntent(open)
            .setAutoCancel(true)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
        if (prio >= 4) {
            @Suppress("DEPRECATION")
            b.setPriority(Notification.PRIORITY_HIGH)
            b.setCategory(if (prio >= 5) Notification.CATEGORY_ALARM else Notification.CATEGORY_STATUS)
        }
        if (prio >= 5) {
            b.setFullScreenIntent(open, true)
        }
        nm.notify(notifyId, b.build())
    }

    private fun ensureChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (nm.getNotificationChannel(CH_LISTEN) == null) {
            val listen = NotificationChannel(CH_LISTEN, "Molaplan kuuntelee", NotificationManager.IMPORTANCE_MIN)
            listen.setShowBadge(false)
            listen.enableVibration(false)
            listen.setSound(null, null)
            nm.createNotificationChannel(listen)
        }
        // R317: ntfy priority 1–5 → min / low / default / high / urgent.
        val names = arrayOf(
            "Vähäiset ilmoitukset",
            "Matalat ilmoitukset",
            "Ilmoitukset",
            "Tärkeät ilmoitukset",
            "Hälytykset"
        )
        val imps = intArrayOf(
            NotificationManager.IMPORTANCE_MIN,
            NotificationManager.IMPORTANCE_LOW,
            NotificationManager.IMPORTANCE_DEFAULT,
            NotificationManager.IMPORTANCE_HIGH,
            NotificationManager.IMPORTANCE_HIGH
        )
        for (i in 1..5) {
            val id = "ntfy_$i"
            if (nm.getNotificationChannel(id) != null) continue
            val ch = NotificationChannel(id, names[i - 1], imps[i - 1])
            ch.lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            if (i >= 4) ch.enableVibration(true)
            if (i == 5) {
                val sound = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                    ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                val aa = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
                ch.setSound(sound, aa)
                if (Build.VERSION.SDK_INT >= 29) ch.setBypassDnd(true)
            }
            nm.createNotificationChannel(ch)
        }
    }

    data class Topic(val server: String, val topic: String, val token: String, val kind: String)

    private fun config(): JSONObject {
        val raw = getSharedPreferences(PREFS, MODE_PRIVATE).getString(KEY_CONFIG, "{}") ?: "{}"
        return try { JSONObject(raw) } catch (_: Exception) { JSONObject() }
    }

    private fun topics(): List<Topic> {
        val arr = config().optJSONArray("topics") ?: return emptyList()
        val out = mutableListOf<Topic>()
        for (i in 0 until arr.length()) {
            val o = arr.optJSONObject(i) ?: continue
            val server = o.optString("server").trim().trimEnd('/')
            val topic = o.optString("topic").trim()
            if (server.isEmpty() || topic.isEmpty()) continue
            if (NtfyListenFilter.isCommandTopic(topic)) continue
            out.add(Topic(server, topic, o.optString("token"), o.optString("kind", "device")))
        }
        return out
    }

    private fun lastId(t: Topic): String? {
        val raw = getSharedPreferences(PREFS, MODE_PRIVATE).getString(KEY_IDS, "{}") ?: "{}"
        val j = try { JSONObject(raw) } catch (_: Exception) { return null }
        val id = j.optString("${t.server}|${t.topic}", "")
        return id.ifEmpty { null }
    }

    private fun saveLastId(t: Topic, id: String) {
        val sp = getSharedPreferences(PREFS, MODE_PRIVATE)
        val j = try { JSONObject(sp.getString(KEY_IDS, "{}") ?: "{}") } catch (_: Exception) { JSONObject() }
        j.put("${t.server}|${t.topic}", id)
        sp.edit().putString(KEY_IDS, j.toString()).apply()
    }

    companion object {
        const val PREFS = "molaplan_ntfy_listen"
        const val KEY_CONFIG = "config"
        const val KEY_IDS = "last_ids"
        const val KEY_FG = "app_fg"
        const val KEY_BATTERY_ASKED = "battery_asked"
        const val CH_LISTEN = "ntfy_listen"
        const val FG_ID = 28201
        private val seenIds: MutableSet<String> = ConcurrentHashMap.newKeySet()

        @Volatile var appForeground: Boolean = false

        private fun trimSeen() {
            if (seenIds.size > 400) {
                val extra = seenIds.size - 200
                val it = seenIds.iterator()
                var i = 0
                while (it.hasNext() && i < extra) { it.next(); it.remove(); i++ }
            }
        }

        fun applyConfig(ctx: Context, json: String) {
            val app = ctx.applicationContext
            app.getSharedPreferences(PREFS, MODE_PRIVATE).edit().putString(KEY_CONFIG, json).apply()
            val empty = try {
                JSONObject(json).optJSONArray("topics")?.length() ?: 0
            } catch (_: Exception) { 0 } == 0
            if (empty) {
                app.stopService(Intent(app, NtfyListenService::class.java))
            } else {
                start(app)
            }
        }

        fun start(ctx: Context) {
            val app = ctx.applicationContext
            val i = Intent(app, NtfyListenService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) app.startForegroundService(i)
            else app.startService(i)
        }

        fun startIfConfigured(ctx: Context) {
            val raw = ctx.applicationContext.getSharedPreferences(PREFS, MODE_PRIVATE).getString(KEY_CONFIG, "") ?: ""
            if (raw.isBlank()) return
            val n = try { JSONObject(raw).optJSONArray("topics")?.length() ?: 0 } catch (_: Exception) { 0 }
            if (n > 0) start(ctx)
        }

        fun setAppForeground(value: Boolean) {
            appForeground = value
        }

        fun batteryExempt(ctx: Context): Boolean {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
            val pm = ctx.applicationContext.getSystemService(Context.POWER_SERVICE) as PowerManager
            return pm.isIgnoringBatteryOptimizations(ctx.applicationContext.packageName)
        }

        fun requestBatteryExemption(ctx: Context): Boolean {
            val app = ctx.applicationContext
            return try {
                app.startActivity(
                    Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:${app.packageName}"))
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                )
                true
            } catch (_: Exception) {
                try {
                    app.startActivity(
                        Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    )
                } catch (_: Exception) {}
                false
            }
        }

        fun markBatteryAsked(ctx: Context) {
            ctx.applicationContext.getSharedPreferences(PREFS, MODE_PRIVATE).edit().putBoolean(KEY_BATTERY_ASKED, true).apply()
        }

        fun batteryAsked(ctx: Context): Boolean =
            ctx.applicationContext.getSharedPreferences(PREFS, MODE_PRIVATE).getBoolean(KEY_BATTERY_ASKED, false)
    }
}
