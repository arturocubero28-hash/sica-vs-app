import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'dart:io';
import 'api/firebase_ios.dart';
import 'api/notificaciones.dart';
import 'api/bloqueo_app.dart';

/// Día 58 (A-2) — clave global de navegación. Permite navegar a una pantalla
/// (ej. el login) desde fuera del árbol de widgets, como client.dart, que no
/// tiene BuildContext propio. Es el patrón estándar de Flutter para esto.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Día 56 — datos de locale para fechas en español (nombres de mes/día).
  // Necesario para DateFormat con locale 'es' (ej. el reloj del encabezado);
  // sin esto, DateFormat("EEE d MMM", 'es') lanzaría una excepción.
  // Es local y rápido, así que puede ir antes de pintar.
  await initializeDateFormatting('es', null);

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ── LA UI SE PINTA PRIMERO. SIEMPRE. ────────────────────────────────
  //
  // Día 70 — "la app se queda pensando y nunca abre".
  //
  // Antes, main() hacía await de Firebase y de NotificacionesService
  // ANTES de llamar a runApp(). Y NotificacionesService.inicializar()
  // arranca pidiendo el permiso de notificaciones, que en Android 13+
  // abre un diálogo del sistema y espera a que la persona conteste.
  //
  // O sea: la app quedaba esperando una respuesta del usuario sin
  // haber dibujado todavía una sola pantalla. Si ese diálogo no
  // aparecía, tardaba, o quedaba sin contestar, runApp() nunca se
  // ejecutaba y el teléfono se quedaba mostrando la pantalla de
  // arranque de Android para siempre. No es que la app fuera lenta:
  // no había app, estaba trabada antes de existir.
  //
  // Firebase tiene el mismo riesgo por otro lado: initializeApp()
  // toca Play Services y puede quedarse esperando en un dispositivo
  // sin conexión o con Play Services en mal estado.
  //
  // Regla que queda para adelante: antes de runApp() solo va lo que es
  // local, rápido y no puede fallar esperando a nadie. Todo lo que
  // dependa de la red, de Play Services o de que el usuario conteste
  // algo, va después -- la persona ve la app mientras tanto.
  runApp(const SicaVsApp());

  // Día 72 — pide la huella al volver a la app después de un rato en
  // segundo plano (si la persona activó el desbloqueo con huella).
  GuardianBloqueo.instancia.iniciar();

  _inicializarServiciosEnSegundoPlano();
}

/// Arranca Firebase y las notificaciones SIN bloquear la primera pantalla.
///
/// Los timeouts no son decorativos: ninguna de estas llamadas garantiza
/// terminar. Si una se cuelga, lo único que se pierde son las
/// notificaciones push — la app queda perfectamente usable, que es lo que
/// importa en el portón.
Future<void> _inicializarServiciosEnSegundoPlano() async {
  try {
    // Día 71 — en iPhone los datos de Firebase vienen de firebase_ios.dart.
    // Si todavía no se llenaron, se sigue sin notificaciones push.
    if (Platform.isIOS) {
      if (kFirebaseIos == null) {
        debugPrint('Firebase iOS sin configurar: sin notificaciones push');
        return;
      }
      await Firebase.initializeApp(options: kFirebaseIos)
          .timeout(const Duration(seconds: 15));
    } else {
      await Firebase.initializeApp().timeout(const Duration(seconds: 15));
    }
  } catch (e) {
    debugPrint('Firebase no inicializado: $e');
    return; // sin Firebase no tiene sentido seguir con las notificaciones
  }

  try {
    // Handler de notificaciones en segundo plano. Se registra en cada
    // arranque en frío, así que hacerlo un instante después de pintar no
    // cambia nada.
    FirebaseMessaging.onBackgroundMessage(notificacionSegundoPlano);
    await NotificacionesService.inicializar()
        .timeout(const Duration(seconds: 30));
  } catch (e) {
    debugPrint('Notificaciones no inicializadas: $e');
  }
}

class SicaVsApp extends StatefulWidget {
  const SicaVsApp({super.key});

  @override
  State<SicaVsApp> createState() => _SicaVsAppState();
}

/// Día 47 — colores personalizables: StatefulWidget en vez de Stateless para
/// poder escuchar AppColors.notifier y reconstruir MaterialApp cuando el
/// admin (o la carga inicial de sesión) cambia los colores. Sin esto, aunque
/// AppColors.azul cambiara de valor, los widgets ya dibujados no se
/// enterarían — Flutter solo redibuja lo que setState() marca como sucio.
class _SicaVsAppState extends State<SicaVsApp> {
  @override
  void initState() {
    super.initState();
    AppColors.notifier.addListener(_onColoresCambiaron);
  }

  @override
  void dispose() {
    AppColors.notifier.removeListener(_onColoresCambiaron);
    super.dispose();
  }

  void _onColoresCambiaron() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Residencial Villas del Sol App',
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
    );
  }
}
