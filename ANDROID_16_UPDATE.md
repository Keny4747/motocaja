# MotoCaja - Android 16 / API 36

Configuracion actualizada para Android 16:

- compileSdk: 36
- targetSdk: 36
- Android Gradle Plugin: 8.13.2
- Gradle: 8.14
- Kotlin: 2.3.21
- Java/JDK: 17
- sqflite: 2.4.4
- shared_preferences: 2.5.5
- provider: 6.1.5+1
- flutter_lints: 6.0.0

## Requisitos locales

1. Flutter reciente con Dart 3.12 o superior.
2. JDK 17.
3. Android SDK Platform 36 instalado.
4. Android SDK Build-Tools 36.x instalado.

## Comandos

```bash
flutter clean
rm -rf android/.gradle
flutter pub get
flutter analyze
flutter run
```

Para confirmar el entorno:

```bash
flutter doctor -v
flutter --version
java -version
```

Nota: la configuracion release todavia usa la firma debug. Antes de publicar en Google Play se debe crear una keystore de produccion.
