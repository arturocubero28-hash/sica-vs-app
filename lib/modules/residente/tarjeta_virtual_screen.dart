import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:screen_protector/screen_protector.dart';
import '../../api/client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/tarjeta_qr.dart';

/// Pantalla de la tarjeta de acceso virtual del residente.
///
/// El QR que muestra esta pantalla es diferente al de las visitas:
///   - Es permanente (no expira en horas, sino que rota a medianoche)
///   - Lo lee el lector ZKTeco de la entrada, no el guardia con la app
///   - Funciona igual que la tarjeta RFID física del residente
///   - Se puede agregar a Google Wallet para tenerlo siempre a mano
class TarjetaVirtualScreen extends StatefulWidget {
  const TarjetaVirtualScreen({super.key});

  @override
  State<TarjetaVirtualScreen> createState() => _TarjetaVirtualScreenState();
}

class _TarjetaVirtualScreenState extends State<TarjetaVirtualScreen> {
  Map<String, dynamic>? _tarjeta;
  bool _cargando = true;
  bool _procesando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Bloquear capturas de pantalla y grabación mientras se muestra el QR.
    ScreenProtector.preventScreenshot();
    _cargar();
  }

  @override
  void dispose() {
    // Restaurar cuando el residente sale de la pantalla
    ScreenProtector.removePreventScreenshot();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() { _cargando = true; _error = null; });
    try {
      final res = await ApiClient.get('/acceso/mi-tarjeta-virtual');
      if (mounted) setState(() => _tarjeta = res as Map<String, dynamic>?);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _activar() async {
    setState(() => _procesando = true);
    try {
      await ApiClient.post('/acceso/mi-tarjeta-virtual/activar', {});
      await _cargar();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✓ Tarjeta virtual activada'),
        backgroundColor: AppColors.verde,
      ));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.message), backgroundColor: AppColors.rojo));
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _suspender() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Suspender la tarjeta?'),
        content: const Text(
          'Si perdiste el teléfono o alguien vio tu QR, suspendela ahora. '
          'Dejará de funcionar en los próximos 5 minutos.\n\n'
          'Podés reactivarla cuando quieras.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Suspender', style: TextStyle(color: AppColors.rojo))),
        ],
      ),
    );
    if (confirmar != true) return;
    setState(() => _procesando = true);
    try {
      await ApiClient.post('/acceso/mi-tarjeta-virtual/suspender', {});
      await _cargar();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.message), backgroundColor: AppColors.rojo));
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _reactivar() async {
    setState(() => _procesando = true);
    try {
      await ApiClient.post('/acceso/mi-tarjeta-virtual/reactivar', {});
      await _cargar();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✓ Tarjeta reactivada con código nuevo'),
        backgroundColor: AppColors.verde,
      ));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.message), backgroundColor: AppColors.rojo));
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _agregarWallet() async {
    setState(() => _procesando = true);
    try {
      final res = await ApiClient.get('/acceso/mi-tarjeta-virtual/wallet-pass');
      final data = res as Map<String, dynamic>;

      if (data['wallet_url'] != null) {
        // Google Wallet configurado → abrir directamente
        final url = Uri.parse(data['wallet_url'].toString());
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        }
      } else {
        // Modo desarrollo — función disponible pero pendiente de configuración
        if (!mounted) return;
        showDialog(context: context, builder: (_) => AlertDialog(
          title: const Text('Google Wallet'),
          content: const Text(
            'La integración con Google Wallet estará disponible '
            'una vez que el sistema esté desplegado en producción.'),
          actions: [TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          )],
        ));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No se pudo conectar con Google Wallet'),
        backgroundColor: AppColors.rojo,
      ));
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi tarjeta de acceso'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _cargar),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.rojo)))
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final tieneTarjeta = _tarjeta?['tiene_tarjeta'] == true;
    final activa = _tarjeta?['estado'] == 'activa';
    final codigo = _tarjeta?['codigo_hoy']?.toString();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [

        // ── Explicación ──
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.azul.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Column(children: [
            Row(children: [
              Icon(Icons.contactless, color: AppColors.azul, size: 22),
              SizedBox(width: 10),
              Expanded(child: Text('Tu tarjeta de acceso digital',
                  style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.azul, fontSize: 15))),
            ]),
            SizedBox(height: 8),
            Text(
              'Funciona igual que tu tarjeta RFID física: acercás el teléfono al lector '
              'y la barrera se abre sola, sin pasar por el guardia.',
              style: TextStyle(fontSize: 13, color: AppColors.gris, height: 1.45),
            ),
          ]),
        ),
        const SizedBox(height: 24),

        if (!tieneTarjeta) ...[
          // ── Sin tarjeta: botón de activar ──
          const Icon(Icons.credit_card_off, size: 64, color: AppColors.gris),
          const SizedBox(height: 16),
          const Text('No tenés una tarjeta virtual activa',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.azul)),
          const SizedBox(height: 8),
          const Text('Activala una sola vez y podrás entrar con tu teléfono.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.gris)),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _procesando ? null : _activar,
              icon: const Icon(Icons.add_card, size: 20),
              label: Text(_procesando ? 'Activando…' : 'Activar tarjeta virtual'),
            ),
          ),
        ] else if (!activa) ...[
          // ── Suspendida ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.rojo.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.rojo.withOpacity(0.3)),
            ),
            child: const Row(children: [
              Icon(Icons.block, color: AppColors.rojo, size: 22),
              SizedBox(width: 10),
              Expanded(child: Text(
                'Tarjeta suspendida. No puede abrir ninguna barrera. '
                'Si ya estás en un lugar seguro, podés reactivarla.',
                style: TextStyle(color: AppColors.rojo, fontSize: 13),
              )),
            ]),
          ),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _procesando ? null : _reactivar,
              icon: const Icon(Icons.lock_open, size: 20),
              label: Text(_procesando ? 'Reactivando…' : 'Reactivar con código nuevo'),
            ),
          ),
        ] else ...[
          // ── Activa: mostrar QR ──
          _QrTarjetaVirtual(codigo: codigo ?? ''),
          const SizedBox(height: 8),
          const SizedBox(height: 24),

          // ── Botón Google Wallet ──
          SizedBox(width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _procesando ? null : _agregarWallet,
              icon: const Icon(Icons.account_balance_wallet_outlined, size: 20),
              label: const Text('Agregar a Google Wallet'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1A73E8),
                side: const BorderSide(color: Color(0xFF1A73E8)),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // ── Suspender ──
          SizedBox(width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _procesando ? null : _suspender,
              icon: const Icon(Icons.block, size: 18),
              label: const Text('Suspender (perdí el teléfono)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.rojo,
                side: BorderSide(color: AppColors.rojo.withOpacity(0.5)),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}

/// QR de la tarjeta virtual — más simple que el de visitas, sin la tarjeta
/// completa. Solo el QR grande con el código, centrado en pantalla.
class _QrTarjetaVirtual extends StatelessWidget {
  final String codigo;
  const _QrTarjetaVirtual({required this.codigo});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
          color: AppColors.azul.withOpacity(0.1),
          blurRadius: 20, offset: const Offset(0, 6),
        )],
        border: Border.all(color: AppColors.naranja, width: 3),
      ),
      child: Column(children: [
        // Header
        Row(children: [
          Container(
            width: 42, height: 42,
            decoration: const BoxDecoration(color: AppColors.azul, shape: BoxShape.circle),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Image.asset('assets/images/logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.shield, color: Colors.white, size: 24)),
            ),
          ),
          const SizedBox(width: 12),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('VILLAS DEL SOL', style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.azul)),
            Text('Tarjeta de acceso', style: TextStyle(
                fontSize: 11, color: AppColors.gris)),
          ]),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: AppColors.verde.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6)),
            child: const Text('ACTIVA', style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.verde)),
          ),
        ]),
        const SizedBox(height: 16),

        // QR
        QrImageViewWidget(data: codigo),

        const SizedBox(height: 12),
        const Text('Acercá esta pantalla al lector de la entrada',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.gris)),
      ]),
    );
  }
}
