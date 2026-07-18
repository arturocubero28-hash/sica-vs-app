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
                onPressed: () => _abrirSubidaComprobante(
                    context, cuota['uuid_publico'] ?? cuota['id'].toString(), monto),
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

  Future<void> _abrirSubidaComprobante(BuildContext context, String cuotaId, double monto) async {
    if (_subidasEnCurso.contains(cuotaId)) return;
    final resultado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => _PantallaMultiplesComprobantes(
        cuotaId: cuotaId, monto: monto,
      )),
    );
    if (resultado == true) onPagada();
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

// ─── Pantalla: subir uno o varios comprobantes para una cuota ─────────────────
//
// El residente puede depositar en varias partes (ej. transfirió L500 hoy y
// L700 mañana). Esta pantalla acumula las fotos antes de enviar — no sube
// nada hasta que el residente toca "Enviar". El admin va a revisar todas
// juntas y aprobar el pago completo de una sola vez.
class _PantallaMultiplesComprobantes extends StatefulWidget {
  final String cuotaId;
  final double monto;
  const _PantallaMultiplesComprobantes({required this.cuotaId, required this.monto});

  @override
  State<_PantallaMultiplesComprobantes> createState() => _PantallaMultiplesComprobantesState();
}

class _PantallaMultiplesComprobantesState extends State<_PantallaMultiplesComprobantes> {
  final List<File> _archivos = [];
  bool _enviando = false;
  bool _restaurado = false;

  static const _maxArchivos = 5;

  @override
  void initState() {
    super.initState();
    _restaurarSiHuboReinicio();
  }

  /// Si Android mató el proceso mientras el residente tomaba una foto,
  /// recupera esa foto Y las que ya tenía acumuladas antes de abrir la cámara.
  Future<void> _restaurarSiHuboReinicio() async {
    final pendiente = await RecuperacionComprobante.leerPendiente();
    if (pendiente == null || pendiente['id'] != widget.cuotaId) return;

    final rutas = (pendiente['rutas'] as List<dynamic>? ?? []).cast<String>();
    final fotoNueva = await RecuperacionComprobante.recuperarFotoPerdida();

    if (!mounted) return;
    setState(() {
      _archivos.addAll(rutas.map((r) => File(r)));
      if (fotoNueva != null) _archivos.add(fotoNueva);
      _restaurado = true;
    });
  }

  Future<void> _agregarFoto() async {
    if (_archivos.length >= _maxArchivos) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Máximo 5 comprobantes por pago'), backgroundColor: AppColors.amber));
      return;
    }

    final fuente = await _elegirFuente(context);
    if (fuente == null || !mounted) return;

    if (fuente == ImageSource.camera) {
      final ok = await PermisosService.pedirCamara();
      if (!ok) { if (mounted) _avisoPermiso(context, 'cámara'); return; }
    } else {
      final ok = await PermisosService.pedirGaleria();
      if (!ok) { if (mounted) _avisoPermiso(context, 'galería'); return; }
    }

    // Persistir el contexto + lo ya acumulado ANTES de abrir la cámara —
    // si Android mata el proceso, se recupera todo al volver.
    await RecuperacionComprobante.guardar(
      id: widget.cuotaId, monto: widget.monto, tipo: 'cuota',
      rutasAcumuladas: _archivos.map((f) => f.path).toList(),
    );
    final archivo = await CamaraHelper.capturar(fuente: fuente, quality: 50, maxSize: 1024);
    if (archivo == null || !mounted) {
      await RecuperacionComprobante.limpiar();
      return;
    }
    setState(() => _archivos.add(archivo));
    await RecuperacionComprobante.limpiar();
  }

  void _quitarFoto(int i) {
    setState(() => _archivos.removeAt(i));
  }

  Future<void> _enviar() async {
    if (_archivos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Adjuntá al menos un comprobante'), backgroundColor: AppColors.amber));
      return;
    }
    setState(() => _enviando = true);
    try {
      await ResidenteApi.subirComprobante(widget.cuotaId, _archivos, widget.monto);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      _mostrarErrorArchivo(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Subir comprobante')),
      body: Column(children: [
        if (_restaurado)
          Container(
            width: double.infinity,
            color: AppColors.verde.withOpacity(0.1),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: const Text('✓ Recuperamos tus fotos después del reinicio',
                style: TextStyle(fontSize: 12.5, color: AppColors.verde)),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.azul.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              '¿Depositaste en varias partes? Agregá todos los comprobantes acá. '
              'La administración los revisa juntos y aprueba el pago completo.',
              style: TextStyle(fontSize: 12.5, color: AppColors.gris, height: 1.4),
            ),
          ),
        ),
        Expanded(
          child: _archivos.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.receipt_long_outlined, size: 56, color: AppColors.gris),
                  const SizedBox(height: 12),
                  const Text('Todavía no adjuntaste ningún comprobante',
                      style: TextStyle(color: AppColors.gris)),
                ]))
              : GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10),
                  itemCount: _archivos.length,
                  itemBuilder: (_, i) => Stack(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(_archivos[i],
                          width: double.infinity, height: double.infinity, fit: BoxFit.cover),
                    ),
                    Positioned(top: 4, right: 4, child: InkWell(
                      onTap: () => _quitarFoto(i),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(color: AppColors.rojo, shape: BoxShape.circle),
                        child: const Icon(Icons.close, size: 14, color: Colors.white),
                      ),
                    )),
                  ]),
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            if (_archivos.length < _maxArchivos)
              SizedBox(width: double.infinity, child: OutlinedButton.icon(
                onPressed: _enviando ? null : _agregarFoto,
                icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                label: Text(_archivos.isEmpty ? 'Adjuntar comprobante' : 'Agregar otro comprobante'),
              )),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: (_archivos.isEmpty || _enviando) ? null : _enviar,
              child: Text(_enviando ? 'Enviando…' : 'Enviar comprobante'),
            )),
          ]),
        ),
      ]),
    );
  }
}
