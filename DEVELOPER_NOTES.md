# MotoCaja - Developer Notes

## Versionados importantes

- SQLite schema: `AppDatabase.schemaVersion`.
- Backup schema: `BackupData.currentVersion`.

Nunca cambies la forma de una tabla o del JSON de backup sin incrementar la versión correspondiente y agregar migración/compatibilidad.

## Restauración

`AppDatabase.replaceAllMovements()` reemplaza la tabla dentro de una transacción SQLite. El archivo se valida completamente antes de tocar la base.

La configuración se restaura después de la tabla y se persiste en SharedPreferences.

## Debug-only

En builds debug, Configuración muestra una sección `Desarrollo` con:

- último diagnóstico de notificación de pago;
- estado técnico de SQLite/backup/permisos;
- opción para repetir onboarding sin borrar movimientos.

No aparece en release gracias a `kDebugMode`.

## Datos demo

No usar nombres o motos reales como valores predeterminados. Los defaults son genéricos y una instalación nueva debe pasar por onboarding.

## Logs

Actualmente hay `debugPrint()` en inicialización, migraciones y recordatorios. Antes de agregar telemetría remota, definir explícitamente qué información puede salir del dispositivo. No registrar contenido completo de notificaciones de pago en producción.

## IDs de movimientos

Actualmente se generan con `microsecondsSinceEpoch`. Es suficiente para el piloto en un solo dispositivo. Si se implementa sincronización multi-dispositivo/backend, migrar a UUID/ULID antes de sincronizar.

## Backup y seguridad

El backup v1 es JSON legible. Para un piloto local es práctico, pero si se distribuye ampliamente conviene evaluar:

- backup cifrado con contraseña o clave del dispositivo;
- checksum/firma para detectar archivos alterados;
- estrategia de compatibilidad entre versiones.

## Checklist antes de APK release

- `flutter analyze`
- `flutter test`
- prueba de instalación limpia y onboarding
- crear y restaurar un backup real
- probar Yape y Plin con app abierta, en segundo plano y tras reinicio
- probar notificaciones con permisos concedidos/denegados
- validar PDF de Día, Semana y Mes
- verificar edición/eliminación y orden de movimientos
- probar cambio de fecha/mes alrededor de fin de mes y año bisiesto
- generar keystore de release y guardarlo fuera del repositorio
- cambiar `applicationId` de `com.example.motocaja` por un identificador definitivo antes de publicar
- revisar política de privacidad si se publica en Play Store

## Pendientes técnicos recomendados

1. Reemplazar versión hardcodeada en Configuración por `package_info_plus`.
2. Ampliar las pruebas de `ReportService` cuando se agreguen nuevos periodos o métricas. Ya existen casos para 30 días, diciembre, febrero bisiesto y promedio por días activos.
3. Añadir pruebas de migración SQLite cuando el schema suba de versión.
4. Evaluar cifrado del backup antes de una distribución masiva.
5. Si llega sincronización en nube, separar repositorios local/remoto y usar IDs globalmente únicos.
