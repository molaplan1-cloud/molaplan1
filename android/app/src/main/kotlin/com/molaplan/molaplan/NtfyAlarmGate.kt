package com.molaplan.molaplan

import org.json.JSONObject

/**
 * t319u: what one line of an ntfy JSON stream does – pure logic (no Android), unit-tested with a
 * replayed historical burst (android/app/src/test/…/NtfyAlarmGateTest.kt).
 *
 * Root cause of the phantom alarm sounds after each install (27.11.2026, 16:57 and 17:47): the
 * listener stored the id of ntfy "open"/"keepalive" events as its resume point. Those ids are not
 * message ids, so `since=<id>` matched nothing and the server replayed its whole ~12 h cache; the
 * in-memory "seen" set hid that while the process lived, but a new process (install / restart)
 * classified the replayed HÄLYTYS, two Hälytyskuva and six Tulo havaittu as alarms → 9 starts.
 *
 * Rules: only real messages move the resume point; a message older than [MAX_AGE_S] at receipt or
 * already seen never notifies (it still refreshes state); arming, disarming, alarm end, status and
 * alarm pictures are never alarms (unless the user set the topic to "always alarm").
 */
object NtfyAlarmGate {
    const val MAX_AGE_S = 120L
    private const val FUTURE_SKEW_S = 300L

    enum class Action { IGNORE, STATE_ONLY, NOTIFY, ALARM }

    data class Result(
        val action: Action,
        val reason: String,
        /** Resume point (message id / unix time) – null for control events. */
        val cursorId: String? = null,
        val cursorTime: Long = 0L,
        val id: String = "",
        val title: String = "",
        val message: String = "",
        val prio: Int = 3,
        val click: String = "",
    )

    /** Quiet window after the user silenced the alarm (R508). */
    const val SILENCE_GRACE_MS = 60_000L

    /**
     * R507 / R508: one alarm sound at a time. A new alarm message (e.g. the panel's prio-5
     * "HÄLYTYS jatkuu – kuittaamatta" reminder every 10 min while unacknowledged) never restarts a
     * sound that is playing, and not within [SILENCE_GRACE_MS] after the user silenced it. After
     * that a fresh reminder rings again: the alarm is still unacknowledged at the panel (the siren
     * at home is on) – acknowledging ("Kuittaa") stops the reminders. The test button always restarts.
     */
    fun shouldRestartSound(playing: Boolean, coalesce: Boolean, msSinceUserSilenced: Long = Long.MAX_VALUE): Boolean =
        !coalesce || (!playing && msSinceUserSilenced >= SILENCE_GRACE_MS)

    fun isFresh(msgTime: Long, nowSec: Long): Boolean =
        msgTime > 0 && nowSec - msgTime <= MAX_AGE_S && msgTime - nowSec <= FUTURE_SKEW_S

    /** Alarm channel only for a real alarm: the rules match AND the message is not arm / disarm / end / status / picture. */
    fun isRealAlarm(
        rules: JSONObject?, topic: String, title: String, message: String,
        tags: List<String>, prio: Int, hasAttachment: Boolean,
    ): Boolean {
        if (!AlarmNotifier.isAlarm(rules, topic, title, tags, prio)) return false
        if (rules?.optJSONObject("topics")?.optString(topic, "auto") == "always") return true
        if (hasAttachment) return false // alarm pictures follow the alarm; they notify, never ring again
        return when (NtfyNotifyFilter.classify(title, message, tags)) {
            NtfyNotifyFilter.Kind.ARM, NtfyNotifyFilter.Kind.DISARM,
            NtfyNotifyFilter.Kind.ALARM_END, NtfyNotifyFilter.Kind.STATUS -> false
            else -> true
        }
    }

    fun decide(
        line: String,
        topic: String,
        filter: String,
        rules: JSONObject?,
        nowSec: Long,
        seen: (String) -> Boolean,
        notifyFetchSuccess: Boolean = false,
    ): Result {
        val j = try { JSONObject(line) } catch (_: Exception) { return Result(Action.IGNORE, "not json") }
        val event = j.optString("event", "message")
        if (event != "message") return Result(Action.IGNORE, "control event $event")
        val id = j.optString("id", "")
        val time = j.optLong("time", 0L)
        val title = j.optString("title", "")
        val message = j.optString("message", "")
        val prio = j.optInt("priority", 3).coerceIn(1, 5)
        val tags = mutableListOf<String>()
        val ta = j.optJSONArray("tags")
        if (ta != null) for (i in 0 until ta.length()) tags.add(ta.optString(i))
        fun r(a: Action, why: String) = Result(a, why, id.ifEmpty { null }, time, id, title, message, prio, j.optString("click", ""))
        if (!NtfyListenFilter.shouldNotify(event, title, message, tags)) return r(Action.STATE_ONLY, "status json")
        if (!NtfyNotifyFilter.allows(filter, title, message, tags, prio, notifyFetchSuccess)) return r(Action.STATE_ONLY, "filter $filter")
        if (!isFresh(time, nowSec)) return r(Action.STATE_ONLY, "old (${nowSec - time} s)")
        if (id.isNotEmpty() && seen(id)) return r(Action.STATE_ONLY, "seen")
        val alarm = isRealAlarm(rules, topic, title, message, tags, prio, j.has("attachment"))
        return r(if (alarm) Action.ALARM else Action.NOTIFY, if (alarm) "alarm" else "notify")
    }
}
