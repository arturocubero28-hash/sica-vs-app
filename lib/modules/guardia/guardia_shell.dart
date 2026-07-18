import 'package:flutter/material.dart';
import '../../api/client.dart';
import '../../api/notificaciones.dart';
import '../../theme/app_theme.dart';
import '../../screens/login_screen.dart';
import 'scanner_screen.dart';
import 'accesos_screen.dart';
import 'seleccionar_punto_screen.dart';

class GuardiaShell extends StatefulWidget {
  const GuardiaShell({super.key});

  @override
  State<GuardiaShell> createState() => _GuardiaShellState();
}

class _GuardiaShellState extends State<GuardiaShell> {
  int _tab = 0;
  Map<String, dynamic>? _usuario;
  String? _puntoAcceso;
  bool _verificandoPunto = true;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  Future<void> _inicializar() async {
    await _cargarUsuario();
    await _verificarPuntoAcceso();
  }

  Future<void> _cargarUsuario() async {
    final u = await AuthStorage.getUser();
    if (mounted) setState(() => _usuario = u);
  }

  /// ACCESS-04 (Auditoría Día 35): el guardia debe elegir su punto de
  /// acceso antes de poder usar la app. Si ya lo tiene guardado del
  /// servidor, se usa directo; si no, se muestra la pantalla bloqueante.
  Future<void> _verificarPuntoAcceso() async {
    final punto = _usuario?['punto_acceso_actual']?.toString();
    if (punto != null && punto.isNotEmpty) {
      if (mounted) setState(() { _puntoAcceso = punto; _verificandoPunto = false; });
      return;
    }
    if (!mounted) return;
    setState(() => _verificandoPunto = false);
    // Pantalla bloqueante — no se puede cerrar sin elegir (esCambioVoluntario: false)
    final elegido = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const SeleccionarPuntoScreen()),
    );
    if (mounted && elegido != null) setState(() => _puntoAcceso = elegido);
  }

  Future<void> _cambiarPunto() async {
    final elegido = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const SeleccionarPuntoScreen(esCambioVoluntario: true)),
    );
    if (mounted && elegido != null) {
      setState(() => _puntoAcceso = elegido);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Ahora estás en: $elegido'),
        backgroundColor: AppColors.verde,
      ));
    }
  }

  Future<void> _logout() async {
    await NotificacionesService.desregistrar();
    await AuthStorage.limpiar();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final nombre = _usuario?['nombre'] ?? '';
    final pantallas = [const ScannerScreen(), const AccesosScreen()];

    if (_verificandoPunto) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
          IconButton(
            icon: const Icon(Icons.location_on_outlined),
            tooltip: 'Cambiar punto de acceso',
            onPressed: _cambiarPunto,
          ),
          IconButton(icon: const Icon(Icons.logout_outlined),
              tooltip: 'Cerrar sesión', onPressed: _logout),
        ],
        bottom: _puntoAcceso != null
            ? PreferredSize(
                preferredSize: const Size.fromHeight(28),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  color: Colors.black12,
                  child: Text('📍 $_puntoAcceso', textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11.5, color: Colors.white)),
                ),
              )
            : null,
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
