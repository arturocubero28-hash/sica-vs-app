import 'package:flutter/material.dart';
import '../api/client.dart';
import '../api/bloqueo_biometrico.dart';
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
  bool _bloqueado = false;

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
      // Si el bloqueo biométrico está activo, pedir huella antes de entrar.
      // La sesión sigue viva; esto solo protege el acceso a la información.
      final bloqueoActivo = await BloqueoBiometrico.estaActivo();
      if (bloqueoActivo) {
        final ok = await BloqueoBiometrico.autenticar(
          motivo: 'Desbloqueá SICA-VS con tu huella',
        );
        if (!ok) {
          // No autenticó: mostrar pantalla de reintento, sin cerrar sesión
          if (mounted) setState(() => _bloqueado = true);
          return;
        }
      }
      if (!mounted) return;
      RoleRouter.navegar(context, rol);
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  Future<void> _reintentar() async {
    final ok = await BloqueoBiometrico.autenticar(
      motivo: 'Desbloqueá SICA-VS con tu huella',
    );
    if (ok && mounted) {
      final rol = await AuthStorage.getRol();
      if (rol != null && mounted) RoleRouter.navegar(context, rol);
    }
  }

  Future<void> _cerrarSesion() async {
    await AuthStorage.limpiar();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()));
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
            if (_bloqueado) ...[
              const Icon(Icons.lock_outline, color: Colors.white70, size: 32),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text('App bloqueada. Usá tu huella para entrar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _reintentar,
                icon: const Icon(Icons.fingerprint),
                label: const Text('Desbloquear'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _cerrarSesion,
                child: const Text('Cerrar sesión',
                    style: TextStyle(color: Colors.white54)),
              ),
            ] else
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
