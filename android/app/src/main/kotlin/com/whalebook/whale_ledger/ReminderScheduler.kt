package com.whalebook.whale_ledger

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import java.util.Calendar

/**
 * 每日记账提醒：用 AlarmManager 的重复闹钟驱动，不需要精确闹钟权限。
 * 重启后由 BootReceiver 重新登记。
 */
object ReminderScheduler {
    private const val CHANNEL_ID = "daily_reminder"
    private const val NOTIF_ID = 4101
    private const val ALARM_REQUEST = 4102
    private const val PREFS = "whale_reminder"

    fun ensureChannel(ctx: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val mgr = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (mgr.getNotificationChannel(CHANNEL_ID) == null) {
                val ch = NotificationChannel(
                    CHANNEL_ID,
                    "记账提醒",
                    NotificationManager.IMPORTANCE_DEFAULT
                ).apply { description = "每天提醒你记一笔" }
                mgr.createNotificationChannel(ch)
            }
        }
    }

    fun hasPermission(ctx: Context): Boolean {
        if (Build.VERSION.SDK_INT < 33) return true
        return ContextCompat.checkSelfPermission(ctx, Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
    }

    fun schedule(ctx: Context, hour: Int, minute: Int) {
        val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs.edit().putInt("hour", hour).putInt("minute", minute).putBoolean("enabled", true).apply()

        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val next = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            if (timeInMillis <= System.currentTimeMillis()) add(Calendar.DAY_OF_YEAR, 1)
        }
        am.setInexactRepeating(
            AlarmManager.RTC_WAKEUP,
            next.timeInMillis,
            AlarmManager.INTERVAL_DAY,
            alarmIntent(ctx)
        )
    }

    fun cancel(ctx: Context) {
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putBoolean("enabled", false).apply()
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.cancel(alarmIntent(ctx))
    }

    fun restoreIfEnabled(ctx: Context) {
        val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (!prefs.getBoolean("enabled", true)) return
        schedule(ctx, prefs.getInt("hour", 21), prefs.getInt("minute", 30))
    }

    private fun alarmIntent(ctx: Context): PendingIntent {
        val intent = Intent(ctx, ReminderReceiver::class.java)
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            flags = flags or PendingIntent.FLAG_IMMUTABLE
        }
        return PendingIntent.getBroadcast(ctx, ALARM_REQUEST, intent, flags)
    }

    fun notifyNow(ctx: Context) {
        ensureChannel(ctx)
        if (!hasPermission(ctx)) return
        val open = Intent(ctx, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            flags = flags or PendingIntent.FLAG_IMMUTABLE
        }
        val pending = PendingIntent.getActivity(ctx, 4103, open, flags)
        val notif = NotificationCompat.Builder(ctx, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("今天的账记了吗？")
            .setContentText("花 10 秒记一笔，月底才看得清钱花去哪了。")
            .setAutoCancel(true)
            .setContentIntent(pending)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .build()
        try {
            NotificationManagerCompat.from(ctx).notify(NOTIF_ID, notif)
        } catch (_: SecurityException) {
            // 权限被收回，忽略
        }
    }
}
