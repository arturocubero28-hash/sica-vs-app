import 'package:flutter/material.dart';
import '../api/bloqueo_biometrico.dart';
import '../api/client.dart';
import '../api/notificaciones.dart';
import '../main.dart' show navigatorKey;
import '../theme/app_theme.dart';
import '../widgets/marca_residencial.dart';
import 'login_screen.dart';

/// Día 72 — pantalla que tapa la app cuando vuelve de segundo plano y el
/// desbloqueo con huella está activo. La sesión NO se toca: solo se pide
/// la huella (o el PIN/patrón del teléfono) para seguir donde estaba.
///
/// No se puede cerrar con "atrás": la única salida es desbloquear o
/// cerrar sesión.
class PantallaBloqueo extends StatefulWidget {
  const PantallaBloqueo({super.key});

  @override
  State<PantallaBloqueo> createState() => _PantallaBloqueoState();
}

class _PantallaBloqueoState extends State<PantallaBloqueo> {
  bool _pidiendo = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _desbloquear());
  }

  Future<void> _desbloquear() async {
    if (_pidiendo) return;
    setState(() => _pidiendo = true);
    final ok = await BloqueoBiometrico.autenticar(
        motivo: 'Desbloqueá Villas del Sol');
    if (!mounted) return;
    setState(() => _pidiendo = false);
    if (ok) Navigator.of(context).pop();
  }

  Future<void> _cerrarSesion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text(
            'Vas a tener que entrar de nuevo con tu correo y contraseña.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cerrar sesión')),
        ],
      ),
    );
    if (confirmar != true) return;
    await NotificacionesService.desregistrar();
    await AuthStorage.cerrarSesion();
    AppColors.restablecerFabrica();
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.azulDeFabrica,
        body: FondoMarca(
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const MarcaResidencial(tamLogo: 84),
                  const SizedBox(height: 36),
                  const Icon(Icons.lock_outline, color: Colors.white70, size: 30),
                  const SizedBox(height: 10),
                  const Text('App bloqueada',
                      style: TextStyle(color: Colors.white, fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text('Tu sesión sigue abierta. Usá tu huella para continuar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withOpacity(0.75),
                          fontSize: 14, height: 1.35)),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _pidiendo ? null : _desbloquear,
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Desbloquear'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.naranjaDeFabrica,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                        textStyle: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _cerrarSesion,
                    child: const Text('Cerrar sesión',
                        style: TextStyle(color: Colors.white60)),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
