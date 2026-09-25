# MotoCaja

Aplicación Flutter Android para motociclistas independientes. Permite registrar servicios e ingresos, controlar gastos y conocer la ganancia real del día sin depender de conexión a internet.

## Funciones actuales

- Inicio con ganancia, ingresos, gastos y servicios del día.
- Registro rápido de servicios con tarifas frecuentes configurables.
- Registro de gastos por categoría.
- Métodos de pago: Efectivo, Yape, Plin y Transferencia.
- Movimientos por fecha mediante calendario.
- Detalle, edición y eliminación de movimientos.
- Resumen por día, últimos 7 días y mes.
- Promedio de ganancia por día trabajado.
- Reporte diario en PDF.
- Recordatorios de inactividad y cierre diario.
- Detección opcional de pagos recibidos por Yape y Plin mediante notificaciones Android.
- Persistencia de movimientos con SQLite.
- Preferencias pequeñas con SharedPreferences.
- Backup/restauración local versionada en JSON.
- Onboarding inicial para nombre, moto, tarifas y pago predeterminado.

## Persistencia

- `SQLite`: movimientos financieros.
- `SharedPreferences`: perfil, tarifas y preferencias.
- Todo funciona localmente en el teléfono. No existe backend en el MVP.

## Requisitos

- Flutter SDK compatible con Dart 3.12+.
- Android SDK configurado.
- Java 17.
- Android API 24+ en el dispositivo.

## Ejecutar

```bash
flutter doctor
flutter pub get
flutter analyze
flutter test
flutter run
```

## Prueba de una instalación nueva

El onboarding solo aparece en una instalación realmente nueva. En desarrollo también puede repetirse desde:

`Configuración -> Desarrollo -> Repetir onboarding`

La sección `Desarrollo` solo aparece en builds debug.

## Backup

Desde `Configuración -> Datos y respaldo`:

- **Crear respaldo** genera un archivo `.json` usando el selector nativo del sistema.
- **Restaurar respaldo** valida el formato antes de reemplazar la tabla local de movimientos.

El archivo contiene información financiera en texto JSON. Para el piloto debe tratarse como información privada.

## Nota

MotoCaja sigue siendo un MVP offline-first. Antes de publicar una versión pública conviene completar el checklist de `DEVELOPER_NOTES.md`.
