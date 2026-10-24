import 'package:firebase_core/firebase_core.dart';

/// Configuración de Firebase para iPhone (Día 71).
///
/// En Android, Firebase lee google-services.json. En iPhone se le pasan los
/// datos acá, en vez de agregar GoogleService-Info.plist al proyecto de
/// Xcode (que no se puede hacer bien sin una Mac).
///
/// CÓMO LLENARLO: en la consola de Firebase, proyecto de la app → agregar
/// app → iOS → bundle ID `com.villasdelsol.sicaVsApp`. Descargar el
/// GoogleService-Info.plist y copiar acá estos cuatro valores:
///   API_KEY            → apiKey
///   GOOGLE_APP_ID      → appId
///   GCM_SENDER_ID      → messagingSenderId
///   PROJECT_ID         → projectId
///
/// Mientras quede en null, la app en iPhone funciona completa pero sin
/// notificaciones push. Nunca se cae por esto.
const FirebaseOptions? kFirebaseIos = null;
// Ejemplo de cómo queda:
// const FirebaseOptions? kFirebaseIos = FirebaseOptions(
//   apiKey: 'AIza...',
//   appId: '1:1234567890:ios:abc123',
//   messagingSenderId: '1234567890',
//   projectId: 'mi-proyecto',
//   iosBundleId: 'com.villasdelsol.sicaVsApp',
// );
