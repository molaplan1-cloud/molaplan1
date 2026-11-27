package com.molaplan.molaplan

import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.work.Worker
import androidx.work.WorkerParameters
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/** t290u: at least every 15 minutes, re-read widget tiles through Dart. */
class WidgetRefreshWorker(ctx: Context, params: WorkerParameters) : Worker(ctx, params) {
    override fun doWork(): Result {
        // R482 (t312u): also runs for user logs / trends (Dart reads the logged tiles once).
        if (!LauncherBridge.hasWidgets(applicationContext) && !LauncherBridge.collectsLogs(applicationContext)) {
            return Result.success()
        }
        val existing = FlutterEngineCache.getInstance().get(EngineHolder.ID)
        if (existing != null) return invokeRefresh(existing, destroy = false)
        return runEntrypoint()
    }

    private fun invokeRefresh(engine: FlutterEngine, destroy: Boolean): Result {
        val latch = CountDownLatch(1)
        var ok = false
        Handler(Looper.getMainLooper()).post {
            try {
                MethodChannel(engine.dartExecutor.binaryMessenger, LauncherBridge.CHANNEL)
                    .invokeMethod(
                        "refresh",
                        null,
                        object : MethodChannel.Result {
                            override fun success(result: Any?) { ok = true; latch.countDown() }
                            override fun error(c: String, m: String?, d: Any?) { latch.countDown() }
                            override fun notImplemented() { latch.countDown() }
                        },
                    )
            } catch (_: Exception) {
                latch.countDown()
            }
        }
        val done = latch.await(60, TimeUnit.SECONDS)
        if (destroy) {
            Handler(Looper.getMainLooper()).post { engine.destroy() }
        }
        TileStatusWidget.updateAll(applicationContext)
        return if (done && ok) Result.success() else Result.retry()
    }

    private fun runEntrypoint(): Result {
        val latch = CountDownLatch(1)
        var ok = false
        var engine: FlutterEngine? = null
        Handler(Looper.getMainLooper()).post {
            try {
                val app = applicationContext
                val loader = FlutterInjector.instance().flutterLoader()
                loader.startInitialization(app)
                loader.ensureInitializationComplete(app, null)
                val e = FlutterEngine(app)
                engine = e
                MethodChannel(e.dartExecutor.binaryMessenger, LauncherBridge.CHANNEL).setMethodCallHandler { call, result ->
                    when (call.method) {
                        "sync" -> {
                            val tiles = call.argument<List<Map<String, Any?>>>("tiles") ?: emptyList()
                            LauncherBridge.mergeTiles(app, tiles)
                            TileStatusWidget.updateAll(app)
                            result.success(mapOf("ok" to true))
                        }
                        "watched" -> result.success(LauncherBridge.watchedIds(app))
                        "logCollect" -> result.success(mapOf("ok" to true))
                        "scheduleRefresh" -> {
                            LauncherBridge.schedulePeriodic(app)
                            result.success(mapOf("ok" to true))
                        }
                        "supported" -> result.success(mapOf("shortcuts" to false, "widgets" to true))
                        "refreshDone" -> {
                            ok = true
                            latch.countDown()
                            result.success(true)
                        }
                        else -> result.notImplemented()
                    }
                }
                e.dartExecutor.executeDartEntrypoint(
                    DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "widgetRefreshMain")
                )
            } catch (_: Exception) {
                latch.countDown()
            }
        }
        val done = latch.await(90, TimeUnit.SECONDS)
        engine?.let { eng ->
            Handler(Looper.getMainLooper()).post { try { eng.destroy() } catch (_: Exception) {} }
        }
        TileStatusWidget.updateAll(applicationContext)
        return if (done && ok) Result.success() else Result.retry()
    }
}
