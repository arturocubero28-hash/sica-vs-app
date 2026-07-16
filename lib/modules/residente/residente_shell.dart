import 'package:flutter/material.dart';
import '../../api/client.dart';
import '../../api/notificaciones.dart';
import '../../theme/app_theme.dart';
import '../../screens/login_screen.dart';
import 'qr_screen.dart';
import 'cuotas_screen.dart';
import 'home_screen.dart';
import 'mas_screen.dart';
import 'tarjeta_virtual_screen.dart';

class ResidenteShell extends StatefulWidget {
  const ResidenteShell({super.key});

  @override
  State<ResidenteShell> createState() => _ResidenteShellState();
}

class _ResidenteShellState extends State<ResidenteShell> {
  int _tab = 0;
  Map<String, dynamic>? _usuario;

  @override
  void initState() {
    super.initState();
    _cargarUsuario();
  }

  Future<void> _cargarUsuario() async {
    final u = await AuthStorage.getUser();
    if (mounted) setState(() => _usuario = u);
  }

  Future<void> _logout() async {
    await NotificacionesService.desregistrar();
    await AuthStorage.limpiar();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final nombre = _usuario?['nombre'] ?? '';
    final pantallas = [
      const HomeScreen(),
      const QrScreen(),
      const CuotasScreen(),
      const TarjetaVirtualScreen(),
      const MasScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const Icon(Icons.shield, color: AppColors.naranja, size: 22),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('SICA-VS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            if (nombre.isNotEmpty)
              Text('Hola, $nombre',
                  style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.8))),
          ]),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            tooltip: 'Cerrar sesión',
            onPressed: _logout,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Fondo con marca de agua sutil del logo
          Positioned.fill(
            child: IgnorePointer(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Opacity(
                    opacity: 0.04,
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 280,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(height: 80), // espacio sobre la barra de navegación
                ],
              ),
            ),
          ),
          // Contenido de la pantalla activa
          pantallas[_tab],
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        backgroundColor: Colors.white,
        indicatorColor: AppColors.naranja.withOpacity(0.15),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: AppColors.azul),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_outlined),
            selectedIcon: Icon(Icons.qr_code, color: AppColors.azul),
            label: 'Mis QR',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long, color: AppColors.azul),
            label: 'Cuotas',
          ),
          NavigationDestination(
            icon: Icon(Icons.contactless_outlined),
            selectedIcon: Icon(Icons.contactless, color: AppColors.naranja),
            label: 'Mi Tarjeta',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_outlined),
            selectedIcon: Icon(Icons.menu, color: AppColors.azul),
            label: 'Más',
          ),
        ],
      ),
    );
  }
}
