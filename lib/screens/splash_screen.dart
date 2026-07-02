import 'package:flutter/material.dart';
import '../api/client.dart';
import '../theme/app_theme.dart';
import '../modules/shared/role_router.dart';
import 'login_screen.dart';

/// Pantalla de inicio: verifica si ya hay sesión guardada.
/// Si la hay, navega al módulo del rol correspondiente.
/// Si no, muestra el login.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _verificar();
  }

  Future<void> _verificar() async {
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    final token = await AuthStorage.getToken();
    final rol   = await AuthStorage.getRol();

    if (token != null && rol != null) {
      RoleRouter.navegar(context, rol);
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.azul,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Escudo
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                color: AppColors.naranja,
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(Icons.shield, color: Colors.white, size: 60),
            ),
            const SizedBox(height: 24),
            const Text('SICA-VS',
                style: TextStyle(
                  fontSize: 36, fontWeight: FontWeight.w900,
                  color: Colors.white, letterSpacing: 2,
                )),
            const SizedBox(height: 8),
            Text('Residencial Villas del Sol',
                style: TextStyle(
                  fontSize: 14, color: Colors.white.withOpacity(0.7),
                )),
            const SizedBox(height: 48),
            const SizedBox(
              width: 24, height: 24,
              child: CircularProgressIndicator(
                  color: AppColors.naranja, strokeWidth: 2.5),
            ),
          ],
        ),
      ),
    );
  }
}
