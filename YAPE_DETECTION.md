# MotoCaja - Deteccion de pagos Yape

## Que hace

- Escucha solo notificaciones del paquete oficial de Yape: `com.bcp.innovacxion.yapeapp`.
- Guarda localmente el ultimo texto recibido como diagnostico.
- Solo muestra una sugerencia si encuentra un monto y una frase compatible con un pago recibido.
- Nunca registra automaticamente: el usuario debe pulsar **Registrar**.
- El ingreso confirmado se guarda en SQLite como `Servicio / Yape`.
- MotoCaja conserva los ultimos identificadores procesados para evitar registros duplicados.

## Activacion

1. Abrir MotoCaja > Configuracion > Pagos inteligentes.
2. Activar **Detectar pagos recibidos por Yape**.
3. Conceder permiso para que MotoCaja muestre notificaciones, si Android lo solicita.
4. En la pantalla del sistema, activar **MotoCaja - Detector de pagos**.
5. Volver a MotoCaja y confirmar que `Acceso a notificaciones` dice `Concedido por Android`.

## Prueba recomendada

1. Con la deteccion activada, realizar un Yape pequeno de prueba hacia el telefono.
2. Si el parser reconoce el formato, debe aparecer:
   - Pago Yape detectado
   - Registrar
   - Ignorar
3. Pulsar **Registrar**.
4. MotoCaja debe abrirse y guardar el movimiento en SQLite.
5. Revisar Inicio / Movimientos / Resumen.

## Si no aparece la sugerencia

Abrir:

Configuracion > Pagos inteligentes > Ultima notificacion Yape detectada

Copiar el Titulo, Texto y Texto ampliado. Ese diagnostico permite ajustar el parser al formato actual de Yape sin guardar un historial completo de notificaciones.

## Recordatorios

- Tocar la notificacion **Cierre del dia** abre directamente la pestana Resumen.
- Tocar el recordatorio de inactividad abre **Registrar servicio**.
- La opcion temporal de 1 minuto fue retirada. Las opciones finales son 60, 90 y 120 minutos.
