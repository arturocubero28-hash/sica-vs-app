import 'package:flutter/material.dart';
import '../../api/client.dart';
import '../../api/notificaciones.dart';
import '../../theme/app_theme.dart';
import '../../screens/login_screen.dart';

class NoMobileScreen extends StatelessWidget {
  final String rol;
  const NoMobileScreen({super.key, required this.rol});

  String get _nombreRol {
    switch (rol) {
      case 'admin':       return 'Administrador';
      case 'super_admin': return 'Super Administrador';
      case 'cajero':      return 'Cajero';
      case 'desarrollador': return 'Desarrollador';
      default:            return rol;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grisCl,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.azul.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.desktop_windows_outlined,
                      size: 64, color: AppColors.azul),
                ),
                const SizedBox(height: 24),
                Text('Hola, $_nombreRol',
                    style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w700,
                      color: AppColors.azul,
                    )),
                const SizedBox(height: 12),
                const Text(
                  'Tu rol está diseñado para el panel web.\n'
                  'Accedé desde un navegador para usar\n'
                  'todas las funciones.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: AppColors.gris, height: 1.5),
                ),
                const SizedBox(height: 32),
                OutlinedButton.icon(
                  icon: const Icon(Icons.logout),
                  label: const Text('Cerrar sesión'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.rojo,
                    side: const BorderSide(color: AppColors.rojo),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    await NotificacionesService.desregistrar();
                    await AuthStorage.cerrarSesion(); // AUTH-02: revoca el JWT en el servidor
                    if (!context.mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (_) => false,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
