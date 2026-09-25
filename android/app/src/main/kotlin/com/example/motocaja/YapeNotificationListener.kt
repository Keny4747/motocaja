package com.example.motocaja

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.os.Bundle
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import java.text.Normalizer
import java.util.Locale
import org.json.JSONArray
import org.json.JSONObject

// El nombre de la clase se conserva para mantener el permiso de acceso a
// notificaciones en instalaciones existentes. Ahora detecta Yape y Plin.
class YapeNotificationListener : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        // Nunca procesar las notificaciones creadas por la propia MotoCaja.
        if (sbn.packageName == packageName) return

        val prefs = getSharedPreferences(YapeActionReceiver.PREFS_NAME, Context.MODE_PRIVATE)
        if (!prefs.getBoolean(KEY_DETECTION_ENABLED, false)) return

        val capturedAt = System.currentTimeMillis()
        val appLabel = applicationLabelFor(sbn.packageName)
        val identitySource = sourceForIdentity(sbn.packageName, appLabel)
        val rawCaptureActive = prefs.getLong(KEY_RAW_CAPTURE_UNTIL, 0L) > capturedAt

        // Algunas apps bancarias incluyen Parcelables propios dentro de extras.
        // Si uno falla al deserializarse no debemos perder toda la notificacion.
        val payload = try {
            extractNotificationPayload(sbn.notification)
        } catch (error: Throwable) {
            Log.e(TAG, "No se pudieron leer todos los extras de ${sbn.packageName}", error)
            extractBasicPayloadSafely(sbn.notification, error)
        }
        val contextText = buildNotificationContext(sbn, payload)

        // Captura temporal de diagnostico: durante dos minutos guardamos TODAS
        // las notificaciones externas en el telefono, sin filtrarlas por banco.
        // Se activa manualmente desde Configuracion y expira sola. Esto permite
        // descubrir el package/texto real de Plin incluso si la entidad cambia.
        if (rawCaptureActive) {
            saveDiagnosticEvent(
                prefs = prefs,
                sbn = sbn,
                appLabel = appLabel,
                payload = payload,
                source = identitySource,
                capturedAt = capturedAt,
                decision = "CAPTURA RAW: notificacion observada antes de filtros",
                amount = extractAmount(contextText),
            )
        }

        // Algunas entidades cambian el package de su app y Android puede no
        // entregar el nombre visible si el paquete no esta declarado en queries.
        // Para paquetes desconocidos continuamos cuando el contenido menciona
        // Plin. Si la captura temporal esta activa, el evento ya quedo guardado
        // arriba aunque luego se descarte para registro automatico.
        if (identitySource == null && !containsPlinSignal(contextText)) {
            return
        }

        val source = identitySource ?: sourceForNotification(
            packageName = sbn.packageName,
            appLabel = appLabel,
            raw = contextText,
        )

        if (source == null) {
            saveDiagnosticEvent(
                prefs = prefs,
                sbn = sbn,
                appLabel = appLabel,
                payload = payload,
                source = null,
                capturedAt = capturedAt,
                decision = "Ignorada: entidad candidata, pero origen Plin no confirmado",
                amount = extractAmount(contextText),
            )
            return
        }

        Log.i(
            TAG,
            "${source.sourceName} notification package=[${sbn.packageName}] " +
                "title=[${payload.title}] content=[$contextText]"
        )

        val direction = classifyPaymentDirection(contextText)
        if (!direction.incoming) {
            saveDiagnosticEvent(
                prefs = prefs,
                sbn = sbn,
                appLabel = appLabel,
                payload = payload,
                source = source,
                capturedAt = capturedAt,
                decision = "Ignorada: ${direction.reason}",
                amount = extractAmount(contextText),
            )
            Log.i(TAG, "${source.sourceName} notification ignored: ${direction.reason}")
            return
        }

        val amount = extractAmount(contextText)
        if (amount == null || amount <= 0.0) {
            saveDiagnosticEvent(
                prefs = prefs,
                sbn = sbn,
                appLabel = appLabel,
                payload = payload,
                source = source,
                capturedAt = capturedAt,
                decision = "Ignorada: parece ingreso, pero no se encontro un monto",
                amount = null,
            )
            Log.i(TAG, "${source.sourceName} notification ignored: amount not found")
            return
        }

        val fingerprint =
            "${sbn.packageName}|${sbn.id}|${sbn.tag.orEmpty()}|$contextText|" +
                "${"%.2f".format(Locale.US, amount)}"
        val previousFingerprint = prefs.getString(KEY_LAST_FINGERPRINT, null)
        val previousAt = prefs.getLong(KEY_LAST_FINGERPRINT_AT, 0L)
        if (fingerprint == previousFingerprint && capturedAt - previousAt < DUPLICATE_WINDOW_MS) {
            saveDiagnosticEvent(
                prefs = prefs,
                sbn = sbn,
                appLabel = appLabel,
                payload = payload,
                source = source,
                capturedAt = capturedAt,
                decision = "Ignorada: actualizacion duplicada de la misma notificacion",
                amount = amount,
            )
            Log.i(TAG, "${source.sourceName} notification ignored: duplicate update")
            return
        }

        prefs.edit()
            .putString(KEY_LAST_FINGERPRINT, fingerprint)
            .putLong(KEY_LAST_FINGERPRINT_AT, capturedAt)
            .apply()

        saveDiagnosticEvent(
            prefs = prefs,
            sbn = sbn,
            appLabel = appLabel,
            payload = payload,
            source = source,
            capturedAt = capturedAt,
            decision = "Detectada: pago recibido candidato",
            amount = amount,
        )

        val eventId = "${sbn.key}|$capturedAt|${fingerprint.hashCode()}"
        showRegistrationPrompt(
            eventId = eventId,
            amount = amount,
            detectedAt = capturedAt,
            sourceTitle = payload.title,
            sourceText = payload.bestBody,
            source = source,
        )
    }

    private fun buildNotificationContext(
        sbn: StatusBarNotification,
        payload: NotificationPayload,
    ): String {
        return listOf(
            payload.combined,
            notificationChannelId(sbn.notification),
            sbn.notification.category.orEmpty(),
            sbn.notification.group.orEmpty(),
            sbn.tag.orEmpty(),
        )
            .map { it.trim() }
            .filter { it.isNotBlank() }
            .distinct()
            .joinToString(" ")
    }

    private fun notificationChannelId(notification: Notification): String {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            notification.channelId.orEmpty()
        } else {
            ""
        }
    }

    private fun extractBasicPayloadSafely(
        notification: Notification,
        error: Throwable? = null,
    ): NotificationPayload {
        val extras = notification.extras
        val title = safeCharSequence(extras, Notification.EXTRA_TITLE)
        val text = safeCharSequence(extras, Notification.EXTRA_TEXT)
        val bigText = safeCharSequence(extras, Notification.EXTRA_BIG_TEXT)
        val parts = listOf(title, text, bigText)
            .map { it.trim() }
            .filter { it.isNotBlank() }
            .distinct()
        val combined = parts.joinToString(" ")
        val errorText = error?.let {
            "Error leyendo extras: ${it.javaClass.simpleName}: ${it.message.orEmpty()}"
        }.orEmpty()
        return NotificationPayload(
            title = title,
            text = text,
            bestBody = bigText.ifBlank { text.ifBlank { combined } },
            diagnosticText = listOf(combined, errorText)
                .filter { it.isNotBlank() }
                .joinToString("\n"),
            combined = combined,
        )
    }

    private fun safeCharSequence(bundle: Bundle, key: String): String {
        return try {
            bundle.getCharSequence(key)?.toString().orEmpty()
        } catch (_: Throwable) {
            ""
        }
    }

    private fun safeCharSequenceArray(bundle: Bundle, key: String): List<String> {
        return try {
            bundle.getCharSequenceArray(key)
                ?.map { it.toString() }
                ?.filter { it.isNotBlank() }
                .orEmpty()
        } catch (_: Throwable) {
            emptyList()
        }
    }

    private fun extractNotificationPayload(notification: Notification): NotificationPayload {
        val extras = notification.extras
        val title = safeCharSequence(extras, Notification.EXTRA_TITLE)
        val bigTitle = safeCharSequence(extras, Notification.EXTRA_TITLE_BIG)
        val text = safeCharSequence(extras, Notification.EXTRA_TEXT)
        val bigText = safeCharSequence(extras, Notification.EXTRA_BIG_TEXT)
        val subText = safeCharSequence(extras, Notification.EXTRA_SUB_TEXT)
        val summaryText = safeCharSequence(extras, Notification.EXTRA_SUMMARY_TEXT)
        val infoText = safeCharSequence(extras, Notification.EXTRA_INFO_TEXT)
        val textLines = safeCharSequenceArray(extras, Notification.EXTRA_TEXT_LINES)

        // Algunas apps bancarias guardan el texto visible en claves propias o
        // dentro de bundles de MessagingStyle. Recuperamos tambien esos campos.
        val allExtraText = collectTextValues(extras)

        val parts = buildList {
            add(title)
            add(bigTitle)
            add(text)
            add(bigText)
            add(subText)
            add(summaryText)
            add(infoText)
            addAll(textLines)
            addAll(allExtraText)
        }
            .map { it.trim() }
            .filter { it.isNotBlank() }
            .distinct()

        val combined = parts.joinToString(" ")
        val diagnosticText = buildList {
            if (bigText.isNotBlank()) add(bigText)
            if (subText.isNotBlank()) add("Subtexto: $subText")
            if (summaryText.isNotBlank()) add("Resumen: $summaryText")
            if (infoText.isNotBlank()) add("Info: $infoText")
            if (textLines.isNotEmpty()) add("Lineas: ${textLines.joinToString(" | ")}")

            val additional = allExtraText
                .map { it.trim() }
                .filter { it.isNotBlank() }
                .filterNot { it == title || it == bigTitle || it == text || it == bigText }
                .filterNot { it == subText || it == summaryText || it == infoText }
                .distinct()
            if (additional.isNotEmpty()) {
                add("Extras: ${additional.joinToString(" | ")}")
            }
        }.joinToString("\n")

        return NotificationPayload(
            title = title.ifBlank { bigTitle },
            text = text,
            bestBody = when {
                bigText.isNotBlank() -> bigText
                textLines.isNotEmpty() -> textLines.joinToString(" ")
                text.isNotBlank() -> text
                summaryText.isNotBlank() -> summaryText
                else -> combined
            },
            diagnosticText = diagnosticText.ifBlank { combined },
            combined = combined,
        )
    }

    private fun collectTextValues(bundle: Bundle, depth: Int = 0): List<String> {
        if (depth > 2) return emptyList()
        val values = mutableListOf<String>()

        val keys = try {
            bundle.keySet().toList()
        } catch (_: Throwable) {
            return values
        }

        for (key in keys) {
            @Suppress("DEPRECATION")
            val value = try {
                bundle.get(key)
            } catch (_: Throwable) {
                continue
            }
            when (value) {
                is CharSequence -> values += value.toString()
                is Bundle -> values += collectTextValues(value, depth + 1)
                is Array<*> -> value.forEach { item ->
                    when (item) {
                        is CharSequence -> values += item.toString()
                        is Bundle -> values += collectTextValues(item, depth + 1)
                    }
                }
                is Collection<*> -> value.forEach { item ->
                    when (item) {
                        is CharSequence -> values += item.toString()
                        is Bundle -> values += collectTextValues(item, depth + 1)
                    }
                }
            }
        }

        return values
    }

    private fun sourceForNotification(
        packageName: String,
        appLabel: String,
        raw: String,
    ): PaymentSource? {
        sourceForIdentity(packageName, appLabel)?.let { return it }

        // Si el propio aviso menciona Plin, aceptamos el package real que Android
        // nos entrega aunque esa entidad todavia no este en nuestra tabla. Esto
        // permite descubrir cambios de package sin abrir la puerta a notificaciones
        // ajenas: sin una senal Plin explicita, un package desconocido se descarta.
        if (containsPlinSignal(raw)) {
            return PaymentSource(
                paymentMethod = "Plin",
                sourceName = participantNameForIdentity(packageName, appLabel)
                    ?: appLabel.ifBlank { packageName },
            )
        }

        return null
    }

    private fun sourceForIdentity(packageName: String, appLabel: String): PaymentSource? {
        sourceForPackage(packageName)?.let { return it }

        val normalized = normalizeForMatching("$packageName $appLabel")
        if (normalized.contains(" yape") || normalized.endsWith("yape") || normalized.contains(".yape")) {
            return PaymentSource("Yape", "Yape")
        }

        val participant = participantNameForIdentity(packageName, appLabel)
        if (participant != null) {
            return PaymentSource("Plin", participant)
        }

        return null
    }

    private fun sourceForPackage(packageName: String): PaymentSource? {
        return when (packageName) {
            YAPE_PACKAGE -> PaymentSource("Yape", "Yape")
            BBVA_PACKAGE -> PaymentSource("Plin", "BBVA")
            INTERBANK_PACKAGE -> PaymentSource("Plin", "Interbank")
            INTERBANK_BUSINESS_PACKAGE -> PaymentSource("Plin", "Interbank Negocios")
            SCOTIABANK_PACKAGE -> PaymentSource("Plin", "Scotiabank")
            BANBIF_PACKAGE -> PaymentSource("Plin", "BanBif")
            CAJA_AREQUIPA_PACKAGE,
            CAJA_AREQUIPA_LEGACY_PACKAGE -> PaymentSource("Plin", "Caja Arequipa")
            CAJA_ICA_PACKAGE -> PaymentSource("Plin", "Caja Ica")
            CAJA_HUANCAYO_PACKAGE -> PaymentSource("Plin", "Caja Huancayo")
            FINANCIERA_CONFIANZA_PACKAGE -> PaymentSource("Plin", "Financiera Confianza")
            ALFIN_PACKAGE -> PaymentSource("Plin", "Alfin Banco")
            LIGO_PACKAGE -> PaymentSource("Plin", "Ligo")
            MIBANCO_PACKAGE -> PaymentSource("Plin", "Mibanco")
            PICHINCHA_PACKAGE -> PaymentSource("Plin", "Banco Pichincha")
            else -> null
        }
    }

    private fun participantNameForIdentity(packageName: String, appLabel: String): String? {
        val identity = normalizeForMatching("$packageName $appLabel")
        return when {
            identity.contains("bbva") -> "BBVA"
            identity.contains("interbank") -> "Interbank"
            identity.contains("scotiabank") || identity.contains("blpm") -> "Scotiabank"
            identity.contains("banbif") -> "BanBif"
            identity.contains("caja arequipa") || identity.contains("cajaarq") ||
                identity.contains("cmac.cajamovilaqp") -> "Caja Arequipa"
            identity.contains("caja ica") || identity.contains("cmacica") -> "Caja Ica"
            identity.contains("caja huancayo") || identity.contains("cajahuancayo") -> "Caja Huancayo"
            identity.contains("confianza") -> "Financiera Confianza"
            identity.contains("alfin") -> "Alfin Banco"
            identity.contains("ligo") || identity.contains("tarjetasperuanasprepago") -> "Ligo"
            identity.contains("mibanco") -> "Mibanco"
            identity.contains("pichincha") -> "Banco Pichincha"
            Regex("(^|[^a-z])gnb([^a-z]|$)").containsMatchIn(identity) -> "Banco GNB"
            identity.contains("caja cusco") || identity.contains("cajacusco") -> "Caja Cusco"
            identity.contains("caja trujillo") || identity.contains("cajatrujillo") -> "Caja Trujillo"
            identity.contains("caja piura") || identity.contains("cajapiura") -> "Caja Piura"
            identity.contains("caja sullana") || identity.contains("cajasullana") -> "Caja Sullana"
            identity.contains("caja maynas") || identity.contains("cajamaynas") -> "Caja Maynas"
            identity.contains("caja tacna") || identity.contains("cajatacna") -> "Caja Tacna"
            identity.contains("caja paita") || identity.contains("cajapaita") -> "Caja Paita"
            identity.contains("caja del santa") || identity.contains("cajadelsanta") -> "Caja del Santa"
            identity.contains("caja centro") || identity.contains("cajacentro") -> "Caja Centro"
            else -> null
        }
    }

    private fun looksLikePlinParticipantIdentity(packageName: String, appLabel: String): Boolean {
        return participantNameForIdentity(packageName, appLabel) != null
    }

    private fun saveDiagnosticEvent(
        prefs: SharedPreferences,
        sbn: StatusBarNotification,
        appLabel: String,
        payload: NotificationPayload,
        source: PaymentSource?,
        capturedAt: Long,
        decision: String,
        amount: Double?,
    ) {
        val sourceName = source?.sourceName ?: appLabel.ifBlank { "Origen no reconocido" }
        val metadata = buildList {
            add(payload.diagnosticText)
            val channelId = notificationChannelId(sbn.notification)
            if (channelId.isNotBlank()) {
                add("Canal: $channelId")
            }
            if (!sbn.notification.category.isNullOrBlank()) {
                add("Categoria: ${sbn.notification.category}")
            }
            if (!sbn.notification.group.isNullOrBlank()) {
                add("Grupo: ${sbn.notification.group}")
            }
            if (!sbn.tag.isNullOrBlank()) add("Tag: ${sbn.tag}")
            add("Decision: $decision")
            if (amount != null) add("Monto interpretado: ${"%.2f".format(Locale.US, amount)}")
        }.joinToString("\n")

        // Compatibilidad con la pantalla de diagnostico anterior.
        prefs.edit()
            .putString(KEY_DIAGNOSTIC_SOURCE_NAME, sourceName)
            .putString(KEY_DIAGNOSTIC_PACKAGE, sbn.packageName)
            .putString(KEY_DIAGNOSTIC_TITLE, payload.title)
            .putString(KEY_DIAGNOSTIC_TEXT, payload.text)
            .putString(KEY_DIAGNOSTIC_BIG_TEXT, metadata)
            .putLong(KEY_DIAGNOSTIC_TIMESTAMP, capturedAt)
            .apply()

        val event = JSONObject().apply {
            put("sourceName", sourceName)
            put("packageName", sbn.packageName)
            put("appLabel", appLabel)
            put("title", payload.title)
            put("text", payload.text)
            put("details", metadata)
            put("decision", decision)
            put("capturedAt", capturedAt)
            put("postedAt", sbn.postTime)
            put("notificationWhen", sbn.notification.`when`)
            put("notificationId", sbn.id)
            put("tag", sbn.tag.orEmpty())
            put("channelId", notificationChannelId(sbn.notification))
            put("category", sbn.notification.category.orEmpty())
            if (amount != null) put("amount", amount)
        }
        appendDiagnosticHistory(prefs, event)
    }

    private fun appendDiagnosticHistory(prefs: SharedPreferences, event: JSONObject) {
        val previous = try {
            JSONArray(prefs.getString(KEY_DIAGNOSTIC_HISTORY, "[]") ?: "[]")
        } catch (_: Exception) {
            JSONArray()
        }
        val updated = JSONArray().put(event)
        val limit = minOf(previous.length(), MAX_DIAGNOSTIC_HISTORY - 1)
        for (index in 0 until limit) {
            updated.put(previous.optJSONObject(index) ?: continue)
        }
        prefs.edit().putString(KEY_DIAGNOSTIC_HISTORY, updated.toString()).apply()
    }

    private fun applicationLabelFor(packageName: String): String {
        return try {
            @Suppress("DEPRECATION")
            val applicationInfo = packageManager.getApplicationInfo(packageName, 0)
            packageManager.getApplicationLabel(applicationInfo).toString()
        } catch (_: Exception) {
            ""
        }
    }

    private fun classifyPaymentDirection(raw: String): PaymentDecision {
        val text = normalizeForMatching(raw)

        // Senales inequívocas de una operacion que SALIO del telefono/cuenta.
        // Se evaluan primero para evitar el falso positivo observado cuando la
        // confirmacion de un Plin enviado llega varios segundos despues.
        val strongOutgoingSignals = listOf(
            "enviaste",
            "has enviado",
            "dinero enviado",
            "enviado con exito",
            "tu plin fue enviado",
            "plin enviado",
            "plineo enviado",
            "realizaste un plin",
            "hiciste un plin",
            "plineaste",
            "yapeaste",
            "pagaste",
            "transferiste",
            "transferencia enviada",
            "compra realizada",
            "retiro realizado",
            "se debito",
            "debitamos",
        )
        val strongOutgoingMatch = strongOutgoingSignals.firstOrNull(text::contains)
        if (strongOutgoingMatch != null) {
            return PaymentDecision(false, "señal de salida '$strongOutgoingMatch'")
        }

        val incomingRegexMatch = INCOMING_PAYMENT_REGEXES
            .firstOrNull { it.containsMatchIn(text) }
        if (incomingRegexMatch != null) {
            return PaymentDecision(true, "patron de ingreso '${incomingRegexMatch.pattern}'")
        }

        val incomingSignals = listOf(
            "recibiste",
            "recibido",
            "has recibido",
            "acabas de recibir",
            "recibiste dinero",
            "recibiste plata",
            "recibiste una transferencia",
            "te yapearon",
            "te yapeo",
            "yape recibido",
            "te plinearon",
            "te plineo",
            "te han plineado",
            "te ha plineado",
            "te plinearon",
            "te hicieron un plin",
            "te hicieron plin",
            "te llego un plin",
            "plineo recibido",
            "plin recibido",
            "recibiste un plin",
            "te enviaron",
            "te envio",
            "te transfirieron",
            "te depositaron",
            "te abonaron",
            "transferencia recibida",
            "pago recibido",
            "abono recibido",
            "abono por plin",
            "abono plin",
            "dinero recibido",
            "te pagaron",
            "te pago",
            "abono en cuenta",
            "deposito recibido",
            "deposito en cuenta",
            "ingreso recibido",
            "ingreso en cuenta",
        )
        val incomingMatch = incomingSignals.firstOrNull(text::contains)
        if (incomingMatch != null) {
            return PaymentDecision(true, "señal de ingreso '$incomingMatch'")
        }

        // Frases ambiguas que normalmente pertenecen a una confirmacion de
        // salida. Se evalúan DESPUES de las señales de ingreso para no romper
        // avisos del tipo "recibiste ... operacion exitosa".
        val weakOutgoingSignals = listOf(
            "envio realizado",
            "envio exitoso",
            "tu plin se realizo",
            "plin realizado",
            "pago realizado",
            "transferencia realizada",
            "transferencia exitosa",
            "operacion realizada",
            "operacion exitosa",
        )
        val weakOutgoingMatch = weakOutgoingSignals.firstOrNull(text::contains)
        if (weakOutgoingMatch != null) {
            return PaymentDecision(false, "confirmacion de salida '$weakOutgoingMatch'")
        }

        // Importante: NO basta con que aparezca la palabra Plin y un monto.
        // Las confirmaciones de Plin enviados tambien contienen ambos elementos.
        return PaymentDecision(false, "sin señal explicita de dinero recibido")
    }

    private fun containsPlinSignal(raw: String): Boolean {
        val normalized = normalizeForMatching(raw)
        return PLIN_SIGNAL_REGEX.containsMatchIn(normalized)
    }

    private fun containsPlinWord(raw: String): Boolean = containsPlinSignal(raw)

    private fun normalizeForMatching(raw: String): String {
        val decomposed = Normalizer.normalize(raw, Normalizer.Form.NFD)
        return decomposed
            .replace(Regex("\\p{M}+"), "")
            .lowercase(Locale.ROOT)
            .replace(Regex("\\s+"), " ")
            .trim()
    }

    private fun extractAmount(raw: String): Double? {
        for (regex in AMOUNT_REGEXES) {
            val match = regex.find(raw) ?: continue
            val candidate = match.groupValues.getOrNull(1)?.trim() ?: continue
            val parsed = parseLocalizedAmount(candidate)
            if (parsed != null && parsed > 0.0) return parsed
        }

        // Algunas notificaciones de Plin muestran el importe como un numero
        // decimal separado del texto, sin anteponer S/. Si la notificacion dice
        // expresamente PLIN aceptamos ese formato como ultimo recurso.
        if (containsPlinWord(raw)) {
            for (match in BARE_DECIMAL_AMOUNT_REGEX.findAll(raw)) {
                val candidate = match.groupValues.getOrNull(1)?.trim() ?: continue
                val parsed = parseLocalizedAmount(candidate)
                if (parsed != null && parsed > 0.0) return parsed
            }
        }

        return null
    }

    private fun parseLocalizedAmount(raw: String): Double? {
        var value = raw
            .replace("\u00A0", "")
            .replace(" ", "")
            .trim()
        if (value.isBlank()) return null

        val lastDot = value.lastIndexOf('.')
        val lastComma = value.lastIndexOf(',')

        value = when {
            lastDot >= 0 && lastComma >= 0 -> {
                // El separador que aparece al final se interpreta como decimal.
                if (lastDot > lastComma) {
                    value.replace(",", "")
                } else {
                    value.replace(".", "").replace(',', '.')
                }
            }
            lastComma >= 0 -> {
                val decimals = value.length - lastComma - 1
                if (decimals in 1..2) value.replace(',', '.') else value.replace(",", "")
            }
            lastDot >= 0 -> {
                val decimals = value.length - lastDot - 1
                if (decimals in 1..2) value else value.replace(".", "")
            }
            else -> value
        }

        return value.toDoubleOrNull()
    }

    private fun showRegistrationPrompt(
        eventId: String,
        amount: Double,
        detectedAt: Long,
        sourceTitle: String,
        sourceText: String,
        source: PaymentSource,
    ) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        ensureChannel(manager)

        val notificationId =
            PROMPT_NOTIFICATION_BASE + (eventId.hashCode() and 0x7fffffff) % 100000

        val registerIntent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra(YapeActionReceiver.EXTRA_FROM_PAYMENT_ACTION, true)
            putExtra(YapeActionReceiver.EXTRA_NOTIFICATION_ID, notificationId)
            putExtra(YapeActionReceiver.EXTRA_EVENT_ID, eventId)
            putExtra(YapeActionReceiver.EXTRA_AMOUNT, amount.toString())
            putExtra(YapeActionReceiver.EXTRA_TIMESTAMP, detectedAt)
            putExtra(YapeActionReceiver.EXTRA_TITLE, sourceTitle)
            putExtra(YapeActionReceiver.EXTRA_TEXT, sourceText)
            putExtra(YapeActionReceiver.EXTRA_PAYMENT_METHOD, source.paymentMethod)
            putExtra(YapeActionReceiver.EXTRA_SOURCE_NAME, source.sourceName)
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
            .setContentTitle("Pago ${source.paymentMethod} detectado")
            .setContentText("Recibiste S/ $formattedAmount. ¿Deseas registrarlo como servicio?")
            .setStyle(
                Notification.BigTextStyle().bigText(
                    "MotoCaja detectó un posible pago recibido por ${source.paymentMethod} " +
                        "de S/ $formattedAmount desde ${source.sourceName}. " +
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

    private data class PaymentDecision(
        val incoming: Boolean,
        val reason: String,
    )

    private data class PaymentSource(
        val paymentMethod: String,
        val sourceName: String,
    )

    private data class NotificationPayload(
        val title: String,
        val text: String,
        val bestBody: String,
        val diagnosticText: String,
        val combined: String,
    )

    companion object {
        private const val TAG = "MotoCajaPayments"
        private const val YAPE_PACKAGE = "com.bcp.innovacxion.yapeapp"
        private const val BBVA_PACKAGE = "com.bbva.nxt_peru"
        private const val INTERBANK_PACKAGE = "pe.com.interbank.mobilebanking"
        private const val INTERBANK_BUSINESS_PACKAGE = "pe.com.interbank.mpay.customer"
        private const val SCOTIABANK_PACKAGE = "pe.com.scotiabank.blpm.android.client"
        private const val BANBIF_PACKAGE = "pe.com.banbif.pnappmobile"

        // Package actual de Caja Arequipa en Google Play (2026). Se conserva el
        // anterior porque algunos usuarios pueden seguir teniendo builds antiguas.
        private const val CAJA_AREQUIPA_PACKAGE = "com.cmac.cajamovilaqp"
        private const val CAJA_AREQUIPA_LEGACY_PACKAGE = "com.cajaarq.p51"

        private const val CAJA_ICA_PACKAGE = "com.cmacica.prd"
        private const val CAJA_HUANCAYO_PACKAGE = "com.cajahuancayo.cajahuancayo.appcajahuancayo"
        private const val FINANCIERA_CONFIANZA_PACKAGE = "pe.confianza.cliente"
        private const val ALFIN_PACKAGE = "com.alfinbanco.appclientes"
        private const val LIGO_PACKAGE = "pe.com.tarjetasperuanasprepago.tppapp"
        private const val MIBANCO_PACKAGE = "com.mibanco.bancamovil"
        private const val PICHINCHA_PACKAGE = "pe.pichincha.bm"
        private const val CHANNEL_ID = "motocaja_yape_detected"
        private const val PROMPT_NOTIFICATION_BASE = 2200
        private const val DUPLICATE_WINDOW_MS = 2 * 60 * 1000L
        private const val MAX_DIAGNOSTIC_HISTORY = 40

        const val KEY_DETECTION_ENABLED = "detection_enabled"
        const val KEY_DIAGNOSTIC_SOURCE_NAME = "diagnostic_source_name"
        const val KEY_DIAGNOSTIC_PACKAGE = "diagnostic_package"
        const val KEY_DIAGNOSTIC_TITLE = "diagnostic_title"
        const val KEY_DIAGNOSTIC_TEXT = "diagnostic_text"
        const val KEY_DIAGNOSTIC_BIG_TEXT = "diagnostic_big_text"
        const val KEY_DIAGNOSTIC_TIMESTAMP = "diagnostic_timestamp"
        const val KEY_DIAGNOSTIC_HISTORY = "diagnostic_history_json_v4"
        const val KEY_RAW_CAPTURE_UNTIL = "raw_capture_until_v4"
        private const val KEY_LAST_FINGERPRINT = "last_fingerprint"
        private const val KEY_LAST_FINGERPRINT_AT = "last_fingerprint_at"

        private val INCOMING_PAYMENT_REGEXES = listOf(
            Regex("""\bte\s+(?:ha|han)\s+plinead[oa]\b"""),
            Regex("""\bte\s+plinearon\b"""),
            Regex("""\bte\s+plineo\b"""),
            Regex("""\b(?:recibiste|has recibido|acabas de recibir)\b.*\bplin\b"""),
            Regex("""\bplin\b.*\b(?:recibido|recibiste|abono|deposito|ingreso)\b"""),
            Regex("""\b(?:abono|deposito|ingreso|transferencia)\b.*\b(?:recibido|recibida|cuenta)\b"""),
        )

        private val AMOUNT_REGEXES = listOf(
            Regex("""(?i)S\s*/\.?\s*([0-9]{1,9}(?:[.,][0-9]{1,3}){0,2})"""),
            Regex("""(?i)\bPEN\s*([0-9]{1,9}(?:[.,][0-9]{1,3}){0,2})"""),
            Regex("""(?i)\b([0-9]{1,9}(?:[.,][0-9]{1,3}){0,2})\s*(?:sol|soles|PEN)\b"""),
        )
        private val BARE_DECIMAL_AMOUNT_REGEX =
            Regex("""\b([0-9]{1,6}[.,][0-9]{1,2})\b""")
        private val PLIN_SIGNAL_REGEX =
            Regex("""\b(plin|plineo|plinear|plineado|plinearon|plineo)\b""")
    }
}
