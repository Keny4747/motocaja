# Notificaciones de MotoCaja

## Comportamiento del piloto

- Recordatorio por inactividad: 90 minutos por defecto desde el ultimo movimiento.
- Opciones: 60, 90 o 120 minutos.
- Horario permitido para el recordatorio por inactividad: 07:00 a 20:30.
- El temporizador se reinicia cada vez que se registra un ingreso o gasto.
- Cierre diario: 21:00 por defecto, configurable desde Ajustes.
- El cierre diario solo se programa si hay movimientos en el dia.
- Si se eliminan todos los movimientos del dia, los recordatorios pendientes se cancelan.
- Los horarios se programan usando la zona horaria del dispositivo; si no se puede obtener, se usa America/Lima.

## Prueba recomendada

1. Ejecutar `flutter pub get`.
2. Ejecutar `flutter analyze`.
3. Ejecutar `flutter run`.
4. Abrir Configuracion > Recordatorios > Probar notificaciones.
5. Aceptar el permiso de Android.
6. Confirmar que aparece la notificacion de MotoCaja.
7. Para probar inactividad sin esperar 90 minutos, cambiar temporalmente `reminderIntervalMinutes` o el valor usado al programar a pocos minutos solo durante desarrollo.

## Android

Se usa `flutter_local_notifications` con alarmas inexactas (`inexactAllowWhileIdle`), por lo que MotoCaja no solicita permiso de alarmas exactas.

El manifest incluye:

- POST_NOTIFICATIONS
- VIBRATE
- RECEIVE_BOOT_COMPLETED
- ScheduledNotificationReceiver
- ScheduledNotificationBootReceiver

El modulo Android usa minSdk 24 y core library desugaring.
