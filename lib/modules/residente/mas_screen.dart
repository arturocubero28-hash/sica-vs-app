import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../api/client.dart';
import '../../api/bloqueo_biometrico.dart';
import '../../api/notificaciones.dart';
import '../../theme/app_theme.dart';
import '../../widgets/error_dialog.dart';
import '../../screens/login_screen.dart';
import 'mi_edificio_screen.dart';
import 'codigo_emergencia_screen.dart';
import '../shared/cambiar_password_screen.dart';

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
        ErrorDialog.mostrar(context, 'No se pudo activar. Verificá tu huella.');
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
    await NotificacionesService.desregistrar(); // borra token FCM del servidor
    await AuthStorage.cerrarSesion(); // AUTH-02: revoca el JWT en el servidor, no solo local
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
                // Día 69 — si administración ya le tomó la foto, el residente
                // la ve acá. Es SOLO LECTURA a propósito: es la foto que el
                // guardia usa para verificar su identidad en el portón, así
                // que si el residente pudiera cambiarla podría poner la cara
                // de otra persona y la verificación dejaría de servir.
                _FotoOCasa(fotoUrl: residente?['foto_url']?.toString()),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(unidad.isNotEmpty ? unidad : 'Mi cuenta',
                      style: TextStyle(
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

        // Día 72 — desbloqueo con huella (local). No tiene nada que ver con
        // iniciar sesión: la sesión queda abierta hasta que se cierre.
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
              title: Text('Desbloquear con huella',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.azul)),
              subtitle: const Text('Pedir tu huella cada vez que abrís la app. Tu sesión sigue abierta.',
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
        // Día 69 — va ANTES de "Cambiar contraseña" a propósito: es la
        // función nueva y la que el residente necesita configurar una vez,
        // justamente antes de que le haga falta.
        _OpcionTile(
          icono: Icons.vpn_key_outlined,
          color: AppColors.naranja,
          titulo: 'Código de emergencia',
          subtitulo: 'Para entrar si se te apaga el teléfono',
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const CodigoEmergenciaScreen())),
        ),

        const SizedBox(height: 8),
        _OpcionTile(
          icono: Icons.lock_reset,
          color: AppColors.azul2,
          titulo: 'Cambiar contraseña',
          subtitulo: 'Actualizá tu contraseña de acceso',
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const CambiarPasswordScreen())),
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
        const Center(child: Text('Residencial Villas del Sol App · v1.0.0',
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
      title: Text(titulo, style: TextStyle(
          fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.azul)),
      subtitle: subtitulo.isNotEmpty
          ? Text(subtitulo, style: const TextStyle(fontSize: 12, color: AppColors.gris))
          : null,
      trailing: const Icon(Icons.chevron_right, color: AppColors.gris),
      onTap: onTap,
    ),
  );
}

/// Día 69 — foto del residente en su perfil, con la casa como respaldo.
///
/// Solo lectura: no hay forma de cambiarla desde la app. La captura
/// administración, porque es la que el guardia compara contra la
/// identificación cuando alguien pide entrar sin teléfono.
class _FotoOCasa extends StatelessWidget {
  final String? fotoUrl;
  const _FotoOCasa({required this.fotoUrl});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: 48, height: 48,
      decoration: BoxDecoration(
        color: AppColors.azul.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(Icons.home, color: AppColors.azul, size: 26),
    );

    if (fotoUrl == null || fotoUrl!.isEmpty) return placeholder;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 48, height: 48,
        child: FutureBuilder<String>(
          future: urlFotoResidente(fotoUrl!),
          builder: (_, snap) {
            if (!snap.hasData) return placeholder;
            return Image.network(
              snap.data!,
              fit: BoxFit.cover,
              // Si la foto no carga (sin señal, enlace vencido), se muestra
              // la casa en vez de un ícono roto.
              errorBuilder: (_, __, ___) => placeholder,
            );
          },
        ),
      ),
    );
  }
}
