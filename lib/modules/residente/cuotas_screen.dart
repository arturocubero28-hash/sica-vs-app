import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../../api/client.dart';
import '../../theme/app_theme.dart';

final _fmt = NumberFormat.currency(locale: 'es_HN', symbol: 'L ');
final _fmtFecha = DateFormat('dd/MM/yyyy');

class CuotasScreen extends StatefulWidget {
  const CuotasScreen({super.key});

  @override
  State<CuotasScreen> createState() => _CuotasScreenState();
}

class _CuotasScreenState extends State<CuotasScreen> {
  Map<String, dynamic>? _datos;
  bool _cargando = true;
  String? _error;

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    setState(() { _cargando = true; _error = null; });
    try {
      final res = await ResidenteApi.misCuotas();
      setState(() => _datos = res);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _ErrorWidget(error: _error!, onRetry: _cargar);

    final todasCuotas = (_datos?['cuotas'] as List<dynamic>?) ?? [];
    // Solo mostrar cuotas pendientes o vencidas — las que están en arreglo
    // o ya pagadas no se muestran (el arreglo se muestra en su propia sección)
    final cuotas = todasCuotas
        .where((c) => ['pendiente', 'vencida', 'en_revision'].contains(c['estado']))
        .toList();
    final arreglo = _datos?['arreglo'] as Map<String, dynamic>?;
    final cuentaBloqueada = _datos?['bloqueada'] == true;

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner de cuenta bloqueada
          if (cuentaBloqueada)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.rojo.withOpacity(0.4)),
              ),
              child: const Row(children: [
                Icon(Icons.lock, color: AppColors.rojo, size: 20),
                SizedBox(width: 10),
                Expanded(child: Text(
                  'Tu cuenta está bloqueada por mora. Pagá tus cuotas para recuperar el acceso.',
                  style: TextStyle(color: AppColors.rojo, fontSize: 13),
                )),
              ]),
            ),

          // Arreglo de pago activo
          if (arreglo != null) ...[
            _SeccionHeader(titulo: 'Arreglo de pago', icono: Icons.handshake_outlined),
            const SizedBox(height: 8),
            ...(arreglo['abonos'] as List<dynamic>? ?? [])
                .where((a) => a['estado'] != 'pagado')
                .map((a) => _AbonoCard(abono: a, onPagado: _cargar)),
            const SizedBox(height: 16),
          ],

          // Cuotas pendientes
          if (cuotas.isNotEmpty) ...[
            _SeccionHeader(titulo: 'Cuotas pendientes', icono: Icons.receipt_long_outlined),
            const SizedBox(height: 8),
            ...cuotas.map((c) => _CuotaCard(cuota: c, onPagada: _cargar)),
          ],

          if (cuotas.isEmpty && arreglo == null)
            const _AlDia(),

          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _CuotaCard extends StatelessWidget {
  final dynamic cuota;
  final VoidCallback onPagada;
  const _CuotaCard({required this.cuota, required this.onPagada});

  @override
  Widget build(BuildContext context) {
    final estado = cuota['estado'] as String;
    final monto  = (cuota['monto'] as num).toDouble();
    final periodo = cuota['periodo'] as String;
    final vencimiento = DateTime.tryParse(cuota['fecha_vencimiento'] ?? '');
    final enRevision = estado == 'en_revision';

    Color badgeColor;
    String badgeLabel;
    switch (estado) {
      case 'vencida':     badgeColor = AppColors.rojo;  badgeLabel = 'Vencida'; break;
      case 'en_revision': badgeColor = AppColors.amber; badgeLabel = 'En revisión'; break;
      default:            badgeColor = AppColors.azul;  badgeLabel = 'Pendiente';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Cuota $periodo',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.azul)),
              if (vencimiento != null)
                Text('Vence: ${_fmtFecha.format(vencimiento)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.gris)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(_fmt.format(monto),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.azul)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(badgeLabel,
                    style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ]),
          ]),

          if (cuota['nota_admin'] != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline, size: 16, color: AppColors.amber),
                const SizedBox(width: 6),
                Expanded(child: Text(cuota['nota_admin'].toString(),
                    style: const TextStyle(fontSize: 12, color: AppColors.amber))),
              ]),
            ),
          ],

          if (!enRevision) ...[
            const SizedBox(height: 12),
            SizedBox(width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.upload_outlined, size: 18),
                label: const Text('Subir comprobante'),
                onPressed: () => _subirComprobante(context, cuota['uuid_publico'] ?? cuota['id'].toString()),
              ),
            ),
          ] else ...[
            const SizedBox(height: 10),
            const Row(children: [
              Icon(Icons.hourglass_empty, size: 16, color: AppColors.amber),
              SizedBox(width: 6),
              Text('Comprobante enviado — esperando aprobación',
                  style: TextStyle(fontSize: 12, color: AppColors.amber)),
            ]),
          ],
        ]),
      ),
    );
  }

  Future<void> _subirComprobante(BuildContext context, String cuotaId) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Subiendo comprobante…'), duration: Duration(seconds: 30)));

    try {
      await ResidenteApi.subirComprobante(cuotaId, File(picked.path));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✓ Comprobante enviado'), backgroundColor: AppColors.verde));
      onPagada();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.rojo));
    }
  }
}

class _AbonoCard extends StatelessWidget {
  final dynamic abono;
  final VoidCallback onPagado;
  const _AbonoCard({required this.abono, required this.onPagado});

  @override
  Widget build(BuildContext context) {
    final numero  = abono['numero'] as int;
    final monto   = (abono['monto'] as num).toDouble();
    final fecha   = DateTime.tryParse(abono['fecha_pactada'] ?? '');
    final estado  = abono['estado'] as String;
    final enRevision = estado == 'en_revision';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: AppColors.azul.withOpacity(0.1), shape: BoxShape.circle),
              child: Center(child: Text('$numero',
                  style: const TextStyle(color: AppColors.azul, fontWeight: FontWeight.w800))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Abono #$numero', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.azul)),
              if (fecha != null)
                Text('Vence: ${_fmtFecha.format(fecha)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.gris)),
            ])),
            Text(_fmt.format(monto),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.azul)),
          ]),
          if (!enRevision) ...[
            const SizedBox(height: 12),
            SizedBox(width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.upload_outlined, size: 18),
                label: const Text('Subir comprobante'),
                onPressed: () => _subirComprobante(context, abono['abono_id'] ?? abono['uuid_publico'] ?? abono['id'].toString()),
              ),
            ),
          ] else
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Row(children: [
                Icon(Icons.hourglass_empty, size: 16, color: AppColors.amber),
                SizedBox(width: 6),
                Text('En revisión', style: TextStyle(fontSize: 12, color: AppColors.amber)),
              ]),
            ),
        ]),
      ),
    );
  }

  Future<void> _subirComprobante(BuildContext context, String abonoId) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Subiendo comprobante…'), duration: Duration(seconds: 30)));
    try {
      await ResidenteApi.subirComprobanteAbono(abonoId, File(picked.path));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✓ Comprobante enviado'), backgroundColor: AppColors.verde));
      onPagado();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.rojo));
    }
  }
}

class _SeccionHeader extends StatelessWidget {
  final String titulo;
  final IconData icono;
  const _SeccionHeader({required this.titulo, required this.icono});

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icono, size: 18, color: AppColors.azul),
    const SizedBox(width: 8),
    Text(titulo, style: const TextStyle(
        fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.azul)),
  ]);
}

class _AlDia extends StatelessWidget {
  const _AlDia();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const SizedBox(height: 60),
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.verde.withOpacity(0.1), shape: BoxShape.circle),
        child: const Icon(Icons.check_circle_outline, size: 64, color: AppColors.verde),
      ),
      const SizedBox(height: 16),
      const Text('¡Estás al día!',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.verde)),
      const SizedBox(height: 8),
      const Text('No tenés cuotas pendientes',
          style: TextStyle(color: AppColors.gris)),
    ]),
  );
}

class _ErrorWidget extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorWidget({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Icon(Icons.wifi_off, size: 56, color: AppColors.gris),
      const SizedBox(height: 12),
      Text(error, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.gris)),
      const SizedBox(height: 16),
      ElevatedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh),
          label: const Text('Reintentar')),
    ],
  ));
}
