# Configurar el bloqueo con huella (local_auth)

El paquete local_auth necesita UN cambio en el código nativo de Android que
vive solo en tu máquina (no está en el repo).

## Cambiar MainActivity a FlutterFragmentActivity

Abrí el archivo:
```
C:\sica_vs_app\android\app\src\main\kotlin\com\villasdelsol\sica_vs_app\MainActivity.kt
```

Cambiá la clase para que extienda `FlutterFragmentActivity` en vez de
`FlutterActivity`. Debe quedar así:

```kotlin
package com.villasdelsol.sica_vs_app

import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity()
```

(Si actualmente dice `import io.flutter.embedding.android.FlutterActivity` y
`class MainActivity : FlutterActivity()`, cambiá ambas líneas.)

Sin este cambio, la app crashea al pedir la huella con un error de
"FragmentActivity". Con el cambio, funciona.

## Luego

```
cd C:\sica_vs_app
git pull origin main
flutter pub get
flutter run
```

## Probar en el emulador

El emulador puede simular huella:
1. En el emulador, abrí Ajustes de Android → Seguridad → Huella digital
2. Configurá una huella (te pide "tocar el sensor")
3. Cuando el emulador pida la huella, usá el menú de controles extendidos
   (los tres puntos) → Fingerprint → Touch sensor

## Cómo se usa

1. El residente entra normal con correo y contraseña
2. Va a la sección "Más" → activa "Bloquear con huella"
3. Confirma con su huella una vez
4. La próxima vez que abra la app, le pide la huella para entrar
5. La sesión sigue viva: las notificaciones push siguen llegando aunque
   la app esté cerrada. La huella solo protege el acceso a la información.
