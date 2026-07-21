import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../api/client.dart';
import '../../api/ble_service.dart';
import '../../api/screen_secure.dart';
import '../../theme/app_theme.dart';
import '../../widgets/tarjeta_qr.dart';

/// Pantalla "Mi tarjeta de acceso" con dos métodos:
///   - QR: el residente muestra el código al lector
///   - BLE: acceso por Bluetooth, atado a este dispositivo
class TarjetaVirtualScreen extends StatefulWidget {
  const TarjetaVirtualScreen({super.key});

  @override
  State<TarjetaVirtualScreen> createState() => _TarjetaVirtualScreenState();
}

class _TarjetaVirtualScreenState extends State<TarjetaVirtualScreen> {
  int _metodo = 0; // 0 = QR, 1 = BLE

  // Estado QR
  Map<String, dynamic>? _qr;
  bool _cargandoQr = true;

  // Estado BLE
  Map<String, dynamic>? _ble;
  bool _cargandoBle = true;
  bool _bleVinculadoAqui = false;

  bool _procesando = false;

  @override
  void initState() {
    super.initState();
    ScreenSecure.activar();
    _cargarTodo();
  }

  @override
  void dispose() {
    ScreenSecure.desactivar();
    super.dispose();
  }

  Future<void> _cargarTodo() async {
    await Future.wait([_cargarQr(), _cargarBle()]);
  }

  Future<void> _cargarQr() async {
    setState(() => _cargandoQr = true);
    try {
      final res = await ApiClient.get('/acceso/mi-tarjeta-virtual');
      if (mounted) setState(() => _qr = res as Map<String, dynamic>?);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _cargandoQr = false);
    }
  }

  Future<void> _cargarBle() async {
    setState(() => _cargandoBle = true);
    try {
      final res = await BleService.estado();
      final local = await BleService.tieneCredencialLocal();
      if (mounted) setState(() {
        _ble = res;
        _bleVinculadoAqui = local;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _cargandoBle = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Row(children: [
          const Expanded(
            child: Text('Mi tarjeta de acceso',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.azul)),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.azul),
            onPressed: _cargarTodo,
            tooltip: 'Actualizar',
          ),
        ]),
        const SizedBox(height: 4),
        _selectorMetodo(),
        const SizedBox(height: 16),
        _metodo == 0 ? _vistaQr() : _vistaBle(),
      ]),
    );
  }

  // ── Selector de método ──
  Widget _selectorMetodo() {
    return Row(children: [
      Expanded(child: _tabMetodo(0, Icons.qr_code_2, 'Código QR')),
      const SizedBox(width: 8),
      Expanded(child: _tabMetodo(1, Icons.bluetooth, 'Bluetooth',
          badge: bleAccesoFisicoListo ? null : 'Próximamente')),
    ]);
  }

  Widget _tabMetodo(int idx, IconData icono, String label, {String? badge}) {
    final activo = _metodo == idx;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() => _metodo = idx),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: activo ? AppColors.azul : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: activo ? AppColors.azul : AppColors.borde),
        ),
        child: Column(children: [
          Icon(icono, size: 22, color: activo ? Colors.white : AppColors.gris),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(
            fontSize: 12.5, fontWeight: FontWeight.w600,
            color: activo ? Colors.white : AppColors.gris)),
          if (badge != null) ...[
            const SizedBox(height: 2),
            Text(badge, style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.w700,
              color: activo ? Colors.white.withOpacity(0.85) : AppColors.amber)),
          ],
        ]),
      ),
    );
  }

  // ═══════════════ VISTA QR ═══════════════
  Widget _vistaQr() {
    if (_cargandoQr) return const Padding(
      padding: EdgeInsets.all(40), child: CircularProgressIndicator());

    final tiene = _qr?['tiene_tarjeta'] == true;
    final activa = _qr?['estado'] == 'activa';
    final codigo = _qr?['codigo_hoy']?.toString();

    if (!tiene) {
      return _tarjetaActivar(
        icono: Icons.qr_code_2,
        titulo: 'Activá tu código QR de acceso',
        descripcion: 'Mostralo al lector de la entrada para ingresar sin el guardia.',
        textoBoton: 'Activar código QR',
        onActivar: _activarQr,
      );
    }

    if (!activa) {
      return _tarjetaSuspendida(
        mensaje: 'Tu código QR está suspendido.',
        onReactivar: _reactivarQr,
      );
    }

    return Column(children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.naranja, width: 3),
        ),
        child: Column(children: [
          _encabezadoTarjeta(),
          const SizedBox(height: 16),
          if (codigo != null) QrImageViewWidget(data: codigo, size: 200),
          const SizedBox(height: 12),
          const Text('Acercá esta pantalla al lector de la entrada',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.gris)),
        ]),
      ),
      const SizedBox(height: 12),
      _botonWallet(),
      const SizedBox(height: 8),
      _botonSuspender(_suspenderQr),
    ]);
  }

  // ═══════════════ VISTA BLE ═══════════════
  Widget _vistaBle() {
    if (_cargandoBle) return const Padding(
      padding: EdgeInsets.all(40), child: CircularProgressIndicator());

    final tiene = _ble?['tiene_credencial'] == true;
    final activa = _ble?['estado'] == 'activa';

    // No hay credencial en ningún lado → activar en este teléfono
    if (!tiene) {
      return _tarjetaActivarBle(
        titulo: 'Activá el acceso Bluetooth',
        descripcion: bleAccesoFisicoListo
            ? 'Acercate a la entrada con el teléfono para ingresar, '
              'sin sacar la app ni mostrar nada.'
            : 'Registrá tu teléfono para el acceso por Bluetooth. Esta función '
              'está en preparación — por ahora no abre las trancas físicas, '
              'te avisaremos por notificación cuando esté lista.',
        onActivar: _activarBle,
      );
    }

    // Hay credencial activa PERO en otro teléfono
    if (activa && !_bleVinculadoAqui) {
      return _tarjetaActivarBle(
        titulo: 'Acceso Bluetooth en otro teléfono',
        descripcion: 'Tu acceso Bluetooth está vinculado a otro dispositivo. '
            'Por seguridad, solo puede estar activo en uno a la vez.',
        onActivar: _activarBleConReemplazo,
        textoBoton: 'Activar en este teléfono',
        esReemplazo: true,
      );
    }

    if (!activa) {
      return _tarjetaSuspendida(
        mensaje: 'Tu acceso Bluetooth está suspendido.',
        onReactivar: _reactivarBle,
      );
    }

    // Activa y vinculada a este teléfono → vista del radar (o de
    // "en preparación" mientras no exista hardware lector real — BLE-08).
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: bleAccesoFisicoListo ? AppColors.azul2 : AppColors.borde, width: 3),
        ),
        child: Column(children: [
          bleAccesoFisicoListo ? _radarBle() : _enPreparacionBle(),
          const SizedBox(height: 16),
          Text(
            bleAccesoFisicoListo ? 'Acceso Bluetooth activo' : 'Credencial Bluetooth vinculada',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.azul),
          ),
          const SizedBox(height: 4),
          Text(
            bleAccesoFisicoListo
                ? 'Acercate a la entrada con el teléfono'
                : 'Todavía no habilita el acceso físico — te avisaremos por '
                  'notificación cuando esté lista en tu residencial.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.gris),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.verde.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.smartphone, size: 15, color: AppColors.verde),
              const SizedBox(width: 6),
              Text('Vinculado a este teléfono',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                      color: AppColors.verde.withOpacity(0.9))),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      _botonSuspender(_suspenderBle),
    ]);
  }

  /// BLE-08: reemplaza el radar (que da a entender escaneo activo en tiempo
  /// real) por un ícono neutro mientras no exista hardware lector real.
  Widget _enPreparacionBle() {
    return Container(
      width: 120, height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.grisCl,
        border: Border.all(color: AppColors.borde, width: 2),
      ),
      child: const Center(
        child: Icon(Icons.hourglass_top_rounded, size: 44, color: AppColors.gris),
      ),
    );
  }

  Widget _radarBle() {
    return Container(
      width: 120, height: 120,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFE6F1FB)),
      child: Center(child: Container(
        width: 88, height: 88,
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFB5D4F4)),
        child: Center(child: Container(
          width: 56, height: 56,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.azul),
          child: const Icon(Icons.bluetooth, color: Colors.white, size: 28),
        )),
      )),
    );
  }

  // ── Widgets compartidos ──
  Widget _encabezadoTarjeta() {
    final nombre = _qr?['titular']?.toString() ?? '';
    return Row(children: [
      Container(
        width: 30, height: 30,
        decoration: const BoxDecoration(color: AppColors.azul, shape: BoxShape.circle),
        child: Padding(padding: const EdgeInsets.all(5),
          child: Image.asset('assets/images/logo.png', fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(Icons.shield, color: Colors.white, size: 18))),
      ),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('VILLAS DEL SOL', style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.azul)),
        if (nombre.isNotEmpty)
          Text(nombre, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: AppColors.gris)),
      ])),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: AppColors.verde.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
        child: const Text('ACTIVA', style: TextStyle(
            fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.verde)),
      ),
    ]);
  }

  Widget _tarjetaActivar({
    required IconData icono, required String titulo, required String descripcion,
    required String textoBoton, required VoidCallback onActivar,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borde),
      ),
      child: Column(children: [
        Icon(icono, size: 56, color: AppColors.gris.withOpacity(0.5)),
        const SizedBox(height: 16),
        Text(titulo, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.azul)),
        const SizedBox(height: 8),
        Text(descripcion, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.gris, height: 1.4)),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: _procesando ? null : onActivar,
          child: Text(_procesando ? 'Activando…' : textoBoton),
        )),
      ]),
    );
  }

  Widget _tarjetaActivarBle({
    required String titulo, required String descripcion, required VoidCallback onActivar,
    String textoBoton = 'Activar en este teléfono', bool esReemplazo = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: esReemplazo ? AppColors.amber : AppColors.borde),
      ),
      child: Column(children: [
        Icon(esReemplazo ? Icons.phonelink_lock : Icons.bluetooth,
            size: 56, color: esReemplazo ? AppColors.amber : AppColors.gris.withOpacity(0.5)),
        const SizedBox(height: 16),
        Text(titulo, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.azul)),
        const SizedBox(height: 8),
        Text(descripcion, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.gris, height: 1.4)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.verde.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.verified_user, size: 16, color: AppColors.verde),
            const SizedBox(width: 8),
            Flexible(child: Text('Por seguridad, solo funciona en el teléfono que activés',
                style: TextStyle(fontSize: 11, color: AppColors.verde.withOpacity(0.9)))),
          ]),
        ),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: _procesando ? null : onActivar,
          child: Text(_procesando ? 'Activando…' : textoBoton),
        )),
      ]),
    );
  }

  Widget _tarjetaSuspendida({required String mensaje, required VoidCallback onReactivar}) {
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.rojo.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.rojo.withOpacity(0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.block, color: AppColors.rojo, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Text('$mensaje Si estás en un lugar seguro, podés reactivarlo.',
              style: const TextStyle(color: AppColors.rojo, fontSize: 13))),
        ]),
      ),
      const SizedBox(height: 16),
      SizedBox(width: double.infinity, child: ElevatedButton.icon(
        onPressed: _procesando ? null : onReactivar,
        icon: const Icon(Icons.lock_open, size: 20),
        label: Text(_procesando ? 'Reactivando…' : 'Reactivar'),
      )),
    ]);
  }

  Widget _botonWallet() {
    return SizedBox(width: double.infinity, child: OutlinedButton.icon(
      onPressed: _procesando ? null : _agregarWallet,
      icon: const Icon(Icons.account_balance_wallet_outlined, size: 20),
      label: const Text('Agregar a Google Wallet'),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF1A73E8),
        side: const BorderSide(color: Color(0xFF1A73E8)),
        padding: const EdgeInsets.symmetric(vertical: 13),
      ),
    ));
  }

  Widget _botonSuspender(VoidCallback onSuspender) {
    return SizedBox(width: double.infinity, child: OutlinedButton.icon(
      onPressed: _procesando ? null : onSuspender,
      icon: const Icon(Icons.lock, size: 18),
      label: const Text('Suspender (perdí el teléfono)'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.rojo,
        side: BorderSide(color: AppColors.rojo.withOpacity(0.5)),
        padding: const EdgeInsets.symmetric(vertical: 13),
      ),
    ));
  }

  // ── Acciones QR ──
  Future<void> _activarQr() async {
    setState(() => _procesando = true);
    try {
      await ApiClient.post('/acceso/mi-tarjeta-virtual/activar', {});
      await _cargarQr();
      _ok('Código QR activado');
    } on ApiException catch (e) { _error(e.message); }
    finally { if (mounted) setState(() => _procesando = false); }
  }

  Future<void> _suspenderQr() async {
    if (!await _confirmarSuspender()) return;
    setState(() => _procesando = true);
    try {
      await ApiClient.post('/acceso/mi-tarjeta-virtual/suspender', {});
      await _cargarQr();
    } on ApiException catch (e) { _error(e.message); }
    finally { if (mounted) setState(() => _procesando = false); }
  }

  Future<void> _reactivarQr() async {
    setState(() => _procesando = true);
    try {
      await ApiClient.post('/acceso/mi-tarjeta-virtual/reactivar', {});
      await _cargarQr();
      _ok('Código QR reactivado');
    } on ApiException catch (e) { _error(e.message); }
    finally { if (mounted) setState(() => _procesando = false); }
  }

  Future<void> _agregarWallet() async {
    setState(() => _procesando = true);
    try {
      final res = await ApiClient.get('/acceso/mi-tarjeta-virtual/wallet-pass');
      final data = res as Map<String, dynamic>;
      if (data['wallet_url'] != null) {
        final url = Uri.parse(data['wallet_url'].toString());
        if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        _dialogo('Google Wallet',
          'La integración con Google Wallet estará disponible una vez que el sistema esté desplegado en producción.');
      }
    } catch (_) { _error('No se pudo conectar con Google Wallet'); }
    finally { if (mounted) setState(() => _procesando = false); }
  }

  // ── Acciones BLE ──
  Future<void> _activarBle() async {
    setState(() => _procesando = true);
    try {
      await BleService.activar();
      await _cargarBle();
      _ok('Acceso Bluetooth activado en este teléfono');
    } on ApiException catch (e) { _error(e.message); }
    finally { if (mounted) setState(() => _procesando = false); }
  }

  Future<void> _activarBleConReemplazo() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cambiar de dispositivo'),
        content: const Text(
          'Tu acceso Bluetooth está vinculado a otro teléfono. '
          'Si continuás, se desactivará en ese dispositivo y quedará activo solo en este.\n\n'
          '¿Querés continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Sí, activar aquí')),
        ],
      ),
    );
    if (confirmar != true) return;
    await _activarBle(); // el backend revoca la credencial previa automáticamente
  }

  Future<void> _suspenderBle() async {
    if (!await _confirmarSuspender()) return;
    setState(() => _procesando = true);
    try {
      await BleService.suspender();
      await _cargarBle();
    } on ApiException catch (e) { _error(e.message); }
    finally { if (mounted) setState(() => _procesando = false); }
  }

  Future<void> _reactivarBle() async {
    setState(() => _procesando = true);
    try {
      await BleService.reactivar();
      await _cargarBle();
      _ok('Acceso Bluetooth reactivado');
    } on ApiException catch (e) { _error(e.message); }
    finally { if (mounted) setState(() => _procesando = false); }
  }

  // ── Helpers UI ──
  Future<bool> _confirmarSuspender() async {
    final r = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Suspender el acceso?'),
        content: const Text(
          'Si perdiste el teléfono o alguien vio tu código, suspendelo ahora. '
          'Dejará de funcionar en los próximos 5 minutos. Podés reactivarlo cuando quieras.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Suspender', style: TextStyle(color: AppColors.rojo))),
        ],
      ),
    );
    return r == true;
  }

  void _ok(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.verde));
  }

  void _error(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.rojo));
  }

  void _dialogo(String titulo, String contenido) {
    if (!mounted) return;
    showDialog(context: context, builder: (_) => AlertDialog(
      title: Text(titulo), content: Text(contenido),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendido'))],
    ));
  }
}
