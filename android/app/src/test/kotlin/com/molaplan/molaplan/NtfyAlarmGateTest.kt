package com.molaplan.molaplan

import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** t319u: a replayed historical burst must never ring the alarm. */
class NtfyAlarmGateTest {
    private val topic = "panel-reply"
    private val now = 1_800_000_000L

    // Default rules as Flutter sends them (lib/notify/alarm_rules.dart toJson()).
    private val rules = JSONObject()
        .put("enabled", true).put("urgentIsAlarm", true).put("insistent", false)
        .put("keywords", JSONArray(listOf("hälytys", "murto", "palohälytys", "alarm", "intrusion", "larm", "inbrott", "häire", "sissetung", "alarma", "intrusión")))
        .put("exclude", JSONArray(listOf("kuitattu", "kuittaus", "ei hälytystä", "hälytys pois", "acknowledged", "cleared", "no alarm", "alarm off", "kvitterad", "kinnitatud", "reconocida", "hälytyskuva", "alarm picture", "alarm image", "larmbild", "häirepilt", "imagen de alarma")))
        .put("tags", JSONArray(listOf("rotating_light", "sos", "siren", "police_car_light")))
        .put("topics", JSONObject())

    // The kinds of message a camera alarm panel's reply topic carried in 12 h (generic names).
    private val panel = listOf(
        Triple("Valvonta päälle (etä)", "Etä: Käyttäjä kytki valvonnan – lähtöviive alkoi.", 3 to listOf("lock")),
        Triple("Valvonta pois", "Valvonnan kytki pois: Käyttäjä", 3 to listOf("unlock")),
        Triple("Meno: talo tyhjä", "Valvonta aktiivinen – lähtöviive päättyi.", 2 to listOf("door")),
        Triple("Tulo havaittu", "Sisäliike – tuloviive alkoi. Ellei PIN-koodia anneta, seuraa hälytys.", 4 to listOf("warning")),
        Triple("HÄLYTYS: sisäkamera: ihminen", "Sisäkameran liike valvonnan aikana – sireeni päällä.", 5 to listOf("rotating_light")),
        Triple("Hälytyskuva – Sisäkamera", "You received a file: cam1.jpg", 4 to listOf("camera")),
        Triple("Hälytys kuitattu, valvonta aktiivinen", "Etä kuitattu – sireeni pois.", 4 to listOf("white_check_mark")),
        Triple("Tila JSON", """{"v":1,"state":"away"}""", 2 to listOf("robot")),
        Triple("Tulo", "Käyttäjä saapui (valvonta pois).", 2 to listOf("house")),
        Triple("Pelotevaihe ulkona", "Ei hälytystä – valvonta jatkuu.", 2 to listOf("bulb")),
        Triple("Laite käynnistyi uudelleen, valvonta aktiivinen", "sähkökatko?", 4 to listOf("lock")),
        Triple("Ei muutosta", "Komento ei muuttanut tilaa.", 3 to listOf("information_source")),
    )

    private fun line(id: String, time: Long, title: String, msg: String, prio: Int, tags: List<String>, picture: Boolean = false): String {
        val j = JSONObject().put("id", id).put("time", time).put("event", "message").put("topic", topic)
            .put("title", title).put("message", msg).put("priority", prio).put("tags", JSONArray(tags))
        if (picture) j.put("attachment", JSONObject().put("name", "cam1.jpg").put("url", "https://x/file/a.jpg"))
        return j.toString()
    }

    private fun decide(l: String, seen: Set<String> = emptySet(), filter: String = "auto") =
        NtfyAlarmGate.decide(l, topic, filter, rules, now) { it in seen }

    @Test
    fun historicalBurstAfterInstallRingsNothing() {
        // 12 h of history replayed at once (e.g. since=<unknown id>), 6x each kind.
        var alarms = 0
        var notifies = 0
        var n = 0
        for (round in 0 until 6) for ((title, msg, pt) in panel) {
            val age = 600L + 7000L * round + 60L * n
            val d = decide(line("id${n++}", now - age, title, msg, pt.first, pt.second, title.startsWith("Hälytyskuva")))
            if (d.action == NtfyAlarmGate.Action.ALARM) alarms++
            if (d.action == NtfyAlarmGate.Action.NOTIFY) notifies++
            assertEquals(title, NtfyAlarmGate.Action.STATE_ONLY, d.action)
        }
        assertEquals(0, alarms)
        assertEquals(0, notifies)
    }

    @Test
    fun freshMessagesOnlyRealAlarmRings() {
        fun act(i: Int) = panel[i].let { (t, m, pt) -> decide(line("f$i", now - 5, t, m, pt.first, pt.second, t.startsWith("Hälytyskuva"))).action }

        assertEquals(NtfyAlarmGate.Action.NOTIFY, act(0)) // armed
        assertEquals(NtfyAlarmGate.Action.NOTIFY, act(1)) // disarmed
        assertEquals(NtfyAlarmGate.Action.STATE_ONLY, act(2)) // exit delay over
        assertEquals(NtfyAlarmGate.Action.STATE_ONLY, act(3)) // entry delay
        assertEquals(NtfyAlarmGate.Action.ALARM, act(4)) // HÄLYTYS
        assertEquals(NtfyAlarmGate.Action.NOTIFY, act(5)) // alarm picture: notify, no second ring
        assertEquals(NtfyAlarmGate.Action.NOTIFY, act(6)) // alarm acknowledged
        for (i in 7 until panel.size) assertEquals(panel[i].first, NtfyAlarmGate.Action.STATE_ONLY, act(i))
    }

    @Test
    fun seenIdsAndControlEventsNeverNotify() {
        val l = line("dup", now - 1, "HÄLYTYS: ovi", "", 5, listOf("rotating_light"))
        assertEquals(NtfyAlarmGate.Action.STATE_ONLY, decide(l, seen = setOf("dup")).action)
        val open = """{"id":"kA1","time":$now,"event":"open","topic":"$topic"}"""
        val keep = """{"id":"kA2","time":$now,"event":"keepalive","topic":"$topic"}"""
        for (c in listOf(open, keep)) {
            val d = decide(c)
            assertEquals(NtfyAlarmGate.Action.IGNORE, d.action)
            assertEquals(null, d.cursorId) // never a resume point (root cause of the replays)
        }
        val m = decide(line("m1", now - 1, "Valvonta päälle", "", 3, listOf("lock")))
        assertEquals("m1", m.cursorId)
        assertEquals(now - 1, m.cursorTime)
    }

    @Test
    fun ageLimitAndClockSkew() {
        assertTrue(NtfyAlarmGate.isFresh(now - 120, now))
        assertFalse(NtfyAlarmGate.isFresh(now - 121, now))
        assertFalse(NtfyAlarmGate.isFresh(0, now))
        assertTrue(NtfyAlarmGate.isFresh(now + 60, now))
    }

    @Test
    fun armDisarmNeverAlarmEvenAtUrgent() {
        assertEquals(NtfyAlarmGate.Action.NOTIFY, decide(line("u1", now, "Valvonta päälle", "", 5, listOf("rotating_light"))).action)
        assertEquals(NtfyAlarmGate.Action.NOTIFY, decide(line("u2", now, "Alarm disarmed", "", 5, emptyList())).action)
        // The user can still force a topic to "always alarm".
        rules.put("topics", JSONObject().put(topic, "always"))
        assertEquals(NtfyAlarmGate.Action.ALARM, decide(line("u3", now, "Valvonta päälle", "", 3, emptyList())).action)
        rules.put("topics", JSONObject())
    }

    @Test
    fun oneAlarmSoundAtATime() {
        assertTrue(NtfyAlarmGate.shouldRestartSound(playing = false, coalesce = true))
        assertFalse(NtfyAlarmGate.shouldRestartSound(playing = true, coalesce = true))
        assertTrue(NtfyAlarmGate.shouldRestartSound(playing = true, coalesce = false)) // the test button
    }
}
