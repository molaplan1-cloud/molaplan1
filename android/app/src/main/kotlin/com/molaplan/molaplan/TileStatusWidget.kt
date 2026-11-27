package com.molaplan.molaplan

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject

/** t290u: home-screen status widget for any Molaplan tile. */
class TileStatusWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        update(context, appWidgetManager, appWidgetIds)
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        LauncherBridge.remove(context, appWidgetIds)
    }

    companion object {
        /** R470 (t309u): small today+tomorrow price bars; past hours dimmed, a white line marks now. */
        fun barsBitmap(o: JSONObject): Bitmap? {
            val bars = o.optJSONArray("bars") ?: return null
            val n = bars.length()
            if (n == 0) return null
            val colors = o.optJSONArray("barColors")
            val now = o.optInt("nowBar", -1)
            val w = 480
            val h = 64
            val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
            val c = Canvas(bmp)
            val p = Paint(Paint.ANTI_ALIAS_FLAG)
            var lo = 0
            var hi = 1
            for (i in 0 until n) {
                val v = bars.optInt(i)
                if (v < lo) lo = v
                if (v > hi) hi = v
            }
            val span = (hi - lo).toFloat()
            val zeroY = h - 2 - (0 - lo) / span * (h - 4)
            val step = w.toFloat() / n
            val gap = if (step > 4f) 1f else 0f
            for (i in 0 until n) {
                val v = bars.optInt(i)
                val y = h - 2 - (v - lo) / span * (h - 4)
                val col = colors?.optLong(i, 0xFF5E9E7CL)?.toInt() ?: 0xFF5E9E7C.toInt()
                p.color = col
                p.alpha = if (now < 0 || i >= now) 255 else 110
                val top = minOf(y, zeroY)
                val bottom = maxOf(y, zeroY).coerceAtLeast(top + 2f)
                c.drawRect(i * step + gap, top, (i + 1) * step - gap, bottom, p)
            }
            if (now in 0 until n) {
                p.color = 0xFFFFFFFF.toInt()
                p.alpha = 230
                val x = now * step + step / 2
                c.drawRect(x - 1.5f, 0f, x + 1.5f, h.toFloat(), p)
            }
            return bmp
        }

        fun updateAll(ctx: Context) {
            val wm = AppWidgetManager.getInstance(ctx)
            val ids = wm.getAppWidgetIds(ComponentName(ctx, TileStatusWidget::class.java))
            update(ctx, wm, ids)
        }

        fun update(ctx: Context, wm: AppWidgetManager, ids: IntArray) {
            val all = LauncherBridge.widgets(ctx)
            for (id in ids) {
                val o = all.optJSONObject(id.toString())
                val views = RemoteViews(ctx.packageName, R.layout.tile_status_widget)
                val title = o?.optString("title").orEmpty().ifBlank { ctx.getString(R.string.molaplan_widget_name) }
                val value = o?.optString("value").orEmpty().ifBlank { "–" }
                val updated = o?.optString("updated").orEmpty()
                val color = o?.optInt("color", 0xFF1565C0.toInt()) ?: 0xFF1565C0.toInt()
                val link = o?.optString("link").orEmpty().ifBlank { "molaplan://tile/" }
                views.setTextViewText(R.id.widget_title, title)
                views.setTextViewText(R.id.widget_value, value)
                views.setTextViewText(R.id.widget_updated, updated)
                views.setInt(R.id.widget_accent, "setBackgroundColor", color)
                val chart = o?.let { barsBitmap(it) }
                if (chart != null) {
                    views.setImageViewBitmap(R.id.widget_chart, chart)
                    views.setViewVisibility(R.id.widget_chart, View.VISIBLE)
                } else {
                    views.setViewVisibility(R.id.widget_chart, View.GONE)
                }
                val tap = Intent(ctx, MainActivity::class.java)
                    .setAction(Intent.ACTION_VIEW)
                    .setData(Uri.parse(link))
                    .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                val pi = PendingIntent.getActivity(
                    ctx,
                    id,
                    tap,
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
                )
                views.setOnClickPendingIntent(R.id.widget_root, pi)
                wm.updateAppWidget(id, views)
            }
        }
    }
}

/** Completes requestPinAppWidget: the system fills in EXTRA_APPWIDGET_ID. */
class WidgetPinnedReceiver : android.content.BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
        if (id == AppWidgetManager.INVALID_APPWIDGET_ID) return
        LauncherBridge.attachPending(context, id)
    }

    companion object {
        const val ACTION = "com.molaplan.molaplan.WIDGET_PINNED"
    }
}
