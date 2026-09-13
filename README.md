# MotoCaja

Aplicación Flutter Android para registrar ingresos por servicios, gastos y visualizar movimientos y resúmenes.

## Funciones incluidas

- Inicio con ganancia del día, ingresos, gastos y servicios.
- Registro de servicio con tarifas S/ 5, S/ 7, S/ 8, S/ 10 y monto libre.
- Registro de gasto por categoría.
- Métodos de pago: Efectivo, Yape, Plin y Transferencia.
- Movimientos filtrados por hoy, semana y mes.
- Resumen de ingresos, gastos, servicios, promedio diario, medios de pago y categorías.
- Configuración básica de nombre, vehículo, pago predeterminado y recordatorios.
- Persistencia local usando SharedPreferences.

## Requisitos

- Flutter SDK instalado.
- Android Studio o Android SDK configurado.
- Un emulador Android o teléfono con depuración USB.

## Ejecutar

```bash
flutter doctor
flutter pub get
flutter run
```

## Si tu versión de Flutter detecta incompatibilidad con el scaffold Android

La carpeta `lib/` contiene toda la aplicación. Puedes regenerar solo el scaffold nativo manteniendo el código:

```bash
mv android android_backup
flutter create --platforms=android .
flutter pub get
flutter run
```

Luego, si quieres conservar el nombre de paquete, ajusta `applicationId` a `com.example.motocaja`.

## Nota

Esta primera versión está pensada como MVP local/offline. No requiere backend ni cuenta de usuario.
