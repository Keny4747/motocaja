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
        // Se conserva el nombre de preferencias de versiones anteriores.
        const val PREFS_NAME = "motocaja_yape"

        const val ACTION_IGNORE = "com.example.motocaja.PAYMENT_IGNORE"

        const val EXTRA_NOTIFICATION_ID = "notification_id"
        const val EXTRA_EVENT_ID = "event_id"
        const val EXTRA_AMOUNT = "amount"
        const val EXTRA_TIMESTAMP = "timestamp"
        const val EXTRA_TITLE = "title"
        const val EXTRA_TEXT = "text"
        const val EXTRA_PAYMENT_METHOD = "payment_method"
        const val EXTRA_SOURCE_NAME = "source_name"
        const val EXTRA_FROM_PAYMENT_ACTION = "from_payment_action"

        // Alias para intents antiguos todavía presentes en el sistema.
        const val EXTRA_FROM_YAPE_ACTION = "from_yape_action"

        const val KEY_PENDING_EVENT_ID = "pending_event_id"
        const val KEY_PENDING_AMOUNT = "pending_amount"
        const val KEY_PENDING_TIMESTAMP = "pending_timestamp"
        const val KEY_PENDING_TITLE = "pending_title"
        const val KEY_PENDING_TEXT = "pending_text"
        const val KEY_PENDING_PAYMENT_METHOD = "pending_payment_method"
        const val KEY_PENDING_SOURCE_NAME = "pending_source_name"
    }
}
