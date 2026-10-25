package com.whalebook.whale_ledger

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** 每日提醒闹钟触发：发通知即可，重复闹钟会自续。 */
class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        ReminderScheduler.notifyNow(context)
    }
}
