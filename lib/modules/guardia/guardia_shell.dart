import 'package:flutter/material.dart';
import '../../api/client.dart';
import '../../theme/app_theme.dart';
import '../../screens/login_screen.dart';
import 'scanner_screen.dart';
import 'accesos_screen.dart';

class GuardiaShell extends StatefulWidget {
  const GuardiaShell({super.key});

  @override
  State<GuardiaShell> createState() => _GuardiaShellState();
}

class _GuardiaShellState extends State<GuardiaShell> {
  int _tab = 0;
  Map<String, dynamic>? _usuario;

  @override
  void initState() { super.initState(); _cargarUsuario(); }

  Future<void> _cargarUsuario() async {
    final u = await AuthStorage.getUser();
    if (mounted) setState(() => _usuario = u);
  }

  Future<void> _logout() async {
    await AuthStorage.limpiar();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final nombre = _usuario?['nombre'] ?? '';
    final pantallas = [const ScannerScreen(), const AccesosScreen()];

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const Icon(Icons.shield, color: AppColors.naranja, size: 22),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('SICA-VS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            if (nombre.isNotEmpty)
              Text('Guardia: $nombre',
                  style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.8))),
          ]),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.logout_outlined),
              tooltip: 'Cerrar sesión', onPressed: _logout),
        ],
      ),
      body: pantallas[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        backgroundColor: Colors.white,
        indicatorColor: AppColors.azul.withOpacity(0.12),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner_outlined),
            selectedIcon: Icon(Icons.qr_code_scanner, color: AppColors.azul),
            label: 'Escáner',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history, color: AppColors.azul),
            label: 'Accesos',
          ),
        ],
      ),
    );
  }
}
