import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'api/notificaciones.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Día 56 — datos de locale para fechas en español (nombres de mes/día).
  // Necesario para DateFormat con locale 'es' (ej. el reloj del encabezado);
  // sin esto, DateFormat("EEE d MMM", 'es') lanzaría una excepción.
  await initializeDateFormatting('es', null);

  // Inicializar Firebase (usa google-services.json)
  try {
    await Firebase.initializeApp();
    // Handler de notificaciones en segundo plano
    FirebaseMessaging.onBackgroundMessage(notificacionSegundoPlano);
    await NotificacionesService.inicializar();
  } catch (e) {
    // Si Firebase no está configurado aún, la app sigue funcionando sin push
    debugPrint('Firebase no inicializado: $e');
  }

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const SicaVsApp());
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
      title: 'SICA-VS',
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
    );
  }
}
