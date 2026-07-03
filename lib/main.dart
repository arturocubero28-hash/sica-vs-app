import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'api/notificaciones.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

class SicaVsApp extends StatelessWidget {
  const SicaVsApp({super.key});

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
