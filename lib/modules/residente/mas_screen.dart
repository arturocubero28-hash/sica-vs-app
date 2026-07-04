import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../api/client.dart';
import '../../api/bloqueo_biometrico.dart';
import '../../theme/app_theme.dart';
import '../../screens/login_screen.dart';
import 'mi_edificio_screen.dart';

final _fmtL = NumberFormat.currency(locale: 'es_HN', symbol: 'L ');

/// Sección "Más" del residente: estado de cuenta, Mi Edificio (dueños),
/// y cerrar sesión.
class MasScreen extends StatefulWidget {
  const MasScreen({super.key});

  @override
  State<MasScreen> createState() => _MasScreenState();
}

class _MasScreenState extends State<MasScreen> {
  Map<String, dynamic>? _cuenta;
  bool _esDuenoEdificio = false;
  bool _cargando = true;
  bool _biometriaDisponible = false;
  bool _bloqueoActivo = false;

  @override
  void initState() { super.initState(); _cargar(); _cargarBiometria(); }

  Future<void> _cargarBiometria() async {
    final disp = await BloqueoBiometrico.disponible();
    final activo = await BloqueoBiometrico.estaActivo();
    if (mounted) setState(() {
      _biometriaDisponible = disp;
      _bloqueoActivo = activo;
    });
  }

  Future<void> _toggleBloqueo(bool valor) async {
    final ok = await BloqueoBiometrico.activar(valor);
    if (mounted) {
      setState(() => _bloqueoActivo = ok ? valor : _bloqueoActivo);
      if (!ok && valor) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No se pudo activar. Verificá tu huella.'),
            backgroundColor: AppColors.rojo));
      }
    }
  }

  Future<void> _cargar() async {
    try {
      final res = await ApiClient.get('/visitas/mi-cuenta');
      final data = res as Map<String, dynamic>;
      // ¿Tiene edificios a su nombre? (dueño)
      bool dueno = false;
      try {
        final edifs = await ApiClient.get('/unidades/mis-edificios');
        dueno = (edifs as List).isNotEmpty;
      } catch (_) {}
      if (mounted) setState(() { _cuenta = data; _esDuenoEdificio = dueno; });
    } catch (_) {
      // silencioso
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _logout() async {
    await AuthStorage.limpiar();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());

    final cuenta = _cuenta?['cuenta'] as Map<String, dynamic>?;
    final residente = _cuenta?['residente'] as Map<String, dynamic>?;
    final bloqueada = cuenta?['bloqueada'] == true;
    final unidad = cuenta?['unidad']?['identificador']?.toString()
        ?? cuenta?['unidad_identificador']?.toString() ?? '';
    final estado = cuenta?['estado']?.toString() ?? '';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Estado de cuenta ──
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.azul.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.home, color: AppColors.azul, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(unidad.isNotEmpty ? unidad : 'Mi cuenta',
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.azul)),
                  Text(residente?['rol_cuenta']?.toString() == 'titular'
                      ? 'Titular de la cuenta' : 'Miembro',
                      style: const TextStyle(fontSize: 12, color: AppColors.gris)),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (bloqueada ? AppColors.rojo : AppColors.verde).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    bloqueada ? 'Bloqueada' : (estado == 'al_dia' ? 'Al día' : estado),
                    style: TextStyle(
                      color: bloqueada ? AppColors.rojo : AppColors.verde,
                      fontSize: 12, fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 16),

        // ── Opciones ──
        if (_esDuenoEdificio)
          _OpcionTile(
            icono: Icons.apartment,
            color: AppColors.azul2,
            titulo: 'Mi Edificio',
            subtitulo: 'Códigos de enrolamiento para tus inquilinos',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const MiEdificioScreen())),
          ),

        // Toggle de bloqueo con huella (solo si el dispositivo lo soporta)
        if (_biometriaDisponible)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: SwitchListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              secondary: Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: AppColors.verde.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.fingerprint, color: AppColors.verde, size: 22),
              ),
              title: const Text('Bloquear con huella',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.azul)),
              subtitle: const Text('Pedir tu huella al abrir la app',
                  style: TextStyle(fontSize: 12, color: AppColors.gris)),
              value: _bloqueoActivo,
              activeColor: AppColors.naranja,
              onChanged: _toggleBloqueo,
            ),
          ),

        _OpcionTile(
          icono: Icons.language,
          color: AppColors.naranja,
          titulo: 'Panel web completo',
          subtitulo: 'Funciones adicionales desde el navegador',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Accedé desde el navegador de tu celular o PC')));
          },
        ),

        const SizedBox(height: 8),
        _OpcionTile(
          icono: Icons.logout,
          color: AppColors.rojo,
          titulo: 'Cerrar sesión',
          subtitulo: '',
          onTap: _logout,
        ),

        const SizedBox(height: 32),
        const Center(child: Text('SICA-VS v1.0.0',
            style: TextStyle(color: AppColors.gris, fontSize: 12))),
      ],
    );
  }
}

class _OpcionTile extends StatelessWidget {
  final IconData icono;
  final Color color;
  final String titulo;
  final String subtitulo;
  final VoidCallback onTap;
  const _OpcionTile({
    required this.icono, required this.color,
    required this.titulo, required this.subtitulo, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      leading: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icono, color: color, size: 22),
      ),
      title: Text(titulo, style: const TextStyle(
          fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.azul)),
      subtitle: subtitulo.isNotEmpty
          ? Text(subtitulo, style: const TextStyle(fontSize: 12, color: AppColors.gris))
          : null,
      trailing: const Icon(Icons.chevron_right, color: AppColors.gris),
      onTap: onTap,
    ),
  );
}
