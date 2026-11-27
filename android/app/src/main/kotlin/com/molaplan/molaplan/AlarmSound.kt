package com.molaplan.molaplan

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.media.ToneGenerator
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.util.Log

/**
 * R474 (t313u): the alarm sound is played by the app itself – a MediaPlayer on the ALARM usage
 * (alarm volume, also in silent mode), kept in a static field so it is never garbage-collected –
 * instead of relying on the notification channel's sound.
 *
 * Root cause of t313u ("Testaa hälytysääni oli ihan vaiti"): Android allows an app at most 25
 * posted notifications. Every ntfy message had its own notification and nothing cleared them, so
 * the tablet had 25 (ntfy_2/3/4 + listener + relaunch) and NotificationService dropped the test
 * alarm ("Package has already posted or enqueued 25 notifications. Not showing more.") – no
 * notification, so no channel sound. The channel sound would also be lost if the user silenced
 * the channel. Now: the sound never depends on the notification, and [NotifyTrim] keeps room.
 *
 * Test: a few seconds. Real alarm: loops until dismissed (notification tap / "Hiljennä" / swipe /
 * in-app), with a safety stop after 15 min; without "Soi, kunnes ilmoitus avataan" 30 s.
 * Fallbacks: chosen sound → default alarm → ringtone → notification sound → ToneGenerator beeps.
 * testaamatta laitteella.
 */
object AlarmSound {
    private const val TAG = "MolaplanAlarm"
    const val TEST_MS = 6_000L
    const val SHORT_MS = 30_000L
    const val MAX_MS = 15 * 60_000L
    const val ACTION_STOP = "com.molaplan.molaplan.ALARM_STOP"
    const val EXTRA_NOTIFY_ID = "notify_id"

    private val main = Handler(Looper.getMainLooper())

    // Strong references: a local MediaPlayer is finalized (released) by the GC within seconds.
    @Volatile private var player: MediaPlayer? = null
    @Volatile private var tone: ToneGenerator? = null
    private var focus: AudioFocusRequest? = null
    private var appCtx: Context? = null
    private val stopTask = Runnable { stopNow() } // timeout (not the user)

    /** t320u: when the user last silenced the alarm (elapsedRealtime ms; 0 = never). */
    @Volatile var userSilencedAt = 0L

    @Volatile var playing = false
        private set

    val ATTRS: AudioAttributes = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_ALARM)
        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
        .build()

    /** Sounds to try, in order (duplicates and nulls removed). */
    fun candidates(ctx: Context): List<Uri> {
        val out = LinkedHashSet<Uri>()
        AlarmNotifier.pickedSoundUri(ctx)?.let { out.add(it) }
        for (t in intArrayOf(RingtoneManager.TYPE_ALARM, RingtoneManager.TYPE_RINGTONE, RingtoneManager.TYPE_NOTIFICATION)) {
            try {
                RingtoneManager.getActualDefaultRingtoneUri(ctx, t)?.let { out.add(it) }
            } catch (_: Exception) {}
            RingtoneManager.getDefaultUri(t)?.let { out.add(it) }
        }
        return out.toList()
    }

    fun volume(ctx: Context): Pair<Int, Int> {
        val am = ctx.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        return am.getStreamVolume(AudioManager.STREAM_ALARM) to am.getStreamMaxVolume(AudioManager.STREAM_ALARM)
    }

    /** Starts the alarm sound for [durationMs]. Returns whether something is playing. */
    fun start(ctx: Context, durationMs: Long, coalesce: Boolean = true): Boolean {
        val app = ctx.applicationContext
        if (Looper.myLooper() != Looper.getMainLooper()) {
            main.post { start(app, durationMs, coalesce) }
            return true
        }
        // t319u: one alarm sound at a time – a burst of alarm messages does not restart it.
        val sinceSilenced = if (userSilencedAt == 0L) Long.MAX_VALUE else android.os.SystemClock.elapsedRealtime() - userSilencedAt
        if (!NtfyAlarmGate.shouldRestartSound(playing, coalesce, sinceSilenced)) {
            Log.i(TAG, if (playing) "already playing – coalesced" else "silenced ${sinceSilenced / 1000} s ago – not restarted")
            return true
        }
        stopNow()
        appCtx = app
        requestFocus(app)
        var ok = false
        for (uri in candidates(app)) {
            if (play(app, uri)) { ok = true; break }
        }
        if (!ok) ok = startTone()
        if (ok) {
            playing = true
            main.postDelayed(stopTask, durationMs.coerceIn(1_000L, MAX_MS))
        } else {
            abandonFocus()
        }
        Log.i(TAG, "start ${durationMs}ms ok=$ok volume=${volume(app)}")
        return ok
    }

    private fun play(app: Context, uri: Uri): Boolean {
        val mp = MediaPlayer()
        return try {
            mp.setAudioAttributes(ATTRS)
            mp.setDataSource(app, uri)
            mp.isLooping = true
            mp.setVolume(1f, 1f)
            try { mp.setWakeMode(app, PowerManager.PARTIAL_WAKE_LOCK) } catch (_: Exception) {}
            mp.setOnErrorListener { _, what, extra ->
                Log.w(TAG, "player error $what/$extra – beeping instead")
                main.post {
                    releasePlayer()
                    if (playing && tone == null) startTone()
                }
                true
            }
            mp.prepare()
            mp.start()
            player = mp
            true
        } catch (e: Exception) {
            Log.w(TAG, "cannot play $uri: ${e.message}")
            try { mp.release() } catch (_: Exception) {}
            false
        }
    }

    private fun startTone(): Boolean = try {
        val tg = ToneGenerator(AudioManager.STREAM_ALARM, ToneGenerator.MAX_VOLUME)
        tone = tg
        tg.startTone(ToneGenerator.TONE_CDMA_EMERGENCY_RINGBACK)
    } catch (e: Exception) {
        Log.w(TAG, "tone failed: ${e.message}")
        false
    }

    private fun requestFocus(app: Context) {
        try {
            val am = app.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val r = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                    .setAudioAttributes(ATTRS)
                    .setOnAudioFocusChangeListener { }
                    .build()
                focus = r
                am.requestAudioFocus(r)
            } else {
                @Suppress("DEPRECATION")
                am.requestAudioFocus(null, AudioManager.STREAM_ALARM, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
            }
        } catch (_: Exception) {}
    }

    private fun abandonFocus() {
        val app = appCtx ?: return
        try {
            val am = app.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                focus?.let { am.abandonAudioFocusRequest(it) }
            } else {
                @Suppress("DEPRECATION")
                am.abandonAudioFocus(null)
            }
        } catch (_: Exception) {}
        focus = null
    }

    private fun releasePlayer() {
        val p = player ?: return
        player = null
        try { if (p.isPlaying) p.stop() } catch (_: Exception) {}
        try { p.release() } catch (_: Exception) {}
    }

    private fun stopNow() {
        main.removeCallbacks(stopTask)
        releasePlayer()
        tone?.let {
            try { it.stopTone() } catch (_: Exception) {}
            try { it.release() } catch (_: Exception) {}
        }
        tone = null
        if (playing) abandonFocus()
        playing = false
    }

    /** Silences the alarm (any thread) – the user's "Hiljennä" / swipe-away / settings button. */
    fun stop() {
        userSilencedAt = android.os.SystemClock.elapsedRealtime()
        if (Looper.myLooper() != Looper.getMainLooper()) { main.post { stopNow() }; return }
        stopNow()
    }
}

/** Notification "Hiljennä" action and swipe-away: silences the alarm sound. */
class AlarmStopReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        AlarmSound.stop()
        val id = intent.getIntExtra(AlarmSound.EXTRA_NOTIFY_ID, 0)
        if (id != 0 && intent.getBooleanExtra("cancel", false)) {
            (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(id)
        }
    }
}

/**
 * R474: Android shows at most 25 notifications per app and silently drops the rest (t313u). Before
 * posting, the oldest dismissable Molaplan notifications are cancelled so at most [LIMIT] remain –
 * ordinary messages first, alarms only if nothing else is left; ongoing ones (the listener) never.
 */
object NotifyTrim {
    const val LIMIT = 20

    data class Item(val id: Int, val tag: String?, val postTime: Long, val alarm: Boolean, val ongoing: Boolean)

    /** Which notifications to cancel so that one more fits within [limit]. Pure, for tests. */
    fun victims(items: List<Item>, limit: Int = LIMIT): List<Item> {
        val free = items.filter { !it.ongoing }
        val excess = items.size - (limit - 1)
        if (excess <= 0) return emptyList()
        return free.sortedWith(compareBy<Item>({ it.alarm }, { it.postTime })).take(excess)
    }

    fun makeRoom(ctx: Context, limit: Int = LIMIT) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        try {
            val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val items = nm.activeNotifications.map { sbn ->
                val n = sbn.notification
                val ongoing = (n.flags and (android.app.Notification.FLAG_ONGOING_EVENT or
                    android.app.Notification.FLAG_FOREGROUND_SERVICE)) != 0
                val ch = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) n.channelId ?: "" else ""
                Item(sbn.id, sbn.tag, sbn.postTime, ch.startsWith("molaplan_alarm"), ongoing)
            }
            for (v in victims(items, limit)) nm.cancel(v.tag, v.id)
        } catch (_: Exception) {}
    }
}
