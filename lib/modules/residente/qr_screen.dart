import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../../api/client.dart';
import '../../api/config.dart';
import '../../theme/app_theme.dart';

final _fmtVigencia = DateFormat('dd/MM/yyyy');
final _fmtHora = DateFormat('dd/MM HH:mm');

class QrScreen extends StatefulWidget {
  const QrScreen({super.key});

  @override
  State<QrScreen> createState() => _QrScreenState();
}

class _QrScreenState extends State<QrScreen> {
  List<dynamic> _visitas = [];
  bool _cargando = true;
  String? _error;
  bool _bloqueada = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() { _cargando = true; _error = null; });
    try {
      final res = await ResidenteApi.misVisitas();
      if (mounted) setState(() => _visitas = res);
    } on ApiException catch (e) {
      if (e.code == 'cuenta_bloqueada') {
        setState(() => _bloqueada = true);
      } else {
        setState(() => _error = e.message);
      }
    } catch (e) {
      setState(() => _error = 'No se pudo conectar');
    } finally {
      setState(() => _cargando = false);
    }
  }

  void _abrirCrear() {
    if (_bloqueada) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Tu cuenta está bloqueada por mora. No podés generar QR.'),
        backgroundColor: AppColors.rojo,
      ));
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ModalCrearQr(onCreado: (visita) {
        _cargar();
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) _abrirTarjeta(visita);
        });
      }),
    );
  }

  void _abrirTarjeta(dynamic visita) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _TarjetaQrPanel(visita: visita, onCancelada: _cargar),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grisCl,
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorReintentar(error: _error!, onRetry: _cargar)
              : _buildConPestanas(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirCrear,
        backgroundColor: AppColors.naranja,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nuevo QR',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }

  bool _esActiva(dynamic v) {
    final estado = v['estado']?.toString() ?? '';
    final estadoReal = v['estado_real']?.toString() ?? '';
    // Histórico si el estado base es final...
    if (['usada', 'expirada', 'revocada'].contains(estado)) return false;
    // ...o si el estado real indica que ya salió o venció por fecha
    if (['salio', 'expirada', 'usada'].contains(estadoReal)) return false;
    return true;
  }

  Widget _buildConPestanas() {
    final activas = _visitas.where(_esActiva).toList();
    final historico = _visitas.where((v) => !_esActiva(v)).toList();

    return DefaultTabController(
      length: 2,
      child: Column(children: [
        Container(
          color: Colors.white,
          child: TabBar(
            labelColor: AppColors.azul,
            unselectedLabelColor: AppColors.gris,
            indicatorColor: AppColors.naranja,
            indicatorWeight: 3,
            tabs: [
              Tab(text: 'Activas (${activas.length})'),
              Tab(text: 'Histórico (${historico.length})'),
            ],
          ),
        ),
        Expanded(child: TabBarView(children: [
          _buildLista(activas, vacioMsg: 'No tenés visitas activas.\nCreá una con el botón naranja.'),
          _buildLista(historico, vacioMsg: 'No hay visitas en el histórico todavía.'),
        ])),
      ]),
    );
  }

  Widget _buildLista(List<dynamic> lista, {required String vacioMsg}) {
    return RefreshIndicator(
      onRefresh: _cargar,
      child: lista.isEmpty
          ? ListView(children: [
              const SizedBox(height: 120),
              Center(child: Column(children: [
                Icon(Icons.qr_code_2, size: 72, color: AppColors.gris.withOpacity(0.3)),
                const SizedBox(height: 12),
                Text(vacioMsg, textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.gris)),
              ])),
            ])
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ...lista.map((v) => _VisitaCard(visita: v, onTap: () => _abrirTarjeta(v))),
                const SizedBox(height: 80),
              ],
            ),
    );
  }
}

// ─── Card de una visita en la lista ───────────────────────────────────────────
class _VisitaCard extends StatelessWidget {
  final dynamic visita;
  final VoidCallback onTap;
  const _VisitaCard({required this.visita, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tipo    = visita['tipo'] ?? 'unica';
    final nombre  = visita['nombre_visitante'] ?? 'Visita';
    final estado  = visita['estado'] ?? '';
    final empresa = visita['empresa'];
    final enVehiculo = visita['en_vehiculo'] == true;
    final validoHasta = visita['valido_hasta'] != null
        ? DateTime.tryParse(visita['valido_hasta'])
        : null;
    final horaEntrada = visita['hora_entrada'] != null
        ? DateTime.tryParse(visita['hora_entrada'])
        : null;
    final horaSalida = visita['hora_salida'] != null
        ? DateTime.tryParse(visita['hora_salida'])
        : null;

    final activa = estado == 'activa' || estado == 'pendiente';

    Color chipColor;
    String chipLabel;
    IconData icono;
    switch (tipo) {
      case 'recurrente':
        chipColor = AppColors.azul2; chipLabel = 'Recurrente';
        icono = Icons.repeat; break;
      case 'repartidor':
        chipColor = AppColors.amber; chipLabel = 'Repartidor';
        icono = Icons.delivery_dining; break;
      default:
        chipColor = AppColors.verde; chipLabel = 'Única';
        icono = Icons.person;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: chipColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icono, color: chipColor, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombre, style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.azul)),
                const SizedBox(height: 3),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  _MiniChip(label: chipLabel, color: chipColor),
                  _MiniChip(
                    label: activa ? 'Activa' : estado,
                    color: activa ? AppColors.verde : AppColors.gris,
                  ),
                  if (enVehiculo) const _MiniChip(label: 'Vehículo', color: AppColors.azul2),
                  if (empresa != null) _MiniChip(label: empresa, color: AppColors.amber),
                ]),
                if (validoHasta != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Válido hasta: ${_fmtVigencia.format(validoHasta)}',
                        style: const TextStyle(fontSize: 11, color: AppColors.gris)),
                  ),
                if (horaEntrada != null || horaSalida != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(children: [
                      if (horaEntrada != null) ...[
                        const Icon(Icons.login, size: 13, color: AppColors.verde),
                        const SizedBox(width: 3),
                        Text(_fmtHora.format(horaEntrada.toLocal()),
                            style: const TextStyle(fontSize: 11, color: AppColors.verde, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 10),
                      ],
                      if (horaSalida != null) ...[
                        const Icon(Icons.logout, size: 13, color: AppColors.azul),
                        const SizedBox(width: 3),
                        Text(_fmtHora.format(horaSalida.toLocal()),
                            style: const TextStyle(fontSize: 11, color: AppColors.azul, fontWeight: FontWeight.w600)),
                      ],
                    ]),
                  ),
              ],
            )),
            const Icon(Icons.qr_code_2, color: AppColors.azul, size: 28),
          ]),
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(label, style: TextStyle(
        color: color, fontSize: 11, fontWeight: FontWeight.w600)),
  );
}

// ─── Panel de la tarjeta QR (imagen del backend con logo) ─────────────────────
class _TarjetaQrPanel extends StatefulWidget {
  final dynamic visita;
  final VoidCallback onCancelada;
  const _TarjetaQrPanel({required this.visita, required this.onCancelada});

  @override
  State<_TarjetaQrPanel> createState() => _TarjetaQrPanelState();
}

class _TarjetaQrPanelState extends State<_TarjetaQrPanel> {
  Uint8List? _imagen;
  bool _cargando = true;
  bool _cancelando = false;

  @override
  void initState() {
    super.initState();
    _cargarImagen();
  }

  Future<void> _cargarImagen() async {
    try {
      final token = await AuthStorage.getToken();
      final uuid = widget.visita['uuid_publico'] ?? widget.visita['id'].toString();
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/visitas/$uuid/qr-imagen'),
        headers: {
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(ApiConfig.timeout);
      if (res.statusCode == 200) {
        setState(() => _imagen = res.bodyBytes);
      }
    } catch (_) {
      // Si falla se muestra un placeholder
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _compartir() async {
    if (_imagen == null) return;
    final dir = await getTemporaryDirectory();
    final nombre = (widget.visita['nombre_visitante'] ?? 'visita')
        .toString().replaceAll(' ', '_');
    final file = File('${dir.path}/qr_$nombre.png');
    await file.writeAsBytes(_imagen!);
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Tu código QR de acceso a Residencial Villas del Sol',
    );
  }

  Future<void> _cancelar() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancelar QR'),
        content: const Text(
            'El código dejará de funcionar y el visitante no podrá entrar con él. ¿Continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Volver')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, cancelar', style: TextStyle(color: AppColors.rojo)),
          ),
        ],
      ),
    );
    if (confirmado != true) return;

    setState(() => _cancelando = true);
    try {
      final uuid = widget.visita['uuid_publico'] ?? widget.visita['id'].toString();
      await ApiClient.post('/visitas/$uuid/cancelar', {});
      if (!mounted) return;
      Navigator.pop(context);
      widget.onCancelada();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.rojo));
    } finally {
      if (mounted) setState(() => _cancelando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nombre = widget.visita['nombre_visitante'] ?? '';
    final estado = widget.visita['estado'] ?? '';
    final activa = estado == 'activa' || estado == 'pendiente';

    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(
            color: AppColors.borde, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        Text(nombre, style: const TextStyle(
            fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.azul)),
        const SizedBox(height: 16),

        if (_cargando)
          const SizedBox(height: 280,
              child: Center(child: CircularProgressIndicator()))
        else if (_imagen != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.memory(_imagen!, width: 280, fit: BoxFit.contain),
          )
        else
          Container(
            height: 200, width: 280,
            decoration: BoxDecoration(
              color: AppColors.grisCl,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(child: Text('No se pudo cargar el QR',
                style: TextStyle(color: AppColors.gris))),
          ),
        const SizedBox(height: 20),

        Row(children: [
          Expanded(child: ElevatedButton.icon(
            onPressed: _imagen != null ? _compartir : null,
            icon: const Icon(Icons.share, size: 18),
            label: const Text('Compartir'),
          )),
          const SizedBox(width: 10),
          if (activa)
            Expanded(child: OutlinedButton.icon(
              onPressed: _cancelando ? null : _cancelar,
              icon: _cancelando
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.block, size: 18, color: AppColors.rojo),
              label: Text(_cancelando ? 'Cancelando…' : 'Cancelar QR',
                  style: const TextStyle(color: AppColors.rojo)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.rojo),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            )),
        ]),
      ]),
    );
  }
}

// ─── Modal de creación con TODOS los campos de la web ─────────────────────────
class _ModalCrearQr extends StatefulWidget {
  final void Function(dynamic visita) onCreado;
  const _ModalCrearQr({required this.onCreado});

  @override
  State<_ModalCrearQr> createState() => _ModalCrearQrState();
}

class _ModalCrearQrState extends State<_ModalCrearQr> {
  String _tipo = 'unica';
  final _nombreCtrl   = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _empresaCtrl  = TextEditingController();
  bool _enVehiculo    = false;
  DateTime? _validoHasta;
  bool _creando = false;
  String? _error;

  @override
  void dispose() {
    _nombreCtrl.dispose(); _telefonoCtrl.dispose();
    _empresaCtrl.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final ahora = DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate: ahora.add(const Duration(days: 30)),
      firstDate: ahora,
      lastDate: ahora.add(const Duration(days: 365)),
      helpText: 'Válido hasta',
    );
    if (elegida != null) setState(() => _validoHasta = elegida);
  }

  Future<void> _crear() async {
    if (_nombreCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Ingresá el nombre del visitante');
      return;
    }
    if (_tipo == 'recurrente' && _validoHasta == null) {
      setState(() => _error = 'Indicá hasta cuándo es válido');
      return;
    }
    setState(() { _creando = true; _error = null; });
    try {
      final body = <String, dynamic>{
        'tipo': _tipo,
        'nombre_visitante': _nombreCtrl.text.trim(),
        if (_telefonoCtrl.text.trim().isNotEmpty)
          'telefono': _telefonoCtrl.text.trim(),
        if (_tipo == 'repartidor' && _empresaCtrl.text.trim().isNotEmpty)
          'empresa': _empresaCtrl.text.trim(),
        'en_vehiculo': _enVehiculo,
        if (_tipo == 'recurrente' && _validoHasta != null)
          'valido_hasta': _validoHasta!.toIso8601String(),
      };
      final visita = await ApiClient.post('/visitas', body);
      if (!mounted) return;
      Navigator.pop(context);
      widget.onCreado(visita);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'No se pudo crear el QR');
    } finally {
      if (mounted) setState(() => _creando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(
              color: AppColors.borde, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Text('Nuevo código QR', style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.azul)),
          const SizedBox(height: 18),

          // Tipo de QR — tarjetas grandes
          Row(children: [
            for (final t in [
              ('unica', 'Única', Icons.person, AppColors.verde),
              ('recurrente', 'Recurrente', Icons.repeat, AppColors.azul2),
              ('repartidor', 'Repartidor', Icons.delivery_dining, AppColors.amber),
            ])
              Expanded(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _tipo = t.$1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _tipo == t.$1 ? t.$4 : AppColors.grisCl,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _tipo == t.$1 ? t.$4 : AppColors.borde,
                      ),
                    ),
                    child: Column(children: [
                      Icon(t.$3, size: 22,
                          color: _tipo == t.$1 ? Colors.white : AppColors.gris),
                      const SizedBox(height: 4),
                      Text(t.$2, style: TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.w700,
                        color: _tipo == t.$1 ? Colors.white : AppColors.gris,
                      )),
                    ]),
                  ),
                ),
              )),
          ]),
          const SizedBox(height: 8),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.azul.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _tipo == 'unica'
                  ? 'Un solo uso: el QR se invalida al entrar.'
                  : _tipo == 'recurrente'
                      ? 'Múltiples entradas hasta la fecha de vencimiento (ej. empleada, familiar).'
                      : 'Para repartidores: acceso puntual con registro de la empresa.',
              style: const TextStyle(fontSize: 12, color: AppColors.azul2),
            ),
          ),
          const SizedBox(height: 14),

          TextField(
            controller: _nombreCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nombre del visitante *',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _telefonoCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Teléfono (opcional)',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),

          if (_tipo == 'repartidor') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _empresaCtrl,
              decoration: const InputDecoration(
                labelText: 'Empresa (PedidosYa, Uber Eats…)',
                prefixIcon: Icon(Icons.storefront_outlined),
              ),
            ),
          ],

          if (_tipo == 'recurrente') ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: _elegirFecha,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Válido hasta *',
                  prefixIcon: Icon(Icons.event_outlined),
                ),
                child: Text(
                  _validoHasta != null
                      ? _fmtVigencia.format(_validoHasta!)
                      : 'Elegir fecha…',
                  style: TextStyle(
                    color: _validoHasta != null ? AppColors.azul : AppColors.gris,
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Llega en vehículo',
                style: TextStyle(fontSize: 14, color: AppColors.azul)),
            subtitle: const Text('El guardia le pedirá el número de placa al entrar',
                style: TextStyle(fontSize: 11.5, color: AppColors.gris)),
            value: _enVehiculo,
            activeColor: AppColors.naranja,
            onChanged: (v) => setState(() => _enVehiculo = v),
          ),

          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: AppColors.rojo, fontSize: 13)),
          ],
          const SizedBox(height: 18),

          SizedBox(width: double.infinity,
            child: ElevatedButton(
              onPressed: _creando ? null : _crear,
              child: _creando
                  ? const SizedBox(height: 20, width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Crear QR'),
            ),
          ),
        ]),
      ),
    );
  }
}

class _ErrorReintentar extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorReintentar({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Icon(Icons.wifi_off, size: 56, color: AppColors.gris),
      const SizedBox(height: 12),
      Text(error, textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.gris)),
      const SizedBox(height: 16),
      ElevatedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh),
          label: const Text('Reintentar')),
    ],
  ));
}
