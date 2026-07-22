# Firma de release — SICA-VS App

> **SIGN-16 (Auditoría Día 39).** Antes, el APK de release se firmaba con la
> clave de *debug*. Esta guía explica cómo crear la firma real y por qué
> importa hacerlo **antes** de repartir la app a los residentes.

---

## Por qué esto importa (y por qué no se puede arreglar después)

La clave de debug es pública: viene con el SDK de Android y es idéntica en
todas las máquinas del mundo. Firmar un release con ella tiene tres
consecuencias:

1. **Google Play rechaza el APK.** No se puede publicar.
2. **Las actualizaciones se rompen para siempre.** Android identifica una app
   por su `applicationId` **y su firma**. Si se reparte el APK firmado con
   debug a los 500 residentes y luego se cambia a la clave real, el sistema
   trata la nueva versión como una app distinta y **rechaza la
   actualización**. Cada residente tendría que desinstalar y reinstalar,
   perdiendo su sesión y sus datos locales.
3. **Cualquiera puede suplantar la app.** Con la clave pública, un tercero
   puede firmar un APK modificado que Android acepta como legítimo.

El punto 2 es el crítico: **no tiene vuelta atrás**. Por eso el build de
release ahora falla si no encuentra el keystore, en vez de firmar con debug
en silencio.

---

## Crear el keystore (una sola vez)

Guardalo **fuera del repositorio**. Por ejemplo, `C:\claves\`.

```powershell
keytool -genkey -v -keystore C:\claves\sicavs-release.jks `
  -keyalg RSA -keysize 2048 -validity 10000 -alias sicavs
```

`keytool` viene con el JDK. Si PowerShell no lo encuentra, está en
`C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe`.

Te va a pedir:

| Dato | Qué poner |
|---|---|
| Contraseña del keystore | Una fuerte. **Anotala.** |
| Nombre y apellido | Tu nombre o "SICA-VS" |
| Unidad organizativa | Villas del Sol |
| Organización | Villas del Sol |
| Ciudad / Estado / País | San Pedro Sula / Cortés / HN |
| Contraseña de la clave | Puede ser la misma del keystore |

`-validity 10000` son unos 27 años. Google Play exige que la clave siga
vigente más allá de 2033, así que no la pongas más corta.

---

## Configurar `key.properties`

Creá `android/key.properties` (este archivo **nunca** se versiona — ya está
en `.gitignore`):

```properties
storeFile=C:/claves/sicavs-release.jks
storePassword=TU_CONTRASEÑA_DEL_KEYSTORE
keyAlias=sicavs
keyPassword=TU_CONTRASEÑA_DE_LA_CLAVE
```

Usá barras normales (`/`) aunque estés en Windows — Gradle las prefiere.

---

## Compilar

```powershell
# APK (para repartir directamente a los residentes)
flutter build apk --release

# AAB (formato que exige Google Play)
flutter build appbundle --release
```

Si falta `key.properties`, el build se detiene con un mensaje explicando
qué hacer. Para desarrollo normal no hace falta nada:

```powershell
flutter run
flutter build apk --debug
```

---

## Respaldo — la parte que más importa

**Si perdés el keystore o sus contraseñas, no hay recuperación.** No existe
forma de volver a firmar la app con la misma identidad. La única salida sería
publicarla como una app nueva, con otro `applicationId`, y pedirle a los 500
residentes que desinstalen y reinstalen.

Respaldá en al menos dos lugares distintos:

- El archivo `sicavs-release.jks`
- El `storePassword`, el `keyAlias` y el `keyPassword`

Sugerencia: una copia en un gestor de contraseñas y otra en un disco externo
o almacenamiento cifrado. **No** en el repositorio, ni en el mismo disco que
la máquina de desarrollo.

Si en algún momento el proyecto se publica en Google Play, activá
**Play App Signing**: Google guarda la clave de firma final y vos conservás
solo una clave de carga, que sí se puede reemplazar si se pierde. Es la red
de seguridad para exactamente este problema.

---

## Verificar con qué clave quedó firmado un APK

```powershell
keytool -printcert -jarfile build\app\outputs\flutter-apk\app-release.apk
```

Si en el propietario aparece `CN=Android Debug`, está firmado con debug y
**no debe distribuirse**. Con la configuración actual eso ya no puede pasar,
pero sirve para verificar APKs viejos que hayan quedado dando vueltas.
