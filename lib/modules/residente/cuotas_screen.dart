import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../../api/client.dart';
import '../../api/permisos.dart';
import '../../api/camara_helper.dart';
import '../../api/recuperacion_comprobante.dart';
import '../../theme/app_theme.dart';

final _fmt = NumberFormat.currency(locale: 'es_HN', symbol: 'L ');
final _fmtFecha = DateFormat('dd/MM/yyyy');

/// IDs de cuotas/abonos cuyo comprobante se está subiendo ahora mismo.
/// Evita que un doble toque suba el mismo comprobante dos veces.
final Set<String> _subidasEnCurso = {};

/// Muestra un selector de cámara o galería y devuelve la fuente elegida.
Future<ImageSource?> _elegirFuente(BuildContext context) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 12),
        Container(width: 40, height: 4, decoration: BoxDecoration(
            color: AppColors.borde, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Subir comprobante',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.azul)),
        ),
        ListTile(
          leading: Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
                color: AppColors.naranja.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.camera_alt, color: AppColors.naranja),
          ),
          title: const Text('Tomar foto'),
          subtitle: const Text('Usá la cámara del teléfono'),
          onTap: () => Navigator.pop(context, ImageSource.camera),
        ),
        ListTile(
          leading: Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
                color: AppColors.azul.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.photo_library, color: AppColors.azul),
          ),
          title: const Text('Elegir de la galería'),
          subtitle: const Text('Seleccioná una imagen guardada'),
          onTap: () => Navigator.pop(context, ImageSource.gallery),
        ),
        const SizedBox(height: 12),
      ]),
    ),
  );
}

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
      if (mounted) setState(() => _datos = res);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _ErrorWidget(error: _error!, onRetry: _cargar);

    return DefaultTabController(
      length: 2,
      child: Column(children: [
        Container(
          color: Colors.white,
          child: const TabBar(
            labelColor: AppColors.azul,
            unselectedLabelColor: AppColors.gris,
            indicatorColor: AppColors.naranja,
            indicatorWeight: 3,
            tabs: [
              Tab(text: 'Pendientes'),
              Tab(text: 'Historial de pagos'),
            ],
          ),
        ),
        Expanded(child: TabBarView(children: [
          _buildPendientes(),
          _HistorialPagos(historial: (_datos?['historial'] as List<dynamic>?) ?? []),
        ])),
      ]),
    );
  }

  Widget _buildPendientes() {

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
                onPressed: () => _subirComprobante(context, cuota['uuid_publico'] ?? cuota['id'].toString(), monto),
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

  Future<void> _subirComprobante(BuildContext context, String cuotaId, double monto) async {
    // Candado: si ya se está subiendo para esta cuota, ignorar el doble toque
    if (_subidasEnCurso.contains(cuotaId)) return;

    final fuente = await _elegirFuente(context);
    if (fuente == null || !context.mounted) return;

    // Pedir permiso según la fuente elegida
    if (fuente == ImageSource.camera) {
      final ok = await PermisosService.pedirCamara();
      if (!ok) {
        if (context.mounted) _avisoPermiso(context, 'cámara');
        return;
      }
    } else {
      final ok = await PermisosService.pedirGaleria();
      if (!ok) {
        if (context.mounted) _avisoPermiso(context, 'galería');
        return;
      }
    }

    // Persistir antes de abrir la cámara — si Android mata el proceso, el SplashScreen
    // recupera la foto y completa la subida automáticamente
    await RecuperacionComprobante.guardar(id: cuotaId, monto: monto, tipo: 'cuota');
    final archivo = await CamaraHelper.capturar(fuente: fuente, quality: 50, maxSize: 1024);
    if (archivo == null || !context.mounted) {
      await RecuperacionComprobante.limpiar();
      return;
    }

    _subidasEnCurso.add(cuotaId);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Subiendo comprobante…'), duration: Duration(seconds: 30)));

    try {
      await ResidenteApi.subirComprobante(cuotaId, archivo, monto);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✓ Comprobante enviado'), backgroundColor: AppColors.verde));
      await RecuperacionComprobante.limpiar();
      onPagada();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      // El backend devuelve mensajes claros sobre formato/tamaño: los mostramos completos
      _mostrarErrorArchivo(context, e.toString());
    } finally {
      _subidasEnCurso.remove(cuotaId);
      await RecuperacionComprobante.limpiar();
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
                onPressed: () => _subirComprobante(context, abono['abono_id'] ?? abono['uuid_publico'] ?? abono['id'].toString(), monto),
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

  Future<void> _subirComprobante(BuildContext context, String abonoId, double monto) async {
    if (_subidasEnCurso.contains(abonoId)) return;

    final fuente = await _elegirFuente(context);
    if (fuente == null || !context.mounted) return;

    if (fuente == ImageSource.camera) {
      final ok = await PermisosService.pedirCamara();
      if (!ok) { if (context.mounted) _avisoPermiso(context, 'cámara'); return; }
    } else {
      final ok = await PermisosService.pedirGaleria();
      if (!ok) { if (context.mounted) _avisoPermiso(context, 'galería'); return; }
    }

    // CamaraHelper maneja retrieveLostData() en caso de que Android mate el proceso
    final archivo = await CamaraHelper.capturar(fuente: fuente, quality: 50, maxSize: 1024);
    if (archivo == null || !context.mounted) return;

    _subidasEnCurso.add(abonoId);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Subiendo comprobante…'), duration: Duration(seconds: 30)));
    try {
      await ResidenteApi.subirComprobanteAbono(abonoId, archivo, monto);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✓ Comprobante enviado'), backgroundColor: AppColors.verde));
      onPagado();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _mostrarErrorArchivo(context, e.toString());
    } finally {
      _subidasEnCurso.remove(abonoId);
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

// ─── Historial de pagos (pestaña) ─────────────────────────────────────────────
final _fmtFechaHora = DateFormat('dd/MM/yyyy HH:mm');

class _HistorialPagos extends StatelessWidget {
  final List<dynamic> historial;
  const _HistorialPagos({required this.historial});

  @override
  Widget build(BuildContext context) {
    if (historial.isEmpty) {
      return const Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.history, size: 64, color: AppColors.gris),
          SizedBox(height: 16),
          Text('Sin pagos registrados aún', style: TextStyle(color: AppColors.gris)),
        ]),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: historial.length,
      itemBuilder: (_, i) {
        final pago = historial[i];
        final etiqueta = pago['etiqueta']?.toString() ?? 'Pago';
        final monto = (pago['monto'] as num).toDouble();
        final metodo = pago['metodo']?.toString() ?? '';
        final fecha = DateTime.tryParse(pago['fecha']?.toString() ?? '');
        final recibo = pago['numero_recibo']?.toString();

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: AppColors.verde.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_outline,
                    color: AppColors.verde, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(etiqueta, style: const TextStyle(
                    fontWeight: FontWeight.w700, color: AppColors.azul)),
                if (fecha != null)
                  Text(_fmtFechaHora.format(fecha),
                      style: const TextStyle(fontSize: 12, color: AppColors.gris)),
                if (metodo.isNotEmpty)
                  Text(metodo, style: const TextStyle(fontSize: 12, color: AppColors.gris)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(_fmt.format(monto), style: const TextStyle(
                    fontWeight: FontWeight.w800, color: AppColors.azul, fontSize: 15)),
                if (recibo != null)
                  Text('REC-$recibo', style: const TextStyle(
                      fontSize: 11, color: AppColors.gris)),
              ]),
            ]),
          ),
        );
      },
    );
  }
}

// ─── Helpers compartidos de comprobante ───────────────────────────────────────

/// Muestra un diálogo cuando el usuario negó el permiso de cámara/galería.
void _avisoPermiso(BuildContext context, String cual) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Permiso de $cual necesario'),
      content: Text(
        'Para subir el comprobante necesitás dar permiso de $cual. '
        'Podés habilitarlo en los Ajustes del teléfono.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: () { Navigator.pop(context); PermisosService.abrirConfiguracion(); },
          child: const Text('Abrir Ajustes'),
        ),
      ],
    ),
  );
}

/// Muestra el error de archivo del backend en un diálogo (mensaje completo con
// indicaciones de formatos permitidos y tamaño), no en un snackbar cortado.
void _mostrarErrorArchivo(BuildContext context, String mensaje) {
  final limpio = mensaje.replaceFirst('Exception: ', '');
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      icon: const Icon(Icons.warning_amber, color: AppColors.amber, size: 40),
      title: const Text('No se pudo subir'),
      content: Text(limpio, style: const TextStyle(height: 1.4)),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Entendido'),
        ),
      ],
    ),
  );
}
