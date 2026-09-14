package com.example.motocaja

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class YapeActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val notificationId = intent.getIntExtra(EXTRA_NOTIFICATION_ID, -1)
        if (notificationId >= 0) {
            val manager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.cancel(notificationId)
        }
    }

    companion object {
        const val PREFS_NAME = "motocaja_yape"

        const val ACTION_IGNORE = "com.example.motocaja.YAPE_IGNORE"

        const val EXTRA_NOTIFICATION_ID = "notification_id"
        const val EXTRA_EVENT_ID = "event_id"
        const val EXTRA_AMOUNT = "amount"
        const val EXTRA_TIMESTAMP = "timestamp"
        const val EXTRA_TITLE = "title"
        const val EXTRA_TEXT = "text"
        const val EXTRA_FROM_YAPE_ACTION = "from_yape_action"

        const val KEY_PENDING_EVENT_ID = "pending_event_id"
        const val KEY_PENDING_AMOUNT = "pending_amount"
        const val KEY_PENDING_TIMESTAMP = "pending_timestamp"
        const val KEY_PENDING_TITLE = "pending_title"
        const val KEY_PENDING_TEXT = "pending_text"
    }
}
