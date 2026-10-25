package com.whalebook.whale_ledger

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** 开机后重新登记每日提醒（重复闹钟会在重启时丢失）。 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action == Intent.ACTION_BOOT_COMPLETED) {
            ReminderScheduler.restoreIfEnabled(context)
        }
    }
}
