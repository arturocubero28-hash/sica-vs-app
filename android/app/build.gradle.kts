import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// =====================================================================
// SIGN-16 (Auditoria Dia 39): firma de release real, nunca la de debug.
//
// PROBLEMA ORIGINAL:
//   El bloque release traia el andamiaje que genera Flutter al crear el
//   proyecto:  signingConfig = signingConfigs.getByName("debug")
//   Cualquier APK de release salia firmado con la clave de debug, que es
//   PUBLICA y la misma en todas las maquinas del mundo.
//
//   No es una vulnerabilidad explotable contra el servidor, pero rompe
//   la distribucion de forma irreversible:
//     - Google Play rechaza APKs firmados con debug.
//     - Si se reparte el APK a los residentes firmado con debug y despues
//       se cambia a la clave real, Android RECHAZA la actualizacion (la
//       firma no coincide). Cada residente tendria que desinstalar y
//       reinstalar, perdiendo su sesion. No tiene vuelta atras.
//     - Cualquiera puede firmar un APK falso con la misma clave publica
//       y hacerlo pasar por la app oficial.
//
// COMO FUNCIONA AHORA:
//   Las credenciales se leen de android/key.properties, que NO se
//   versiona (ya esta en .gitignore). Si el archivo no existe:
//     - debug y profile  -> compilan normal, sin ningun cambio
//     - release          -> FALLA con un mensaje que explica que hacer
//   Fallar es intencional: mucho mejor que el build se detenga a que
//   genere en silencio un APK imposible de actualizar despues.
//
// Guia completa de creacion y respaldo del keystore: android/SIGNING.md
// =====================================================================
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hayKeystore = keystorePropertiesFile.exists()
if (hayKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.villasdelsol.sica_vs_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    defaultConfig {
        applicationId = "com.villasdelsol.sica_vs_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // Solo se declara si existe key.properties. Si no existe, no se
        // crea ninguna config de release y el build de release se detiene
        // mas abajo con un mensaje claro (en vez de firmar con debug).
        if (hayKeystore) {
            create("release") {
                storeFile = keystoreProperties["storeFile"]?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String?
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
            }
        }
    }

    buildTypes {
        release {
            if (hayKeystore) {
                signingConfig = signingConfigs.getByName("release")
            }
            // SIGN-16: si no hay keystore, NO se cae de vuelta a debug.
            // signingConfig queda nulo y el build de release se detiene
            // en la verificacion de abajo, que da un mensaje util.
            //
            // NOTA: no se activa minify/shrink (ProGuard) en este cambio.
            // Seria una mejora aparte, y hay que probarla con cuidado
            // porque puede eliminar clases que Firebase, WebAuthn o los
            // plugins de Flutter usan por reflexion.
        }
    }
}

// SIGN-16: corta el build de release si falta el keystore, con
// instrucciones concretas. Solo se dispara al ensamblar release —
// debug y profile no se ven afectados.
gradle.taskGraph.whenReady {
    val esRelease = allTasks.any { tarea ->
        tarea.name.contains("Release") &&
            (tarea.name.startsWith("assemble") || tarea.name.startsWith("bundle"))
    }
    if (esRelease && !hayKeystore) {
        throw GradleException(
            """
            |
            |  ============================================================
            |  SIGN-16: falta la configuracion de firma de release.
            |  ============================================================
            |
            |  No se encontro android/key.properties, asi que este APK/AAB
            |  no se puede firmar. El build se detiene a proposito: antes
            |  se firmaba con la clave de DEBUG, lo que genera un APK que
            |  Google Play rechaza y que NUNCA se puede actualizar despues
            |  con la clave real.
            |
            |  Para compilar release, ver la guia: android/SIGNING.md
            |
            |  Resumen:
            |    1. Crear el keystore (una sola vez, fuera del repo).
            |    2. Crear android/key.properties con sus credenciales.
            |    3. Respaldar el .jks y las contrasenas en lugar seguro.
            |
            |  Para desarrollo normal usa debug, que no necesita nada:
            |    flutter run
            |    flutter build apk --debug
            |
            """.trimMargin()
        )
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_1_8)
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
