package com.molaplan.molaplan

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.admin.DeviceAdminReceiver
import android.app.admin.DevicePolicyManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageInstaller
import android.content.pm.PackageManager
import android.os.Build
import java.io.File
import java.security.MessageDigest

/** t211u: device-admin component; Molaplan becomes device owner only when provisioned via adb. */
class AdminReceiver : DeviceAdminReceiver()

/**
 * Installs Molaplan's own update APK. Before anything is installed the file must
 *  1. match the expected SHA-256 (from the release's SHA256SUMS), and
 *  2. be signed with exactly the same certificate as the running app, and be this package.
 * As device owner the PackageInstaller session finishes silently (Android 9+: no prompt);
 * otherwise Android asks the user – shown as a notification when no screen is in use.
 */
object SilentUpdater {
    private const val PREFS = "molaplan_update"
    private const val CHANNEL = "updates"

    /** t228u: set while MainActivity is resumed – shows the install confirmation directly. */
    @Volatile var foreground: ((Intent) -> Boolean)? = null

    fun isDeviceOwner(ctx: Context): Boolean {
        val dpm = ctx.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        return dpm.isDeviceOwnerApp(ctx.packageName)
    }

    fun admin(ctx: Context) = ComponentName(ctx, AdminReceiver::class.java)

    private fun sha256(f: File): String {
        val md = MessageDigest.getInstance("SHA-256")
        f.inputStream().use { i ->
            val buf = ByteArray(1 shl 16)
            while (true) {
                val n = i.read(buf)
                if (n <= 0) break
                md.update(buf, 0, n)
            }
        }
        return md.digest().joinToString("") { "%02x".format(it) }
    }

    @Suppress("DEPRECATION")
    private fun certs(p: PackageInfo?): Set<String> =
        p?.signatures?.map { s -> MessageDigest.getInstance("SHA-256").digest(s.toByteArray()).joinToString("") { "%02x".format(it) } }
            ?.toSet() ?: emptySet()

    /** Own signing certificate(s), SHA-256 hex – also reported to Dart for the bridge status. */
    @Suppress("DEPRECATION")
    fun ownCerts(ctx: Context): Set<String> =
        certs(ctx.packageManager.getPackageInfo(ctx.packageName, PackageManager.GET_SIGNATURES))

    /** Returns null when the file is acceptable, else the reason. */
    @Suppress("DEPRECATION")
    fun check(ctx: Context, f: File, expectedSha: String?): String? {
        if (!f.isFile) return "file missing"
        if (expectedSha != null && !sha256(f).equals(expectedSha.trim(), ignoreCase = true)) return "sha256 mismatch"
        val info = ctx.packageManager.getPackageArchiveInfo(f.absolutePath, PackageManager.GET_SIGNATURES)
            ?: return "not an APK"
        if (info.packageName != ctx.packageName) return "wrong package ${info.packageName}"
        val own = ownCerts(ctx)
        val theirs = certs(info)
        if (own.isEmpty() || theirs != own) return "signing certificate differs"
        return null
    }

    fun last(ctx: Context): String? = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString("last", null)

    fun record(ctx: Context, s: String) {
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString("last", "${System.currentTimeMillis()}|$s").apply()
    }

    /** Starts the install; the outcome arrives in [InstallResultReceiver] (and [last]). */
    fun install(ctx: Context, f: File, expectedSha: String?): String {
        val app = ctx.applicationContext
        check(app, f, expectedSha)?.let { record(app, "rejected: $it"); return "rejected: $it" }
        val pi = app.packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
        params.setAppPackageName(app.packageName)
        if (Build.VERSION.SDK_INT >= 31) params.setRequireUserAction(PackageInstaller.SessionParams.USER_ACTION_NOT_REQUIRED)
        val id = pi.createSession(params)
        pi.openSession(id).use { s ->
            s.openWrite("molaplan.apk", 0, f.length()).use { out ->
                f.inputStream().use { it.copyTo(out) }
                s.fsync(out)
            }
            val cb = PendingIntent.getBroadcast(
                app, id, Intent(app, InstallResultReceiver::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_MUTABLE else 0)
            )
            s.commit(cb.intentSender)
        }
        val how = if (isDeviceOwner(app)) "silent" else "prompt"
        record(app, "started ($how)")
        return "started ($how)"
    }

    fun promptNotification(ctx: Context, confirm: Intent) {
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(NotificationChannel(CHANNEL, "Päivitykset", NotificationManager.IMPORTANCE_HIGH))
        }
        val p = PendingIntent.getActivity(
            ctx, 1, confirm.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val b = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) Notification.Builder(ctx, CHANNEL)
        else @Suppress("DEPRECATION") Notification.Builder(ctx)
        nm.notify(
            4712,
            b.setSmallIcon(ctx.applicationInfo.icon)
                .setContentTitle("Molaplan-päivitys valmis")
                .setContentText("Asenna napauttamalla.")
                .setContentIntent(p)
                .setAutoCancel(true)
                .build()
        )
    }
}

class InstallResultReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val status = intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE)
        when (status) {
            PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                // Not device owner: Android must ask. Notification works with the screen off too.
                @Suppress("DEPRECATION")
                val confirm = intent.getParcelableExtra<Intent>(Intent.EXTRA_INTENT)
                if (confirm != null && SilentUpdater.foreground?.invoke(confirm) != true) {
                    SilentUpdater.promptNotification(context, confirm)
                }
                SilentUpdater.record(context, "waiting for user")
            }
            PackageInstaller.STATUS_SUCCESS -> SilentUpdater.record(context, "installed")
            else -> SilentUpdater.record(
                context, "failed $status ${intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE) ?: ""}".trim()
            )
        }
    }
}

/**
 * Maintenance trigger over adb only (protected by android.permission.DUMP, which apps cannot hold):
 *   adb shell am broadcast -a com.molaplan.molaplan.INSTALL_UPDATE -n com.molaplan.molaplan/.UpdateTriggerReceiver
 *       --es path /data/local/tmp/molaplan.apk --es sha256 <hex>
 * Goes through the same checks as the in-app path (sha256 + same signing certificate).
 */
class UpdateTriggerReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val path = intent.getStringExtra("path") ?: return
        val r = try {
            SilentUpdater.install(context, File(path), intent.getStringExtra("sha256"))
        } catch (e: Exception) {
            SilentUpdater.record(context, "error ${e.message}")
            "error ${e.message}"
        }
        resultData = r
    }
}
