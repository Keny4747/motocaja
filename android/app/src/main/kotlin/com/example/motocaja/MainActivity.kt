package com.example.motocaja

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.app.NotificationManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "motocaja/yape_notifications"
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        persistPendingYapeIntent(intent)
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                val prefs = getSharedPreferences(
                    YapeActionReceiver.PREFS_NAME,
                    Context.MODE_PRIVATE,
                )

                when (call.method) {
                    "isNotificationAccessGranted" -> {
                        result.success(isNotificationAccessGranted())
                    }

                    "openNotificationAccessSettings" -> {
                        openNotificationAccessSettings()
                        result.success(null)
                    }

                    "getDetectionEnabled" -> {
                        result.success(
                            prefs.getBoolean(
                                YapeNotificationListener.KEY_DETECTION_ENABLED,
                                false,
                            )
                        )
                    }

                    "setDetectionEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        prefs.edit()
                            .putBoolean(
                                YapeNotificationListener.KEY_DETECTION_ENABLED,
                                enabled,
                            )
                            .apply()
                        result.success(null)
                    }

                    "getLastDiagnostic" -> {
                        val timestamp = prefs.getLong(
                            YapeNotificationListener.KEY_DIAGNOSTIC_TIMESTAMP,
                            0L,
                        )
                        if (timestamp == 0L) {
                            result.success(null)
                        } else {
                            result.success(
                                mapOf(
                                    "title" to prefs.getString(
                                        YapeNotificationListener.KEY_DIAGNOSTIC_TITLE,
                                        "",
                                    ),
                                    "text" to prefs.getString(
                                        YapeNotificationListener.KEY_DIAGNOSTIC_TEXT,
                                        "",
                                    ),
                                    "bigText" to prefs.getString(
                                        YapeNotificationListener.KEY_DIAGNOSTIC_BIG_TEXT,
                                        "",
                                    ),
                                    "timestamp" to timestamp,
                                )
                            )
                        }
                    }

                    "consumePendingPayment" -> {
                        val eventId = prefs.getString(
                            YapeActionReceiver.KEY_PENDING_EVENT_ID,
                            null,
                        )
                        val amount = prefs.getString(
                            YapeActionReceiver.KEY_PENDING_AMOUNT,
                            null,
                        )

                        if (eventId.isNullOrBlank() || amount.isNullOrBlank()) {
                            result.success(null)
                        } else {
                            val data = mapOf(
                                "eventId" to eventId,
                                "amount" to amount,
                                "timestamp" to prefs.getLong(
                                    YapeActionReceiver.KEY_PENDING_TIMESTAMP,
                                    System.currentTimeMillis(),
                                ),
                                "title" to prefs.getString(
                                    YapeActionReceiver.KEY_PENDING_TITLE,
                                    "",
                                ),
                                "text" to prefs.getString(
                                    YapeActionReceiver.KEY_PENDING_TEXT,
                                    "",
                                ),
                            )
                            prefs.edit()
                                .remove(YapeActionReceiver.KEY_PENDING_EVENT_ID)
                                .remove(YapeActionReceiver.KEY_PENDING_AMOUNT)
                                .remove(YapeActionReceiver.KEY_PENDING_TIMESTAMP)
                                .remove(YapeActionReceiver.KEY_PENDING_TITLE)
                                .remove(YapeActionReceiver.KEY_PENDING_TEXT)
                                .apply()
                            result.success(data)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        persistPendingYapeIntent(intent)

        if (intent.getBooleanExtra(YapeActionReceiver.EXTRA_FROM_YAPE_ACTION, false)) {
            methodChannel?.invokeMethod("pendingYapePaymentAvailable", null)
        }
    }

    private fun persistPendingYapeIntent(intent: Intent?) {
        if (intent?.getBooleanExtra(YapeActionReceiver.EXTRA_FROM_YAPE_ACTION, false) != true) {
            return
        }

        val eventId = intent.getStringExtra(YapeActionReceiver.EXTRA_EVENT_ID) ?: return
        val amount = intent.getStringExtra(YapeActionReceiver.EXTRA_AMOUNT) ?: return
        val notificationId = intent.getIntExtra(YapeActionReceiver.EXTRA_NOTIFICATION_ID, -1)
        if (notificationId >= 0) {
            val notificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.cancel(notificationId)
        }
        val prefs = getSharedPreferences(YapeActionReceiver.PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit()
            .putString(YapeActionReceiver.KEY_PENDING_EVENT_ID, eventId)
            .putString(YapeActionReceiver.KEY_PENDING_AMOUNT, amount)
            .putLong(
                YapeActionReceiver.KEY_PENDING_TIMESTAMP,
                intent.getLongExtra(
                    YapeActionReceiver.EXTRA_TIMESTAMP,
                    System.currentTimeMillis(),
                ),
            )
            .putString(
                YapeActionReceiver.KEY_PENDING_TITLE,
                intent.getStringExtra(YapeActionReceiver.EXTRA_TITLE),
            )
            .putString(
                YapeActionReceiver.KEY_PENDING_TEXT,
                intent.getStringExtra(YapeActionReceiver.EXTRA_TEXT),
            )
            .apply()
    }

    private fun isNotificationAccessGranted(): Boolean {
        val component = ComponentName(this, YapeNotificationListener::class.java)
        val enabled = Settings.Secure.getString(
            contentResolver,
            "enabled_notification_listeners",
        ) ?: return false

        return enabled.split(':')
            .mapNotNull { ComponentName.unflattenFromString(it) }
            .any { it == component }
    }

    private fun openNotificationAccessSettings() {
        val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
        if (intent.resolveActivity(packageManager) != null) {
            startActivity(intent)
        } else {
            startActivity(Intent(Settings.ACTION_SETTINGS))
        }
    }
}
