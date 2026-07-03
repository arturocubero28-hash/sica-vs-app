# Configuración de Firebase para notificaciones push

Estos cambios se aplican UNA sola vez en tu máquina (los archivos de Gradle
no están en el repo porque Flutter los ignora por defecto).

## Paso 1 — Colocar el google-services.json

Copiá el archivo `google-services.json` que descargaste de Firebase a:

```
C:\sica_vs_app\android\app\google-services.json
```

(directamente dentro de la carpeta `app`)

## Paso 2 — android/settings.gradle

Abrí `C:\sica_vs_app\android\settings.gradle` y buscá el bloque `plugins { ... }`.
Agregá la última línea (el plugin de Google Services):

```gradle
plugins {
    id "dev.flutter.flutter-plugin-loader" version "1.0.0"
    id "com.android.application" version "8.1.0" apply false
    id "org.jetbrains.kotlin.android" version "1.8.22" apply false
    id "com.google.gms.google-services" version "4.4.1" apply false
}
```

(La versión de com.android.application puede variar; dejá la que ya tengas,
solo agregá la línea de google-services.)

## Paso 3 — android/app/build.gradle

Abrí `C:\sica_vs_app\android\app\build.gradle`.

### 3a. Al inicio, en el bloque `plugins { ... }`, agregá la última línea:

```gradle
plugins {
    id "com.android.application"
    id "kotlin-android"
    id "dev.flutter.flutter-gradle-plugin"
    id "com.google.gms.google-services"
}
```

### 3b. En el bloque `android { defaultConfig { ... } }`, asegurate de que
`minSdkVersion` sea al menos 21 (Firebase lo requiere):

```gradle
    defaultConfig {
        applicationId "com.villasdelsol.sica_vs_app"
        minSdkVersion 21
        targetSdkVersion flutter.targetSdkVersion
        versionCode flutterVersionCode.toInteger()
        versionName flutterVersionName
    }
```

## Paso 4 — Aplicar y correr

```
cd C:\sica_vs_app
flutter clean
flutter pub get
flutter run
```

La primera compilación tras agregar Firebase tarda más (baja dependencias
nativas). Es normal.

## Cómo verificar que funcionó

Al iniciar sesión, en la consola de `flutter run` deberías ver algo como:
```
I/flutter: FCM token: dXXXXXX...
```

Ese token es el que la app envía al backend para poder mandarte notificaciones.

## Paso 5 — Core library desugaring (requerido por flutter_local_notifications)

En `android/app/build.gradle`:

### 5a. Dentro de `android { compileOptions { ... } }` agregá la primera línea:

```gradle
    compileOptions {
        coreLibraryDesugaringEnabled true
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }
```

### 5b. Al final del archivo, en el bloque `dependencies { ... }`:

```gradle
dependencies {
    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.4'
}
```

Luego:
```
flutter run
```
