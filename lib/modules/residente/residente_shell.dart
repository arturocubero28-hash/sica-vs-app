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
  String? _unidad;

  @override
  void initState() {
    super.initState();
    _cargarUsuario();
    _cargarUnidad();
  }

  Future<void> _cargarUsuario() async {
    final u = await AuthStorage.getUser();
    if (mounted) setState(() => _usuario = u);
  }

  Future<void> _cargarUnidad() async {
    try {
      final res = await ApiClient.get('/visitas/mi-cuenta');
      final cuenta = (res as Map<String, dynamic>?)?['cuenta'] as Map<String, dynamic>?;
      final nombreCompleto = cuenta?['nombre_completo']?.toString();
      if (!mounted) return;
      setState(() {
        if (nombreCompleto != null && nombreCompleto.isNotEmpty && nombreCompleto != '—') {
          _unidad = nombreCompleto;
        }
      });
    } catch (_) {
      // Silencioso: el chip de unidad es informativo, no crítico
    }
  }

  Future<void> _logout() async {
    await NotificacionesService.desregistrar();
    await AuthStorage.cerrarSesion(); // AUTH-02: revoca el JWT en el servidor, no solo local
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  String _iniciales(String nombre) {
    final partes = nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (partes.isEmpty) return '?';
    if (partes.length == 1) return partes[0].substring(0, 1).toUpperCase();
    return (partes[0].substring(0, 1) + partes[1].substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final nombre = _usuario?['nombre']?.toString() ?? '';
    final apellido = _usuario?['apellido']?.toString() ?? '';
    final nombreCompleto = [nombre, apellido].where((s) => s.isNotEmpty).join(' ');

    final pantallas = [
      const HomeScreen(),
      const QrScreen(),
      const CuotasScreen(),
      const TarjetaVirtualScreen(),
      const MasScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.grisCl,
      extendBodyBehindAppBar: false,
      body: Column(children: [
        _Encabezado(
          nombreCompleto: nombreCompleto,
          iniciales: _iniciales(nombreCompleto),
          unidad: _unidad,
          onLogout: _logout,
        ),
        Expanded(
          child: Stack(children: [
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
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
            pantallas[_tab],
          ]),
        ),
      ]),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
          boxShadow: [
            BoxShadow(color: AppColors.azul.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, -4)),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
          child: NavigationBar(
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
        ),
      ),
    );
  }
}

/// Encabezado moderno: degradado, avatar con iniciales, nombre protagonista
/// y chip de contexto con la unidad. Reemplaza el AppBar plano estándar.
class _Encabezado extends StatelessWidget {
  final String nombreCompleto;
  final String iniciales;
  final String? unidad;
  final VoidCallback onLogout;

  const _Encabezado({
    required this.nombreCompleto,
    required this.iniciales,
    required this.unidad,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(18, topPadding + 14, 18, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.azul, AppColors.azul2],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppRadius.lg)),
      ),
      child: Column(children: [
        Row(children: [
          // Avatar con iniciales
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.5),
            ),
            alignment: Alignment.center,
            child: Text(iniciales, style: const TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Bienvenido de nuevo',
                  style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.68))),
              const SizedBox(height: 1),
              Text(
                nombreCompleto.isEmpty ? 'Residente' : nombreCompleto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          // Botón de logout como círculo táctil
          InkWell(
            onTap: onLogout,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.logout_outlined, color: Colors.white, size: 18),
            ),
          ),
        ]),
        if (unidad != null) ...[
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.home_rounded, color: AppColors.naranja, size: 15),
                const SizedBox(width: 7),
                Text(unidad!, style: const TextStyle(
                    fontSize: 12.5, color: Colors.white, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ],
      ]),
    );
  }
}
