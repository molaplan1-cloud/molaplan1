package com.molaplan.molaplan

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import org.json.JSONArray
import org.json.JSONObject
import java.util.Locale

/**
 * R460–R465 (t307u): a dedicated "Hälytykset" channel for real alarms (panel HÄLYTYS, entry
 * delay, alarm pictures) – alarm sound on the ALARM stream (alarm volume, also in silent /
 * vibrate mode), strong vibration, lights, Do-Not-Disturb bypass, full-screen intent and an
 * optional insistent sound. Other messages keep the quieter ntfy_1…ntfy_5 channels.
 * A channel's sound cannot change after creation, so a new sound (or newly granted DND access)
 * creates a new channel id molaplan_alarm_v<N> and deletes the old one.
 * R474 (t313u): the channel itself is silent (vibration, pop-up, DND bypass, full screen); the
 * sound is played by [AlarmSound] on USAGE_ALARM so it no longer depends on the notification
 * being shown (Android's 25-notification limit dropped it) or on the channel's sound setting.
 * A channel made by v0.20.2 or older (with a sound) is replaced by a new silent version.
 * testaamatta laitteella (Galaxy Tab Active3 / Android 13 is the first target).
 */
object AlarmNotifier {
    const val PREFS = "molaplan_alarm"
    private const val KEY_VER = "channel_ver"
    private const val KEY_SOUND = "sound_uri"
    private const val KEY_SOUND_TITLE = "sound_title"
    private const val KEY_DND_AT_CREATE = "dnd_at_create"
    const val EXTRA_ALARM = "molaplan_alarm"
    /** Set on the notification tap (not on the full-screen intent): silences the sound. */
    const val EXTRA_ALARM_STOP = "molaplan_alarm_stop"
    const val TEST_ID = 28299
    val VIBRATION = longArrayOf(0, 900, 300, 900, 300, 900, 300, 1500)

    private fun prefs(ctx: Context) = ctx.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun channelId(ctx: Context): String = "molaplan_alarm_v${prefs(ctx).getInt(KEY_VER, 1)}"

    /** The sound picked in Molaplan, or null (= the device's default alarm sound). */
    fun pickedSoundUri(ctx: Context): Uri? {
        val s = prefs(ctx).getString(KEY_SOUND, null)
        return if (s.isNullOrBlank()) null else Uri.parse(s)
    }

    /** The chosen sound, or the device's default alarm sound (ringtone / notification as fallback). */
    fun soundUri(ctx: Context): Uri? {
        pickedSoundUri(ctx)?.let { return it }
        return RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
    }

    fun soundTitle(ctx: Context): String? {
        val saved = prefs(ctx).getString(KEY_SOUND_TITLE, null)
        if (!saved.isNullOrBlank()) return saved
        // getRingtone() prepares a player; stop() releases it right away (not left to the GC).
        return try {
            soundUri(ctx)?.let { uri ->
                val r = RingtoneManager.getRingtone(ctx, uri)
                val t = r?.getTitle(ctx)
                try { r?.stop() } catch (_: Exception) {}
                t
            }
        } catch (_: Exception) { null }
    }

    private fun channelName(): Pair<String, String> = when (Locale.getDefault().language) {
        "fi" -> "Hälytykset" to "Murto- ja muut hälytykset: kova hälytysääni, myös äänettömällä ja Älä häiritse -tilassa."
        "sv" -> "Larm" to "Inbrotts- och andra larm: hög larmsignal, även i ljudlöst läge och Stör ej."
        "et" -> "Häired" to "Sissetungi- ja muud häired: vali häireheli, ka vaikses ja Mitte segada režiimis."
        "es" -> "Alarmas" to "Alarmas de intrusión y otras: sonido de alarma fuerte, también en silencio y No molestar."
        else -> "Alarms" to "Intrusion and other alarms: loud alarm sound, also in silent and Do Not Disturb mode."
    }

    private fun dndAccess(ctx: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return nm.isNotificationPolicyAccessGranted
    }

    fun ensureChannel(ctx: Context): String {
        val id = channelId(ctx)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return id
        val app = ctx.applicationContext
        val nm = app.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val existing = nm.getNotificationChannel(id)
        // DND access granted after the channel was made: bypass is only honoured from creation.
        if (existing != null && dndAccess(app) && !prefs(app).getBoolean(KEY_DND_AT_CREATE, false) && !existing.canBypassDnd()) {
            return recreate(app)
        }
        // R474: an older channel with its own sound would ring twice (or not at all) – replace it.
        if (existing != null && existing.sound != null) return recreate(app)
        val (name, desc) = channelName()
        if (existing != null) {
            if (existing.name != name) {
                existing.name = name
                existing.description = desc
                nm.createNotificationChannel(existing)
            }
            return id
        }
        val ch = NotificationChannel(id, name, NotificationManager.IMPORTANCE_HIGH)
        ch.description = desc
        ch.lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        ch.enableVibration(true)
        ch.vibrationPattern = VIBRATION
        ch.enableLights(true)
        ch.lightColor = Color.RED
        ch.setShowBadge(true)
        // Silent channel: AlarmSound plays the alarm on AudioAttributes.USAGE_ALARM itself.
        ch.setSound(null, null)
        ch.setBypassDnd(true)
        nm.createNotificationChannel(ch)
        prefs(app).edit().putBoolean(KEY_DND_AT_CREATE, dndAccess(app)).apply()
        // Old versions of this channel.
        for (c in nm.notificationChannels) {
            if (c.id.startsWith("molaplan_alarm_v") && c.id != id) nm.deleteNotificationChannel(c.id)
        }
        return id
    }

    private fun recreate(app: Context): String {
        val p = prefs(app)
        p.edit().putInt(KEY_VER, p.getInt(KEY_VER, 1) + 1).apply()
        return ensureChannel(app)
    }

    /** R474: the sound is played by AlarmSound, so a new sound needs no new channel. */
    fun setSound(ctx: Context, uri: String?, title: String?) {
        val app = ctx.applicationContext
        prefs(app).edit().putString(KEY_SOUND, uri).putString(KEY_SOUND_TITLE, title).apply()
    }

    /** Mirrors lib/notify/alarm_rules.dart alarmMatches(). Without rules: priority 5 only. */
    fun isAlarm(rules: JSONObject?, topic: String, title: String, tags: List<String>, prio: Int): Boolean {
        if (rules == null) return prio >= 5
        if (!rules.optBoolean("enabled", true)) return false
        when (rules.optJSONObject("topics")?.optString(topic, "auto") ?: "auto") {
            "never" -> return false
            "always" -> return true
        }
        if (rules.optBoolean("urgentIsAlarm", true) && prio >= 5) return true
        val t = title.lowercase()
        if (strings(rules.optJSONArray("exclude")).any { it.isNotEmpty() && t.contains(it) }) return false
        val tagSet = strings(rules.optJSONArray("tags")).toSet()
        if (tags.any { tagSet.contains(it.trim().lowercase()) }) return true
        return strings(rules.optJSONArray("keywords")).any { it.isNotEmpty() && t.contains(it) }
    }

    private fun strings(a: JSONArray?): List<String> {
        if (a == null) return emptyList()
        return (0 until a.length()).map { a.optString(it).trim().lowercase() }
    }

    fun canFullScreen(ctx: Context): Boolean {
        if (Build.VERSION.SDK_INT < 34) return true
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return nm.canUseFullScreenIntent()
    }

    private fun stopLabel(): String = when (Locale.getDefault().language) {
        "fi" -> "Hiljennä"
        "sv" -> "Tysta"
        "et" -> "Vaigista"
        "es" -> "Silenciar"
        else -> "Silence"
    }

    /** How long the sound plays: test a few seconds, insistent until dismissed (15 min cap). */
    fun soundMs(test: Boolean, insistent: Boolean): Long = when {
        test -> AlarmSound.TEST_MS
        insistent -> AlarmSound.MAX_MS
        else -> AlarmSound.SHORT_MS
    }

    /** Whether Android will show a notification on the alarm channel at all. */
    fun canNotify(ctx: Context): Boolean {
        val app = ctx.applicationContext
        val nm = app.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 24 && !nm.areNotificationsEnabled()) return false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = nm.getNotificationChannel(ensureChannel(app)) ?: return false
            if (ch.importance == NotificationManager.IMPORTANCE_NONE) return false
        }
        return true
    }

    /**
     * Shows the alarm notification and starts the alarm sound (R474: the sound is played even if
     * Android does not show the notification). Returns whether the sound started.
     */
    fun post(ctx: Context, notifyId: Int, title: String, body: String, tap: Intent, insistent: Boolean, test: Boolean = false): Boolean {
        val app = ctx.applicationContext
        val played = AlarmSound.start(app, soundMs(test, insistent))
        try {
            show(app, notifyId, title, body, tap, insistent && !test)
        } catch (e: Exception) {
            android.util.Log.w("MolaplanAlarm", "notification failed: ${e.message}")
        }
        wake(app)
        return played
    }

    private fun show(app: Context, notifyId: Int, title: String, body: String, tap: Intent, insistent: Boolean) {
        val channel = ensureChannel(app)
        val nm = app.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        NotifyTrim.makeRoom(app)
        val flags = PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        // Full screen: opens Molaplan over the lock screen and keeps ringing.
        val full = PendingIntent.getActivity(app, notifyId, Intent(tap).putExtra(EXTRA_ALARM, true), flags)
        // Tap: opens Molaplan and silences the alarm.
        val open = PendingIntent.getActivity(
            app, notifyId + 1, Intent(tap).putExtra(EXTRA_ALARM, true).putExtra(EXTRA_ALARM_STOP, true), flags
        )
        fun stopIntent(code: Int, cancel: Boolean) = PendingIntent.getBroadcast(
            app, notifyId + code,
            Intent(app, AlarmStopReceiver::class.java).setAction(AlarmSound.ACTION_STOP)
                .putExtra(AlarmSound.EXTRA_NOTIFY_ID, notifyId).putExtra("cancel", cancel),
            flags
        )
        val b = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            Notification.Builder(app, channel)
        else @Suppress("DEPRECATION") Notification.Builder(app)
        b.setSmallIcon(app.applicationInfo.icon)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setContentIntent(open)
            .setDeleteIntent(stopIntent(2, false))
            .setAutoCancel(true)
            .setCategory(Notification.CATEGORY_ALARM)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setColor(Color.RED)
        @Suppress("DEPRECATION")
        b.addAction(Notification.Action.Builder(0, stopLabel(), stopIntent(3, true)).build())
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            @Suppress("DEPRECATION")
            b.setPriority(Notification.PRIORITY_MAX)
                .setVibrate(VIBRATION)
        }
        if (canFullScreen(app)) b.setFullScreenIntent(full, true)
        val n = b.build()
        if (insistent) n.flags = n.flags or Notification.FLAG_INSISTENT
        nm.notify(notifyId, n)
    }

    /** Lights the screen for a moment (the full-screen intent does the rest on the lock screen). */
    private fun wake(app: Context) {
        try {
            val pm = app.getSystemService(Context.POWER_SERVICE) as PowerManager
            if (pm.isInteractive) return
            @Suppress("DEPRECATION")
            val wl = pm.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                "molaplan:alarm"
            )
            wl.acquire(10_000L)
        } catch (_: Exception) {}
    }

    /** Settings → permission checklist. */
    fun status(ctx: Context): Map<String, Any?> {
        val app = ctx.applicationContext
        val nm = app.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val notifications = if (Build.VERSION.SDK_INT >= 24) nm.areNotificationsEnabled() else true
        var channelOn = true
        var channelBypass = true
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = nm.getNotificationChannel(ensureChannel(app))
            channelOn = ch != null && ch.importance >= NotificationManager.IMPORTANCE_HIGH
            channelBypass = ch?.canBypassDnd() ?: false
        }
        return mapOf(
            "notifications" to notifications,
            "channel" to channelOn,
            "dnd" to (dndAccess(app) && channelBypass),
            "fullScreen" to canFullScreen(app),
            "battery" to NtfyListenService.batteryExempt(app),
            "sound" to soundTitle(app),
            "volume" to AlarmSound.volume(app).first,
            "maxVolume" to AlarmSound.volume(app).second,
            "playing" to AlarmSound.playing,
            "sdk" to Build.VERSION.SDK_INT,
        )
    }

    fun openSettings(ctx: Context, what: String): Boolean {
        val app = ctx.applicationContext
        val pkg = app.packageName
        val i = when (what) {
            "dnd" -> Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
            "fullScreen" -> if (Build.VERSION.SDK_INT >= 34)
                Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, Uri.parse("package:$pkg"))
            else null
            "channel" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
                    .putExtra(Settings.EXTRA_APP_PACKAGE, pkg)
                    .putExtra(Settings.EXTRA_CHANNEL_ID, ensureChannel(app))
            else null
            "notifications" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, pkg)
            else null
            "battery" -> return NtfyListenService.requestBatteryExemption(app)
            "sound" -> Intent(Settings.ACTION_SOUND_SETTINGS)
            else -> null
        } ?: Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$pkg"))
        return try {
            app.startActivity(i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            true
        } catch (_: Exception) {
            try {
                app.startActivity(
                    Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$pkg"))
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                )
            } catch (_: Exception) {}
            false
        }
    }
}
