package com.example.motocaja

import android.app.NotificationManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray

class MainActivity : FlutterActivity() {
    // Nombre heredado: se mantiene para conservar compatibilidad con Flutter.
    private val channelName = "motocaja/yape_notifications"
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        persistPendingPaymentIntent(intent)
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

                    "startRawDiagnosticCapture" -> {
                        val requested = call.argument<Number>("durationMs")?.toLong()
                            ?: 120_000L
                        val duration = requested.coerceIn(30_000L, 300_000L)
                        val until = System.currentTimeMillis() + duration
                        prefs.edit()
                            .putLong(YapeNotificationListener.KEY_RAW_CAPTURE_UNTIL, until)
                            .remove(YapeNotificationListener.KEY_DIAGNOSTIC_HISTORY)
                            .remove(YapeNotificationListener.KEY_DIAGNOSTIC_TIMESTAMP)
                            .remove(YapeNotificationListener.KEY_DIAGNOSTIC_SOURCE_NAME)
                            .remove(YapeNotificationListener.KEY_DIAGNOSTIC_PACKAGE)
                            .remove(YapeNotificationListener.KEY_DIAGNOSTIC_TITLE)
                            .remove(YapeNotificationListener.KEY_DIAGNOSTIC_TEXT)
                            .remove(YapeNotificationListener.KEY_DIAGNOSTIC_BIG_TEXT)
                            .apply()
                        result.success(until)
                    }

                    "stopRawDiagnosticCapture" -> {
                        prefs.edit()
                            .remove(YapeNotificationListener.KEY_RAW_CAPTURE_UNTIL)
                            .apply()
                        result.success(null)
                    }

                    "isRawDiagnosticCaptureActive" -> {
                        result.success(
                            prefs.getLong(
                                YapeNotificationListener.KEY_RAW_CAPTURE_UNTIL,
                                0L,
                            ) > System.currentTimeMillis()
                        )
                    }

                    "getDiagnosticHistory" -> {
                        val raw = prefs.getString(
                            YapeNotificationListener.KEY_DIAGNOSTIC_HISTORY,
                            "[]",
                        ) ?: "[]"
                        val array = try {
                            JSONArray(raw)
                        } catch (_: Exception) {
                            JSONArray()
                        }
                        val items = mutableListOf<Map<String, Any?>>()
                        for (index in 0 until array.length()) {
                            val item = array.optJSONObject(index) ?: continue
                            items += mapOf(
                                "sourceName" to item.optString("sourceName"),
                                "packageName" to item.optString("packageName"),
                                "appLabel" to item.optString("appLabel"),
                                "title" to item.optString("title"),
                                "text" to item.optString("text"),
                                "details" to item.optString("details"),
                                "decision" to item.optString("decision"),
                                "capturedAt" to item.optLong("capturedAt", 0L),
                                "postedAt" to item.optLong("postedAt", 0L),
                                "notificationWhen" to item.optLong("notificationWhen", 0L),
                                "notificationId" to item.optInt("notificationId", -1),
                                "tag" to item.optString("tag"),
                                "channelId" to item.optString("channelId"),
                                "category" to item.optString("category"),
                                "amount" to if (item.has("amount")) item.optDouble("amount") else null,
                            )
                        }
                        result.success(items)
                    }

                    "clearDiagnosticHistory" -> {
                        prefs.edit()
                            .remove(YapeNotificationListener.KEY_DIAGNOSTIC_HISTORY)
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
                                    "sourceName" to prefs.getString(
                                        YapeNotificationListener.KEY_DIAGNOSTIC_SOURCE_NAME,
                                        "",
                                    ),
                                    "packageName" to prefs.getString(
                                        YapeNotificationListener.KEY_DIAGNOSTIC_PACKAGE,
                                        "",
                                    ),
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
                            val paymentMethod = prefs.getString(
                                YapeActionReceiver.KEY_PENDING_PAYMENT_METHOD,
                                "Yape",
                            ) ?: "Yape"
                            val sourceName = prefs.getString(
                                YapeActionReceiver.KEY_PENDING_SOURCE_NAME,
                                paymentMethod,
                            ) ?: paymentMethod

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
                                "paymentMethod" to paymentMethod,
                                "sourceName" to sourceName,
                            )
                            prefs.edit()
                                .remove(YapeActionReceiver.KEY_PENDING_EVENT_ID)
                                .remove(YapeActionReceiver.KEY_PENDING_AMOUNT)
                                .remove(YapeActionReceiver.KEY_PENDING_TIMESTAMP)
                                .remove(YapeActionReceiver.KEY_PENDING_TITLE)
                                .remove(YapeActionReceiver.KEY_PENDING_TEXT)
                                .remove(YapeActionReceiver.KEY_PENDING_PAYMENT_METHOD)
                                .remove(YapeActionReceiver.KEY_PENDING_SOURCE_NAME)
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
        persistPendingPaymentIntent(intent)

        if (isPaymentAction(intent)) {
            methodChannel?.invokeMethod("pendingPaymentAvailable", null)
        }
    }

    private fun isPaymentAction(intent: Intent?): Boolean {
        if (intent == null) return false
        return intent.getBooleanExtra(YapeActionReceiver.EXTRA_FROM_PAYMENT_ACTION, false) ||
            intent.getBooleanExtra(YapeActionReceiver.EXTRA_FROM_YAPE_ACTION, false)
    }

    private fun persistPendingPaymentIntent(intent: Intent?) {
        if (!isPaymentAction(intent)) return
        val paymentIntent = intent ?: return

        val eventId = paymentIntent.getStringExtra(YapeActionReceiver.EXTRA_EVENT_ID) ?: return
        val amount = paymentIntent.getStringExtra(YapeActionReceiver.EXTRA_AMOUNT) ?: return
        val notificationId = paymentIntent.getIntExtra(YapeActionReceiver.EXTRA_NOTIFICATION_ID, -1)
        if (notificationId >= 0) {
            val notificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.cancel(notificationId)
        }

        val paymentMethod =
            paymentIntent.getStringExtra(YapeActionReceiver.EXTRA_PAYMENT_METHOD) ?: "Yape"
        val sourceName =
            paymentIntent.getStringExtra(YapeActionReceiver.EXTRA_SOURCE_NAME) ?: paymentMethod

        val prefs = getSharedPreferences(YapeActionReceiver.PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit()
            .putString(YapeActionReceiver.KEY_PENDING_EVENT_ID, eventId)
            .putString(YapeActionReceiver.KEY_PENDING_AMOUNT, amount)
            .putLong(
                YapeActionReceiver.KEY_PENDING_TIMESTAMP,
                paymentIntent.getLongExtra(
                    YapeActionReceiver.EXTRA_TIMESTAMP,
                    System.currentTimeMillis(),
                ),
            )
            .putString(
                YapeActionReceiver.KEY_PENDING_TITLE,
                paymentIntent.getStringExtra(YapeActionReceiver.EXTRA_TITLE),
            )
            .putString(
                YapeActionReceiver.KEY_PENDING_TEXT,
                paymentIntent.getStringExtra(YapeActionReceiver.EXTRA_TEXT),
            )
            .putString(YapeActionReceiver.KEY_PENDING_PAYMENT_METHOD, paymentMethod)
            .putString(YapeActionReceiver.KEY_PENDING_SOURCE_NAME, sourceName)
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
