package com.example.motocaja

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import java.util.Locale

class YapeNotificationListener : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (sbn.packageName != YAPE_PACKAGE) return

        val prefs = getSharedPreferences(YapeActionReceiver.PREFS_NAME, Context.MODE_PRIVATE)
        if (!prefs.getBoolean(KEY_DETECTION_ENABLED, false)) return

        val extras = sbn.notification.extras
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString().orEmpty()
        val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString().orEmpty()
        val subText = extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString().orEmpty()
        val capturedAt = System.currentTimeMillis()

        // Guardamos el último formato real que entregó Yape. Esto nos permite
        // ajustar el parser sin almacenar un historial completo de notificaciones.
        prefs.edit()
            .putString(KEY_DIAGNOSTIC_TITLE, title)
            .putString(KEY_DIAGNOSTIC_TEXT, text)
            .putString(KEY_DIAGNOSTIC_BIG_TEXT, bigText)
            .putLong(KEY_DIAGNOSTIC_TIMESTAMP, capturedAt)
            .apply()

        Log.i(TAG, "Yape notification title=[$title] text=[$text] bigText=[$bigText] subText=[$subText]")

        val combined = listOf(title, text, bigText, subText)
            .filter { it.isNotBlank() }
            .joinToString(" ")

        if (!looksLikeIncomingPayment(combined)) {
            Log.i(TAG, "Yape notification ignored: no incoming-payment signal")
            return
        }

        val amount = extractAmount(combined)
        if (amount == null || amount <= 0.0) {
            Log.i(TAG, "Yape notification ignored: amount not found")
            return
        }

        // Evita avisos repetidos cuando Yape actualiza la misma notificación.
        val fingerprint = "${sbn.id}|${sbn.tag.orEmpty()}|$title|$text|$bigText|${"%.2f".format(Locale.US, amount)}"
        val previousFingerprint = prefs.getString(KEY_LAST_FINGERPRINT, null)
        val previousAt = prefs.getLong(KEY_LAST_FINGERPRINT_AT, 0L)
        if (fingerprint == previousFingerprint && capturedAt - previousAt < DUPLICATE_WINDOW_MS) {
            Log.i(TAG, "Yape notification ignored: duplicate update")
            return
        }

        prefs.edit()
            .putString(KEY_LAST_FINGERPRINT, fingerprint)
            .putLong(KEY_LAST_FINGERPRINT_AT, capturedAt)
            .apply()

        val eventId = "${sbn.key}|$capturedAt|${fingerprint.hashCode()}"
        showRegistrationPrompt(
            eventId = eventId,
            amount = amount,
            detectedAt = capturedAt,
            sourceTitle = title,
            sourceText = if (bigText.isNotBlank()) bigText else text,
        )
    }

    private fun looksLikeIncomingPayment(raw: String): Boolean {
        val text = raw.lowercase(Locale.ROOT)

        val blockedSignals = listOf(
            "enviaste",
            "yapeaste",
            "pagaste",
            "pago realizado",
            "transferiste",
            "enviado con éxito",
            "enviado con exito",
        )
        if (blockedSignals.any(text::contains)) return false

        val incomingSignals = listOf(
            "recibiste",
            "recibido",
            "te yapearon",
            "te yapeó",
            "te yapeo",
            "yape recibido",
            "te enviaron",
            "te envió",
            "te envio",
        )
        return incomingSignals.any(text::contains)
    }

    private fun extractAmount(raw: String): Double? {
        val match = AMOUNT_REGEX.find(raw) ?: return null
        val value = match.groupValues.getOrNull(1)
            ?.replace(',', '.')
            ?.trim()
            ?: return null
        return value.toDoubleOrNull()
    }

    private fun showRegistrationPrompt(
        eventId: String,
        amount: Double,
        detectedAt: Long,
        sourceTitle: String,
        sourceText: String,
    ) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        ensureChannel(manager)

        val notificationId = PROMPT_NOTIFICATION_BASE + (eventId.hashCode() and 0x7fffffff) % 100000

        val registerIntent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra(YapeActionReceiver.EXTRA_FROM_YAPE_ACTION, true)
            putExtra(YapeActionReceiver.EXTRA_NOTIFICATION_ID, notificationId)
            putExtra(YapeActionReceiver.EXTRA_EVENT_ID, eventId)
            putExtra(YapeActionReceiver.EXTRA_AMOUNT, amount.toString())
            putExtra(YapeActionReceiver.EXTRA_TIMESTAMP, detectedAt)
            putExtra(YapeActionReceiver.EXTRA_TITLE, sourceTitle)
            putExtra(YapeActionReceiver.EXTRA_TEXT, sourceText)
        }
        val registerPendingIntent = PendingIntent.getActivity(
            this,
            notificationId,
            registerIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val ignoreIntent = Intent(this, YapeActionReceiver::class.java).apply {
            action = YapeActionReceiver.ACTION_IGNORE
            putExtra(YapeActionReceiver.EXTRA_NOTIFICATION_ID, notificationId)
        }
        val ignorePendingIntent = PendingIntent.getBroadcast(
            this,
            notificationId + 1,
            ignoreIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val contentIntent = PendingIntent.getActivity(
            this,
            notificationId + 2,
            Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val formattedAmount = String.format(Locale.US, "%.2f", amount)
        val notification = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
            .setSmallIcon(R.drawable.ic_stat_motocaja)
            .setContentTitle("Pago Yape detectado")
            .setContentText("Recibiste S/ $formattedAmount. ¿Deseas registrarlo como servicio?")
            .setStyle(
                Notification.BigTextStyle().bigText(
                    "MotoCaja detectó un posible pago recibido por Yape de S/ $formattedAmount. " +
                        "Confirma antes de guardarlo en tus ingresos."
                )
            )
            .setContentIntent(contentIntent)
            .setAutoCancel(true)
            .setCategory(Notification.CATEGORY_STATUS)
            .setPriority(Notification.PRIORITY_HIGH)
            .addAction(android.R.drawable.ic_input_add, "Registrar", registerPendingIntent)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Ignorar", ignorePendingIntent)
            .build()

        manager.notify(notificationId, notification)
    }

    private fun ensureChannel(manager: NotificationManager) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Pagos detectados",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Sugerencias de registro cuando MotoCaja detecta un pago recibido."
        }
        manager.createNotificationChannel(channel)
    }

    companion object {
        private const val TAG = "MotoCajaYape"
        private const val YAPE_PACKAGE = "com.bcp.innovacxion.yapeapp"
        private const val CHANNEL_ID = "motocaja_yape_detected"
        private const val PROMPT_NOTIFICATION_BASE = 2200
        private const val DUPLICATE_WINDOW_MS = 2 * 60 * 1000L

        const val KEY_DETECTION_ENABLED = "detection_enabled"
        const val KEY_DIAGNOSTIC_TITLE = "diagnostic_title"
        const val KEY_DIAGNOSTIC_TEXT = "diagnostic_text"
        const val KEY_DIAGNOSTIC_BIG_TEXT = "diagnostic_big_text"
        const val KEY_DIAGNOSTIC_TIMESTAMP = "diagnostic_timestamp"
        private const val KEY_LAST_FINGERPRINT = "last_fingerprint"
        private const val KEY_LAST_FINGERPRINT_AT = "last_fingerprint_at"

        private val AMOUNT_REGEX = Regex(
            """(?i)S\s*/\.?\s*(\d{1,6}(?:[.,]\d{1,2})?)"""
        )
    }
}
