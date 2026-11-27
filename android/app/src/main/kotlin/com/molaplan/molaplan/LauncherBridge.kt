package com.molaplan.molaplan

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.drawable.Icon
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.TimeUnit

/** t290u: pinned shortcuts + status widgets + WorkManager refresh. */
object LauncherBridge {
    const val CHANNEL = "molaplan/launcher"
    const val PREFS = "molaplan_launcher"
    const val KEY_WIDGETS = "widgets"
    const val PERIODIC = "molaplan_widget_refresh"
    const val ONCE = "molaplan_widget_refresh_now"
    const val MINUTES = 15L

    fun register(activity: MainActivity, engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            val app = activity.applicationContext
            when (call.method) {
                "supported" -> {
                    val sm = if (Build.VERSION.SDK_INT >= 26) activity.getSystemService(ShortcutManager::class.java) else null
                    val wm = AppWidgetManager.getInstance(activity)
                    val pinWidget = Build.VERSION.SDK_INT >= 26 && wm.isRequestPinAppWidgetSupported
                    result.success(
                        mapOf(
                            "shortcuts" to (sm?.isRequestPinShortcutSupported == true),
                            "widgets" to pinWidget,
                        )
                    )
                }
                "pinShortcut" -> {
                    val id = call.argument<String>("id") ?: ""
                    val title = (call.argument<String>("title") ?: "Molaplan").ifBlank { "Molaplan" }
                    val link = call.argument<String>("link") ?: "molaplan://run/$id"
                    result.success(pinShortcut(activity, id, title, link))
                }
                "pinWidget" -> {
                    val id = call.argument<String>("id") ?: ""
                    val title = call.argument<String>("title") ?: ""
                    val value = call.argument<String>("value") ?: "–"
                    val color = (call.argument<Number>("color") ?: 0xFF1565C0).toInt()
                    val updated = call.argument<String>("updated") ?: ""
                    val tap = call.argument<String>("tap") ?: "open"
                    val link = call.argument<String>("link") ?: "molaplan://tile/$id"
                    val r = pinWidget(activity, id, title, value, color, updated, tap, link)
                    pendingWidget?.let { copyBars(it, call.arguments as? Map<*, *>) }
                    result.success(r)
                }
                "sync" -> {
                    val tiles = call.argument<List<Map<String, Any?>>>("tiles") ?: emptyList()
                    mergeTiles(app, tiles)
                    TileStatusWidget.updateAll(app)
                    result.success(mapOf("ok" to true))
                }
                "watched" -> result.success(watchedIds(app))
                "scheduleRefresh" -> {
                    schedulePeriodic(app)
                    result.success(mapOf("ok" to true))
                }
                "refreshDone" -> result.success(true)
                else -> result.notImplemented()
            }
        }
    }

    fun pinShortcut(activity: MainActivity, id: String, title: String, link: String): Map<String, Any> {
        if (Build.VERSION.SDK_INT < 26) return mapOf("ok" to false, "reason" to "sdk")
        val sm = activity.getSystemService(ShortcutManager::class.java)
        if (sm == null || !sm.isRequestPinShortcutSupported) return mapOf("ok" to false, "reason" to "unsupported")
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(link), activity, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val info = ShortcutInfo.Builder(activity, "run-$id")
            .setShortLabel(title.take(20))
            .setLongLabel(title.take(40))
            .setIcon(Icon.createWithResource(activity, R.mipmap.ic_launcher))
            .setIntent(intent)
            .build()
        return try {
            mapOf("ok" to sm.requestPinShortcut(info, null))
        } catch (e: Exception) {
            mapOf("ok" to false, "reason" to (e.message ?: e.javaClass.simpleName))
        }
    }

    fun pinWidget(
        activity: MainActivity,
        id: String,
        title: String,
        value: String,
        color: Int,
        updated: String,
        tap: String,
        link: String,
    ): Map<String, Any> {
        if (Build.VERSION.SDK_INT < 26) return mapOf("ok" to false, "reason" to "sdk")
        val wm = AppWidgetManager.getInstance(activity)
        val cn = ComponentName(activity, TileStatusWidget::class.java)
        if (!wm.isRequestPinAppWidgetSupported) return mapOf("ok" to false, "reason" to "unsupported")
        pendingWidget = JSONObject()
            .put("id", id)
            .put("title", title)
            .put("value", value)
            .put("color", color)
            .put("updated", updated)
            .put("tap", tap)
            .put("link", link)
        val success = PendingIntent.getBroadcast(
            activity,
            id.hashCode(),
            Intent(activity, WidgetPinnedReceiver::class.java).setAction(WidgetPinnedReceiver.ACTION),
            PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        return try {
            val ok = wm.requestPinAppWidget(cn, null, success)
            if (ok) schedulePeriodic(activity)
            mapOf("ok" to ok)
        } catch (e: Exception) {
            mapOf("ok" to false, "reason" to (e.message ?: e.javaClass.simpleName))
        }
    }

    @Volatile var pendingWidget: JSONObject? = null

    fun attachPending(ctx: Context, appWidgetId: Int) {
        val p = pendingWidget ?: return
        pendingWidget = null
        val all = widgets(ctx)
        all.put(appWidgetId.toString(), p)
        save(ctx, all)
        TileStatusWidget.updateAll(ctx)
        schedulePeriodic(ctx)
    }

    fun widgets(ctx: Context): JSONObject {
        val raw = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY_WIDGETS, "{}") ?: "{}"
        return try { JSONObject(raw) } catch (_: Exception) { JSONObject() }
    }

    fun save(ctx: Context, all: JSONObject) {
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY_WIDGETS, all.toString()).apply()
    }

    fun remove(ctx: Context, ids: IntArray) {
        val all = widgets(ctx)
        for (id in ids) all.remove(id.toString())
        save(ctx, all)
        if (all.length() == 0) {
            WorkManager.getInstance(ctx).cancelUniqueWork(PERIODIC)
        }
    }

    fun watchedIds(ctx: Context): List<String> {
        val all = widgets(ctx)
        val out = LinkedHashSet<String>()
        val keys = all.keys()
        while (keys.hasNext()) {
            val id = all.optJSONObject(keys.next())?.optString("id").orEmpty()
            if (id.isNotEmpty()) out.add(id)
        }
        return out.toList()
    }

    fun hasWidgets(ctx: Context) = widgets(ctx).length() > 0

    fun mergeTiles(ctx: Context, tiles: List<Map<String, Any?>>) {
        if (tiles.isEmpty()) return
        val byId = HashMap<String, Map<String, Any?>>()
        for (t in tiles) {
            val id = t["id"]?.toString() ?: continue
            byId[id] = t
        }
        val all = widgets(ctx)
        val keys = all.keys()
        val names = mutableListOf<String>()
        while (keys.hasNext()) names.add(keys.next())
        for (k in names) {
            val o = all.optJSONObject(k) ?: continue
            val src = byId[o.optString("id")] ?: continue
            if (src["title"] != null) o.put("title", src["title"].toString())
            if (src["value"] != null) o.put("value", src["value"].toString())
            if (src["color"] is Number) o.put("color", (src["color"] as Number).toInt())
            if (src["updated"] != null) o.put("updated", src["updated"].toString())
            if (src["link"] != null) o.put("link", src["link"].toString())
            if (src["tap"] != null) o.put("tap", src["tap"].toString())
            copyBars(o, src)
            all.put(k, o)
        }
        // A newly requested widget may not have an id yet; stash as pending values by tile id.
        save(ctx, all)
        val pending = pendingWidget
        if (pending != null) {
            val src = byId[pending.optString("id")]
            if (src != null) {
                if (src["value"] != null) pending.put("value", src["value"].toString())
                if (src["updated"] != null) pending.put("updated", src["updated"].toString())
                if (src["color"] is Number) pending.put("color", (src["color"] as Number).toInt())
                copyBars(pending, src)
            }
        }
    }

    /** R470: price bars (c/kWh ×10), their colours and the current bar; removed when absent. */
    fun copyBars(o: JSONObject, src: Map<*, *>?) {
        if (src == null) return
        val bars = src["bars"] as? List<*>
        val colors = src["barColors"] as? List<*>
        if (bars == null || bars.isEmpty()) {
            o.remove("bars"); o.remove("barColors"); o.remove("nowBar")
            return
        }
        o.put("bars", JSONArray(bars.map { (it as? Number)?.toInt() ?: 0 }))
        o.put("barColors", JSONArray((colors ?: emptyList<Any>()).map { (it as? Number)?.toLong() ?: 0xFF5E9E7CL }))
        o.put("nowBar", (src["nowBar"] as? Number)?.toInt() ?: -1)
    }

    fun schedulePeriodic(ctx: Context) {
        val constraints = Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build()
        val req = PeriodicWorkRequestBuilder<WidgetRefreshWorker>(MINUTES, TimeUnit.MINUTES)
            .setConstraints(constraints)
            .build()
        WorkManager.getInstance(ctx.applicationContext)
            .enqueueUniquePeriodicWork(PERIODIC, ExistingPeriodicWorkPolicy.KEEP, req)
    }

    fun onIncoming(ctx: Context) {
        TileStatusWidget.updateAll(ctx)
        if (!hasWidgets(ctx)) return
        val engine = FlutterEngineCache.getInstance().get(EngineHolder.ID)
        if (engine != null) {
            Handler(Looper.getMainLooper()).post {
                MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).invokeMethod("refresh", null)
            }
            return
        }
        val req = OneTimeWorkRequestBuilder<WidgetRefreshWorker>()
            .setInitialDelay(2, TimeUnit.SECONDS)
            .build()
        WorkManager.getInstance(ctx.applicationContext)
            .enqueueUniqueWork(ONCE, ExistingWorkPolicy.REPLACE, req)
    }
}
