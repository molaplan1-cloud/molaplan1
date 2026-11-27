package com.molaplan.molaplan

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews

/** t290u: home-screen status widget for any Molaplan tile. */
class TileStatusWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        update(context, appWidgetManager, appWidgetIds)
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        LauncherBridge.remove(context, appWidgetIds)
    }

    companion object {
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
